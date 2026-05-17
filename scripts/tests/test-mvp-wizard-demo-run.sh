#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="mvp-wizard-demo-run"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
GATEWAY_PID=""
cleanup() {
  if [ -n "$GATEWAY_PID" ]; then
    kill "$GATEWAY_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

HERMES_CALL_LOG="$TMP_DIR/hermes-calls.log"
export HERMES_CALL_LOG

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
if [ "${1:-}" = "--version" ]; then
  echo "hermes 0.11.0"
  exit 0
fi
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "create" ]; then
  printf '{"id":"kanban-%s","status":"created"}\n' "$(wc -l < "$HERMES_CALL_LOG" | tr -d ' ')"
  exit 0
fi
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "complete" ]; then
  printf '{"status":"completed"}\n'
  exit 0
fi
printf '{"status":"ok"}\n'
SH
cat > "$FAKE_BIN/tmux" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "-V" ] && echo "tmux 3.4" || exit 0
SH
cat > "$FAKE_BIN/claude" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && echo "claude 2.1.110" || exit 0
SH
cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && echo "codex 0.122.0" || exit 0
SH
cat > "$FAKE_BIN/make" <<'SH'
#!/usr/bin/env bash
echo "fake make $*"
exit 0
SH
cat > "$FAKE_BIN/npm" <<'SH'
#!/usr/bin/env bash
echo "fake npm $*"
exit 0
SH
chmod +x "$FAKE_BIN/hermes" "$FAKE_BIN/tmux" "$FAKE_BIN/claude" "$FAKE_BIN/codex" "$FAKE_BIN/make" "$FAKE_BIN/npm"

export HOME="$TMP_DIR/home"
export ORCHESTRA_HOME="$TMP_DIR/orchestra"
export LOCAL_BIN_DIR="$TMP_DIR/local-bin"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME/.hermes"
cat > "$HOME/.hermes/.env" <<'EOF'
OPENROUTER_API_KEY=sk-or-test
OPENAI_API_KEY=sk-test
ANTHROPIC_API_KEY=sk-ant-oat01-test
EOF

PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null

PORT="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
REPORT="$TMP_DIR/report.json"
"$REPO_ROOT/scripts/bin/orch-mvp-wizard" \
  --yes \
  --skip-setup \
  --skip-start \
  --project-id wizard-demo-run \
  --project-dir "$PROJECT_DIR" \
  --port "$PORT" \
  --report "$REPORT" \
  >"$TMP_DIR/wizard.out"

GATEWAY_PID="$(cat "$STATE_ROOT/wizard-demo-run/gateway.pid")"

assert_contains "MVP demo run completed" "$TMP_DIR/wizard.out" "wizard should report demo completion"
assert_file_exists "$STATE_ROOT/wizard-demo-run/mvp-demo-flow.json" "demo flow report missing"
assert_file_exists "$STATE_ROOT/wizard-demo-run/mvp-demo-log.jsonl" "demo execution log missing"

python3 - "$REPORT" "$STATE_ROOT/wizard-demo-run/mvp-demo-flow.json" "$STATE_ROOT/wizard-demo-run/mvp-demo-log.jsonl" "$STATE_ROOT" "$AUDIT_ROOT" "$HERMES_CALL_LOG" <<'PY'
import json
import pathlib
import sys

report_path, flow_path, log_path, state_root, audit_root, hermes_log = sys.argv[1:]
report = json.load(open(report_path, encoding="utf-8"))
flow = json.load(open(flow_path, encoding="utf-8"))
run_id = flow["run_id"]
run_dir = pathlib.Path(state_root) / "wizard-demo-run" / "runs" / run_id

assert any(step["name"] == "mvp-demo-run" and step["status"] == "passed" for step in report["steps"]), report
assert flow["status"]["status"] == "completed", flow
assert flow["log_ref"].endswith("mvp-demo-log.jsonl"), flow
assert flow["participants"], flow
assert (run_dir / "iteration_closeout_report.json").is_file(), run_dir
assert (run_dir / "system_improvement_proposals.json").is_file(), run_dir
test_execution = json.loads((run_dir / "test_execution_report.json").read_text(encoding="utf-8"))
assert test_execution["commands"][0]["executed"] is True, test_execution
assert test_execution["commands"][0]["exit_code"] == 0, test_execution

log_records = [
    json.loads(line)
    for line in pathlib.Path(log_path).read_text(encoding="utf-8").splitlines()
    if line.strip()
]
actions = [record["action"] for record in log_records]
for action in [
    "read_capabilities",
    "create_run",
    "read_task_projection",
    "submit_worker_output",
    "submit_global_evaluation",
    "approve_final_acceptance",
    "submit_closeout",
    "read_final_status",
    "read_events",
]:
    assert action in actions, actions
for record in log_records:
    assert record["seq"] >= 1, record
    assert record["participant"], record
    assert record["stage"], record
    assert record["what_happened"], record
    assert "input" in record, record
    assert "output" in record, record

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / "wizard-demo-run" / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "run_completed" for record in audit_records), audit_records

calls = pathlib.Path(hermes_log).read_text(encoding="utf-8").splitlines()
assert len([line for line in calls if line.startswith("kanban create")]) == 7, calls
assert len([line for line in calls if line.startswith("kanban complete")]) == 6, calls
PY

test_done
