#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-review-verdict-reject-blocks"
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
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "block" ]; then
  printf '{"status":"blocked"}\n'
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

PROJECT_ID="gateway-review-reject"
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
    "idempotency_key": "gw-043-create",
    "ticket": {
        "background": "Review reject test",
        "goal": "Route rejected review verdict to a blocked decision",
        "deliverables": ["Review rejection evidence"],
        "acceptance_criteria": ["reject does not queue improvement or completion"],
        "hard_constraints": ["Rejected review output needs explicit decision"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Block for Kimi decision"
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
print(next(item["task_id"] for item in tasks if item["stage"] == "implementation"))
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TASK_ID" "$TMP_DIR/verdict-response.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, task_id, response_path = sys.argv[1:]
verdict = {
    "schema_version": "orchestra.v1",
    "artifact_type": "review_report",
    "run_id": run_id,
    "task_id": task_id,
    "stage": "implementation",
    "review_kind": "code_review",
    "verdict": "reject",
    "findings": [{"finding_id": "R-001", "summary": "Implementation does not satisfy approved acceptance criteria"}],
    "affected_acceptance_criteria_refs": ["AC-001"],
    "required_fixes": [],
    "evidence_refs": [f"state://runs/{run_id}/run.json"],
    "within_approved_scope": False,
    "risk_level": "medium",
    "authority_required": "kimi",
    "improvement_cycle": 0,
    "supersedes_ref": None
}
payload = {
    "idempotency_key": "gw-043-verdict",
    "task_id": task_id,
    "verdict": verdict
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/verdicts",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 200, response.status
    body = json.loads(response.read().decode("utf-8"))
with open(response_path, "w", encoding="utf-8") as handle:
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

python3 - "$TMP_DIR/verdict-response.json" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$TMP_DIR/tasks-after.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$RUN_ID" "$TASK_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

response_path, status_path, events_path, tasks_path, state_root, audit_root, project_id, run_id, task_id, hermes_log = sys.argv[1:]
response = json.load(open(response_path, encoding="utf-8"))
status = json.load(open(status_path, encoding="utf-8"))
events = json.load(open(events_path, encoding="utf-8"))
tasks = json.load(open(tasks_path, encoding="utf-8"))

assert response["route_result"] == "decision_required", response
assert response["failure_class"] == "review_rejected", response
assert response["authority_required"] == "kimi", response
assert response["decision_id"].startswith("decision-"), response
assert response["verdict_ref"].startswith(f"state://runs/{run_id}/review-verdicts/"), response

assert status["status"] == "blocked", status
assert status["blocked_reason"] == "review_rejected", status
assert status["pending_decision_id"] == response["decision_id"], status
assert response["verdict_ref"] in status["pending_decision_refs"], status
assert response["verdict_ref"] in status["artifact_refs"]["review_verdict_refs"], status

task = next(item for item in tasks["tasks"] if item["task_id"] == task_id)
assert task["status"] == "blocked", task
assert task["blocked_reason"] == "review_rejected", task
assert response["verdict_ref"] in task["artifact_refs"], task

event_types = [event["type"] for event in events["events"]]
assert "artifact_written" in event_types, event_types
assert "decision_required" in event_types, event_types
assert "stage_started" not in event_types, event_types
assert "run_completed" not in event_types, event_types

verdict_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "review-verdicts" / pathlib.Path(response["verdict_ref"]).name
verdict = json.loads(verdict_path.read_text(encoding="utf-8"))
assert verdict["verdict"] == "reject", verdict
assert verdict["decision_id"] == response["decision_id"], verdict

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "review_verdict_recorded" and record.get("decision") == "REJECTED" and record.get("failure_class") == "review_rejected" for record in audit_records), audit_records
assert any(record.get("type") == "decision_required" and record.get("approval_id") == response["decision_id"] for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert any("kanban block" in line and "review_rejected" in line for line in calls), calls
PY

test_done
