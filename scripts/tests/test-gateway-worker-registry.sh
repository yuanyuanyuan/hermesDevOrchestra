#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-worker-registry"
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

PROJECT_ID="gateway-workers"
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

python3 - "$BASE_URL" "$TMP_DIR/capabilities.json" "$TMP_DIR/unknown.json" "$TMP_DIR/incompatible.json" "$TMP_DIR/valid.json" "$STATE_ROOT" "$PROJECT_ID" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

base_url, capabilities_path, unknown_path, incompatible_path, valid_path, state_root, project_id = sys.argv[1:]

with urllib.request.urlopen(f"{base_url}/orchestra/capabilities", timeout=5) as response:
    assert response.status == 200, response.status
    capabilities = json.loads(response.read().decode("utf-8"))
with open(capabilities_path, "w", encoding="utf-8") as handle:
    json.dump(capabilities, handle, indent=2)
    handle.write("\n")

def payload(idempotency_key, worker_pairing):
    return {
        "idempotency_key": idempotency_key,
        "ticket": {
            "background": "Worker registry test",
            "goal": "Validate worker pairing before dispatch",
            "deliverables": ["Validation response"],
            "acceptance_criteria": ["Backend pairing is role-compatible"],
            "hard_constraints": ["Use registry"],
            "soft_constraints": [],
            "related_tasks": [],
            "failure_strategy": "Reject invalid worker pairing"
        },
        "options": {"mode": "mvp_full", "worker_pairing": worker_pairing}
    }

def post(body):
    request = urllib.request.Request(
        f"{base_url}/orchestra/runs",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))

unknown_status, unknown_body = post(payload("gw-015-unknown", {"implementer": "missing-backend", "reviewer": "claude"}))
incompatible_status, incompatible_body = post(payload("gw-015-incompatible", {"implementer": "claude", "reviewer": "claude"}))
valid_status, valid_body = post(payload("gw-015-valid", {"implementer": "codex", "reviewer": "claude"}))

assert "worker_backends" in capabilities, capabilities
assert capabilities["worker_backends"]["codex"]["roles"] == ["implementer"], capabilities
assert capabilities["worker_backends"]["claude"]["roles"] == ["reviewer"], capabilities

assert unknown_status == 400, f"unknown backend should fail before run creation: {unknown_status} {unknown_body}"
assert unknown_body["error"]["code"] == "worker_backend_unknown"
assert incompatible_status == 400, f"role-incompatible backend should fail: {incompatible_status} {incompatible_body}"
assert incompatible_body["error"]["code"] == "worker_backend_role_incompatible"

assert valid_status == 201, valid_body
assert valid_body["status"] == "queued"

run_root = pathlib.Path(state_root) / project_id / "runs"
run_ids = [path.name for path in run_root.iterdir() if path.is_dir()]
assert run_ids == [valid_body["run_id"]], run_ids

for path, body in ((unknown_path, unknown_body), (incompatible_path, incompatible_body), (valid_path, valid_body)):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

test_done
