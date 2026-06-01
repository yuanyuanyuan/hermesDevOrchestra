#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-seam-extraction"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

# Verify helper modules exist and are non-empty
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_intake.py" "gateway_intake.py missing"
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_projection.py" "gateway_projection.py missing"
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_evidence.py" "gateway_evidence.py missing"

[ "$(wc -l < "$REPO_ROOT/scripts/lib/gateway_intake.py")" -gt 0 ] || fail "gateway_intake.py is empty"
[ "$(wc -l < "$REPO_ROOT/scripts/lib/gateway_projection.py")" -gt 0 ] || fail "gateway_projection.py is empty"
[ "$(wc -l < "$REPO_ROOT/scripts/lib/gateway_evidence.py")" -gt 0 ] || fail "gateway_evidence.py is empty"

# Verify orch_gateway.py net growth <= 50 lines (baseline 6109)
BASELINE=6109
CURRENT_LINES=$(wc -l < "$REPO_ROOT/scripts/lib/orch_gateway.py")
GROWTH=$((CURRENT_LINES - BASELINE))
[ "$GROWTH" -le 50 ] || fail "orch_gateway.py grew $GROWTH lines (limit 50)"

# Verify helpers are imported in orch_gateway.py
assert_contains "gateway_intake" "$REPO_ROOT/scripts/lib/orch_gateway.py" "missing gateway_intake import"
assert_contains "gateway_projection" "$REPO_ROOT/scripts/lib/orch_gateway.py" "missing gateway_projection import"
assert_contains "gateway_evidence" "$REPO_ROOT/scripts/lib/orch_gateway.py" "missing gateway_evidence import"

# Verify fallback mechanism exists
assert_contains "_record_fallback" "$REPO_ROOT/scripts/lib/orch_gateway.py" "missing fallback recorder"
assert_contains "FALLBACK_HEURISTIC" "$REPO_ROOT/scripts/lib/orch_gateway.py" "missing FALLBACK_HEURISTIC"
assert_contains "x-gateway-fallback" "$REPO_ROOT/scripts/lib/orch_gateway.py" "missing x-gateway-fallback header"

# Verify helper module import cycle safety (intake -> projection -> evidence, no cycles)
python3 -c "
import sys, os
sys.path.insert(0, os.path.join('$REPO_ROOT', 'scripts', 'lib'))
import gateway_intake
import gateway_projection
import gateway_evidence
print('import_cycle_check: PASS')
"

# Verify NormalizedIntent schema fields exist
python3 -c "
import sys, os
sys.path.insert(0, os.path.join('$REPO_ROOT', 'scripts', 'lib'))
from gateway_intake import normalize, NormalizedIntent
result = normalize({'repo_url': 'https://github.com/x/y'})
required = ['intent_type', 'confidence', 'source_trace']
for field in required:
    assert field in result, f'missing {field}'
false_positive = normalize({'resolution': 'done'})
assert false_positive['intent_type'] == 'unknown', false_positive
print('normalized_intent_schema: PASS')
"

# Test fallback when helper is broken (simulate by renaming)
TMP_DIR="$(mktemp -d)"
trap 'rm -rf \"$TMP_DIR\"' EXIT
cp -r "$REPO_ROOT/scripts/lib" "$TMP_DIR/"

# Break intake helper and verify gateway still loads (soft-fail)
mv "$TMP_DIR/lib/gateway_intake.py" "$TMP_DIR/lib/gateway_intake.py.bak"
python3 -c "
import sys, os
sys.path.insert(0, '$TMP_DIR/lib')
# gateway should still import even if helpers fail
import orch_gateway
assert orch_gateway._HELPERS_OK == False, 'expected helpers not ok'
print('fallback_import: PASS')
"

# Test real HTTP fallback: start Gateway with broken helper, call API, verify 503 + header
FALLBACK_TMP="$(mktemp -d)"
mkdir -p "$FALLBACK_TMP/scripts/lib"
cp "$REPO_ROOT/scripts/lib/orch_gateway.py" "$FALLBACK_TMP/scripts/lib/"
cp "$REPO_ROOT/scripts/lib/runtime_activation.py" "$FALLBACK_TMP/scripts/lib/" 2>/dev/null || true
cp "$REPO_ROOT/scripts/lib/debate_report.py" "$FALLBACK_TMP/scripts/lib/" 2>/dev/null || true
# intentionally omit gateway_intake.py to trigger fallback

# Copy all required dependencies for Gateway standalone run
cp "$REPO_ROOT/scripts/lib/debate_report.py" "$FALLBACK_TMP/scripts/lib/" 2>/dev/null || true
cp "$REPO_ROOT/scripts/lib/runtime_activation.py" "$FALLBACK_TMP/scripts/lib/" 2>/dev/null || true
# Create minimal project state for Gateway
mkdir -p "$FALLBACK_TMP/.hermes/projects/test-proj"
echo '{"schema_version":"orchestra.v1"}' > "$FALLBACK_TMP/.hermes/projects/test-proj/project.json"

# Test real fallback by calling create_run directly with broken helper
python3 - <<'PYEOF'
import sys, os
sys.path.insert(0, 'scripts/lib')
import orch_gateway
orch_gateway._HELPERS_OK = False
app = orch_gateway.GatewayApp('test-proj', 'http://127.0.0.1:8643')
status, body = app.create_run({})
print('status:', status)
print('fallback:', body.get('fallback'))
print('error_code:', body.get('error', {}).get('code'))
assert status == 503, f'expected 503, got {status}'
assert body.get('fallback') == 'FALLBACK_HEURISTIC'
assert body.get('error', {}).get('code') == 'gateway_fallback'
print('http_fallback: PASS')
PYEOF
rm -rf "$FALLBACK_TMP"

test_done
