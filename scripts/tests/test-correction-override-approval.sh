#!/usr/bin/env bash
# Test: Correction and Override Approval
# Tests correction rounds and override records for approval workflows

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
echo "Test: Correction and Override Approval"
echo "=========================================="
echo ""

# Test 1: Import correction module
echo "Test 1: Import correction module"
if python3 -c "from correction_override import create_correction_round, create_override_record, approve_override, reject_override, get_pending_overrides, validate_override_record, check_override_auto_merge_blocked, OverrideApprovalRequiredError, MissingApproverRefError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Create correction round
echo ""
echo "Test 2: Create correction round"
RESULT=$(python3 -c "
from correction_override import create_correction_round
round = create_correction_round('run-1', 'task-1', 'user_override', 'compact', 'Fix typo', ['ref-1'])
print(round['status'] == 'pending' and round['evidence_mode'] == 'compact')
")
if [ "$RESULT" = "True" ]; then
    pass "Correction round created correctly"
else
    fail "Correction round creation failed"
fi

# Test 3: Create override record - L1 (auto-approve)
echo ""
echo "Test 3: Create override record - L1 (auto-approve)"
RESULT=$(python3 -c "
from correction_override import create_override_record
override = create_override_record('run-2', 'task-2', [], 'minor_fix', 'L1')
print(override['status'] == 'approved' and override['requires_approval'] == False)
")
if [ "$RESULT" = "True" ]; then
    pass "L1 override auto-approved"
else
    fail "L1 override not auto-approved"
fi

# Test 4: Create override record - L3 (requires approval)
echo ""
echo "Test 4: Create override record - L3 (requires approval)"
RESULT=$(python3 -c "
from correction_override import create_override_record
override = create_override_record('run-3', 'task-3', [], 'major_change', 'L3')
print(override['status'] == 'pending_approval' and override['requires_approval'] == True)
")
if [ "$RESULT" = "True" ]; then
    pass "L3 override pending approval"
else
    fail "L3 override not pending approval"
fi

# Test 5: Approve override
echo ""
echo "Test 5: Approve override"
RESULT=$(python3 -c "
from correction_override import create_override_record, approve_override
run = {'run_id': 'run-4', 'override_records': [create_override_record('run-4', 'task-4', [], 'major_change', 'L3')]}
override_id = run['override_records'][0]['override_id']
approved = approve_override(run, override_id, 'human-approver-1')
print(approved['status'] == 'approved' and approved['approver_ref'] == 'human-approver-1')
")
if [ "$RESULT" = "True" ]; then
    pass "Override approved successfully"
else
    fail "Override approval failed"
fi

# Test 6: Reject override
echo ""
echo "Test 6: Reject override"
RESULT=$(python3 -c "
from correction_override import create_override_record, reject_override
run = {'run_id': 'run-5', 'override_records': [create_override_record('run-5', 'task-5', [], 'minor_fix', 'L2')]}
override_id = run['override_records'][0]['override_id']
rejected = reject_override(run, override_id, 'Not justified')
print(rejected['status'] == 'rejected' and rejected['rejection_reason'] == 'Not justified')
")
if [ "$RESULT" = "True" ]; then
    pass "Override rejected successfully"
else
    fail "Override rejection failed"
fi

# Test 7: Get pending overrides
echo ""
echo "Test 7: Get pending overrides"
RESULT=$(python3 -c "
from correction_override import create_override_record, get_pending_overrides
run = {'run_id': 'run-6', 'override_records': [
    create_override_record('run-6', 'task-6a', [], 'major_change', 'L3'),
    create_override_record('run-6', 'task-6b', [], 'minor_fix', 'L1')
]}
pending = get_pending_overrides(run)
print(len(pending) == 1 and pending[0]['task_id'] == 'task-6a')
")
if [ "$RESULT" = "True" ]; then
    pass "Pending overrides retrieved correctly"
else
    fail "Pending overrides retrieval failed"
fi

# Test 8: Validate override record - valid
echo ""
echo "Test 8: Validate override record - valid"
RESULT=$(python3 -c "
from correction_override import create_override_record, validate_override_record
override = create_override_record('run-7', 'task-7', [], 'minor_fix', 'L1')
errors = validate_override_record(override)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid override passes validation"
else
    fail "Valid override fails validation"
fi

# Test 9: Validate override record - missing fields
echo ""
echo "Test 9: Validate override record - missing fields"
RESULT=$(python3 -c "
from correction_override import validate_override_record
errors = validate_override_record({})
print(len(errors) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing fields detected"
else
    fail "Missing fields not detected"
fi

# Test 10: Auto-merge blocked for pending overrides
echo ""
echo "Test 10: Auto-merge blocked for pending overrides"
RESULT=$(python3 -c "
from correction_override import create_override_record, check_override_auto_merge_blocked
run = {'run_id': 'run-8', 'override_records': [create_override_record('run-8', 'task-8', [], 'major_change', 'L3')]}
blocked = check_override_auto_merge_blocked(run)
print(blocked == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge blocked for pending overrides"
else
    fail "Auto-merge not blocked correctly"
fi

# Test 11: Auto-merge not blocked when no pending overrides
echo ""
echo "Test 11: Auto-merge not blocked when no pending overrides"
RESULT=$(python3 -c "
from correction_override import create_override_record, check_override_auto_merge_blocked
run = {'run_id': 'run-9', 'override_records': [create_override_record('run-9', 'task-9', [], 'minor_fix', 'L1')]}
blocked = check_override_auto_merge_blocked(run)
print(blocked == False)
")
if [ "$RESULT" = "True" ]; then
    pass "Auto-merge not blocked when no pending"
else
    fail "Auto-merge incorrectly blocked"
fi

# Test 12: Correction round with full evidence mode
echo ""
echo "Test 12: Correction round with full evidence mode"
RESULT=$(python3 -c "
from correction_override import create_correction_round
round = create_correction_round('run-10', 'task-10', 'user_override', 'full', 'Major correction', ['ref-1', 'ref-2'])
print(round['evidence_mode'] == 'full' and len(round['evidence_refs']) == 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Correction round with full evidence mode created"
else
    fail "Correction round creation failed"
fi

# Test 13: Override with approver ref at creation
echo ""
echo "Test 13: Override with approver ref at creation"
RESULT=$(python3 -c "
from correction_override import create_override_record
override = create_override_record('run-11', 'task-11', [], 'major_change', 'L3', approver_ref='human-1')
print(override['approver_ref'] == 'human-1' and override['status'] == 'pending')
")
if [ "$RESULT" = "True" ]; then
    pass "Override with approver ref created"
else
    fail "Override with approver ref creation failed"
fi

# Test 14: Multiple correction rounds in override
echo ""
echo "Test 14: Multiple correction rounds in override"
RESULT=$(python3 -c "
from correction_override import create_correction_round, create_override_record
rounds = [
    create_correction_round('run-12', 'task-12', 'user_override', 'compact', 'First attempt', ['ref-1']),
    create_correction_round('run-12', 'task-12', 'user_override', 'full', 'Second attempt', ['ref-2'])
]
override = create_override_record('run-12', 'task-12', rounds, 'major_change', 'L3')
print(len(override['correction_rounds']) == 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Multiple correction rounds in override"
else
    fail "Multiple correction rounds handling failed"
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
