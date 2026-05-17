#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-events-sse"
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
  printf '{"id":"kanban-task","status":"created"}\n'
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

PROJECT_ID="gateway-sse"
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

RUN_ID="$(python3 - "$BASE_URL" <<'PY'
import json
import sys
import urllib.request

base_url = sys.argv[1]
payload = {"idempotency_key": "gw-017-create", "intent": "fix flaky login", "options": {"mode": "mvp_full"}}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    print(json.loads(response.read().decode("utf-8"))["run_id"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/sse.txt" <<'PY'
import sys
import urllib.request

base_url, run_id, output_path = sys.argv[1:]
request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/events?since_seq=1",
    headers={"Accept": "text/event-stream"},
)
with urllib.request.urlopen(request, timeout=5) as response:
    content_type = response.headers.get("Content-Type", "")
    body = response.read().decode("utf-8")
assert response.status == 200, response.status
assert content_type.startswith("text/event-stream"), content_type
with open(output_path, "w", encoding="utf-8") as handle:
    handle.write(body)
PY

assert_contains "id: 2" "$TMP_DIR/sse.txt" "SSE missing resumed seq 2"
assert_contains "event: ticket_normalized" "$TMP_DIR/sse.txt" "SSE missing event type"
assert_contains "id: 3" "$TMP_DIR/sse.txt" "SSE missing resumed seq 3"
assert_contains "event: decision_required" "$TMP_DIR/sse.txt" "SSE missing decision event"
assert_contains "data: " "$TMP_DIR/sse.txt" "SSE missing data payload"

test_done
