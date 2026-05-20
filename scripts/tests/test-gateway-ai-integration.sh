#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-ai-integration"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Testing Gateway AI integration..."

# Setup isolated environment
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"

mkdir -p "$STATE_ROOT" "$AUDIT_ROOT" "$CACHE_ROOT"

# Find free port
PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()")

# Start Gateway in background (direct Python invocation to avoid HOME issues)
echo "  Starting Gateway on port $PORT..."
python3 /data/hermes/scripts/lib/orch_gateway.py --project-id test-ai-integration --port "$PORT" &
GATEWAY_PID=$!
trap 'kill $GATEWAY_PID 2>/dev/null; rm -rf "$TMP_DIR"' EXIT

# Wait for Gateway to start
echo "  Waiting for Gateway..."
STARTED=false
for i in {1..30}; do
    if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        STARTED=true
        break
    fi
    sleep 0.2
done

if [ "$STARTED" = "false" ]; then
    fail "Gateway failed to start within 6 seconds" "running" "not responding"
fi
echo "    ✓ Gateway started"

# Test /health endpoint
echo "  Testing /health..."
HEALTH=$(curl -s "http://127.0.0.1:$PORT/health")
if echo "$HEALTH" | python3 -m json.tool &>/dev/null; then
    echo "    ✓ /health returns valid JSON"
else
    fail "/health should return valid JSON" "valid JSON" "$HEALTH"
fi

# Test /orchestra/capabilities
echo "  Testing /orchestra/capabilities..."
CAPS=$(curl -s "http://127.0.0.1:$PORT/orchestra/capabilities")
if echo "$CAPS" | python3 -c "import sys, json; d=json.load(sys.stdin); assert 'routes' in d; assert 'workers' in d" 2>/dev/null; then
    echo "    ✓ /orchestra/capabilities returns routes and workers"
else
    fail "/orchestra/capabilities should contain routes and workers" "routes+workers" "$CAPS"
fi

# Test module endpoint: debate-engine load-registries
echo "  Testing debate-engine load-registries..."
REGISTRIES=$(curl -s -X POST "http://127.0.0.1:$PORT/orchestra/modules/debate-engine/load-registries" \
    -H "Content-Type: application/json" \
    -d '{"authority": "gateway_local_runtime", "allow_staged": true}')
if echo "$REGISTRIES" | python3 -c "import sys, json; d=json.load(sys.stdin); assert 'result' in d" 2>/dev/null; then
    echo "    ✓ debate-engine load-registries works"
else
    echo "    ✗ debate-engine load-registries: $REGISTRIES"
    fail "load-registries should return result" "result key" "$REGISTRIES"
fi

# Test module endpoint: worker-registry load-backends
echo "  Testing worker-registry load-backends..."
BACKENDS=$(curl -s -X POST "http://127.0.0.1:$PORT/orchestra/modules/worker-registry/load-backends" \
    -H "Content-Type: application/json" \
    -d '{"authority": "gateway_local_runtime", "allow_staged": true}')
if echo "$BACKENDS" | python3 -c "import sys, json; d=json.load(sys.stdin); r=d.get('result',{}); assert 'backends' in r" 2>/dev/null; then
    echo "    ✓ worker-registry load-backends works"
    BACKEND_IDS=$(echo "$BACKENDS" | python3 -c "import sys, json; b=json.load(sys.stdin)['result']['backends']; print([x['id'] if isinstance(x,dict) else x for x in b])" 2>/dev/null || echo "N/A")
    echo "      Backends: $BACKEND_IDS"
else
    echo "    ✗ worker-registry load-backends: $BACKENDS"
    fail "load-backends should return backends" "backends key" "$BACKENDS"
fi

# Test module endpoint: capability-negotiation
echo "  Testing capability-negotiation..."
NEGOTIATE=$(curl -s -X POST "http://127.0.0.1:$PORT/orchestra/modules/capability-negotiation/negotiate" \
    -H "Content-Type: application/json" \
    -d '{"authority": "gateway_local_operator", "role": "implementer", "allow_staged": true}')
if echo "$NEGOTIATE" | python3 -c "import sys, json; d=json.load(sys.stdin); r=d.get('result',{}); assert 'selected_backend' in r" 2>/dev/null; then
    BACKEND=$(echo "$NEGOTIATE" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['selected_backend'])")
    echo "    ✓ capability-negotiation works (selected: $BACKEND)"
