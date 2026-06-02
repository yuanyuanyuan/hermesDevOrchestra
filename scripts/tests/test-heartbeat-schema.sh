#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="heartbeat-schema"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export PYTHONPATH="$REPO_ROOT/scripts/lib"

python3 - "$REPO_ROOT" "$TMP_DIR" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from heartbeat_handler import HeartbeatError, HeartbeatHandler
from worker_session import WorkerSessionManager

repo_root = Path(sys.argv[1])
tmp = Path(sys.argv[2])
run_id = "run-heartbeat"
task_id = "task-1"
run_dir = tmp / "runs" / run_id
events_path = run_dir / "events.jsonl"
run_dir.mkdir(parents=True)
(run_dir / "run.json").write_text(json.dumps({"run_id": run_id}) + "\n", encoding="utf-8")

manager = WorkerSessionManager(repo_root, suffix_factory=lambda: "abc123abc123")
record = manager.create_dispatch_session(
    run_id=run_id,
    task_id=task_id,
    assigned_actor="codex",
    workspace_root=tmp / "workspaces",
    computed_write_scope=["src/a.py"],
    context_bundle_id="ctx-1",
)
manager.persist_record(record, run_dir / "worker-sessions")

handler = HeartbeatHandler()
now = datetime.now(timezone.utc)

def heartbeat(seq: int, completed_count: int = 0) -> dict:
    return {
        "protocol_version": "1.0.0",
        "message_type": "worker_heartbeat",
        "run_id": run_id,
        "task_id": task_id,
        "session_id": record["session_id"],
        "timestamp": (now + timedelta(seconds=seq)).isoformat(timespec="milliseconds"),
        "stage": "running",
        "progress": {
            "completed_count": completed_count,
            "total_count": 3,
            "in_progress_tasks": ["subtask-1"],
            "blocked_tasks": [],
        },
        "eta_seconds": 30,
        "block_reason": None,
        "resource_usage": {"cpu_percent": 1.0, "memory_mb": 64},
        "heartbeat_seq": seq,
    }

accepted = handler.process_heartbeat(run_dir=run_dir, events_path=events_path, payload=heartbeat(1))
assert accepted["status"] == "accepted", accepted

duplicate = handler.process_heartbeat(run_dir=run_dir, events_path=events_path, payload=heartbeat(1))
assert duplicate["status"] == "heartbeat_duplicate_ignored", duplicate

buffered = handler.process_heartbeat(run_dir=run_dir, events_path=events_path, payload=heartbeat(3, 2))
assert buffered["status"] == "heartbeat_buffered_out_of_order", buffered

drained = handler.process_heartbeat(run_dir=run_dir, events_path=events_path, payload=heartbeat(2, 1))
assert drained["processed_count"] == 2, drained
assert drained["last_heartbeat_seq"] == 3, drained

events = [json.loads(line) for line in events_path.read_text(encoding="utf-8").splitlines()]
assert [event["heartbeat_seq"] for event in events] == [1, 2, 3], events

stored = json.loads((run_dir / "worker-sessions" / f"{record['session_id']}.json").read_text(encoding="utf-8"))
assert stored["latest_heartbeat"]["progress"]["completed_count"] == 2, stored

invalid = heartbeat(4)
del invalid["progress"]["in_progress_tasks"]
try:
    handler.process_heartbeat(run_dir=run_dir, events_path=events_path, payload=invalid)
except HeartbeatError as exc:
    assert exc.code == "invalid_heartbeat", exc.code
else:
    raise AssertionError("invalid heartbeat was accepted")
PY

test_done
