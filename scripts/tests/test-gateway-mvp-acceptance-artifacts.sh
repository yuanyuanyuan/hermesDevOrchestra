#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-mvp-acceptance-artifacts"
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

PROJECT_ID="gateway-mvp-acceptance"
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
        "idempotency_key": "gw-047-create",
        "ticket": {
            "background": "Full MVP acceptance evidence",
            "goal": "Complete a local Gateway MVP run with required evidence artifacts",
            "deliverables": ["Completed run", "Acceptance artifacts"],
            "acceptance_criteria": ["Acceptance evidence exists", "Gateway closeout completes"],
            "hard_constraints": ["Do not use cache as completion authority"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Block if required evidence is missing"
        },
        "options": {"mode": "mvp_full"}
    },
    expected=201,
)
run_id = create["run_id"]
tasks = get(f"/orchestra/runs/{run_id}/tasks")["tasks"]
test_execution_ref = f"state://runs/{run_id}/test_execution_report.json"
for index, task in enumerate(tasks, start=1):
    changed_files = ["scripts/lib/orch_gateway.py"] if task["stage"] == "implementation" else []
    post(
        f"/orchestra/runs/{run_id}/worker-outputs",
        {
            "idempotency_key": f"gw-047-worker-{index}",
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
                    "changed_files": changed_files,
                    "diff_summary": "Gateway MVP acceptance task evidence",
                    "write_scope_result": {
                        "within_scope": True,
                        "violations": [],
                        "forbidden_paths_touched": []
                    },
                    "test_evidence_refs": [test_execution_ref] if changed_files else [],
                    "risk_notes": [],
                    "approval_refs": [],
                    "commands": ["make test"],
                    "backend_execution": {
                        "backend": "codex",
                        "backend_kind": "cli",
                        "executed": True
                    }
                },
                "conversation_context": [{"summary": "state and scoped artifact refs only"}]
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
    "debate_report_refs": [f"state://runs/{run_id}/debate-reports/direction_debate.json"],
    "implementation_evidence_refs": [f"state://runs/{run_id}/worker-output-reports"],
    "review_verdict_refs": [],
    "qa_verdict_refs": [],
    "test_execution_refs": [test_execution_ref],
    "improvement_report_refs": [f"state://runs/{run_id}/improvement_report.json"],
    "downgrade_refs": [f"state://runs/{run_id}/debate-reports/direction_debate.json"],
    "unresolved_decision_refs": [],
    "audit_refs": [],
    "verdict": "pass_with_warnings",
    "warnings": [{"warning_id": "W-047", "summary": "Template debate fallback was used"}],
    "residual_risks": ["Template debate fallback accepted for MVP"],
    "blocking_issues": [],
    "authority_required": "kimi",
    "final_acceptance_ref": None,
    "next_actions": ["Request final acceptance"],
    "created_at": "2026-05-17T00:00:00Z"
}
global_response = post(
    f"/orchestra/runs/{run_id}/global-evaluations",
    {"idempotency_key": "gw-047-global-evaluation", "report": global_report},
)
decision = post(
    f"/orchestra/decisions/{global_response['decision_id']}",
    {
        "idempotency_key": "gw-047-final-acceptance",
        "action": "approve",
        "actor": "kimi",
        "rationale": "Template fallback warning accepted for MVP",
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
        "accepted_by": "gateway",
        "authority": "gateway",
        "verdict": "accepted_with_warnings",
        "rationale": "Template fallback warning accepted for MVP",
        "decision_ref": final_acceptance_ref
    },
    "accepted_warning_refs": [global_response["global_evaluation_report_ref"]],
    "downgrade_records": [{"kind": "debate_degraded", "backend": "template"}],
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
    "downgrade_refs": [f"state://runs/{run_id}/debate-reports/direction_debate.json"],
    "worker_fallback_refs": [],
    "knowledge_update_refs": []
}
closeout_response = post(
    f"/orchestra/runs/{run_id}/closeout",
    {
        "idempotency_key": "gw-047-closeout",
        "iteration_closeout_report": closeout,
        "system_improvement_proposals": proposals
    },
)
status = get(f"/orchestra/runs/{run_id}")
events = get(f"/orchestra/runs/{run_id}/events?since_seq=0&limit=200")
with open(flow_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "run_id": run_id,
            "closeout_response": closeout_response,
            "status": status,
            "events": events,
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
status = flow["status"]
events = flow["events"]["events"]
run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id

assert status["status"] == "completed", status

required_files = [
    "structured_prd.json",
    "development_plan.json",
    "test_plan.json",
    "test_execution_report.json",
    "worker_selection_record.json",
    "best_choice_report.json",
    "implementation_plan_report.json",
    "task_feedback_report.json",
    "improvement_report.json",
    "global_evaluation_report.json",
    "iteration_closeout_report.json",
    "system_improvement_proposals.json",
]
for name in required_files:
    assert (run_dir / name).is_file(), f"missing required MVP artifact: {name}"

development_plan = json.loads((run_dir / "development_plan.json").read_text(encoding="utf-8"))
test_plan = json.loads((run_dir / "test_plan.json").read_text(encoding="utf-8"))
test_execution = json.loads((run_dir / "test_execution_report.json").read_text(encoding="utf-8"))
worker_selection = json.loads((run_dir / "worker_selection_record.json").read_text(encoding="utf-8"))
assert development_plan["parallelism_policy"]["top_level_serial"] is True, development_plan
assert test_plan["cases"][0]["acceptance_criteria_refs"], test_plan
assert test_execution["commands"][0]["command"] == "make test", test_execution
assert test_execution["commands"][0]["executed"] is True, test_execution
assert test_execution["commands"][0]["exit_code"] == 0, test_execution
assert worker_selection["selected_backend"] == "codex", worker_selection
assert worker_selection["backend_kind"] == "cli", worker_selection

tasks = json.loads((run_dir / "tasks.json").read_text(encoding="utf-8"))["tasks"]
for task in tasks:
    envelope = run_dir / "worker-context-envelopes" / f"{task['task_id']}.json"
    bundle = run_dir / "worker-context-bundles" / f"{task['task_id']}.json"
    assert envelope.is_file(), envelope
    assert bundle.is_file(), bundle
    envelope_data = json.loads(envelope.read_text(encoding="utf-8"))
    assert envelope_data["protocol"] == "hermes-role-engine/v1", envelope_data
    assert envelope_data["context_bundle_refs"], envelope_data
    assert not any(str(value).startswith("/") for value in envelope_data.get("artifact_refs", [])), envelope_data

worker_reports = list((run_dir / "worker-output-reports").glob("*.json"))
assert worker_reports, "missing worker output reports"
assert any(
    json.loads(path.read_text(encoding="utf-8")).get("backend_execution", {}).get("backend_kind") == "cli"
    for path in worker_reports
), "missing real CLI worker execution evidence"

event_types = [event["type"] for event in events]
assert "task_completed" in event_types, event_types
assert "stage_completed" in event_types, event_types
assert "run_completed" in event_types, event_types

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "mvp_acceptance_artifacts_recorded" for record in audit_records), audit_records
assert any(record.get("type") == "worker_context_prepared" for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in calls if line.startswith("kanban create")]) == 7
assert len([line for line in calls if line.startswith("kanban complete")]) == 6
PY

test_done
