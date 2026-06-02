from __future__ import annotations

import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Protocol
from uuid import uuid4

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
    HEARTBEAT_ACTIVE_STATUSES = {"running", "blocked"}

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

    def sweep_run(
        self,
        records_root: Path | str,
        events_path: Path | str,
        *,
        hard_timeout_seconds: int = 120,
        soft_timeout_factor: float = 2.0,
    ) -> dict[str, Any]:
        records_path = Path(records_root)
        sweep_run_id = f"sweep-{uuid4().hex[:16]}"
        scanned = 0
        zombies = 0
        stalled = 0
        events: list[dict[str, Any]] = []
        now = self._clock()

        for path in sorted(records_path.glob("*.json")) if records_path.exists() else []:
            record = self.manager.load_record(path)
            if record.get("status") not in self.HEARTBEAT_ACTIVE_STATUSES:
                continue
            scanned += 1
            last_heartbeat_at = record.get("last_heartbeat_at") or record.get("started_at")
            heartbeat_age = self._age_seconds(last_heartbeat_at, now)
            if heartbeat_age >= hard_timeout_seconds:
                zombies += 1
                updated = self._mark_zombie(record, now, sweep_run_id, records_path / "archive")
                self.manager.write_record(path, updated)
                events.append(self._event(updated, "worker_zombie_detected", "error", sweep_run_id))
                continue
            estimated = record.get("estimated_seconds")
            started_age = self._age_seconds(record.get("dispatched_at") or record.get("started_at"), now)
            if isinstance(estimated, int) and estimated > 0 and started_age >= estimated * soft_timeout_factor and record.get("status") != "completed":
                stalled += 1
                updated = dict(record)
                updated["sweeper_status"] = "likely_stalled"
                updated["last_sweep_run_id"] = sweep_run_id
                self.manager.write_record(path, updated)
                events.append(self._event(updated, "worker_likely_stalled", "warning", sweep_run_id))

        sweep_event = {
            "schema_version": "orchestra.event.v1",
            "seq": 0,
            "timestamp": now.isoformat(),
            "run_id": _run_id_from_events_path(Path(events_path)),
            "task_id": None,
            "stage": None,
            "type": "sweep_run",
            "severity": "info",
            "status": "completed",
            "message": "Worker session sweeper completed",
            "artifact_refs": [],
            "decision_id": None,
            "sweep_run_id": sweep_run_id,
            "scanned_sessions_count": scanned,
            "zombie_count": zombies,
            "stalled_count": stalled,
        }
        sweep_result_event = dict(sweep_event)
        sweep_result_event["type"] = "sweep_result"
        self._append_events(Path(events_path), [sweep_event, sweep_result_event, *events])
        return {"sweep_run_id": sweep_run_id, "scanned_sessions_count": scanned, "zombie_count": zombies, "stalled_count": stalled}

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

    def _mark_zombie(self, record: dict[str, Any], now: datetime, sweep_run_id: str, archive_root: Path) -> dict[str, Any]:
        updated = dict(record)
        updated["sweeper_status"] = "zombie"
        updated["status"] = "timed_out"
        updated["ended_at"] = now.isoformat()
        updated["termination_reason"] = "heartbeat_timeout"
        updated["cleanup_status"] = "cleaned"
        updated["cleanup_attempted_at"] = now.isoformat()
        updated["last_sweep_run_id"] = sweep_run_id
        workspace_path = updated.get("workspace_path")
        if isinstance(workspace_path, str) and workspace_path:
            archive_root.mkdir(parents=True, exist_ok=True)
            target = archive_root / Path(workspace_path).name
            if Path(workspace_path).exists() and not target.exists():
                shutil.move(workspace_path, target)
            updated["workspace_archive_path"] = str(target)
        self.manager.validate_record(updated)
        return updated

    def _age_seconds(self, timestamp: Any, now: datetime) -> float:
        if not isinstance(timestamp, str) or not timestamp:
            return float("inf")
        return (now - datetime.fromisoformat(timestamp.replace("Z", "+00:00"))).total_seconds()

    def _event(self, record: dict[str, Any], event_type: str, severity: str, sweep_run_id: str) -> dict[str, Any]:
        return {
            "schema_version": "orchestra.event.v1",
            "seq": 0,
            "timestamp": self._clock().isoformat(),
            "run_id": record.get("run_id"),
            "task_id": record.get("task_id"),
            "stage": record.get("status"),
            "type": event_type,
            "severity": severity,
            "status": record.get("sweeper_status"),
            "message": event_type,
            "artifact_refs": [record.get("workspace_ref")] if record.get("workspace_ref") else [],
            "decision_id": None,
            "session_id": record.get("session_id"),
            "sweep_run_id": sweep_run_id,
        }

    def _append_events(self, path: Path, events: list[dict[str, Any]]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        seq = _next_event_seq(path)
        with path.open("a", encoding="utf-8") as handle:
            for event in events:
                event["seq"] = seq
                json.dump(event, handle, ensure_ascii=False)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
                seq += 1


def _next_event_seq(path: Path) -> int:
    if not path.exists():
        return 1
    seq = 0
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                seq = max(seq, int(json.loads(line).get("seq", 0)))
    return seq + 1


def _run_id_from_events_path(path: Path) -> str:
    try:
        return path.parent.name
    except IndexError:
        return ""
