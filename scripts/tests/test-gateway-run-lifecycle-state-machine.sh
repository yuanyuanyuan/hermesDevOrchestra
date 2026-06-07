#!/usr/bin/env bash
# Test: PRD Run Lifecycle State Machine
# Tests legal and illegal transitions, paused/blocked resume behavior

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
echo "Test: PRD Run Lifecycle State Machine"
echo "=========================================="
echo ""

# Test 1: Import lifecycle module
echo "Test 1: Import lifecycle module"
if python3 -c "from run_lifecycle import LIFECYCLE_STATES, TRANSITION_GUARD_TABLE, can_transition, validate_transition, get_lifecycle_status, get_resume_target, resume, InvalidTransitionError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Initial state is created
echo ""
echo "Test 2: Initial state is created"
RESULT=$(python3 -c "
from run_lifecycle import get_lifecycle_status
run = {'run_id': 'test-1', 'status': 'queued'}
print(get_lifecycle_status(run))
")
if [ "$RESULT" = "created" ]; then
    pass "Initial state is 'created'"
else
    fail "Expected 'created', got '$RESULT'"
fi

# Test 3: Legal transition created -> intake_complete
echo ""
echo "Test 3: Legal transition created -> intake_complete"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('created', 'intake_complete'))
")
if [ "$RESULT" = "True" ]; then
    pass "created -> intake_complete is legal"
else
    fail "created -> intake_complete should be legal"
fi

# Test 4: Legal transition intake_complete -> direction_debate
echo ""
echo "Test 4: Legal transition intake_complete -> direction_debate"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('intake_complete', 'direction_debate'))
")
if [ "$RESULT" = "True" ]; then
    pass "intake_complete -> direction_debate is legal"
else
    fail "intake_complete -> direction_debate should be legal"
fi

# Test 5: Legal transition direction_debate -> solution_debate
echo ""
echo "Test 5: Legal transition direction_debate -> solution_debate"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('direction_debate', 'solution_debate'))
")
if [ "$RESULT" = "True" ]; then
    pass "direction_debate -> solution_debate is legal"
else
    fail "direction_debate -> solution_debate should be legal"
fi

# Test 6: Legal transition solution_debate -> implementation
echo ""
echo "Test 6: Legal transition solution_debate -> implementation"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('solution_debate', 'implementation'))
")
if [ "$RESULT" = "True" ]; then
    pass "solution_debate -> implementation is legal"
else
    fail "solution_debate -> implementation should be legal"
fi

# Test 7: Legal transition implementation -> improvement
echo ""
echo "Test 7: Legal transition implementation -> improvement"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('implementation', 'improvement'))
")
if [ "$RESULT" = "True" ]; then
    pass "implementation -> improvement is legal"
else
    fail "implementation -> improvement should be legal"
fi

# Test 8: Legal transition improvement -> global_evaluation
echo ""
echo "Test 8: Legal transition improvement -> global_evaluation"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('improvement', 'global_evaluation'))
")
if [ "$RESULT" = "True" ]; then
    pass "improvement -> global_evaluation is legal"
else
    fail "improvement -> global_evaluation should be legal"
fi

# Test 9: Legal transition global_evaluation -> closed
echo ""
echo "Test 9: Legal transition global_evaluation -> closed"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('global_evaluation', 'closed'))
")
if [ "$RESULT" = "True" ]; then
    pass "global_evaluation -> closed is legal"
else
    fail "global_evaluation -> closed should be legal"
fi

# Test 10: Illegal transition created -> implementation (skip stages)
echo ""
echo "Test 10: Illegal transition created -> implementation (skip stages)"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('created', 'implementation'))
")
if [ "$RESULT" = "False" ]; then
    pass "created -> implementation is illegal (correctly rejected)"
else
    fail "created -> implementation should be illegal"
fi

# Test 11: Illegal transition created -> closed (skip all stages)
echo ""
echo "Test 11: Illegal transition created -> closed (skip all stages)"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('created', 'closed'))
")
if [ "$RESULT" = "False" ]; then
    pass "created -> closed is illegal (correctly rejected)"
else
    fail "created -> closed should be illegal"
fi

# Test 12: Illegal transition closed -> created (cannot reopen)
echo ""
echo "Test 12: Illegal transition closed -> created (cannot reopen)"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('closed', 'created'))
")
if [ "$RESULT" = "False" ]; then
    pass "closed -> created is illegal (correctly rejected)"
else
    fail "closed -> created should be illegal"
fi

# Test 13: Illegal transition cancelled -> implementation (cannot resume)
echo ""
echo "Test 13: Illegal transition cancelled -> implementation (cannot resume)"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('cancelled', 'implementation'))
")
if [ "$RESULT" = "False" ]; then
    pass "cancelled -> implementation is illegal (correctly rejected)"
else
    fail "cancelled -> implementation should be illegal"
fi

# Test 14: Legal transition to blocked
echo ""
echo "Test 14: Legal transition to blocked"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('intake_complete', 'blocked'))
")
if [ "$RESULT" = "True" ]; then
    pass "intake_complete -> blocked is legal"
else
    fail "intake_complete -> blocked should be legal"
fi

