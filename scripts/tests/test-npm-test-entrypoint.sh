#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="npm-test-entrypoint"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

MAKE_CALL_LOG="$TMP_DIR/make-calls.log"
export MAKE_CALL_LOG

cat > "$FAKE_BIN/make" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAKE_CALL_LOG"
exit 0
SH
chmod +x "$FAKE_BIN/make"

OUTPUT="$TMP_DIR/npm-test.out"
if ! npm --silent test >"$OUTPUT" 2>&1; then
    fail "npm test should delegate to make test" "exit 0" "$(cat "$OUTPUT")"
fi

assert_eq "test" "$(cat "$MAKE_CALL_LOG")" "npm test should call make test"
if grep -Fq "no test specified" "$OUTPUT"; then
    fail "npm test must not be the default placeholder" "delegates to make test" "$(cat "$OUTPUT")"
fi

test_done
