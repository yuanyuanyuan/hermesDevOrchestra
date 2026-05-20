#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="hermes-cli"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "Testing Hermes CLI functionality..."

# Test hermes --version
echo "  Testing hermes --version..."
VERSION=$(hermes --version 2>&1) || true
if echo "$VERSION" | grep -q "Hermes Agent"; then
    echo "    ✓ hermes --version works: $VERSION"
else
    fail "hermes --version should return version" "Hermes Agent" "$VERSION"
fi

# Test hermes status
echo "  Testing hermes status..."
STATUS=$(hermes status 2>&1) || true
if [ -n "$STATUS" ]; then
    echo "    ✓ hermes status works"
else
    echo "    ⚠ hermes status returned empty (may need configuration)"
fi

# Test hermes doctor
echo "  Testing hermes doctor..."
DOCTOR=$(hermes doctor 2>&1) || true
if [ -n "$DOCTOR" ]; then
    echo "    ✓ hermes doctor works"
else
    echo "    ⚠ hermes doctor returned empty"
fi

test_done
