#!/usr/bin/env bash
# Test: Worker Advancement Evidence Hardening
# Tests write scope, DAG, review, and commit evidence validation

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
echo "Test: Worker Advancement Evidence Hardening"
echo "=========================================="
echo ""

# Test 1: Import worker evidence module
echo "Test 1: Import worker evidence module"
if python3 -c "from worker_evidence_harden import validate_write_scope, validate_dag_evidence, validate_review_evidence, validate_commit_evidence, validate_worker_advancement, WriteScopeViolationError, MissingDAGValidationError, DAGCycleDetectedError, MissingReviewEvidenceError, MissingCommitEvidenceError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Write scope validation - pass
echo ""
echo "Test 2: Write scope validation - pass"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope
try:
    validate_write_scope('run-1', ['scripts/lib/', 'tests/'], ['scripts/lib/module.py', 'tests/test.py'])
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Write scope validation passed"
else
    fail "Write scope validation failed incorrectly"
fi

# Test 3: Write scope validation - fail
echo ""
echo "Test 3: Write scope validation - fail"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, WriteScopeViolationError
try:
    validate_write_scope('run-2', ['scripts/lib/'], ['config/secret.txt'])
    print('False')
except WriteScopeViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Write scope violation detected"
else
    fail "Write scope violation not detected"
fi

# Test 4: DAG validation - required stage with result
echo ""
echo "Test 4: DAG validation - required stage with result"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence
try:
    validate_dag_evidence('run-3', 'implementation', {'valid': True, 'cycles': []})
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "DAG validation passed for implementation stage"
else
    fail "DAG validation failed incorrectly"
fi

# Test 5: DAG validation - required stage missing
echo ""
echo "Test 5: DAG validation - required stage missing"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence, MissingDAGValidationError
try:
    validate_dag_evidence('run-4', 'implementation', None)
    print('False')
except MissingDAGValidationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "MissingDAGValidationError raised correctly"
else
    fail "MissingDAGValidationError not raised"
fi

# Test 6: DAG validation - cycle detected
echo ""
echo "Test 6: DAG validation - cycle detected"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence, DAGCycleDetectedError
try:
    validate_dag_evidence('run-5', 'implementation', {'valid': False, 'cycles': [['a', 'b', 'a']]})
    print('False')
except DAGCycleDetectedError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "DAGCycleDetectedError raised correctly"
else
    fail "DAGCycleDetectedError not raised"
fi

# Test 7: Review evidence - required stage with result
echo ""
echo "Test 7: Review evidence - required stage with result"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_review_evidence
try:
    validate_review_evidence('run-6', 'implementation', {'approved': True, 'reviewer': 'claude'})
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Review evidence validation passed"
else
    fail "Review evidence validation failed"
fi

# Test 8: Review evidence - required stage missing
echo ""
echo "Test 8: Review evidence - required stage missing"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_review_evidence, MissingReviewEvidenceError
try:
    validate_review_evidence('run-7', 'implementation', None)
    print('False')
except MissingReviewEvidenceError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "MissingReviewEvidenceError raised correctly"
else
    fail "MissingReviewEvidenceError not raised"
fi

# Test 9: Commit evidence - required stage with result
echo ""
echo "Test 9: Commit evidence - required stage with result"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_commit_evidence
try:
    validate_commit_evidence('run-8', 'implementation', {'commit_sha': 'abc123', 'message': 'test'})
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Commit evidence validation passed"
else
    fail "Commit evidence validation failed"
fi

# Test 10: Commit evidence - required stage missing
echo ""
echo "Test 10: Commit evidence - required stage missing"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_commit_evidence, MissingCommitEvidenceError
try:
    validate_commit_evidence('run-9', 'implementation', None)
    print('False')
except MissingCommitEvidenceError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "MissingCommitEvidenceError raised correctly"
else
    fail "MissingCommitEvidenceError not raised"
fi

# Test 11: Full worker advancement - valid
echo ""
echo "Test 11: Full worker advancement - valid"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-10'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib/'],
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['scripts/lib/module.py'])
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Full worker advancement validation passed"
else
    fail "Full worker advancement validation failed"
fi

# Test 12: Full worker advancement - write scope violation
echo ""
echo "Test 12: Full worker advancement - write scope violation"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-11'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib/'],
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['config/secret.txt'])
print(len(errors) > 0 and 'write_scope_violation' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Write scope violation detected in full validation"
else
    fail "Write scope violation not detected"
fi

# Test 13: Full worker advancement - missing DAG
echo ""
echo "Test 13: Full worker advancement - missing DAG"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-12'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib/'],
    'dag_validation_result': None,
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['scripts/lib/module.py'])
print(len(errors) > 0 and 'missing_dag_validation' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Missing DAG validation detected in full validation"
else
    fail "Missing DAG validation not detected"
fi

# Test 14: Full worker advancement - missing review
echo ""
echo "Test 14: Full worker advancement - missing review"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-13'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib/'],
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': None,
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['scripts/lib/module.py'])
print(len(errors) > 0 and 'missing_review_evidence' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Missing review evidence detected in full validation"
else
    fail "Missing review evidence not detected"
fi

# Test 15: Write scope rejects sibling path prefix
echo ""
echo "Test 15: Write scope rejects sibling path prefix"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, WriteScopeViolationError
try:
    validate_write_scope('run-14', ['scripts/lib'], ['scripts/libary/module.py'])
    print('False')
except WriteScopeViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Sibling path prefix rejected"
else
    fail "Sibling path prefix incorrectly accepted"
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
