#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-closeout-forbidden-proposal"
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
  printf '{"id":"kanban-fixed","status":"created"}\n'
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

PROJECT_ID="gateway-closeout-forbidden"
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
    "idempotency_key": "gw-036-create",
    "ticket": {
        "background": "Forbidden proposal test",
        "goal": "Prevent automatic root rule edits",
        "deliverables": ["Completion blocker"],
        "acceptance_criteria": ["Root rule proposals are not auto-applied"],
        "hard_constraints": ["Only .workflow/knowledge/* may auto-apply"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Block completion gate"
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

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/closeout-response.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, run_id, response_path = sys.argv[1:]
proposals_ref = f"state://runs/{run_id}/system_improvement_proposals.json"
payload = {
    "idempotency_key": "gw-036-closeout",
    "iteration_closeout_report": {
        "schema_version": "orchestra.v1",
        "artifact_type": "iteration_closeout_report",
        "run_id": run_id,
        "global_evaluation_report_ref": f"state://runs/{run_id}/global_evaluation_report.json",
        "closeout_kind": "completed",
        "final_acceptance": {"accepted_by": "kimi", "authority": "kimi", "verdict": "pass", "rationale": "", "decision_ref": None},
        "accepted_warning_refs": [],
        "downgrade_records": [],
        "unresolved_decisions": [],
        "pending_decision_refs": [],
        "deferred_decisions": [],
        "completed_stage_refs": [],
        "incomplete_stage_refs": [],
        "stop_request_ref": None,
        "run_stopped_event_ref": None,
        "preserved_artifact_refs": [],
        "resume_checkpoint_refs": [],
        "worker_cancel_marker_refs": [],
        "test_execution_refs": [],
        "review_verdict_refs": [],
        "qa_verdict_refs": [],
        "worker_fallbacks": [],
        "knowledge_updates": {"auto_applied_refs": ["repo://AGENTS.md"], "proposal_refs": [], "forbidden_target_refs": []},
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
        "proposals": [
            {
                "proposal_id": "P-001",
                "target": "AGENTS.md",
                "summary": "Change root agent rules",
                "rationale": "Would be unsafe to auto-apply",
                "risk_level": "high",
                "authority_required": "human",
                "artifact_refs": [],
                "status": "auto_applied_low_risk"
            }
        ],
        "auto_applied_refs": ["repo://AGENTS.md"],
        "proposed_patch_refs": [],
        "approval_required": [],
        "decision_refs": [],
        "final_acceptance_ref": None,
        "downgrade_refs": [],
        "worker_fallback_refs": [],
        "knowledge_update_refs": []
    }
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/closeout",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    urllib.request.urlopen(request, timeout=5)
except urllib.error.HTTPError as exc:
    status = exc.code
    body = json.loads(exc.read().decode("utf-8"))
else:
    raise AssertionError("forbidden proposal unexpectedly completed")
assert status == 400, (status, body)
with open(response_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/closeout-response.json" "$BASE_URL" "$RUN_ID" <<'PY'
import json
import sys
import urllib.request

response = json.load(open(sys.argv[1], encoding="utf-8"))
base_url, run_id = sys.argv[2:]
with urllib.request.urlopen(f"{base_url}/orchestra/runs/{run_id}", timeout=5) as http_response:
    status = json.loads(http_response.read().decode("utf-8"))

assert response["error"]["code"] == "closeout_validation_failed", response
assert "system_improvement_proposals.forbidden_auto_apply" in response["completion_blockers"], response
assert status["status"] == "queued", status
assert status["artifact_refs"].get("iteration_closeout_report") is None, status
PY

test_done
