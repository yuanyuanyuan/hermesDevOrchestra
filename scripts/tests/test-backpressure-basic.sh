#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="backpressure-basic"
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
  exit 0
fi
exit 0
SH
cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
echo invoked > "${CODEX_MARKER:?}"
exit 0
SH
chmod +x "$FAKE_BIN/tmux" "$FAKE_BIN/codex"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
export CODEX_MARKER="$TMP_DIR/codex-invoked.txt"
mkdir -p "$HOME"

PROJECT_ID="backpressure-proj"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

cat > "$RUNTIME_ROOT/$PROJECT_ID/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","task_type":"implementation","project_workspace":"/tmp/work","task_id":"impl-bp-1","task_body":"Blocked by queue pressure","task_summary":"Backpressure task","current_stage":"implementation","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON

cat > "$STATE_ROOT/$PROJECT_ID/task-graph.json" <<'JSON'
{"project_id":"backpressure-proj","tasks":[
  {"task_id":"impl-bp-1","role":"implementer","state":"ready"},
  {"task_id":"impl-bp-2","role":"implementer","state":"ready"},
  {"task_id":"impl-bp-3","role":"implementer","state":"ready"}
]}
JSON

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" "$PROJECT_ID" "$PROJECT_DIR" --once

[ ! -f "$CODEX_MARKER" ] || fail "dispatch should pause before invoking codex under backpressure" "codex not invoked" "codex invoked"
assert_file_exists "$STATE_ROOT/$PROJECT_ID/backpressure.json" "backpressure state file should be written"
assert_contains "backpressure paused" "$STATE_ROOT/$PROJECT_ID/current-task.json" "project state should record backpressure pause"

test_done
