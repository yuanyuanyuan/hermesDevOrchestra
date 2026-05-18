#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-capabilities-authority-layers"
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
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="gateway-capabilities"
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

python3 - "$BASE_URL" "$TMP_DIR/capabilities.json" <<'PY'
import json
import sys
import urllib.request

base_url, out_path = sys.argv[1:]
with urllib.request.urlopen(f"{base_url}/orchestra/capabilities", timeout=5) as response:
    assert response.status == 200, response.status
    body = json.loads(response.read().decode("utf-8"))
with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(body, handle, indent=2)
    handle.write("\n")
PY

python3 - "$TMP_DIR/capabilities.json" "$CACHE_ROOT" <<'PY'
import json
import sys

capabilities_path, cache_root = sys.argv[1:]
body = json.load(open(capabilities_path, encoding="utf-8"))

assert body["schema_version"] == "orchestra.v1", body
assert body["gateway"]["project"], body
assert body["kanban"]["backend"] == "official_hermes_kanban", body
assert body["authority_model"]["phase"] == "phase_1", body["authority_model"]
assert body["authority_model"]["trust_boundary"] == "localhost_only", body["authority_model"]
assert body["authority_model"]["authentication"] == "none", body["authority_model"]
assert body["authority_model"]["authority_field_is_advisory_within_loopback"] is True, body["authority_model"]

cache = body["cache"]
assert cache["backend"] == "local_filesystem", cache
assert cache["available"] is True, cache
assert cache["root"] == cache_root, cache
assert cache["degraded"] is False, cache
assert cache["fallback_backend"] is None, cache

workers = body["workers"]
assert workers["default_pairing"] == {"implementer": "codex", "reviewer": "claude"}, workers
assert workers["registry"]["codex"]["compatible_roles"] == ["implementer"], workers
assert workers["registry"]["claude"]["compatible_roles"] == ["reviewer"], workers

debaters = body["debaters"]
assert "template" in debaters["registry"], debaters
assert debaters["registry"]["template"]["backend_type"] == "template", debaters
assert debaters["registry"]["template"]["degraded"] is True, debaters
assert debaters["default_backend"] == "template", debaters

routes = set(body["routes"])
assert "POST /orchestra/runs/{run_id}/closeout" in routes, routes
assert "POST /orchestra/runs/{run_id}/global-evaluations" in routes, routes
PY

test_done
