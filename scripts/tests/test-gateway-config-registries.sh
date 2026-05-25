#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-config-registries"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

assert_file_exists "$REPO_ROOT/config/workers/backends.json" "worker backend registry missing"
assert_file_exists "$REPO_ROOT/config/workers/roles.json" "worker role registry missing"
assert_file_exists "$REPO_ROOT/config/debate/teams.json" "debate team registry missing"
assert_file_exists "$REPO_ROOT/config/debate/modes.json" "debate mode registry missing"
assert_file_exists "$REPO_ROOT/config/knowledge/runtime-kb.json" "runtime knowledge config missing"

python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
backends = json.loads((repo / "config/workers/backends.json").read_text(encoding="utf-8"))
roles = json.loads((repo / "config/workers/roles.json").read_text(encoding="utf-8"))
teams = json.loads((repo / "config/debate/teams.json").read_text(encoding="utf-8"))
modes = json.loads((repo / "config/debate/modes.json").read_text(encoding="utf-8"))
knowledge = json.loads((repo / "config/knowledge/runtime-kb.json").read_text(encoding="utf-8"))

backend_names = {entry["name"] for entry in backends["backends"]}
assert {"codex", "claude"} <= backend_names, backends
role_names = {entry["role"] for entry in roles["roles"]}
assert {"implementer", "reviewer"} <= role_names, roles
for role in roles["roles"]:
    forbidden = set(role.get("fallback_allowed_failure_classes", []))
    assert "schema_mismatch" not in forbidden, role
    assert "security_policy" not in forbidden, role

assert len(teams["teams"]) == 16, teams
assert len({team["id"] for team in teams["teams"]}) == 16, teams
assert len(modes["modes"]) == 8, modes
assert len({mode["id"] for mode in modes["modes"]}) == 8, modes
assert any(team["id"] == "architecture" for team in teams["teams"]), teams
assert any(mode["id"] == "red_team" for mode in modes["modes"]), modes
assert knowledge["enabled"] is False, knowledge
assert knowledge["backend"]["id"] == "deferred", knowledge
assert knowledge["backend"]["enabled"] is False, knowledge
assert knowledge["backend"]["adapter_required_before_enable"] is True, knowledge
PY

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="gateway-config-registries"
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

python3 - "$BASE_URL/orchestra/capabilities" <<'PY'
import json
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=5) as response:
    body = json.loads(response.read().decode("utf-8"))

assert body["workers"]["config_ref"] == "config/workers/backends.json", body["workers"]
assert body["roles"]["config_ref"] == "config/workers/roles.json", body["roles"]
assert body["debaters"]["teams_config_ref"] == "config/debate/teams.json", body["debaters"]
assert body["debaters"]["modes_config_ref"] == "config/debate/modes.json", body["debaters"]
assert body["debaters"]["team_count"] == 16, body["debaters"]
assert body["debaters"]["mode_count"] == 8, body["debaters"]
PY

test_done
