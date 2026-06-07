#!/usr/bin/env bash
# Test: Worker Source Isolation
# Tests source isolation for review, audit, and cross_check workers

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
echo "Test: Worker Source Isolation"
echo "=========================================="
echo ""

# Test 1: Import source isolation module
echo "Test 1: Import source isolation module"
if python3 -c "from worker_source_isolation import validate_model_source, get_adjudicator_source, check_worker_source_isolation, create_worker_session, validate_worker_session, SourceIsolationViolationError, MissingModelSourceError, UnknownSourceError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Valid model source
echo ""
echo "Test 2: Valid model source"
RESULT=$(python3 -c "
from worker_source_isolation import validate_model_source
print(validate_model_source('claude'))
")
if [ "$RESULT" = "True" ]; then
    pass "Valid model source accepted"
else
    fail "Valid model source rejected"
fi

# Test 3: Invalid model source
echo ""
echo "Test 3: Invalid model source"
RESULT=$(python3 -c "
from worker_source_isolation import validate_model_source
print(validate_model_source('unknown_model'))
")
if [ "$RESULT" = "False" ]; then
    pass "Invalid model source rejected"
else
    fail "Invalid model source accepted"
fi

# Test 4: Get adjudicator source from run
echo ""
echo "Test 4: Get adjudicator source from run"
RESULT=$(python3 -c "
from worker_source_isolation import get_adjudicator_source
run = {'adjudicator_source': 'claude'}
print(get_adjudicator_source(run))
")
if [ "$RESULT" = "claude" ]; then
    pass "Adjudicator source retrieved from run"
else
    fail "Adjudicator source not retrieved"
fi

# Test 5: Get adjudicator source from task
echo ""
echo "Test 5: Get adjudicator source from task"
RESULT=$(python3 -c "
from worker_source_isolation import get_adjudicator_source
run = {}
task = {'adjudicator_source': 'kimi'}
print(get_adjudicator_source(run, task))
")
if [ "$RESULT" = "kimi" ]; then
    pass "Adjudicator source retrieved from task"
else
    fail "Adjudicator source not retrieved from task"
fi

# Test 6: Source isolation check - no violation
echo ""
echo "Test 6: Source isolation check - no violation"
RESULT=$(python3 -c "
from worker_source_isolation import check_worker_source_isolation
try:
    check_worker_source_isolation('run-1', 'claude', 'kimi', 'reviewer')
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "No source isolation violation"
else
    fail "Source isolation violation incorrectly raised"
fi

# Test 7: Source isolation check - violation
echo ""
echo "Test 7: Source isolation check - violation"
RESULT=$(python3 -c "
from worker_source_isolation import check_worker_source_isolation, SourceIsolationViolationError
try:
    check_worker_source_isolation('run-2', 'claude', 'claude', 'reviewer')
    print('False')
except SourceIsolationViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Source isolation violation detected"
else
    fail "Source isolation violation not detected"
fi

# Test 8: Create worker session - implementer (no isolation)
echo ""
echo "Test 8: Create worker session - implementer (no isolation)"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session
run = {'adjudicator_source': 'claude'}
session = create_worker_session('run-3', 'task-3', 'worker-1', 'implementer', 'claude', run)
print(session['role'] == 'implementer' and session['source_isolation_status'] == 'degraded' and session['source_isolation_reason'] == 'not_required_for_role')
")
if [ "$RESULT" = "True" ]; then
    pass "Implementer session created without isolation check"
else
    fail "Implementer session creation failed"
fi

# Test 9: Create worker session - reviewer (isolation passed)
echo ""
echo "Test 9: Create worker session - reviewer (isolation passed)"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session
run = {'adjudicator_source': 'claude'}
session = create_worker_session('run-4', 'task-4', 'worker-2', 'reviewer', 'kimi', run)
print(session['role'] == 'reviewer' and session['source_isolation_status'] == 'passed')
")
if [ "$RESULT" = "True" ]; then
    pass "Reviewer session created with isolation passed"
else
    fail "Reviewer session creation failed"
fi

# Test 10: Create worker session - reviewer (isolation violated)
echo ""
echo "Test 10: Create worker session - reviewer (isolation violated)"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, SourceIsolationViolationError
try:
    run = {'adjudicator_source': 'claude'}
    session = create_worker_session('run-5', 'task-5', 'worker-3', 'reviewer', 'claude', run)
    print('False')
except SourceIsolationViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Source isolation violation detected for reviewer"
else
    fail "Source isolation violation not detected"
fi

# Test 11: Create worker session - missing model_source
echo ""
echo "Test 11: Create worker session - missing model_source"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, MissingModelSourceError
try:
    run = {'adjudicator_source': 'claude'}
    session = create_worker_session('run-6', 'task-6', 'worker-4', 'reviewer', '', run)
    print('False')
except MissingModelSourceError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "MissingModelSourceError raised correctly"
else
    fail "MissingModelSourceError not raised"
fi

# Test 12: Create worker session - unknown source
echo ""
echo "Test 12: Create worker session - unknown source"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, UnknownSourceError
try:
    run = {'adjudicator_source': 'claude'}
    session = create_worker_session('run-7', 'task-7', 'worker-5', 'auditor', 'unknown_model', run)
    print('False')
except UnknownSourceError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "UnknownSourceError raised correctly"
else
    fail "UnknownSourceError not raised"
fi

# Test 13: Validate worker session - valid
echo ""
echo "Test 13: Validate worker session - valid"
RESULT=$(python3 -c "
from worker_source_isolation import validate_worker_session
session = {'session_id': 's1', 'run_id': 'r1', 'task_id': 't1', 'worker_id': 'w1', 'role': 'reviewer', 'model_source': 'claude'}
errors = validate_worker_session(session)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid worker session passes validation"
else
    fail "Valid worker session fails validation"
fi

# Test 14: Validate worker session - missing fields
echo ""
echo "Test 14: Validate worker session - missing fields"
RESULT=$(python3 -c "
from worker_source_isolation import validate_worker_session
session = {'session_id': 's1'}
errors = validate_worker_session(session)
print(len(errors) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing fields detected"
else
    fail "Missing fields not detected"
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
