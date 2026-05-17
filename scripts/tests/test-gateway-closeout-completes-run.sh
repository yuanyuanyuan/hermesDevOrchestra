#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-closeout-completes-run"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

HERMES_CALL_LOG="$TMP_DIR/hermes-calls.log"
export HERMES_CALL_LOG

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "create" ]; then
  printf '{"id":"kanban-%s","status":"created"}\n' "$(wc -l < "$HERMES_CALL_LOG" | tr -d ' ')"
  exit 0
fi
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "complete" ]; then
  printf '{"status":"completed"}\n'
  exit 0
fi
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

cat > "$FAKE_BIN/make" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$FAKE_BIN/make"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
export ORCH_GATEWAY_RUN_TESTS=1
mkdir -p "$HOME"

PROJECT_ID="gateway-closeout-complete"
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

python3 - "$BASE_URL" "$TMP_DIR/flow.json" <<'PY'
import json
import sys
import urllib.request

base_url, flow_path = sys.argv[1:]

def post(path, payload, expected=200):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        assert response.status == expected, (response.status, path)
        return json.loads(response.read().decode("utf-8"))

def get(path):
    with urllib.request.urlopen(f"{base_url}{path}", timeout=5) as response:
        assert response.status == 200, (response.status, path)
        return json.loads(response.read().decode("utf-8"))

create = post(
    "/orchestra/runs",
    {
        "idempotency_key": "gw-032-create",
        "ticket": {
            "background": "Positive closeout gate test",
            "goal": "Complete run only through closeout authority",
            "deliverables": ["Completed run"],
            "acceptance_criteria": ["Closeout gate writes run_completed"],
            "hard_constraints": ["All stage tasks must be complete"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Block if closeout authority is incomplete"
        },
        "options": {"mode": "mvp_full"}
    },
    expected=201,
)
run_id = create["run_id"]
tasks = get(f"/orchestra/runs/{run_id}/tasks")["tasks"]
test_execution_ref = f"state://runs/{run_id}/test_execution_report.json"
for index, task in enumerate(tasks, start=1):
    post(
        f"/orchestra/runs/{run_id}/worker-outputs",
        {
            "idempotency_key": f"gw-032-worker-{index}",
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
                    "write_scope_result": {
                        "within_scope": True,
                        "violations": [],
                        "forbidden_paths_touched": []
                    },
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
    "test_execution_refs": [test_execution_ref],
    "improvement_report_refs": [],
    "downgrade_refs": [],
    "unresolved_decision_refs": [],
    "audit_refs": [],
    "verdict": "pass_with_warnings",
    "warnings": [{"warning_id": "W-001", "summary": "Template fallback accepted"}],
    "residual_risks": ["Template fallback accepted for MVP"],
    "blocking_issues": [],
    "authority_required": "kimi",
    "final_acceptance_ref": None,
    "next_actions": ["Request final acceptance"],
    "created_at": "2026-05-17T00:00:00Z"
}
global_response = post(
    f"/orchestra/runs/{run_id}/global-evaluations",
    {"idempotency_key": "gw-032-global-evaluation", "report": global_report},
)
decision = post(
    f"/orchestra/decisions/{global_response['decision_id']}",
    {
        "idempotency_key": "gw-032-final-acceptance",
        "action": "approve",
        "actor": "kimi",
        "rationale": "Warnings accepted for MVP",
        "accepted_warning_refs": [global_response["global_evaluation_report_ref"]]
    },
)
final_acceptance_ref = decision["final_acceptance_ref"]
proposals_ref = f"state://runs/{run_id}/system_improvement_proposals.json"
closeout_ref = f"state://runs/{run_id}/iteration_closeout_report.json"
closeout = {
    "schema_version": "orchestra.v1",
    "artifact_type": "iteration_closeout_report",
    "run_id": run_id,
    "global_evaluation_report_ref": global_response["global_evaluation_report_ref"],
    "closeout_kind": "completed",
    "final_acceptance": {
        "accepted_by": "kimi",
        "authority": "kimi",
        "verdict": "accepted_with_warnings",
        "rationale": "Warnings accepted for MVP",
        "decision_ref": final_acceptance_ref
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
    "knowledge_updates": {
        "auto_applied_refs": [],
        "proposal_refs": [],
        "forbidden_target_refs": []
    },
    "system_improvement_proposals_ref": proposals_ref,
    "completion_gate": {
        "artifacts_schema_valid": True,
        "audit_closeout_recorded": True,
        "kanban_stage_tasks_done": True,
        "gateway_state_consistent": True,
        "completion_blockers": []
    },
    "created_at": "2026-05-17T00:00:00Z"
}
proposals = {
    "schema_version": "orchestra.v1",
    "artifact_type": "system_improvement_proposals",
    "run_id": run_id,
    "source_refs": [closeout_ref],
    "proposals": [],
    "auto_applied_refs": [],
    "proposed_patch_refs": [],
    "approval_required": [],
    "decision_refs": [],
    "final_acceptance_ref": final_acceptance_ref,
    "downgrade_refs": [],
    "worker_fallback_refs": [],
    "knowledge_update_refs": []
}
closeout_response = post(
    f"/orchestra/runs/{run_id}/closeout",
    {
        "idempotency_key": "gw-032-closeout",
        "iteration_closeout_report": closeout,
        "system_improvement_proposals": proposals
    },
)
status = get(f"/orchestra/runs/{run_id}")
events = get(f"/orchestra/runs/{run_id}/events?since_seq=0&limit=100")
with open(flow_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "run_id": run_id,
            "closeout_response": closeout_response,
            "status": status,
            "events": events,
            "closeout_ref": closeout_ref,
            "proposals_ref": proposals_ref,
        },
        handle,
        indent=2,
    )
    handle.write("\n")
PY

python3 - "$TMP_DIR/flow.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

flow_path, state_root, audit_root, project_id, hermes_log = sys.argv[1:]
flow = json.load(open(flow_path, encoding="utf-8"))
run_id = flow["run_id"]
response = flow["closeout_response"]
status = flow["status"]
events = flow["events"]

assert response["status"] == "completed", response
assert response["route_result"] == "run_completed", response
assert response["iteration_closeout_report_ref"] == flow["closeout_ref"], response
assert response["system_improvement_proposals_ref"] == flow["proposals_ref"], response

assert status["status"] == "completed", status
assert status["blocked_reason"] is None, status
assert status["artifact_refs"]["iteration_closeout_report"] == flow["closeout_ref"], status
assert status["artifact_refs"]["system_improvement_proposals"] == flow["proposals_ref"], status

event_types = [event["type"] for event in events["events"]]
assert "run_completed" in event_types, event_types
completed_event = next(event for event in events["events"] if event["type"] == "run_completed")
assert completed_event["artifact_refs"] == [flow["closeout_ref"], flow["proposals_ref"], f"state://runs/{run_id}/run.json"], completed_event

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
closeout = json.loads((run_dir / "iteration_closeout_report.json").read_text(encoding="utf-8"))
proposals = json.loads((run_dir / "system_improvement_proposals.json").read_text(encoding="utf-8"))
assert closeout["closeout_kind"] == "completed", closeout
assert closeout["completion_gate"]["completion_blockers"] == [], closeout
assert proposals["artifact_type"] == "system_improvement_proposals", proposals

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "run_completed" and record.get("command_id") == response["command_id"] for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in calls if line.startswith("kanban create")]) == 7
assert len([line for line in calls if line.startswith("kanban complete")]) == 6
PY

test_done
