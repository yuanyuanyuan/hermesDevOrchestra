#!/usr/bin/env bash
# Test: Rollback Strategy
# Tests rollback request, execution, and reporting with scope protection

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
echo "Test: Rollback Strategy"
echo "=========================================="
echo ""

# Test 1: Import rollback module
echo "Test 1: Import rollback module"
if python3 -c "from rollback_executor import create_rollback_request, execute_rollback, validate_rollback_prereqs, check_protected_targets, write_rollback_report, load_rollback_report, RollbackPrereqMissingError, ProtectedTargetApprovalRequiredError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Create rollback request
echo ""
echo "Test 2: Create rollback request"
RESULT=$(python3 -c "
from datetime import datetime
from rollback_executor import create_rollback_request
request = create_rollback_request('run-1', 'implementation', 'abc123', 'Test rollback')
timestamp = request['request_id'].removeprefix('rollback-run-1-')
datetime.strptime(timestamp, '%Y%m%d%H%M%S')
print(request['request_id'].startswith('rollback-run-1-') and len(timestamp) == 14)
")
if [ "$RESULT" = "True" ]; then
    pass "Rollback request created with correct ID format"
else
    fail "Rollback request ID format incorrect"
fi

# Test 3: Validate prerequisites - all present
echo ""
echo "Test 3: Validate prerequisites - all present"
RESULT=$(python3 -c "
from rollback_executor import validate_rollback_prereqs
run = {'run_id': 'run-1', 'baseline_ref': 'abc123'}
request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
missing = validate_rollback_prereqs(run, request)
print(len(missing) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Prerequisites validated (all present)"
else
    fail "Prerequisites validation failed"
fi

# Test 4: Validate prerequisites - missing baseline_ref
echo ""
echo "Test 4: Validate prerequisites - missing baseline_ref"
RESULT=$(python3 -c "
from rollback_executor import validate_rollback_prereqs
run = {'run_id': 'run-1'}
request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation'}
missing = validate_rollback_prereqs(run, request)
print('baseline_ref' in missing)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing baseline_ref detected"
else
    fail "Missing baseline_ref not detected"
fi

# Test 5: Validate prerequisites - missing run_id
echo ""
echo "Test 5: Validate prerequisites - missing run_id"
RESULT=$(python3 -c "
from rollback_executor import validate_rollback_prereqs
run = {}
request = {'request_id': 'req-1', 'requested_stage': 'implementation'}
missing = validate_rollback_prereqs(run, request)
print('run_id' in missing)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing run_id detected"
else
    fail "Missing run_id not detected"
fi

# Test 6: Check protected targets - none
echo ""
echo "Test 6: Check protected targets - none"
RESULT=$(python3 -c "
from rollback_executor import check_protected_targets
refs = ['state://runs/run-1/tasks/task-1', 'state://runs/run-1/conflict-ledger.json']
protected = check_protected_targets(refs)
print(len(protected) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Non-protected targets detected correctly"
else
    fail "Non-protected targets incorrectly flagged"
fi

# Test 7: Check protected targets - found
echo ""
echo "Test 7: Check protected targets - found"
RESULT=$(python3 -c "
from rollback_executor import check_protected_targets
refs = ['config/release/commands.json', 'state://runs/run-1/tasks/task-1']
protected = check_protected_targets(refs)
print('config/release/commands.json' in protected)
")
if [ "$RESULT" = "True" ]; then
    pass "Protected target detected"
else
    fail "Protected target not detected"
fi

# Test 8: Check protected targets - custom target set
echo ""
echo "Test 8: Check protected targets - custom target set"
RESULT=$(python3 -c "
from rollback_executor import check_protected_targets
refs = ['custom/protected.yaml', 'config/release/commands.json']
protected = check_protected_targets(refs, {'custom/protected.yaml'})
print(protected == ['custom/protected.yaml'])
")
if [ "$RESULT" = "True" ]; then
    pass "Custom protected target set honored"
else
    fail "Custom protected target set not honored"
fi

# Test 9: Validate prerequisites - request_id format mismatch
echo ""
echo "Test 9: Validate prerequisites - request_id format mismatch"
RESULT=$(python3 -c "
from rollback_executor import validate_rollback_prereqs
run = {'run_id': 'run-1', 'baseline_ref': 'abc123'}
request = {'request_id': 'rollback-other-run-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
missing = validate_rollback_prereqs(run, request)
print('request_id_format' in missing)
")
if [ "$RESULT" = "True" ]; then
    pass "request_id format mismatch detected"
else
    fail "request_id format mismatch not detected"
fi

# Test 10: Execute rollback - success (dry run)
echo ""
echo "Test 10: Execute rollback - success (dry run)"
RESULT=$(python3 -c "
from rollback_executor import execute_rollback
run = {'run_id': 'run-1', 'baseline_ref': 'abc123', 'changed_refs': ['state://runs/run-1/tasks/task-1']}
request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
report = execute_rollback(run, request, dry_run=True)
print(report['result'] == 'dry_run' and report['run_id'] == 'run-1')
")
if [ "$RESULT" = "True" ]; then
    pass "Dry run rollback executed successfully"
else
    fail "Dry run rollback failed"
fi

# Test 11: Execute rollback - prereq missing
echo ""
echo "Test 11: Execute rollback - prereq missing"
RESULT=$(python3 -c "
from rollback_executor import execute_rollback, RollbackPrereqMissingError
try:
    run = {}
    request = {'request_id': 'req-1', 'requested_stage': 'implementation'}
    execute_rollback(run, request)
    print('False')
except RollbackPrereqMissingError as e:
    print('baseline_ref' in e.missing)
")
if [ "$RESULT" = "True" ]; then
    pass "RollbackPrereqMissingError raised correctly"
else
    fail "RollbackPrereqMissingError not raised"
fi

# Test 12: Execute rollback - protected target approval required
echo ""
echo "Test 12: Execute rollback - protected target approval required"
RESULT=$(python3 -c "
from rollback_executor import execute_rollback, ProtectedTargetApprovalRequiredError
try:
    run = {'run_id': 'run-1', 'baseline_ref': 'abc123', 'changed_refs': ['config/release/commands.json']}
    request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
    execute_rollback(run, request, dry_run=False)
    print('False')
except ProtectedTargetApprovalRequiredError as e:
    print('config/release/commands.json' in e.targets)
")
if [ "$RESULT" = "True" ]; then
    pass "ProtectedTargetApprovalRequiredError raised correctly"
else
    fail "ProtectedTargetApprovalRequiredError not raised"
fi

# Test 13: Rollback report structure
echo ""
echo "Test 13: Rollback report structure"
RESULT=$(python3 -c "
from rollback_executor import execute_rollback
run = {'run_id': 'run-1', 'baseline_ref': 'abc123', 'changed_refs': ['state://runs/run-1/tasks/task-1']}
request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
report = execute_rollback(run, request, dry_run=True)
required_keys = ['run_id', 'request_id', 'requested_stage', 'baseline_ref', 'rollback_strategy', 'affected_refs', 'protected_target_check', 'result', 'reason', 'created_at', 'completed_at']
print(all(k in report for k in required_keys))
")
if [ "$RESULT" = "True" ]; then
    pass "Rollback report has all required fields"
else
    fail "Rollback report missing required fields"
fi

# Test 14: Rollback only affects current-run refs
echo ""
echo "Test 14: Rollback only affects current-run refs"
RESULT=$(python3 -c "
from rollback_executor import execute_rollback
run = {
    'run_id': 'run-1',
    'baseline_ref': 'abc123',
    'changed_refs': [
        'state://runs/run-1/tasks/task-1',
        'state://runs/run-1/conflict-ledger.json',
        'repo://other-repo/file.txt'
    ]
}
request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
report = execute_rollback(run, request, dry_run=True)
# Only state://runs/run-1/* refs should be affected
all_current_run = all(ref.startswith('state://runs/run-1/') for ref in report['affected_refs'])
print(all_current_run and len(report['affected_refs']) == 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Only current-run refs affected by rollback"
else
    fail "Rollback affects non-current-run refs"
fi

# Test 15: Multiple protected targets
echo ""
echo "Test 15: Multiple protected targets"
RESULT=$(python3 -c "
from rollback_executor import check_protected_targets
refs = ['config/release/commands.json', 'config/schemas/orchestra.full.schema.json', 'state://runs/run-1/tasks/task-1']
protected = check_protected_targets(refs)
print(len(protected) == 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Multiple protected targets detected"
else
    fail "Multiple protected targets not detected"
fi

# Test 16: Rollback strategy default
echo ""
echo "Test 16: Rollback strategy default"
RESULT=$(python3 -c "
from rollback_executor import execute_rollback
run = {'run_id': 'run-1', 'baseline_ref': 'abc123', 'changed_refs': ['state://runs/run-1/tasks/task-1']}
request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
report = execute_rollback(run, request, dry_run=True)
print(report['rollback_strategy'] == 'git_revert')
")
if [ "$RESULT" = "True" ]; then
    pass "Default rollback strategy is git_revert"
else
    fail "Default rollback strategy incorrect"
fi

# Test 17: Rollback report write/load round trip
echo ""
echo "Test 17: Rollback report write/load round trip"
RESULT=$(python3 -c "
import tempfile
from rollback_executor import execute_rollback, write_rollback_report, load_rollback_report
run = {'run_id': 'run-1', 'baseline_ref': 'abc123', 'changed_refs': ['state://runs/run-1/tasks/task-1']}
request = {'request_id': 'rollback-run-1-20260101010101', 'requested_stage': 'implementation', 'baseline_ref': 'abc123'}
report = execute_rollback(run, request, dry_run=True)
with tempfile.TemporaryDirectory() as tmp:
    path = write_rollback_report(report, tmp)
    loaded = load_rollback_report(tmp)
    print(path.name == 'rollback_report.json' and loaded == report)
")
if [ "$RESULT" = "True" ]; then
    pass "Rollback report write/load round trip works"
else
    fail "Rollback report write/load round trip failed"
fi

# Test 18: Missing rollback report loads as None
echo ""
echo "Test 18: Missing rollback report loads as None"
RESULT=$(python3 -c "
import tempfile
from rollback_executor import load_rollback_report
with tempfile.TemporaryDirectory() as tmp:
    print(load_rollback_report(tmp) is None)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing rollback report returns None"
else
    fail "Missing rollback report should return None"
fi

# Test 19: Corrupted rollback report loads as None
echo ""
echo "Test 19: Corrupted rollback report loads as None"
RESULT=$(python3 -c "
import pathlib
import tempfile
from rollback_executor import load_rollback_report
with tempfile.TemporaryDirectory() as tmp:
    pathlib.Path(tmp, 'rollback_report.json').write_text('{bad json', encoding='utf-8')
    print(load_rollback_report(tmp) is None)
")
if [ "$RESULT" = "True" ]; then
    pass "Corrupted rollback report returns None"
else
    fail "Corrupted rollback report should return None"
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
