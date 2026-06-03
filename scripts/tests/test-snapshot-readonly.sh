#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="snapshot-readonly"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "create" ]; then
  printf '{"id":"kanban-task","status":"created"}\n'
  exit 0
fi
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
export PYTHONPATH="$REPO_ROOT/scripts/lib"
mkdir -p "$HOME"

PROJECT_ID="snapshot-readonly"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

PORT="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
BASE_URL="http://127.0.0.1:$PORT"
GATEWAY_LOG="$TMP_DIR/gateway.log"
"$REPO_ROOT/scripts/bin/orch-gateway" --project-id "$PROJECT_ID" --host 127.0.0.1 --port "$PORT" >"$GATEWAY_LOG" 2>&1 &
GATEWAY_PID="$!"
trap 'kill "$GATEWAY_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

python3 - "$BASE_URL/health" "$GATEWAY_LOG" <<'PY'
import sys
import time
import urllib.request

url, log_path = sys.argv[1:]
deadline = time.time() + 5
last_error = None
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=0.5) as response:
            if response.status == 200:
                raise SystemExit(0)
    except Exception as exc:
        last_error = exc
        time.sleep(0.1)
print(open(log_path, encoding="utf-8", errors="replace").read(), file=sys.stderr)
raise SystemExit(f"gateway did not become healthy: {last_error}")
PY

python3 - "$BASE_URL" "$REPO_ROOT" "$STATE_ROOT" "$PROJECT_ID" <<'PY'
import json
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from worker_session import WorkerSessionManager

base_url, repo_root, state_root, project_id = sys.argv[1:]
payload = {"idempotency_key": "snapshot-create", "intent": "check live snapshot", "options": {"mode": "mvp_full"}}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    run_id = json.loads(response.read().decode("utf-8"))["run_id"]

run_dir = Path(state_root) / project_id / "runs" / run_id
manager = WorkerSessionManager(Path(repo_root), suffix_factory=lambda: "snapabc12345")
record = manager.create_dispatch_session(
    run_id=run_id,
    task_id="task-snapshot",
    assigned_actor="codex",
    workspace_root=Path(state_root) / "workspaces",
    computed_write_scope=["src/snapshot.py"],
    context_bundle_id="ctx-snapshot",
)
manager.persist_record(record, run_dir / "worker-sessions")

heartbeat = {
    "protocol_version": "1.0.0",
    "message_type": "worker_heartbeat",
    "task_id": "task-snapshot",
    "session_id": record["session_id"],
    "timestamp": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
    "stage": "running",
    "progress": {"completed_count": 1, "total_count": 2, "in_progress_tasks": ["subtask-2"], "blocked_tasks": []},
    "eta_seconds": 20,
    "block_reason": None,
    "heartbeat_seq": 1,
}
post = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/heartbeat",
    data=json.dumps(heartbeat).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(post, timeout=5) as response:
    accepted = json.loads(response.read().decode("utf-8"))
assert accepted["status"] == "accepted", accepted

record_path = run_dir / "worker-sessions" / f"{record['session_id']}.json"
before = record_path.read_text(encoding="utf-8")
with urllib.request.urlopen(f"{base_url}/orchestra/runs/{run_id}/snapshot", timeout=5) as response:
    snapshot = json.loads(response.read().decode("utf-8"))
after = record_path.read_text(encoding="utf-8")

assert before == after, "snapshot endpoint mutated worker session record"
assert snapshot["readonly"] is True, snapshot
assert len(snapshot["sessions"]) == 1, snapshot
assert snapshot["sessions"][0]["latest_heartbeat"]["heartbeat_seq"] == 1, snapshot
assert snapshot["sessions"][0]["snapshot_lag_seconds"] <= 35, snapshot
PY

test_done
