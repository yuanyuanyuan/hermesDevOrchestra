from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import jsonschema


FULL_TARGET_CONTRACTS = [
    ("config/debate/full/teams.json", "debate_team_registry"),
    ("config/debate/full/modes.json", "debate_mode_registry"),
    ("config/debate/full/coverage-policy.json", "debate_coverage_policy"),
    ("config/debate/full/assembly-policy.json", "debate_assembly_policy"),
    ("config/debate/full/backend-policy.json", "debate_backend_policy"),
    ("config/workers/full/backends.json", "worker_backend_registry"),
    ("config/workers/full/roles.json", "worker_role_registry"),
    ("config/cutover/full-readiness-gates.json", "full_contract_readiness_gate_policy"),
]


class FullSchemaValidationError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class FullSchemaValidation:
    def __init__(
        self,
        repo_root: Path | str,
        schema_path: str = "config/schemas/orchestra.full.schema.json",
        allow_staged: bool = False,
        enabled: bool = True,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.schema_path = schema_path
        self.allow_staged = allow_staged
        self.enabled = enabled
        self._schema: dict[str, Any] | None = None

    def validate_schema(self) -> dict[str, Any]:
        self._require_enabled()
        schema = self._load_schema()
        try:
            jsonschema.Draft202012Validator.check_schema(schema)
        except Exception as exc:
            raise FullSchemaValidationError("schema_invalid", f"{self.schema_path} is not a valid Draft 2020-12 schema: {exc}") from exc
        return {
            "ok": True,
            "path": self.schema_path,
            "draft": "2020-12",
        }

    def validate_contract(self, rel_path: str, definition_name: str) -> dict[str, Any]:
        self._require_enabled()
        schema = self._load_schema()
        self.validate_schema()
        payload = self._load_json(rel_path)
        self._require_package_active(payload, rel_path)

        if definition_name not in schema.get("$defs", {}):
            raise FullSchemaValidationError("schema_invalid", f"{self.schema_path} is missing $defs/{definition_name}")

        try:
            jsonschema.validate(
                instance=payload,
                schema={
                    "$schema": schema["$schema"],
                    "$ref": f"#/$defs/{definition_name}",
                    "$defs": schema["$defs"],
                },
            )
        except jsonschema.ValidationError as exc:
            raise FullSchemaValidationError("schema_invalid", f"{rel_path} failed schema validation: {exc.message}") from exc

        return {
            "ok": True,
            "path": rel_path,
            "definition": definition_name,
            "artifact_type": payload.get("artifact_type"),
        }

    def validate_all(self) -> dict[str, Any]:
        schema_result = self.validate_schema()
        contract_results = [self.validate_contract(rel_path, definition_name) for rel_path, definition_name in FULL_TARGET_CONTRACTS]
        return {
            "ok": True,
            "schema": schema_result,
            "contracts": contract_results,
        }

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise FullSchemaValidationError("module_disabled", "full schema validation is disabled")

    def _load_schema(self) -> dict[str, Any]:
        if self._schema is None:
            self._schema = self._load_json(self.schema_path)
            if "$defs" not in self._schema:
                raise FullSchemaValidationError("schema_invalid", f"{self.schema_path} is missing $defs")
        return self._schema

    def _load_json(self, rel_path: str) -> dict[str, Any]:
        path = self.repo_root / rel_path
        try:
            with path.open(encoding="utf-8") as handle:
                payload = json.load(handle)
        except json.JSONDecodeError as exc:
            raise FullSchemaValidationError("schema_invalid", f"{rel_path} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise FullSchemaValidationError("schema_invalid", f"{rel_path} is missing") from exc
        except PermissionError as exc:
            raise FullSchemaValidationError("schema_invalid", f"{rel_path} is not readable: {exc.strerror or exc}") from exc
        if not isinstance(payload, dict):
            raise FullSchemaValidationError("schema_invalid", f"{rel_path} must contain a JSON object")
        return payload

    def _require_package_active(self, payload: dict[str, Any], rel_path: str) -> None:
        package_status = payload.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise FullSchemaValidationError("schema_invalid", f"{rel_path} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise FullSchemaValidationError(
                "package_not_active",
                f"{rel_path} package_status={package_status} is not active; allow_staged=True is required",
            )
