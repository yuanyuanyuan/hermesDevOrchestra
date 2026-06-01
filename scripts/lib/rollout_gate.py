from __future__ import annotations

import json
from datetime import date, datetime
from pathlib import Path
from typing import Any


class RolloutGateError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class RolloutGate:
    def __init__(self, repo_root: Path | str, policy_path: str = "config/performance/slo-policy.json") -> None:
        self.repo_root = Path(repo_root)
        self.policy_path = policy_path
        self._policy: dict[str, Any] | None = None

    def allow(self, channel: str, project_age_weeks: int, calibration_evidence: dict[str, Any]) -> dict[str, Any]:
        if channel not in {"quick", "light", "standard"}:
            raise RolloutGateError("validation_error", "channel must be quick, light, or standard")
        if not isinstance(project_age_weeks, int) or project_age_weeks < 1:
            raise RolloutGateError("validation_error", "project_age_weeks must be a positive integer")
        if not isinstance(calibration_evidence, dict):
            raise RolloutGateError("validation_error", "calibration_evidence must be an object")

        policy = self._load_policy()
        rollout = policy.get("rollout_gate", {})
        min_confidence = float(rollout.get("min_confidence", 0.7))
        min_coverage = float(rollout.get("min_coverage", 0.5))
        confidence = self._number(calibration_evidence.get("confidence"), "confidence")
        coverage = self._number(calibration_evidence.get("coverage"), "coverage")

        if confidence < min_confidence or coverage < min_coverage:
            return {
                "allowed": False,
                "channel": "standard",
                "requested_channel": channel,
                "forced_standard": True,
                "reason": "insufficient_calibration_evidence",
                "project_age_weeks": project_age_weeks,
                "calibration_evidence": dict(calibration_evidence),
            }

        return {
            "allowed": True,
            "channel": channel,
            "requested_channel": channel,
            "forced_standard": False,
            "reason": "rollout_gate_allowed",
            "project_age_weeks": project_age_weeks,
            "calibration_evidence": dict(calibration_evidence),
        }

    def project_age_weeks(self, first_intake_date: str, today: date | None = None) -> int:
        try:
            started = datetime.strptime(first_intake_date, "%Y-%m-%d").date()
        except ValueError as exc:
            raise RolloutGateError("validation_error", "first_intake_date must use YYYY-MM-DD") from exc
        current = today or date.today()
        if current < started:
            return 1
        return ((current - started).days // 7) + 1

    def _number(self, value: Any, name: str) -> float:
        if not isinstance(value, (int, float)):
            raise RolloutGateError("validation_error", f"calibration_evidence.{name} must be numeric")
        return float(value)

    def _load_policy(self) -> dict[str, Any]:
        if self._policy is None:
            path = self.repo_root / self.policy_path
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise RolloutGateError("config_invalid", f"slo-policy.json is not valid JSON: {exc.msg}") from exc
            except FileNotFoundError as exc:
                raise RolloutGateError("config_invalid", "slo-policy.json is missing") from exc
            if not isinstance(data, dict):
                raise RolloutGateError("config_invalid", "slo-policy.json must contain an object")
            self._policy = data
        return self._policy
