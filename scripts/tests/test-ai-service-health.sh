#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="ai-service-health"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "Testing AI service availability..."

# Test Claude CLI
echo "  Testing Claude CLI..."
CLAUDE_VERSION=$(claude --version 2>&1) || true
if [ -n "$CLAUDE_VERSION" ]; then
    echo "    ✓ Claude CLI available: $CLAUDE_VERSION"
else
    fail "Claude CLI should be available" "version string" "empty"
fi

# Test Codex CLI
echo "  Testing Codex CLI..."
CODEX_VERSION=$(codex --version 2>&1) || true
if [ -n "$CODEX_VERSION" ]; then
    echo "    ✓ Codex CLI available: $CODEX_VERSION"
else
    fail "Codex CLI should be available" "version string" "empty"
fi

# Test Hermes CLI
echo "  Testing Hermes CLI..."
HERMES_VERSION=$(hermes --version 2>&1) || true
if [ -n "$HERMES_VERSION" ]; then
    echo "    ✓ Hermes CLI available: $HERMES_VERSION"
else
    fail "Hermes CLI should be available" "version string" "empty"
fi

# Test Python AI libraries
echo "  Testing Python AI libraries..."
PYTHON_BIN="/data/hermes/.test-venv/bin/python3"
if [ -x "$PYTHON_BIN" ]; then
    "$PYTHON_BIN" -c "
import anthropic
import openai
print('    ✓ AI libraries available (anthropic={}, openai={})'.format(anthropic.__version__, openai.__version__))
" 2>&1
else
    fail "Python venv not found" ".test-venv/bin/python3" "missing"
fi

test_done
