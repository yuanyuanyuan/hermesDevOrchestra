#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="e2e-ai-worker-flow"
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

cat > "$FAKE_BIN/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  -L)
    shift 2
    ;;
esac
case "${1:-}" in
  has-session|send-keys|kill-session) exit 0 ;;
esac
exit 1
SH
chmod +x "$FAKE_BIN/tmux"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="e2e-ai-worker"
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

python3 - "$BASE_URL" "$TMP_DIR/workspace" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

base_url, workspace_root, state_root, audit_root, project_id, hermes_log = sys.argv[1:]

def post(path, payload, *, expected=200):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            assert response.status == expected, (path, response.status)
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = json.loads(exc.read().decode("utf-8"))
        if exc.code == expected:
            return body
        raise AssertionError((path, exc.code, body)) from exc

def get(path):
    with urllib.request.urlopen(f"{base_url}{path}", timeout=10) as response:
        assert response.status == 200, (path, response.status)
        return json.loads(response.read().decode("utf-8"))

create = post(
    "/orchestra/runs",
    {
        "idempotency_key": "gw-e2e-worker-create",
        "ticket": {
            "background": "Worker output contract flow",
            "goal": "Negotiate a worker, create a session, and accept worker output",
            "deliverables": ["Queued run", "Worker session", "Accepted worker output"],
            "acceptance_criteria": ["Target task completes", "Gateway writes worker output report"],
            "hard_constraints": ["Use projected run tasks"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Block invalid worker output"
        },
        "options": {"mode": "mvp_full"}
    },
    expected=201,
)
run_id = create["run_id"]
tasks_before = get(f"/orchestra/runs/{run_id}/tasks")
implementation_task = next(task for task in tasks_before["tasks"] if task["stage"] == "implementation")
task_id = implementation_task["task_id"]
kanban_ref = implementation_task["kanban_ref"]

negotiation = post(
    "/orchestra/modules/capability-negotiation/negotiate",
    {
        "authority": "gateway_local_operator",
        "role": "implementer",
        "requested_backend": "codex",
        "required_capabilities": ["structured_envelope"],
    },
)
selected_backend = negotiation["result"]["selected_backend"]
assert selected_backend == "codex", negotiation

invalid_session = post(
    "/orchestra/modules/worker-session/create-session",
    {
        "authority": "gateway_local_operator",
        "run_id": "../escape-run",
        "task_id": task_id,
        "role": "implementer",
        "backend_id": selected_backend,
        "workspace_root": workspace_root,
        "write_scope_ref": f"state://runs/{run_id}/write-scopes/{task_id}.json",
        "context_bundle_ref": f"state://runs/{run_id}/worker-context-bundles/{task_id}.json",
        "timeout_seconds": 300,
    },
    expected=400,
)
assert invalid_session["error"]["code"] == "validation_error", invalid_session

session = post(
    "/orchestra/modules/worker-session/create-session",
    {
        "authority": "gateway_local_operator",
        "run_id": run_id,
        "task_id": task_id,
        "role": "implementer",
        "backend_id": selected_backend,
        "workspace_root": workspace_root,
        "write_scope_ref": f"state://runs/{run_id}/write-scopes/{task_id}.json",
        "context_bundle_ref": f"state://runs/{run_id}/worker-context-bundles/{task_id}.json",
        "timeout_seconds": 300,
    },
)
session_result = session["result"]
assert session_result["session_id"], session_result
assert session_result["status"], session_result
assert session_result["session_record_ref"].startswith(f"state://runs/{run_id}/worker-sessions/"), session_result
session_record_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "worker-sessions" / f"{session_result['session_id']}.json"
session_record = json.loads(session_record_path.read_text(encoding="utf-8"))
assert session_record["status"] == "planned", session_record
assert session_record["cleanup_owner"] == "gateway_worker_session_sweeper", session_record

starting = post(
    "/orchestra/modules/worker-session/transition",
    {
        "authority": "gateway_local_operator",
        "record": session_result,
        "next_status": "starting",
    },
)
running = post(
    "/orchestra/modules/worker-session/transition",
    {
        "authority": "gateway_local_operator",
        "record": starting["result"],
        "next_status": "running",
    },
)
completed = post(
    "/orchestra/modules/worker-session/transition",
    {
        "authority": "gateway_local_operator",
        "record": running["result"],
        "next_status": "completed",
        "output_envelope_ref": f"state://runs/{run_id}/worker-output-envelopes/{task_id}.json",
    },
)
assert completed["result"]["status"] == "completed", completed

invalid_transition = post(
    "/orchestra/modules/worker-session/transition",
    {
        "authority": "gateway_local_operator",
        "record": {
            **running["result"],
            "session_id": "../escape-session",
        },
        "next_status": "completed",
    },
    expected=400,
)
assert invalid_transition["error"]["code"] == "validation_error", invalid_transition

sweep = post(
    "/orchestra/modules/worker-session-sweeper/sweep-directory",
    {
        "authority": "gateway_local_operator",
        "records_root": str(session_record_path.parent),
    },
)
assert sweep["result"]["updated_records"] == 1, sweep
session_record = json.loads(session_record_path.read_text(encoding="utf-8"))
assert session_record["status"] == "completed", session_record
assert session_record["cleanup_status"] in {"cleaned", "not_found"}, session_record

worker_output = post(
    f"/orchestra/runs/{run_id}/worker-outputs",
    {
        "idempotency_key": "gw-e2e-worker-output",
        "task_id": task_id,
        "worker_response": {
            "protocol": "hermes-role-engine/v1",
            "role": "implementer",
            "correlation_id": task_id,
            "turn": 1,
            "status": "completed",
            "next_action": "complete",
            "role_specific_payload": {
                "requested_transition": "task_complete",
                "artifact_refs": [f"state://runs/{run_id}/run.json"],
                "changed_files": ["scripts/example.py"],
                "diff_summary": "Gateway worker flow completion",
                "write_scope_result": {
                    "within_scope": True,
                    "violations": [],
                    "forbidden_paths_touched": []
                },
                "test_evidence_refs": [f"state://runs/{run_id}/test-execution-report.json"],
                "risk_notes": [],
                "approval_refs": [],
                "commands": ["make test"],
                "parallel_execution": {
                    "parallel_group_id": "parallel-impl-success",
                    "task_ids": [task_id, "task-review-pass"],
                    "workspace_refs": [
                        f"state://runs/{run_id}/worker-workspaces/{task_id}.json",
                        f"state://runs/{run_id}/worker-workspaces/task-review-pass.json"
                    ],
                    "write_scope_refs": [
                        f"state://runs/{run_id}/write-scopes/{task_id}.json",
                        f"state://runs/{run_id}/write-scopes/task-review-pass.json"
                    ],
                    "declared_conflict_locks": ["repo://docs/runtime-boundary.md"],
                    "merge_order": [task_id, "task-review-pass"],
                    "review_gate": {
                        "required": True,
                        "owner": "gateway_serial_integrator",
                        "serial_integration": True
                    },
                    "actual_changed_files": ["scripts/example.py"],
                    "overlapping_writes": [],
                    "declared_lock_conflicts": [],
                    "authority_file_writes": [],
                    "out_of_scope_writes": []
                },
                "backend_execution": {
                    "backend": selected_backend,
                    "backend_kind": "cli",
                    "executed": True
                }
            },
            "conversation_context": [{"summary": "Scoped worker contract flow"}]
        }
    },
)
assert worker_output["gate_result"] == "accepted", worker_output
assert worker_output["transition"] == "task_complete", worker_output
assert worker_output["worker_output_report_ref"].startswith(f"state://runs/{run_id}/worker-output-reports/"), worker_output
assert len(worker_output["parallel_artifact_refs"]) == 2, worker_output

status = get(f"/orchestra/runs/{run_id}")
events = get(f"/orchestra/runs/{run_id}/events?since_seq=0&limit=20")
tasks_after = get(f"/orchestra/runs/{run_id}/tasks")

target_task = next(task for task in tasks_after["tasks"] if task["task_id"] == task_id)
assert target_task["status"] == "completed", target_task
assert worker_output["worker_output_report_ref"] in target_task["artifact_refs"], target_task
assert status["status"] == "queued", status
assert status["progress"]["completed_stages"] == 1, status

event_types = [event["type"] for event in events["events"]]
assert "task_completed" in event_types, event_types
assert "run_completed" not in event_types, event_types

report_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "worker-output-reports" / pathlib.Path(worker_output["worker_output_report_ref"]).name
report = json.loads(report_path.read_text(encoding="utf-8"))
assert report["artifact_type"] == "worker_output_report", report
assert report["result"] == "accepted", report
assert report["backend_execution"]["backend"] == selected_backend, report
parallel_dir = pathlib.Path(state_root) / project_id / "runs" / run_id / "parallel-groups" / "parallel-impl-success"
plan = json.loads((parallel_dir / "plan.json").read_text(encoding="utf-8"))
scan = json.loads((parallel_dir / "conflict-scan.json").read_text(encoding="utf-8"))
assert plan["artifact_type"] == "parallel_group_plan", plan
assert scan["artifact_type"] == "conflict_scan", scan
assert scan["merge_allowed"] is True, scan
assert not (parallel_dir / "merge-conflict-report.json").exists(), parallel_dir

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "worker_output_accepted" and record.get("task_id") == task_id for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in calls if line.startswith("kanban create")]) == 7, calls
assert f"kanban complete --board {project_id} --task {kanban_ref}" in calls, calls

