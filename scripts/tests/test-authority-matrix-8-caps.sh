#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="authority-matrix-8-caps"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

MATRIX="$REPO_ROOT/config/decisions/authority-matrix.json"
GATEWAY="$REPO_ROOT/scripts/bin/orch-gateway"

assert_file_exists "$MATRIX" "authority matrix missing"
assert_file_exists "$REPO_ROOT/config/decisions/actor-secrets.json.example" "actor secrets example missing"

python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
matrix = json.loads((repo / "config/decisions/authority-matrix.json").read_text(encoding="utf-8"))
capabilities = matrix["capabilities"]
expected = {
    "create_run",
    "hydrate_requirements",
    "mutate_kanban_raw_state",
    "advance_stage",
    "select_debate_teams",
    "code_or_review",
    "approve_l3_l4",
    "apply_self_evolution",
}
assert set(capabilities) == expected, capabilities
for capability, rules in capabilities.items():
    assert set(rules) == {"kimi", "gateway", "hermes_agents", "claude_codex", "user"}, (capability, rules)
    assert all(value in {"allowed", "blocked", "requires_approval"} for value in rules.values()), rules
assert capabilities["mutate_kanban_raw_state"]["kimi"] == "blocked"
assert capabilities["mutate_kanban_raw_state"]["gateway"] == "allowed"
assert "secret" not in json.dumps(matrix).lower()
PY

TMP_DIR="$(mktemp -d)"
trap 'kill "$GATEWAY_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"
cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
mkdir -p "$HOME"

PROJECT_ID="authority-matrix"
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
"$GATEWAY" --project-id "$PROJECT_ID" --host 127.0.0.1 --port "$PORT" >"$GATEWAY_LOG" 2>&1 &
GATEWAY_PID="$!"

python3 - "$BASE_URL/health" "$GATEWAY_LOG" <<'PY'
import sys
import time
import urllib.request

url, log_path = sys.argv[1:]
deadline = time.time() + 5
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=0.5) as response:
            if response.status == 200:
                break
    except Exception:
        time.sleep(0.1)
else:
    print(open(log_path, encoding="utf-8", errors="replace").read(), file=sys.stderr)
    raise SystemExit("gateway did not become healthy")
PY

assert_contains "authority_matrix_loaded: 8 capabilities" "$GATEWAY_LOG" "authority matrix load log missing"

python3 - "$BASE_URL" "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

base_url, repo_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts/lib"))
from actor_auth import issue_token

secret = "replace-with-local-random-secret"
token = issue_token("gateway", "gateway-system", secret)
request = urllib.request.Request(
    f"{base_url}/orchestra/kanban/raw-state",
    data=json.dumps({"operation": "undefined_capability_probe"}).encode("utf-8"),
    headers={"Content-Type": "application/json", "X-Actor-Token": token},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    body = json.loads(response.read().decode("utf-8"))
assert response.status == 200, body

PY

test_done
