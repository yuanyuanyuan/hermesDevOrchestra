#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="env-snapshot"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

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
printf '{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"snap-corr","turn":1,"task_id":"impl-snapshot","status":"task_complete","next_action":"complete","role_specific_payload":{"summary":"snapshot ok","behaviors":[{"name":"snapshot","test":"true","status":"passed"}],"regression":{"commands":["true"],"passed":1,"failed":0},"changed_files":[],"decisions":["captured snapshot"],"pitfalls":["none"]},"conversation_context":[]}\n' > "$out"
SH
cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "status" ]; then
  echo "hermes status ok"
  exit 0
fi
echo "hermes test"
exit 0
SH
chmod +x "$FAKE_BIN/tmux" "$FAKE_BIN/codex" "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="snapshot-proj"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

cat > "$RUNTIME_ROOT/$PROJECT_ID/task.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","task_type":"implementation","project_workspace":"/tmp/work","task_id":"impl-snapshot","task_body":"Capture snapshot","task_summary":"Snapshot task","current_stage":"implementation","conversation_history":{"summary":"seed","recent_turns":[]},"handoff_from_parent":null,"last_engine_error":null,"rollback_count":0,"instructions":{}}
JSON

"$REPO_ROOT/scripts/bin/orch-bus-loop" "$PROJECT_ID" "$PROJECT_DIR" --once

ACTIVE_RUN="$STATE_ROOT/$PROJECT_ID/active-run.json"
assert_file_exists "$ACTIVE_RUN" "dispatch should create active run manifest"
SNAPSHOT_PATH="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["snapshot_path"])' "$ACTIVE_RUN")"
assert_file_exists "$SNAPSHOT_PATH" "env snapshot file should exist"
assert_contains "git_status" "$SNAPSHOT_PATH" "snapshot should record git status"
assert_contains "disk_free" "$SNAPSHOT_PATH" "snapshot should record disk usage"
assert_contains "hermes status ok" "$SNAPSHOT_PATH" "snapshot should record hermes status"

python3 - "$AUDIT_ROOT/$PROJECT_ID/observability_trace.db" <<'PY'
import sqlite3
import sys

conn = sqlite3.connect(sys.argv[1])
row = conn.execute("select count(*) from env_snapshots").fetchone()
assert row[0] == 1
conn.close()
PY

test_done
