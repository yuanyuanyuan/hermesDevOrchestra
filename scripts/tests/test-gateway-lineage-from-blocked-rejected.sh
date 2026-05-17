#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-lineage-from-blocked-rejected"
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

PROJECT_ID="gateway-blocked-lineage"
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

SOURCE_RUN_ID="$(python3 - "$BASE_URL" <<'PY'
import json
import sys
import urllib.request

base_url = sys.argv[1]
payload = {
    "idempotency_key": "gw-010-blocked-source",
    "intent": "continue this later",
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
    body = json.loads(response.read().decode("utf-8"))
assert body["status"] == "blocked", body
print(body["run_id"])
PY
)"

python3 - "$BASE_URL" "$SOURCE_RUN_ID" "$TMP_DIR/conflict.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, source_run_id, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-010-lineage-from-blocked",
    "source_run_id": source_run_id,
    "resume_from_refs": [f"state://runs/{source_run_id}/run.json"],
    "ticket": {
        "background": "Attempt to continue from blocked intake source",
        "goal": "Create a lineage run from blocked source",
        "deliverables": ["Rejection"],
        "acceptance_criteria": ["Blocked source recovers in place"],
        "hard_constraints": ["Do not fork active blocked evidence"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Reject lineage and keep decision pending"
    },
    "options": {"mode": "mvp_full"}
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(request, timeout=5) as response:
        status = response.status
        body = json.loads(response.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    status = exc.code
    body = json.loads(exc.read().decode("utf-8"))

assert status == 409, f"expected blocked-source lineage conflict, got {status}: {body}"
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/conflict.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$SOURCE_RUN_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

conflict_path, state_root, audit_root, project_id, source_run_id, hermes_log = sys.argv[1:]
conflict = json.load(open(conflict_path, encoding="utf-8"))
assert conflict["schema_version"] == "orchestra.v1"
assert conflict["error"]["code"] == "lineage_source_not_terminal", conflict
assert conflict["source_run_id"] == source_run_id, conflict
assert conflict["source_status"] == "blocked", conflict
assert conflict["recovery_mode"] == "decision_in_place", conflict

project_state = pathlib.Path(state_root) / project_id
run_root = project_state / "runs"
run_ids = sorted(path.name for path in run_root.iterdir() if path.is_dir())
assert run_ids == [source_run_id], run_ids

commands = sorted((run_root / source_run_id / "commands").glob("*.json"))
assert len(commands) == 1, commands

idempotency_records = sorted((project_state / "idempotency").glob("*.json"))
assert len(idempotency_records) == 1, idempotency_records

source_run = json.loads((run_root / source_run_id / "run.json").read_text(encoding="utf-8"))
assert source_run["status"] == "blocked", source_run
assert source_run["pending_decision_id"], source_run

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert not any(record.get("type") == "run_lineage_created" for record in audit_records)

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8") if pathlib.Path(hermes_log).exists() else ""
assert "kanban create" not in calls
PY

test_done
