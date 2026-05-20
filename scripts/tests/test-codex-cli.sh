#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="codex-cli"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "Testing Codex CLI functionality..."

# Test codex --version
echo "  Testing codex --version..."
VERSION=$(codex --version 2>&1) || true
if [ -n "$VERSION" ]; then
    echo "    ✓ codex --version works: $VERSION"
else
    fail "codex --version should return version" "version string" "empty"
fi

# Test codex --help
echo "  Testing codex --help..."
HELP=$(codex --help 2>&1) || true
if echo "$HELP" | grep -qi "usage\|codex"; then
    echo "    ✓ codex --help works"
else
    echo "    ✗ codex --help failed: $HELP"
    fail "codex --help should show usage" "Usage/Codex" "$HELP"
fi

test_done
