#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-run-lineage-from-stopped"
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

PROJECT_ID="gateway-lineage"
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

python3 - "$BASE_URL" "$TMP_DIR/source-create.json" <<'PY'
import json
import sys
import urllib.request

base_url, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-009-source-create",
    "ticket": {
        "background": "Source run",
        "goal": "Create a source run that will be stopped",
        "deliverables": ["Stopped source evidence"],
        "acceptance_criteria": ["Source run can seed a lineage run"],
        "hard_constraints": ["Do not mutate stopped source when continuing"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Stop and create lineage"
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

SOURCE_RUN_ID="$(python3 - "$TMP_DIR/source-create.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["run_id"])
PY
)"

python3 - "$BASE_URL" "$SOURCE_RUN_ID" <<'PY'
import json
import sys
import urllib.request

base_url, run_id = sys.argv[1:]
payload = {"idempotency_key": "gw-009-source-stop", "reason": "Prepare lineage source", "force": False}
request = urllib.request.Request(
    f"{base_url}/orchestra/runs/{run_id}/stop",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 200, response.status
PY

python3 - "$BASE_URL" "$SOURCE_RUN_ID" "$TMP_DIR/lineage-create.json" <<'PY'
import json
import sys
import urllib.request

base_url, source_run_id, output_path = sys.argv[1:]
payload = {
    "idempotency_key": "gw-009-lineage-create",
    "source_run_id": source_run_id,
    "resume_from_refs": [f"state://runs/{source_run_id}/run.json", f"state://runs/{source_run_id}/partial_closeout.json"],
    "ticket": {
        "background": "Continue from stopped source evidence",
        "goal": "Create a new lineage run",
        "deliverables": ["New run", "Lineage artifact"],
        "acceptance_criteria": ["New run records source_run_id and lineage_ref"],
        "hard_constraints": ["Source run remains stopped"],
        "soft_constraints": [],
        "related_tasks": [],
        "failure_strategy": "Block if source refs are invalid"
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

python3 - "$BASE_URL" "$SOURCE_RUN_ID" "$TMP_DIR/lineage-create.json" "$TMP_DIR/source-status.json" "$TMP_DIR/lineage-status.json" <<'PY'
import json
import sys
import urllib.request

base_url, source_run_id, lineage_create_path, source_status_path, lineage_status_path = sys.argv[1:]
lineage = json.load(open(lineage_create_path, encoding="utf-8"))
for run_id, path in ((source_run_id, source_status_path), (lineage["run_id"], lineage_status_path)):
    with urllib.request.urlopen(f"{base_url}/orchestra/runs/{run_id}", timeout=5) as response:
        assert response.status == 200, response.status
        data = json.loads(response.read().decode("utf-8"))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
PY

python3 - "$TMP_DIR/lineage-create.json" "$TMP_DIR/source-status.json" "$TMP_DIR/lineage-status.json" "$STATE_ROOT" "$AUDIT_ROOT" "$PROJECT_ID" "$SOURCE_RUN_ID" <<'PY'
import json
import pathlib
import sys

lineage_create_path, source_status_path, lineage_status_path, state_root, audit_root, project_id, source_run_id = sys.argv[1:]
lineage_create = json.load(open(lineage_create_path, encoding="utf-8"))
source_status = json.load(open(source_status_path, encoding="utf-8"))
lineage_status = json.load(open(lineage_status_path, encoding="utf-8"))

lineage_run_id = lineage_create["run_id"]
assert lineage_run_id != source_run_id
assert lineage_create["source_run_id"] == source_run_id, lineage_create
assert lineage_create["lineage_ref"] == f"state://runs/{lineage_run_id}/lineage.json", lineage_create
assert lineage_status["source_run_id"] == source_run_id, lineage_status
assert lineage_status["lineage_ref"] == lineage_create["lineage_ref"], lineage_status
assert source_status["status"] == "stopped"

lineage_path = pathlib.Path(state_root) / project_id / "runs" / lineage_run_id / "lineage.json"
lineage = json.loads(lineage_path.read_text(encoding="utf-8"))
assert lineage["artifact_type"] == "run_lineage"
assert lineage["run_id"] == lineage_run_id
assert lineage["source_run_id"] == source_run_id
assert lineage["source_status"] == "stopped"
assert lineage["resume_from_refs"] == [
    f"state://runs/{source_run_id}/run.json",
    f"state://runs/{source_run_id}/partial_closeout.json",
]

source_run_path = pathlib.Path(state_root) / project_id / "runs" / source_run_id / "run.json"
assert json.loads(source_run_path.read_text(encoding="utf-8"))["status"] == "stopped"

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / project_id / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "run_lineage_created" and record.get("run_id") == lineage_run_id for record in audit_records)
PY

test_done
