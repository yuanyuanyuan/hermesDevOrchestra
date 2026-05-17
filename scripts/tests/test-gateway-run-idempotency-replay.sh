#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-idempotency-replay"
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

PROJECT_ID="gateway-replay"
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

cat > "$TMP_DIR/payload.json" <<'JSON'
{
  "idempotency_key": "gw-002-replay",
  "ticket": {
    "background": "Replay after an uncertain network response",
    "goal": "Return the same Six-Stage Run result for the same command identity",
    "deliverables": ["Replayable command result"],
    "acceptance_criteria": ["Second identical request returns the first run_id and command_id"],
    "hard_constraints": ["Do not duplicate side effects"],
    "soft_constraints": [],
    "related_tasks": [],
    "failure_strategy": "Keep the original command evidence"
  },
  "options": {"mode": "mvp_full"}
}
JSON

python3 - "$BASE_URL" "$TMP_DIR/payload.json" "$TMP_DIR/first.json" "$TMP_DIR/second.json" <<'PY'
import json
import sys
import urllib.request

base_url, payload_path, first_path, second_path = sys.argv[1:]
payload = open(payload_path, encoding="utf-8").read().encode("utf-8")

for output_path in (first_path, second_path):
    request = urllib.request.Request(
        f"{base_url}/orchestra/runs",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        assert response.status in (200, 201), response.status
        data = json.loads(response.read().decode("utf-8"))
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/first.json" "$TMP_DIR/second.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

first_path, second_path, state_root, audit_root, project_id, hermes_log = sys.argv[1:]
first = json.load(open(first_path, encoding="utf-8"))
second = json.load(open(second_path, encoding="utf-8"))

assert second == first, f"expected replay response to match original result\nfirst={first}\nsecond={second}"
run_id = first["run_id"]
command_id = first["command_id"]

run_root = pathlib.Path(state_root) / project_id / "runs"
run_dirs = [path for path in run_root.iterdir() if path.is_dir()]
assert [path.name for path in run_dirs] == [run_id], f"expected one run directory for replay, got {[path.name for path in run_dirs]}"

command_records = list((run_root / run_id / "commands").glob("*.json"))
assert len(command_records) == 1
assert command_records[0].name == f"{command_id}.json"

events = [
    json.loads(line)
    for line in (run_root / run_id / "events.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert [event["seq"] for event in events] == [1]
assert events[0]["command_id"] == command_id

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
run_created = [record for record in audit_records if record.get("type") == "run_created"]
assert len(run_created) == 1
assert run_created[0]["command_id"] == command_id

kanban_calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in kanban_calls if line.startswith("kanban create")]) == 7
PY

test_done
