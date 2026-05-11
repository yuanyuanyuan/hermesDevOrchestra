#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="file-bus"
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
stdin="$(cat)"
if printf '%s' "$stdin" | grep -q "Continue the task"; then
  printf '{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","status":"completed","author":"codex"}\n' > "$out"
else
  question="$(printf '%s' "$stdin" | sed -n "s/.*to \\([^ ]*codex-question.md\\).*/\\1/p" | head -1)"
  printf '{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","status":"question","author":"codex","question":"Need decision"}\n' > "$question"
fi
SH
cat > "$FAKE_BIN/claude" <<'SH'
#!/usr/bin/env bash
if printf '%s ' "$@" | grep -q "Review the Codex result"; then
  printf '{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","decision":"APPROVED","author":"claude"}\n'
else
  printf '{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","author":"claude","authority":"L2","level":"L2","decision":"APPROVED","assessment":{"assessed_level":"L2"},"execution":{"authority_sufficient":true}}\n'
fi
SH
chmod +x "$FAKE_BIN/tmux" "$FAKE_BIN/codex" "$FAKE_BIN/claude"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$HOME" "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null

"$REPO_ROOT/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-file-bus-init.out
RUNTIME_DIR="$RUNTIME_ROOT/test-proj"
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","status":"queued","author":"hermes","authority":"orchestrator","description":"fixture"}
JSON

for _ in 1 2 3 4; do
  "$REPO_ROOT/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
done
assert_file_exists "$RUNTIME_DIR/codex-question.md" "codex-question.md not created"
assert_file_exists "$RUNTIME_DIR/claude-decision.md" "claude-decision.md not created"
assert_file_exists "$RUNTIME_DIR/codex-result.md" "codex-result.md not created"
assert_file_exists "$RUNTIME_DIR/review-result.md" "review-result.md not created"
"$REPO_ROOT/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
find "$AUDIT_ROOT/test-proj/archive" -name archive-manifest.json | grep -q . || fail "archive-manifest.json missing" "manifest" "missing"

cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-stale","correlation_id":"corr-stale","status":"queued","author":"hermes","authority":"orchestrator","description":"stale review guard"}
JSON
cat > "$RUNTIME_DIR/review-result.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","decision":"APPROVED","author":"claude"}
JSON
"$REPO_ROOT/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
assert_file_exists "$RUNTIME_DIR/task.md" "stale review without task_id must not consume current task"
[ ! -f "$RUNTIME_DIR/review-result.md" ] || fail "stale review should be quarantined" "quarantined" "still present"

test_done
