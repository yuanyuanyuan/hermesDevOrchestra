#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-conflict-ledger-blocks-advancement"
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

PROJECT_ID="gateway-conflict-ledger"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

python3 - "$REPO_ROOT" "$PROJECT_ID" "$STATE_ROOT" "$AUDIT_ROOT" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

repo_root, project_id, state_root, audit_root, hermes_log = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from orch_gateway import GatewayApp, read_json, write_json  # noqa: E402

app = GatewayApp(project_id, "http://127.0.0.1:9")
status, created = app.create_run(
    {
        "idempotency_key": "gw-conflict-create",
        "ticket": {
            "background": "Conflict Ledger gate test",
            "goal": "Block advancement while high severity conflict is open",
            "deliverables": ["Blocked worker output"],
            "acceptance_criteria": ["Open high conflict blocks stage advancement"],
            "hard_constraints": ["Conflict Ledger is authoritative"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Block until conflict is resolved",
        },
        "options": {"mode": "mvp_full"},
    }
)
assert status == 201, (status, created)
run_id = created["run_id"]
tasks = read_json(app.store.tasks_path(run_id))
task_id = tasks["tasks"][0]["task_id"]

ledger = {
    "schema_version": "orchestra.v1",
    "artifact_type": "conflict_ledger",
    "run_id": run_id,
    "conflicts": [
        {
            "conflict_id": "conflict-high-open",
            "run_id": run_id,
            "stage": "direction_debate",
            "type": "cross_team_conflict",
            "sources": ["state://runs/%s/requirement-completion-bundle.json" % run_id],
            "severity": "high",
            "resolution": "open",
            "resolver": "",
            "resolution_evidence": "",
            "created_at": "2026-06-04T00:00:00Z",
            "resolved_at": None,
        }
    ],
}
write_json(app.store.conflict_ledger_path(run_id), ledger)

status, output = app.submit_worker_output(
    run_id,
    {
        "idempotency_key": "gw-conflict-worker-output",
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
                    "forbidden_paths_touched": [],
                },
                "test_evidence_refs": [f"state://runs/{run_id}/test-execution-report.json"],
                "risk_notes": [],
                "approval_refs": [],
            },
            "conversation_context": [],
        },
    },
)
assert status == 200, (status, output)
assert output["gate_result"] == "blocked", output
assert output["failure_class"] == "open_conflict", output
assert output["open_conflict_refs"] == ["conflict-high-open"], output

run = read_json(app.store.run_path(run_id))
assert run["status"] == "blocked", run
assert run["blocked_reason"] == "open_high_conflict", run
assert run["current_stage"] == "direction_debate", run
assert run["progress"]["completed_stages"] == 0, run

tasks_after = read_json(app.store.tasks_path(run_id))
task = next(item for item in tasks_after["tasks"] if item["task_id"] == task_id)
assert task["status"] == "blocked", task
assert task["blocked_reason"] == "open_high_conflict", task

report_path = pathlib.Path(state_root) / project_id / "runs" / run_id / "worker-output-validation-reports" / pathlib.Path(output["validation_report_ref"]).name
report = json.loads(report_path.read_text(encoding="utf-8"))
assert report["failure_class"] == "open_conflict", report
assert "conflict-high-open" in report["violations"], report

events = [
    json.loads(line)
    for line in app.store.events_path(run_id).read_text(encoding="utf-8").splitlines()
    if line.strip()
]
event_types = [event["type"] for event in events]
assert "worker_output_blocked" in event_types, event_types
assert "task_completed" not in event_types, event_types

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "worker_output_blocked" and record.get("failure_class") == "open_conflict" for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in calls if line.startswith("kanban create")]) == 7
assert not any(line.startswith("kanban complete") for line in calls), calls
PY

test_done
