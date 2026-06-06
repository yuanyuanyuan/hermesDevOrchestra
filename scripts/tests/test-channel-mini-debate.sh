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
if python3 -c "from mini_debate_orchestration import create_mini_debate_request, execute_mini_debate, attach_mini_debate_to_run, persist_mini_debate_refs, validate_mini_debate, check_auto_merge_blocked, MiniDebateTimeoutError, MiniDebateConsensusError, MissingDebateReportError; print('OK')"; then
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
backend_report = {'consensus_score': 0.91, 'rounds_completed': 1, 'debate_refs': ['debate://backend/run-1/mini/1']}
report = execute_mini_debate(run, request, debate_backend_available=True, backend_report=backend_report)
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
backend_report = {'consensus_score': 0.76, 'rounds_completed': 2, 'debate_refs': ['debate://backend/run-9/mini/1']}
report = execute_mini_debate(run, request, debate_backend_available=True, backend_report=backend_report)
required_keys = ['run_id', 'task_id', 'channel', 'debate_type', 'status', 'consensus_score', 'required_consensus', 'rounds_completed', 'max_rounds', 'timeout_minutes', 'started_at', 'completed_at', 'debate_refs']
print(all(k in report for k in required_keys) and report['consensus_score'] == 0.76 and report['debate_refs'] == backend_report['debate_refs'])
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate report has all required fields"
else
    fail "Mini-debate report missing required fields"
fi

# Test 15: Mini-debate degraded report structure
echo ""
echo "Test 15: Mini-debate degraded report structure"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate
run = {'run_id': 'run-10'}
request = {'run_id': 'run-10', 'task_id': 'task-10', 'channel': 'quick'}
report = execute_mini_debate(run, request, debate_backend_available=False)
required_keys = ['run_id', 'task_id', 'channel', 'debate_type', 'status', 'degradation_reason', 'consensus_score', 'required_consensus', 'rounds_completed', 'max_rounds', 'timeout_minutes', 'started_at', 'completed_at', 'debate_refs']
print(all(k in report for k in required_keys) and report['status'] == 'degraded' and report['degradation_reason'] == 'debate_backend_unavailable' and report['consensus_score'] == 0.0 and report['completed_at'] is None and report['debate_refs'] == [])
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate degraded report has all expected fields"
else
    fail "Mini-debate degraded report missing expected fields"
fi

