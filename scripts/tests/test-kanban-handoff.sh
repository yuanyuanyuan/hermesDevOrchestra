#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="kanban-handoff"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

init_project() {
  local project_id="$1"
  PROJECT_DIR="$TMP_DIR/$project_id"
  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init >/dev/null
  "$REPO_ROOT/scripts/bin/orch-init" "$project_id" "$PROJECT_DIR" >/dev/null
  RUNTIME_DIR="$RUNTIME_ROOT/$project_id"
  STATE_DIR="$STATE_ROOT/$project_id"
}

json_field() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

path, dotted = sys.argv[1:]
value = json.load(open(path, encoding="utf-8"))
for part in dotted.split("."):
    if part:
        if isinstance(value, list):
            value = value[int(part)]
        else:
            value = value[part]
if value is None:
    print("null")
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

init_project handoff-review
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","task_type":"implementation","project_workspace":"/tmp/work","task_id":"impl-task-2","task_body":"Implement login API","task_summary":"Implement login API","current_stage":"implementation","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"impl-corr-2","turn":1,"task_id":"impl-task-2","status":"task_complete","next_action":"complete","role_specific_payload":{"summary":"Implementation shipped","behaviors":[{"name":"login-api","test":"npm test -- login","status":"passed"}],"regression":{"commands":["npm test"],"passed":12,"failed":0},"changed_files":["src/login.ts"],"decisions":["keep handler thin"],"pitfalls":["requires seeded user fixture"]},"conversation_context":[]}
JSON
"$REPO_ROOT/scripts/bin/orch-bus-loop" handoff-review "$PROJECT_DIR" --once
assert_eq "reviewer" "$(json_field "$RUNTIME_DIR/task.md" "role")" "implementer completion should create reviewer child"
assert_eq "review_handoff" "$(json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow_state should mark review handoff"
assert_eq "impl-task-2" "$(json_field "$RUNTIME_DIR/task.md" "parents.0")" "reviewer child should link back to implementer parent"
python3 - "$STATE_DIR/current-task.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["handoff_ref"]
PY
assert_eq "untrusted" "$(json_field "$RUNTIME_DIR/task.md" "handoff_from_parent.trust_level")" "reviewer child should mark parent handoff untrusted"
assert_contains "<untrusted-handoff" "$RUNTIME_DIR/task.md" "reviewer child should carry wrapped untrusted context"

init_project handoff-qa
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"reviewer","task_type":"review","project_workspace":"/tmp/work","task_id":"review-task-1","task_body":"Review login API","task_summary":"Review login API","current_stage":"review","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":{"summary":"impl done","artifact_refs":["/tmp/fake.json"]},"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"reviewer","correlation_id":"review-corr-1","turn":1,"task_id":"review-task-1","status":"approved","next_action":"complete","role_specific_payload":{"summary":"Approved with user-visible change","behaviors":[{"name":"review-pass","test":"manual review","status":"passed"}],"regression":{"commands":["npm test"],"passed":12,"failed":0},"changed_files":["src/login.ts"],"decisions":["QA required for visible login flow"],"pitfalls":["ui copy still needs smoke check"],"user_visible_change":true},"conversation_context":[]}
JSON
"$REPO_ROOT/scripts/bin/orch-bus-loop" handoff-qa "$PROJECT_DIR" --once
assert_eq "qa-tester" "$(json_field "$RUNTIME_DIR/task.md" "role")" "reviewer approval with qa trigger should create qa child"
assert_eq "qa_handoff" "$(json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow_state should mark qa handoff"
assert_eq "review-task-1" "$(json_field "$RUNTIME_DIR/task.md" "parents.0")" "qa child should link back to reviewer parent"

