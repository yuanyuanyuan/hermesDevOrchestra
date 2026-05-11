#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="kanban-handoff"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

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
  "$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" "$project_id" "$PROJECT_DIR" >/dev/null
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
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" handoff-review "$PROJECT_DIR" --once
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
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" handoff-qa "$PROJECT_DIR" --once
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
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" handoff-findings "$PROJECT_DIR" --once
assert_eq "implementer" "$(json_field "$RUNTIME_DIR/task.md" "role")" "review findings should create implementer follow-up child"
assert_eq "followup_handoff" "$(json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow_state should mark implementer follow-up"
assert_eq "review-task-2" "$(json_field "$RUNTIME_DIR/task.md" "parents.0")" "follow-up child should link back to reviewer parent"
python3 - "$STATE_DIR/current-task.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["handoff_ref"]
PY

test_done
