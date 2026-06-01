#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="mvp-wizard"
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
case "${1:-}" in
  --version) echo "hermes 0.11.0" ;;
  kanban) echo '{"status":"ok"}' ;;
  *) echo "Hermes fake" ;;
esac
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
chmod +x "$FAKE_BIN/hermes" "$FAKE_BIN/tmux" "$FAKE_BIN/claude" "$FAKE_BIN/codex"

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

REPORT="$TMP_DIR/report.json"
"$REPO_ROOT/scripts/bin/orch-mvp-wizard" \
  --yes \
  --skip-setup \
  --skip-start \
  --skip-gateway \
  --skip-tests \
  --project-id wizard-demo \
  --project-dir "$PROJECT_DIR" \
  --report "$REPORT" \
  >"$TMP_DIR/wizard.out"

assert_contains "MVP guided acceptance complete" "$TMP_DIR/wizard.out" "wizard should complete"
assert_file_exists "$PROJECT_DIR/.workflow/knowledge/project-summary.json" "orch-init should generate workflow knowledge"
assert_file_exists "$STATE_ROOT/wizard-demo/paths.json" "project should be registered"
assert_file_exists "$REPORT" "acceptance report missing"

python3 - "$REPORT" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["project_id"] == "wizard-demo", report
assert report["project_dir"], report
assert report["status"] == "passed", report
assert report["steps"], report
assert any(step["name"] == "orch-init" and step["status"] == "passed" for step in report["steps"]), report
PY

test_done
