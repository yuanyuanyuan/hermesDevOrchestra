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
if python3 -c "from e_class_mini_debate import create_e_class_dispute, execute_e_class_debate, persist_e_class_debate_refs, validate_e_class_dispute, check_e_class_auto_merge_blocked, EClassConsensusError, EClassDebateUnavailableError; print('OK')"; then
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
dispute = {'dispute_id': 'edispute-2-1', 'classification': 'high_priority'}
report = execute_e_class_debate(run, dispute, debate_backend_available=True)
print(report['status'] == 'completed' and report['consensus_score'] >= 0.60)
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
report = {'debate_refs': ['debate://run-4/e-class/edispute-4-1'], 'status': 'completed', 'consensus_score': 0.75, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:00:00Z'}
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
run = {'run_id': 'run-5', 'e_class_debate_refs': ['debate://run-5/e-class/edispute-5-1']}
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
run = {'run_id': 'run-8', 'e_class_debate_status': {'dispute_id': 'edispute-8-1', 'status': 'completed'}}
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
dispute = {'dispute_id': 'edispute-9-1', 'classification': 'high_priority'}
report = execute_e_class_debate(run, dispute, debate_backend_available=True)
required_keys = ['run_id', 'dispute_id', 'classification', 'status', 'consensus_score', 'required_consensus', 'rounds_completed', 'max_rounds', 'timeout_minutes', 'started_at', 'completed_at', 'debate_refs']
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
report1 = {'debate_refs': ['debate://run-11/e-class/1'], 'status': 'completed', 'consensus_score': 0.75, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:00:00Z'}
report2 = {'debate_refs': ['debate://run-11/e-class/2'], 'status': 'completed', 'consensus_score': 0.80, 'required_consensus': 0.60, 'completed_at': '2026-01-01T00:01:00Z'}
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

# Test 15: Cross-dispute isolation - status for dispute A must not unblock dispute B
echo ""
echo "Test 15: Cross-dispute isolation"
RESULT=$(python3 -c "
from e_class_mini_debate import check_e_class_auto_merge_blocked
run = {'run_id': 'run-15', 'e_class_debate_status': {'dispute_id': 'edispute-A', 'status': 'completed'}}
blocked = check_e_class_auto_merge_blocked(run, 'edispute-B')
print(blocked == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Cross-dispute status correctly blocked"
else
    fail "Cross-dispute status leaked across disputes"
fi

# Test 16: execute_e_class_debate accepts backend_report parameter
echo ""
echo "Test 16: execute_e_class_debate accepts backend_report"
RESULT=$(python3 -c "
from e_class_mini_debate import execute_e_class_debate
run = {'run_id': 'run-16'}
dispute = {'dispute_id': 'edispute-16-1', 'classification': 'high_priority'}
report = execute_e_class_debate(run, dispute, debate_backend_available=True, backend_report={'consensus_score': 0.80, 'debate_refs': ['debate://run-16/e-class/edispute-16-1']})
print(report['consensus_score'] == 0.80 and 'debate://run-16/e-class/edispute-16-1' in report['debate_refs'])
")
if [ "$RESULT" = "True" ]; then
    pass "backend_report honored when well-formed"
else
    fail "backend_report not honored"
fi

# Test 17: validate_e_class_dispute rejects refs that do not mention dispute_id
echo ""
echo "Test 17: validate_e_class_dispute cross-dispute rejection"
RESULT=$(python3 -c "
from e_class_mini_debate import validate_e_class_dispute
run = {'run_id': 'run-17', 'e_class_debate_refs': ['debate://run-17/e-class/edispute-A']}
errors = validate_e_class_dispute(run, 'edispute-B')
print(len(errors) > 0 and 'edispute-B' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "validate_e_class_dispute rejects cross-dispute refs"
else
    fail "validate_e_class_dispute did not reject cross-dispute refs"
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
