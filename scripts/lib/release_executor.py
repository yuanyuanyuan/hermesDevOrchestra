from __future__ import annotations

import hashlib
import json
import os
import re
import signal
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition
from release_pipeline import ReleasePipeline, ReleasePipelineError


_SECRET_PATTERNS = [
    re.compile(r"(?i)\b(secret|token|password|api[_-]?key)(\s*[:=]\s*|\s+)([^\s]+)"),
]
_ABSOLUTE_PATH_PATTERN = re.compile(r"(^|[\s=])(/[A-Za-z0-9._~/-]+)")


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
        runtime_env: dict[str, str] | None = None,
        artifact_root: Path | str | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self.runtime_env = dict(runtime_env or os.environ)
        self.artifact_root = Path(artifact_root) if artifact_root is not None else self.repo_root / ".release-artifacts"
        self.pipeline = ReleasePipeline(
            repo_root=self.repo_root,
            package_root=self.package_root,
            allow_staged=self.allow_staged,
            enabled=self.enabled,
        )

    def execute(
        self,
        command_ref: str,
        approval_ref: str | None = None,
        *,
        run_id: str = "release-executor-run",
        environment: str | None = None,
        test_execution_report_refs: list[str] | None = None,
        health_check_refs: list[str] | None = None,
        rollback_or_recovery_refs: list[str] | None = None,
        gate_results: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        if not self.enabled:
            raise ReleaseExecutorError("module_disabled", "release executor is disabled")
        if not isinstance(run_id, str) or not run_id:
            raise ReleaseExecutorError("validation_error", "run_id must be a non-empty string")

        if test_execution_report_refs is None:
            test_execution_report_refs = []
        if health_check_refs is None:
            health_check_refs = []
        if rollback_or_recovery_refs is None:
            rollback_or_recovery_refs = []
        if gate_results is None:
            gate_results = {}

        try:
            validation = self.pipeline.validate_command_refs()
            command = self.pipeline.get_command(command_ref)
            resolved_environment = environment or self.pipeline.resolve_environment(command_ref) or "unmapped"
        except ReleasePipelineError as exc:
            raise ReleaseExecutorError(exc.code, exc.message) from exc

        approval_checked = self._approval_required(command) or approval_ref is not None
        self._validate_approval(command, approval_ref)

        cwd = self._resolve_cwd(command["cwd_ref"])
        allowed_env = self._build_allowed_env(command["env_allowlist"])
        execution = self._run_process(
            argv=list(command["argv"]),
            cwd=cwd,
            env=allowed_env,
            timeout_seconds=int(command["timeout_seconds"]),
            kill_policy=dict(command["kill_policy"]),
        )

        stdout_text = self._redact_output(execution["stdout"], dict(command["redaction_policy"]), allowed_env)
        stderr_text = self._redact_output(execution["stderr"], dict(command["redaction_policy"]), allowed_env)
        stdout_ref, stdout_path = self._store_output(run_id, "stdout", stdout_text, command["output_capture_policy"]["store"])
        stderr_ref, stderr_path = self._store_output(run_id, "stderr", stderr_text, command["output_capture_policy"]["store"])

        report = self._build_report(
            run_id=run_id,
            environment=resolved_environment,
            command_ref=command_ref,
            command_registry_ref=str(validation["command_registry_ref"]),
            command=command,
            execution=execution,
            stdout_ref=stdout_ref,
            stderr_ref=stderr_ref,
            approval_checked=approval_checked,
            approval_ref=approval_ref,
            test_execution_report_refs=test_execution_report_refs,
            health_check_refs=health_check_refs,
            rollback_or_recovery_refs=rollback_or_recovery_refs,
            gate_results=gate_results,
        )

        self._validate_definition("deployment_report", report)
        return {
            "deployment_report": report,
            "stdout_path": str(stdout_path),
            "stderr_path": str(stderr_path),
            "allowed_env": allowed_env,
        }

    def _approval_required(self, command: dict[str, Any]) -> bool:
        policy = command["approval_policy"]
        return bool(policy.get("approval_refs_required_before_execution")) or policy.get("authority_required") != "none"

    def _validate_approval(self, command: dict[str, Any], approval_ref: str | None) -> None:
        policy = command["approval_policy"]
        approval_required = self._approval_required(command)
        if approval_required and (not isinstance(approval_ref, str) or not approval_ref):
            raise ReleaseExecutorError("approval_required", "approval_ref is required before execution")
        if approval_ref is not None and (not isinstance(approval_ref, str) or not approval_ref):
            raise ReleaseExecutorError("validation_error", "approval_ref must be a non-empty string")
        if policy.get("fixed_phrase_required") and approval_ref is not None and "fixed-phrase:" not in approval_ref:
            raise ReleaseExecutorError("approval_required", "approval_ref must include a fixed-phrase confirmation")

    def _resolve_cwd(self, cwd_ref: str) -> Path:
        if cwd_ref == "project://root":
            return self.repo_root
        raise ReleaseExecutorError("cwd_not_supported", f"unsupported cwd_ref: {cwd_ref}")

    def _build_allowed_env(self, allowlist: list[str]) -> dict[str, str]:
        return {key: self.runtime_env[key] for key in allowlist if key in self.runtime_env}

    def _run_process(
        self,
        *,
        argv: list[str],
        cwd: Path,
        env: dict[str, str],
        timeout_seconds: int,
        kill_policy: dict[str, Any],
    ) -> dict[str, Any]:
        started_at = self._timestamp()
        started_monotonic = time.monotonic()
        try:
            process = subprocess.Popen(
                argv,
                cwd=str(cwd),
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                shell=False,
            )
        except FileNotFoundError as exc:
            raise ReleaseExecutorError("execution_failed", f"command executable not found: {argv[0]}") from exc
        except OSError as exc:
            raise ReleaseExecutorError("execution_failed", f"command failed to start: {exc}") from exc

        timed_out = False
        stdout = ""
        stderr = ""
        try:
            stdout, stderr = process.communicate(timeout=timeout_seconds)
        except subprocess.TimeoutExpired as exc:
            timed_out = True
            stdout = self._coerce_text(exc.stdout)
            stderr = self._coerce_text(exc.stderr)
            self._send_signal(process, str(kill_policy["graceful_signal"]))
            try:
                more_stdout, more_stderr = process.communicate(timeout=int(kill_policy["graceful_timeout_seconds"]))
            except subprocess.TimeoutExpired as graceful_exc:
                stdout += self._coerce_text(graceful_exc.stdout)
                stderr += self._coerce_text(graceful_exc.stderr)
                process.kill()
                try:
                    more_stdout, more_stderr = process.communicate(timeout=max(1, int(kill_policy["force_timeout_seconds"])))
                except subprocess.TimeoutExpired:
                    more_stdout, more_stderr = "", ""
            stdout += self._coerce_text(more_stdout)
            stderr += self._coerce_text(more_stderr)

        finished_at = self._timestamp()
        duration_ms = max(0, int((time.monotonic() - started_monotonic) * 1000))
        return {
            "stdout": stdout,
            "stderr": stderr,
            "exit_code": None if timed_out else process.returncode,
            "timed_out": timed_out,
            "started_at": started_at,
            "finished_at": finished_at,
            "duration_ms": duration_ms,
        }

    def _send_signal(self, process: subprocess.Popen[str], signal_name: str) -> None:
        signal_value = getattr(signal, f"SIG{signal_name}", None)
        if signal_value is None:
            process.terminate()
            return
        try:
            process.send_signal(signal_value)
        except ProcessLookupError:
            return

    def _redact_output(self, text: str, redaction_policy: dict[str, Any], allowed_env: dict[str, str]) -> str:
        if not text or redaction_policy.get("enabled") is not True:
            return text

        redacted = text
        if redaction_policy.get("redact_env_not_in_allowlist"):
            for key, value in self.runtime_env.items():
                if key in allowed_env or not value:
                    continue
                redacted = redacted.replace(value, "[REDACTED_SECRET]")
        if redaction_policy.get("redact_secrets"):
            for pattern in _SECRET_PATTERNS:
                redacted = pattern.sub(lambda match: f"{match.group(1)}{match.group(2)}[REDACTED_SECRET]", redacted)
        if redaction_policy.get("redact_absolute_paths"):
            redacted = _ABSOLUTE_PATH_PATTERN.sub(lambda match: f"{match.group(1)}[REDACTED_PATH]", redacted)
        return redacted

    def _coerce_text(self, value: str | bytes | None) -> str:
        if value is None:
            return ""
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        return value

    def _store_output(self, run_id: str, stream_name: str, text: str, store: str) -> tuple[str, Path]:
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if store == "state_artifact":
            path = self.artifact_root / "state" / run_id / f"{stream_name}-{digest}.log"
            ref = f"state://runs/{run_id}/release/{stream_name}-{digest}.log"
        else:
            path = self.artifact_root / "cache" / digest / f"{stream_name}.log"
            ref = f"cache://sha256:{digest}"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return ref, path

    def _build_report(
        self,
        *,
        run_id: str,
        environment: str,
        command_ref: str,
        command_registry_ref: str,
        command: dict[str, Any],
        execution: dict[str, Any],
        stdout_ref: str,
        stderr_ref: str,
        approval_checked: bool,
        approval_ref: str | None,
        test_execution_report_refs: list[str],
        health_check_refs: list[str],
        rollback_or_recovery_refs: list[str],
        gate_results: dict[str, Any],
    ) -> dict[str, Any]:
        deployment_status = "timed_out"
        if not execution["timed_out"]:
            deployment_status = "succeeded" if execution["exit_code"] == 0 else "failed"

        argv_hash = hashlib.sha256(
            json.dumps(command["argv"], ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        ).hexdigest()
        return {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "deployment_report",
            "run_id": run_id,
            "environment": environment,
            "deployment_status": deployment_status,
            "command_ref": command_ref,
            "command_registry_ref": command_registry_ref,
            "executor": "gateway_release_executor",
            "approval_checked_before_execution": approval_checked,
            "argv_hash": f"sha256:{argv_hash}",
            "stdout_ref": stdout_ref,
            "stderr_ref": stderr_ref,
            "exit_code": execution["exit_code"],
            "started_at": execution["started_at"],
            "finished_at": execution["finished_at"],
            "duration_ms": execution["duration_ms"],
            "timeout_seconds": int(command["timeout_seconds"]),
            "timed_out": execution["timed_out"],
            "kill_policy": dict(command["kill_policy"]),
            "health_check_refs": list(health_check_refs),
            "gate_results": {
                "approval_checked": approval_checked,
                "approval_ref_present": approval_ref is not None,
                **gate_results,
            },
            "test_execution_report_refs": list(test_execution_report_refs),
            "approval_refs": [approval_ref] if approval_ref is not None else [],
            "rollback_or_recovery_refs": list(rollback_or_recovery_refs),
            "created_at": self._timestamp(),
        }

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise ReleaseExecutorError("report_invalid", exc.message) from exc
