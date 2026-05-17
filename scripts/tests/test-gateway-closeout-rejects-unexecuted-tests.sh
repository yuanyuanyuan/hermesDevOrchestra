#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-closeout-rejects-unexecuted-tests"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "create" ]; then
  printf '{"id":"kanban-%s","status":"created"}\n' "$RANDOM"
  exit 0
fi
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="gateway-closeout-unexecuted"
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
deadline = time.time() + 5
last_error = None
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=0.5) as response:
            if response.status == 200:
                raise SystemExit(0)
    except Exception as exc:
        last_error = exc
        time.sleep(0.1)

print(open(log_path, encoding="utf-8", errors="replace").read(), file=sys.stderr)
raise SystemExit(f"gateway did not become healthy: {last_error}")
PY

python3 - "$BASE_URL" "$TMP_DIR/response.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, output_path = sys.argv[1:]

def post(path, payload, expected=200):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            body = json.loads(response.read().decode("utf-8"))
            assert response.status == expected, (response.status, body)
            return response.status, body
    except urllib.error.HTTPError as exc:
        body = json.loads(exc.read().decode("utf-8"))
        return exc.code, body

def get(path):
    with urllib.request.urlopen(f"{base_url}{path}", timeout=5) as response:
        assert response.status == 200, response.status
        return json.loads(response.read().decode("utf-8"))

_, create = post(
    "/orchestra/runs",
    {
        "idempotency_key": "gw-closeout-unexecuted-create",
        "ticket": {
            "background": "Closeout gate must verify executed tests",
            "goal": "Reject paper-only test evidence",
            "deliverables": ["Blocked closeout"],
            "acceptance_criteria": ["Unexecuted tests cannot satisfy closeout"],
            "hard_constraints": ["Do not trust completion_gate booleans"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Block closeout"
        },
        "options": {"mode": "mvp_full"}
    },
    expected=201,
)
run_id = create["run_id"]
tasks = get(f"/orchestra/runs/{run_id}/tasks")["tasks"]
for index, task in enumerate(tasks, start=1):
    post(
        f"/orchestra/runs/{run_id}/worker-outputs",
        {
            "idempotency_key": f"gw-closeout-unexecuted-worker-{index}",
            "task_id": task["task_id"],
            "worker_response": {
                "protocol": "hermes-role-engine/v1",
                "role": "implementer",
                "correlation_id": task["task_id"],
                "turn": index,
                "status": "completed",
                "next_action": "complete",
                "role_specific_payload": {
                    "requested_transition": "task_complete",
                    "artifact_refs": [f"state://runs/{run_id}/run.json"],
                    "changed_files": [],
                    "diff_summary": "",
                    "write_scope_result": {"within_scope": True, "violations": [], "forbidden_paths_touched": []},
                    "test_evidence_refs": [],
                    "risk_notes": [],
                    "approval_refs": []
                },
                "conversation_context": []
            }
        },
    )

global_report = {
    "schema_version": "orchestra.v1",
    "artifact_type": "global_evaluation_report",
    "run_id": run_id,
    "stage": "global_evaluation",
    "input_artifact_refs": [f"state://runs/{run_id}/run.json"],
    "structured_prd_ref": f"state://runs/{run_id}/structured_prd.json",
    "development_plan_ref": f"state://runs/{run_id}/development_plan.json",
    "debate_report_refs": [],
    "implementation_evidence_refs": [],
    "review_verdict_refs": [],
    "qa_verdict_refs": [],
    "test_execution_refs": [f"state://runs/{run_id}/test_execution_report.json"],
    "improvement_report_refs": [],
    "downgrade_refs": [],
    "unresolved_decision_refs": [],
    "audit_refs": [],
    "verdict": "pass_with_warnings",
    "warnings": [{"warning_id": "W-001", "summary": "Testing was only planned"}],
    "residual_risks": ["Test command was not executed"],
    "blocking_issues": [],
    "authority_required": "kimi",
    "final_acceptance_ref": None,
    "next_actions": ["Request final acceptance"],
    "created_at": "2026-05-17T00:00:00Z"
}
_, global_response = post(
    f"/orchestra/runs/{run_id}/global-evaluations",
    {"idempotency_key": "gw-closeout-unexecuted-global", "report": global_report},
)
_, decision = post(
    f"/orchestra/decisions/{global_response['decision_id']}",
    {
        "idempotency_key": "gw-closeout-unexecuted-final",
        "action": "approve",
        "actor": "kimi",
        "rationale": "Trying to accept warnings",
        "accepted_warning_refs": [global_response["global_evaluation_report_ref"]]
    },
)

test_execution_ref = f"state://runs/{run_id}/test_execution_report.json"
proposals_ref = f"state://runs/{run_id}/system_improvement_proposals.json"
status, body = post(
    f"/orchestra/runs/{run_id}/closeout",
    {
        "idempotency_key": "gw-closeout-unexecuted-closeout",
        "iteration_closeout_report": {
            "schema_version": "orchestra.v1",
            "artifact_type": "iteration_closeout_report",
            "run_id": run_id,
            "global_evaluation_report_ref": global_response["global_evaluation_report_ref"],
            "closeout_kind": "completed",
            "final_acceptance": {
                "accepted_by": "kimi",
                "authority": "kimi",
                "verdict": "accepted_with_warnings",
                "rationale": "Trying to accept warnings",
                "decision_ref": decision["final_acceptance_ref"]
            },
            "accepted_warning_refs": [global_response["global_evaluation_report_ref"]],
            "downgrade_records": [],
            "unresolved_decisions": [],
            "pending_decision_refs": [],
            "deferred_decisions": [],
            "completed_stage_refs": [f"state://runs/{run_id}/tasks.json"],
            "incomplete_stage_refs": [],
            "stop_request_ref": None,
            "run_stopped_event_ref": None,
            "preserved_artifact_refs": [f"state://runs/{run_id}/run.json"],
            "resume_checkpoint_refs": [],
            "worker_cancel_marker_refs": [],
            "test_execution_refs": [test_execution_ref],
            "review_verdict_refs": [],
            "qa_verdict_refs": [],
            "worker_fallbacks": [],
            "knowledge_updates": {"auto_applied_refs": [], "proposal_refs": [], "forbidden_target_refs": []},
            "system_improvement_proposals_ref": proposals_ref,
            "completion_gate": {
                "artifacts_schema_valid": True,
                "audit_closeout_recorded": True,
                "kanban_stage_tasks_done": True,
                "gateway_state_consistent": True,
                "completion_blockers": []
            },
            "created_at": "2026-05-17T00:00:00Z"
        },
        "system_improvement_proposals": {
            "schema_version": "orchestra.v1",
            "artifact_type": "system_improvement_proposals",
            "run_id": run_id,
            "source_refs": [],
            "proposals": [],
            "auto_applied_refs": [],
            "proposed_patch_refs": [],
            "approval_required": [],
            "decision_refs": [],
            "final_acceptance_ref": decision["final_acceptance_ref"],
            "downgrade_refs": [],
            "worker_fallback_refs": [],
            "knowledge_update_refs": []
        }
    },
)
assert status == 400, (status, body)
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/response.json" <<'PY'
import json
import sys

body = json.load(open(sys.argv[1], encoding="utf-8"))
assert body["error"]["code"] == "closeout_validation_failed", body
assert "test_execution_refs" in body["completion_blockers"], body
PY

test_done
