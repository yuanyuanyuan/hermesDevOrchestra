from __future__ import annotations

import hashlib
import json
import os
import re
import signal
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition
from release_pipeline import ReleasePipeline, ReleasePipelineError


class ReleaseExecutorError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class ReleaseExecutor:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/release",
        allow_staged: bool = False,
        enabled: bool = True,
        project_root: Path | str | None = None,
        env: dict[str, str] | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.project_root = Path(project_root) if project_root is not None else self.repo_root
        self.base_env = dict(env or os.environ)
        self.pipeline = ReleasePipeline(
            self.repo_root,
            package_root=package_root,
            allow_staged=allow_staged,
            enabled=enabled,
        )

    def execute(self, command_ref: str, approval_ref: str | None = None) -> dict[str, Any]:
        self._validate_command_ref(command_ref)
        try:
            pipeline = self.pipeline._load_pipeline()
            registry = self.pipeline._load_registry()
            resolved_commands = self.pipeline.validate_command_refs()["resolved_commands"]
        except ReleasePipelineError as exc:
            raise ReleaseExecutorError(exc.code, exc.message) from exc

        command = resolved_commands.get(command_ref)
        if command is None:
            raise ReleaseExecutorError("command_not_registered", f"{command_ref} is not registered")

        approval_policy = dict(command["approval_policy"])
        if approval_policy.get("approval_refs_required_before_execution") and not approval_ref:
            raise ReleaseExecutorError("approval_required", f"{command_ref} requires approval_ref before execution")

        environment_entry = self._find_environment_entry(pipeline, command_ref)
        filtered_env = self._filtered_env(command["env_allowlist"])
        cwd = self._resolve_cwd(command["cwd_ref"])
        started_at = self._timestamp()
        started_monotonic = datetime.now(timezone.utc)
        termination_sequence: list[str] = []

        try:
            process = subprocess.Popen(
                list(command["argv"]),
                cwd=str(cwd),
                env=filtered_env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                shell=False,
            )
        except OSError as exc:
            raise ReleaseExecutorError("execution_failed", f"{command_ref} failed to start: {exc.strerror or exc}") from exc

        timed_out = False
        stdout_text = ""
        stderr_text = ""
        timeout_seconds = int(command["timeout_seconds"])
        kill_policy = dict(command["kill_policy"])
        try:
            stdout_text, stderr_text = process.communicate(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            timed_out = True
            graceful_signal = str(kill_policy["graceful_signal"])
            termination_sequence.append(graceful_signal)
            self._send_signal(process, graceful_signal)
            graceful_timeout = int(kill_policy["graceful_timeout_seconds"])
            try:
                process.wait(timeout=graceful_timeout if graceful_timeout > 0 else 0.01)
            except subprocess.TimeoutExpired:
                termination_sequence.append(str(kill_policy["force_signal"]))
                process.kill()
                force_timeout = int(kill_policy["force_timeout_seconds"])
                try:
                    process.wait(timeout=force_timeout if force_timeout > 0 else 0.01)
                except subprocess.TimeoutExpired:
                    process.kill()
            stdout_text, stderr_text = process.communicate()

        finished_at = self._timestamp()
        duration_ms = max(0, int((datetime.now(timezone.utc) - started_monotonic).total_seconds() * 1000))

        stdout_redacted, stdout_findings = self._redact_output(stdout_text, command["env_allowlist"])
        stderr_redacted, stderr_findings = self._redact_output(stderr_text, command["env_allowlist"])
        secret_scan_status = "findings_redacted" if stdout_findings or stderr_findings else "clear"

        stdout_ref = self._cache_ref(stdout_redacted)
        stderr_ref = self._cache_ref(stderr_redacted)
        deployment_status = "timed_out" if timed_out else ("succeeded" if process.returncode == 0 else "failed")
        approval_refs = [approval_ref] if approval_ref else []

        report = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "deployment_report",
            "run_id": f"release-{environment_entry['id']}",
            "environment": environment_entry["id"],
            "deployment_status": deployment_status,
            "command_ref": command_ref,
            "command_registry_ref": pipeline["command_registry_ref"],
            "executor": "gateway_release_executor",
            "approval_checked_before_execution": True,
            "argv_hash": self._argv_hash(command["argv"]),
            "stdout_ref": stdout_ref,
            "stderr_ref": stderr_ref,
            "exit_code": process.returncode,
            "started_at": started_at,
            "finished_at": finished_at,
            "duration_ms": duration_ms,
            "timeout_seconds": timeout_seconds,
            "timed_out": timed_out,
            "kill_policy": kill_policy,
            "health_check_refs": list(environment_entry.get("health_check_refs", [])),
            "gate_results": self._gate_results(pipeline),
            "test_execution_report_refs": [],
            "approval_refs": approval_refs,
            "rollback_or_recovery_refs": [],
            "created_at": finished_at,
        }

        self._validate_definition("deployment_report", report)

        return {
            "deployment_report": report,
            "stored_outputs": {
                stdout_ref: stdout_redacted,
                stderr_ref: stderr_redacted,
            },
            "secret_scan_status": secret_scan_status,
            "shell_used": False,
            "termination_sequence": termination_sequence,
            "registry_authority": registry["registry_authority"],
        }

    def _validate_command_ref(self, command_ref: str) -> None:
        if not isinstance(command_ref, str) or not re.fullmatch(r"command://release/[a-z0-9-]+", command_ref):
            raise ReleaseExecutorError("command_ref_invalid", "command_ref must match command://release/<id>")
        if ".." in command_ref or ";" in command_ref:
            raise ReleaseExecutorError("command_ref_invalid", "command_ref must not contain traversal or shell metacharacters")

    def _find_environment_entry(self, pipeline: dict[str, Any], command_ref: str) -> dict[str, Any]:
        for entry in pipeline["environments"]:
            if entry.get("deploy_command_ref") == command_ref:
                return entry
        return {"id": command_ref.rsplit("/", 1)[-1], "health_check_refs": []}

    def _filtered_env(self, allowlist: list[str]) -> dict[str, str]:
        if not isinstance(allowlist, list) or not all(isinstance(item, str) and item for item in allowlist):
            raise ReleaseExecutorError("config_invalid", "env_allowlist must be a list of non-empty strings")
        filtered: dict[str, str] = {}
        for key in allowlist:
            if key in self.base_env:
                filtered[key] = self.base_env[key]
        return filtered

    def _resolve_cwd(self, cwd_ref: str) -> Path:
        if cwd_ref == "project://root":
            return self.project_root
        if not isinstance(cwd_ref, str) or not cwd_ref.startswith("project://root/"):
            raise ReleaseExecutorError("cwd_ref_invalid", "cwd_ref must stay under project://root")
        relative = cwd_ref.removeprefix("project://root/")
        parts = Path(relative).parts
        if any(part in ("..", "") for part in parts):
            raise ReleaseExecutorError("cwd_ref_invalid", "cwd_ref must not contain path traversal")
        return self.project_root / relative

    def _send_signal(self, process: subprocess.Popen[str], signal_name: str) -> None:
        if signal_name == "INT":
            process.send_signal(signal.SIGINT)
            return
        process.terminate()

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _argv_hash(self, argv: list[str]) -> str:
        payload = json.dumps(list(argv), separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        return f"sha256:{hashlib.sha256(payload).hexdigest()}"

    def _cache_ref(self, text: str) -> str:
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        return f"cache://sha256:{digest}"

    def _gate_results(self, pipeline: dict[str, Any]) -> dict[str, Any]:
        results: dict[str, Any] = {}
        gates = pipeline.get("gates", {})
        if isinstance(gates, dict):
            for gate_name, gate in gates.items():
                required = bool(gate.get("required")) if isinstance(gate, dict) else False
                results[gate_name] = {"required": required, "status": "not_run"}
        return results

    def _redact_output(self, text: str, allowlist: list[str]) -> tuple[str, bool]:
        redacted = text
        findings = False

        for key, value in self.base_env.items():
            if key in allowlist:
                continue
            if value and value in redacted:
                redacted = redacted.replace(value, f"[REDACTED_ENV:{key}]")
                findings = True

        secret_pattern = re.compile(r"(?im)\b(api[_-]?token|token|password|secret|api[_-]?key)=([^\s]+)")

        def replace_secret(match: re.Match[str]) -> str:
            nonlocal findings
            findings = True
            return f"{match.group(1)}=[REDACTED_SECRET]"

        redacted = secret_pattern.sub(replace_secret, redacted)

        project_root_text = str(self.project_root)
        if project_root_text and project_root_text in redacted:
            redacted = redacted.replace(project_root_text, "[REDACTED_PATH]")
            findings = True

        absolute_path_pattern = re.compile(r"(?<![A-Za-z0-9_])/(?:[^\s/]+/)*[^\s/]+")

        def replace_path(match: re.Match[str]) -> str:
            nonlocal findings
            findings = True
            return "[REDACTED_PATH]"

        redacted = absolute_path_pattern.sub(replace_path, redacted)
        return redacted, findings

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise ReleaseExecutorError("schema_invalid", exc.message) from exc
