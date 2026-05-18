from __future__ import annotations

import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Protocol

from worker_session import ACTIVE_SESSION_STATUSES, TERMINAL_SESSION_STATUSES, WorkerSessionError, WorkerSessionManager


class WorkerSessionSweeperError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class TmuxControllerProtocol(Protocol):
    def has_session(self, socket_name: str, session_name: str) -> bool: ...

    def send_interrupt(self, socket_name: str, session_name: str) -> bool: ...

    def kill_session(self, socket_name: str, session_name: str) -> bool: ...


class TmuxController:
    def has_session(self, socket_name: str, session_name: str) -> bool:
        completed = subprocess.run(
            ["tmux", "-L", socket_name, "has-session", "-t", session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return completed.returncode == 0

    def send_interrupt(self, socket_name: str, session_name: str) -> bool:
        subprocess.run(
            ["tmux", "-L", socket_name, "send-keys", "-t", session_name, "C-c"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return not self.has_session(socket_name, session_name)

    def kill_session(self, socket_name: str, session_name: str) -> bool:
        completed = subprocess.run(
            ["tmux", "-L", socket_name, "kill-session", "-t", session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return completed.returncode == 0 or not self.has_session(socket_name, session_name)


class WorkerSessionSweeper:
    ACTIVE_STATUSES = ACTIVE_SESSION_STATUSES
    TERMINAL_STATUSES = TERMINAL_SESSION_STATUSES

    def __init__(
        self,
        repo_root: Path | str,
        clock: Callable[[], datetime] | None = None,
        tmux_controller: TmuxControllerProtocol | None = None,
    ) -> None:
        clock_fn = clock or (lambda: datetime.now(timezone.utc))
        self.manager = WorkerSessionManager(repo_root, clock=clock_fn)
        self._clock = clock_fn
        self.tmux = tmux_controller or TmuxController()

    def sweep_directory(self, records_root: Path | str) -> dict[str, int]:
        records_path = Path(records_root)
        if not records_path.exists():
            return {"updated_records": 0, "timed_out_records": 0, "missing_records": 0, "invalid_records": 0}

        updated_records = 0
        timed_out_records = 0
        missing_records = 0
        invalid_records = 0

        for path in sorted(records_path.glob("*.json")):
            try:
                record = self.manager.load_record(path)
            except WorkerSessionError as exc:
                invalid_records += 1
                continue
            updated = self._sweep_record(record)
            if updated is None:
                continue
            self.manager.write_record(path, updated)
            updated_records += 1
            if updated["status"] == "timed_out":
                timed_out_records += 1
            if updated["status"] == "abandoned":
                missing_records += 1

        return {
            "updated_records": updated_records,
            "timed_out_records": timed_out_records,
            "missing_records": missing_records,
            "invalid_records": invalid_records,
        }

    def _sweep_record(self, record: dict[str, Any]) -> dict[str, Any] | None:
        status = record["status"]
        if status not in self.ACTIVE_STATUSES and not (
            status in self.TERMINAL_STATUSES and record["cleanup_status"] not in {"cleaned", "not_found"}
        ):
            return None

        socket_name = record.get("tmux_socket_name", "")
        session_name = record.get("tmux_session_name", "")
        if not isinstance(socket_name, str) or not socket_name or not isinstance(session_name, str) or not session_name:
            raise WorkerSessionSweeperError("record_invalid", "session record is missing tmux socket metadata")

        session_exists = self.tmux.has_session(socket_name, session_name)
        now = self._clock().isoformat()

        if status in self.ACTIVE_STATUSES and not session_exists:
            updated = dict(record)
            updated["status"] = "abandoned"
            updated["ended_at"] = now
            updated["termination_reason"] = "tmux_session_missing"
            updated["cleanup_status"] = "not_found"
            updated["cleanup_attempted_at"] = now
            self.manager.validate_record(updated)
            return updated

        if status in self.ACTIVE_STATUSES and self._heartbeat_expired(record):
            updated = dict(record)
            updated["status"] = "timed_out"
            updated["ended_at"] = now
            updated["termination_reason"] = "heartbeat_timeout"
            updated["cleanup_status"] = "graceful_stop_requested"
            updated["cleanup_attempted_at"] = now
            return self._cleanup_session(updated, session_exists=session_exists)

        if status in self.TERMINAL_STATUSES and session_exists:
            updated = dict(record)
            updated["cleanup_attempted_at"] = now
            if updated["cleanup_status"] == "not_started":
                updated["cleanup_status"] = "graceful_stop_requested"
            return self._cleanup_session(updated, session_exists=True)

        return None

    def _cleanup_session(self, record: dict[str, Any], *, session_exists: bool) -> dict[str, Any]:
        updated = dict(record)
        socket_name = updated["tmux_socket_name"]
        session_name = updated["tmux_session_name"]

        if not session_exists:
            updated["cleanup_status"] = "not_found"
            self.manager.validate_record(updated)
            return updated

        interrupted = self.tmux.send_interrupt(socket_name, session_name)
        if interrupted or not self.tmux.has_session(socket_name, session_name):
            updated["cleanup_status"] = "cleaned"
            updated["cleanup_error"] = None
            self.manager.validate_record(updated)
            return updated

        killed = self.tmux.kill_session(socket_name, session_name)
        if killed or not self.tmux.has_session(socket_name, session_name):
            updated["cleanup_status"] = "cleaned"
            updated["cleanup_error"] = None
            self.manager.validate_record(updated)
            return updated

        updated["cleanup_status"] = "failed"
        updated["cleanup_error"] = "tmux_cleanup_failed"
        self.manager.validate_record(updated)
        return updated

    def _heartbeat_expired(self, record: dict[str, Any]) -> bool:
        timeout_seconds = record["timeout_seconds"]
        heartbeat_at = record.get("last_heartbeat_at") or record.get("started_at")
        if not isinstance(heartbeat_at, str) or not heartbeat_at:
            return True
        try:
            heartbeat_time = datetime.fromisoformat(heartbeat_at)
        except ValueError as exc:
            raise WorkerSessionSweeperError("record_invalid", f"invalid heartbeat timestamp: {heartbeat_at}") from exc
        return (self._clock() - heartbeat_time).total_seconds() >= timeout_seconds
