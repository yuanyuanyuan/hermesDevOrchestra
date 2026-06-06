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
if python3 -c "from worker_evidence_harden import validate_write_scope, validate_dag_evidence, validate_review_evidence, validate_commit_evidence, validate_worker_advancement, WriteScopeViolationError, InvalidEvidenceInputError, MissingDAGValidationError, DAGCycleDetectedError, DAGValidationFailedError, MissingReviewEvidenceError, MissingCommitEvidenceError; print('OK')"; then
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

# Test 15: DAG validation - invalid result without cycles
echo ""
echo "Test 15: DAG validation - invalid result without cycles"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence, DAGValidationFailedError
try:
    validate_dag_evidence('run-14', 'implementation', {'valid': False, 'cycles': []})
    print('False')
except DAGValidationFailedError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid DAG result without cycles detected"
else
    fail "Invalid DAG result without cycles not detected"
fi

# Test 16: Empty actual files with non-empty scope passes
echo ""
echo "Test 16: Empty actual files with non-empty scope passes"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope
try:
    validate_write_scope('run-15', ['scripts/lib/'], [])
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Empty actual files pass with non-empty scope"
else
    fail "Empty actual files failed with non-empty scope"
fi

# Test 17: Path traversal violates write scope
echo ""
echo "Test 17: Path traversal violates write scope"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, WriteScopeViolationError
try:
    validate_write_scope('run-16', ['scripts/lib/'], ['scripts/lib/../../etc/passwd'])
    print('False')
except WriteScopeViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Path traversal violates write scope"
else
    fail "Path traversal did not violate write scope"
fi

# Test 18: Non-required stages can omit review and commit evidence
echo ""
echo "Test 18: Non-required stages can omit review and commit evidence"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_review_evidence, validate_commit_evidence
try:
    validate_review_evidence('run-17', 'solution_debate', None)
    validate_commit_evidence('run-17', 'solution_debate', None)
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Non-required stages can omit review and commit evidence"
else
    fail "Non-required stages incorrectly required evidence"
fi

