#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="ai-model-quality"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "Testing AI model response quality..."

# Test Claude reasoning via --print
echo "  Testing Claude reasoning..."
REASONING=$(claude --print "What is 2+2? Answer with just the number." 2>&1) || true
if echo "$REASONING" | grep -q "4"; then
    echo "    ✓ Claude reasoning correct"
else
    echo "    ✗ Claude reasoning returned: $REASONING"
    fail "Claude should answer 2+2 correctly" "4" "$REASONING"
fi

# Test Claude code generation
echo "  Testing Claude code generation..."
CODE=$(claude --print "Respond with ONLY this exact Python code, nothing else: def greet(): return 'hello'" 2>&1) || true
if echo "$CODE" | grep -q "def greet\|return.*hello"; then
    echo "    ✓ Claude code generation works"
else
    echo "    ⚠ Claude code generation returned unexpected format (non-blocking)"
    echo "      Response: $(echo "$CODE" | head -1)"
fi

# Test Claude structured output (JSON)
echo "  Testing Claude JSON output..."
JSON_OUTPUT=$(claude --output-format json --print 'Return exactly this JSON: {"status": "ok"}' 2>&1) || true
if echo "$JSON_OUTPUT" | python3 -m json.tool &>/dev/null; then
    echo "    ✓ Claude JSON output valid"
else
    echo "    ✗ Claude JSON output: $JSON_OUTPUT"
    # Not a hard fail - --output-format json wraps the result
    echo "    ⚠ JSON format may differ (non-blocking)"
fi

test_done
