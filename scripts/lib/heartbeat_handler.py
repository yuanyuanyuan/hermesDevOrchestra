from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


HEARTBEAT_PROTOCOL_VERSION = "1.0.0"
HEARTBEAT_STAGES = {"running", "paused", "blocked", "completed", "error"}
BLOCK_REASONS = {"waiting_for_upstream_artifact", "resource_exhausted", "manual_approval", "error_retry", None}
ACTIVE_SNAPSHOT_STATUSES = {"running", "blocked"}


class HeartbeatError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class HeartbeatHandler:
    def __init__(self, clock: Callable[[], datetime] | None = None) -> None:
        self._clock = clock or (lambda: datetime.now(timezone.utc))

    def process_heartbeat(self, *, run_dir: Path | str, events_path: Path | str, payload: dict[str, Any]) -> dict[str, Any]:
        heartbeat = self.validate_heartbeat(payload)
        run_path = Path(run_dir)
        record_path = run_path / "worker-sessions" / f"{heartbeat['session_id']}.json"
        if not record_path.exists():
            raise HeartbeatError("worker_session_not_found", "heartbeat session_id does not match a worker session")

        record = self._read_json(record_path)
        if record.get("run_id") != heartbeat["run_id"] or record.get("task_id") != heartbeat["task_id"]:
            raise HeartbeatError("worker_session_mismatch", "heartbeat run_id/task_id do not match the worker session")

        state_path = run_path / "heartbeats" / f"{heartbeat['session_id']}.json"
        state = self._read_json(state_path) if state_path.exists() else {"last_seq": 0, "pending": {}}
        seq = heartbeat["heartbeat_seq"]
        last_seq = int(state.get("last_seq", 0))
        pending = state.get("pending") if isinstance(state.get("pending"), dict) else {}

        if seq <= last_seq or str(seq) in pending:
            return {"status": "heartbeat_duplicate_ignored", "session_id": heartbeat["session_id"], "heartbeat_seq": seq}
        if seq > last_seq + 1:
            pending[str(seq)] = heartbeat
            state["pending"] = pending
            self._write_json(state_path, state)
            return {"status": "heartbeat_buffered_out_of_order", "session_id": heartbeat["session_id"], "heartbeat_seq": seq}

        processed: list[dict[str, Any]] = []
        current = heartbeat
        while current:
            processed.append(current)
            last_seq = current["heartbeat_seq"]
            current = pending.pop(str(last_seq + 1), None)

        latest = processed[-1]
        record["last_heartbeat_at"] = latest["timestamp"]
        record["latest_heartbeat"] = latest
        record["heartbeat_seq"] = latest["heartbeat_seq"]
        record["status"] = latest["stage"] if latest["stage"] in {"running", "blocked"} else record.get("status")
        self._write_json(record_path, record)
        self._append_heartbeat_events(Path(events_path), processed)

        state["last_seq"] = last_seq
        state["pending"] = pending
        self._write_json(state_path, state)
        return {"status": "accepted", "session_id": heartbeat["session_id"], "processed_count": len(processed), "last_heartbeat_seq": last_seq}

    def snapshot(self, *, run_id: str, run_dir: Path | str) -> dict[str, Any]:
        sessions = []
        for path in sorted((Path(run_dir) / "worker-sessions").glob("*.json")):
            record = self._read_json(path)
            if record.get("run_id") != run_id or record.get("status") not in ACTIVE_SNAPSHOT_STATUSES:
                continue
            latest = record.get("latest_heartbeat")
            if not isinstance(latest, dict):
                continue
            sessions.append(
                {
                    "session_id": record.get("session_id"),
                    "task_id": record.get("task_id"),
                    "status": record.get("status"),
                    "latest_heartbeat": latest,
                    "snapshot_lag_seconds": max(0, int((self._clock() - _parse_time(latest["timestamp"])).total_seconds())),
                }
            )
        return {"run_id": run_id, "sessions": sessions, "generated_at": self._clock().isoformat(), "readonly": True}

    def validate_heartbeat(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise HeartbeatError("invalid_heartbeat", "heartbeat must be a JSON object")
        required = ["protocol_version", "message_type", "run_id", "task_id", "session_id", "timestamp", "stage", "progress", "eta_seconds", "block_reason", "heartbeat_seq"]
        for field in required:
            if field not in payload:
                raise HeartbeatError("invalid_heartbeat", f"missing heartbeat field: {field}")
        if payload["protocol_version"] != HEARTBEAT_PROTOCOL_VERSION or payload["message_type"] != "worker_heartbeat":
            raise HeartbeatError("invalid_heartbeat", "unsupported heartbeat protocol")
        if payload["stage"] not in HEARTBEAT_STAGES:
            raise HeartbeatError("invalid_heartbeat", "invalid heartbeat stage")
        if payload["block_reason"] not in BLOCK_REASONS:
            raise HeartbeatError("invalid_heartbeat", "invalid block_reason")
        if not isinstance(payload["eta_seconds"], int):
            raise HeartbeatError("invalid_heartbeat", "eta_seconds must be an integer")
        if not isinstance(payload["heartbeat_seq"], int) or payload["heartbeat_seq"] < 1:
            raise HeartbeatError("invalid_heartbeat", "heartbeat_seq must be a positive integer")
        _parse_time(payload["timestamp"])
        progress = payload["progress"]
        if not isinstance(progress, dict):
            raise HeartbeatError("invalid_heartbeat", "progress must be an object")
        if not isinstance(progress.get("completed_count"), int) or not isinstance(progress.get("total_count"), int):
            raise HeartbeatError("invalid_heartbeat", "progress counts must be integers")
        for field in ["in_progress_tasks", "blocked_tasks"]:
            if not isinstance(progress.get(field), list) or not all(isinstance(item, str) for item in progress[field]):
                raise HeartbeatError("invalid_heartbeat", f"progress.{field} must be a string list")
        return dict(payload)

    def _append_heartbeat_events(self, events_path: Path, heartbeats: list[dict[str, Any]]) -> None:
        events_path.parent.mkdir(parents=True, exist_ok=True)
        seq = _next_event_seq(events_path)
        with events_path.open("a", encoding="utf-8") as handle:
            for heartbeat in heartbeats:
                json.dump(
                    {
                        "schema_version": "orchestra.event.v1",
                        "seq": seq,
                        "timestamp": heartbeat["timestamp"],
                        "run_id": heartbeat["run_id"],
                        "task_id": heartbeat["task_id"],
                        "stage": heartbeat["stage"],
                        "type": "heartbeat",
                        "severity": "info",
                        "status": heartbeat["stage"],
                        "message": "Worker heartbeat accepted",
                        "artifact_refs": [],
                        "decision_id": None,
                        "session_id": heartbeat["session_id"],
                        "heartbeat_seq": heartbeat["heartbeat_seq"],
                    },
                    handle,
                    ensure_ascii=False,
                )
                handle.write("\n")
                seq += 1

    def _read_json(self, path: Path) -> dict[str, Any]:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)

    def _write_json(self, path: Path, data: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _next_event_seq(path: Path) -> int:
    if not path.exists():
        return 1
    seq = 0
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                seq = max(seq, int(json.loads(line).get("seq", 0)))
    return seq + 1


def _parse_time(value: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError) as exc:
        raise HeartbeatError("invalid_heartbeat", "timestamp must be ISO-8601") from exc
    if parsed.tzinfo is None:
        raise HeartbeatError("invalid_heartbeat", "timestamp must include a timezone")
    return parsed
