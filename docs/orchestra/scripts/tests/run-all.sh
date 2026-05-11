#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0

shopt -s nullglob
for test_script in "$TEST_DIR"/test-*.sh; do
    if bash "$test_script"; then
        echo "PASS $test_script"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL $test_script"
        FAILED=$((FAILED + 1))
    fi
done

echo "Smoke summary: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