else
    echo "    ✗ capability-negotiation: $NEGOTIATE"
    fail "negotiate should select backend" "selected_backend" "$NEGOTIATE"
fi

# Test POST /orchestra/runs (create a run)
echo "  Testing POST /orchestra/runs..."
RUN_RESPONSE=$(curl -s -X POST "http://127.0.0.1:$PORT/orchestra/runs" \
    -H "Content-Type: application/json" \
    -d '{
        "idempotency_key": "test-ai-integration-001",
        "ticket": {
            "background": "Gateway AI integration tracer bullet",
            "goal": "Verify the public run-level orchestration contract",
            "deliverables": ["Run state", "Task projection", "Event projection"],
            "acceptance_criteria": ["Run creation returns queued status", "Run exposes tasks/events URLs"],
            "hard_constraints": ["Use the run-level orchestration entrypoint"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Block with evidence if orchestration state cannot be written"
        },
        "options": {
            "mode": "mvp_full"
        }
    }')
if echo "$RUN_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); assert d['status'] == 'queued'; assert d['projection_status'] == 'consistent'; assert d['events_url'].startswith('/orchestra/runs/'); assert d['tasks_url'].startswith('/orchestra/runs/')" 2>/dev/null; then
    RUN_ID=$(echo "$RUN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['run_id'])" 2>/dev/null || echo "none")
    echo "    ✓ POST /orchestra/runs created a queued run (run_id: $RUN_ID)"
else
    echo "    ✗ POST /orchestra/runs: $RUN_RESPONSE"
    fail "POST /orchestra/runs should create a queued run with events/tasks URLs" "queued run" "$RUN_RESPONSE"
fi

echo "  Testing GET /orchestra/runs/$RUN_ID..."
RUN_STATUS=$(curl -s "http://127.0.0.1:$PORT/orchestra/runs/$RUN_ID")
if echo "$RUN_STATUS" | python3 -c "import sys, json; d=json.load(sys.stdin); assert d['run_id']; assert d['status'] == 'queued'; assert d['current_stage'] == 'direction_debate'" 2>/dev/null; then
    echo "    ✓ GET /orchestra/runs/{run_id} returns queued run state"
else
    echo "    ✗ GET /orchestra/runs/{run_id}: $RUN_STATUS"
    fail "GET /orchestra/runs/{run_id} should return queued run state" "queued run state" "$RUN_STATUS"
fi

echo "  Testing GET /orchestra/runs/$RUN_ID/tasks..."
RUN_TASKS=$(curl -s "http://127.0.0.1:$PORT/orchestra/runs/$RUN_ID/tasks")
if echo "$RUN_TASKS" | python3 -c "import sys, json; d=json.load(sys.stdin); tasks=d['tasks']; assert d['projection_status'] == 'consistent'; assert len(tasks) == 6; assert tasks[0]['stage'] == 'direction_debate'; assert tasks[-1]['stage'] == 'continuous_improvement'" 2>/dev/null; then
    echo "    ✓ GET /orchestra/runs/{run_id}/tasks returns six-stage task projection"
else
    echo "    ✗ GET /orchestra/runs/{run_id}/tasks: $RUN_TASKS"
    fail "GET /orchestra/runs/{run_id}/tasks should return six queued stage tasks" "six-stage task projection" "$RUN_TASKS"
fi

echo "  Testing GET /orchestra/runs/$RUN_ID/events..."
RUN_EVENTS=$(curl -s "http://127.0.0.1:$PORT/orchestra/runs/$RUN_ID/events?since_seq=0&limit=20")
if echo "$RUN_EVENTS" | python3 -c "import sys, json; d=json.load(sys.stdin); events=d['events']; assert d['projection_status'] == 'consistent'; assert len(events) == 1; assert events[0]['type'] == 'run_created'; assert events[0]['status'] == 'queued'" 2>/dev/null; then
    echo "    ✓ GET /orchestra/runs/{run_id}/events returns run_created event"
else
    echo "    ✗ GET /orchestra/runs/{run_id}/events: $RUN_EVENTS"
    fail "GET /orchestra/runs/{run_id}/events should return run_created event" "run_created event" "$RUN_EVENTS"
fi

echo ""
echo "Gateway AI integration test passed!"

test_done
