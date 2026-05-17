#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-events-pagination"
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

PROJECT_ID="gateway-events"
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
payload = {"idempotency_key": "gw-013-create", "intent": "fix flaky login", "options": {"mode": "mvp_full"}}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 201, response.status
    print(json.loads(response.read().decode("utf-8"))["run_id"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/page1.json" "$TMP_DIR/page2.json" <<'PY'
import json
import sys
import urllib.request

base_url, run_id, page1_path, page2_path = sys.argv[1:]
for url, path in (
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=0&limit=1", page1_path),
    (f"{base_url}/orchestra/runs/{run_id}/events?since_seq=1&limit=2", page2_path),
):
    with urllib.request.urlopen(url, timeout=5) as response:
        assert response.status == 200, response.status
        data = json.loads(response.read().decode("utf-8"))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/page1.json" "$TMP_DIR/page2.json" "$RUN_ID" <<'PY'
import json
import sys

page1_path, page2_path, run_id = sys.argv[1:]
page1 = json.load(open(page1_path, encoding="utf-8"))
page2 = json.load(open(page2_path, encoding="utf-8"))

assert page1["run_id"] == run_id
assert [event["seq"] for event in page1["events"]] == [1]
assert page1["has_more"] is True
assert page1["next_seq"] == 2, page1

assert [event["seq"] for event in page2["events"]] == [2, 3]
assert page2["has_more"] is False
assert page2["next_seq"] == 4, page2
assert [event["type"] for event in page2["events"]] == ["ticket_normalized", "decision_required"]
PY

test_done
