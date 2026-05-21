#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-engine-ai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

PYTHON_BIN="/data/hermes/.test-venv/bin/python3"

echo "Testing Debate Engine modules..."

# Test debate engine: load registries
echo "  Loading debate registries..."
if ! RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_engine import DebateEngine

engine = DebateEngine(repo_root='/data/hermes')
registries = engine.load_registries()

teams = registries.get('teams', [])
modes = registries.get('modes', [])
assert teams, registries
assert modes, registries
print(f'Teams: {len(teams)}')
print(f'Modes: {len(modes)}')
print(f'Team IDs: {registries.get(\"team_ids\", [])[:5]}')
" 2>&1); then
    echo "    ✗ Failed to load registries: $RESULT"
    fail "DebateEngine should load registries" "Teams: N" "$RESULT"
fi
echo "    ✓ Debate registries loaded"
echo "      $RESULT" | head -3

# Test debate assembly
echo "  Testing debate assembly selection..."
if ! RESULT=$("$PYTHON_BIN" -c "
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

assert selection.get('stage') == 'direction_debate', selection
assert selection.get('selected_team_ids'), selection
print(f'Stage: {selection.get(\"stage\")}')
print(f'Selected teams: {selection.get(\"selected_team_ids\", [])}')
print(f'Members: {len(selection.get(\"selected_member_ids\", []))}')
" 2>&1); then
    echo "    ✗ Assembly failed: $RESULT"
    fail "DebateAssembly should select teams" "Stage:" "$RESULT"
fi
echo "    ✓ Debate assembly works"
echo "      $RESULT" | head -3

# Test backend adapter: select backend
echo "  Testing backend adapter selection..."
if ! RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_backend_adapter import DebateBackendAdapterRegistry

registry = DebateBackendAdapterRegistry(repo_root='/data/hermes')
registry.load_policy()

backend = registry.select_backend(stage='direction_debate')
assert backend.get('id'), backend
assert backend.get('family'), backend
print(f'Backend ID: {backend.get(\"id\")}')
print(f'Family: {backend.get(\"family\")}')
print(f'Stages: {backend.get(\"allowed_stages\", [])}')
" 2>&1); then
    echo "    ✗ Backend adapter failed: $RESULT"
    fail "DebateBackendAdapterRegistry should select backend" "Backend ID:" "$RESULT"
fi
echo "    ✓ Backend adapter works"
echo "      $RESULT" | head -2

# Test debate engine: create run
echo "  Testing debate engine create run..."
if ! RESULT=$("$PYTHON_BIN" -c "
import sys
sys.path.insert(0, '/data/hermes/scripts/lib')

from debate_engine import DebateEngine

engine = DebateEngine(repo_root='/data/hermes')
engine.load_registries()

run = engine.create_run(
    question='Should we adopt GraphQL or REST API?',
    mode_id='parallel_debate'
)

assert run.get('status'), run
assert run.get('mode_id') == 'parallel_debate', run
print(f'Run ID: {run.get(\"debate_id\", run.get(\"run_id\", \"?\"))}')
print(f'Status: {run.get(\"status\")}')
print(f'Mode: {run.get(\"mode_id\")}')
" 2>&1); then
    echo "    ✗ create_run failed: $RESULT"
    fail "DebateEngine should create run" "Run ID:" "$RESULT"
fi
echo "    ✓ Debate engine create_run works"
echo "      $RESULT" | head -2

# Test degraded mode: invoke through template fixture adapter
echo "  Testing degraded mode (template fixture)..."
if ! RESULT=$("$PYTHON_BIN" -c "
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
assert degraded_count > 0, result
assert has_degradation_record is True, result

print(f'Opinions: {len(opinions)}')
print(f'Degraded count: {degraded_count}')
print(f'Has degradation_record: {has_degradation_record}')
print(f'Backend ID: {opinions[0].get(\"backend_id\") if opinions else \"n/a\"}')
" 2>&1); then
    echo "    ✗ Degraded mode test failed: $RESULT"
    fail "DebateMemberInvocationService.execute should work in degraded mode" "Degraded count:" "$RESULT"
fi
echo "    ✓ Degraded mode assertions passed"
echo "      $RESULT" | head -4

test_done
