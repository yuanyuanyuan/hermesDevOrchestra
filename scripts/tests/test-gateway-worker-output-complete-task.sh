#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-worker-output-complete-task"
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

PROJECT_ID="gateway-worker-complete"
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

python3 - "$BASE_URL" "$TMP_DIR/create.json" "$TMP_DIR/tasks-before.json" <<'PY'
import json
import sys
import urllib.request

base_url, create_path, tasks_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-025-create",
    "ticket": {
        "background": "Advancement Gate positive completion test",
        "goal": "Complete one task from validated worker output",
        "deliverables": ["Completed first stage task"],
        "acceptance_criteria": ["Valid worker output completes only the target task"],
        "hard_constraints": ["Run completion still requires closeout authority"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Block invalid output"
    },
    "options": {"mode": "mvp_full"}
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 201, response.status
    create = json.loads(response.read().decode("utf-8"))
with urllib.request.urlopen(f"{base_url}/orchestra/runs/{create['run_id']}/tasks", timeout=5) as response:
    assert response.status == 200, response.status
    tasks = json.loads(response.read().decode("utf-8"))
for path, body in ((create_path, create), (tasks_path, tasks)):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

RUN_ID="$(python3 - "$TMP_DIR/create.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["run_id"])
PY
)"
TASK_ID="$(python3 - "$TMP_DIR/tasks-before.json" <<'PY'
import json
import sys
tasks = json.load(open(sys.argv[1], encoding="utf-8"))["tasks"]
print(tasks[0]["task_id"])
PY
)"
KANBAN_REF="$(python3 - "$TMP_DIR/tasks-before.json" <<'PY'
import json
import sys
tasks = json.load(open(sys.argv[1], encoding="utf-8"))["tasks"]
print(tasks[0]["kanban_ref"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TASK_ID" "$TMP_DIR/worker-output.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, task_id, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-025-worker-output",
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
            "diff_summary": "Implemented a code change",
            "write_scope_result": {
                "within_scope": True,
                "violations": [],
                "forbidden_paths_touched": []
            },
            "test_evidence_refs": [f"state://runs/{run_id}/test-execution-report.json"],
            "risk_notes": [],
            "approval_refs": []
        },
        "conversation_context": []
    }
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/worker-outputs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 200, response.status
    body = json.loads(response.read().decode("utf-8"))
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$TMP_DIR/tasks-after.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, status_path, events_path, tasks_path = sys.argv[1:]
for url, path in (
    (f"{base_url}/orchestra/runs/{run_id}", status_path),
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0&limit=20", events_path),
    (f"{base_url}/orchestra/runs/{run_id}/tasks", tasks_path),
):
    with urllib.request.urlopen(url, timeout=5) as response:
        assert response.status == 200, response.status
        body = json.loads(response.read().decode("utf-8"))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/worker-output.json" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$TMP_DIR/tasks-after.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$RUN_ID" "$TASK_ID" "$KANBAN_REF" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

output_path, status_path, events_path, tasks_path, state_root, audit_root, project_id, run_id, task_id, kanban_ref, hermes_log = sys.argv[1:]
output = json.load(open(output_path, encoding="utf-8"))
status = json.load(open(status_path, encoding="utf-8"))
events = json.load(open(events_path, encoding="utf-8"))
tasks = json.load(open(tasks_path, encoding="utf-8"))

assert output["gate_result"] == "accepted", output
assert output["transition"] == "task_complete", output
assert output["task_id"] == task_id, output
assert output["worker_output_report_ref"].startswith(f"state://runs/{run_id}/worker-output-reports/"), output

assert status["status"] == "queued", status
assert status["blocked_reason"] is None, status
assert status["progress"]["completed_stages"] == 1, status
assert status["current_stage"] == "solution_debate", status

task = next(item for item in tasks["tasks"] if item["task_id"] == task_id)
assert task["status"] == "completed", tasks
assert output["worker_output_report_ref"] in task["artifact_refs"], task
assert all(item["status"] != "completed" for item in tasks["tasks"] if item["task_id"] != task_id), tasks

event_types = [event["type"] for event in events["events"]]
assert "task_completed" in event_types, event_types
assert "run_completed" not in event_types, event_types
completed_event = next(event for event in events["events"] if event["type"] == "task_completed")
assert completed_event["task_id"] == task_id, completed_event

report_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "worker-output-reports" / pathlib.Path(output["worker_output_report_ref"]).name
report = json.loads(report_path.read_text(encoding="utf-8"))
assert report["artifact_type"] == "worker_output_report", report
assert report["result"] == "accepted", report
assert report["requested_transition"] == "task_complete", report

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "worker_output_accepted" and record.get("command_id") == output["command_id"] for record in audit_records), audit_records
assert not any(record.get("type") == "run_completed" for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in calls if line.startswith("kanban create")]) == 7
complete_calls = [line for line in calls if line.startswith("kanban complete")]
assert complete_calls == [f"kanban complete --board {project_id} --task {kanban_ref}"], complete_calls
PY

test_done
