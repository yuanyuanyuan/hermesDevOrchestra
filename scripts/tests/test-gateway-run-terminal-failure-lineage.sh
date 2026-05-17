#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-terminal-failure-lineage"
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

PROJECT_ID="gateway-terminal-failure"
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
        "idempotency_key": "gw-048-create",
        "ticket": {
            "background": "Terminal failed run evidence",
            "goal": "Fail only when authority chain is unrecoverable",
            "deliverables": ["Failed run", "Lineage source evidence"],
            "acceptance_criteria": ["run_failed evidence exists"],
            "hard_constraints": ["Do not delete source evidence"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Create lineage run after terminal failure"
        },
        "options": {"mode": "mvp_full"}
    },
    expected=201,
)
run_id = create["run_id"]
failure_report = {
    "schema_version": "orchestra.v1",
    "artifact_type": "run_failure_report",
    "run_id": run_id,
    "failure_class": "authority_chain_corrupt",
    "terminal_failure_reason": "authority_chain_corrupt",
    "failed_stage": "implementation",
    "failed_task_id": f"{run_id}-implementation",
    "authority_chain_assessment": {
        "state_trusted": False,
        "audit_trusted": True,
        "kanban_trusted": True,
        "artifact_refs_trusted": False
    },
    "unrecoverable_artifact_refs": [f"state://runs/{run_id}/corrupt-artifact.json"],
    "unauthorized_write_refs": [],
    "invariant_violation_refs": [f"state://runs/{run_id}/run.json"],
    "last_good_checkpoint_ref": f"state://runs/{run_id}/run.json",
    "preserved_state_refs": [f"state://runs/{run_id}/run.json"],
    "preserved_audit_refs": [],
    "preserved_kanban_refs": [f"state://runs/{run_id}/tasks.json"],
    "preserved_artifact_refs": [f"state://runs/{run_id}/structured_prd.json"],
    "lineage_hint_refs": [f"state://runs/{run_id}/run_failure_report.json"],
    "run_failed_event_ref": None,
    "created_at": "2026-05-17T00:00:00Z"
}
failed = post(
    f"/orchestra/runs/{run_id}/failures",
    {"idempotency_key": "gw-048-fail", "failure_report": failure_report},
)
status = get(f"/orchestra/runs/{run_id}")
events = get(f"/orchestra/runs/{run_id}/events?since_seq=0&limit=50")
lineage = post(
    "/orchestra/runs",
    {
        "idempotency_key": "gw-048-lineage",
        "source_run_id": run_id,
        "resume_from_refs": [failed["run_failure_report_ref"]],
        "ticket": {
            "background": "Continue from terminal failed source",
            "goal": "Create lineage run without mutating failed source",
            "deliverables": ["New run"],
            "acceptance_criteria": ["Lineage source is preserved"],
            "hard_constraints": ["Do not mutate source run"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Block if source evidence is missing"
        },
        "options": {"mode": "mvp_full"}
    },
    expected=201,
)
with open(flow_path, "w", encoding="utf-8") as handle:
    json.dump({"failed": failed, "status": status, "events": events, "lineage": lineage, "run_id": run_id}, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/flow.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" <<'PY'
import json
import pathlib
import sys

flow_path, state_root, audit_root, project_id = sys.argv[1:]
flow = json.load(open(flow_path, encoding="utf-8"))
run_id = flow["run_id"]
failed = flow["failed"]
status = flow["status"]
events = flow["events"]["events"]
lineage = flow["lineage"]
run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id

assert failed["status"] == "failed", failed
assert failed["run_failure_report_ref"] == f"state://runs/{run_id}/run_failure_report.json", failed
assert status["status"] == "failed", status
assert status["failure_reason"] == "authority_chain_corrupt", status
assert status["failure_report_ref"] == failed["run_failure_report_ref"], status
assert status["lineage_hint_refs"] == [failed["run_failure_report_ref"]], status
assert (run_dir / "run_failure_report.json").is_file()

event_types = [event["type"] for event in events]
assert "run_failed" in event_types, event_types
failed_event = next(event for event in events if event["type"] == "run_failed")
assert failed_event["artifact_refs"][0] == failed["run_failure_report_ref"], failed_event

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "run_failed" and record.get("run_id") == run_id for record in audit_records), audit_records

assert lineage["source_run_id"] == run_id, lineage
assert lineage["lineage_ref"].startswith(f"state://runs/{lineage['run_id']}/lineage.json"), lineage
source_after = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
assert source_after["status"] == "failed", source_after
PY

test_done
