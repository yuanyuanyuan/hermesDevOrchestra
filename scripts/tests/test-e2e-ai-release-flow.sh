#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="e2e-ai-release-flow"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="e2e-ai-release"
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

python3 - "$BASE_URL" "$AUDIT_ROOT" "$PROJECT_ID" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

base_url, audit_root, project_id = sys.argv[1:4]

def post(path, payload, *, expected):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            body = json.loads(response.read().decode("utf-8"))
            status = response.status
    except urllib.error.HTTPError as exc:
        status = exc.code
        body = json.loads(exc.read().decode("utf-8"))
    assert status == expected, (path, status, body)
    return body

registry = post(
    "/orchestra/modules/release-pipeline/load-registry",
    {
        "authority": "gateway_local_runtime",
        "allow_staged": True,
    },
    expected=200,
)
registry_result = registry["result"]
assert registry_result["package_status"] == "staged_target", registry_result
assert registry_result["commands"], registry_result

plan_error = post(
    "/orchestra/modules/release-pipeline/plan",
    {
        "authority": "gateway_local_runtime",
        "allow_staged": True,
        "environment": "dev_test",
    },
    expected=400,
)
assert plan_error["error"]["code"] == "command_disabled", plan_error
assert "command://release/dev-test" in plan_error["error"]["message"], plan_error

execute_error = post(
    "/orchestra/modules/release-executor/execute",
    {
        "authority": "gateway_local_release_operator",
        "allow_staged": True,
        "command_ref": "command://release/dev-test",
        "run_id": "release-flow-run",
        "environment": "dev_test",
    },
    expected=400,
)
assert execute_error["error"]["code"] == "command_disabled", execute_error
assert "command://release/dev-test" in execute_error["error"]["message"], execute_error

# Verify audit trail has records
audit_path = os.path.join(audit_root, project_id, "audit.jsonl")
assert os.path.isfile(audit_path), f"audit trail missing: {audit_path}"
with open(audit_path, encoding="utf-8") as f:
    records = [json.loads(line) for line in f if line.strip()]
assert len(records) >= 1, f"audit trail empty: {audit_path}"
init_records = [r for r in records if r.get("type") == "project_init"]
assert len(init_records) >= 1, f"no project_init audit record: {records}"
PY

test_done
