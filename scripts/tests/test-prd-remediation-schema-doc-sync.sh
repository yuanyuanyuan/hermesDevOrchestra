#!/usr/bin/env bash
# Test: PRD Remediation Schema-Doc Sync
# Tests schema, docs, and success metrics synchronization

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
echo "Test: PRD Remediation Schema-Doc Sync"
echo "=========================================="
echo ""

# Test 1: Import sync module
echo "Test 1: Import sync module"
if python3 -c "from schema_doc_sync import validate_success_metrics, validate_artifact_definitions, sync_schema_with_docs, create_sync_report, validate_sync_report, MissingSuccessMetricError, MissingArtifactDefinitionError, SchemaDocMismatchError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Validate success metrics - all present
echo ""
echo "Test 2: Validate success metrics - all present"
RESULT=$(python3 -c "
from schema_doc_sync import validate_success_metrics
metrics = {
    'conflict_gate_block_rate': 1.0,
    'rollback_traceability': 1.0,
    'channel_escape_accuracy': 1.0,
    'source_isolation_enforced': 1.0,
    'strict_audit_green': 1.0,
}
missing = validate_success_metrics(metrics)
print(len(missing) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "All success metrics present"
else
    fail "Success metrics validation failed"
fi

# Test 3: Validate success metrics - missing
echo ""
echo "Test 3: Validate success metrics - missing"
RESULT=$(python3 -c "
from schema_doc_sync import validate_success_metrics
metrics = {'conflict_gate_block_rate': 1.0}
missing = validate_success_metrics(metrics)
print(len(missing) > 0 and 'rollback_traceability' in missing)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing success metric detected"
else
    fail "Missing success metric not detected"
fi

# Test 4: Validate artifact definitions - all present
echo ""
echo "Test 4: Validate artifact definitions - all present"
RESULT=$(python3 -c "
from schema_doc_sync import validate_artifact_definitions
schema = {
    '\$defs': {
        'conflict_ledger': {},
        'rollback_report': {},
        'channel_decision': {},
        'worker_session_record': {},
        'override_record': {},
        'global_evaluation_report': {},
    }
}
missing = validate_artifact_definitions(schema)
print(len(missing) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "All artifact definitions present"
else
    fail "Artifact definitions validation failed"
fi

# Test 5: Validate artifact definitions - missing
echo ""
echo "Test 5: Validate artifact definitions - missing"
RESULT=$(python3 -c "
from schema_doc_sync import validate_artifact_definitions
schema = {'\$defs': {'conflict_ledger': {}}}
missing = validate_artifact_definitions(schema)
print(len(missing) > 0 and 'rollback_report' in missing)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing artifact definition detected"
else
    fail "Missing artifact definition not detected"
fi

# Test 6: Sync schema with docs - synchronized
echo ""
echo "Test 6: Sync schema with docs - synchronized"
RESULT=$(python3 -c "
from schema_doc_sync import sync_schema_with_docs
schema = {'\$defs': {'conflict_ledger': {}, 'rollback_report': {}}}
docs = {'artifacts': {'conflict_ledger': {}, 'rollback_report': {}}}
mismatches = sync_schema_with_docs(schema, docs)
print(len(mismatches) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Schema and docs synchronized"
else
    fail "Schema-doc sync failed"
fi

# Test 7: Sync schema with docs - mismatch
echo ""
echo "Test 7: Sync schema with docs - mismatch"
RESULT=$(python3 -c "
from schema_doc_sync import sync_schema_with_docs
schema = {'\$defs': {'conflict_ledger': {}, 'rollback_report': {}}}
docs = {'artifacts': {'conflict_ledger': {}}}
mismatches = sync_schema_with_docs(schema, docs)
print(len(mismatches) > 0 and 'missing_doc_section: rollback_report' in mismatches)
")
if [ "$RESULT" = "True" ]; then
    pass "Schema-doc mismatch detected"
else
    fail "Schema-doc mismatch not detected"
fi

# Test 8: Create sync report - all synced
echo ""
echo "Test 8: Create sync report - all synced"
RESULT=$(python3 -c "
from schema_doc_sync import create_sync_report
schema = {'\$defs': {'conflict_ledger': {}, 'rollback_report': {}, 'channel_decision': {}, 'worker_session_record': {}, 'override_record': {}, 'global_evaluation_report': {}}}
docs = {'artifacts': {'conflict_ledger': {}, 'rollback_report': {}, 'channel_decision': {}, 'worker_session_record': {}, 'override_record': {}, 'global_evaluation_report': {}}}
metrics = {'conflict_gate_block_rate': 1.0, 'rollback_traceability': 1.0, 'channel_escape_accuracy': 1.0, 'source_isolation_enforced': 1.0, 'strict_audit_green': 1.0}
report = create_sync_report(schema, docs, metrics)
print(report['all_synced'] == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Sync report shows all synced"
else
    fail "Sync report incorrect"
fi

# Test 9: Create sync report - not synced
echo ""
echo "Test 9: Create sync report - not synced"
RESULT=$(python3 -c "
from schema_doc_sync import create_sync_report
schema = {'\$defs': {'conflict_ledger': {}}}
docs = {'artifacts': {}}
metrics = {}
report = create_sync_report(schema, docs, metrics)
print(report['all_synced'] == False)
")
if [ "$RESULT" = "True" ]; then
    pass "Sync report shows not synced"
else
    fail "Sync report incorrect"
fi

# Test 10: Validate sync report - valid
echo ""
echo "Test 10: Validate sync report - valid"
RESULT=$(python3 -c "
from schema_doc_sync import create_sync_report, validate_sync_report
schema = {'\$defs': {}}
docs = {'artifacts': {}}
metrics = {}
report = create_sync_report(schema, docs, metrics)
errors = validate_sync_report(report)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid sync report passes validation"
else
    fail "Valid sync report fails validation"
fi

# Test 11: Validate sync report - missing section
echo ""
echo "Test 11: Validate sync report - missing section"
RESULT=$(python3 -c "
from schema_doc_sync import validate_sync_report
errors = validate_sync_report({})
print(len(errors) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Missing section detected"
else
    fail "Missing section not detected"
fi

# Test 12: Required success metrics list
echo ""
echo "Test 12: Required success metrics list"
RESULT=$(python3 -c "
from schema_doc_sync import REQUIRED_SUCCESS_METRICS
print(len(REQUIRED_SUCCESS_METRICS) == 5)
")
if [ "$RESULT" = "True" ]; then
    pass "5 required success metrics defined"
else
    fail "Required success metrics count incorrect"
fi

# Test 13: Required artifact definitions list
echo ""
echo "Test 13: Required artifact definitions list"
RESULT=$(python3 -c "
from schema_doc_sync import REQUIRED_ARTIFACT_DEFINITIONS
print(len(REQUIRED_ARTIFACT_DEFINITIONS) == 6)
")
if [ "$RESULT" = "True" ]; then
    pass "6 required artifact definitions defined"
else
    fail "Required artifact definitions count incorrect"
fi

# Test 14: Sync report structure
echo ""
echo "Test 14: Sync report structure"
RESULT=$(python3 -c "
from schema_doc_sync import create_sync_report
schema = {'\$defs': {}}
docs = {'artifacts': {}}
metrics = {}
report = create_sync_report(schema, docs, metrics)
required_keys = ['timestamp', 'success_metrics', 'artifact_definitions', 'schema_doc_sync', 'all_synced']
print(all(k in report for k in required_keys))
")
if [ "$RESULT" = "True" ]; then
    pass "Sync report has all required fields"
else
    fail "Sync report missing required fields"
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
