#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-ai-negative-cases"
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

PROJECT_ID="gateway-ai-negative"
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
deadline = time.time() + 30
last_error = None
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=0.5) as response:
            if response.status == 200:
                time.sleep(0.5)
                raise SystemExit(0)
    except Exception as exc:
        last_error = exc
        time.sleep(0.1)

print(open(log_path, encoding="utf-8", errors="replace").read(), file=sys.stderr)
raise SystemExit(f"gateway did not become healthy: {last_error}")
PY

python3 - "$BASE_URL" "$STATE_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

base_url, state_root, project_id, hermes_log = sys.argv[1:]

def post(path, payload, *, expected=None):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            body = json.loads(response.read().decode("utf-8"))
            status = response.status
    except urllib.error.HTTPError as exc:
        status = exc.code
        body = json.loads(exc.read().decode("utf-8"))
    if expected is not None:
        assert status == expected, (path, status, body)
    return status, body

def get(path, *, expected=None):
    try:
        with urllib.request.urlopen(f"{base_url}{path}", timeout=5) as response:
            body = json.loads(response.read().decode("utf-8"))
            status = response.status
    except urllib.error.HTTPError as exc:
        status = exc.code
        body = json.loads(exc.read().decode("utf-8"))
    if expected is not None:
        assert status == expected, (path, status, body)
    return status, body

malformed_status, malformed_body = post("/orchestra/runs", {}, expected=400)
assert malformed_body["error"]["code"] == "validation_error", malformed_body

request_payload = {
    "idempotency_key": "gw-ai-neg-duplicate",
    "ticket": {
        "background": "Negative Gateway AI contract test",
        "goal": "Exercise deterministic idempotency and validation failures",
        "deliverables": ["One queued run"],
        "acceptance_criteria": ["Replay is deterministic", "Conflicts are rejected"],
        "hard_constraints": ["Use public run entrypoint"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Reject invalid payloads"
    },
    "options": {"mode": "mvp_full"}
}
first_status, first_body = post("/orchestra/runs", request_payload, expected=201)
second_status, second_body = post("/orchestra/runs", request_payload, expected=201)
assert first_status == second_status == 201
assert first_body["run_id"] == second_body["run_id"], (first_body, second_body)
assert first_body["command_id"] == second_body["command_id"], (first_body, second_body)

conflicting_payload = {
    "idempotency_key": "gw-ai-neg-duplicate",
    "ticket": {
        "background": "Negative Gateway AI contract test",
        "goal": "Mutated payload should conflict",
        "deliverables": ["Conflict response"],
        "acceptance_criteria": ["Payload hash mismatch returns 409"],
        "hard_constraints": ["Do not create a second run"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Reject reused idempotency key with changed payload"
    },
    "options": {"mode": "mvp_full"}
}
conflict_status, conflict_body = post("/orchestra/runs", conflicting_payload, expected=409)
assert conflict_body["error"]["code"] == "idempotency_conflict", conflict_body
assert conflict_body["existing_run_id"] == first_body["run_id"], conflict_body
assert conflict_body["existing_command_id"] == first_body["command_id"], conflict_body

unknown_status, unknown_body = get("/orchestra/runs/run-does-not-exist", expected=404)
assert unknown_body["error"]["code"] == "not_found", unknown_body

unauthorized_status, unauthorized_body = post(
    "/orchestra/modules/release-pipeline/plan",
    {
        "authority": "untrusted_actor",
        "allow_staged": True,
        "environment": "dev_test",
    },
    expected=403,
)
assert unauthorized_body["error"]["code"] == "authority_required", unauthorized_body

run_root = pathlib.Path(state_root) / project_id / "runs"
run_ids = sorted(path.name for path in run_root.iterdir() if path.is_dir())
assert run_ids == [first_body["run_id"]], run_ids

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
create_calls = [line for line in calls if line.startswith("kanban create")]
assert len(create_calls) == 7, create_calls
PY

test_done
