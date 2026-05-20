#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="worker-ai-execution"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

PYTHON_BIN="/data/hermes/.test-venv/bin/python3"

echo "Testing Worker modules..."

# Test worker registry: load backends
echo "  Loading worker backends..."
RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from worker_registry import WorkerRegistry

registry = WorkerRegistry(repo_root='/data/hermes', allow_staged=True)
backends_data = registry.load_backends()
roles_data = registry.load_roles()

backends = list(backends_data.get('backend_index', {}).values())
roles = list(roles_data.get('role_index', {}).values())

print(f'Backends: {len(backends)}')
print(f'Backend IDs: {list(backends_data.get(\"backend_index\", {}).keys())}')
print(f'Roles: {len(roles)}')
print(f'Role IDs: {list(roles_data.get(\"role_index\", {}).keys())}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Backends:"; then
    echo "    ✓ Worker backends loaded"
    echo "      $RESULT" | head -4
else
    echo "    ✗ Failed to load backends: $RESULT"
    fail "WorkerRegistry should load backends" "Backends:" "$RESULT"
fi

# Test capability negotiation
echo "  Testing capability negotiation..."
RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from worker_registry import WorkerRegistry
from capability_negotiation import CapabilityNegotiator

registry = WorkerRegistry(repo_root='/data/hermes', allow_staged=True)
registry.load_backends()
registry.load_roles()

negotiator = CapabilityNegotiator(registry)
negotiation = negotiator.negotiate(role='implementer')

print(f'Role: {negotiation.get(\"role\")}')
print(f'Selected backend: {negotiation.get(\"selected_backend\")}')
print(f'Reason: {negotiation.get(\"selection_record\", {}).get(\"reason\", \"n/a\")}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Selected backend:"; then
    echo "    ✓ Capability negotiation works"
    echo "      $RESULT" | head -2
else
    echo "    ✗ Negotiation failed: $RESULT"
    fail "CapabilityNegotiator should select backend" "Selected backend:" "$RESULT"
fi

# Test worker session creation
echo "  Testing worker session creation..."
RESULT=$("$PYTHON_BIN" -c "
import sys, tempfile, os
from pathlib import Path
sys.path.insert(0, '/data/hermes/scripts/lib')

from worker_session import WorkerSessionManager

tmp = tempfile.mkdtemp()
manager = WorkerSessionManager(repo_root='/data/hermes')

session = manager.create_session(
    run_id='test-run-001',
    task_id='test-task-001',
    role='implementer',
    backend_id='codex',
    workspace_root=Path(tmp) / 'workspace',
    write_scope_ref='state://runs/test-run-001/write-scope',
    context_bundle_ref='state://runs/test-run-001/context',
    timeout_seconds=300
)

print(f'Session ID: {session.get(\"session_id\")}')
print(f'Status: {session.get(\"status\")}')
print(f'Workspace: {session.get(\"workspace_path\", \"n/a\")}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Session ID:"; then
    echo "    ✓ Worker session creation works"
    echo "      $RESULT" | head -2
else
    echo "    ✗ Session creation failed: $RESULT"
    fail "WorkerSessionManager should create session" "Session ID:" "$RESULT"
fi

# Test degraded mode: simulate backend unavailability via overrides
echo "  Testing degraded mode (backend unavailable)..."
RESULT=$("$PYTHON_BIN" -c "
import sys, json
sys.path.insert(0, '/data/hermes/scripts/lib')

from worker_registry import WorkerRegistry
from capability_negotiation import CapabilityNegotiator

# Simulate codex being unavailable
overrides = {'codex': {'available': False, 'reasons': ['health_check_failed']}}
registry = WorkerRegistry(repo_root='/data/hermes', allow_staged=True, availability_overrides=overrides)
registry.load_backends()
registry.load_roles()

avail = registry.backend_availability('codex')
print(f'Codex available: {avail[\"available\"]}')
print(f'Codex reasons: {avail[\"reasons\"]}')

negotiator = CapabilityNegotiator(registry)
result = negotiator.negotiate(role='implementer')

status = result.get('negotiation_report', {}).get('negotiation_status', 'unknown')
selected = result.get('selected_backend')
fallback_used = result.get('selection_record', {}).get('fallback_used', False)

print(f'Negotiation status: {status}')
print(f'Selected backend: {selected}')
print(f'Fallback used: {fallback_used}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Negotiation status:"; then
    echo "    ✓ Degraded mode negotiation works"
    echo "      $RESULT" | head -5
else
    echo "    ✗ Degraded mode test failed: $RESULT"
    fail "CapabilityNegotiator should handle degraded mode" "Negotiation status:" "$RESULT"
fi

test_done
