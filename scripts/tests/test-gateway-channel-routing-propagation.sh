#!/usr/bin/env bash
# Test: Channel Routing Propagation
# Tests channel decision persistence and stage behavior effects

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
echo "Test: Channel Routing Propagation"
echo "=========================================="
echo ""

# Test 1: Import channel routing module
echo "Test 1: Import channel routing module"
if python3 -c "from channel_routing_propagation import classify_and_persist, get_channel_requirements, can_skip_stage, get_required_evidence, get_required_debate_rounds, ChannelPolicyInvalidError, RolloutEvidenceMissingError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Light channel persists correctly
echo ""
echo "Test 2: Light channel persists correctly"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist
run = {'run_id': 'run-1', 'rollout_evidence': ['rollout_approval']}
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24, force_standard=False)
print(updated['channel_decision']['channel'] == 'light')
")
if [ "$RESULT" = "True" ]; then
    pass "Light channel persisted correctly"
else
    fail "Light channel not persisted"
fi

# Test 3: Standard channel persists correctly (forced)
echo ""
echo "Test 3: Standard channel persists correctly (forced)"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist
run = {'run_id': 'run-2'}
updated = classify_and_persist(run, 'Major refactor', ['a.py', 'b.py', 'c.py', 'd.py', 'e.py', 'f.py'], 4, force_standard=True)
print(updated['channel_decision']['channel'] == 'standard')
")
if [ "$RESULT" = "True" ]; then
    pass "Standard channel persisted correctly (forced)"
else
    fail "Standard channel not persisted"
fi

# Test 4: Forced standard channel
echo ""
echo "Test 4: Forced standard channel"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist
run = {'run_id': 'run-3'}
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24, force_standard=True, force_standard_reasons=['security_issue'])
print(updated['channel_decision']['channel'] == 'standard' and updated['channel_decision']['forced_standard'] == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Forced standard channel works"
else
    fail "Forced standard channel failed"
fi

# Test 5: Light channel allows stage skips
echo ""
echo "Test 5: Light channel allows stage skips"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, can_skip_stage
run = {'run_id': 'run-4', 'rollout_evidence': ['rollout_approval']}
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24)
print(can_skip_stage(updated, 'direction_debate'))
")
if [ "$RESULT" = "True" ]; then
    pass "Light channel allows direction_debate skip"
else
    fail "Light channel stage skip incorrect"
fi

# Test 6: Standard channel does not allow stage skips
echo ""
echo "Test 6: Standard channel does not allow stage skips"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, can_skip_stage
run = {'run_id': 'run-5'}
updated = classify_and_persist(run, 'Major refactor', ['a.py', 'b.py', 'c.py', 'd.py', 'e.py', 'f.py'], 4, force_standard=True)
print(not can_skip_stage(updated, 'direction_debate') and not can_skip_stage(updated, 'solution_debate'))
")
if [ "$RESULT" = "True" ]; then
    pass "Standard channel does not allow stage skips"
else
    fail "Standard channel incorrectly allows stage skips"
fi

# Test 7: Light channel has lower evidence requirements
echo ""
echo "Test 7: Light channel has lower evidence requirements"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, get_required_evidence
run = {'run_id': 'run-6', 'rollout_evidence': ['rollout_approval']}
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24)
evidence = get_required_evidence(updated)
print(len(evidence) == 2 and 'task_description' in evidence and 'impact_analysis' in evidence)
")
if [ "$RESULT" = "True" ]; then
    pass "Light channel has lower evidence requirements"
else
    fail "Light channel evidence requirements incorrect"
fi

# Test 8: Standard channel has full evidence requirements
echo ""
echo "Test 8: Standard channel has full evidence requirements"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, get_required_evidence
run = {'run_id': 'run-7'}
updated = classify_and_persist(run, 'Major refactor', ['a.py', 'b.py', 'c.py', 'd.py', 'e.py', 'f.py'], 4, force_standard=True)
evidence = get_required_evidence(updated)
print(len(evidence) == 4)
")
if [ "$RESULT" = "True" ]; then
    pass "Standard channel has full evidence requirements"
else
    fail "Standard channel evidence requirements incorrect"
fi

# Test 9: Light channel has lower debate rounds
echo ""
echo "Test 9: Light channel has lower debate rounds"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, get_required_debate_rounds
run = {'run_id': 'run-8', 'rollout_evidence': ['rollout_approval']}
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24)
rounds = get_required_debate_rounds(updated)
print(rounds == 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Light channel has 2 debate rounds"
else
    fail "Light channel debate rounds incorrect"
fi

# Test 10: Standard channel has full debate rounds
echo ""
echo "Test 10: Standard channel has full debate rounds"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, get_required_debate_rounds
run = {'run_id': 'run-9'}
updated = classify_and_persist(run, 'Major refactor', ['a.py', 'b.py', 'c.py', 'd.py', 'e.py', 'f.py'], 4, force_standard=True)
rounds = get_required_debate_rounds(updated)
print(rounds == 3)
")
if [ "$RESULT" = "True" ]; then
    pass "Standard channel has 3 debate rounds"
else
    fail "Standard channel debate rounds incorrect"
fi

# Test 11: Missing rollout evidence raises error
echo ""
echo "Test 11: Missing rollout evidence raises error"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, RolloutEvidenceMissingError
try:
    run = {'run_id': 'run-10'}  # No rollout_evidence
    classify_and_persist(run, 'Fix typo', ['README.md'], 24)
    print('False')
except RolloutEvidenceMissingError as e:
    print('rollout_approval' in e.missing)
")
if [ "$RESULT" = "True" ]; then
    pass "RolloutEvidenceMissingError raised correctly"
else
    fail "RolloutEvidenceMissingError not raised"
fi

# Test 12: Channel decision structure
echo ""
echo "Test 12: Channel decision structure"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist
run = {'run_id': 'run-11', 'rollout_evidence': ['rollout_approval']}
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24)
decision = updated['channel_decision']
required_keys = ['channel', 'reason', 'project_age_weeks', 'files_count', 'required_debate_rounds', 'required_evidence', 'forced_standard', 'forced_standard_reasons', 'decision_ref', 'classified_at']
print(all(k in decision for k in required_keys))
")
if [ "$RESULT" = "True" ]; then
    pass "Channel decision has all required fields"
else
    fail "Channel decision missing required fields"
fi

# Test 13: Validate channel decision - valid
echo ""
echo "Test 13: Validate channel decision - valid"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, validate_channel_decision
run = {'run_id': 'run-12', 'rollout_evidence': ['rollout_approval']}
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24)
errors = validate_channel_decision(updated)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid channel decision passes validation"
else
    fail "Valid channel decision fails validation"
fi

# Test 14: Validate channel decision - missing
echo ""
echo "Test 14: Validate channel decision - missing"
RESULT=$(python3 -c "
from channel_routing_propagation import validate_channel_decision
run = {'run_id': 'run-13'}
errors = validate_channel_decision(run)
print('channel_decision missing' in errors)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing channel decision detected"
else
    fail "Missing channel decision not detected"
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
