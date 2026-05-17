#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-v1-proxy-degraded"
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

PROJECT_ID="gateway-v1"
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
UPSTREAM_PORT="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
BASE_URL="http://127.0.0.1:$PORT"
UPSTREAM_URL="http://127.0.0.1:$UPSTREAM_PORT"
GATEWAY_LOG="$TMP_DIR/gateway.log"
"$REPO_ROOT/scripts/bin/orch-gateway" --project-id "$PROJECT_ID" --host 127.0.0.1 --port "$PORT" --upstream-api-url "$UPSTREAM_URL" >"$GATEWAY_LOG" 2>&1 &
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

python3 - "$BASE_URL" "$TMP_DIR/health.json" "$TMP_DIR/v1.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, health_path, v1_path = sys.argv[1:]
with urllib.request.urlopen(f"{base_url}/health", timeout=5) as response:
    assert response.status == 200, response.status
    health = json.loads(response.read().decode("utf-8"))

try:
    with urllib.request.urlopen(f"{base_url}/v1/sessions", timeout=5) as response:
        v1_status = response.status
        v1_body = json.loads(response.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    v1_status = exc.code
    v1_body = json.loads(exc.read().decode("utf-8"))

assert health["upstream_api"] == "degraded", health
assert v1_status == 502, f"expected /v1 degraded 502, got {v1_status}: {v1_body}"
assert v1_body["schema_version"] == "orchestra.v1"
assert v1_body["error"]["code"] == "upstream_unavailable"

for path, body in ((health_path, health), (v1_path, v1_body)):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

test_done
