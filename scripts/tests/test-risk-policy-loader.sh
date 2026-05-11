#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="risk-policy-loader"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
mkdir -p "$HOME/.hermes-orchestra"
cp "$REPO_ROOT/config/risk-policy.yaml" "$HOME/.hermes-orchestra/risk-policy.yaml"

SAFE_OUT="$TMP_DIR/safe.json"
L3_OUT="$TMP_DIR/l3.json"
L4_OUT="$TMP_DIR/l4.json"
ROLE_OUT="$TMP_DIR/role.json"

"$REPO_ROOT/scripts/bin/orch-risk-check" "echo hello" >"$SAFE_OUT"
safe_status=$?
assert_exit_code 0 "$safe_status" "safe command should stay below risk floor"
assert_contains '"level": "L0"' "$SAFE_OUT" "safe command level mismatch"

set +e
"$REPO_ROOT/scripts/bin/orch-risk-check" "docker system prune -af" >"$L3_OUT"
l3_status=$?
set -e
assert_exit_code 2 "$l3_status" "docker system prune should be L3"
assert_contains '"level": "L3"' "$L3_OUT" "L3 level missing"
assert_contains '"rule_id": "risk-system-prune"' "$L3_OUT" "L3 rule mismatch"
assert_contains '"approval_mode": "explicit"' "$L3_OUT" "L3 approval mode mismatch"

set +e
"$REPO_ROOT/scripts/bin/orch-risk-check" "git push origin main --force" >"$L4_OUT"
l4_status=$?
set -e
assert_exit_code 3 "$l4_status" "force push on main should be L4"
assert_contains '"level": "L4"' "$L4_OUT" "L4 level missing"
assert_contains 'APPROVE-L4 {approval_id}' "$L4_OUT" "L4 phrase template missing"

set +e
"$REPO_ROOT/scripts/bin/orch-risk-check" --role reviewer --tool terminal "ls -la" >"$ROLE_OUT"
role_status=$?
set -e
assert_exit_code 4 "$role_status" "reviewer terminal should be blocked by guardrail"
assert_contains '"source": "role_guardrail"' "$ROLE_OUT" "guardrail source missing"
assert_contains '"guardrail_blocked": true' "$ROLE_OUT" "guardrail block flag missing"

test_done
