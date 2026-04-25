#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="docs-contract"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_contains "orch-decisions" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-decisions"
assert_contains "orch-approve" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-approve"
assert_contains "orch-reject" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-reject"
assert_contains "orch-risk-check" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-risk-check"
assert_contains "orch-audit" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-audit"
assert_contains "orch-verify" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-verify"
assert_contains "~/.local/share/hermes-orchestra/{project}/audit.jsonl" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document Audit JSONL path"
assert_contains "docs/COVERAGE-MATRIX.md" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must reference docs/COVERAGE-MATRIX.md"

assert_file_exists "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing"
assert_contains "Upstream native" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing upstream column"
assert_contains "Adapter-provided" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing adapter column"
assert_contains "Deferred" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing deferred column"
assert_contains "remote adapter" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing remote adapter"
assert_contains "audit hardening" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing audit hardening"
assert_contains "isolation" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing isolation"
assert_contains "gbrain" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing gbrain"
assert_contains "dashboard" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing dashboard"
assert_contains "team approvals" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing team approvals"

test_done
