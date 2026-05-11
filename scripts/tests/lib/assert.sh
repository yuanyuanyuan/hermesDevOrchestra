#!/usr/bin/env bash
set -euo pipefail

: "${TEST_NAME:=unnamed-test}"

fail() {
    local message="$1"
    local expected="${2:-}"
    local actual="${3:-}"

    echo "FAIL $TEST_NAME: $message" >&2
    [ -n "$expected" ] && echo "expected: $expected" >&2
    [ -n "$actual" ] && echo "actual: $actual" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-values differ}"

    [ "$expected" = "$actual" ] || fail "$message" "$expected" "$actual"
}

assert_contains() {
    local needle="$1"
    local file="$2"
    local message="${3:-missing expected content}"

    grep -Fq "$needle" "$file" || fail "$message" "$needle" "$(sed -n '1,40p' "$file" 2>/dev/null || true)"
}

assert_file_exists() {
    local file="$1"
    local message="${2:-file missing}"

    [ -f "$file" ] || fail "$message" "$file" "missing"
}

assert_executable() {
    local file="$1"
    local message="${2:-file not executable}"

    [ -x "$file" ] || fail "$message" "$file" "not executable"
}

assert_jsonl_valid() {
    local file="$1"

    python3 - "$file" <<'PY' || fail "invalid JSONL" "$file" "parse failed"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            json.loads(line)
PY
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-unexpected exit code}"

    assert_eq "$expected" "$actual" "$message"
}

make_fake_path() {
    local dir="$1"

    mkdir -p "$dir"
    export PATH="$dir:$PATH"
}

test_done() {
    echo "PASS $TEST_NAME"
}
