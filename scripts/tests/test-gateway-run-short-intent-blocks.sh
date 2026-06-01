#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-short-intent-blocks"
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
mkdir -p "$HOME"

PROJECT_ID="gateway-intent"
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
    "idempotency_key": "gw-006-short-intent",
    "intent": "fix flaky login",
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
    data = json.loads(response.read().decode("utf-8"))
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
for url, path in (
    (f"{base_url}/orchestra/runs/{run_id}", status_path),
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0", events_path),
    (f"{base_url}/orchestra/runs/{run_id}/tasks", tasks_path),
):
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

assert create["status"] == "blocked", f"create response should be blocked for short intent: {create}"
assert status["status"] == "blocked", f"status should be blocked for short intent: {status}"
assert status["current_stage"] == "intake", status
assert status["blocked_reason"] == "structured_prd_required", status
assert status["pending_decision_id"]
assert status["pending_decision_refs"], status
assert status["artifact_refs"]["structured_prd"].startswith("state://")
assert status["artifact_refs"]["requirement_completion_bundle"].startswith("state://")

event_types = [event["type"] for event in events["events"]]
assert event_types == ["run_created", "ticket_normalized", "decision_required"]
assert events["next_seq"] == 4
assert all(event["command_id"] == command_id for event in events["events"])
decision_event = events["events"][-1]
assert decision_event["decision_id"] == status["pending_decision_id"]
assert decision_event["status"] == "blocked"

assert tasks["tasks"] == []

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
structured_prd = json.loads((run_dir / "structured_prd.json").read_text(encoding="utf-8"))
assert structured_prd["artifact_type"] == "structured_prd"
assert structured_prd["status"] == "incomplete"
assert structured_prd["source"] == "intent"
assert structured_prd["missing_fields"] == ["acceptance_criteria", "constraints", "failure_strategy"]

bundle = json.loads((run_dir / "requirement-completion-bundle.json").read_text(encoding="utf-8"))
assert bundle["artifact_type"] == "requirement_completion_bundle"
assert bundle["intent_summary"]["conclusions"][0]["confidence"] < 0.3, bundle
assert any(item["flag"] == "manual_confirmation_required" for item in bundle["risk_flags"]["items"]), bundle

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "ticket_normalized" and record.get("command_id") == command_id for record in audit_records)
assert any(record.get("type") == "decision_required" and record.get("command_id") == command_id for record in audit_records)

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8") if pathlib.Path(hermes_log).exists() else ""
assert "kanban create" not in calls
PY

test_done
