from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


_COMMAND_REF_PATTERN = re.compile(r"^command://release/[A-Za-z0-9._-]+$")
_ALLOWED_ENV_VARS = {"PATH", "HOME", "CI", "HERMES_RELEASE_ENV"}
_SHELL_LAUNCHERS = {"bash", "sh", "zsh", "fish", "dash", "ksh", "cmd.exe", "powershell", "pwsh"}


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

    def load_pipeline(self) -> dict[str, Any]:
        self._require_enabled()
        if self._pipeline is not None:
            return self._pipeline

        data = self._load_json("pipeline.json")
        self._validate_definition("release_pipeline_config", data)
        if data.get("enabled") is not True and not self.allow_staged:
            raise ReleasePipelineError(
                "module_disabled",
                "pipeline.json is disabled; allow_staged=True is required",
            )

        environments = self._require_list(data, "environments", "pipeline.json")
        if not environments:
            raise ReleasePipelineError("empty_config", "pipeline.json environments must not be empty")

        environment_index: dict[str, dict[str, Any]] = {}
        for environment in environments:
            environment_id = self._require_string(environment, "id", "environment")
            if environment_id in environment_index:
                raise ReleasePipelineError("config_invalid", f"environment {environment_id} is defined more than once")
            environment_index[environment_id] = environment

        gates = data.get("gates")
        if not isinstance(gates, dict):
            raise ReleasePipelineError("config_invalid", "pipeline.json gates must be an object")
        required_gates = {
            "pre_deploy_checks",
            "staging_validation",
            "uat",
            "production_approval",
            "post_deploy_validation",
        }
        missing_gates = sorted(required_gates - set(gates))
        if missing_gates:
            raise ReleasePipelineError("config_invalid", f"pipeline.json is missing gates: {missing_gates}")

        commands = data.get("commands")
        if not isinstance(commands, dict) or not commands:
            raise ReleasePipelineError("config_invalid", "pipeline.json commands must be a non-empty object")

        evidence_requirements = data.get("evidence_requirements")
        if not isinstance(evidence_requirements, dict):
            raise ReleasePipelineError("config_invalid", "pipeline.json evidence_requirements must be an object")
        required_evidence = {
            "deployment_report_ref",
            "test_execution_report_refs",
            "uat_decision_ref",
            "approval_refs",
            "rollback_or_recovery_refs",
        }
        missing_evidence = sorted(required_evidence - set(evidence_requirements))
        if missing_evidence:
            raise ReleasePipelineError("config_invalid", f"pipeline.json is missing evidence requirements: {missing_evidence}")

        self._pipeline = {**data, "environment_index": environment_index}
        return self._pipeline

    def load_registry(self) -> dict[str, Any]:
        self._require_enabled()
        if self._registry is not None:
            return self._registry

        data = self._load_json("commands.json")
        self._validate_definition("release_command_registry", data)
        self._require_package_active(data, "commands.json")
        if data.get("enabled") is not True and not self.allow_staged:
            raise ReleasePipelineError(
                "module_disabled",
                "commands.json is disabled; allow_staged=True is required",
            )

        commands = self._require_list(data, "commands", "commands.json")
        if not commands:
            raise ReleasePipelineError("empty_config", "commands.json commands must not be empty")

        command_index: dict[str, dict[str, Any]] = {}
        for command in commands:
            command_ref = self._require_string(command, "command_ref", "command entry")
            if command_ref in command_index:
                raise ReleasePipelineError("config_invalid", f"command {command_ref} is defined more than once")
            command_index[command_ref] = command

        self._registry = {**data, "command_index": command_index}
        return self._registry

    def validate_command_refs(self) -> dict[str, Any]:
        pipeline = self.load_pipeline()
        registry = self.load_registry()

        if registry.get("arbitrary_shell_allowed") is not False:
            raise ReleasePipelineError("unsafe_registry", "commands.json must set arbitrary_shell_allowed to false")

        for command_ref, command in sorted(registry["command_index"].items()):
            self._validate_command_ref(command_ref)
            self._validate_command_entry(command_ref, command)

        referenced_command_refs = set(pipeline["commands"].values())
        referenced_command_refs.add(pipeline["rollback_policy"]["rollback_command_ref"])
        for environment in pipeline["environments"]:
            referenced_command_refs.add(environment["deploy_command_ref"])

        validated_refs: list[str] = []
        for command_ref in sorted(referenced_command_refs):
            self._validate_command_ref(command_ref)
            command = registry["command_index"].get(command_ref)
            if command is None:
                raise ReleasePipelineError("command_ref_not_found", f"command ref is not registered: {command_ref}")
            validated_refs.append(command_ref)

        return {
            "command_registry_ref": pipeline["command_registry_ref"],
            "validated_command_refs": validated_refs,
            "environment_ids": sorted(pipeline["environment_index"]),
        }

    def plan(self, environment: str) -> dict[str, Any]:
        if not isinstance(environment, str) or not environment:
            raise ReleasePipelineError("validation_error", "environment must be a non-empty string")

        pipeline = self.load_pipeline()
        registry = self.load_registry()
        self.validate_command_refs()

        environment_entry = pipeline["environment_index"].get(environment)
        if environment_entry is None:
            raise ReleasePipelineError("environment_not_found", f"unknown release environment: {environment}")

        deploy_command_ref = environment_entry["deploy_command_ref"]
        deploy_command = registry["command_index"][deploy_command_ref]
        rollback_ref = pipeline["rollback_policy"]["rollback_command_ref"]
        rollback_command = registry["command_index"][rollback_ref]
        return {
            "environment": environment_entry,
            "deploy_command": deploy_command,
            "rollback_command": rollback_command,
            "command_registry_ref": pipeline["command_registry_ref"],
            "approval_policy": pipeline["approval_policy"],
            "gates": pipeline["gates"],
            "evidence_requirements": pipeline["evidence_requirements"],
        }

    def get_command(self, command_ref: str) -> dict[str, Any]:
        self._validate_command_ref(command_ref)
        registry = self.load_registry()
        command = registry["command_index"].get(command_ref)
        if command is None:
            raise ReleasePipelineError("command_ref_not_found", f"command ref is not registered: {command_ref}")
        self._validate_command_entry(command_ref, command)
        return command

    def resolve_environment(self, command_ref: str) -> str | None:
        pipeline = self.load_pipeline()
        for environment in pipeline["environments"]:
            if environment["deploy_command_ref"] == command_ref:
                return str(environment["id"])
        if pipeline["rollback_policy"]["rollback_command_ref"] == command_ref:
            return "rollback"
        return None

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise ReleasePipelineError("module_disabled", "release pipeline is disabled")

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

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise ReleasePipelineError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise ReleasePipelineError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _require_list(self, data: dict[str, Any], key: str, label: str) -> list[dict[str, Any]]:
        value = data.get(key)
        if not isinstance(value, list):
            raise ReleasePipelineError("config_invalid", f"{label} {key} must be a list")
        return value

    def _require_string(self, data: dict[str, Any], key: str, label: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise ReleasePipelineError("config_invalid", f"{label} is missing {key}")
        return value

    def _validate_command_ref(self, command_ref: str) -> None:
        if not isinstance(command_ref, str) or not _COMMAND_REF_PATTERN.fullmatch(command_ref):
            raise ReleasePipelineError("command_ref_invalid", f"invalid release command ref: {command_ref!r}")

    def _validate_command_entry(self, command_ref: str, command: dict[str, Any]) -> None:
        if command.get("enabled") is not True:
            raise ReleasePipelineError("command_disabled", f"command is disabled: {command_ref}")

        argv = command.get("argv")
        if not isinstance(argv, list) or not argv or not all(isinstance(item, str) and item for item in argv):
            raise ReleasePipelineError("config_invalid", f"{command_ref} argv must be a non-empty list of strings")
        if argv[0] in _SHELL_LAUNCHERS:
            raise ReleasePipelineError("unsafe_command", f"{command_ref} uses a forbidden shell launcher")

        cwd_ref = command.get("cwd_ref")
        if not isinstance(cwd_ref, str) or not cwd_ref.startswith("project://") or ".." in cwd_ref:
            raise ReleasePipelineError("unsafe_command", f"{command_ref} has an invalid cwd_ref")

        env_allowlist = command.get("env_allowlist")
        if not isinstance(env_allowlist, list) or not env_allowlist:
            raise ReleasePipelineError("config_invalid", f"{command_ref} env_allowlist must be a non-empty list")
        unknown_env = [item for item in env_allowlist if item not in _ALLOWED_ENV_VARS]
        if unknown_env:
            raise ReleasePipelineError("unsafe_command", f"{command_ref} env_allowlist includes forbidden vars: {unknown_env}")

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise ReleasePipelineError("config_invalid", exc.message) from exc
