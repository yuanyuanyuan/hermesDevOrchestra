from __future__ import annotations

import json
import os
import re
import secrets
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from debate_report import DebateReportError, validate_artifact_definition


class WorkerSessionError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


ACTIVE_SESSION_STATUSES = frozenset({"starting", "running", "stopping"})
TERMINAL_SESSION_STATUSES = frozenset({"completed", "failed", "timed_out", "abandoned"})


class WorkerSessionManager:
    ACTIVE_STATUSES = ACTIVE_SESSION_STATUSES
    TERMINAL_STATUSES = TERMINAL_SESSION_STATUSES
    ALLOWED_TRANSITIONS = {
        "planned": {"starting", "abandoned"},
        "starting": {"running", "failed", "timed_out", "abandoned"},
        "running": {"stopping", "completed", "failed", "timed_out", "abandoned"},
        "stopping": {"completed", "failed", "timed_out", "abandoned"},
        "completed": set(),
        "failed": set(),
        "timed_out": set(),
        "abandoned": set(),
    }

    def __init__(
        self,
        repo_root: Path | str,
        clock: Callable[[], datetime] | None = None,
        suffix_factory: Callable[[], str] | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self._clock = clock or (lambda: datetime.now(timezone.utc))
        self._suffix_factory = suffix_factory or (lambda: secrets.token_hex(6))

    def create_session(
        self,
        *,
        run_id: str,
        task_id: str,
        role: str,
        backend_id: str,
        workspace_root: Path | str,
        write_scope_ref: str,
        context_bundle_ref: str,
        timeout_seconds: int,
        transcript_ref: str | None = None,
        output_envelope_ref: str | None = None,
    ) -> dict[str, Any]:
        self._require_string(run_id, "run_id")
        self._require_string(task_id, "task_id")
        self._require_string(role, "role")
        self._require_string(backend_id, "backend_id")
        self._require_state_ref(write_scope_ref, "write_scope_ref")
        self._require_state_ref(context_bundle_ref, "context_bundle_ref")
        if not isinstance(timeout_seconds, int) or timeout_seconds < 1:
            raise WorkerSessionError("validation_error", "timeout_seconds must be an integer >= 1")

        suffix = self._normalize_suffix(self._suffix_factory())
        session_id = f"{self._slug(run_id)}-{self._slug(task_id)}-{suffix}"
        tmux_socket_name = f"hermes-worker-{suffix}"
        workspace_path = Path(workspace_root) / session_id
        workspace_path.mkdir(parents=True, exist_ok=False)
        os.chmod(workspace_path, 0o700)

        try:
            now = self._now()
            record = {
                "schema_version": "orchestra.full.v1",
                "artifact_type": "worker_session_record",
                "session_id": session_id,
                "run_id": run_id,
                "task_id": task_id,
                "role": role,
                "backend_id": backend_id,
                "workspace_ref": f"state://runs/{run_id}/worker-workspaces/{session_id}.json",
                "write_scope_ref": write_scope_ref,
                "context_bundle_ref": context_bundle_ref,
                "started_at": now,
                "ended_at": None,
                "status": "planned",
                "exit_signal": None,
                "transcript_ref": transcript_ref or f"state://runs/{run_id}/worker-transcripts/{session_id}.log",
                "output_envelope_ref": output_envelope_ref,
                "cleanup_owner": "gateway_worker_session_sweeper",
                "cleanup_status": "not_started",
                "timeout_seconds": timeout_seconds,
                "last_heartbeat_at": None,
                "termination_reason": None,
                "workspace_path": str(workspace_path),
                "tmux_session_name": session_id,
                "tmux_socket_name": tmux_socket_name,
                "tmux_launch_args": ["-L", tmux_socket_name, "new-session", "-d", "-s", session_id],
                "cleanup_attempted_at": None,
                "cleanup_error": None,
            }
            self.validate_record(record)
            return record
        except Exception:
            shutil.rmtree(workspace_path, ignore_errors=True)
            raise

    def transition(
        self,
        record: dict[str, Any],
        next_status: str,
        *,
        exit_signal: str | None = None,
        output_envelope_ref: str | None = None,
        cleanup_status: str | None = None,
        termination_reason: str | None = None,
    ) -> dict[str, Any]:
        current_status = record.get("status")
        if current_status not in self.ALLOWED_TRANSITIONS:
            raise WorkerSessionError("record_invalid", f"unknown current status: {current_status}")
        if next_status not in self.ALLOWED_TRANSITIONS[current_status]:
            raise WorkerSessionError("invalid_transition", f"{current_status} cannot transition to {next_status}")

        updated = dict(record)
        updated["status"] = next_status
        if exit_signal is not None:
            updated["exit_signal"] = exit_signal
        if output_envelope_ref is not None:
            updated["output_envelope_ref"] = output_envelope_ref
        if cleanup_status is not None:
            updated["cleanup_status"] = cleanup_status
        if termination_reason is not None:
            updated["termination_reason"] = termination_reason
        if next_status in self.TERMINAL_STATUSES:
            updated["ended_at"] = self._now()
        self.validate_record(updated)
        return updated

    def record_heartbeat(self, record: dict[str, Any]) -> dict[str, Any]:
        if record.get("status") not in self.ACTIVE_STATUSES:
            raise WorkerSessionError("invalid_transition", "heartbeat is only allowed for active sessions")
        updated = dict(record)
        updated["last_heartbeat_at"] = self._now()
        self.validate_record(updated)
        return updated

    def persist_record(self, record: dict[str, Any], records_root: Path | str) -> Path:
        self.validate_record(record)
        records_path = Path(records_root)
        records_path.mkdir(parents=True, exist_ok=True)
        target = records_path / f"{record['session_id']}.json"
        self.write_record(target, record)
        return target

    def write_record(self, path: Path | str, record: dict[str, Any]) -> None:
        self.validate_record(record)
        target = Path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def load_record(self, path: Path | str) -> dict[str, Any]:
        target = Path(path)
        try:
            raw = target.read_text(encoding="utf-8")
        except OSError as exc:
            raise WorkerSessionError("record_invalid", f"session record is not readable: {exc.strerror or exc}") from exc
        try:
            record = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise WorkerSessionError("record_invalid", f"session record is not valid JSON: {exc.msg}") from exc
        if not isinstance(record, dict):
            raise WorkerSessionError("record_invalid", "session record must be a JSON object")
        self.validate_record(record)
        return record

    def validate_record(self, record: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, "worker_session_record", record)
        except DebateReportError as exc:
            raise WorkerSessionError("record_invalid", exc.message) from exc

    def _now(self) -> str:
        return self._clock().isoformat()

    def _slug(self, value: str) -> str:
        slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-")
        if not slug:
            raise WorkerSessionError("validation_error", "session identifiers must contain at least one safe character")
        return slug

    def _normalize_suffix(self, suffix: str) -> str:
        if not isinstance(suffix, str) or not re.fullmatch(r"[A-Za-z0-9]{12,}", suffix):
            raise WorkerSessionError("validation_error", "suffix_factory must return at least 12 alphanumeric characters")
        return suffix

    def _require_string(self, value: Any, label: str) -> None:
        if not isinstance(value, str) or not value:
            raise WorkerSessionError("validation_error", f"{label} must be a non-empty string")

    def _require_state_ref(self, value: Any, label: str) -> None:
        if not isinstance(value, str) or not value.startswith("state://runs/"):
            raise WorkerSessionError("validation_error", f"{label} must be a state://runs artifact reference")
