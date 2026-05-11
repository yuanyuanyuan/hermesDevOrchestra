#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="mvp-acceptance"
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

PROJECT_ID="mvp-acceptance"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null
RUNTIME_DIR="$RUNTIME_ROOT/$PROJECT_ID"
STATE_DIR="$STATE_ROOT/$PROJECT_ID"

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

cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"pm","task_type":"requirement_doc","project_workspace":"/tmp/work","task_id":"pm-accept-1","task_body":"Define login task chain","task_summary":"Acceptance PM task","current_stage":"planning","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"pm","correlation_id":"pm-accept-corr","turn":1,"task_id":"pm-accept-1","status":"requirement_ready","next_action":"create_tasks","role_specific_payload":{"requirement_summary":"Login flow ready"},"tasks":[{"id":"T1","title":"Implement login API","assignee":"implementer","body":"Ship login endpoint","expected_duration_max":"30min","acceptance_criteria":["200 on valid login"],"parents":[]},{"id":"T2","title":"Review login API","assignee":"reviewer","body":"Review auth code","parents":["T1"]}],"conversation_context":[]}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" "$PROJECT_ID" "$PROJECT_DIR" --once
assert_eq "implementer" "$(json_field "$RUNTIME_DIR/task.md" "role")" "pm should hand off to implementer"
assert_eq "30min" "$(json_field "$RUNTIME_DIR/task.md" "expected_duration_max")" "planned expected duration should be preserved"
IMPLEMENTER_TASK_ID="$(json_field "$RUNTIME_DIR/task.md" "task_id")"

cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"impl-accept-corr","turn":2,"status":"task_complete","next_action":"complete","role_specific_payload":{"summary":"Implementation shipped","behaviors":[{"name":"login-api","test":"npm test -- login","status":"passed"}],"regression":{"commands":["npm test"],"passed":12,"failed":0},"changed_files":["src/login.ts"],"decisions":["keep token issuance server-side"],"pitfalls":["requires QA for visible login flow"]},"conversation_context":[]}
JSON
python3 - "$RUNTIME_DIR/codex-result.md" "$IMPLEMENTER_TASK_ID" <<'PY'
import json
import sys

path, task_id = sys.argv[1:]
data = json.load(open(path, encoding="utf-8"))
data["task_id"] = task_id
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" "$PROJECT_ID" "$PROJECT_DIR" --once
assert_eq "reviewer" "$(json_field "$RUNTIME_DIR/task.md" "role")" "implementer should hand off to reviewer"
assert_eq "untrusted" "$(json_field "$RUNTIME_DIR/task.md" "handoff_from_parent.trust_level")" "reviewer should treat handoff as untrusted"
REVIEW_TASK_ID="$(json_field "$RUNTIME_DIR/task.md" "task_id")"

cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"reviewer","correlation_id":"review-accept-corr","turn":3,"status":"approved","next_action":"complete","role_specific_payload":{"summary":"Approved with visible login change","behaviors":[{"name":"review-pass","test":"manual review","status":"passed"}],"regression":{"commands":["npm test"],"passed":12,"failed":0},"changed_files":["src/login.ts"],"decisions":["run QA for visible flow"],"pitfalls":["smoke login UI once"],"user_visible_change":true},"conversation_context":[]}
JSON
python3 - "$RUNTIME_DIR/codex-result.md" "$REVIEW_TASK_ID" <<'PY'
import json
import sys

path, task_id = sys.argv[1:]
data = json.load(open(path, encoding="utf-8"))
data["task_id"] = task_id
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" "$PROJECT_ID" "$PROJECT_DIR" --once
assert_eq "qa-tester" "$(json_field "$RUNTIME_DIR/task.md" "role")" "reviewer approval with visible change should hand off to qa"
assert_eq "qa_handoff" "$(json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow state should reach qa handoff"
assert_eq "20min" "$(json_field "$RUNTIME_DIR/task.md" "expected_duration_max")" "qa child should receive default expected duration"

test_done
