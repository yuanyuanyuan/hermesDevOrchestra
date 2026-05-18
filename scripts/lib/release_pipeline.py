from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


class ReleasePipelineError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class ReleasePipeline:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/release",
        allow_staged: bool = False,
        enabled: bool = True,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self._pipeline: dict[str, Any] | None = None
        self._registry: dict[str, Any] | None = None

    def plan(self, environment: str) -> dict[str, Any]:
        if not isinstance(environment, str) or not environment:
            raise ReleasePipelineError("validation_error", "environment must be a non-empty string")

        pipeline = self._load_pipeline()
        registry = self._load_registry()
        environment_entry = self._find_environment(pipeline, environment)
        resolved_commands = self._resolved_commands(pipeline, registry)
        command_ref = self._require_string(environment_entry, "deploy_command_ref", f"environment {environment}")
        command = resolved_commands.get(command_ref)
        if command is None:
            raise ReleasePipelineError("command_not_registered", f"{command_ref} is not registered")

        return {
            "environment": environment_entry,
            "command": command,
            "command_ref": command_ref,
            "command_registry_ref": pipeline["command_registry_ref"],
            "approval_required": bool(environment_entry.get("requires_approval") or command["approval_policy"]["approval_refs_required_before_execution"]),
            "health_check_refs": list(environment_entry.get("health_check_refs", [])),
            "gate_names": sorted(pipeline["gates"].keys()),
        }

    def validate_command_refs(self) -> dict[str, Any]:
        pipeline = self._load_pipeline()
        registry = self._load_registry()
        resolved_commands = self._resolved_commands(pipeline, registry)
        return {
            "command_registry_ref": pipeline["command_registry_ref"],
            "environment_command_refs": sorted({env["deploy_command_ref"] for env in pipeline["environments"]}),
            "resolved_commands": resolved_commands,
        }

    def _load_pipeline(self) -> dict[str, Any]:
        self._require_enabled()
        if self._pipeline is not None:
            return self._pipeline
        data = self._load_json("pipeline.json")
        self._require_config_enabled(data, "pipeline.json")
        self._validate_definition("release_pipeline_config", data)

        environments = data.get("environments")
        if not isinstance(environments, list) or not environments:
            raise ReleasePipelineError("config_invalid", "pipeline.json environments must be a non-empty list")
        gates = data.get("gates")
        if not isinstance(gates, dict) or not gates:
            raise ReleasePipelineError("config_invalid", "pipeline.json gates must be a non-empty object")
        commands = data.get("commands")
        if not isinstance(commands, dict) or not commands:
            raise ReleasePipelineError("config_invalid", "pipeline.json commands must be a non-empty object")
        command_registry_ref = data.get("command_registry_ref")
        if command_registry_ref != "config://release/commands":
            raise ReleasePipelineError("config_invalid", "pipeline.json command_registry_ref must be config://release/commands")

        self._pipeline = data
        return self._pipeline

    def _load_registry(self) -> dict[str, Any]:
        self._require_enabled()
        if self._registry is not None:
            return self._registry
        data = self._load_json("commands.json")
        self._require_config_enabled(data, "commands.json")
        self._require_package_active(data, "commands.json")
        self._validate_definition("release_command_registry", data)

        commands = data.get("commands")
        if not isinstance(commands, list) or not commands:
            raise ReleasePipelineError("config_invalid", "commands.json commands must be a non-empty list")

        command_index: dict[str, dict[str, Any]] = {}
        for entry in commands:
            command_ref = self._require_string(entry, "command_ref", "command entry")
            if command_ref in command_index:
                raise ReleasePipelineError("config_invalid", f"command {command_ref} is defined more than once")
            command_index[command_ref] = entry

        self._registry = {**data, "command_index": command_index}
        return self._registry

    def _resolved_commands(
        self,
        pipeline: dict[str, Any],
        registry: dict[str, Any],
    ) -> dict[str, dict[str, Any]]:
        command_index = registry["command_index"]
        resolved_commands: dict[str, dict[str, Any]] = {}
        for command_ref in self._collect_pipeline_command_refs(pipeline):
            command = command_index.get(command_ref)
            if command is None:
                raise ReleasePipelineError("command_not_registered", f"{command_ref} is not registered")
            resolved_commands[command_ref] = command
        return resolved_commands

    def _collect_pipeline_command_refs(self, pipeline: dict[str, Any]) -> list[str]:
        refs: list[str] = []
        for environment in pipeline["environments"]:
            deploy_command_ref = self._require_string(environment, "deploy_command_ref", "environment entry")
            if deploy_command_ref not in refs:
                refs.append(deploy_command_ref)

        commands = pipeline.get("commands", {})
        for key in sorted(commands):
            command_ref = self._require_string(commands, key, f"pipeline commands[{key}]")
            if command_ref not in refs:
                refs.append(command_ref)

        rollback_policy = pipeline.get("rollback_policy", {})
        rollback_ref = rollback_policy.get("rollback_command_ref")
        if rollback_ref is not None:
            rollback_ref = self._require_string(rollback_policy, "rollback_command_ref", "rollback policy")
            if rollback_ref not in refs:
                refs.append(rollback_ref)
        return refs

    def _find_environment(self, pipeline: dict[str, Any], environment: str) -> dict[str, Any]:
        for entry in pipeline["environments"]:
            if entry.get("id") == environment:
                return entry
        raise ReleasePipelineError("environment_not_found", f"unknown release environment: {environment}")

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise ReleasePipelineError("module_disabled", "release pipeline is disabled")

    def _require_config_enabled(self, data: dict[str, Any], filename: str) -> None:
        if data.get("enabled") is not True:
            raise ReleasePipelineError("module_disabled", f"{filename} is disabled")

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise ReleasePipelineError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise ReleasePipelineError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise ReleasePipelineError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise ReleasePipelineError("config_invalid", f"{filename} is missing") from exc
        except PermissionError as exc:
            raise ReleasePipelineError("config_invalid", f"{filename} is not readable: {exc.strerror or exc}") from exc
        if not isinstance(data, dict):
            raise ReleasePipelineError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _require_string(self, data: dict[str, Any], key: str, label: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise ReleasePipelineError("config_invalid", f"{label} is missing {key}")
        return value

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise ReleasePipelineError("config_invalid", exc.message) from exc
