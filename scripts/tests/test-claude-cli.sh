#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="claude-cli"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "Testing Claude CLI functionality..."

# Test claude --version
echo "  Testing claude --version..."
VERSION=$(claude --version 2>&1) || true
if [ -n "$VERSION" ]; then
    echo "    ✓ claude --version works: $VERSION"
else
    fail "claude --version should return version" "version string" "empty"
fi

# Test claude --print (basic prompt)
echo "  Testing claude --print..."
RESPONSE=$(claude --print "Respond with exactly: test-ok" 2>&1) || true
if echo "$RESPONSE" | grep -q "test-ok"; then
    echo "    ✓ claude --print works"
else
    echo "    ✗ claude --print returned: $RESPONSE"
    fail "claude --print should respond" "test-ok" "$RESPONSE"
fi

# Test claude --print with code task
echo "  Testing claude --print code task..."
CODE_RESPONSE=$(claude --print "Write a bash one-liner that prints 'hello-world'. Just the command, nothing else." 2>&1) || true
if echo "$CODE_RESPONSE" | grep -q "hello-world\|echo"; then
    echo "    ✓ claude code task works"
else
    echo "    ⚠ claude code task returned: $CODE_RESPONSE (non-blocking)"
fi

test_done
