#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="worker-lifecycle-timeout"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/lib/orch-common.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  has-session) exit 0 ;;
  list-panes) echo 0; exit 0 ;;
  send-keys) exit 0 ;;
esac
exit 0
SH
chmod +x "$FAKE_BIN/tmux"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="timeout-proj"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null
orch_project_dirs "$PROJECT_ID"

WORKSPACE="$RUNTIME_DIR/workspaces/impl-timeout"
mkdir -p "$WORKSPACE"
echo "dirty" > "$WORKSPACE/junk.txt"

cat > "$RUNTIME_DIR/task.md" <<JSON
{"protocol":"hermes-role-engine/v1","role":"implementer","task_type":"implementation","project_workspace":"$WORKSPACE","task_id":"impl-timeout","task_body":"Ship timeout-safe task","task_summary":"Timeout task","current_stage":"implementation","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{},"expected_duration_max":"1s"}
JSON

orch_write_active_run "impl-timeout" "implementer" "tmux_session" "hermes-timeout-codex" "$WORKSPACE" "1s" "" "codex"
python3 - "$(orch_active_run_file)" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["started_at_epoch"] -= 30
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

"$REPO_ROOT/scripts/bin/orch-bus-loop" "$PROJECT_ID" "$PROJECT_DIR" --once

[ ! -f "$WORKSPACE/junk.txt" ] || fail "workspace should be cleaned on timeout reclaim" "junk removed" "junk still present"
[ ! -f "$(orch_active_run_file)" ] || fail "active run should be cleared after reclaim" "missing active run file" "still present"
assert_eq "queued" "$(orch_json_field "$STATE_DIR/current-task.json" "state")" "timed out task should return to queued state"
assert_eq "reclaim_ready" "$(orch_json_field "$STATE_DIR/current-task.json" "workflow_state")" "workflow state should mark reclaim readiness"
assert_contains "timed_out reclaim" "$STATE_DIR/current-task.json" "routing reason should record timeout reclaim"

python3 - "$(orch_trace_db_file)" <<'PY'
import sqlite3
import sys

conn = sqlite3.connect(sys.argv[1])
count = conn.execute("select count(*) from lifecycle_events where status = 'timed_out'").fetchone()[0]
assert count == 1
conn.close()
PY

test_done
