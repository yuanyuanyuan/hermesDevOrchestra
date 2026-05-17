#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-events-gap-inconsistent"
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
  printf '{"id":"kanban-fixed","status":"created"}\n'
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
mkdir -p "$HOME"

PROJECT_ID="gateway-events-gap"
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

python3 - "$BASE_URL" "$TMP_DIR/create.json" <<'PY'
import json
import sys
import urllib.request

base_url, create_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-035-create",
    "ticket": {
        "background": "Event projection gap test",
        "goal": "Detect stale event projection",
        "deliverables": ["Projection inconsistency response"],
        "acceptance_criteria": ["Event gaps require resync without blocking run"],
        "hard_constraints": ["Events are observation only"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Return projection inconsistency"
    },
    "options": {"mode": "mvp_full"}
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 201, response.status
    create = json.loads(response.read().decode("utf-8"))
with open(create_path, "w", encoding="utf-8") as handle:
    json.dump(create, handle, indent=2)
    handle.write("\n")
PY

RUN_ID="$(python3 - "$TMP_DIR/create.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["run_id"])
PY
)"

python3 - "$STATE_ROOT" "$PROJECT_ID" "$RUN_ID" <<'PY'
import json
import pathlib
import sys

state_root, project_id, run_id = sys.argv[1:]
events_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "events.jsonl"
events = [
    {
        "schema_version": "orchestra.event.v1",
        "seq": 1,
        "timestamp": "2026-05-17T00:00:00Z",
        "command_id": "cmd-corrupt",
        "idempotency_key": "gw-035-create",
        "run_id": run_id,
        "task_id": None,
        "stage": None,
        "type": "run_created",
        "severity": "info",
        "status": "queued",
        "message": "Six-Stage Run created",
        "artifact_refs": [f"state://runs/{run_id}/run.json"],
        "decision_id": None
    },
    {
        "schema_version": "orchestra.event.v1",
        "seq": 3,
        "timestamp": "2026-05-17T00:00:01Z",
        "command_id": "cmd-corrupt",
        "idempotency_key": None,
        "run_id": run_id,
        "task_id": None,
        "stage": None,
        "type": "artifact_written",
        "severity": "info",
        "status": "queued",
        "message": "Corrupt event with a gap",
        "artifact_refs": [f"state://runs/{run_id}/run.json"],
        "decision_id": None
    }
]
events_path.write_text("".join(json.dumps(event) + "\n" for event in events), encoding="utf-8")
PY

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/events.json" "$TMP_DIR/status.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, events_path, status_path = sys.argv[1:]
for url, path in (
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0&limit=20", events_path),
    (f"{base_url}/orchestra/runs/{run_id}", status_path),
):
    with urllib.request.urlopen(url, timeout=5) as response:
        assert response.status == 200, response.status
        body = json.loads(response.read().decode("utf-8"))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/events.json" "$TMP_DIR/status.json" <<'PY'
import json
import sys

events = json.load(open(sys.argv[1], encoding="utf-8"))
status = json.load(open(sys.argv[2], encoding="utf-8"))

assert events["projection_status"] == "inconsistent", events
assert [event["seq"] for event in events["events"]] == [1, 3], events
assert status["status"] == "queued", status
assert status["blocked_reason"] is None, status
assert status["failure_reason"] is None, status
PY

test_done