init_project handoff-findings
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"reviewer","task_type":"review","project_workspace":"/tmp/work","task_id":"review-task-2","task_body":"Review persistence flow","task_summary":"Review persistence flow","current_stage":"review","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":{"summary":"impl done","artifact_refs":["/tmp/fake.json"]},"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"reviewer","correlation_id":"review-corr-2","turn":1,"task_id":"review-task-2","status":"findings","next_action":"block","role_specific_payload":{"summary":"Token rotation missing","behaviors":[{"name":"rotation-gap","test":"manual reasoning","status":"failed"}],"regression":{"commands":["npm test"],"passed":11,"failed":1},"changed_files":["src/login.ts"],"decisions":["must rotate token before merge"],"pitfalls":["follow-up should preserve previous tests"],"findings":[{"severity":"high","path":"src/login.ts","line":8,"issue":"rotation gap","recommended_fix":"rotate token"}],"required_follow_up":"Fix token rotation and resubmit"},"conversation_context":[]}
JSON
"$REPO_ROOT/scripts/bin/orch-bus-loop" handoff-findings "$PROJECT_DIR" --once
assert_eq "implementer" "$(json_field "$RUNTIME_DIR/task.md" "role")" "review findings should create implementer follow-up child"
assert_eq "followup_handoff" "$(json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow_state should mark implementer follow-up"
assert_eq "review-task-2" "$(json_field "$RUNTIME_DIR/task.md" "parents.0")" "follow-up child should link back to reviewer parent"
python3 - "$STATE_DIR/current-task.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["handoff_ref"]
PY

init_project handoff-dispatch
PORT="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
BASE_URL="http://127.0.0.1:$PORT"
GATEWAY_LOG="$TMP_DIR/gateway-dispatch.log"
"$REPO_ROOT/scripts/bin/orch-gateway" --project-id handoff-dispatch --host 127.0.0.1 --port "$PORT" >"$GATEWAY_LOG" 2>&1 &
GATEWAY_PID="$!"
trap 'kill "$GATEWAY_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

python3 - "$BASE_URL" "$GATEWAY_LOG" "$TMP_DIR/dispatch-create.json" "$TMP_DIR/dispatch-tasks.json" "$TMP_DIR/direct-advance.json" "$TMP_DIR/dispatch-response.json" <<'PY'
import json
import sys
import time
import urllib.error
import urllib.request

base_url, log_path, create_path, tasks_path, advance_path, dispatch_path = sys.argv[1:]
deadline = time.time() + 5
while time.time() < deadline:
    try:
        with urllib.request.urlopen(f"{base_url}/health", timeout=0.5) as response:
            if response.status == 200:
                break
    except Exception:
        time.sleep(0.1)
else:
    print(open(log_path, encoding="utf-8", errors="replace").read(), file=sys.stderr)
    raise SystemExit("gateway did not become healthy")

payload = {
    "idempotency_key": "handoff-dispatch-create",
    "ticket": {
        "background": "dispatch authority",
        "goal": "dispatch tasks through Gateway",
        "deliverables": ["dispatch token"],
        "acceptance_criteria": ["direct advance is blocked"],
        "hard_constraints": [],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "block"
    },
    "options": {"mode": "mvp_full"}
}
request = urllib.request.Request(f"{base_url}/orchestra/runs", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"}, method="POST")
with urllib.request.urlopen(request, timeout=5) as response:
    create = json.loads(response.read().decode())
with urllib.request.urlopen(f"{base_url}/orchestra/runs/{create['run_id']}/tasks", timeout=5) as response:
    tasks = json.loads(response.read().decode())
task = next(item for item in tasks["tasks"] if item["stage"] == "implementation")

advance_req = urllib.request.Request(
    f"{base_url}/orchestra/runs/{create['run_id']}/tasks/{task['task_id']}/advance",
    data=b"{}",
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    urllib.request.urlopen(advance_req, timeout=5)
except urllib.error.HTTPError as exc:
    direct = json.loads(exc.read().decode())
    assert exc.code == 400, exc.code
else:
    raise AssertionError("direct advance should fail")
assert direct["error"]["code"] == "dispatch_token_required", direct

dispatch_req = urllib.request.Request(
    f"{base_url}/orchestra/runs/{create['run_id']}/tasks/{task['task_id']}/dispatch",
    data=json.dumps({"actor": "codex"}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(dispatch_req, timeout=5) as response:
    dispatched = json.loads(response.read().decode())
assert response.status == 200
assert dispatched["dispatch_token"], dispatched
assert dispatched["computed_write_scope"], dispatched
assert dispatched["workspace_path"], dispatched

for path, body in [(create_path, create), (tasks_path, tasks), (advance_path, direct), (dispatch_path, dispatched)]:
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

test_done