conflict_task = next(task for task in tasks_after["tasks"] if task["status"] != "completed")
conflict_task_id = conflict_task["task_id"]

invalid_parallel = post(
    f"/orchestra/runs/{run_id}/worker-outputs",
    {
        "idempotency_key": "gw-e2e-worker-output-invalid-parallel",
        "task_id": conflict_task_id,
        "worker_response": {
            "protocol": "hermes-role-engine/v1",
            "role": "implementer",
            "correlation_id": conflict_task_id,
            "turn": 1,
            "status": "completed",
            "next_action": "complete",
            "role_specific_payload": {
                "requested_transition": "task_complete",
                "artifact_refs": [f"state://runs/{run_id}/run.json"],
                "changed_files": ["scripts/example.py"],
                "diff_summary": "Gateway worker invalid parallel metadata",
                "write_scope_result": {
                    "within_scope": True,
                    "violations": [],
                    "forbidden_paths_touched": []
                },
                "test_evidence_refs": [f"state://runs/{run_id}/test-execution-report.json"],
                "risk_notes": [],
                "approval_refs": [],
                "parallel_execution": {
                    "parallel_group_id": "../escape-group",
                    "task_ids": [conflict_task_id],
                    "workspace_refs": [
                        f"state://runs/{run_id}/worker-workspaces/{conflict_task_id}.json"
                    ],
                    "write_scope_refs": [
                        f"state://runs/{run_id}/write-scopes/{conflict_task_id}.json"
                    ],
                    "declared_conflict_locks": [],
                    "merge_order": [conflict_task_id],
                    "review_gate": {
                        "required": "yes",
                        "owner": "",
                        "serial_integration": True
                    },
                    "actual_changed_files": ["scripts/example.py"],
                    "overlapping_writes": [],
                    "declared_lock_conflicts": [],
                    "authority_file_writes": [],
                    "out_of_scope_writes": []
                }
            },
            "conversation_context": [{"summary": "Invalid parallel metadata"}]
        }
    },
    expected=400,
)
assert invalid_parallel["error"]["code"] == "validation_error", invalid_parallel

