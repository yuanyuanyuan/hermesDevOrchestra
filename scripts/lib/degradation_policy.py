from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


class DegradationPolicyError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class DegradationPolicy:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/degradation",
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

        data = self._load_json("policy.json")
        self._validate_definition("degradation_policy", data)
        self._require_package_active(data, "policy.json")

        state_machine = data.get("state_machine")
        if not isinstance(state_machine, dict):
            raise DegradationPolicyError("config_invalid", "policy.json state_machine must be an object")
        states = state_machine.get("states")
        if not isinstance(states, list) or not all(isinstance(state, str) and state for state in states):
            raise DegradationPolicyError("config_invalid", "policy.json state_machine.states must be a non-empty string list")
        transitions = state_machine.get("transitions")
        if not isinstance(transitions, list) or not transitions:
            raise DegradationPolicyError("config_invalid", "policy.json state_machine.transitions must be a non-empty list")

        transition_pairs: set[tuple[str, str]] = set()
        for transition in transitions:
            if not isinstance(transition, dict):
                raise DegradationPolicyError("config_invalid", "policy.json transitions must be objects")
            source = transition.get("from")
            target = transition.get("to")
            if not isinstance(source, str) or not isinstance(target, str):
                raise DegradationPolicyError("config_invalid", "policy.json transition entries require string from/to")
            transition_pairs.add((source, target))

        required_record_fields = data.get("required_record_fields")
        if not isinstance(required_record_fields, list) or not all(
            isinstance(field, str) and field for field in required_record_fields
        ):
            raise DegradationPolicyError("config_invalid", "policy.json required_record_fields must be a non-empty string list")

        family_policy = data.get("artifact_family_policy")
        if not isinstance(family_policy, dict) or not family_policy:
            raise DegradationPolicyError("config_invalid", "policy.json artifact_family_policy must be a non-empty object")

        self._policy = {
            **data,
            "state_machine": {
                **state_machine,
                "state_set": set(states),
                "transition_pairs": transition_pairs,
            },
        }
        return self._policy

    def transition(self, current_status: str, next_status: str) -> str:
        policy = self.load_policy()
        self._require_status(current_status, "current_status", policy)
        self._require_status(next_status, "next_status", policy)
        if (current_status, next_status) not in policy["state_machine"]["transition_pairs"]:
            raise DegradationPolicyError("transition_invalid", f"invalid degradation transition: {current_status} -> {next_status}")
        return next_status

    def build_record(
        self,
        *,
        degradation_status: str,
        degradation_class: str,
        cause: str,
        affected_evidence_refs: list[str],
        recovery_options: list[str],
        policy_key: str | None = None,
        decision_required: str | None = None,
        accepted_by_ref: str | None = None,
        completion_evidence_allowed: bool | None = None,
        replacement_evidence_ref: str | None = None,
        policy_ref: str = "config://degradation/policy",
    ) -> dict[str, Any]:
        policy = self.load_policy()
        self._require_status(degradation_status, "degradation_status", policy)
        self._require_non_empty_string(degradation_class, "degradation_class")
        self._require_non_empty_string(cause, "cause")
        self._require_string_list(affected_evidence_refs, "affected_evidence_refs")
        self._require_string_list(recovery_options, "recovery_options")

        resolved_policy_key = policy_key or degradation_class
        if not isinstance(resolved_policy_key, str) or not resolved_policy_key:
            raise DegradationPolicyError("validation_error", "policy_key must be a non-empty string when provided")
        family_policy = policy["artifact_family_policy"].get(resolved_policy_key, {})
        if family_policy and not isinstance(family_policy, dict):
            raise DegradationPolicyError("config_invalid", f"artifact_family_policy[{resolved_policy_key}] must be an object")

        resolved_decision = decision_required or family_policy.get("decision_required") or "none"
        if resolved_decision not in {"none", "kimi", "human"}:
            raise DegradationPolicyError("config_invalid", f"unsupported decision_required value: {resolved_decision}")

        if completion_evidence_allowed is None:
            resolved_completion = bool(family_policy.get("completion_evidence_allowed", policy["default_completion_evidence_allowed"]))
        else:
            resolved_completion = completion_evidence_allowed
        if not isinstance(resolved_completion, bool):
            raise DegradationPolicyError("validation_error", "completion_evidence_allowed must be a boolean")

        if degradation_status == "recovered" and policy["state_machine"].get("replacement_evidence_required_for_recovered") is True:
            if not isinstance(replacement_evidence_ref, str) or not replacement_evidence_ref:
                raise DegradationPolicyError("replacement_evidence_required", "recovered degradation records require replacement_evidence_ref")

        if degradation_status in {"degraded", "blocked_due_to_degradation"} and resolved_completion and resolved_decision != "none":
            if not isinstance(accepted_by_ref, str) or not accepted_by_ref:
                raise DegradationPolicyError(
                    "acceptance_required",
                    "degraded completion evidence requires an acceptance ref for the configured decision authority",
                )

        record = {
            "degradation_status": degradation_status,
            "degradation_class": degradation_class,
            "cause": cause,
            "affected_evidence_refs": list(affected_evidence_refs),
            "decision_required": resolved_decision,
            "recovery_options": list(recovery_options),
            "accepted_by_ref": accepted_by_ref,
            "completion_evidence_allowed": resolved_completion,
            "replacement_evidence_ref": replacement_evidence_ref,
            "policy_ref": policy_ref,
        }
        self._validate_required_record_fields(policy, record)
        self._validate_definition("degradation_record", record)
        return record

    def allows_completion_evidence(self, record: dict[str, Any]) -> bool:
        policy = self.load_policy()
        if not isinstance(record, dict):
            raise DegradationPolicyError("validation_error", "record must be an object")
        self._validate_required_record_fields(policy, record)
        self._validate_definition("degradation_record", record)

        status = record["degradation_status"]
        if status == "normal":
            return bool(record["completion_evidence_allowed"])
        if status == "recovered":
            if policy["state_machine"].get("replacement_evidence_required_for_recovered") is True:
                replacement = record.get("replacement_evidence_ref")
                if not isinstance(replacement, str) or not replacement:
                    raise DegradationPolicyError("replacement_evidence_required", "recovered record is missing replacement_evidence_ref")
            return True

        if record["completion_evidence_allowed"] is not True:
            return False
        if record["decision_required"] == "none":
            return True

        accepted_by_ref = record.get("accepted_by_ref")
        return isinstance(accepted_by_ref, str) and bool(accepted_by_ref)

    def _validate_required_record_fields(self, policy: dict[str, Any], record: dict[str, Any]) -> None:
        missing_fields = [field for field in policy["required_record_fields"] if field not in record]
        if missing_fields:
            raise DegradationPolicyError("record_field_missing", f"degradation record is missing fields: {missing_fields}")

    def _require_status(self, value: str, label: str, policy: dict[str, Any]) -> None:
        if not isinstance(value, str) or not value:
            raise DegradationPolicyError("validation_error", f"{label} must be a non-empty string")
        if value not in policy["state_machine"]["state_set"]:
            raise DegradationPolicyError("validation_error", f"{label} is not a declared degradation state: {value}")

    def _require_non_empty_string(self, value: str, label: str) -> None:
        if not isinstance(value, str) or not value:
            raise DegradationPolicyError("validation_error", f"{label} must be a non-empty string")

    def _require_string_list(self, value: list[str], label: str) -> None:
        if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
            raise DegradationPolicyError("validation_error", f"{label} must be a list of non-empty strings")

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise DegradationPolicyError("module_disabled", "degradation policy is disabled")

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise DegradationPolicyError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise DegradationPolicyError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise DegradationPolicyError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise DegradationPolicyError("config_invalid", f"{filename} is missing") from exc
        if not isinstance(data, dict):
            raise DegradationPolicyError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise DegradationPolicyError("schema_invalid", exc.message) from exc
