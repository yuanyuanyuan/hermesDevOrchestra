#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="mvp-wizard-real-worker-demo"
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
CODEX_REAL_WORKER_LOG="$TMP_DIR/codex-real-worker.log"
CLAUDE_REAL_WORKER_LOG="$TMP_DIR/claude-real-worker.log"
export HERMES_CALL_LOG CODEX_REAL_WORKER_LOG CLAUDE_REAL_WORKER_LOG

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
cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  echo "codex 0.122.0"
  exit 0
fi
out=""
args="$*"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output-last-message) out="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
prompt="$(cat)"
demo_id="$(printf '%s\n' "$prompt" | sed -n 's/.*DEMO_ID=\([a-z0-9-]*\).*/\1/p' | head -1)"
[ -n "$demo_id" ] || demo_id="missing-demo-id"
mkdir -p .workflow/knowledge
cat > .workflow/knowledge/orchestra-real-worker-demo.md <<EOF
# Orchestra Real Worker Demo

real_worker_demo_id: $demo_id
codex_cli: completed
low_risk_file: .workflow/knowledge/orchestra-real-worker-demo.md
EOF
printf 'codex args=%s demo_id=%s cwd=%s\n' "$args" "$demo_id" "$PWD" >> "$CODEX_REAL_WORKER_LOG"
if [ -n "$out" ]; then
  mkdir -p "$(dirname "$out")"
  printf '{"status":"completed","demo_id":"%s","changed_files":[".workflow/knowledge/orchestra-real-worker-demo.md"]}\n' "$demo_id" > "$out"
fi
printf '{"event":"codex-real-worker-complete","demo_id":"%s"}\n' "$demo_id"
SH
cat > "$FAKE_BIN/claude" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  echo "claude 2.1.110"
  exit 0
fi
context="$(cat)"
printf 'claude args=%s cwd=%s\n%s\n' "$*" "$PWD" "$context" >> "$CLAUDE_REAL_WORKER_LOG"
printf '{"type":"result","result":"{\"decision\":\"APPROVED\",\"summary\":\"real worker low-risk change reviewed\"}"}\n'
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
chmod +x "$FAKE_BIN/hermes" "$FAKE_BIN/tmux" "$FAKE_BIN/codex" "$FAKE_BIN/claude" "$FAKE_BIN/make" "$FAKE_BIN/npm"

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
  --real-worker-demo \
  --project-id real-worker-demo \
  --project-dir "$PROJECT_DIR" \
  --port "$PORT" \
  --report "$REPORT" \
  >"$TMP_DIR/wizard.out"

GATEWAY_PID="$(cat "$STATE_ROOT/real-worker-demo/gateway.pid")"

assert_contains "MVP real-worker demo completed" "$TMP_DIR/wizard.out" "wizard should report real-worker demo completion"
assert_file_exists "$STATE_ROOT/real-worker-demo/mvp-real-worker-flow.json" "real-worker flow report missing"
assert_file_exists "$STATE_ROOT/real-worker-demo/mvp-real-worker-log.jsonl" "real-worker execution log missing"
assert_file_exists "$PROJECT_DIR/.workflow/knowledge/orchestra-real-worker-demo.md" "real worker should change a low-risk project file"

python3 - "$REPORT" "$STATE_ROOT/real-worker-demo/mvp-real-worker-flow.json" "$STATE_ROOT/real-worker-demo/mvp-real-worker-log.jsonl" "$PROJECT_DIR" "$STATE_ROOT" "$AUDIT_ROOT" "$CODEX_REAL_WORKER_LOG" "$CLAUDE_REAL_WORKER_LOG" <<'PY'
import json
import pathlib
import sys

report_path, flow_path, log_path, project_dir, state_root, audit_root, codex_log, claude_log = sys.argv[1:]
report = json.load(open(report_path, encoding="utf-8"))
flow = json.load(open(flow_path, encoding="utf-8"))
run_id = flow["run_id"]
run_dir = pathlib.Path(state_root) / "real-worker-demo" / "runs" / run_id

assert any(step["name"] == "mvp-real-worker-demo" and step["status"] == "passed" for step in report["steps"]), report
assert flow["status"]["status"] == "completed", flow
assert flow["real_worker_change"]["changed_file"] == ".workflow/knowledge/orchestra-real-worker-demo.md", flow
assert flow["real_worker_change"]["codex_exit_code"] == 0, flow
assert flow["real_worker_change"]["claude_exit_code"] == 0, flow
assert any(participant["name"] == "codex-cli" for participant in flow["participants"]), flow
assert any(participant["name"] == "claude-cli" for participant in flow["participants"]), flow

changed_file = pathlib.Path(project_dir) / ".workflow/knowledge/orchestra-real-worker-demo.md"
content = changed_file.read_text(encoding="utf-8")
assert "real_worker_demo_id:" in content, content
assert "codex_cli: completed" in content, content
assert pathlib.Path(codex_log).read_text(encoding="utf-8").strip(), "codex was not invoked"
assert pathlib.Path(claude_log).read_text(encoding="utf-8").strip(), "claude was not invoked"

log_records = [
    json.loads(line)
    for line in pathlib.Path(log_path).read_text(encoding="utf-8").splitlines()
    if line.strip()
]
actions = [record["action"] for record in log_records]
for action in [
    "create_run",
    "read_task_projection",
    "run_codex_cli",
    "validate_low_risk_file_change",
    "run_claude_cli",
    "submit_real_worker_output",
    "submit_real_review_output",
    "submit_global_evaluation",
    "submit_closeout",
    "read_final_status",
]:
    assert action in actions, actions

worker_reports = list((run_dir / "worker-output-reports").glob("*.json"))
assert worker_reports, "missing worker output reports"
worker_data = [json.loads(path.read_text(encoding="utf-8")) for path in worker_reports]
assert any(report.get("backend_execution", {}).get("backend") == "codex" for report in worker_data), worker_data
assert any(report.get("backend_execution", {}).get("backend") == "claude" for report in worker_data), worker_data

audit_records = [
    json.loads(line)
    for line in (pathlib.Path(audit_root) / "real-worker-demo" / "audit.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
assert any(record.get("type") == "run_completed" for record in audit_records), audit_records
PY

test_done
