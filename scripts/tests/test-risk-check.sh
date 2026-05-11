#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="risk-check"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

set +e
"$REPO_ROOT/scripts/bin/orch-risk-check" "npm install lodash" >/tmp/orch-risk-safe.out; safe=$?
"$REPO_ROOT/scripts/bin/orch-risk-check" "CREATE TABLE users" >/tmp/orch-risk-create.out; create=$?
"$REPO_ROOT/scripts/bin/orch-risk-check" "sudo chmod 777 /tmp/x" >/tmp/orch-risk-sudo.out; sudo_code=$?
"$REPO_ROOT/scripts/bin/orch-risk-check" "docker system prune" >/tmp/orch-risk-docker.out; docker=$?
"$REPO_ROOT/scripts/bin/orch-risk-check" "修改 JWT 密钥" >/tmp/orch-risk-jwt.out; jwt=$?
set -e

assert_exit_code 0 "$safe" "safe command should exit 0"
assert_exit_code 2 "$create" "CREATE TABLE should exit L3 code"
assert_exit_code 2 "$sudo_code" "sudo chmod should exit L3 code"
assert_exit_code 2 "$docker" "docker system prune should exit L3 code"
assert_exit_code 2 "$jwt" "修改 JWT should exit L3 code"

test_done
