#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-decision-approve-intake"
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

PROJECT_ID="gateway-decision"
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
    "idempotency_key": "gw-011-create",
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

DECISION_ID="$(python3 - "$BASE_URL" "$RUN_ID" <<'PY'
import json
import sys
import urllib.request

base_url, run_id = sys.argv[1:]
with urllib.request.urlopen(f"{base_url}/orchestra/runs/{run_id}", timeout=5) as response:
    data = json.loads(response.read().decode("utf-8"))
print(data["pending_decision_id"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$DECISION_ID" "$TMP_DIR/decision.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, decision_id, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-011-approve",
    "action": "approve",
    "ticket": {
        "background": "Login flow flakes under retry",
        "goal": "Fix flaky login behavior",
        "deliverables": ["Regression test", "Implementation fix"],
        "acceptance_criteria": ["Login retry test passes", "No raw secrets in evidence"],
        "hard_constraints": ["Stay within auth module", "Preserve audit evidence"],
        "soft_constraints": ["Prefer existing test helpers"],
        "related_tasks": [],
        "failure_strategy": "Block if tests or review fail"
    }
}
request = urllib.request.Request(
    f"{base_url}/orchestra/decisions/{decision_id}",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 200, response.status
    data = json.loads(response.read().decode("utf-8"))
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

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

python3 - "$TMP_DIR/decision.json" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$TMP_DIR/tasks.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$RUN_ID" "$DECISION_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import re
import pathlib
import sys

decision_path, status_path, events_path, tasks_path, state_root, audit_root, project_id, run_id, decision_id, hermes_log = sys.argv[1:]
decision = json.load(open(decision_path, encoding="utf-8"))
status = json.load(open(status_path, encoding="utf-8"))
events = json.load(open(events_path, encoding="utf-8"))
tasks = json.load(open(tasks_path, encoding="utf-8"))

assert decision["schema_version"] == "orchestra.v1"
assert decision["decision_id"] == decision_id
assert decision["run_id"] == run_id
assert decision["status"] == "queued"
assert decision["action"] == "approve"

assert status["status"] == "queued"
assert status["current_stage"] == "direction_debate"
assert status["blocked_reason"] is None
assert status["pending_decision_id"] is None
assert status["pending_decision_refs"] == []
assert status["artifact_refs"]["structured_prd"].startswith("state://")
assert status["artifact_refs"]["requirement_completion_bundle"].startswith("state://")

event_types = [event["type"] for event in events["events"]]
assert event_types == ["run_created", "ticket_normalized", "decision_required", "decision_resolved"]
assert events["events"][-1]["decision_id"] == decision_id
assert events["events"][-1]["status"] == "queued"

assert len(tasks["tasks"]) == 6
assert tasks["tasks"][0]["stage"] == "direction_debate"

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
structured_prd = json.loads((run_dir / "structured_prd.json").read_text(encoding="utf-8"))
assert structured_prd["status"] == "ready"
assert structured_prd["source"] == "decision"
assert structured_prd["acceptance_criteria"] == ["Login retry test passes", "No raw secrets in evidence"]

bundle = json.loads((run_dir / "requirement-completion-bundle.json").read_text(encoding="utf-8"))
assert bundle["artifact_type"] == "requirement_completion_bundle"
for section in ("intent_summary", "dependency_graph", "conflict_list", "acceptance_matrix", "prompt_envelope", "risk_flags"):
    assert re.fullmatch(r"[0-9a-f]{64}", bundle[section]["source_input_hash"]), bundle
    assert bundle[section]["projection_timestamp"].endswith("Z"), bundle
assert set(bundle["dependency_graph"]["dimensions"]) == {"environment", "upstream", "downstream", "code"}, bundle
assert bundle["prompt_envelope"]["context_window_budget"] >= 1, bundle

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "decision_resolved" and record.get("decision_id") == decision_id for record in audit_records)

kanban_calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in kanban_calls if line.startswith("kanban create")]) == 7
PY

test_done
