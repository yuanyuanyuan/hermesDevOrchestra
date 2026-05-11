#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="kanban-routing"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/tmux" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "send-keys" ]; then
  for arg in "$@"; do
    case "$arg" in
      bash\ *) eval "$arg" ;;
    esac
  done
fi
exit 0
SH
cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output-last-message" ]; then out="$2"; shift 2; else shift; fi
done
stdin="$(cat)"
task_id="$(printf '%s\n' "$stdin" | sed -n 's/.*"task_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$task_id" ] || task_id="task-unknown"
printf '{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"corr-resume","turn":2,"status":"task_complete","next_action":"complete","task_id":"%s","role_specific_payload":{"summary":"resumed task","behaviors":[{"name":"resume-path","test":"true","status":"passed"}],"regression":{"commands":["true"],"passed":1,"failed":0},"changed_files":[],"decisions":["resume after approval"],"pitfalls":["requires explicit user approval"]},"conversation_context":[]}\n' "$task_id" > "$out"
SH
chmod +x "$FAKE_BIN/tmux" "$FAKE_BIN/codex"

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
  AUDIT_DIR="$AUDIT_ROOT/$project_id"
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

init_project route-research
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"pm","task_type":"clarification","project_workspace":"/tmp/work","task_id":"pm-task-1","task_body":"Clarify auth flow","task_summary":"Auth PM task","current_stage":"clarification","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"pm","correlation_id":"pm-corr-1","turn":1,"task_id":"pm-task-1","status":"needs_research","next_action":"create_research_task","research":{"topic":"compare auth options"},"role_specific_payload":{"summary":"Need to compare auth options first","research_triggers":["comparison"]},"conversation_context":[]}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" route-research "$PROJECT_DIR" --once
assert_eq "researcher" "$(json_field "$RUNTIME_DIR/task.md" "role")" "pm needs_research should create researcher child"
assert_eq "research_handoff" "$(json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow_state should mark research handoff"
assert_contains "research-required:" "$STATE_DIR/current-task.json" "routing reason should use research-required prefix"
python3 - "$STATE_DIR/task-graph.json" <<'PY'
import json, sys
graph = json.load(open(sys.argv[1], encoding="utf-8"))
roles = {task["role"] for task in graph["tasks"]}
assert "pm" in roles
assert "researcher" in roles
research = next(task for task in graph["tasks"] if task["role"] == "researcher")
assert research["parents"] == ["pm-task-1"]
PY

init_project route-skeleton
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"pm","task_type":"requirement_doc","project_workspace":"/tmp/work","task_id":"pm-task-2","task_body":"Define login tasks","task_summary":"Login PM task","current_stage":"planning","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"pm","correlation_id":"pm-corr-2","turn":2,"task_id":"pm-task-2","status":"requirement_ready","next_action":"create_tasks","role_specific_payload":{"requirement_summary":"Login flow ready"},"tasks":[{"id":"T1","title":"Implement login API","assignee":"implementer","body":"Ship login endpoint","acceptance_criteria":["200 on valid login"],"parents":[]},{"id":"T2","title":"Review login API","assignee":"reviewer","body":"Review auth code","parents":["T1"]}],"conversation_context":[]}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" route-skeleton "$PROJECT_DIR" --once
assert_eq "implementer" "$(json_field "$RUNTIME_DIR/task.md" "role")" "pm requirement_ready should queue implementer task"
assert_eq "task_graph_ready" "$(json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow_state should mark skeleton graph creation"
python3 - "$STATE_DIR/task-graph.json" <<'PY'
import json, sys
graph = json.load(open(sys.argv[1], encoding="utf-8"))
roles = {task["role"] for task in graph["tasks"]}
assert "implementer" in roles
assert "reviewer" in roles
implementer = next(task for task in graph["tasks"] if task["role"] == "implementer")
assert implementer["parents"] == ["pm-task-2"]
PY

init_project route-resume
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","task_type":"implementation","project_workspace":"/tmp/work","task_id":"impl-task-1","task_body":"Implement auth persistence","task_summary":"Implement auth persistence","current_stage":"implementation","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"impl-corr-1","turn":1,"task_id":"impl-task-1","status":"blocked","next_action":"block","role_specific_payload":{"block_reason":"waiting on migration ordering","suggested_unblock_action":"confirm migration order"},"conversation_context":[]}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" route-resume "$PROJECT_DIR" --once
assert_file_exists "$RUNTIME_DIR/codex-question.md" "implementer block should leave a question artifact for unblock"
assert_eq "impl-task-1" "$(json_field "$STATE_DIR/current-task.json" "task_id")" "same-role block should keep original task id"
assert_eq "task:impl-task-1" "$(json_field "$STATE_DIR/current-task.json" "resume_target")" "resume target should point to original task"
assert_contains "needs-review:" "$STATE_DIR/current-task.json" "blocked routing should use normalized needs-review prefix"
cat > "$RUNTIME_DIR/claude-decision.md" <<'JSON'
{"schema_version":"1.0","project_id":"route-resume","task_id":"impl-task-1","correlation_id":"impl-corr-1","status":"decision","author":"user","authority":"L1","decision":"APPROVED","execution":{"authority_sufficient":true}}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" route-resume "$PROJECT_DIR" --once
assert_file_exists "$RUNTIME_DIR/codex-result.md" "resume path should continue the same task"
assert_eq "impl-task-1" "$(json_field "$RUNTIME_DIR/codex-result.md" "task_id")" "continued execution should preserve the original task id"

test_done
