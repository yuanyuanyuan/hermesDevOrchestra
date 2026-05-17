#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-events-rebuild"
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
  printf '{"id":"kanban-%s","status":"created"}\n' "$(wc -l < "$HERMES_CALL_LOG" | tr -d ' ')"
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
export ORCH_GATEWAY_FAIL_EVENT_APPEND=1
mkdir -p "$HOME"

PROJECT_ID="gateway-events-rebuild"
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

base_url, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-019-create",
    "ticket": {
        "background": "Projection rebuild test",
        "goal": "Create authority state while event append is degraded",
        "deliverables": ["Run state", "Audit evidence", "Rebuilt event projection"],
        "acceptance_criteria": ["Event polling rebuilds the missing projection"],
        "hard_constraints": ["Do not invent Audit records"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Rebuild projection from authorities"
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
    body = json.loads(response.read().decode("utf-8"))
assert body["event_projection_degraded"] is True, body
assert body["projection_status"] == "inconsistent", body
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

RUN_ID="$(python3 - "$TMP_DIR/create.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["run_id"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/events-rebuilt.json" "$TMP_DIR/events-replay.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, rebuilt_path, replay_path = sys.argv[1:]
for output_path in (rebuilt_path, replay_path):
    with urllib.request.urlopen(f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0&limit=10", timeout=5) as response:
        assert response.status == 200, response.status
        body = json.loads(response.read().decode("utf-8"))
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/create.json" "$TMP_DIR/events-rebuilt.json" "$TMP_DIR/events-replay.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" <<'PY'
import json
import pathlib
import sys

create_path, rebuilt_path, replay_path, state_root, audit_root, project_id = sys.argv[1:]
create = json.load(open(create_path, encoding="utf-8"))
rebuilt = json.load(open(rebuilt_path, encoding="utf-8"))
replay = json.load(open(replay_path, encoding="utf-8"))
run_id = create["run_id"]
command_id = create["command_id"]

assert rebuilt["projection_status"] == "rebuilt", rebuilt
assert rebuilt["rebuilt_from_refs"], rebuilt
assert f"state://runs/{run_id}/run.json" in rebuilt["rebuilt_from_refs"], rebuilt
assert any(ref.startswith("audit://") for ref in rebuilt["rebuilt_from_refs"]), rebuilt
assert rebuilt["projection_issue_refs"] == create["projection_issue_refs"], rebuilt
assert [event["type"] for event in rebuilt["events"]] == ["run_created"], rebuilt
assert rebuilt["next_seq"] == 2, rebuilt

event = rebuilt["events"][0]
assert event["seq"] == 1, event
assert event["run_id"] == run_id, event
assert event["command_id"] == command_id, event
assert event["status"] == "queued", event
assert f"state://runs/{run_id}/run.json" in event["artifact_refs"], event
assert f"state://runs/{run_id}/tasks.json" in event["artifact_refs"], event
assert any(ref.startswith("audit://") for ref in event["artifact_refs"]), event
assert not any(str(ref).startswith("/") for ref in event["artifact_refs"]), event

assert replay["projection_status"] == "consistent", replay
assert replay["events"] == rebuilt["events"], replay
assert replay["rebuilt_from_refs"] == [], replay

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
assert (run_dir / "events.jsonl").is_file()
assert len((run_dir / "events.jsonl").read_text(encoding="utf-8").splitlines()) == 1

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
run_created_records = [
    record
    for record in audit_records
    if record.get("type") == "run_created" and record.get("command_id") == command_id
]
assert len(run_created_records) == 1, audit_records
assert not any(record.get("type") in {"event_projection_rebuilt", "projection_rebuilt"} for record in audit_records), audit_records
PY

test_done
