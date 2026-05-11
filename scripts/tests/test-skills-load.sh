#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="skills-load"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "skills" ] && [ "${2:-}" = "list" ]; then
  printf '%s\n' dev-orchestra claude-supervisor codex-executor escalation-handler
else
  echo "hermes 0.11.0"
fi
SH
chmod +x "$FAKE_BIN/hermes"

hermes skills list > "$TMP_DIR/skills.out"
assert_contains "dev-orchestra" "$TMP_DIR/skills.out" "dev-orchestra skill missing"
assert_contains "claude-supervisor" "$TMP_DIR/skills.out" "claude-supervisor skill missing"
assert_contains "codex-executor" "$TMP_DIR/skills.out" "codex-executor skill missing"
assert_contains "escalation-handler" "$TMP_DIR/skills.out" "escalation-handler skill missing"

test_done
