#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="sweeper-zombie-detection"
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

from worker_session import WorkerSessionManager
from worker_session_sweeper import WorkerSessionSweeper

repo_root = Path(sys.argv[1])
tmp = Path(sys.argv[2])
run_id = "run-sweep"
records_root = tmp / "runs" / run_id / "worker-sessions"
events_path = tmp / "runs" / run_id / "events.jsonl"
clock_now = datetime(2026, 6, 2, 12, 0, tzinfo=timezone.utc)
manager = WorkerSessionManager(repo_root, clock=lambda: clock_now, suffix_factory=lambda: "sweepabc12345")

def make_record(task_id: str, suffix: str, started_delta: int, heartbeat_delta: int, estimated: int | None = None) -> dict:
    local_manager = WorkerSessionManager(repo_root, clock=lambda: clock_now - timedelta(seconds=started_delta), suffix_factory=lambda: suffix)
    record = local_manager.create_dispatch_session(
        run_id=run_id,
        task_id=task_id,
        assigned_actor="codex",
        workspace_root=tmp / "workspaces",
        computed_write_scope=[f"src/{task_id}.py"],
        context_bundle_id=f"ctx-{task_id}",
    )
    record["status"] = "running"
    record["last_heartbeat_at"] = (clock_now - timedelta(seconds=heartbeat_delta)).isoformat()
    record["started_at"] = (clock_now - timedelta(seconds=started_delta)).isoformat()
    if estimated is not None:
        record["estimated_seconds"] = estimated
    manager.persist_record(record, records_root)
    return record

zombie = make_record("zombie-task", "zombieabc123", 180, 130)
stalled = make_record("stalled-task", "stallabc1234", 50, 10, estimated=20)

sweeper = WorkerSessionSweeper(repo_root, clock=lambda: clock_now)
result = sweeper.sweep_run(records_root, events_path)
assert result["scanned_sessions_count"] == 2, result
assert result["zombie_count"] == 1, result
assert result["stalled_count"] == 1, result

updated_zombie = json.loads((records_root / f"{zombie['session_id']}.json").read_text(encoding="utf-8"))
assert updated_zombie["sweeper_status"] == "zombie", updated_zombie
assert updated_zombie["cleanup_status"] == "cleaned", updated_zombie
assert str(records_root / "archive") in updated_zombie["workspace_archive_path"], updated_zombie

updated_stalled = json.loads((records_root / f"{stalled['session_id']}.json").read_text(encoding="utf-8"))
assert updated_stalled["sweeper_status"] == "likely_stalled", updated_stalled

events = [json.loads(line) for line in events_path.read_text(encoding="utf-8").splitlines()]
event_types = [event["type"] for event in events]
assert event_types[0:2] == ["sweep_run", "sweep_result"], event_types
assert set(event_types[2:]) == {"worker_zombie_detected", "worker_likely_stalled"}, event_types
assert events[0]["scanned_sessions_count"] == 2, events[0]
PY

test_done