invalid_review_gate = post(
    f"/orchestra/runs/{run_id}/worker-outputs",
    {
        "idempotency_key": "gw-e2e-worker-output-invalid-review-gate",
        "task_id": conflict_task_id,
        "worker_response": {
            "protocol": "hermes-role-engine/v1",
            "role": "implementer",
            "correlation_id": conflict_task_id,
            "turn": 1,
            "status": "completed",
            "next_action": "complete",
            "role_specific_payload": {
                "requested_transition": "task_complete",
                "artifact_refs": [f"state://runs/{run_id}/run.json"],
                "changed_files": ["scripts/example.py"],
                "diff_summary": "Gateway worker invalid review gate metadata",
                "write_scope_result": {
                    "within_scope": True,
                    "violations": [],
                    "forbidden_paths_touched": []
                },
                "test_evidence_refs": [f"state://runs/{run_id}/test-execution-report.json"],
                "risk_notes": [],
                "approval_refs": [],
                "parallel_execution": {
                    "parallel_group_id": "parallel-invalid-review-gate",
                    "task_ids": [conflict_task_id],
                    "workspace_refs": [
                        f"state://runs/{run_id}/worker-workspaces/{conflict_task_id}.json"
                    ],
                    "write_scope_refs": [
                        f"state://runs/{run_id}/write-scopes/{conflict_task_id}.json"
                    ],
                    "declared_conflict_locks": [],
                    "merge_order": [conflict_task_id],
                    "review_gate": {
                        "required": "yes",
                        "owner": "",
                        "serial_integration": True
                    },
                    "actual_changed_files": ["scripts/example.py"],
                    "overlapping_writes": [],
                    "declared_lock_conflicts": [],
                    "authority_file_writes": [],
                    "out_of_scope_writes": []
                }
            },
            "conversation_context": [{"summary": "Invalid review gate metadata"}]
        }
    },
    expected=400,
)
assert invalid_review_gate["error"]["code"] == "validation_error", invalid_review_gate

