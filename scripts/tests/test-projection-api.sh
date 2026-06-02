#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="projection-api"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'kill "$GATEWAY_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"
cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "create" ]; then
  printf '{"id":"kanban-fixture","status":"created"}\n'
else
  printf '{"status":"ok"}\n'
fi
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
mkdir -p "$HOME"

PROJECT_ID="projection-api"
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

python3 - "$BASE_URL" "$REPO_ROOT" "$TMP_DIR/projection.json" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

base_url, repo_root, out_path = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts/lib"))
from actor_auth import issue_token

secret = "replace-with-local-random-secret"
token = issue_token("kimi", "kimi-agent", secret)
payload = {
    "idempotency_key": "projection-create-001",
    "ticket": {
        "goal": "Create projection fixture",
        "deliverables": ["projection"],
        "acceptance_criteria": ["projection includes six entity groups"],
        "hard_constraints": [],
        "soft_constraints": [],
        "failure_strategy": "block with evidence",
    },
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    created = json.loads(response.read().decode("utf-8"))
run_id = created["run_id"]

request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/projection",
    headers={"X-Actor-Token": token},
    method="GET",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 200, response.status
    assert response.headers["X-Projection-Schema-Version"] == "1.0.0", response.headers
    projection = json.loads(response.read().decode("utf-8"))

for key in ["run", "tasks", "artifacts", "decisions", "audits", "events"]:
    assert key in projection, projection
assert projection["projection_schema_version"] == "1.0.0", projection
intake = projection["run"]["intake_projection"]
assert isinstance(intake["confidence_score"], (int, float)), intake
assert 0.0 <= intake["confidence_score"] <= 1.0, intake
assert isinstance(intake["conflict_summary"], list), intake
assert set(intake["dependency_projection"]) == {"environment", "upstream", "downstream", "code"}, intake
assert projection["authority_matrix_view"]["mutate_kanban_raw_state"] == "blocked", projection["authority_matrix_view"]

request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/projection",
    data=json.dumps({"refresh_entities": ["tasks"], "reason": "manual_refresh"}).encode("utf-8"),
    headers={"Content-Type": "application/json", "X-Actor-Token": token},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    refreshed = json.loads(response.read().decode("utf-8"))
assert refreshed["run_id"] == run_id, refreshed

request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/projection",
    data=json.dumps({"refresh_entities": ["tasks"], "reason": "bad_reason"}).encode("utf-8"),
    headers={"Content-Type": "application/json", "X-Actor-Token": token},
    method="POST",
)
try:
    urllib.request.urlopen(request, timeout=5)
except urllib.error.HTTPError as exc:
    assert exc.code == 409, exc.code
    body = json.loads(exc.read().decode("utf-8"))
    assert body["error"]["code"] == "invalid_refresh_reason", body
else:
    raise AssertionError("invalid refresh reason was accepted")

pathlib.Path(out_path).write_text(json.dumps(projection, indent=2) + "\n", encoding="utf-8")
PY

test_done
