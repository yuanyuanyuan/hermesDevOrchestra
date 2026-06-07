#!/usr/bin/env bash
# Test: PRD Compliance Remediation E2E Gate
# Final strict e2e gate proving remediated PRD compliance issues are closed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Add lib directory to Python path
export PYTHONPATH="${REPO_ROOT}/scripts/lib:${PYTHONPATH:-}"

# Ensure we're in the right directory for imports
cd "$REPO_ROOT/scripts/lib"

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
echo "Test: PRD Compliance Remediation E2E Gate"
echo "=========================================="
echo ""

# Test 1: Lifecycle state machine
echo "Test 1: Lifecycle state machine"
RESULT=$(python3 -c "
from run_lifecycle import can_transition, validate_transition, InvalidTransitionError
# Test legal transition
if not can_transition('created', 'intake_complete'):
    print('False')
# Test illegal transition
try:
    validate_transition('test', 'created', 'implementation')
    print('False')
except InvalidTransitionError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Lifecycle state machine working"
else
    fail "Lifecycle state machine failed"
fi

# Test 2: Rollback strategy
echo ""
echo "Test 2: Rollback strategy"
RESULT=$(python3 -c "
from rollback_executor import validate_rollback_prereqs, check_protected_targets
# Test prerequisites
run = {'run_id': 'run-1', 'baseline_ref': 'abc123'}
request = {'request_id': 'req-1', 'requested_stage': 'implementation'}
missing = validate_rollback_prereqs(run, request)
if len(missing) > 0:
    print('False')
# Test protected targets
refs = ['config/release/commands.json']
protected = check_protected_targets(refs)
if len(protected) == 0:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Rollback strategy working"
else
    fail "Rollback strategy failed"
fi

# Test 3: Channel routing propagation
echo ""
echo "Test 3: Channel routing propagation"
RESULT=$(python3 -c "
from channel_routing_propagation import classify_and_persist, can_skip_stage
run = {'run_id': 'run-2'}
# Use force_standard to avoid config file dependency
updated = classify_and_persist(run, 'Fix typo', ['README.md'], 24, force_standard=True)
if updated['channel_decision']['channel'] != 'standard':
    print('False')
if can_skip_stage(updated, 'direction_debate'):
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Channel routing propagation working"
else
    fail "Channel routing propagation failed"
fi

# Test 4: Security escape
echo ""
echo "Test 4: Security escape"
RESULT=$(python3 -c "
from security_escape import detect_security_escape, force_standard_for_security
matched = detect_security_escape(['config/password.txt'])
if len(matched) == 0:
    print('False')
run = {'run_id': 'run-3'}
updated = force_standard_for_security(run, ['config/password.txt'])
if not updated['channel_decision']['forced_standard']:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Security escape working"
else
    fail "Security escape failed"
fi

# Test 5: Mini-debate orchestration
echo ""
echo "Test 5: Mini-debate orchestration"
RESULT=$(python3 -c "
from mini_debate_orchestration import create_mini_debate_request, execute_mini_debate
request = create_mini_debate_request('run-4', 'task-4', 'quick', 'Fix typo', ['README.md'])
if request['max_rounds'] != 1:
    print('False')
run = {'run_id': 'run-4'}
report = execute_mini_debate(run, request, debate_backend_available=True)
if report['status'] != 'completed':
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Mini-debate orchestration working"
else
    fail "Mini-debate orchestration failed"
fi

# Test 6: Worker source isolation
echo ""
echo "Test 6: Worker source isolation"
RESULT=$(python3 -c "
from worker_source_isolation import create_worker_session, SourceIsolationViolationError
run = {'adjudicator_source': 'claude'}
try:
    session = create_worker_session('run-5', 'task-5', 'worker-1', 'reviewer', 'claude', run)
    print('False')
except SourceIsolationViolationError:
    print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Worker source isolation working"
else
    fail "Worker source isolation failed"
fi

# Test 7: Worker evidence hardening
echo ""
echo "Test 7: Worker evidence hardening"
RESULT=$(python3 -c "
from worker_evidence_harden import validate_worker_advancement
run = {'run_id': 'run-6'}
task = {
    'current_stage': 'implementation',
    'write_scope': ['scripts/lib/'],
    'dag_validation_result': {'valid': True, 'cycles': []},
    'review_evidence': {'approved': True},
    'commit_evidence': {'commit_sha': 'abc123'}
}
errors = validate_worker_advancement(run, task, ['scripts/lib/module.py'])
if len(errors) > 0:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Worker evidence hardening working"
else
    fail "Worker evidence hardening failed"
fi

# Test 8: Intake completeness
echo ""
echo "Test 8: Intake completeness"
RESULT=$(python3 -c "
from intake_completeness import create_intake_bundle, validate_intake_bundle
bundle = create_intake_bundle(
    'run-7', 'Test task', ['Criteria 1'], ['Constraint 1'],
    ['Dep 1'], ['Metric 1'], ['Risk 1'], ['Plan 1'],
    'Revert', ['test.py']
)
errors = validate_intake_bundle('run-7', bundle)
if len(errors) > 0:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Intake completeness working"
else
    fail "Intake completeness failed"
fi

# Test 9: E-class mini-debate
echo ""
echo "Test 9: E-class mini-debate"
RESULT=$(python3 -c "
from e_class_mini_debate import create_e_class_dispute, execute_e_class_debate
dispute = create_e_class_dispute('run-8', 'task-8', 'imp-8', 'high_priority', 'Test dispute', ['ref-1'])
run = {'run_id': 'run-8'}
report = execute_e_class_debate(run, dispute, debate_backend_available=True)
if report['status'] != 'completed':
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "E-class mini-debate working"
else
    fail "E-class mini-debate failed"
fi

# Test 10: Global evaluation veto
echo ""
echo "Test 10: Global evaluation veto"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_global_evaluation
veto_scores = {'security_compliance': 0.8, 'completion_correctness': 0.9}
residual_risks = [{'risk_id': 'r1', 'severity': 'low'}]
errors = validate_global_evaluation('run-9', veto_scores, residual_risks)
if len(errors) > 0:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Global evaluation veto working"
else
    fail "Global evaluation veto failed"
fi

# Test 11: Correction override
echo ""
echo "Test 11: Correction override"
RESULT=$(python3 -c "
from correction_override import create_override_record, approve_override
override = create_override_record('run-10', 'task-10', [], 'minor_fix', 'L1')
if override['status'] != 'approved':
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Correction override working"
else
    fail "Correction override failed"
fi

# Test 12: Schema doc sync
echo ""
echo "Test 12: Schema doc sync"
RESULT=$(python3 -c "
from schema_doc_sync import validate_success_metrics, validate_artifact_definitions
metrics = {
    'conflict_gate_block_rate': 1.0,
    'rollback_traceability': 1.0,
    'channel_escape_accuracy': 1.0,
    'source_isolation_enforced': 1.0,
    'strict_audit_green': 1.0,
}
missing_metrics = validate_success_metrics(metrics)
if len(missing_metrics) > 0:
    print('False')
schema = {'\$defs': {
    'conflict_ledger': {}, 'rollback_report': {}, 'channel_decision': {},
    'worker_session_record': {}, 'override_record': {}, 'global_evaluation_report': {}
}}
missing_artifacts = validate_artifact_definitions(schema)
if len(missing_artifacts) > 0:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Schema doc sync working"
else
    fail "Schema doc sync failed"
fi

# Test 13: Full fixture run - blocking scenarios
echo ""
echo "Test 13: Full fixture run - blocking scenarios"
RESULT=$(python3 -c "
from global_evaluation_veto import validate_global_evaluation
# High residual risk should block
veto_scores = {'security_compliance': 0.8}
residual_risks = [{'risk_id': 'r1', 'severity': 'high'}]
errors = validate_global_evaluation('run-11', veto_scores, residual_risks)
if len(errors) == 0:
    print('False')
# Veto dimension block should block
veto_scores = {'security_compliance': 0.4}
residual_risks = []
errors = validate_global_evaluation('run-12', veto_scores, residual_risks)
if len(errors) == 0:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Blocking scenarios detected correctly"
else
    fail "Blocking scenarios not detected"
fi

# Test 14: Release gate report
echo ""
echo "Test 14: Release gate report"
RESULT=$(python3 -c "
from schema_doc_sync import create_sync_report
schema = {'\$defs': {
    'conflict_ledger': {}, 'rollback_report': {}, 'channel_decision': {},
    'worker_session_record': {}, 'override_record': {}, 'global_evaluation_report': {}
}}
docs = {'artifacts': {
    'conflict_ledger': {}, 'rollback_report': {}, 'channel_decision': {},
    'worker_session_record': {}, 'override_record': {}, 'global_evaluation_report': {}
}}
metrics = {
    'conflict_gate_block_rate': 1.0,
    'rollback_traceability': 1.0,
    'channel_escape_accuracy': 1.0,
    'source_isolation_enforced': 1.0,
    'strict_audit_green': 1.0,
}
report = create_sync_report(schema, docs, metrics)
if not report['all_synced']:
    print('False')
print('True')
")
if [ "$RESULT" = "True" ]; then
    pass "Release gate report generated"
else
    fail "Release gate report generation failed"
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
    echo -e "${GREEN}All tests passed! PRD Compliance Remediation E2E Gate: PASSED${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed! PRD Compliance Remediation E2E Gate: FAILED${NC}"
    exit 1
fi