# Test 19: Full worker advancement blocks empty write scope unless explicit
echo ""
echo "Test 19: Full worker advancement blocks empty write scope unless explicit"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-18'}
task = {
    'current_stage': 'implementation',
    'write_scope': [],
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['outside/scope.py'])
print(any('missing_write_scope' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Full worker advancement blocks empty write scope"
else
    fail "Full worker advancement permitted empty write scope"
fi

# Test 20: Task-level unrestricted write scope is rejected
echo ""
echo "Test 20: Task-level unrestricted write scope is rejected"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-19'}
task = {
    'current_stage': 'implementation',
    'write_scope': [],
    'write_scope_unrestricted': True,
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['outside/scope.py'])
print(any('invalid_evidence_input: write_scope_unrestricted' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Task-level unrestricted write scope is rejected"
else
    fail "Task-level unrestricted write scope was permitted"
fi

# Test 21: Leading traversal path violates matching scope
echo ""
echo "Test 21: Leading traversal path violates matching scope"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, WriteScopeViolationError
try:
    validate_write_scope('run-20', ['foo'], ['../foo'])
    print('False')
except WriteScopeViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Leading traversal path violates matching scope"
else
    fail "Leading traversal path was accepted"
fi

# Test 22: Scope prefix requires path boundary
echo ""
echo "Test 22: Scope prefix requires path boundary"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, WriteScopeViolationError
try:
    validate_write_scope('run-21', ['scripts'], ['scripts_evil/file.py'])
    print('False')
except WriteScopeViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Scope prefix escape rejected"
else
    fail "Scope prefix escape accepted"
fi

# Test 23: Invalid path type returns typed error through aggregator
echo ""
echo "Test 23: Invalid path type returns typed error through aggregator"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-22'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib'],
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, [None])
print(any('invalid_evidence_input' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid path type returns typed aggregator error"
else
    fail "Invalid path type did not return typed aggregator error"
fi

# Test 24: Invalid DAG type returns typed error through aggregator
echo ""
echo "Test 24: Invalid DAG type returns typed error through aggregator"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-23'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib'],
    'dag_validation_result': 'invalid',
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['scripts/lib/module.py'])
print(any('invalid_evidence_input: dag_validation_result' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid DAG type returns typed aggregator error"
else
    fail "Invalid DAG type did not return typed aggregator error"
fi

# Test 25: DAG validator schema with back_edges list[dict] detects cycle
echo ""
echo "Test 25: DAG validator schema with back_edges list[dict] detects cycle"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence, DAGCycleDetectedError
try:
    validate_dag_evidence('run-24', 'implementation', {'passed': False, 'cycle_detected': True, 'back_edges': [{'from': 'a', 'to': 'b'}]})
    print('False')
except DAGCycleDetectedError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "DAG validator back_edges list[dict] cycle detected"
else
    fail "DAG validator back_edges list[dict] cycle not detected"
fi

# Test 26: DAG validator schema failed without cycle
echo ""
echo "Test 26: DAG validator schema failed without cycle"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence, DAGValidationFailedError
try:
    validate_dag_evidence('run-25', 'implementation', {'passed': False, 'cycle_detected': False, 'back_edges': [], 'errors': ['orphan_task']})
    print('False')
except DAGValidationFailedError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "DAG validator non-cycle failure detected"
else
    fail "DAG validator non-cycle failure not detected"
fi

# Test 27: global_evaluation requires review evidence
echo ""
echo "Test 27: global_evaluation requires review evidence"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_review_evidence, MissingReviewEvidenceError
try:
    validate_review_evidence('run-26', 'global_evaluation', None)
    print('False')
except MissingReviewEvidenceError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "global_evaluation requires review evidence"
else
    fail "global_evaluation did not require review evidence"
fi

# Test 28: Missing current_stage fails closed
echo ""
echo "Test 28: Missing current_stage fails closed"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
errors = validate_worker_advancement({'run_id': 'run-27'}, {}, ['anywhere/x.py'])
print(any('missing_current_stage' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Missing current_stage fails closed"
else
    fail "Missing current_stage did not fail closed"
fi

# Test 29: Write scope error includes expected scope
echo ""
echo "Test 29: Write scope error includes expected scope"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-28'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib'],
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['config/secret.txt'])
print(any('\"expected_scope\": [\"scripts/lib\"]' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Write scope error includes concrete expected scope"
else
    fail "Write scope error omitted concrete expected scope"
fi

# Test 30: CLI stdin mode reports validation errors
echo ""
echo "Test 30: CLI stdin mode reports validation errors"
set +e
CLI_OUTPUT=$(printf '%s\n' '{"run":{"run_id":"run-29"},"task":{},"actual_changed_files":["anywhere/x.py"]}' | scripts/bin/orch-validate-worker-advancement)
CLI_STATUS=$?
set -e
RESULT=$(python3 -c "
import json
import sys
payload = json.loads(sys.argv[1])
print(sys.argv[2] == '1' and payload['valid'] is False and any('missing_current_stage' in error for error in payload['errors']))
" "$CLI_OUTPUT" "$CLI_STATUS")
if [ "$RESULT" = "True" ]; then
    pass "CLI stdin mode reports validation errors"
else
    fail "CLI stdin mode did not report validation errors"
fi

# Test 31: CLI argv mode reports valid advancement
echo ""
echo "Test 31: CLI argv mode reports valid advancement"
set +e
CLI_OUTPUT=$(scripts/bin/orch-validate-worker-advancement \
    --run '{"run_id":"run-30"}' \
    --task '{"current_stage":"implementation","write_scope":["scripts/lib"],"dag_validation_result":{"valid":true,"cycles":[]},"review_evidence":{"approved":true},"commit_evidence":{"commit_sha":"abc123"}}' \
    --actual-changed-files '["scripts/lib/worker_evidence_harden.py"]')
CLI_STATUS=$?
set -e
RESULT=$(python3 -c "
import json
import sys
payload = json.loads(sys.argv[1])
print(sys.argv[2] == '0' and payload['valid'] is True and payload['errors'] == [])
" "$CLI_OUTPUT" "$CLI_STATUS")
if [ "$RESULT" = "True" ]; then
    pass "CLI argv mode reports valid advancement"
else
    fail "CLI argv mode did not report valid advancement"
fi

# Test 32: Sentinel-looking scope does not match traversal path
echo ""
echo "Test 32: Sentinel-looking scope does not match traversal path"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, WriteScopeViolationError
try:
    validate_write_scope('run-31', ['__invalid_path__'], ['../escape.py'])
    print('False')
except WriteScopeViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Sentinel-looking scope does not match traversal path"
else
    fail "Sentinel-looking scope matched traversal path"
fi

# Test 33: Invalid scope path is rejected as input
echo ""
echo "Test 33: Invalid scope path is rejected as input"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, InvalidEvidenceInputError
try:
    validate_write_scope('run-32', ['/etc'], ['etc/passwd'])
    print('False')
except InvalidEvidenceInputError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid scope path is rejected as input"
else
    fail "Invalid scope path was not rejected"
fi

# Test 34: Empty scope string is rejected as input
echo ""
echo "Test 34: Empty scope string is rejected as input"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, InvalidEvidenceInputError
try:
    validate_write_scope('run-33', [''], ['scripts/lib/module.py'])
    print('False')
except InvalidEvidenceInputError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Empty scope string is rejected as input"
else
    fail "Empty scope string was not rejected"
fi

# Test 35: Dot scope explicitly covers repository root
echo ""
echo "Test 35: Dot scope explicitly covers repository root"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope
try:
    validate_write_scope('run-34', ['.'], ['scripts/lib/module.py'])
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Dot scope explicitly covers repository root"
else
    fail "Dot scope did not cover repository root"
fi

# Test 36: Stage canonicalization blocks case-spoof bypass
echo ""
echo "Test 36: Stage canonicalization blocks case-spoof bypass"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-35'}
task = {'current_stage': 'Implementation', 'write_scope': ['scripts/lib']}
errors = validate_worker_advancement(run, task, ['scripts/lib/module.py'])
print(any('missing_dag_validation: implementation' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Stage canonicalization blocks case-spoof bypass"
else
    fail "Stage case spoof bypassed evidence gates"
fi

# Test 37: Unknown stage fails closed
echo ""
echo "Test 37: Unknown stage fails closed"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
errors = validate_worker_advancement({'run_id': 'run-36'}, {'current_stage': 'impl', 'write_scope': ['scripts/lib']}, ['scripts/lib/module.py'])
print(any('unknown_stage: impl' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Unknown stage fails closed"
else
    fail "Unknown stage did not fail closed"
fi

# Test 38: Stage ordering mismatch fails closed
echo ""
echo "Test 38: Stage ordering mismatch fails closed"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-37', 'current_stage': 'solution_debate'}
task = {
    'current_stage': 'global_evaluation',
    'write_scope': ['scripts/lib'],
    'review_evidence': {'approved': True}
}
errors = validate_worker_advancement(run, task, ['scripts/lib/module.py'])
print(any('stage_order_violation: run_current_stage=solution_debate; task_stage=global_evaluation' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Stage ordering mismatch fails closed"
else
    fail "Stage ordering mismatch did not fail closed"
fi

# Test 39: direction_debate requires write scope
echo ""
echo "Test 39: direction_debate requires write scope"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
errors = validate_worker_advancement({'run_id': 'run-38'}, {'current_stage': 'direction_debate', 'write_scope': []}, ['best_choice_report.json'])
print(any('missing_write_scope: direction_debate' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "direction_debate requires write scope"
else
    fail "direction_debate did not require write scope"
fi

# Test 40: DAG falsy valid value fails validation
echo ""
echo "Test 40: DAG falsy valid value fails validation"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence, DAGValidationFailedError
try:
    validate_dag_evidence('run-39', 'implementation', {'valid': 0, 'cycles': []})
    print('False')
except DAGValidationFailedError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "DAG falsy valid value fails validation"
else
    fail "DAG falsy valid value bypassed validation"
fi

# Test 41: DAG errors fail even when passed is true
echo ""
echo "Test 41: DAG errors fail even when passed is true"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_dag_evidence, DAGValidationFailedError
try:
    validate_dag_evidence('run-40', 'implementation', {'passed': True, 'errors': ['orphan_task']})
    print('False')
except DAGValidationFailedError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "DAG errors fail even when passed is true"
else
    fail "DAG errors were ignored when passed is true"
fi

# Test 42: Missing stage does not hide other evidence errors
echo ""
echo "Test 42: Missing stage does not hide other evidence errors"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
errors = validate_worker_advancement({'run_id': 'run-41'}, {'write_scope': ['/abs']}, ['anywhere/x.py'])
print(any('missing_current_stage' in error for error in errors) and any('invalid_evidence_input: expected_scope' in error for error in errors))
")
if [ "$RESULT" = "True" ]; then
    pass "Missing stage does not hide other evidence errors"
else
    fail "Missing stage hid other evidence errors"
fi

# Test 43: Run and task type guards return typed errors
echo ""
echo "Test 43: Run and task type guards return typed errors"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
print(
    validate_worker_advancement(None, {}, []) == ['invalid_evidence_input: run']
    and validate_worker_advancement({'run_id': 'run-42'}, None, []) == ['invalid_evidence_input: task']
)
")
if [ "$RESULT" = "True" ]; then
    pass "Run and task type guards return typed errors"
else
    fail "Run and task type guards did not return typed errors"
fi

# Test 44: Null byte changed path violates write scope
echo ""
echo "Test 44: Null byte changed path violates write scope"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_write_scope, WriteScopeViolationError
try:
    validate_write_scope('run-43', ['scripts/lib'], ['scripts/lib/module.py\x00'])
    print('False')
except WriteScopeViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Null byte changed path violates write scope"
else
    fail "Null byte changed path was accepted"
fi

# Test 45: CLI malformed JSON exits 2 with structured error
echo ""
echo "Test 45: CLI malformed JSON exits 2 with structured error"
set +e
CLI_OUTPUT=$(printf '%s\n' '{bad json' | scripts/bin/orch-validate-worker-advancement)
CLI_STATUS=$?
set -e
RESULT=$(python3 -c "
import json
import sys
payload = json.loads(sys.argv[1])
print(sys.argv[2] == '2' and payload['valid'] is False and payload['errors'][0].startswith('usage_error: stdin_payload_invalid_json'))
" "$CLI_OUTPUT" "$CLI_STATUS")
if [ "$RESULT" = "True" ]; then
    pass "CLI malformed JSON exits 2 with structured error"
else
    fail "CLI malformed JSON did not return structured usage error"
fi

# Test 46: CLI empty stdin exits 2 with structured error
echo ""
echo "Test 46: CLI empty stdin exits 2 with structured error"
set +e
CLI_OUTPUT=$(printf '' | scripts/bin/orch-validate-worker-advancement)
CLI_STATUS=$?
set -e
RESULT=$(python3 -c "
import json
import sys
payload = json.loads(sys.argv[1])
print(sys.argv[2] == '2' and payload == {'errors': ['usage_error: stdin_payload_required'], 'valid': False})
" "$CLI_OUTPUT" "$CLI_STATUS")
if [ "$RESULT" = "True" ]; then
    pass "CLI empty stdin exits 2 with structured error"
else
    fail "CLI empty stdin did not return structured usage error"
fi

# Test 47: CLI oversized JSON exits 2 with structured error
echo ""
echo "Test 47: CLI oversized JSON exits 2 with structured error"
set +e
CLI_OUTPUT=$(python3 - <<'PY' | scripts/bin/orch-validate-worker-advancement
import sys
sys.stdout.write('{"run":{"run_id":"' + ('x' * 1048577) + '"},"task":{},"actual_changed_files":[]}')
PY
)
CLI_STATUS=$?
set -e
RESULT=$(python3 -c "
import json
import sys
payload = json.loads(sys.argv[1])
print(sys.argv[2] == '2' and payload == {'errors': ['usage_error: stdin_payload_too_large'], 'valid': False})
" "$CLI_OUTPUT" "$CLI_STATUS")
if [ "$RESULT" = "True" ]; then
    pass "CLI oversized JSON exits 2 with structured error"
else
    fail "CLI oversized JSON did not return structured usage error"
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
