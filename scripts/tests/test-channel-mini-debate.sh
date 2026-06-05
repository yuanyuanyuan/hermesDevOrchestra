#!/usr/bin/env bash
# Test: Channel Mini-Debate
# Tests mini-debate orchestration for Quick and Light channels

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Add lib directory to Python path
export PYTHONPATH="${REPO_ROOT}/scripts/lib:${PYTHONPATH:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${RED}✗ FAIL${NC}: $1"
}

echo "=========================================="
echo "Test: Channel Mini-Debate"
echo "=========================================="
echo ""

# Test 1: Import mini-debate module
echo "Test 1: Import mini-debate module"
if python3 -c "from mini_debate_orchestration import create_mini_debate_request, execute_mini_debate, persist_mini_debate_refs, validate_mini_debate, check_auto_merge_blocked, MiniDebateTimeoutError, MiniDebateConsensusError, MissingDebateReportError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Quick channel config
echo ""
echo "Test 2: Quick channel config"
RESULT=$(python3 -c "
from mini_debate_orchestration import get_mini_debate_config
config = get_mini_debate_config('quick')
print(config['max_rounds'] == 1 and config['timeout_minutes'] == 10)
")
if [ "$RESULT" = "True" ]; then
    pass "Quick channel config correct"
else
    fail "Quick channel config incorrect"
fi

# Test 3: Light channel config
echo ""
echo "Test 3: Light channel config"
RESULT=$(python3 -c "
from mini_debate_orchestration import get_mini_debate_config
config = get_mini_debate_config('light')
print(config['max_rounds'] == 2 and config['timeout_minutes'] == 20)
")
if [ "$RESULT" = "True" ]; then
    pass "Light channel config correct"
else
    fail "Light channel config incorrect"
fi

# Test 4: Standard channel config
echo ""
echo "Test 4: Standard channel config"
RESULT=$(python3 -c "
from mini_debate_orchestration import get_mini_debate_config
config = get_mini_debate_config('standard')
print(config['max_rounds'] == 3 and config['timeout_minutes'] == 60)
")
if [ "$RESULT" = "True" ]; then
    pass "Standard channel config correct"
else
    fail "Standard channel config incorrect"
fi

# Test 5: Create mini-debate request
echo ""
echo "Test 5: Create mini-debate request"
RESULT=$(python3 -c "
from mini_debate_orchestration import create_mini_debate_request
request = create_mini_debate_request('run-1', 'task-1', 'quick', 'Fix typo', ['README.md'])
print(request['channel'] == 'quick' and request['max_rounds'] == 1)
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate request created correctly"
else
    fail "Mini-debate request creation failed"
fi

# Test 6: Execute mini-debate - success
echo ""
echo "Test 6: Execute mini-debate - success"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate
run = {'run_id': 'run-1'}
request = {'run_id': 'run-1', 'task_id': 'task-1', 'channel': 'quick'}
report = execute_mini_debate(run, request, debate_backend_available=True)
print(report['status'] == 'completed' and report['consensus_score'] >= 0.8)
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate executed successfully"
else
    fail "Mini-debate execution failed"
fi

# Test 7: Execute mini-debate - backend unavailable
echo ""
echo "Test 7: Execute mini-debate - backend unavailable"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate
run = {'run_id': 'run-2'}
request = {'run_id': 'run-2', 'task_id': 'task-2', 'channel': 'light'}
report = execute_mini_debate(run, request, debate_backend_available=False)
print(report['status'] == 'degraded' and report['degradation_reason'] == 'debate_backend_unavailable')
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate degraded when backend unavailable"
else
    fail "Mini-debate degradation handling failed"
fi

# Test 8: Persist mini-debate refs
echo ""
echo "Test 8: Persist mini-debate refs"
RESULT=$(python3 -c "
from mini_debate_orchestration import persist_mini_debate_refs
run = {'run_id': 'run-3'}
report = {'debate_refs': ['debate://run-3/mini/123'], 'channel': 'quick', 'debate_type': 'confirmation', 'status': 'completed', 'consensus_score': 0.9, 'required_consensus': 0.8, 'completed_at': '2026-01-01T00:00:00Z'}
updated = persist_mini_debate_refs(run, report)
print('debate://run-3/mini/123' in updated['mini_debate_refs'])
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate refs persisted correctly"
else
    fail "Mini-debate refs persistence failed"
fi

# Test 9: Validate mini-debate - valid
echo ""
echo "Test 9: Validate mini-debate - valid"
RESULT=$(python3 -c "
from mini_debate_orchestration import validate_mini_debate
run = {'run_id': 'run-4', 'mini_debate_status': {'status': 'completed', 'consensus_score': 0.9}}
errors = validate_mini_debate(run)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid mini-debate passes validation"
else
    fail "Valid mini-debate fails validation"
fi

# Test 10: Validate mini-debate - missing status
echo ""
echo "Test 10: Validate mini-debate - missing status"
RESULT=$(python3 -c "
from mini_debate_orchestration import validate_mini_debate
run = {'run_id': 'run-5'}
errors = validate_mini_debate(run)
print('mini_debate_status missing' in errors)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing mini_debate_status detected"
else
    fail "Missing mini_debate_status not detected"
fi

# Test 11: Auto-merge blocked for quick channel without debate
echo ""
echo "Test 11: Auto-merge blocked for quick channel without debate"
RESULT=$(python3 -c "
from mini_debate_orchestration import check_auto_merge_blocked
run = {'run_id': 'run-6', 'channel_decision': {'channel': 'quick'}}
blocked = check_auto_merge_blocked(run)
print(blocked == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge blocked for quick channel without debate"
else
    fail "Auto-merge not blocked correctly"
fi

# Test 12: Auto-merge not blocked for standard channel
echo ""
echo "Test 12: Auto-merge not blocked for standard channel"
RESULT=$(python3 -c "
from mini_debate_orchestration import check_auto_merge_blocked
run = {'run_id': 'run-7', 'channel_decision': {'channel': 'standard'}}
blocked = check_auto_merge_blocked(run)
print(blocked == False)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge not blocked for standard channel"
else
    fail "Auto-merge incorrectly blocked for standard channel"
fi

# Test 13: Auto-merge not blocked for quick channel with completed debate
echo ""
echo "Test 13: Auto-merge not blocked for quick channel with completed debate"
RESULT=$(python3 -c "
from mini_debate_orchestration import check_auto_merge_blocked
run = {'run_id': 'run-8', 'channel_decision': {'channel': 'quick'}, 'mini_debate_status': {'status': 'completed'}}
blocked = check_auto_merge_blocked(run)
print(blocked == False)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge not blocked for quick channel with completed debate"
else
    fail "Auto-merge incorrectly blocked"
fi

# Test 14: Mini-debate report structure
echo ""
echo "Test 14: Mini-debate report structure"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate
run = {'run_id': 'run-9'}
request = {'run_id': 'run-9', 'task_id': 'task-9', 'channel': 'light'}
report = execute_mini_debate(run, request, debate_backend_available=True)
required_keys = ['run_id', 'task_id', 'channel', 'debate_type', 'status', 'consensus_score', 'required_consensus', 'rounds_completed', 'max_rounds', 'timeout_minutes', 'started_at', 'completed_at', 'debate_refs']
print(all(k in report for k in required_keys))
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate report has all required fields"
else
    fail "Mini-debate report missing required fields"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}${PASS_COUNT}${NC}"
echo -e "Failed: ${RED}${FAIL_COUNT}${NC}"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
