#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="make-upstream-status-advisory"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

RUNTIME_DIR="$TMP_DIR/hermes-agent"
mkdir -p "$RUNTIME_DIR"
git -C "$RUNTIME_DIR" init -q
git -C "$RUNTIME_DIR" config user.email test@example.invalid
git -C "$RUNTIME_DIR" config user.name "Test User"
git -C "$RUNTIME_DIR" commit --allow-empty -q -m "fake runtime pin"

OUTPUT="$TMP_DIR/upstream-status.out"
if ! HERMES_AGENT_DIR="$RUNTIME_DIR" make --no-print-directory -C "$REPO_ROOT" upstream-status >"$OUTPUT" 2>&1; then
    fail "upstream-status should be advisory by default" "exit 0" "$(cat "$OUTPUT")"
fi

assert_contains "status: mismatch" "$OUTPUT" "upstream-status should still report mismatch"

test_done
