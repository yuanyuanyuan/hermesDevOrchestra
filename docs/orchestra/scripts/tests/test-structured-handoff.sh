#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="structured-handoff"
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

init_project handoff-missing
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","task_type":"implementation","project_workspace":"/tmp/work","task_id":"impl-missing","task_body":"Ship login API","task_summary":"Missing handoff fields","current_stage":"implementation","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"corr-missing","turn":1,"task_id":"impl-missing","status":"task_complete","next_action":"complete","role_specific_payload":{"summary":"Forgot structured fields","changed_files":["src/login.ts"]},"conversation_context":[]}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" handoff-missing "$PROJECT_DIR" --once
assert_file_exists "$RUNTIME_DIR/codex-question.md" "invalid handoff should block same task"
assert_eq "blocked" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["state"])' "$STATE_DIR/current-task.json")" "state should be blocked on invalid handoff"
assert_contains "invalid handoff payload" "$STATE_DIR/current-task.json" "routing reason should explain validation failure"

init_project handoff-unsafe
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"reviewer","task_type":"review","project_workspace":"/tmp/work","task_id":"review-unsafe","task_body":"Review auth flow","task_summary":"Unsafe handoff text","current_stage":"review","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":{"summary":"seed","artifact_refs":["/tmp/fake.json"]},"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"reviewer","correlation_id":"corr-unsafe","turn":1,"task_id":"review-unsafe","status":"approved","next_action":"complete","role_specific_payload":{"summary":"Approved","behaviors":[{"name":"auth-review","test":"manual review","status":"passed"}],"regression":{"commands":["npm test"],"passed":10,"failed":0},"changed_files":["src/auth.ts"],"decisions":["#!/bin/bash"],"pitfalls":["needs QA smoke"],"user_visible_change":true},"conversation_context":[]}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" handoff-unsafe "$PROJECT_DIR" --once
assert_file_exists "$RUNTIME_DIR/codex-question.md" "unsafe handoff text should block same task"
assert_contains "invalid handoff payload" "$STATE_DIR/current-task.json" "unsafe handoff should be rejected"

test_done