conflict_output = post(
    f"/orchestra/runs/{run_id}/worker-outputs",
    {
        "idempotency_key": "gw-e2e-worker-output-conflict",
        "task_id": conflict_task_id,
        "worker_response": {
            "protocol": "hermes-role-engine/v1",
            "role": "implementer",
            "correlation_id": conflict_task_id,
            "turn": 1,
            "status": "completed",
            "next_action": "complete",
            "role_specific_payload": {
                "requested_transition": "task_complete",
                "artifact_refs": [f"state://runs/{run_id}/run.json"],
                "changed_files": ["scripts/example.py"],
                "diff_summary": "Gateway worker parallel conflict",
                "write_scope_result": {
                    "within_scope": True,
                    "violations": [],
                    "forbidden_paths_touched": []
                },
                "test_evidence_refs": [f"state://runs/{run_id}/test-execution-report.json"],
                "risk_notes": [],
                "approval_refs": [],
                "parallel_execution": {
                    "parallel_group_id": "parallel-impl-conflict",
                    "task_ids": [conflict_task_id, "task-review-conflict"],
                    "workspace_refs": [
                        f"state://runs/{run_id}/worker-workspaces/{conflict_task_id}.json",
                        f"state://runs/{run_id}/worker-workspaces/task-review-conflict.json"
                    ],
                    "write_scope_refs": [
                        f"state://runs/{run_id}/write-scopes/{conflict_task_id}.json",
                        f"state://runs/{run_id}/write-scopes/task-review-conflict.json"
                    ],
                    "declared_conflict_locks": ["repo://scripts/example.py"],
                    "merge_order": [conflict_task_id, "task-review-conflict"],
                    "review_gate": {
                        "required": True,
                        "owner": "gateway_serial_integrator",
                        "serial_integration": True
                    },
                    "actual_changed_files": ["scripts/example.py"],
                    "overlapping_writes": ["scripts/example.py"],
                    "declared_lock_conflicts": ["repo://scripts/example.py"],
                    "authority_file_writes": ["scripts/lib/orch_gateway.py"],
                    "out_of_scope_writes": ["docs/out-of-scope.md"]
                }
            },
            "conversation_context": [{"summary": "Parallel conflict flow"}]
        }
    },
)
assert conflict_output["gate_result"] == "blocked", conflict_output
assert conflict_output["failure_class"] == "parallel_conflict", conflict_output

conflict_status = get(f"/orchestra/runs/{run_id}")
conflict_events = get(f"/orchestra/runs/{run_id}/events?since_seq=0&limit=20")
conflict_tasks_after = get(f"/orchestra/runs/{run_id}/tasks")
conflict_target = next(task for task in conflict_tasks_after["tasks"] if task["task_id"] == conflict_task_id)
assert conflict_status["status"] == "blocked", conflict_status
assert conflict_status["blocked_reason"] == "worker_output_parallel_conflict", conflict_status
assert conflict_target["status"] == "blocked", conflict_target
assert conflict_target["blocked_reason"] == "worker_output_parallel_conflict", conflict_target
conflict_parallel_dir = pathlib.Path(state_root) / project_id / "runs" / run_id / "parallel-groups" / "parallel-impl-conflict"
conflict_report = json.loads((conflict_parallel_dir / "merge-conflict-report.json").read_text(encoding="utf-8"))
assert conflict_report["artifact_type"] == "merge_conflict_report", conflict_report
assert conflict_report["kimi_decision_required"] is True, conflict_report
conflict_kinds = {entry["kind"] for entry in conflict_report["conflicts"]}
assert conflict_kinds == {
    "overlapping_write",
    "declared_lock_conflict",
    "authority_file_write",
    "out_of_scope_write",
}, conflict_report
event_types = [event["type"] for event in conflict_events["events"]]
assert "worker_output_blocked" in event_types, event_types
PY

test_done
