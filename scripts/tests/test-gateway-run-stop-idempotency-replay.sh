#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-stop-idempotency-replay"
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

PROJECT_ID="gateway-stop-replay"
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

python3 - "$BASE_URL" "$TMP_DIR/create.json" <<'PY'
import json
import sys
import urllib.request

base_url, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-008-create",
    "ticket": {
        "background": "Stop replay test run",
        "goal": "Create a queued run that can be stopped idempotently",
        "deliverables": ["Queued run", "Replayable stop result"],
        "acceptance_criteria": ["Stop retry returns the original command result"],
        "hard_constraints": ["Do not duplicate stop evidence"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Stop and archive"
    },
    "options": {"mode": "mvp_full"}
}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 201, response.status
    data = json.loads(response.read().decode("utf-8"))
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

RUN_ID="$(python3 - "$TMP_DIR/create.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["run_id"])
PY
)"

python3 - "$BASE_URL" "$RUN_ID" "$TMP_DIR/first-stop.json" "$TMP_DIR/replay-stop.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, run_id, first_output_path, replay_output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-008-stop",
    "reason": "Retryable stop request",
    "force": False
}

def post_stop():
    request = urllib.request.Request(
        f"{base_url}/orchestra/runs/{run_id}/stop",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))

first_status, first_body = post_stop()
replay_status, replay_body = post_stop()

assert first_status == 200, first_status
assert replay_status == 200, f"expected stop replay 200, got {replay_status}: {replay_body}"
assert replay_body == first_body, f"expected replayed stop result\nfirst={first_body}\nreplay={replay_body}"

for path, body in ((first_output_path, first_body), (replay_output_path, replay_body)):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/first-stop.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$RUN_ID" <<'PY'
import json
import pathlib
import sys

stop_path, state_root, audit_root, project_id, run_id = sys.argv[1:]
stop = json.load(open(stop_path, encoding="utf-8"))
run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id

command_records = list((run_dir / "commands").glob("*.json"))
assert len(command_records) == 2, [path.name for path in command_records]

events = [
    json.loads(line)
    for line in (run_dir / "events.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert [event["type"] for event in events] == ["run_created", "run_stopped"]
assert events[1]["command_id"] == stop["command_id"]

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
stop_audits = [record for record in audit_records if record.get("type") == "run_stopped"]
assert len(stop_audits) == 1
assert stop_audits[0]["command_id"] == stop["command_id"]
PY

test_done