# Test 15: Blocked run cannot resume without resolving blockers
echo ""
echo "Test 15: Blocked run cannot resume without resolving blockers"
RESULT=$(python3 -c "
from run_lifecycle import can_resume
run = {'run_id': 'test-2', 'lifecycle_status': 'blocked', 'blocker_refs': ['ref-1']}
print(can_resume(run))
")
if [ "$RESULT" = "False" ]; then
    pass "Blocked run with blockers cannot resume"
else
    fail "Blocked run with blockers should not resume"
fi

# Test 16: Blocked run can resume after resolving blockers and declaring target
echo ""
echo "Test 16: Blocked run can resume after resolving blockers and declaring target"
RESULT=$(python3 -c "
from run_lifecycle import can_resume
run = {'run_id': 'test-3', 'lifecycle_status': 'blocked', 'blocker_refs': [], 'resume_lifecycle_status': 'implementation'}
print(can_resume(run))
")
if [ "$RESULT" = "True" ]; then
    pass "Blocked run without blockers and with target can resume"
else
    fail "Blocked run without blockers and with target should resume"
fi

# Test 17: Paused run can resume with previous lifecycle target
echo ""
echo "Test 17: Paused run can resume with previous lifecycle target"
RESULT=$(python3 -c "
from run_lifecycle import can_resume
run = {'run_id': 'test-4', 'lifecycle_status': 'paused', 'previous_lifecycle_status': 'direction_debate'}
print(can_resume(run))
")
if [ "$RESULT" = "True" ]; then
    pass "Paused run with previous target can resume"
else
    fail "Paused run with previous target should resume"
fi

# Test 18: Legal transition to rollback_requested
echo ""
echo "Test 18: Legal transition to rollback_requested"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('implementation', 'rollback_requested'))
")
if [ "$RESULT" = "True" ]; then
    pass "implementation -> rollback_requested is legal"
else
    fail "implementation -> rollback_requested should be legal"
fi

# Test 19: Illegal transition from cancelled to rollback_requested
echo ""
echo "Test 19: Illegal transition from cancelled to rollback_requested"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('cancelled', 'rollback_requested'))
")
if [ "$RESULT" = "False" ]; then
    pass "cancelled -> rollback_requested is illegal (correctly rejected)"
else
    fail "cancelled -> rollback_requested should be illegal"
fi

# Test 20: Backward compatibility - status mapping
echo ""
echo "Test 20: Backward compatibility - status mapping"
RESULT=$(python3 -c "
from run_lifecycle import get_lifecycle_status
run = {'run_id': 'test-5', 'status': 'running'}
print(get_lifecycle_status(run))
")
if [ "$RESULT" = "intake_complete" ]; then
    pass "Old status 'running' maps to 'intake_complete'"
else
    fail "Expected 'intake_complete', got '$RESULT'"
fi

# Test 21: Backward compatibility - running status uses current_stage when present
echo ""
echo "Test 21: Backward compatibility - running status uses current_stage when present"
RESULT=$(python3 -c "
from run_lifecycle import get_lifecycle_status
run = {'run_id': 'test-6', 'status': 'running', 'current_stage': 'implementation'}
print(get_lifecycle_status(run))
")
if [ "$RESULT" = "implementation" ]; then
    pass "Old status 'running' maps from current_stage"
else
    fail "Expected 'implementation', got '$RESULT'"
fi

# Test 22: Paused cannot directly jump across active states
echo ""
echo "Test 22: Paused cannot directly jump across active states"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('paused', 'continuous_improvement'))
")
if [ "$RESULT" = "False" ]; then
    pass "paused -> continuous_improvement is illegal"
else
    fail "paused -> continuous_improvement should be illegal"
fi

# Test 23: Blocked cannot directly jump across active states
echo ""
echo "Test 23: Blocked cannot directly jump across active states"
RESULT=$(python3 -c "
from run_lifecycle import can_transition
print(can_transition('blocked', 'continuous_improvement'))
")
if [ "$RESULT" = "False" ]; then
    pass "blocked -> continuous_improvement is illegal"
else
    fail "blocked -> continuous_improvement should be illegal"
fi

# Test 24: Resume moves paused run to explicit previous lifecycle target
echo ""
echo "Test 24: Resume moves paused run to explicit previous lifecycle target"
RESULT=$(python3 -c "
from run_lifecycle import resume
run = {'run_id': 'test-7', 'lifecycle_status': 'paused', 'previous_lifecycle_status': 'implementation'}
print(resume(run)['lifecycle_status'])
")
if [ "$RESULT" = "implementation" ]; then
    pass "Paused run resumes to explicit previous lifecycle target"
else
    fail "Expected 'implementation', got '$RESULT'"
fi

# Test 25: Blocked run with unresolved blockers cannot resume despite target
echo ""
echo "Test 25: Blocked run with unresolved blockers cannot resume despite target"
RESULT=$(python3 -c "
from run_lifecycle import can_resume
run = {'run_id': 'test-8', 'lifecycle_status': 'blocked', 'blocker_refs': ['ref-1'], 'resume_lifecycle_status': 'implementation'}
print(can_resume(run))
")
if [ "$RESULT" = "False" ]; then
    pass "Blocked run with unresolved blockers cannot resume"
else
    fail "Blocked run with unresolved blockers should not resume"
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
