from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

from debate_report import DebateReportError, validate_artifact_definition


class StagedCutoverError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class FullSchemaCutover:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/cutover",
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

        data = self._load_json("full-readiness-gates.json")
        self._validate_definition("full_contract_readiness_gate_policy", data)
        self._require_package_active(data, "full-readiness-gates.json")

        required_gate_evidence = self._require_string_list(data, "required_gate_evidence", "full-readiness-gates.json")
        historical_policy = self._require_object(data, "default_historical_artifact_policy", "full-readiness-gates.json")
        new_run_policy = self._require_object(data, "default_new_run_policy_after_activation", "full-readiness-gates.json")
        artifact_families = data.get("artifact_families")
        if not isinstance(artifact_families, list) or not artifact_families:
            raise StagedCutoverError("config_invalid", "full-readiness-gates.json artifact_families must be a non-empty list")

        family_index: dict[str, dict[str, Any]] = {}
        for family in artifact_families:
            normalized = self._normalize_family(family)
            family_id = normalized["family_id"]
            if family_id in family_index:
                raise StagedCutoverError("config_invalid", f"artifact family {family_id} is defined more than once")
            family_index[family_id] = normalized

        self._policy = {
            **data,
            "required_gate_evidence": required_gate_evidence,
            "default_historical_artifact_policy": historical_policy,
            "default_new_run_policy_after_activation": new_run_policy,
            "artifact_family_index": family_index,
        }
        return self._policy

    def evaluate_family(self, family_id: str) -> dict[str, Any]:
        policy = self.load_policy()
        family = self._require_family(policy, family_id)
        missing_gate_requirements: list[str] = []

        required_checks = set(family["required_checks"])
        if "runtime_consumption_tests" not in required_checks:
            missing_gate_requirements.append("runtime_consumption_tests")
        if "explicit_cutover_decision" not in required_checks:
            missing_gate_requirements.append("explicit_cutover_decision")

        return {
            "family_id": family["family_id"],
            "activation_scope": family["activation_scope"],
            "mvp_sources": list(family["mvp_sources"]),
            "full_targets": list(family["full_targets"]),
            "required_gate_evidence": list(policy["required_gate_evidence"]),
            "required_checks": list(family["required_checks"]),
            "rollback_policy": dict(family["rollback_policy"]),
            "historical_policy": dict(policy["default_historical_artifact_policy"]),
            "new_run_policy_after_activation": dict(policy["default_new_run_policy_after_activation"]),
            "missing_gate_requirements": missing_gate_requirements,
            "gate_ready": not missing_gate_requirements,
        }

    def can_activate(
        self,
        family_id: str,
        *,
        evidence: Iterable[str] | None = None,
        completed_checks: Iterable[str] | None = None,
    ) -> dict[str, Any]:
        family = self.evaluate_family(family_id)
        provided_evidence = self._normalize_string_iterable(evidence, "evidence")
        provided_checks = self._normalize_string_iterable(completed_checks, "completed_checks")

        missing_evidence = sorted(set(family["required_gate_evidence"]) - provided_evidence)
        missing_checks = sorted(set(family["required_checks"]) - provided_checks)
        allowed = family["gate_ready"] and not missing_evidence and not missing_checks

        return {
            "family_id": family_id,
            "allowed": allowed,
            "missing_evidence": missing_evidence,
            "missing_checks": missing_checks,
            "activation_scope": family["activation_scope"],
            "rollback_policy": dict(family["rollback_policy"]),
        }

    def plan_artifact_write(
        self,
        family_id: str,
        *,
        family_activated: bool,
        historical_run: bool = False,
        existing_schema_version: str | None = None,
    ) -> dict[str, Any]:
        policy = self.load_policy()
        self._require_family(policy, family_id)

        if historical_run:
            if not isinstance(existing_schema_version, str) or not existing_schema_version:
                raise StagedCutoverError("validation_error", "existing_schema_version is required for historical runs")
            historical_policy = policy["default_historical_artifact_policy"]
            return {
                "family_id": family_id,
                "historical_run": True,
                "schema_ref": policy["active_runtime_default_schema_ref"],
                "schema_version": existing_schema_version,
                "write_full_artifacts": False,
                "preserve_original_schema_version": historical_policy["preserve_original_schema_version"],
                "rewrite_in_place_allowed": historical_policy["rewrite_in_place_allowed"],
                "migration_writes_lineage_ref": historical_policy["migration_writes_lineage_ref"],
            }

        new_run_policy = policy["default_new_run_policy_after_activation"]
        schema_ref = policy["full_target_schema_ref"] if family_activated else policy["active_runtime_default_schema_ref"]
        return {
            "family_id": family_id,
            "historical_run": False,
            "schema_ref": schema_ref,
            "write_full_artifacts": bool(family_activated and new_run_policy["write_full_artifacts_for_activated_family"]),
            "legacy_refs_remain_resolvable": new_run_policy["legacy_refs_remain_resolvable"],
            "mixed_family_runs_allowed": new_run_policy["mixed_family_runs_allowed_during_staged_cutover"],
            "completion_requires_active_family_contracts_only": new_run_policy["completion_requires_active_family_contracts_only"],
        }

    def _normalize_family(self, family: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(family, dict):
            raise StagedCutoverError("config_invalid", "artifact family entries must be objects")

        family_id = self._require_string(family, "family_id", "artifact family")
        activation_scope = self._require_string(family, "activation_scope", f"artifact family {family_id}")
        full_targets = self._require_string_list(family, "full_targets", f"artifact family {family_id}")
        required_checks = self._require_string_list(family, "required_checks", f"artifact family {family_id}")
        rollback_policy = self._require_object(family, "rollback_policy", f"artifact family {family_id}")

        mvp_sources = family.get("mvp_sources", [])
        if not isinstance(mvp_sources, list) or not all(isinstance(item, str) and item for item in mvp_sources):
            raise StagedCutoverError("config_invalid", f"artifact family {family_id} mvp_sources must be a string list")

        if not rollback_policy:
            raise StagedCutoverError("config_invalid", f"artifact family {family_id} rollback_policy must not be empty")
        for key, value in rollback_policy.items():
            if not isinstance(key, str) or not key:
                raise StagedCutoverError("config_invalid", f"artifact family {family_id} rollback_policy has an invalid key")
            if not isinstance(value, bool):
                raise StagedCutoverError("config_invalid", f"artifact family {family_id} rollback_policy[{key}] must be a boolean")

        return {
            "family_id": family_id,
            "activation_scope": activation_scope,
            "mvp_sources": list(mvp_sources),
            "full_targets": full_targets,
            "required_checks": required_checks,
            "rollback_policy": rollback_policy,
        }

    def _require_family(self, policy: dict[str, Any], family_id: str) -> dict[str, Any]:
        if not isinstance(family_id, str) or not family_id:
            raise StagedCutoverError("validation_error", "family_id must be a non-empty string")
        family = policy["artifact_family_index"].get(family_id)
        if family is None:
            raise StagedCutoverError("family_not_found", f"unknown artifact family: {family_id}")
        return family

    def _normalize_string_iterable(self, values: Iterable[str] | None, label: str) -> set[str]:
        if values is None:
            return set()
        normalized = set(values)
        if not all(isinstance(item, str) and item for item in normalized):
            raise StagedCutoverError("validation_error", f"{label} must contain only non-empty strings")
        return normalized

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise StagedCutoverError("module_disabled", "full schema cutover is disabled")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                payload = json.load(handle)
        except json.JSONDecodeError as exc:
            raise StagedCutoverError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise StagedCutoverError("config_invalid", f"{filename} is missing") from exc
        except PermissionError as exc:
            raise StagedCutoverError("config_invalid", f"{filename} is not readable: {exc.strerror or exc}") from exc
        if not isinstance(payload, dict):
            raise StagedCutoverError("config_invalid", f"{filename} must contain a JSON object")
        return payload

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise StagedCutoverError("config_invalid", exc.message) from exc

    def _require_package_active(self, payload: dict[str, Any], filename: str) -> None:
        package_status = payload.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise StagedCutoverError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise StagedCutoverError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _require_string(self, payload: dict[str, Any], key: str, label: str) -> str:
        value = payload.get(key)
        if not isinstance(value, str) or not value:
            raise StagedCutoverError("config_invalid", f"{label} is missing {key}")
        return value

    def _require_string_list(self, payload: dict[str, Any], key: str, label: str) -> list[str]:
        value = payload.get(key)
        if not isinstance(value, list) or not value or not all(isinstance(item, str) and item for item in value):
            raise StagedCutoverError("config_invalid", f"{label} {key} must be a non-empty string list")
        return list(value)

    def _require_object(self, payload: dict[str, Any], key: str, label: str) -> dict[str, Any]:
        value = payload.get(key)
        if not isinstance(value, dict):
            raise StagedCutoverError("config_invalid", f"{label} {key} must be an object")
        return dict(value)
