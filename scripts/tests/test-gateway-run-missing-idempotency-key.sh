#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-missing-idempotency-key"
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

PROJECT_ID="gateway-missing-idempotency"
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

python3 - "$BASE_URL" "$TMP_DIR/response.json" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

base_url, response_path, hermes_log = sys.argv[1:]
log_path = pathlib.Path(hermes_log)
before_calls = log_path.read_text(encoding="utf-8").splitlines() if log_path.exists() else []
payload = {
    "ticket": {
        "background": "Missing idempotency test",
        "goal": "Reject mutating run create without idempotency key",
        "deliverables": ["Validation error"],
        "acceptance_criteria": ["No side effects occur"],
        "hard_constraints": ["Command journal must not be written"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Return validation failure"
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
        body = json.loads(response.read().decode("utf-8"))
        body["http_status"] = response.status
except urllib.error.HTTPError as error:
    body = json.loads(error.read().decode("utf-8"))
    body["http_status"] = error.code
after_calls = log_path.read_text(encoding="utf-8").splitlines() if log_path.exists() else []
body["hermes_call_count_before"] = len(before_calls)
body["hermes_call_count_after"] = len(after_calls)
with open(response_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/response.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

response_path, state_root, audit_root, project_id, hermes_log = sys.argv[1:]
response = json.load(open(response_path, encoding="utf-8"))
project_state = pathlib.Path(state_root) / project_id
project_audit = pathlib.Path(audit_root) / project_id

assert response["http_status"] == 400, response
assert response["error"]["code"] == "validation_error", response
assert "idempotency_key" in response["error"]["message"], response

assert not (project_state / "orchestra-active-run.json").exists()
runs_dir = project_state / "runs"
assert not any(runs_dir.iterdir()) if runs_dir.exists() else True
idempotency_dir = project_state / "idempotency"
assert not any(idempotency_dir.iterdir()) if idempotency_dir.exists() else True
audit_path = project_audit / "audit.jsonl"
audit_records = [json.loads(line) for line in audit_path.read_text(encoding="utf-8").splitlines() if line.strip()] if audit_path.exists() else []
assert not any(record.get("type") == "run_created" or record.get("command_id") for record in audit_records), audit_records

assert response["hermes_call_count_after"] == response["hermes_call_count_before"], response
PY

test_done
