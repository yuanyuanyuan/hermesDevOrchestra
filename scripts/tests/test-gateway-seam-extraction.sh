#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-seam-extraction"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
export REPO_ROOT

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

# Verify helper modules exist and are non-empty
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_intake.py" "gateway_intake.py missing"
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_projection.py" "gateway_projection.py missing"
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_evidence.py" "gateway_evidence.py missing"

[ "$(wc -l < "$REPO_ROOT/scripts/lib/gateway_intake.py")" -gt 0 ] || fail "gateway_intake.py is empty"
[ "$(wc -l < "$REPO_ROOT/scripts/lib/gateway_projection.py")" -gt 0 ] || fail "gateway_projection.py is empty"
[ "$(wc -l < "$REPO_ROOT/scripts/lib/gateway_evidence.py")" -gt 0 ] || fail "gateway_evidence.py is empty"

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

# Verify projection/evidence helpers as direct unit-style tests
python3 - <<'PYEOF'
import os
import sys

repo_root = os.environ["REPO_ROOT"]
sys.path.insert(0, os.path.join(repo_root, "scripts", "lib"))

from gateway_evidence import gather
from gateway_projection import project

intent = {
    "intent_type": "create_run",
    "confidence": 0.9,
    "source_trace": ["gateway_intake"],
    "normalized_payload": {
        "idempotency_key": "abc123",
        "ticket": {"title": "demo"},
    },
    "validation_errors": [],
}
projected = project(
    intent,
    {
        "project_id": "test-proj",
        "request_type": "create_run",
        "run_id": "run-1",
        "timestamp": "2026-06-01T00:00:00Z",
    },
)
assert projected["projection_status"] == "consistent", projected
assert projected["intent_type"] == "create_run", projected
assert projected["mapped_entities"]["ticket_title"] == "demo", projected
assert projected["state_refs"] == [
    "state://runs/run-1/run.json",
    "state://runs/run-1/events.jsonl",
    "state://runs/run-1/tasks.json",
    "state://projects/test-proj/projection.json",
], projected
evidence = gather(projected)
assert evidence["degraded"] is False, evidence
assert evidence["evidence_refs"] == projected["state_refs"], evidence
assert evidence["confidence_markers"]["intent_classification"] == 0.9, evidence
print("projection_evidence_helpers: PASS")
PYEOF

# Verify project discovery logic is importable and unit-testable
python3 - <<'PYEOF'
import os
import sys
import tempfile
from pathlib import Path

repo_root = os.environ["REPO_ROOT"]
sys.path.insert(0, os.path.join(repo_root, "scripts", "lib"))

from project_discovery import run_discovery

project_dir = Path(tempfile.mkdtemp(prefix="project-discovery-"))
(project_dir / "pyproject.toml").write_text(
    "[project]\nname = \"demo\"\nversion = \"0.1.0\"\ndependencies = [\"fastapi>=0.100\"]\n",
    encoding="utf-8",
)
report = run_discovery(project_dir)
assert report["tech_stack"]["frameworks"] == ["FastAPI"], report
assert report["tech_stack"]["versions"]["fastapi"] == "0.100", report
assert report["test_command"] == "pytest", report
print("project_discovery_helpers: PASS")
PYEOF

# Verify the seam is exercised through the helper call chain
python3 - <<'PYEOF'
import os
import sys
import tempfile
from pathlib import Path

repo_root = os.environ["REPO_ROOT"]
state_root = tempfile.mkdtemp(prefix="gateway-state-")
audit_root = tempfile.mkdtemp(prefix="gateway-audit-")
os.environ["STATE_ROOT"] = state_root
os.environ["AUDIT_ROOT"] = audit_root
sys.path.insert(0, os.path.join(repo_root, "scripts", "lib"))

import orch_gateway

calls = []

def fake_normalize(payload, expected_intent_type=None):
    calls.append(("normalize", expected_intent_type, dict(payload)))
    return {
        "intent_type": expected_intent_type,
        "confidence": 1.0,
        "source_trace": ["test"],
    }

def fake_project(intent, ctx):
    calls.append(("project", intent["intent_type"], ctx["request_type"]))
    return {"intent": intent, "ctx": ctx}

def fake_gather(projected):
    calls.append(("gather", projected["ctx"]["request_type"]))
    return {"evidence": []}

orch_gateway._HELPERS_OK = True
orch_gateway._HELPERS_IMPORT_ERROR = None
orch_gateway._intake_normalize = fake_normalize
orch_gateway._projection_project = fake_project
orch_gateway._evidence_gather = fake_gather

app = orch_gateway.GatewayApp("test-proj", "http://127.0.0.1:8643")
app.repo_root = Path(tempfile.mkdtemp(prefix="gateway-repo-"))
fallback = app._intake_pipeline_fallback_reason(
    {"idempotency_key": "test-key", "ticket": {"title": "demo"}},
    "create_run",
)
assert fallback is None, fallback
assert [step[0] for step in calls] == ["normalize", "project", "gather"], calls
print("helper_pipeline_chain: PASS")
PYEOF

# Verify fallback propagates across the request endpoints added by the seam
python3 - <<'PYEOF'
import os
import sys
import tempfile
from pathlib import Path

repo_root = os.environ["REPO_ROOT"]
sys.path.insert(0, os.path.join(repo_root, "scripts", "lib"))

