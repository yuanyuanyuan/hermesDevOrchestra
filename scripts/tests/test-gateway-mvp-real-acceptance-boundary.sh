#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-mvp-real-acceptance-boundary"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

HERMES_CALL_LOG="$TMP_DIR/hermes-calls.log"
MAKE_CALL_LOG="$TMP_DIR/make-calls.log"
export HERMES_CALL_LOG MAKE_CALL_LOG

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

cat > "$FAKE_BIN/make" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAKE_CALL_LOG"
exit 0
SH
chmod +x "$FAKE_BIN/make"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
export ORCH_GATEWAY_RUN_TESTS=1
mkdir -p "$HOME"

PROJECT_ID="gateway-real-boundary"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

for knowledge_file in project-summary tech-stack api-surface module-map coding-rules test-strategy risk-notes update-manifest; do
  assert_file_exists "$PROJECT_DIR/.workflow/knowledge/${knowledge_file}.json" "workflow knowledge missing after orch-init"
done

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
    "idempotency_key": "gw-real-boundary-create",
    "ticket": {
        "background": "Full MVP boundary",
        "goal": "Create run with concrete acceptance evidence",
        "deliverables": ["Run state", "Kanban links", "Executed test evidence"],
        "acceptance_criteria": ["Acceptance evidence is executable", "Kanban dependencies are linked"],
        "hard_constraints": ["Do not use scaffold test evidence"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Block if evidence cannot be produced"
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
    data = json.loads(response.read().decode("utf-8"))
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/create.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" "$MAKE_CALL_LOG" <<'PY'
import json
import pathlib
import sys

create_path, state_root, audit_root, project_id, hermes_log, make_log = sys.argv[1:]
create = json.load(open(create_path, encoding="utf-8"))
run_id = create["run_id"]
run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id

assert create["run_uri"] == f"state://{project_id}/{run_id}/run.json", create

test_execution = json.loads((run_dir / "test_execution_report.json").read_text(encoding="utf-8"))
command = test_execution["commands"][0]
assert command["command"] == "make test", test_execution
assert command["source"] == "executed_gateway_command", test_execution
assert command["exit_code"] == 0, test_execution
assert "mvp_acceptance_scaffold" not in json.dumps(test_execution), test_execution

hermes_calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert any(call.startswith("kanban init") for call in hermes_calls), hermes_calls
assert len([call for call in hermes_calls if call.startswith("kanban create")]) == 7, hermes_calls
assert len([call for call in hermes_calls if call.startswith("kanban link")]) >= 5, hermes_calls

make_calls = pathlib.Path(make_log).read_text(encoding="utf-8").splitlines()
assert make_calls == ["test"], make_calls

events = [
    json.loads(line)
    for line in (run_dir / "events.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
event_types = [event["type"] for event in events]
assert "debate_degraded" in event_types, event_types
assert all(not str(ref).startswith("/") for event in events for ref in event["artifact_refs"]), events

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "test_execution_recorded" for record in audit_records), audit_records
assert any(record.get("type") == "debate_degraded" for record in audit_records), audit_records
PY

test_done
