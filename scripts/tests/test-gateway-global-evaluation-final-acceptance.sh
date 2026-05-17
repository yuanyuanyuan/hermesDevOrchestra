#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-global-evaluation-final-acceptance"
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

PROJECT_ID="gateway-global-accept"
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
    "idempotency_key": "gw-030-create",
    "ticket": {
        "background": "Final acceptance routing test",
        "goal": "Proceed to Stage 6 after Kimi accepts warnings",
        "deliverables": ["Stage 6 queued"],
        "acceptance_criteria": ["Final acceptance does not complete the run by itself"],
        "hard_constraints": ["Closeout gate still required"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Block until final acceptance"
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
    "verdict": "pass_with_warnings",
    "warnings": [{"warning_id": "W-001", "summary": "Residual warning"}],
    "residual_risks": ["Residual warning accepted by Kimi"],
    "blocking_issues": [],
    "authority_required": "kimi",
    "final_acceptance_ref": None,
    "next_actions": ["Request final acceptance"],
    "created_at": "2026-05-17T00:00:00Z"
}
payload = {"idempotency_key": "gw-030-global-evaluation", "report": report}
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

DECISION_ID="$(python3 - "$TMP_DIR/global-response.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["decision_id"])
PY
)"
REPORT_REF="$(python3 - "$TMP_DIR/global-response.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["global_evaluation_report_ref"])
PY
)"

python3 - "$BASE_URL" "$DECISION_ID" "$REPORT_REF" "$TMP_DIR/decision-response.json" <<'PY'
import json
import sys
import urllib.request

base_url, decision_id, report_ref, response_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-030-final-acceptance",
    "action": "approve",
    "actor": "kimi",
    "rationale": "Warnings are acceptable for MVP closeout",
    "accepted_warning_refs": [report_ref]
}
request = urllib.request.Request(
    f"{base_url}/orchestra/decisions/{decision_id}",
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

python3 - "$TMP_DIR/decision-response.json" "$TMP_DIR/status.json" "$TMP_DIR/events.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$RUN_ID" "$REPORT_REF" <<'PY'
import json
import pathlib
import sys

response_path, status_path, events_path, state_root, audit_root, project_id, run_id, report_ref = sys.argv[1:]
response = json.load(open(response_path, encoding="utf-8"))
status = json.load(open(status_path, encoding="utf-8"))
events = json.load(open(events_path, encoding="utf-8"))

assert response["route_result"] == "stage6_queued", response
assert response["status"] == "queued", response
assert response["final_acceptance_ref"] == f"state://runs/{run_id}/final_acceptance.json", response

assert status["status"] == "queued", status
assert status["current_stage"] == "continuous_improvement", status
assert status["blocked_reason"] is None, status
assert status["pending_decision_id"] is None, status
assert status["pending_decision_refs"] == [], status
assert status["artifact_refs"]["final_acceptance"] == response["final_acceptance_ref"], status
assert status["artifact_refs"]["global_evaluation_report"] == report_ref, status

event_types = [event["type"] for event in events["events"]]
assert "decision_resolved" in event_types, event_types
assert "stage_started" in event_types, event_types
assert "run_completed" not in event_types, event_types

acceptance_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "final_acceptance.json"
acceptance = json.loads(acceptance_path.read_text(encoding="utf-8"))
assert acceptance["artifact_type"] == "final_acceptance", acceptance
assert acceptance["accepted_by"] == "kimi", acceptance
assert acceptance["global_evaluation_report_ref"] == report_ref, acceptance

report_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "global_evaluation_report.json"
report = json.loads(report_path.read_text(encoding="utf-8"))
assert report["final_acceptance_ref"] == response["final_acceptance_ref"], report

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "decision_resolved" and record.get("decision_id") == response["decision_id"] for record in audit_records), audit_records
assert not any(record.get("type") == "run_completed" for record in audit_records), audit_records
PY

test_done
