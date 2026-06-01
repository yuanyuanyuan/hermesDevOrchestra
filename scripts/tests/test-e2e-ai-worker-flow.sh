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
import urllib.request

base_url, workspace_root, state_root, audit_root, project_id, hermes_log = sys.argv[1:]

def post(path, payload, *, expected=200):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        assert response.status == expected, (path, response.status)
        return json.loads(response.read().decode("utf-8"))

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
        "allow_staged": True,
        "role": "implementer",
        "requested_backend": "codex",
        "required_capabilities": ["structured_envelope"],
    },
)
selected_backend = negotiation["result"]["selected_backend"]
assert selected_backend == "codex", negotiation

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

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "worker_output_accepted" and record.get("task_id") == task_id for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in calls if line.startswith("kanban create")]) == 7, calls
assert f"kanban complete --board {project_id} --task {kanban_ref}" in calls, calls
PY

test_done
