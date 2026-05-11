#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="implementer-block-contract"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"
mkdir -p "$HOME"

PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-impl-block-init.out
RUNTIME_DIR="$RUNTIME_ROOT/test-proj"
STATE_DIR="$STATE_ROOT/test-proj"

cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"impl-arch","role":"implementer","correlation_id":"corr-arch","description":"Need to continue implementation"}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"corr-arch","turn":1,"task_id":"impl-arch","status":"blocked","next_action":"block","role_specific_payload":{"block_category":"architecture-decision","block_reason":"Need architecture sign-off for schema split","suggested_unblock_action":"Confirm schema direction"},"conversation_context":[]}
JSON

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
assert_contains 'architecture-decision: Need architecture sign-off for schema split' "$STATE_DIR/current-task.json" "architecture block category missing from routing state"
assert_contains '"block_category":"architecture-decision"' "$RUNTIME_DIR/codex-question.md" "architecture block category should survive handoff"

rm -f "$RUNTIME_DIR/codex-question.md" "$RUNTIME_DIR/claude-decision.md" "$STATE_DIR/last-result.hash" "$STATE_DIR/last-question.hash" "$STATE_DIR/last-decision.hash"
cat > "$RUNTIME_DIR/task.md" <<'JSON'
{"schema_version":"1.0","project_id":"test-proj","task_id":"impl-test","role":"implementer","correlation_id":"corr-test","description":"Need to continue implementation"}
JSON
cat > "$RUNTIME_DIR/codex-result.md" <<'JSON'
{"protocol":"hermes-role-engine/v1","role":"implementer","correlation_id":"corr-test","turn":1,"task_id":"impl-test","status":"test_failed","next_action":"block","role_specific_payload":{"block_reason":"pytest failed on auth regression","suggested_unblock_action":"Fix regression and rerun pytest"},"conversation_context":[]}
JSON

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
assert_contains 'critical-test-failure: pytest failed on auth regression' "$STATE_DIR/current-task.json" "test failure category should be inferred"

test_done
