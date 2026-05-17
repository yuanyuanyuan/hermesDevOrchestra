#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="mvp-wizard-cli-auth-no-env"
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
[ "${1:-}" = "--version" ] && echo "hermes 0.11.0" || echo '{"status":"ok"}'
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

PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null

REPORT="$TMP_DIR/report.json"
"$REPO_ROOT/scripts/bin/orch-mvp-wizard" \
  --skip-setup \
  --skip-start \
  --skip-gateway \
  --skip-tests \
  --project-id cli-auth-demo \
  --project-dir "$PROJECT_DIR" \
  --report "$REPORT" \
  >"$TMP_DIR/wizard.out" 2>"$TMP_DIR/wizard.err"

assert_contains "MVP 引导验收完成" "$TMP_DIR/wizard.out" "wizard should complete without env API keys"
assert_contains "API key 缺失" "$TMP_DIR/wizard.err" "missing keys should be visible as warning"
assert_file_exists "$REPORT" "acceptance report missing"

python3 - "$REPORT" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["status"] == "passed", report
step = next(item for item in report["steps"] if item["name"] == "api-key-check")
assert step["status"] == "warning", report
PY

test_done
