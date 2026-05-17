#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-closeout-summary-alone-rejected"
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

PROJECT_ID="gateway-closeout-summary"
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
    "idempotency_key": "gw-031-create",
    "ticket": {
        "background": "Closeout completion gate test",
        "goal": "Reject closeout summary as completion authority",
        "deliverables": ["Validation failure"],
        "acceptance_criteria": ["Summary-only closeout cannot complete run"],
        "hard_constraints": ["Completion requires schema-valid closeout and proposals"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Return validation failure without side effects"
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

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/closeout-response.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, run_id, response_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-031-closeout",
    "summary": "Looks done to the model."
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/closeout",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    urllib.request.urlopen(request, timeout=5)
except urllib.error.HTTPError as exc:
    status = exc.code
    body = json.loads(exc.read().decode("utf-8"))
else:
    raise AssertionError("summary-only closeout unexpectedly succeeded")
assert status == 400, (status, body)
with open(response_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/status.json" "$TMP_DIR/events.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, status_path, events_path = sys.argv[1:]
for url, path in (
    (f"{base_url}/orchestra/runs/{run_id}", status_path),
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0&limit=20", events_path),
):
    with urllib.request.urlopen(url, timeout=5) as response:
        assert response.status == 200, response.status
        body = json.loads(response.read().decode("utf-8"))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/closeout-response.json" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$RUN_ID" <<'PY'
import json
import pathlib
import sys

response_path, status_path, events_path, state_root, audit_root, project_id, run_id = sys.argv[1:]
response = json.load(open(response_path, encoding="utf-8"))
status = json.load(open(status_path, encoding="utf-8"))
events = json.load(open(events_path, encoding="utf-8"))

assert response["error"]["code"] == "closeout_validation_failed", response
assert "iteration_closeout_report" in response["completion_blockers"], response
assert "system_improvement_proposals" in response["completion_blockers"], response

assert status["status"] == "queued", status
assert status["artifact_refs"].get("iteration_closeout_report") is None, status
assert status["artifact_refs"].get("system_improvement_proposals") is None, status

event_types = [event["type"] for event in events["events"]]
assert "run_completed" not in event_types, event_types

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
assert not (run_dir / "iteration_closeout_report.json").exists()
assert not (run_dir / "system_improvement_proposals.json").exists()

audit_path = pathlib.Path(audit_root) / project_id / "audit.jsonl"
audit_records = [json.loads(line) for line in audit_path.read_text(encoding="utf-8").splitlines() if line.strip()]
assert not any(record.get("type") == "run_completed" for record in audit_records), audit_records
PY

test_done
