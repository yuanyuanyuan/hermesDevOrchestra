#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="init-start-status"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && echo "hermes 0.11.0" || echo "hermes fake"
SH
cat > "$FAKE_BIN/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  -V) echo "tmux 3.4" ;;
  has-session) exit 1 ;;
  list-panes) echo "0" ;;
  new-session|kill-session|ls) exit 0 ;;
  *) exit 0 ;;
esac
SH
cat > "$FAKE_BIN/claude" <<'SH'
#!/usr/bin/env bash
echo "claude fake"
SH
cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
echo "codex fake"
SH
chmod +x "$FAKE_BIN/hermes" "$FAKE_BIN/tmux" "$FAKE_BIN/claude" "$FAKE_BIN/codex"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$HOME" "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null

"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-init-start-init.out
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-start" test-proj "$PROJECT_DIR" >/tmp/orch-init-start-start.out
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-status" test-proj > /tmp/orch-init-start-status.out
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-stop" test-proj >/tmp/orch-init-start-stop.out || true

assert_contains "Project: test-proj" /tmp/orch-init-start-status.out "status missing project"
assert_contains "Stage:" /tmp/orch-init-start-status.out "status missing stage"
assert_contains "Claude session: hermes-test-proj-claude" /tmp/orch-init-start-status.out "status missing Claude session"
assert_contains "Codex session: hermes-test-proj-codex" /tmp/orch-init-start-status.out "status missing Codex session"
assert_contains "Watcher:" /tmp/orch-init-start-status.out "status missing watcher"

test_done
