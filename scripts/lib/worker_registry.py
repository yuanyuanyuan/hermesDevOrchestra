from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


class WorkerRegistryError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class WorkerRegistry:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/workers/full",
        allow_staged: bool = False,
        enabled: bool = True,
        availability_overrides: dict[str, dict[str, Any]] | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self.availability_overrides = availability_overrides or {}
        self._backends: dict[str, Any] | None = None
        self._roles: dict[str, Any] | None = None

    def load_backends(self) -> dict[str, Any]:
        self._require_enabled()
        if self._backends is not None:
            return self._backends
        data = self._load_json("backends.json")
        self._require_package_active(data, "backends.json")
        self._validate_definition("worker_backend_registry", data)

        backends = self._require_list(data, "backends", "backends.json")
        if not backends:
            raise WorkerRegistryError("empty_registry", "backends registry must not be empty")

        backend_index: dict[str, dict[str, Any]] = {}
        for backend in backends:
            backend_id = self._require_string(backend, "id", "backend entry")
            if backend_id in backend_index:
                raise WorkerRegistryError("config_invalid", f"backend {backend_id} is defined more than once")
            backend_index[backend_id] = backend

        self._backends = {**data, "backend_index": backend_index}
        return self._backends

    def load_roles(self) -> dict[str, Any]:
        self._require_enabled()
        if self._roles is not None:
            return self._roles
        data = self._load_json("roles.json")
        self._require_package_active(data, "roles.json")
        self._validate_definition("worker_role_registry", data)

        roles = self._require_list(data, "roles", "roles.json")
        if not roles:
            raise WorkerRegistryError("empty_registry", "roles registry must not be empty")

        role_index: dict[str, dict[str, Any]] = {}
        for role in roles:
            role_id = self._require_string(role, "role", "role entry")
            if role_id in role_index:
                raise WorkerRegistryError("config_invalid", f"role {role_id} is defined more than once")
            role_index[role_id] = role

        self._roles = {**data, "role_index": role_index}
        return self._roles

    def get_backend(self, backend_id: str) -> dict[str, Any]:
        backend = self.load_backends()["backend_index"].get(backend_id)
        if backend is None:
            raise WorkerRegistryError("backend_not_found", f"unknown backend: {backend_id}")
        return backend

    def get_role(self, role: str) -> dict[str, Any]:
        role_entry = self.load_roles()["role_index"].get(role)
        if role_entry is None:
            raise WorkerRegistryError("role_not_found", f"unknown role: {role}")
        return role_entry

    def backend_availability(self, backend_id: str) -> dict[str, Any]:
        backend = self.get_backend(backend_id)
        reasons: list[str] = []
        if not backend.get("enabled", False):
            reasons.append("backend_disabled")

        override = self.availability_overrides.get(backend_id)
        if override is not None:
            override_reasons = self._normalize_string_list(override.get("reasons", []), f"{backend_id} availability override")
            if not override.get("available", False) and not override_reasons:
                override_reasons = ["availability_override_blocked"]
            reasons.extend(override_reasons)
            return {"available": not reasons and bool(override.get("available", False)), "reasons": reasons}

        install_check = backend.get("install_check", {})
        executable = None
        if install_check.get("kind") == "executable_on_path":
            executable = install_check.get("executable")
            if not isinstance(executable, str) or not executable:
                reasons.append("install_check_invalid")
            elif shutil.which(executable) is None:
                reasons.append("install_check_failed")

        health_check = backend.get("health_check", {})
        if not reasons and health_check.get("kind") == "command_probe":
            timeout_seconds = health_check.get("timeout_seconds", 5)
            if executable is None:
                reasons.append("health_check_missing_executable")
            else:
                try:
                    completed = subprocess.run(
                        [executable, "--version"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=timeout_seconds,
                        check=False,
                    )
                except (OSError, subprocess.TimeoutExpired):
                    reasons.append("health_check_failed")
                else:
                    if completed.returncode != 0:
                        reasons.append("health_check_failed")

        return {"available": not reasons, "reasons": reasons}

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise WorkerRegistryError("module_disabled", "worker registry is disabled")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise WorkerRegistryError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise WorkerRegistryError("config_invalid", f"{filename} is missing") from exc
        except PermissionError as exc:
            raise WorkerRegistryError("config_invalid", f"{filename} is not readable: {exc.strerror or exc}") from exc
        if not isinstance(data, dict):
            raise WorkerRegistryError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise WorkerRegistryError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise WorkerRegistryError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _require_list(self, data: dict[str, Any], key: str, label: str) -> list[dict[str, Any]]:
        value = data.get(key)
        if not isinstance(value, list):
            raise WorkerRegistryError("config_invalid", f"{label} {key} must be a list")
        return value

    def _require_string(self, data: dict[str, Any], key: str, label: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise WorkerRegistryError("config_invalid", f"{label} is missing {key}")
        return value

    def _normalize_string_list(self, value: Any, label: str) -> list[str]:
        if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
            raise WorkerRegistryError("config_invalid", f"{label} must be a list of non-empty strings")
        return list(value)

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise WorkerRegistryError("config_invalid", exc.message) from exc
