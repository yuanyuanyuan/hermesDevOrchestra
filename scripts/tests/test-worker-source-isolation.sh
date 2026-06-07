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
if python3 -c "from worker_source_isolation import validate_model_source, get_adjudicator_source, check_worker_source_isolation, create_worker_session, validate_worker_session, SourceIsolationError, SourceIsolationViolationError, MissingModelSourceError, MissingAdjudicatorSourceError, UnknownSourceError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Valid model sources
echo ""
echo "Test 2: Valid model sources"
RESULT=$(python3 -c "
from worker_source_isolation import VALID_MODEL_SOURCES, validate_model_source
print(all(validate_model_source(source) for source in VALID_MODEL_SOURCES))
")
if [ "$RESULT" = "True" ]; then
    pass "Valid model sources accepted"
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
except Exception:
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
print(session['role'] == 'implementer' and session['source_isolation_status'] == 'degraded')
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
session = {'session_id': 's1', 'run_id': 'r1', 'task_id': 't1', 'worker_id': 'w1', 'role': 'reviewer', 'model_source': 'claude', 'source_isolation_status': 'passed'}
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

# Test 15: Validate worker session - invalid role
echo ""
echo "Test 15: Validate worker session - invalid role"
RESULT=$(python3 -c "
from worker_source_isolation import validate_worker_session
session = {'session_id': 's1', 'run_id': 'r1', 'task_id': 't1', 'worker_id': 'w1', 'role': 'planner', 'model_source': 'claude'}
errors = validate_worker_session(session)
print('Invalid role: planner' in errors)
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid role detected"
else
    fail "Invalid role not detected"
fi

# Test 16: Missing adjudicator source blocks isolated role
echo ""
echo "Test 16: Missing adjudicator source blocks isolated role"
RESULT=$(python3 -c "
from worker_source_isolation import check_worker_source_isolation, MissingAdjudicatorSourceError
try:
    check_worker_source_isolation('run-8', 'claude', None, 'reviewer')
    print('False')
except MissingAdjudicatorSourceError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Missing adjudicator source blocks isolated role"
else
    fail "Missing adjudicator source did not block isolated role"
fi

# Test 17: Task adjudicator source overrides run source
echo ""
echo "Test 17: Task adjudicator source overrides run source"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, SourceIsolationViolationError
try:
    run = {'adjudicator_source': 'claude'}
    task = {'adjudicator_source': 'kimi'}
    create_worker_session('run-9', 'task-9', 'worker-6', 'reviewer', 'kimi', run, task)
    print('False')
except SourceIsolationViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Task adjudicator source overrides run source"
else
    fail "Task adjudicator source did not override run source"
fi

# Test 18: Task adjudicator source None falls back to run source
echo ""
echo "Test 18: Task adjudicator source None falls back to run source"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, SourceIsolationViolationError
try:
    run = {'adjudicator_source': 'claude'}
    task = {'adjudicator_source': None}
    create_worker_session('run-10', 'task-10', 'worker-7', 'reviewer', 'claude', run, task)
    print('False')
except SourceIsolationViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Task adjudicator source None falls back to run source"
else
    fail "Task adjudicator source None did not fall back to run source"
fi

# Test 19: Source aliases are normalized before comparison
echo ""
echo "Test 19: Source aliases are normalized before comparison"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, SourceIsolationViolationError
try:
    run = {'adjudicator_source': 'anthropic'}
    create_worker_session('run-11', 'task-11', 'worker-8', 'reviewer', 'claude', run)
    print('False')
except SourceIsolationViolationError as exc:
    print('source_isolation_violation' in str(exc))
")
if [ "$RESULT" = "True" ]; then
    pass "Source aliases are normalized before comparison"
else
    fail "Source aliases were not normalized before comparison"
fi

# Test 20: Non-string adjudicator source is rejected
echo ""
echo "Test 20: Non-string adjudicator source is rejected"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, UnknownSourceError
try:
    run = {'adjudicator_source': 42}
    create_worker_session('run-12', 'task-12', 'worker-9', 'reviewer', 'claude', run)
    print('False')
except UnknownSourceError as exc:
    print(str(exc) == 'Unknown adjudicator_source: 42')
")
if [ "$RESULT" = "True" ]; then
    pass "Non-string adjudicator source is rejected"
else
    fail "Non-string adjudicator source was not rejected"
fi

# Test 21: Unknown role rejected by direct isolation check
echo ""
echo "Test 21: Unknown role rejected by direct isolation check"
RESULT=$(python3 -c "
from worker_source_isolation import check_worker_source_isolation
try:
    check_worker_source_isolation('run-13', 'claude', 'kimi', 'reviewers')
    print('False')
except ValueError as exc:
    print(str(exc) == 'Invalid role: reviewers')
")
if [ "$RESULT" = "True" ]; then
    pass "Unknown role rejected by direct isolation check"
else
    fail "Unknown role was not rejected by direct isolation check"
fi

# Test 22: Non-isolated role branch returns without isolation
echo ""
echo "Test 22: Non-isolated role branch returns without isolation"
RESULT=$(python3 -c "
from worker_source_isolation import check_worker_source_isolation
print(check_worker_source_isolation('run-14', 'claude', 'claude', 'implementer') is None)
")
if [ "$RESULT" = "True" ]; then
    pass "Non-isolated role branch returns without isolation"
else
    fail "Non-isolated role branch did not return cleanly"
fi

# Test 23: Auditor and cross_checker positive sessions
echo ""
echo "Test 23: Auditor and cross_checker positive sessions"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session
run = {'adjudicator_source': 'kimi'}
auditor = create_worker_session('run-15', 'task-15', 'worker-10', 'auditor', 'claude', run)
cross_checker = create_worker_session('run-15', 'task-16', 'worker-11', 'cross_checker', 'codex', run)
print(auditor['source_isolation_status'] == 'passed' and cross_checker['source_isolation_status'] == 'passed')
")
if [ "$RESULT" = "True" ]; then
    pass "Auditor and cross_checker positive sessions created"
else
    fail "Auditor or cross_checker positive session failed"
fi

# Test 24: Implementer session validation still checks model_source
echo ""
echo "Test 24: Implementer session validation still checks model_source"
RESULT=$(python3 -c "
from worker_source_isolation import validate_worker_session
session = {'session_id': 's1', 'run_id': 'r1', 'task_id': 't1', 'worker_id': 'w1', 'role': 'implementer', 'model_source': 'bogus'}
errors = validate_worker_session(session)
print('Unknown model_source: bogus' in errors)
")
if [ "$RESULT" = "True" ]; then
    pass "Implementer session validation checks model_source"
else
    fail "Implementer session validation did not check model_source"
fi

# Test 25: Invalid source isolation status is rejected
echo ""
echo "Test 25: Invalid source isolation status is rejected"
RESULT=$(python3 -c "
from worker_source_isolation import validate_worker_session
session = {'session_id': 's1', 'run_id': 'r1', 'task_id': 't1', 'worker_id': 'w1', 'role': 'reviewer', 'model_source': 'claude', 'source_isolation_status': 'not_applicable'}
errors = validate_worker_session(session)
print('Invalid source_isolation_status: not_applicable' in errors)
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid source isolation status is rejected"
else
    fail "Invalid source isolation status was not rejected"
fi

# Test 26: Session IDs are unique for repeated triples
echo ""
echo "Test 26: Session IDs are unique for repeated triples"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session
run = {'adjudicator_source': 'kimi'}
first = create_worker_session('run-16', 'task-17', 'worker-12', 'reviewer', 'claude', run)
second = create_worker_session('run-16', 'task-17', 'worker-12', 'reviewer', 'claude', run)
print(first['session_id'] != second['session_id'])
")
if [ "$RESULT" = "True" ]; then
    pass "Session IDs are unique for repeated triples"
else
    fail "Session IDs collided for repeated triples"
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
