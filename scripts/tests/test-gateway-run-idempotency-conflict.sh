#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-idempotency-conflict"
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

PROJECT_ID="gateway-conflict"
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

cat > "$TMP_DIR/first-payload.json" <<'JSON'
{
  "idempotency_key": "gw-003-conflict",
  "ticket": {
    "background": "Original command",
    "goal": "Create the original Six-Stage Run",
    "deliverables": ["Original result"],
    "acceptance_criteria": ["Original result is replayable"],
    "hard_constraints": ["Do not duplicate side effects"],
    "soft_constraints": [],
    "related_tasks": [],
    "failure_strategy": "Keep original evidence"
  },
  "options": {"mode": "mvp_full"}
}
JSON

cat > "$TMP_DIR/conflicting-payload.json" <<'JSON'
{
  "idempotency_key": "gw-003-conflict",
  "ticket": {
    "background": "Conflicting command",
    "goal": "Create a different Six-Stage Run under the same command identity",
    "deliverables": ["Conflicting result"],
    "acceptance_criteria": ["Gateway rejects conflicting reuse"],
    "hard_constraints": ["Do not duplicate side effects"],
    "soft_constraints": [],
    "related_tasks": [],
    "failure_strategy": "Return conflict"
  },
  "options": {"mode": "mvp_full"}
}
JSON

python3 - "$BASE_URL" "$TMP_DIR/first-payload.json" "$TMP_DIR/conflicting-payload.json" "$TMP_DIR/first.json" "$TMP_DIR/conflict.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, first_payload_path, conflict_payload_path, first_output_path, conflict_output_path = sys.argv[1:]

def post(payload_path):
    payload = open(payload_path, encoding="utf-8").read().encode("utf-8")
    request = urllib.request.Request(
        f"{base_url}/orchestra/runs",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))

first_status, first_body = post(first_payload_path)
conflict_status, conflict_body = post(conflict_payload_path)

assert first_status == 201, first_status
assert conflict_status == 409, f"expected conflict status 409, got {conflict_status}: {conflict_body}"

with open(first_output_path, "w", encoding="utf-8") as handle:
    json.dump(first_body, handle, indent=2)
    handle.write("\n")
with open(conflict_output_path, "w", encoding="utf-8") as handle:
    json.dump(conflict_body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/first.json" "$TMP_DIR/conflict.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

first_path, conflict_path, state_root, audit_root, project_id, hermes_log = sys.argv[1:]
first = json.load(open(first_path, encoding="utf-8"))
conflict = json.load(open(conflict_path, encoding="utf-8"))

assert conflict["schema_version"] == "orchestra.v1"
assert conflict["error"]["code"] == "idempotency_conflict"
assert first["idempotency_key"] == "gw-003-conflict"

run_root = pathlib.Path(state_root) / project_id / "runs"
run_dirs = [path for path in run_root.iterdir() if path.is_dir()]
assert [path.name for path in run_dirs] == [first["run_id"]]

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert len([record for record in audit_records if record.get("type") == "run_created"]) == 1

kanban_calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in kanban_calls if line.startswith("kanban create")]) == 7
PY

test_done
