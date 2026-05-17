#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-global-evaluation-block-human-approval"
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
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="gateway-global-block-human"
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

python3 - "$BASE_URL" "$TMP_DIR/create.json" <<'PY'
import json
import sys
import urllib.request

base_url, create_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-040-create",
    "ticket": {
        "background": "Global evaluation block test",
        "goal": "Block Stage 5 on a human approval boundary",
        "deliverables": ["Human approval decision evidence"],
        "acceptance_criteria": ["block verdict does not enter Stage 6"],
        "hard_constraints": ["Human approval cannot be bypassed by Kimi"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Block for human approval"
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
with open(create_path, "w", encoding="utf-8") as handle:
    json.dump(create, handle, indent=2)
    handle.write("\n")
PY

RUN_ID="$(python3 - "$TMP_DIR/create.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["run_id"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/global-response.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, response_path = sys.argv[1:]
report = {
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
    "test_execution_refs": [],
    "improvement_report_refs": [],
    "downgrade_refs": [],
    "unresolved_decision_refs": [],
    "audit_refs": [],
    "verdict": "block",
    "warnings": [],
    "residual_risks": ["L3 permission boundary remains unresolved"],
    "blocking_issues": [{"issue_id": "GE-BLOCK-001", "summary": "Human approval boundary"}],
    "authority_required": "human",
    "final_acceptance_ref": None,
    "next_actions": ["Request human approval"],
    "created_at": "2026-05-17T00:00:00Z"
}
payload = {"idempotency_key": "gw-040-global-evaluation", "report": report}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/global-evaluations",
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

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/status.json" "$TMP_DIR/events.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, status_path, events_path = sys.argv[1:]
for url, path in (
    (f"{base_url}/orchestra/runs/{run_id}", status_path),
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0&limit=20", events_path),
):
    with urllib.request.urlopen(url, timeout=5) as response:
        assert response.status == 200, response.status
        body = json.loads(response.read().decode("utf-8"))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/global-response.json" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$RUN_ID" <<'PY'
import json
import pathlib
import sys

response_path, status_path, events_path, state_root, audit_root, project_id, run_id = sys.argv[1:]
response = json.load(open(response_path, encoding="utf-8"))
status = json.load(open(status_path, encoding="utf-8"))
events = json.load(open(events_path, encoding="utf-8"))

assert response["route_result"] == "decision_required", response
assert response["blocked_reason"] == "global_evaluation_blocked", response
assert response["authority_required"] == "human", response
assert response["decision_id"].startswith("decision-"), response
assert response["global_evaluation_report_ref"] == f"state://runs/{run_id}/global_evaluation_report.json", response

assert status["status"] == "blocked", status
assert status["current_stage"] == "global_evaluation", status
assert status["blocked_reason"] == "global_evaluation_blocked", status
assert status["pending_decision_id"] == response["decision_id"], status
assert response["global_evaluation_report_ref"] in status["pending_decision_refs"], status
assert status["artifact_refs"]["global_evaluation_report"] == response["global_evaluation_report_ref"], status

event_types = [event["type"] for event in events["events"]]
assert "artifact_written" in event_types, event_types
assert "decision_required" in event_types, event_types
assert "stage_started" not in event_types, event_types
assert "run_completed" not in event_types, event_types

report_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "global_evaluation_report.json"
report = json.loads(report_path.read_text(encoding="utf-8"))
assert report["artifact_type"] == "global_evaluation_report", report
assert report["verdict"] == "block", report
assert report["decision_id"] == response["decision_id"], report

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "global_evaluation_recorded" and record.get("decision") == "BLOCK" for record in audit_records), audit_records
assert any(record.get("type") == "decision_required" and record.get("approval_id") == response["decision_id"] and record.get("authority_required") == "human" for record in audit_records), audit_records
assert not any(record.get("type") == "run_completed" for record in audit_records), audit_records
PY

test_done
