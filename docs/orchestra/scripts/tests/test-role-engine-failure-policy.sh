#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="role-engine-failure-policy"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

ROOT="$REPO_ROOT/docs/orchestra/hermes/role-engine-protocol/v1"

assert_contains "parse_error" "$ROOT/common-envelope.md" "parse_error policy missing"
assert_contains "schema_mismatch" "$ROOT/common-envelope.md" "schema_mismatch policy missing"
assert_contains "retry the primary engine once" "$ROOT/common-envelope.md" "retry policy missing"
assert_contains "single fallback invocation is allowed only if the role profile explicitly declares" "$ROOT/common-envelope.md" "fallback policy missing"

python3 - "$ROOT" <<'PY'
import json
import os
import sys

root = sys.argv[1]


def load(name):
    with open(os.path.join(root, "examples", name), encoding="utf-8") as handle:
        return json.load(handle)


timeout_retry = load("timeout.retry.json")
assert timeout_retry["failure_class"] == "timeout"
assert timeout_retry["attempt_number"] == 1
assert timeout_retry["normalized_action"] == "retry_primary"
assert timeout_retry["block_task"] is False

crash_block = load("crash.block.json")
assert crash_block["failure_class"] == "crash"
assert crash_block["attempt_number"] == 2
assert crash_block["fallback_declared"] is False
assert crash_block["normalized_action"] == "block"
assert crash_block["block_task"] is True

rate_limit_fallback = load("rate_limit.fallback.json")
assert rate_limit_fallback["failure_class"] == "rate_limit"
assert rate_limit_fallback["attempt_number"] == 2
assert rate_limit_fallback["fallback_declared"] is True
assert rate_limit_fallback["normalized_action"] == "invoke_fallback_once"
audit = rate_limit_fallback["audit_event"]
assert audit["original_engine"]
assert audit["fallback_engine"]
assert audit["trigger_reason"] == "rate_limit"

for name in ("parse_error.block.json", "schema_mismatch.block.json"):
    case = load(name)
    assert case["normalized_action"] == "block"
    assert case["block_task"] is True
    assert case["hard_stop"] is True
    assert case["attempt_number"] == 1
PY

test_done
