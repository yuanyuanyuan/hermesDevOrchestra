#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="install-probe"
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
case "${1:-}" in
  --version) echo "hermes 0.11.0" ;;
  --help) echo "Hermes help" ;;
  *) echo "Hermes fake" ;;
esac
SH
cat > "$FAKE_BIN/tmux" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "-V" ] && echo "tmux 3.4" || exit 0
SH
chmod +x "$FAKE_BIN/hermes" "$FAKE_BIN/tmux"

export HOME="$TMP_DIR/home"
export ORCHESTRA_HOME="$TMP_DIR/orchestra"
export LOCAL_BIN_DIR="$TMP_DIR/local-bin"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"
mkdir -p "$HOME"

bash "$REPO_ROOT/docs/hermes-dev-orchestra/scripts/setup.sh" >/tmp/orch-install-probe.out

assert_contains "0.11.0" /tmp/orch-install-probe.out "setup must probe upstream hermes 0.11.0"
assert_file_exists "$HOME/.hermes/SOUL.md" "SOUL not installed"
assert_file_exists "$HOME/.hermes/skills/dev-orchestra/SKILL.md" "dev-orchestra skill missing"
assert_executable "$LOCAL_BIN_DIR/orch-init" "orch-init not linked"
assert_executable "$LOCAL_BIN_DIR/orch-risk-check" "orch-risk-check not linked"
assert_executable "$LOCAL_BIN_DIR/orch-verify" "orch-verify not linked"

test_done
