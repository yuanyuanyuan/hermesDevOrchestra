#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-create"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

HERMES_CALL_LOG="$TMP_DIR/hermes-calls.log"
export HERMES_CALL_LOG

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "create" ]; then
  title="task"
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--title" ]; then title="$2"; shift 2; else shift; fi
  done
  printf '{"id":"kanban-%s","status":"created"}\n' "$(printf '%s' "$title" | tr ' /_' '---' | tr -cd '[:alnum:]-' | cut -c1-40)"
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

PROJECT_ID="gateway-create"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

assert_executable "$REPO_ROOT/scripts/bin/orch-gateway" "gateway entrypoint missing"

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

base_url, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-001-create",
    "ticket": {
        "background": "Gateway tracer bullet",
        "goal": "Create a Six-Stage Run through the Orchestra API",
        "deliverables": ["Run state", "Audit evidence", "Event projection", "Task projection"],
        "acceptance_criteria": ["Kimi can inspect status, events, and tasks after creation"],
        "hard_constraints": ["Use scoped artifact refs", "Do not expose raw Kanban CRUD"],
        "soft_constraints": ["Keep the first slice minimal"],
        "related_tasks": [],
        "failure_strategy": "Block with evidence if the authority chain cannot be written"
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
    body = response.read().decode("utf-8")
    assert response.status == 201, response.status
    data = json.loads(body)
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

RUN_ID="$(python3 - "$TMP_DIR/create.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["run_id"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$TMP_DIR/tasks.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, status_path, events_path, tasks_path = sys.argv[1:]
targets = [
    (f"{base_url}/orchestra/runs/{run_id}", status_path),
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0", events_path),
    (f"{base_url}/orchestra/runs/{run_id}/tasks", tasks_path),
]
for url, path in targets:
    with urllib.request.urlopen(url, timeout=5) as response:
        assert response.status == 200, response.status
        data = json.loads(response.read().decode("utf-8"))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/create.json" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$TMP_DIR/tasks.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

create_path, status_path, events_path, tasks_path, state_root, audit_root, project_id, hermes_log = sys.argv[1:]
create = json.load(open(create_path, encoding="utf-8"))
status = json.load(open(status_path, encoding="utf-8"))
events = json.load(open(events_path, encoding="utf-8"))
tasks = json.load(open(tasks_path, encoding="utf-8"))

run_id = create["run_id"]
command_id = create["command_id"]

assert create["schema_version"] == "orchestra.v1"
assert create["idempotency_key"] == "gw-001-create"
assert create["status"] == "queued"
assert create["event_projection_degraded"] is False
assert create["projection_status"] == "consistent"
assert create["events_url"] == f"/orchestra/runs/{run_id}/events"
assert create["tasks_url"] == f"/orchestra/runs/{run_id}/tasks"

assert status["schema_version"] == "orchestra.v1"
assert status["run_id"] == run_id
assert status["status"] == "queued"
assert status["project"] == project_id
assert status["last_command_id"] == command_id
assert status["current_stage"] == "direction_debate"

assert events["schema_version"] == "orchestra.v1"
assert events["run_id"] == run_id
assert events["since_seq"] == 0
assert events["next_seq"] == 2
assert events["projection_status"] == "consistent"
assert len(events["events"]) == 1
event = events["events"][0]
assert event["schema_version"] == "orchestra.event.v1"
assert event["seq"] == 1
assert event["type"] == "run_created"
assert event["command_id"] == command_id
assert event["run_id"] == run_id
assert all(not str(ref).startswith("/") for ref in event["artifact_refs"])

assert tasks["schema_version"] == "orchestra.v1"
assert tasks["run_id"] == run_id
assert tasks["projection_status"] == "consistent"
stage_names = [task["stage"] for task in tasks["tasks"]]
assert stage_names == [
    "direction_debate",
    "solution_debate",
    "implementation",
    "improvement",
    "global_evaluation",
    "continuous_improvement",
]

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
assert (run_dir / "run.json").is_file()
assert (run_dir / "events.jsonl").is_file()
assert any((run_dir / "commands").glob("*.json"))

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "run_created" and record.get("command_id") == command_id for record in audit_records)

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8")
assert "kanban create" in calls
assert "direction_debate" in calls
PY

test_done