# Test 16: Validate mini-debate - invalid status
echo ""
echo "Test 16: Validate mini-debate - invalid status"
RESULT=$(python3 -c "
from mini_debate_orchestration import validate_mini_debate
run = {'run_id': 'run-11', 'mini_debate_status': {'status': 'pending', 'consensus_score': 0.9}}
errors = validate_mini_debate(run)
print('status must be completed or degraded' in errors)
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid mini-debate status detected"
else
    fail "Invalid mini-debate status not detected"
fi

# Test 17: Validate mini-debate - invalid consensus score
echo ""
echo "Test 17: Validate mini-debate - invalid consensus score"
RESULT=$(python3 -c "
from mini_debate_orchestration import validate_mini_debate
run = {'run_id': 'run-12', 'mini_debate_status': {'status': 'completed', 'consensus_score': 1.5}}
errors = validate_mini_debate(run)
print('consensus_score must be between 0 and 1' in errors)
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid consensus score detected"
else
    fail "Invalid consensus score not detected"
fi

# Test 18: Auto-merge blocked when channel decision missing
echo ""
echo "Test 18: Auto-merge blocked when channel decision missing"
RESULT=$(python3 -c "
from mini_debate_orchestration import check_auto_merge_blocked
run = {'run_id': 'run-13'}
blocked = check_auto_merge_blocked(run)
print(blocked == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge blocked when channel decision missing"
else
    fail "Auto-merge not blocked when channel decision missing"
fi

# Test 19: Mini-debate refs are unique
echo ""
echo "Test 19: Mini-debate refs are unique"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate
run = {'run_id': 'run-14'}
request = {'run_id': 'run-14', 'task_id': 'task-14', 'channel': 'quick'}
first = execute_mini_debate(run, request, debate_backend_available=True, backend_report={'consensus_score': 0.9})
second = execute_mini_debate(run, request, debate_backend_available=True, backend_report={'consensus_score': 0.9})
print(first['debate_refs'][0] != second['debate_refs'][0])
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate refs are unique"
else
    fail "Mini-debate refs are not unique"
fi

# Test 20: Missing backend report degrades even when backend is available
echo ""
echo "Test 20: Missing backend report degrades even when backend is available"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate
run = {'run_id': 'run-15'}
request = {'run_id': 'run-15', 'task_id': 'task-15', 'channel': 'quick'}
report = execute_mini_debate(run, request, debate_backend_available=True)
print(report['status'] == 'degraded' and report['degradation_reason'] == 'debate_backend_unavailable')
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate degrades when backend report is missing"
else
    fail "Mini-debate did not degrade when backend report is missing"
fi

# Test 21: Create mini-debate request requires channel
echo ""
echo "Test 21: Create mini-debate request requires channel"
RESULT=$(python3 -c "
from mini_debate_orchestration import create_mini_debate_request
try:
    create_mini_debate_request('run-16', 'task-16', '', 'Fix typo', ['README.md'])
    print('False')
except ValueError as exc:
    print(str(exc) == 'channel is required')
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate request rejects missing channel"
else
    fail "Mini-debate request did not reject missing channel"
fi

# Test 22: Mini-debate timeout raises explicit error
echo ""
echo "Test 22: Mini-debate timeout raises explicit error"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate, MiniDebateTimeoutError
run = {'run_id': 'run-17'}
request = {'run_id': 'run-17', 'task_id': 'task-17', 'channel': 'quick'}
try:
    execute_mini_debate(run, request, backend_report={'consensus_score': 0.9, 'elapsed_minutes': 11})
    print('False')
except MiniDebateTimeoutError as exc:
    print(exc.timeout_minutes == 10)
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate timeout raises explicit error"
else
    fail "Mini-debate timeout did not raise expected error"
fi

# Test 23: Missing consensus score raises missing report error
echo ""
echo "Test 23: Missing consensus score raises missing report error"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate, MissingDebateReportError
run = {'run_id': 'run-18'}
request = {'run_id': 'run-18', 'task_id': 'task-18', 'channel': 'quick'}
try:
    execute_mini_debate(run, request, backend_report={'rounds_completed': 1})
    print('False')
except MissingDebateReportError as exc:
    print(exc.reason == 'missing consensus_score')
")
if [ "$RESULT" = "True" ]; then
    pass "Missing consensus score raises missing report error"
else
    fail "Missing consensus score did not raise expected error"
fi

# Test 24: Malformed backend report raises missing report error
echo ""
echo "Test 24: Malformed backend report raises missing report error"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate, MissingDebateReportError
run = {'run_id': 'run-19'}
request = {'run_id': 'run-19', 'task_id': 'task-19', 'channel': 'quick'}
try:
    execute_mini_debate(run, request, backend_report='not-a-dict')
    print('False')
except MissingDebateReportError as exc:
    print(exc.reason == 'malformed')
")
if [ "$RESULT" = "True" ]; then
    pass "Malformed backend report raises missing report error"
else
    fail "Malformed backend report did not raise expected error"
fi

# Test 25: Non-finite consensus score is rejected
echo ""
echo "Test 25: Non-finite consensus score is rejected"
RESULT=$(python3 -c "
from mini_debate_orchestration import execute_mini_debate, MissingDebateReportError
run = {'run_id': 'run-20'}
request = {'run_id': 'run-20', 'task_id': 'task-20', 'channel': 'quick'}
for score in (float('nan'), float('inf')):
    try:
        execute_mini_debate(run, request, backend_report={'consensus_score': score})
        print('False')
        break
    except MissingDebateReportError:
        pass
else:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Non-finite consensus score rejected"
else
    fail "Non-finite consensus score was accepted"
fi

# Test 26: Non-dict channel decision blocks auto-merge
echo ""
echo "Test 26: Non-dict channel decision blocks auto-merge"
RESULT=$(python3 -c "
from mini_debate_orchestration import check_auto_merge_blocked
run = {'run_id': 'run-21', 'channel_decision': ['quick']}
print(check_auto_merge_blocked(run) == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Non-dict channel decision blocks auto-merge"
else
    fail "Non-dict channel decision did not block auto-merge"
fi

# Test 27: Attach mini-debate refs deduplicates stale refs
echo ""
echo "Test 27: Attach mini-debate refs deduplicates stale refs"
RESULT=$(python3 -c "
from mini_debate_orchestration import attach_mini_debate_to_run
run = {'run_id': 'run-22', 'mini_debate_refs': ['debate://run-22/mini/a']}
report = {'debate_refs': ['debate://run-22/mini/a', 'debate://run-22/mini/b'], 'channel': 'quick', 'debate_type': 'confirmation', 'status': 'completed', 'consensus_score': 0.9, 'required_consensus': 0.8, 'completed_at': '2026-01-01T00:00:00Z'}
updated = attach_mini_debate_to_run(run, report)
print(updated['mini_debate_refs'] == ['debate://run-22/mini/a', 'debate://run-22/mini/b'])
")
if [ "$RESULT" = "True" ]; then
    pass "Attach mini-debate refs deduplicates stale refs"
else
    fail "Attach mini-debate refs did not deduplicate stale refs"
fi

# Test 28: Validate degraded status is accepted
echo ""
echo "Test 28: Validate degraded status is accepted"
RESULT=$(python3 -c "
from mini_debate_orchestration import validate_mini_debate
run = {'run_id': 'run-23', 'mini_debate_status': {'status': 'degraded', 'consensus_score': 0.0}}
print(validate_mini_debate(run) == [])
")
if [ "$RESULT" = "True" ]; then
    pass "Degraded mini-debate status passes validation"
else
    fail "Degraded mini-debate status failed validation"
fi

# Test 29: Validate missing consensus score
echo ""
echo "Test 29: Validate missing consensus score"
RESULT=$(python3 -c "
from mini_debate_orchestration import validate_mini_debate
run = {'run_id': 'run-24', 'mini_debate_status': {'status': 'completed'}}
print('consensus_score missing from mini_debate_status' in validate_mini_debate(run))
")
if [ "$RESULT" = "True" ]; then
    pass "Missing consensus score detected in validation"
else
    fail "Missing consensus score was not detected in validation"
fi

# Test 30: Validate non-finite consensus score
echo ""
echo "Test 30: Validate non-finite consensus score"
RESULT=$(python3 -c "
from mini_debate_orchestration import validate_mini_debate
run = {'run_id': 'run-25', 'mini_debate_status': {'status': 'completed', 'consensus_score': float('nan')}}
print('consensus_score must be between 0 and 1' in validate_mini_debate(run))
")
if [ "$RESULT" = "True" ]; then
    pass "Non-finite consensus score detected in validation"
else
    fail "Non-finite consensus score was not detected in validation"
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
