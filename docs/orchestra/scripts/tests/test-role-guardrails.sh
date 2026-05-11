#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="role-guardrails"
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

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-role-guardrails-init.out

REVIEWER_CONFIG="$PROJECT_DIR/.hermes/projects/test-proj/profiles/reviewer/config.yaml"
ORCH_CONFIG="$PROJECT_DIR/.hermes/projects/test-proj/profiles/orchestrator/config.yaml"
HOOK="$REPO_ROOT/docs/orchestra/hermes/hooks/pre_tool_call-risk-gate.sh"

assert_contains "flags: --output-format json --allowedTools Read,Glob,Grep" "$REVIEWER_CONFIG" "reviewer CLI allowlist missing"
assert_contains "flags: --output-format json --allowedTools Read,Glob,Grep" "$ORCH_CONFIG" "orchestrator CLI allowlist missing"

set +e
HERMES_PROFILE_ROLE=reviewer HERMES_TOOL_NAME=terminal HERMES_TOOL_ARGS='cat secrets.env' "$HOOK" >"$TMP_DIR/reviewer-hook.json"
reviewer_status=$?
set -e
assert_exit_code 2 "$reviewer_status" "reviewer terminal should be blocked"
assert_contains '"source": "role_guardrail"' "$TMP_DIR/reviewer-hook.json" "reviewer hook source mismatch"

set +e
HERMES_PROFILE_ROLE=orchestrator HERMES_TOOL_NAME=Write HERMES_TOOL_ARGS='notes.md' "$HOOK" >"$TMP_DIR/orchestrator-hook.json"
orchestrator_status=$?
set -e
assert_exit_code 2 "$orchestrator_status" "orchestrator write should be blocked"
assert_contains '"role": "orchestrator"' "$TMP_DIR/orchestrator-hook.json" "orchestrator role missing"

set +e
HERMES_PROFILE_ROLE=implementer HERMES_TOOL_NAME=terminal HERMES_TOOL_ARGS='rm -rf /tmp/demo' "$HOOK" >"$TMP_DIR/implementer-hook.json"
implementer_status=$?
set -e
assert_exit_code 3 "$implementer_status" "implementer destructive terminal should be risk blocked"
assert_contains '"level": "L4"' "$TMP_DIR/implementer-hook.json" "implementer risk level missing"

test_done
