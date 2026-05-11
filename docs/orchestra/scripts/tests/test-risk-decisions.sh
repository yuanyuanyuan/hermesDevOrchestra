#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="risk-decisions"
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
echo resumed >> "${CODEX_RESUME_LOG:-/tmp/orch-codex-resume.log}"
printf '{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","status":"completed"}\n' > "$out"
SH
chmod +x "$FAKE_BIN/tmux" "$FAKE_BIN/codex"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"
export CODEX_RESUME_LOG="$TMP_DIR/codex-resume.log"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$HOME" "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-risk-decisions-init.out
RUNTIME_DIR="$RUNTIME_ROOT/test-proj"
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","description":"修改 JWT"}
JSON
cat > "$RUNTIME_DIR/codex-question.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","question":"Need approval"}
JSON
cat > "$RUNTIME_DIR/escalation.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","level":"L3","type":"SECURITY","details":"修改 JWT"}
JSON

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
pending_count="$(find "$STATE_ROOT/test-proj/pending-decisions" -name '*.json' | wc -l | tr -d ' ')"
assert_eq "1" "$pending_count" "escalation should create one pending decision"
[ ! -f "$CODEX_RESUME_LOG" ] || fail "no Codex resume before approval" "no Codex" "resumed"
approval_id="$(find "$STATE_ROOT/test-proj/pending-decisions" -name '*.json' -printf '%f\n' | sed 's/\.json$//')"
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-approve" "$approval_id" "approved fixture" >/tmp/orch-risk-approved.out
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
assert_file_exists "$CODEX_RESUME_LOG" "Codex should resume after user approval"
[ ! -f "$RUNTIME_DIR/escalation.md" ] || fail "approved escalation.md should be archived automatically" "archived" "still present"

rm -f "$CODEX_RESUME_LOG" "$RUNTIME_DIR/codex-result.md" "$RUNTIME_DIR/claude-decision.md"
rm -rf "$STATE_ROOT/test-proj/pending-decisions"
mkdir -p "$STATE_ROOT/test-proj/pending-decisions"
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-l4","correlation_id":"corr-l4","description":"git push origin main --force"}
JSON
cat > "$RUNTIME_DIR/codex-question.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-l4","correlation_id":"corr-l4","question":"Need L4 approval"}
JSON
cat > "$RUNTIME_DIR/escalation.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-l4","correlation_id":"corr-l4","level":"L4","type":"SECURITY","details":"git push origin main --force"}
JSON

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
l4_approval_id="$(find "$STATE_ROOT/test-proj/pending-decisions" -name '*.json' -printf '%f\n' | sed 's/\.json$//')"
set +e
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-approve" "$l4_approval_id" "approved fixture" >/tmp/orch-risk-l4-bad.out 2>/tmp/orch-risk-l4-bad.err
bad_phrase_status=$?
set -e
assert_exit_code 7 "$bad_phrase_status" "L4 approval should require fixed phrase"
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-approve" "$l4_approval_id" "APPROVE-L4 $l4_approval_id" >/tmp/orch-risk-l4-good.out
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
assert_file_exists "$CODEX_RESUME_LOG" "Codex should resume after exact L4 approval phrase"

rm -f "$CODEX_RESUME_LOG" "$RUNTIME_DIR/codex-result.md" "$RUNTIME_DIR/claude-decision.md"
rm -rf "$STATE_ROOT/test-proj/pending-decisions"
mkdir -p "$STATE_ROOT/test-proj/pending-decisions"
cat > "$RUNTIME_DIR/claude-decision.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-2","correlation_id":"corr-2","author":"claude","authority":"L2","level":"L2","decision":"APPROVED","details":"修改 JWT","assessment":{"assessed_level":"L2"},"execution":{"authority_sufficient":true}}
JSON
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-2","correlation_id":"corr-2","description":"修改 JWT"}
JSON
cat > "$RUNTIME_DIR/codex-question.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-2","correlation_id":"corr-2","question":"Need decision"}
JSON
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
find "$STATE_ROOT/test-proj/pending-decisions" -name '*.json' | grep -q . || fail "under-classified L2 with L3 text should create pending decision" "pending" "missing"
[ ! -f "$CODEX_RESUME_LOG" ] || fail "under-classified Claude decision must not resume Codex" "no Codex" "resumed"

test_done
