#!/usr/bin/env bash
# Test: E-Class Mini-Debate
# Tests E-class improvement disputes with two-round mini-debate

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
echo "Test: E-Class Mini-Debate"
echo "=========================================="
echo ""

# Test 1: Import E-class module
echo "Test 1: Import E-class module"
if python3 -c "from e_class_mini_debate import create_e_class_dispute, execute_e_class_debate, persist_e_class_debate_refs, validate_e_class_dispute, check_e_class_auto_merge_blocked, EClassConsensusError, EClassDebateUnavailableError, MissingDebateRefsError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Create E-class dispute
echo ""
echo "Test 2: Create E-class dispute"
RESULT=$(python3 -c "
from e_class_mini_debate import create_e_class_dispute
dispute = create_e_class_dispute('run-1', 'task-1', 'imp-1', 'high_priority', 'Test dispute', ['ref-1'])
print(dispute['status'] == 'pending' and dispute['classification'] == 'high_priority')
")
if [ "$RESULT" = "True" ]; then
    pass "E-class dispute created correctly"
else
    fail "E-class dispute creation failed"
fi

# Test 3: Execute E-class debate - success
echo ""
echo "Test 3: Execute E-class debate - success"
RESULT=$(python3 -c "
from e_class_mini_debate import execute_e_class_debate
run = {'run_id': 'run-2'}
dispute = {'dispute_id': 'edispute-2-1', 'classification': 'high_priority', 'evidence_refs': ['evidence://run-2/ref-1']}
backend_report = {'consensus_score': 0.72, 'rounds_completed': 2, 'debate_refs': ['debate://run/run-2/e-class/edispute-2-1']}
report = execute_e_class_debate(run, dispute, debate_backend_available=True, backend_report=backend_report)
print(report['status'] == 'completed' and report['consensus_score'] == 0.72 and report['evidence_refs'] == ['evidence://run-2/ref-1'])
")
if [ "$RESULT" = "True" ]; then
    pass "E-class debate executed successfully"
else
    fail "E-class debate execution failed"
fi

# Test 4: Execute E-class debate - backend unavailable
echo ""
echo "Test 4: Execute E-class debate - backend unavailable"
RESULT=$(python3 -c "
from e_class_mini_debate import execute_e_class_debate, EClassDebateUnavailableError
try:
    run = {'run_id': 'run-3'}
    dispute = {'dispute_id': 'edispute-3-1', 'classification': 'low_priority'}
    report = execute_e_class_debate(run, dispute, debate_backend_available=False)
    print('False')
except EClassDebateUnavailableError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "EClassDebateUnavailableError raised correctly"
else
    fail "EClassDebateUnavailableError not raised"
fi

# Test 5: Persist E-class debate refs
echo ""
echo "Test 5: Persist E-class debate refs"
RESULT=$(python3 -c "
from e_class_mini_debate import persist_e_class_debate_refs
run = {'run_id': 'run-4'}
report = {'dispute_id': 'edispute-4-1', 'debate_refs': ['debate://run-4/e-class/edispute-4-1'], 'status': 'completed', 'consensus_score': 0.75, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:00:00Z'}
updated = persist_e_class_debate_refs(run, report)
print('debate://run-4/e-class/edispute-4-1' in updated['e_class_debate_refs'])
")
if [ "$RESULT" = "True" ]; then
    pass "E-class debate refs persisted correctly"
else
    fail "E-class debate refs persistence failed"
fi

# Test 6: Validate E-class dispute - valid
echo ""
echo "Test 6: Validate E-class dispute - valid"
RESULT=$(python3 -c "
from e_class_mini_debate import validate_e_class_dispute
run = {
    'run_id': 'run-5',
    'e_class_debate_refs': ['debate://run-5/e-class/edispute-5-1'],
    'e_class_debate_status': {'dispute_id': 'edispute-5-1', 'status': 'completed'}
}
errors = validate_e_class_dispute(run, 'edispute-5-1')
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid E-class dispute passes validation"
else
    fail "Valid E-class dispute fails validation"
fi

# Test 7: Validate E-class dispute - missing refs
echo ""
echo "Test 7: Validate E-class dispute - missing refs"
RESULT=$(python3 -c "
from e_class_mini_debate import validate_e_class_dispute
run = {'run_id': 'run-6'}
errors = validate_e_class_dispute(run, 'edispute-6-1')
print(len(errors) > 0 and 'missing_debate_refs' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Missing debate refs detected"
else
    fail "Missing debate refs not detected"
fi

# Test 8: Auto-merge blocked for E-class without debate
echo ""
echo "Test 8: Auto-merge blocked for E-class without debate"
RESULT=$(python3 -c "
from e_class_mini_debate import check_e_class_auto_merge_blocked
run = {'run_id': 'run-7'}
blocked = check_e_class_auto_merge_blocked(run, 'edispute-7-1')
print(blocked == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge blocked for E-class without debate"
else
    fail "Auto-merge not blocked correctly"
fi

# Test 9: Auto-merge not blocked for E-class with completed debate
echo ""
echo "Test 9: Auto-merge not blocked for E-class with completed debate"
RESULT=$(python3 -c "
from e_class_mini_debate import check_e_class_auto_merge_blocked
run = {'run_id': 'run-8', 'e_class_debate_status': {'status': 'completed'}}
run['e_class_debate_status']['dispute_id'] = 'edispute-8-1'
blocked = check_e_class_auto_merge_blocked(run, 'edispute-8-1')
print(blocked == False)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge not blocked for E-class with completed debate"
else
    fail "Auto-merge incorrectly blocked"
fi

# Test 10: E-class config
echo ""
echo "Test 10: E-class config"
RESULT=$(python3 -c "
from e_class_mini_debate import get_e_class_config
config = get_e_class_config()
print(config['max_rounds'] == 2 and config['required_consensus'] == 0.60)
")
if [ "$RESULT" = "True" ]; then
    pass "E-class config correct"
else
    fail "E-class config incorrect"
fi

# Test 11: E-class debate report structure
echo ""
echo "Test 11: E-class debate report structure"
RESULT=$(python3 -c "
from e_class_mini_debate import execute_e_class_debate
run = {'run_id': 'run-9'}
dispute = {'dispute_id': 'edispute-9-1', 'classification': 'high_priority', 'evidence_refs': ['evidence://run-9/ref-1']}
backend_report = {'consensus_score': 0.80, 'rounds_completed': 2, 'debate_refs': ['debate://run/run-9/e-class/edispute-9-1']}
report = execute_e_class_debate(run, dispute, debate_backend_available=True, backend_report=backend_report)
required_keys = ['run_id', 'dispute_id', 'classification', 'status', 'consensus_score', 'required_consensus', 'rounds_completed', 'max_rounds', 'timeout_minutes', 'started_at', 'completed_at', 'debate_refs', 'evidence_refs']
print(all(k in report for k in required_keys))
")
if [ "$RESULT" = "True" ]; then
    pass "E-class debate report has all required fields"
else
    fail "E-class debate report missing required fields"
fi

# Test 12: E-class dispute structure
echo ""
echo "Test 12: E-class dispute structure"
RESULT=$(python3 -c "
from e_class_mini_debate import create_e_class_dispute
dispute = create_e_class_dispute('run-10', 'task-10', 'imp-10', 'low_priority', 'Test dispute', ['ref-1'])
required_keys = ['dispute_id', 'run_id', 'task_id', 'improvement_id', 'classification', 'description', 'evidence_refs', 'status', 'created_at']
print(all(k in dispute for k in required_keys))
")
if [ "$RESULT" = "True" ]; then
    pass "E-class dispute has all required fields"
else
    fail "E-class dispute missing required fields"
fi

# Test 13: Multiple E-class disputes
echo ""
echo "Test 13: Multiple E-class disputes"
RESULT=$(python3 -c "
from e_class_mini_debate import persist_e_class_debate_refs
run = {'run_id': 'run-11'}
report1 = {'dispute_id': 'edispute-11-1', 'debate_refs': ['debate://run-11/e-class/1'], 'status': 'completed', 'consensus_score': 0.75, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:00:00Z'}
report2 = {'dispute_id': 'edispute-11-2', 'debate_refs': ['debate://run-11/e-class/2'], 'status': 'completed', 'consensus_score': 0.80, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:01:00Z'}
updated = persist_e_class_debate_refs(run, report1)
updated = persist_e_class_debate_refs(updated, report2)
print(len(updated['e_class_debate_refs']) == 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Multiple E-class disputes handled correctly"
else
    fail "Multiple E-class disputes handling failed"
fi

# Test 14: E-class debate unavailable blocks auto-merge
echo ""
echo "Test 14: E-class debate unavailable blocks auto-merge"
RESULT=$(python3 -c "
from e_class_mini_debate import check_e_class_auto_merge_blocked
run = {'run_id': 'run-12', 'e_class_debate_status': {'status': 'degraded'}}
blocked = check_e_class_auto_merge_blocked(run, 'edispute-12-1')
print(blocked == True)
")
if [ "$RESULT" = "True" ]; then
    pass "E-class debate unavailable blocks auto-merge"
else
    fail "E-class debate unavailable not blocking"
fi

# Test 15: E-class dispute with empty evidence refs
echo ""
echo "Test 15: E-class dispute with empty evidence refs"
RESULT=$(python3 -c "
from e_class_mini_debate import create_e_class_dispute, MissingDebateRefsError
try:
    create_e_class_dispute('run-13', 'task-13', 'imp-13', 'low_priority', 'Test dispute', [])
    print('False')
except MissingDebateRefsError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "E-class dispute rejects empty evidence refs"
else
    fail "E-class dispute accepted empty evidence refs"
fi

# Test 16: Persist E-class debate refs does not mutate input run
echo ""
echo "Test 16: Persist E-class debate refs does not mutate input run"
RESULT=$(python3 -c "
from e_class_mini_debate import persist_e_class_debate_refs
run = {'run_id': 'run-14', 'e_class_debate_refs': ['debate://run-14/e-class/existing']}
report = {'dispute_id': 'edispute-14-1', 'debate_refs': ['debate://run-14/e-class/edispute-14-1'], 'status': 'completed', 'consensus_score': 0.75, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:00:00Z'}
updated = persist_e_class_debate_refs(run, report)
print(run is not updated and len(run['e_class_debate_refs']) == 1 and len(updated['e_class_debate_refs']) == 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Persist returns copied run without mutating input"
else
    fail "Persist mutated input run"
fi

# Test 17: Execute E-class debate - low backend consensus
echo ""
echo "Test 17: Execute E-class debate - low backend consensus"
RESULT=$(python3 -c "
from e_class_mini_debate import execute_e_class_debate, EClassConsensusError
try:
    run = {'run_id': 'run-15'}
    dispute = {'dispute_id': 'edispute-15-1', 'classification': 'low_priority'}
    backend_report = {'consensus_score': 0.55, 'rounds_completed': 2, 'debate_refs': ['debate://run-15/e-class/edispute-15-1']}
    execute_e_class_debate(run, dispute, backend_report=backend_report)
    print('False')
except EClassConsensusError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Low backend consensus raises EClassConsensusError"
else
    fail "Low backend consensus did not raise EClassConsensusError"
fi

# Test 18: Execute E-class debate - missing backend report
echo ""
echo "Test 18: Execute E-class debate - missing backend report"
RESULT=$(python3 -c "
from e_class_mini_debate import execute_e_class_debate, EClassDebateUnavailableError
try:
    execute_e_class_debate({'run_id': 'run-16'}, {'dispute_id': 'edispute-16-1'}, debate_backend_available=True)
    print('False')
except EClassDebateUnavailableError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Missing backend report raises EClassDebateUnavailableError"
else
    fail "Missing backend report did not raise EClassDebateUnavailableError"
fi

# Test 19: Validate E-class dispute rejects unknown dispute ID
echo ""
echo "Test 19: Validate E-class dispute rejects unknown dispute ID"
RESULT=$(python3 -c "
from e_class_mini_debate import validate_e_class_dispute
run = {
    'run_id': 'run-17',
    'e_class_debate_refs': ['debate://run-17/e-class/edispute-17-1'],
    'e_class_debate_status': {'dispute_id': 'edispute-17-1', 'status': 'completed'}
}
errors = validate_e_class_dispute(run, 'edispute-17-missing')
print(any('missing_debate_ref_for_dispute' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Unknown dispute ID is rejected"
else
    fail "Unknown dispute ID was not rejected"
fi

# Test 20: Validate E-class dispute rejects incomplete status
echo ""
echo "Test 20: Validate E-class dispute rejects incomplete status"
RESULT=$(python3 -c "
from e_class_mini_debate import validate_e_class_dispute
run = {
    'run_id': 'run-18',
    'e_class_debate_refs': ['debate://run-18/e-class/edispute-18-1'],
    'e_class_debate_status': {'dispute_id': 'edispute-18-1', 'status': 'pending'}
}
errors = validate_e_class_dispute(run, 'edispute-18-1')
print(any('incomplete_debate_status' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Incomplete debate status is rejected"
else
    fail "Incomplete debate status was not rejected"
fi

# Test 21: Auto-merge checks the requested dispute id
echo ""
echo "Test 21: Auto-merge checks the requested dispute id"
RESULT=$(python3 -c "
from e_class_mini_debate import check_e_class_auto_merge_blocked, persist_e_class_debate_refs
run = {'run_id': 'run-19'}
report = {'dispute_id': 'edispute-19-a', 'debate_refs': ['debate://run-19/e-class/edispute-19-a'], 'status': 'completed', 'consensus_score': 0.75, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:00:00Z'}
updated = persist_e_class_debate_refs(run, report)
print(check_e_class_auto_merge_blocked(updated, 'edispute-19-b') == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge remains blocked for a different dispute id"
else
    fail "Auto-merge ignored requested dispute id"
fi

# Test 22: NaN and Inf consensus scores are unavailable
echo ""
echo "Test 22: NaN and Inf consensus scores are unavailable"
RESULT=$(python3 -c "
from e_class_mini_debate import execute_e_class_debate, EClassDebateUnavailableError
run = {'run_id': 'run-20'}
dispute = {'dispute_id': 'edispute-20-1', 'classification': 'high_priority', 'evidence_refs': ['ref-1']}
for value in [float('nan'), float('inf')]:
    try:
        execute_e_class_debate(run, dispute, backend_report={'consensus_score': value})
        print('False')
        break
    except EClassDebateUnavailableError:
        pass
else:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "NaN and Inf consensus scores are rejected"
else
    fail "NaN or Inf consensus score was accepted"
fi

# Test 23: Prefix-overlapping dispute refs do not match
echo ""
echo "Test 23: Prefix-overlapping dispute refs do not match"
RESULT=$(python3 -c "
from e_class_mini_debate import validate_e_class_dispute
run = {
    'run_id': 'run-21',
    'e_class_debate_refs': ['debate://run-21/e-class/edispute-1-extra'],
    'e_class_debate_statuses': {'edispute-1-extra': {'dispute_id': 'edispute-1-extra', 'status': 'completed'}}
}
errors = validate_e_class_dispute(run, 'edispute-1')
print(any('missing_debate_ref_for_dispute' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Prefix-overlapping dispute refs do not match"
else
    fail "Prefix-overlapping dispute refs matched incorrectly"
fi

# Test 24: Multiple dispute statuses are preserved
echo ""
echo "Test 24: Multiple dispute statuses are preserved"
RESULT=$(python3 -c "
from e_class_mini_debate import persist_e_class_debate_refs, validate_e_class_dispute
run = {'run_id': 'run-22'}
report1 = {'dispute_id': 'edispute-22-a', 'debate_refs': ['debate://run-22/e-class/edispute-22-a'], 'status': 'completed', 'consensus_score': 0.75, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:00:00Z'}
report2 = {'dispute_id': 'edispute-22-b', 'debate_refs': ['debate://run-22/e-class/edispute-22-b'], 'status': 'completed', 'consensus_score': 0.80, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:01:00Z'}
updated = persist_e_class_debate_refs(persist_e_class_debate_refs(run, report1), report2)
print(validate_e_class_dispute(updated, 'edispute-22-a') == [] and validate_e_class_dispute(updated, 'edispute-22-b') == [])
")
if [ "$RESULT" = "True" ]; then
    pass "Multiple dispute statuses are preserved"
else
    fail "Multiple dispute statuses were overwritten"
fi

# Test 25: E-class config is read-only
echo ""
echo "Test 25: E-class config is read-only"
RESULT=$(python3 -c "
import e_class_mini_debate as module
try:
    module.E_CLASS_CONFIG['required_consensus'] = 0.0
    print('False')
except TypeError:
    print(module.get_e_class_config()['required_consensus'] == 0.60)
")
if [ "$RESULT" = "True" ]; then
    pass "E-class config is read-only"
else
    fail "E-class config was mutable"
fi

# Test 26: Empty IDs are rejected
echo ""
echo "Test 26: Empty IDs are rejected"
RESULT=$(python3 -c "
from e_class_mini_debate import create_e_class_dispute
for args in [(None, 'task', 'imp'), ('', 'task', 'imp'), ('run', '', 'imp'), ('run', 'task', '')]:
    try:
        create_e_class_dispute(args[0], args[1], args[2], 'high_priority', 'desc', ['ref-1'])
        print('False')
        break
    except ValueError:
        pass
else:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Empty IDs are rejected"
else
    fail "Empty IDs were accepted"
fi

# Test 27: CLI stdin mode executes debate
echo ""
echo "Test 27: CLI stdin mode executes debate"
CLI_OUTPUT=$(printf '%s\n' '{"run":{"run_id":"run-cli"},"dispute":{"dispute_id":"edispute-run-cli-imp","classification":"high_priority","evidence_refs":["ref-1"]},"backend_report":{"consensus_score":0.72,"rounds_completed":2,"debate_refs":["debate://run-cli/e-class/edispute-run-cli-imp"]}}' | scripts/bin/orch-e-class-debate)
RESULT=$(python3 -c "
import json
import sys
payload = json.loads(sys.argv[1])
print(payload['status'] == 'completed' and payload['dispute_id'] == 'edispute-run-cli-imp')
" "$CLI_OUTPUT")
if [ "$RESULT" = "True" ]; then
    pass "CLI stdin mode executes debate"
else
    fail "CLI stdin mode failed"
fi

# Test 28: CLI validate mode checks specific dispute
echo ""
echo "Test 28: CLI validate mode checks specific dispute"
CLI_OUTPUT=$(scripts/bin/orch-e-class-debate --validate --dispute-id edispute-cli-a --run '{"run_id":"run-cli","e_class_debate_refs":["debate://run-cli/e-class/edispute-cli-a"],"e_class_debate_statuses":{"edispute-cli-a":{"dispute_id":"edispute-cli-a","status":"completed"}}}')
RESULT=$(python3 -c "
import json
import sys
payload = json.loads(sys.argv[1])
print(payload['valid'] is True and payload['errors'] == [] and payload['auto_merge_blocked'] is False)
" "$CLI_OUTPUT")
if [ "$RESULT" = "True" ]; then
    pass "CLI validate mode checks specific dispute"
else
    fail "CLI validate mode failed"
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
