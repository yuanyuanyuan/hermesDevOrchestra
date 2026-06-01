from __future__ import annotations

import json
from pathlib import Path, PurePosixPath
from typing import Any

from staged_cutover import FullSchemaCutover, StagedCutoverError


MODULE_FAMILY_DEFAULTS = {
    "full-schema-validation": "gateway_authority",
    "full-schema-cutover": "gateway_authority",
    "degradation-policy": "gateway_authority",
    "performance-slo": "gateway_authority",
    "fixture-policy": "gateway_authority",
    "self-evolution": "closeout_and_self_evolution",
}


class RuntimeActivationError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class RuntimeActivation:
    def __init__(
        self,
        repo_root: Path | str,
        config_path: str = "config/cutover/runtime-family-activation.json",
    ) -> None:
        self.repo_root = Path(repo_root)
        self.config_path = config_path
        self._config: dict[str, Any] | None = None

    def load(self) -> dict[str, Any]:
        if self._config is not None:
            return self._config

        payload = self._load_json()
        if payload.get("schema_version") != "orchestra.full.v1":
            raise RuntimeActivationError("config_invalid", f"{self.config_path} must use schema_version=orchestra.full.v1")
        if payload.get("artifact_type") != "runtime_family_activation":
            raise RuntimeActivationError("config_invalid", f"{self.config_path} artifact_type must be runtime_family_activation")
        if payload.get("activation_policy_ref") != "config://cutover/full-readiness-gates":
            raise RuntimeActivationError("config_invalid", f"{self.config_path} activation_policy_ref must be config://cutover/full-readiness-gates")
        if payload.get("default_runtime_mode") != "mixed_family_cutover":
            raise RuntimeActivationError("config_invalid", f"{self.config_path} default_runtime_mode must be mixed_family_cutover")

        entries = payload.get("activated_families")
        if not isinstance(entries, list) or not entries:
            raise RuntimeActivationError("config_invalid", f"{self.config_path} activated_families must be a non-empty list")

        cutover = FullSchemaCutover(self.repo_root, allow_staged=True)
        activated: dict[str, dict[str, Any]] = {}
        for entry in entries:
            normalized = self._normalize_entry(entry)
            family_id = normalized["family_id"]
            if family_id in activated:
                raise RuntimeActivationError("config_invalid", f"{self.config_path} defines family {family_id} more than once")
            try:
                activation = cutover.can_activate(
                    family_id,
                    evidence=normalized["evidence"],
                    completed_checks=normalized["completed_checks"],
                )
            except StagedCutoverError as exc:
                raise RuntimeActivationError(exc.code, exc.message) from exc
            if activation["allowed"] is not True:
                raise RuntimeActivationError(
                    "activation_blocked",
                    f"{self.config_path} family {family_id} is missing evidence={activation['missing_evidence']} checks={activation['missing_checks']}",
                )
            activated[family_id] = {
                **normalized,
                "activation_scope": activation["activation_scope"],
                "rollback_policy": activation["rollback_policy"],
            }

        self._config = {
            **payload,
            "activated_family_index": activated,
        }
        return self._config

    def is_family_active(self, family_id: str) -> bool:
        return family_id in self.load()["activated_family_index"]

    def default_allow_staged(self, module: str) -> bool:
        family_id = MODULE_FAMILY_DEFAULTS.get(module)
        return bool(family_id and self.is_family_active(family_id))

    def summary(self) -> dict[str, Any]:
        config = self.load()
        activated = config["activated_family_index"]
        return {
            "config_ref": self.config_path,
            "default_runtime_mode": config["default_runtime_mode"],
            "active_family_ids": sorted(activated),
            "module_defaults": {
                module: family_id
                for module, family_id in MODULE_FAMILY_DEFAULTS.items()
                if family_id in activated
            },
        }

    def _normalize_entry(self, entry: Any) -> dict[str, Any]:
        if not isinstance(entry, dict):
            raise RuntimeActivationError("config_invalid", f"{self.config_path} activated_families entries must be objects")
        family_id = self._require_string(entry, "family_id")
        evidence = self._require_string_list(entry, "evidence")
        completed_checks = self._require_string_list(entry, "completed_checks")
        decision_ref = self._validate_decision_ref(family_id, self._require_string(entry, "decision_ref"))
        return {
            "family_id": family_id,
            "evidence": evidence,
            "completed_checks": completed_checks,
            "decision_ref": decision_ref,
        }

    def _validate_decision_ref(self, family_id: str, decision_ref: str) -> str:
        if not decision_ref.startswith("repo://"):
            raise RuntimeActivationError("config_invalid", f"{self.config_path} family {family_id} decision_ref must target repo://.workflow/knowledge/")
        repo_path = PurePosixPath(decision_ref.removeprefix("repo://"))
        if repo_path.is_absolute() or ".." in repo_path.parts or repo_path.parts[:2] != (".workflow", "knowledge"):
            raise RuntimeActivationError("config_invalid", f"{self.config_path} family {family_id} decision_ref must target repo://.workflow/knowledge/")
        return decision_ref

    def _load_json(self) -> dict[str, Any]:
        path = self.repo_root / self.config_path
        try:
            with path.open(encoding="utf-8") as handle:
                payload = json.load(handle)
        except FileNotFoundError as exc:
            raise RuntimeActivationError("config_invalid", f"{self.config_path} is missing") from exc
        except PermissionError as exc:
            raise RuntimeActivationError("config_invalid", f"{self.config_path} is not readable: {exc.strerror or exc}") from exc
        except json.JSONDecodeError as exc:
            raise RuntimeActivationError("config_invalid", f"{self.config_path} is not valid JSON: {exc.msg}") from exc
        if not isinstance(payload, dict):
            raise RuntimeActivationError("config_invalid", f"{self.config_path} must contain a JSON object")
        return payload

    def _require_string(self, payload: dict[str, Any], key: str) -> str:
        value = payload.get(key)
        if not isinstance(value, str) or not value:
            raise RuntimeActivationError("config_invalid", f"{self.config_path} entry {key} must be a non-empty string")
        return value

    def _require_string_list(self, payload: dict[str, Any], key: str) -> list[str]:
        value = payload.get(key)
        if not isinstance(value, list) or not value or not all(isinstance(item, str) and item for item in value):
            raise RuntimeActivationError("config_invalid", f"{self.config_path} entry {key} must be a non-empty string list")
        return list(value)
