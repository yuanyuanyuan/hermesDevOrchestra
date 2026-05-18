from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


class PerformanceSLOError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class PerformanceBudgetPolicy:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/performance",
        allow_staged: bool = False,
        enabled: bool = True,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self._policy: dict[str, Any] | None = None

    def load_policy(self) -> dict[str, Any]:
        self._require_enabled()
        if self._policy is not None:
            return self._policy

        data = self._load_json("slo-policy.json")
        self._validate_definition("performance_slo_policy", data)
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise PerformanceSLOError("config_invalid", "slo-policy.json is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise PerformanceSLOError("module_disabled", "slo-policy.json is staged; allow_staged=True is required")
        self._policy = data
        return self._policy

    def evaluate(self, component_id: str, observed: dict[str, Any]) -> dict[str, Any]:
        policy = self.load_policy()
        if not isinstance(component_id, str) or not component_id:
            raise PerformanceSLOError("validation_error", "component_id must be a non-empty string")
        if not isinstance(observed, dict):
            raise PerformanceSLOError("validation_error", "observed must be an object")

        component_budgets = policy["component_budgets"]
        if component_id not in component_budgets:
            raise PerformanceSLOError("component_unknown", f"unknown performance component: {component_id}")

        component_budget = component_budgets[component_id]
        misses: list[str] = []
        degradation_status = "normal"
        degradation_action = "none"
        completion_evidence_allowed = True

        if component_id == "gateway_api":
            misses = self._threshold_misses(component_budget, observed)
        elif component_id == "event_projection":
            misses = self._threshold_misses(component_budget, observed)
            if misses:
                action = self._action_for_condition(policy, "projection_budget_miss_after_authority_commit")
                degradation_status = action["degradation_status"]
                degradation_action = action["action"]
                completion_evidence_allowed = action["completion_evidence_allowed"]
        elif component_id == "runtime_knowledge":
            misses = self._threshold_misses(component_budget, observed)
            if misses:
                action = self._action_for_condition(policy, "runtime_knowledge_query_timeout")
                degradation_status = action["degradation_status"]
                degradation_action = action["action"]
                completion_evidence_allowed = action["completion_evidence_allowed"]
        elif component_id == "release_pipeline":
            if "command_timed_out" not in observed:
                raise PerformanceSLOError("observation_missing", "release_pipeline requires command_timed_out")
            if observed["command_timed_out"] is True:
                misses = ["command_timed_out"]
                action = self._action_for_condition(policy, "release_command_timeout")
                degradation_status = action["degradation_status"]
                degradation_action = action["action"]
                completion_evidence_allowed = action["completion_evidence_allowed"]
        else:
            misses = self._threshold_misses(component_budget, observed)

        budget_status = "budget_missed" if misses else "on_budget"
        return {
            "component_id": component_id,
            "budget_status": budget_status,
            "budget_misses": misses,
            "degradation_status": degradation_status,
            "degradation_action": degradation_action,
            "completion_evidence_allowed": completion_evidence_allowed,
            "human_wait_excluded_from_slo": bool(policy["human_wait_excluded_from_slo"]),
            "external_backend_wait_reported_separately": bool(policy["external_backend_wait_reported_separately"]),
            "observed": dict(observed),
            "evaluated_at": self._timestamp(),
        }

    def _threshold_misses(self, component_budget: dict[str, Any], observed: dict[str, Any]) -> list[str]:
        misses: list[str] = []
        numeric_thresholds = {
            key: value
            for key, value in component_budget.items()
            if isinstance(value, int) and (key.endswith("_ms") or key.endswith("_seconds"))
        }
        missing_fields = [key for key in numeric_thresholds if key not in observed]
        if missing_fields:
            raise PerformanceSLOError("observation_missing", f"missing observed fields: {missing_fields}")

        for key, threshold in numeric_thresholds.items():
            observed_value = observed[key]
            if not isinstance(observed_value, (int, float)):
                raise PerformanceSLOError("observation_missing", f"{key} must be numeric")
            if observed_value > threshold:
                misses.append(key)
        return misses

    def _action_for_condition(self, policy: dict[str, Any], condition: str) -> dict[str, Any]:
        for action in policy["degradation_actions"]:
            if action.get("condition") == condition:
                return action
        raise PerformanceSLOError("config_invalid", f"missing degradation action for condition {condition}")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise PerformanceSLOError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise PerformanceSLOError("config_invalid", f"{filename} is missing") from exc
        if not isinstance(data, dict):
            raise PerformanceSLOError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise PerformanceSLOError("module_disabled", "performance slo policy is disabled")

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise PerformanceSLOError("config_invalid", exc.message) from exc
