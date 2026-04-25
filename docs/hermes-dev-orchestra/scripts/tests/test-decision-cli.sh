#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="decision-cli"
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

source "$REPO_ROOT/docs/hermes-dev-orchestra/scripts/lib/orch-common.sh"
orch_project_dirs test-proj
mkdir -p "$RUNTIME_DIR" "$STATE_DIR" "$AUDIT_DIR"
id_approve="$(orch_create_pending_decision L3 SECURITY "Approve this" task-1 esc-1 escalation-handler)"
id_reject="$(orch_create_pending_decision L4 SECURITY "Reject this" task-2 esc-2 escalation-handler)"

"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-decisions" test-proj > /tmp/orch-decision-cli-list.out
assert_contains "$id_approve" /tmp/orch-decision-cli-list.out "orch-decisions missing approval id"
assert_contains "$id_reject" /tmp/orch-decision-cli-list.out "orch-decisions missing rejection id"
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_approve" "APPROVED fixture" >/tmp/orch-decision-cli-approve.out
assert_contains "APPROVED $id_approve" /tmp/orch-decision-cli-approve.out "approval output missing"
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-reject" "$id_reject" "REJECTED fixture" >/tmp/orch-decision-cli-reject.out
assert_contains "REJECTED $id_reject" /tmp/orch-decision-cli-reject.out "rejection output missing"

set +e
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-decisions" "../outside" >/tmp/orch-decision-cli-traversal.out 2>&1
decisions_traversal=$?
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-audit" "../outside" >/tmp/orch-audit-traversal.out 2>&1
audit_traversal=$?
set -e
[ "$decisions_traversal" -ne 0 ] || fail "orch-decisions must reject project path traversal" "non-zero" "$decisions_traversal"
[ "$audit_traversal" -ne 0 ] || fail "orch-audit must reject project path traversal" "non-zero" "$audit_traversal"

test_done