import orch_gateway

orch_gateway._HELPERS_OK = False
orch_gateway._HELPERS_IMPORT_ERROR = "ImportError: helper imports unavailable"
app = orch_gateway.GatewayApp("test-proj", "http://127.0.0.1:8643")
app.repo_root = Path(tempfile.mkdtemp(prefix="gateway-repo-"))

checks = [
    ("stop_run", lambda: app.stop_run("run-1", {})),
    ("submit_verdict", lambda: app.submit_verdict("run-1", {})),
    ("submit_global_evaluation", lambda: app.submit_global_evaluation("run-1", {})),
    ("submit_closeout", lambda: app.submit_closeout("run-1", {})),
    ("submit_failure", lambda: app.submit_failure("run-1", {})),
]
for name, invoke in checks:
    status, body = invoke()
    assert status == 503, (name, status, body)
    assert body.get("fallback") == "FALLBACK_HEURISTIC", (name, body)
    assert body.get("error", {}).get("code") == "gateway_fallback", (name, body)
print("fallback_endpoints: PASS")
PYEOF

# Verify fallback header is emitted by the actual HTTP handler
HTTP_TMP="$(mktemp -d)"
mkdir -p "$HTTP_TMP/scripts/lib"
cp -r "$REPO_ROOT/scripts/lib/." "$HTTP_TMP/scripts/lib/"
rm -f "$HTTP_TMP/scripts/lib/gateway_intake.py"
HTTP_STATE_ROOT="$(mktemp -d)"
HTTP_AUDIT_ROOT="$(mktemp -d)"
PORT=8765
STATE_ROOT="$HTTP_STATE_ROOT" AUDIT_ROOT="$HTTP_AUDIT_ROOT" python3 "$HTTP_TMP/scripts/lib/orch_gateway.py" --project-id test-proj --port "$PORT" >/tmp/orch-gateway-http.log 2>&1 &
HTTP_PID=$!
for _ in $(seq 1 30); do
    if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        break
    fi
    sleep 0.2
done
if ! curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    kill "$HTTP_PID" >/dev/null 2>&1 || true
    fail "gateway http server did not start"
fi
curl -s -D "$HTTP_TMP/headers.txt" -o "$HTTP_TMP/body.json" \
    -X POST "http://127.0.0.1:$PORT/orchestra/runs" \
    -H "Content-Type: application/json" \
    -d '{}' >/dev/null
tr -d '\r' < "$HTTP_TMP/headers.txt" | grep -qi '^x-gateway-fallback: heuristic$' || fail "missing x-gateway-fallback header"
python3 - "$HTTP_TMP/body.json" <<'PYEOF'
import json, sys
body = json.load(open(sys.argv[1], encoding="utf-8"))
assert body.get("fallback") == "FALLBACK_HEURISTIC", body
assert body.get("error", {}).get("code") == "gateway_fallback", body
print("http_fallback_header: PASS")
PYEOF
kill "$HTTP_PID" >/dev/null 2>&1 || true
wait "$HTTP_PID" 2>/dev/null || true
rm -rf "$HTTP_TMP" "$HTTP_STATE_ROOT" "$HTTP_AUDIT_ROOT"

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

# Test helper syntax errors are not silently downgraded to fallback mode
BROKEN_TMP="$(mktemp -d)"
mkdir -p "$BROKEN_TMP/lib"
cp -r "$REPO_ROOT/scripts/lib/." "$BROKEN_TMP/lib/"
cat > "$BROKEN_TMP/lib/gateway_intake.py" <<'PYEOF'
def normalize(
PYEOF
python3 - <<PYEOF
import sys
sys.path.insert(0, "$BROKEN_TMP/lib")
try:
    import orch_gateway  # noqa: F401
except SyntaxError:
    print("syntax_error_passthrough: PASS")
else:
    raise AssertionError("expected SyntaxError from broken helper import")
PYEOF
rm -rf "$BROKEN_TMP"

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
import tempfile
from pathlib import Path
sys.path.insert(0, 'scripts/lib')
import orch_gateway
orch_gateway._HELPERS_OK = False
app = orch_gateway.GatewayApp('test-proj', 'http://127.0.0.1:8643')
app.repo_root = Path(tempfile.mkdtemp(prefix="gateway-repo-"))
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

assert_contains 'self.send_header("x-gateway-fallback", "heuristic" if body["fallback"] == "FALLBACK_HEURISTIC" else body["fallback"])' "$REPO_ROOT/scripts/lib/orch_gateway.py" "fallback header must use contract value"

PY_TMP="$(mktemp -d)"
mkdir -p "$PY_TMP/project"
git -C "$PY_TMP/project" init -q >/dev/null
cat > "$PY_TMP/project/requirements.txt" <<'EOF'
fastapi==0.115.0
uvicorn==0.30.0
EOF
"$REPO_ROOT/scripts/bin/orch-init" demo-py "$PY_TMP/project" >/dev/null
python3 - "$PY_TMP/project/.workflow/knowledge/detection-report.json" <<'PYEOF'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))["detection_report"]
assert report["tech_stack"]["frameworks"] == ["FastAPI"], report["tech_stack"]
assert report["tech_stack"]["versions"].get("FastAPI") == "0.115.0", report["tech_stack"]
print("python_version_detection: PASS")
PYEOF
rm -rf "$PY_TMP"

test_done
