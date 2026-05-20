#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "  Hermes Orchestra AI Integration Tests"
echo "========================================="
echo ""

PASSED=0
FAILED=0
ERRORS=()

run_test() {
    local name="$1"
    local script="$2"
    echo "--- $name ---"
    if bash "$SCRIPT_DIR/$script" 2>&1; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        ERRORS+=("$name")
    fi
    echo ""
}

# Phase 1: AI Service Health
run_test "Phase 1: AI Service Health" "test-ai-service-health.sh"
run_test "Phase 1: AI Model Quality" "test-ai-model-quality.sh"

# Phase 2: CLI Tools
run_test "Phase 2: Hermes CLI" "test-hermes-cli.sh"
run_test "Phase 2: Codex CLI" "test-codex-cli.sh"
run_test "Phase 2: Claude CLI" "test-claude-cli.sh"

# Phase 3: Module Integration
run_test "Phase 3: Debate Engine" "test-debate-engine-ai.sh"
run_test "Phase 3: Worker Execution" "test-worker-ai-execution.sh"
run_test "Phase 3: Gateway Integration" "test-gateway-ai-integration.sh"

echo "========================================="
echo "  Results: $PASSED passed, $FAILED failed"
echo "========================================="

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
    exit 1
fi

echo ""
echo "All AI integration tests passed!"
