#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-engine-ai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

PYTHON_BIN="/data/hermes/.test-venv/bin/python3"

echo "Testing Debate Engine modules..."

# Test debate engine: load registries
echo "  Loading debate registries..."
RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_engine import DebateEngine

engine = DebateEngine(repo_root='/data/hermes')
registries = engine.load_registries()

teams = registries.get('teams', [])
modes = registries.get('modes', [])
print(f'Teams: {len(teams)}')
print(f'Modes: {len(modes)}')
print(f'Team IDs: {registries.get(\"team_ids\", [])[:5]}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Teams:"; then
    echo "    ✓ Debate registries loaded"
    echo "      $RESULT" | head -3
else
    echo "    ✗ Failed to load registries: $RESULT"
    fail "DebateEngine should load registries" "Teams: N" "$RESULT"
fi

# Test debate assembly
echo "  Testing debate assembly selection..."
RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_assembly import DebateAssembly

assembly = DebateAssembly(repo_root='/data/hermes')
assembly.load_policy()

selection = assembly.select_for_stage(
    stage='direction_debate',
    task_type='api_contract',
    risk_level='L3'
)

print(f'Stage: {selection.get(\"stage\")}')
print(f'Selected teams: {selection.get(\"selected_team_ids\", [])}')
print(f'Members: {len(selection.get(\"selected_member_ids\", []))}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Stage:"; then
    echo "    ✓ Debate assembly works"
    echo "      $RESULT" | head -3
else
    echo "    ✗ Assembly failed: $RESULT"
    fail "DebateAssembly should select teams" "Stage:" "$RESULT"
fi

# Test backend adapter: select backend
echo "  Testing backend adapter selection..."
RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_backend_adapter import DebateBackendAdapterRegistry

registry = DebateBackendAdapterRegistry(repo_root='/data/hermes')
registry.load_policy()

backend = registry.select_backend(stage='direction_debate')
print(f'Backend ID: {backend.get(\"id\")}')
print(f'Family: {backend.get(\"family\")}')
print(f'Stages: {backend.get(\"allowed_stages\", [])}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Backend ID:"; then
    echo "    ✓ Backend adapter works"
    echo "      $RESULT" | head -2
else
    echo "    ✗ Backend adapter failed: $RESULT"
    fail "DebateBackendAdapterRegistry should select backend" "Backend ID:" "$RESULT"
fi

# Test debate engine: create run
echo "  Testing debate engine create run..."
RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_engine import DebateEngine

engine = DebateEngine(repo_root='/data/hermes')
engine.load_registries()

run = engine.create_run(
    question='Should we adopt GraphQL or REST API?',
    mode_id='parallel_debate'
)

print(f'Run ID: {run.get(\"debate_id\", run.get(\"run_id\", \"?\"))}')
print(f'Status: {run.get(\"status\")}')
print(f'Mode: {run.get(\"mode_id\")}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Run ID:"; then
    echo "    ✓ Debate engine create_run works"
    echo "      $RESULT" | head -2
else
    echo "    ✗ create_run failed: $RESULT"
    fail "DebateEngine should create run" "Run ID:" "$RESULT"
fi

# Test degraded mode: invoke through template fixture adapter
echo "  Testing degraded mode (template fixture)..."
RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_engine import DebateEngine
from debate_assembly import DebateAssembly
from debate_backend_adapter import DebateBackendAdapterRegistry
from debate_member_invocation import DebateMemberInvocationService

engine = DebateEngine(repo_root='/data/hermes')
engine.load_registries()

run = engine.create_run(
    question='Should we adopt GraphQL or REST API for the new service?',
    mode_id='parallel_debate'
)

assembly_tool = DebateAssembly(repo_root='/data/hermes')
assembly_tool.load_policy()
assembly = assembly_tool.select_for_stage(
    stage='direction_debate',
    task_type='api_contract',
    risk_level='L3'
)

service = DebateMemberInvocationService(repo_root='/data/hermes')
run_id = run.get('debate_id')
result = service.execute(
    run=run,
    assembly=assembly,
    input_refs=[f'state://runs/{run_id}/artifacts/input-1'],
)

opinions = result.get('opinions', [])
degraded_count = sum(1 for o in opinions if o.get('degraded'))
has_degradation_record = any('degradation_record' in o for o in opinions)

print(f'Opinions: {len(opinions)}')
print(f'Degraded count: {degraded_count}')
print(f'Has degradation_record: {has_degradation_record}')
print(f'Backend ID: {opinions[0].get(\"backend_id\") if opinions else \"n/a\"}')
" 2>&1) || true

if echo "$RESULT" | grep -q "Degraded count:"; then
    DEGRADED_COUNT=$(echo "$RESULT" | grep "Degraded count:" | grep -o '[0-9]*')
    HAS_DEG_REC=$(echo "$RESULT" | grep "Has degradation_record:" | awk '{print $NF}')
    if [ "$DEGRADED_COUNT" -gt 0 ] 2>/dev/null && [ "$HAS_DEG_REC" = "True" ]; then
        echo "    ✓ Degraded mode assertions passed (degraded_count=$DEGRADED_COUNT, degradation_record=True)"
        echo "      $RESULT" | head -4
    else
        echo "    ✗ Degraded mode assertions failed: $RESULT"
        fail "Degraded mode: degraded_count > 0 and degradation_record required" "degraded_count > 0, degradation_record=True" "$RESULT"
    fi
else
    echo "    ✗ Degraded mode test failed: $RESULT"
    fail "DebateMemberInvocationService.execute should work in degraded mode" "Degraded count:" "$RESULT"
fi

test_done
