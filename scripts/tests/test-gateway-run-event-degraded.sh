#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-event-degraded"
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
export ORCH_GATEWAY_FAIL_EVENT_APPEND=1
mkdir -p "$HOME"

PROJECT_ID="gateway-degraded"
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

python3 - "$BASE_URL" "$TMP_DIR/first.json" "$TMP_DIR/replay.json" <<'PY'
import json
import sys
import urllib.request

base_url, first_path, replay_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-018-create",
    "ticket": {
        "background": "Projection failure test",
        "goal": "Create authority state even if event projection append fails",
        "deliverables": ["Run state", "Audit evidence", "Projection issue"],
        "acceptance_criteria": ["Retry replays degraded authority result"],
        "hard_constraints": ["Do not duplicate side effects"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Return degraded success"
    },
    "options": {"mode": "mvp_full"}
}

def post():
    request = urllib.request.Request(
        f"{base_url}/orchestra/runs",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        assert response.status == 201, response.status
        return json.loads(response.read().decode("utf-8"))

first = post()
replay = post()
assert replay == first, f"retry must replay degraded authority result\nfirst={first}\nreplay={replay}"

for path, body in ((first_path, first), (replay_path, replay)):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/first.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

first_path, state_root, audit_root, project_id, hermes_log = sys.argv[1:]
first = json.load(open(first_path, encoding="utf-8"))
run_id = first["run_id"]
command_id = first["command_id"]

assert first["event_projection_degraded"] is True, first
assert first["projection_status"] == "inconsistent", first
assert first["projection_issue_refs"], first

run_dir = pathlib.Path(state_root) / project_id / "runs" / run_id
assert (run_dir / "run.json").is_file()
assert (run_dir / "tasks.json").is_file()
assert not (run_dir / "events.jsonl").exists()

for ref in first["projection_issue_refs"]:
    assert ref.startswith(f"state://runs/{run_id}/projection-issues/")
issue_files = list((run_dir / "projection-issues").glob("*.json"))
assert len(issue_files) == 1

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert len([record for record in audit_records if record.get("type") == "run_created" and record.get("command_id") == command_id]) == 1

command_records = list((run_dir / "commands").glob("*.json"))
assert len(command_records) == 1

kanban_calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in kanban_calls if line.startswith("kanban create")]) == 7
PY

test_done
