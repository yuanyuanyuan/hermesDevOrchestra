#!/usr/bin/env bash
# Test: Intake Completeness PRD Fields
# Tests intake bundle completeness with CI/CD detection and prompt envelope

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
echo "Test: Intake Completeness PRD Fields"
echo "=========================================="
echo ""

# Test 1: Import intake module
echo "Test 1: Import intake module"
if python3 -c "from intake_completeness import detect_cicd_config, validate_prompt_envelope, validate_cicd_discovery, separate_facts_and_assumptions, create_intake_bundle, validate_intake_bundle, MissingPromptEnvelopePartError, MissingCIDiscoveryError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Detect GitHub Actions
echo ""
echo "Test 2: Detect GitHub Actions"
RESULT=$(python3 -c "
from intake_completeness import detect_cicd_config
config = detect_cicd_config(['.github/workflows/test.yml'])
print('github_actions' in config['detected_systems'])
")
if [ "$RESULT" = "True" ]; then
    pass "GitHub Actions detected"
else
    fail "GitHub Actions not detected"
fi

# Test 3: Detect Docker
echo ""
echo "Test 3: Detect Docker"
RESULT=$(python3 -c "
from intake_completeness import detect_cicd_config
config = detect_cicd_config(['Dockerfile', 'docker-compose.yml'])
print('docker' in config['detected_systems'])
")
if [ "$RESULT" = "True" ]; then
    pass "Docker detected"
else
    fail "Docker not detected"
fi

# Test 4: Detect tests
echo ""
echo "Test 4: Detect tests"
RESULT=$(python3 -c "
from intake_completeness import detect_cicd_config
config = detect_cicd_config(['test_module.py'], {'test_module.py': 'def test_function(): pass'})
print(config['has_tests'] == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Tests detected"
else
    fail "Tests not detected"
fi

# Test 5: Validate prompt envelope - valid
echo ""
echo "Test 5: Validate prompt envelope - valid"
RESULT=$(python3 -c "
from intake_completeness import validate_prompt_envelope
envelope = {
    'task_description': 'Test task',
    'acceptance_criteria': ['Criteria 1'],
    'technical_constraints': ['Constraint 1'],
    'dependencies': ['Dep 1'],
    'success_metrics': ['Metric 1'],
    'risks_and_assumptions': ['Risk 1'],
    'verification_plan': ['Plan 1'],
    'rollback_strategy': 'Revert changes'
}
try:
    validate_prompt_envelope('run-1', envelope)
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Valid prompt envelope passes validation"
else
    fail "Valid prompt envelope fails validation"
fi

# Test 6: Validate prompt envelope - missing parts
echo ""
echo "Test 6: Validate prompt envelope - missing parts"
RESULT=$(python3 -c "
from intake_completeness import validate_prompt_envelope, MissingPromptEnvelopePartError
try:
    validate_prompt_envelope('run-2', {'task_description': 'Test'})
    print('False')
except MissingPromptEnvelopePartError as e:
    print(len(e.missing_parts) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "MissingPromptEnvelopePartError raised correctly"
else
    fail "MissingPromptEnvelopePartError not raised"
fi

# Test 7: Create intake bundle
echo ""
echo "Test 7: Create intake bundle"
RESULT=$(python3 -c "
from intake_completeness import create_intake_bundle
bundle = create_intake_bundle(
    'run-3', 'Test task', ['Criteria 1'], ['Constraint 1'],
    ['Dep 1'], ['Metric 1'], ['Risk 1'], ['Plan 1'],
    'Revert', ['test.py']
)
print('prompt_envelope' in bundle and 'cicd_discovery' in bundle and 'facts_and_assumptions' in bundle)
")
if [ "$RESULT" = "True" ]; then
    pass "Intake bundle created correctly"
else
    fail "Intake bundle creation failed"
fi

# Test 8: Validate intake bundle - valid
echo ""
echo "Test 8: Validate intake bundle - valid"
RESULT=$(python3 -c "
from intake_completeness import create_intake_bundle, validate_intake_bundle
bundle = create_intake_bundle(
    'run-4', 'Test task', ['Criteria 1'], ['Constraint 1'],
    ['Dep 1'], ['Metric 1'], ['Risk 1'], ['Plan 1'],
    'Revert', ['test.py']
)
errors = validate_intake_bundle('run-4', bundle)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid intake bundle passes validation"
else
    fail "Valid intake bundle fails validation"
fi

# Test 9: Separate facts and assumptions
echo ""
echo "Test 9: Separate facts and assumptions"
RESULT=$(python3 -c "
from intake_completeness import separate_facts_and_assumptions
result = separate_facts_and_assumptions(['fact1', 'fact2'], ['assumption1'])
print(result['facts_count'] == 2 and result['assumptions_count'] == 1)
")
if [ "$RESULT" = "True" ]; then
    pass "Facts and assumptions separated correctly"
else
    fail "Facts and assumptions separation failed"
fi

# Test 10: Validate CI/CD discovery - valid
echo ""
echo "Test 10: Validate CI/CD discovery - valid"
RESULT=$(python3 -c "
from intake_completeness import validate_cicd_discovery
discovery = {'detected_systems': ['github_actions'], 'config_files': ['.github/workflows/test.yml']}
try:
    validate_cicd_discovery('run-5', discovery)
    print('True')
except:
    print('False')
")
if [ "$RESULT" = "True" ]; then
    pass "Valid CI/CD discovery passes validation"
else
    fail "Valid CI/CD discovery fails validation"
fi

# Test 11: Validate CI/CD discovery - missing fields
echo ""
echo "Test 11: Validate CI/CD discovery - missing fields"
RESULT=$(python3 -c "
from intake_completeness import validate_cicd_discovery, MissingCIDiscoveryError
try:
    validate_cicd_discovery('run-6', {})
    print('False')
except MissingCIDiscoveryError as e:
    print(len(e.missing_fields) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "MissingCIDiscoveryError raised correctly"
else
    fail "MissingCIDiscoveryError not raised"
fi

# Test 12: Detect multiple CI/CD systems
echo ""
echo "Test 12: Detect multiple CI/CD systems"
RESULT=$(python3 -c "
from intake_completeness import detect_cicd_config
config = detect_cicd_config(['.github/workflows/test.yml', 'Dockerfile', '.gitlab-ci.yml'])
print(len(config['detected_systems']) >= 2)
")
if [ "$RESULT" = "True" ]; then
    pass "Multiple CI/CD systems detected"
else
    fail "Multiple CI/CD systems not detected"
fi

# Test 13: Detect deployment
echo ""
echo "Test 13: Detect deployment"
RESULT=$(python3 -c "
from intake_completeness import detect_cicd_config
config = detect_cicd_config(['deploy.sh'], {'deploy.sh': '#!/bin/bash\ndeploy to production'})
print(config['has_deployment'] == True)
")
if [ "$RESULT" = "True" ]; then
    pass "Deployment detected"
else
    fail "Deployment not detected"
fi

# Test 14: Intake bundle structure
echo ""
echo "Test 14: Intake bundle structure"
RESULT=$(python3 -c "
from intake_completeness import create_intake_bundle
bundle = create_intake_bundle(
    'run-7', 'Test task', ['Criteria 1'], ['Constraint 1'],
    ['Dep 1'], ['Metric 1'], ['Risk 1'], ['Plan 1'],
    'Revert', ['test.py']
)
required_keys = ['run_id', 'prompt_envelope', 'cicd_discovery', 'facts_and_assumptions', 'created_at']
print(all(k in bundle for k in required_keys))
")
if [ "$RESULT" = "True" ]; then
    pass "Intake bundle has all required fields"
else
    fail "Intake bundle missing required fields"
fi

# Test 15: CI/CD detection avoids substring false positives
echo ""
echo "Test 15: CI/CD detection avoids substring false positives"
RESULT=$(python3 -c "
from intake_completeness import detect_cicd_config
config = detect_cicd_config([
    'docs/.github-notes.md',
    'src/foo.github.txt',
    'docs/docker-compose.yaml.md',
    'notes/Jenkinsfile-guide.md',
])
print(config['detected_systems'] == [] and config['config_files'] == [])
")
if [ "$RESULT" = "True" ]; then
    pass "CI/CD substring false positives avoided"
else
    fail "CI/CD substring false positives detected"
fi

# Test 16: CI/CD detection accepts exact configured paths
echo ""
echo "Test 16: CI/CD detection accepts exact configured paths"
RESULT=$(python3 -c "
from intake_completeness import detect_cicd_config
config = detect_cicd_config([
    './.github/actions/build/action.yml',
    '.circleci/config.yml',
    'jenkins/pipeline.groovy',
    'k8s/deployment.yml',
])
systems = set(config['detected_systems'])
print({'github_actions', 'circleci', 'jenkins', 'kubernetes'}.issubset(systems))
")
if [ "$RESULT" = "True" ]; then
    pass "Exact CI/CD paths detected"
else
    fail "Exact CI/CD paths not detected"
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
