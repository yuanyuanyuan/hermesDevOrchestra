#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="e2e-ai-debate-flow"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="e2e-ai-debate"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

PORT="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
BASE_URL="http://127.0.0.1:$PORT"
GATEWAY_LOG="$TMP_DIR/gateway.log"
"$REPO_ROOT/scripts/bin/orch-gateway" --project-id "$PROJECT_ID" --host 127.0.0.1 --port "$PORT" >"$GATEWAY_LOG" 2>&1 &
GATEWAY_PID="$!"
trap 'kill "$GATEWAY_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

python3 - "$BASE_URL/health" "$GATEWAY_LOG" <<'PY'
import sys
import time
import urllib.request

url, log_path = sys.argv[1:]
deadline = time.time() + 30
last_error = None
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=0.5) as response:
            if response.status == 200:
                time.sleep(0.5)
                raise SystemExit(0)
    except Exception as exc:
        last_error = exc
        time.sleep(0.1)

print(open(log_path, encoding="utf-8", errors="replace").read(), file=sys.stderr)
raise SystemExit(f"gateway did not become healthy: {last_error}")
PY

python3 - "$BASE_URL" "$REPO_ROOT/config/debate/full/backend-policy.json" "$TMP_DIR" <<'PY'
import json
import pathlib
import sys
import urllib.request

base_url, backend_policy_path, tmp_dir = sys.argv[1:]
tmp_path = pathlib.Path(tmp_dir)

def post(path, payload):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        assert response.status == 200, (path, response.status)
        return json.loads(response.read().decode("utf-8"))

run_response = post(
    "/orchestra/modules/debate-engine/create-run",
    {
        "authority": "gateway_local_operator",
        "allow_staged": True,
        "question": "Should Hermes keep the local HTTP gateway contract or replace it?",
        "mode_id": "parallel_debate",
        "metadata": {"stage": "direction_debate"},
    },
)
run = run_response["result"]
assert run["debate_id"], run
assert run["mode_id"] == "parallel_debate", run

assembly_response = post(
    "/orchestra/modules/debate-assembly/select-for-stage",
    {
        "authority": "gateway_local_operator",
        "allow_staged": True,
        "stage": "direction_debate",
        "task_type": "api_contract",
        "risk_level": "L2",
    },
)
assembly = assembly_response["result"]
selected_members = assembly["selected_member_ids"]
assert assembly["stage"] == "direction_debate", assembly
assert isinstance(selected_members, list) and selected_members, assembly

backend_response = post(
    "/orchestra/modules/debate-backend-adapter/select-backend",
    {
        "authority": "gateway_local_runtime",
        "allow_staged": True,
        "stage": "direction_debate",
    },
)
backend = backend_response["result"]
assert backend["id"], backend
expected_degraded = bool(backend["degraded_fixture_only"])

execution_response = post(
    "/orchestra/modules/debate-member-invocation/execute",
    {
        "authority": "gateway_local_operator",
        "allow_staged": True,
        "run": run,
        "assembly": assembly,
        "input_refs": [f"state://runs/{run['debate_id']}/run.json"],
        "context_refs": [f"state://runs/{run['debate_id']}/context.json"],
        "option_refs": [],
        "affected_scopes": ["api://gateway-contract"],
        "candidate_solutions": [
            {
                "team_id": "architecture",
                "solution_text": "Keep the local HTTP gateway contract.",
                "team_score": 4,
                "assumptions": ["loopback boundary holds", "module facade remains small"],
                "conflicts": ["network exposure would need auth"],
                "write_scope": ["scripts/lib/orch_gateway.py"],
            },
            {
                "team_id": "delivery",
                "solution_text": "Replace the gateway contract with a separate service.",
                "team_score": 2,
                "assumptions": ["sidecar can be deployed quickly"],
                "conflicts": ["network exposure would need auth", "migration risk"],
                "write_scope": ["docs/gateway-integration-architecture.md"],
            },
        ],
        "event_log_path": str(tmp_path / "events.jsonl"),
        "audit_log_path": str(tmp_path / "audit.jsonl"),
    },
)
execution = execution_response["result"]
invocations = execution["invocations"]
opinions = execution["opinions"]
report = execution["report"]
audit_trail = execution["audit_trail"]

assert len(invocations) == len(selected_members), (len(invocations), len(selected_members))
assert len(opinions) == len(selected_members), (len(opinions), len(selected_members))
assert report["artifact_type"] == "debate_report", report
assert audit_trail["artifact_type"] == "debate_audit_trail", audit_trail
assert report["stage"] == "direction_debate", report
assert audit_trail["stage"] == "direction_debate", audit_trail
assert report["debate_metrics"]["canonical_mode_selected"] in {"consensus_fast", "standard_debate", "deep_fork"}, report
assert report["implementation_report"]["dag_validation_result"]["passed"] is True, report
assert report["ready_for_stage3"] is True, report
assert "stage_transition" in (tmp_path / "events.jsonl").read_text(encoding="utf-8")
assert "source_isolation_check" in (tmp_path / "audit.jsonl").read_text(encoding="utf-8")

if expected_degraded:
    assert all(opinion["degraded"] is True for opinion in opinions), opinions
    assert report["degraded"] is True, report
    assert report["degradation_status"] == "degraded", report
    assert report["authority_required"] == "kimi", report
else:
    assert all(opinion["degraded"] is False for opinion in opinions), opinions
    assert report["degraded"] is False, report
    assert report["degradation_status"] == "normal", report

backend_policy = json.loads(open(backend_policy_path, encoding="utf-8").read())
rebuilt_response = post(
    "/orchestra/modules/debate-report/build",
    {
        "authority": "gateway_local_operator",
        "run": run,
        "assembly": assembly,
        "backend_policy": backend_policy,
        "invocations": invocations,
        "opinions": opinions,
        "invocation_receipts": audit_trail["invocations"],
        "input_refs": [f"state://runs/{run['debate_id']}/run.json"],
        "affected_scopes": ["api://gateway-contract"],
    },
)
rebuilt = rebuilt_response["result"]
assert rebuilt["report"]["artifact_type"] == "debate_report", rebuilt
assert rebuilt["audit_trail"]["artifact_type"] == "debate_audit_trail", rebuilt
assert rebuilt["report"]["stage"] == report["stage"], (rebuilt, report)
assert rebuilt["report"]["degraded"] == report["degraded"], (rebuilt, report)
assert rebuilt["report_ref"] == execution["report_ref"], (rebuilt, execution)
assert rebuilt["audit_ref"] == execution["audit_ref"], (rebuilt, execution)
PY

test_done
