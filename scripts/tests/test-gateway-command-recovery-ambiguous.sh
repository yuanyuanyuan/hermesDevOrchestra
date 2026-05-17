#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-command-recovery-ambiguous"
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
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="gateway-recovery-ambiguous"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

python3 - "$STATE_ROOT" "$PROJECT_ID" <<'PY'
import json
import pathlib
import sys

state_root, project_id = sys.argv[1:]
run_id = "run-recovery-ambiguous"
command_id = "cmd-recovery-ambiguous"
run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
(run_dir / "commands").mkdir(parents=True, exist_ok=True)
now = "2026-05-17T00:00:00Z"
run = {
    "schema_version": "orchestra.v1",
    "run_id": run_id,
    "status": "queued",
    "project": project_id,
    "last_command_id": command_id,
    "source_run_id": None,
    "lineage_ref": None,
    "created_at": now,
    "updated_at": now,
    "current_stage": "direction_debate",
    "progress": {"completed_stages": 0, "total_stages": 6},
    "stages": [{"stage": stage, "status": "queued"} for stage in ["direction_debate", "solution_debate", "implementation", "improvement", "global_evaluation", "continuous_improvement"]],
    "blocked_reason": None,
    "failure_reason": None,
    "failure_report_ref": None,
    "failure_audit_ref": None,
    "last_good_checkpoint_ref": None,
    "lineage_hint_refs": [],
    "pending_decision_id": None,
    "pending_decision_refs": [],
    "resume_checkpoint_refs": [],
    "stopped_reason": None,
    "stop_audit_ref": None,
    "artifact_refs": {"command_record": f"state://runs/{run_id}/commands/{command_id}.json"}
}
command = {
    "schema_version": "orchestra.v1",
    "artifact_type": "command_record",
    "command_id": command_id,
    "idempotency_key": "gw-038-create",
    "project": project_id,
    "endpoint": "POST /orchestra/runs",
    "resource_path": "/orchestra/runs",
    "status": "in_progress",
    "payload_hash": "sha256-placeholder",
    "intent": "create_run",
    "planned_side_effects": ["write_run_state", "create_kanban_stage_tasks", "write_task_projection", "append_audit", "append_event_projection"],
    "steps": [{"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [f"state://runs/{run_id}/run.json"]}],
    "created_at": now,
    "updated_at": now
}
(run_dir / "run.json").write_text(json.dumps(run, indent=2) + "\n", encoding="utf-8")
(run_dir / "commands" / f"{command_id}.json").write_text(json.dumps(command, indent=2) + "\n", encoding="utf-8")
(pathlib.Path(state_root) / project_id / "orchestra-active-run.json").write_text(json.dumps({"schema_version": "orchestra.v1", "run_id": run_id, "status": "queued", "updated_at": now}) + "\n", encoding="utf-8")
PY

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

python3 - "$BASE_URL" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys
import urllib.request

base_url, state_root, audit_root, project_id, hermes_log = sys.argv[1:]
run_id = "run-recovery-ambiguous"
command_id = "cmd-recovery-ambiguous"
with urllib.request.urlopen(f"{base_url}/orchestra/runs/{run_id}", timeout=5) as response:
    assert response.status == 200, response.status
    status = json.loads(response.read().decode("utf-8"))
with urllib.request.urlopen(f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0&limit=20", timeout=5) as response:
    events = json.loads(response.read().decode("utf-8"))

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
command = json.loads((run_dir / "commands" / f"{command_id}.json").read_text(encoding="utf-8"))
report_ref = f"state://runs/{run_id}/command-reconciliation-reports/{command_id}.json"
report = json.loads((run_dir / "command-reconciliation-reports" / f"{command_id}.json").read_text(encoding="utf-8"))

assert status["status"] == "blocked", status
assert status["blocked_reason"] == "command_reconciliation_ambiguous", status
assert status["pending_decision_id"].startswith("decision-"), status
assert report_ref in status["pending_decision_refs"], status
assert command["status"] == "failed", command
assert command["recovery_action"] == "blocked_ambiguous", command
assert report["artifact_type"] == "command_reconciliation_report", report
assert report["recovery_result"] == "blocked_ambiguous", report
assert report["command_id"] == command_id, report

event_types = [event["type"] for event in events["events"]]
assert "decision_required" in event_types, events
decision_event = next(event for event in events["events"] if event["type"] == "decision_required")
assert decision_event["artifact_refs"] == [report_ref, f"state://runs/{run_id}/run.json"], decision_event

audit_path = pathlib.Path(audit_root) / project_id / "audit.jsonl"
audit_records = [json.loads(line) for line in audit_path.read_text(encoding="utf-8").splitlines() if line.strip()]
assert any(record.get("type") == "decision_required" and record.get("command_id") == command_id for record in audit_records), audit_records

log_path = pathlib.Path(hermes_log)
assert (log_path.read_text(encoding="utf-8") if log_path.exists() else "") == ""
PY

test_done
