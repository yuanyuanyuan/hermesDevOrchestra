#!/usr/bin/env bash
# Test: Global Evaluation Veto and Residual Risk Thresholds
# Tests one-vote veto and residual-risk threshold logic

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
echo "Test: Global Evaluation Veto and Residual Risk Thresholds"
echo "=========================================="
echo ""

# Test 1: Import global evaluation module
echo "Test 1: Import global evaluation module"
if python3 -c "from global_evaluation_veto import validate_veto_dimension, validate_residual_risks, check_authority_approval, sort_residual_risks_by_severity, attach_required_action, validate_global_evaluation, create_global_evaluation_report, VetoDimensionError, ResidualRiskError, UnknownRiskSeverityError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Veto dimension validation - pass
echo ""
echo "Test 2: Veto dimension validation - pass"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_veto_dimension
try:
    validate_veto_dimension('security_compliance', 0.8, 0.6)
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Veto dimension validation passed"
else
    fail "Veto dimension validation failed"
fi

# Test 3: Veto dimension validation - fail
echo ""
echo "Test 3: Veto dimension validation - fail"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_veto_dimension, VetoDimensionError
try:
    validate_veto_dimension('security_compliance', 0.4, 0.6)
    print('False')
except VetoDimensionError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "VetoDimensionError raised correctly"
else
    fail "VetoDimensionError not raised"
fi

# Test 4: Residual risk validation - high risk
echo ""
echo "Test 4: Residual risk validation - high risk"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_residual_risks
risks = [{'risk_id': 'r1', 'severity': 'high', 'description': 'Test risk'}]
high_risks = validate_residual_risks('run-1', risks)
print(len(high_risks) == 1)
")
if [ "$RESULT" = "True" ]; then
    pass "High residual risk detected"
else
    fail "High residual risk not detected"
fi

# Test 5: Residual risk validation - low risk
echo ""
echo "Test 5: Residual risk validation - low risk"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_residual_risks
risks = [{'risk_id': 'r2', 'severity': 'low', 'description': 'Test risk'}]
high_risks = validate_residual_risks('run-2', risks)
print(len(high_risks) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Low residual risk not flagged as high"
else
    fail "Low residual risk incorrectly flagged"
fi

# Test 6: Unknown risk severity
echo ""
echo "Test 6: Unknown risk severity"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_residual_risks, UnknownRiskSeverityError
try:
    risks = [{'risk_id': 'r3', 'severity': 'critical', 'description': 'Test risk'}]
    validate_residual_risks('run-3', risks)
    print('False')
except UnknownRiskSeverityError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "UnknownRiskSeverityError raised correctly"
else
    fail "UnknownRiskSeverityError not raised"
fi

# Test 7: Authority approval check - approved
echo ""
echo "Test 7: Authority approval check - approved"
RESULT=$(python3 -c "
from global_evaluation_veto import check_authority_approval
run = {'authority_route': {'approved_risks': ['r1']}}
risks = [{'risk_id': 'r1', 'severity': 'high'}]
approved = check_authority_approval(run, risks)
print(approved == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Authority approval check passed"
else
    fail "Authority approval check failed"
fi

# Test 8: Authority approval check - not approved
echo ""
echo "Test 8: Authority approval check - not approved"
RESULT=$(python3 -c "
from global_evaluation_veto import check_authority_approval
run = {'authority_route': {'approved_risks': []}}
risks = [{'risk_id': 'r1', 'severity': 'high'}]
approved = check_authority_approval(run, risks)
print(approved == False)
")
if [ "$RESULT" = "True" ]; then
    pass "Authority approval check correctly rejected"
else
    fail "Authority approval check incorrectly passed"
fi

# Test 9: Sort residual risks by severity
echo ""
echo "Test 9: Sort residual risks by severity"
RESULT=$(python3 -c "
from global_evaluation_veto import sort_residual_risks_by_severity
risks = [{'severity': 'low'}, {'severity': 'high'}, {'severity': 'medium'}]
sorted_risks = sort_residual_risks_by_severity(risks)
print(sorted_risks[0]['severity'] == 'high' and sorted_risks[-1]['severity'] == 'low')
")
if [ "$RESULT" = "True" ]; then
    pass "Residual risks sorted correctly"
else
    fail "Residual risks not sorted correctly"
fi

# Test 10: Attach required action
echo ""
echo "Test 10: Attach required action"
RESULT=$(python3 -c "
from global_evaluation_veto import attach_required_action
risks = [{'severity': 'high'}, {'severity': 'medium'}, {'severity': 'low'}]
risks_with_actions = attach_required_action(risks)
print(risks_with_actions[0]['required_action'] == 'human_approval_required' and risks_with_actions[2]['required_action'] == 'accept')
")
if [ "$RESULT" = "True" ]; then
    pass "Required actions attached correctly"
else
    fail "Required actions not attached correctly"
fi

# Test 11: Validate global evaluation - valid
echo ""
echo "Test 11: Validate global evaluation - valid"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_global_evaluation
veto_scores = {'security_compliance': 0.8, 'completion_correctness': 0.9}
residual_risks = [{'risk_id': 'r1', 'severity': 'low'}]
errors = validate_global_evaluation('run-4', veto_scores, residual_risks)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid global evaluation passes validation"
else
    fail "Valid global evaluation fails validation"
fi

# Test 12: Validate global evaluation - veto block
echo ""
echo "Test 12: Validate global evaluation - veto block"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_global_evaluation
veto_scores = {'security_compliance': 0.4}
residual_risks = []
errors = validate_global_evaluation('run-5', veto_scores, residual_risks)
print(len(errors) > 0 and 'veto_dimension_blocked' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Veto dimension block detected"
else
    fail "Veto dimension block not detected"
fi

# Test 13: Validate global evaluation - high residual risk
echo ""
echo "Test 13: Validate global evaluation - high residual risk"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_global_evaluation
veto_scores = {'security_compliance': 0.8}
residual_risks = [{'risk_id': 'r1', 'severity': 'high'}]
errors = validate_global_evaluation('run-6', veto_scores, residual_risks)
print(len(errors) > 0 and 'high_residual_risks' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "High residual risk detected in validation"
else
    fail "High residual risk not detected in validation"
fi

# Test 14: Create global evaluation report
echo ""
echo "Test 14: Create global evaluation report"
RESULT=$(python3 -c "
from global_evaluation_veto import create_global_evaluation_report
veto_scores = {'security_compliance': 0.8, 'completion_correctness': 0.9}
residual_risks = [{'risk_id': 'r1', 'severity': 'high'}, {'risk_id': 'r2', 'severity': 'low'}]
report = create_global_evaluation_report('run-7', veto_scores, residual_risks)
print(report['requires_approval'] == True and report['high_risk_count'] == 1)
")
if [ "$RESULT" = "True" ]; then
    pass "Global evaluation report created correctly"
else
    fail "Global evaluation report creation failed"
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
