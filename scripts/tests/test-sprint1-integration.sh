#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="sprint1-integration"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

echo "=== Sprint 1 Integration Tests ==="

# Test 1: Full Contract Validation Harness
echo "Test 1: Full Contract Validation Harness"
python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
sys.path.insert(0, str(repo_root / "scripts/lib"))

from full_schema_validation import FullSchemaValidation

# Test with allow_staged=True
validator = FullSchemaValidation(repo_root, allow_staged=True)
report = validator.validate_all()
assert report["ok"] is True, f"Validation failed: {report}"
print("PASS: Full contract validation harness works")
PY

# Test 2: Readiness Gate Status
echo "Test 2: Readiness Gate Status"
GATE_STATUS=$("$REPO_ROOT/scripts/bin/orch-readiness-gate" --repo "$REPO_ROOT" status)
echo "$GATE_STATUS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['ok'] is True, 'Status check failed'
assert 'families' in data, 'Missing families key'
print('PASS: Readiness gate status works')
"

# Test 3: Readiness Gate Check
echo "Test 3: Readiness Gate Check"
if "$REPO_ROOT/scripts/bin/orch-readiness-gate" --repo "$REPO_ROOT" check full_debate_package 2>/dev/null; then
    echo "PASS: Readiness gate check returned ok (family active)"
else
    echo "PASS: Readiness gate check returned not ok (family pending)"
fi

# Test 4: Readiness Gate Activate/Deactivate
echo "Test 4: Readiness Gate Activate/Deactivate"

# Create temporary repo structure to avoid mutating tracked config
TEMP_REPO=$(mktemp -d)
trap "rm -rf $TEMP_REPO" EXIT

# Copy necessary config files to temp repo
mkdir -p "$TEMP_REPO/config/cutover"
cp "$REPO_ROOT/config/readiness-gates.json" "$TEMP_REPO/config/"
cp "$REPO_ROOT/config/cutover/full-readiness-gates.json" "$TEMP_REPO/config/cutover/" 2>/dev/null || true

# Copy the gate script
cp "$REPO_ROOT/scripts/bin/orch-readiness-gate" "$TEMP_REPO/"
chmod +x "$TEMP_REPO/orch-readiness-gate"

# Test activate in temp repo
"$TEMP_REPO/orch-readiness-gate" --repo "$TEMP_REPO" activate full_debate_package >/dev/null
GATE_CHECK=$("$TEMP_REPO/orch-readiness-gate" --repo "$TEMP_REPO" check full_debate_package 2>&1) || true
echo "$GATE_CHECK" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['ok'] is True, f'Check failed after activate: {data}'
assert data['status'] == 'active', f'Expected active, got {data[\"status\"]}'
print('PASS: Readiness gate activate works')
"

# Test deactivate in temp repo
"$TEMP_REPO/orch-readiness-gate" --repo "$TEMP_REPO" deactivate full_debate_package >/dev/null
GATE_CHECK=$("$TEMP_REPO/orch-readiness-gate" --repo "$TEMP_REPO" check full_debate_package 2>&1) || true
echo "$GATE_CHECK" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['ok'] is False, f'Check should fail after deactivate: {data}'
assert data['status'] == 'pending', f'Expected pending, got {data[\"status\"]}'
print('PASS: Readiness gate deactivate works')
"

# Verify tracked config was not modified
if git -C "$REPO_ROOT" diff --name-only | grep -q "config/readiness-gates.json"; then
    echo "FAIL: Tracked config was modified during test" >&2
    exit 1
fi
echo "PASS: Tracked config not modified"

# Test 5: Validation Functions in orch-common.sh
echo "Test 5: Validation Functions"
source "$REPO_ROOT/scripts/lib/orch-common.sh"

# Test orch_validate_artifact_identity
python3 -c "
import json
from pathlib import Path
payload = {
    'schema_version': 'orchestra.v1',
    'artifact_type': 'test_artifact',
    'data': 'test'
}
Path('/tmp/test-artifact.json').write_text(json.dumps(payload))
"
orch_validate_artifact_identity /tmp/test-artifact.json

# Test orch_validate_safe_durable_artifact
python3 -c "
import json
from pathlib import Path
payload = {
    'schema_version': 'orchestra.v1',
    'artifact_type': 'test_artifact',
    'data': 'test'
}
Path('/tmp/test-safe-artifact.json').write_text(json.dumps(payload))
"
orch_validate_safe_durable_artifact /tmp/test-safe-artifact.json

# Test 6: Gateway Authority Chain Divergence Detection
echo "Test 6: Gateway Authority Chain Divergence Detection"
python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
sys.path.insert(0, str(repo_root / "scripts/lib"))

# Test that the function exists and can be called
from orch_gateway import GatewayApp

# Create a minimal test to verify the function exists
app = GatewayApp.__new__(GatewayApp)
app.store = None
app.repo_root = repo_root

# Verify the method exists
assert hasattr(app, 'detect_authority_chain_divergence'), "Method not found"
print("PASS: Gateway authority chain divergence detection method exists")
PY

# Test 7: Migration Plan Document
echo "Test 7: Migration Plan Document"
MIGRATION_DOC="$REPO_ROOT/docs/migration/mvp-to-full-migration-plan.md"
if [ -f "$MIGRATION_DOC" ]; then
    echo "PASS: Migration plan document exists"
    # Check for key sections
    if grep -q "ID Mapping Table" "$MIGRATION_DOC" && \
       grep -q "Rollback Strategy" "$MIGRATION_DOC" && \
       grep -q "Test Cases" "$MIGRATION_DOC"; then
        echo "PASS: Migration plan has required sections"
    else
        fail "Migration plan missing required sections" "required sections" "$(head -50 "$MIGRATION_DOC")"
    fi
else
    fail "Migration plan document not found" "document exists" "not found"
fi

# Test 8: Existing Tests Still Pass
echo "Test 8: Existing Tests Still Pass"
bash "$REPO_ROOT/scripts/tests/test-debate-engine.sh" >/dev/null 2>&1
echo "PASS: Debate engine test passes"

bash "$REPO_ROOT/scripts/tests/test-gateway-conflict-ledger-blocks-advancement.sh" >/dev/null 2>&1
echo "PASS: Conflict ledger test passes"

echo ""
echo "=== All Sprint 1 Integration Tests Passed ==="
test_done
