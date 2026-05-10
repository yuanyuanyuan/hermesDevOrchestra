#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="profile-packaging"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"
mkdir -p "$HOME"

PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init >/dev/null

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-profile-packaging-init.out

cat > "$PROJECT_DIR/.hermes/profiles/implementer.override.yaml" <<'YAML'
model: claude
toolsets:
  enabled: [web]
  disabled: [code_execution]
YAML

cat > "$PROJECT_DIR/.hermes/profiles/implementer.project.md" <<'MD'
Project-only rule: check project constraints before coding.
MD

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-profile-sync" test-proj "$PROJECT_DIR" >/tmp/orch-profile-packaging-sync.out

CONFIG_OUT="$PROJECT_DIR/.hermes/projects/test-proj/profiles/implementer/config.yaml"
SOUL_OUT="$PROJECT_DIR/.hermes/projects/test-proj/profiles/implementer/SOUL.md"
PROJECT_JSON="$PROJECT_DIR/.hermes/projects/test-proj/project.json"

assert_file_exists "$CONFIG_OUT" "generated implementer config missing"
assert_file_exists "$SOUL_OUT" "generated implementer SOUL missing"
assert_file_exists "$PROJECT_JSON" "project metadata missing"

assert_contains "model: claude" "$CONFIG_OUT" "override model not applied"
assert_contains "enabled: [terminal, file, memory, kanban, web]" "$CONFIG_OUT" "toolset merge output incorrect"
assert_contains "disabled: [delegation, messaging, browser, code_execution]" "$CONFIG_OUT" "disabled toolset merge output incorrect"
assert_contains "Project-only rule: check project constraints before coding." "$SOUL_OUT" "project SOUL fragment missing"

python3 - "$SOUL_OUT" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
global_idx = text.index("## Global Rules")
project_idx = text.index("## Project Rules")
project_rule_idx = text.index("Project-only rule: check project constraints before coding.")
role_idx = text.index("## Role Rules")
if not (global_idx < project_idx < project_rule_idx < role_idx):
    raise SystemExit("SOUL order incorrect")
PY

[ ! -e "$HOME/.hermes/profiles/implementer" ] || fail "project overrides leaked into global Hermes home" "no global implementer profile" "$HOME/.hermes/profiles/implementer"

python3 - "$PROJECT_JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["project_slug"] == "test-proj"
assert data["board_slug"] == "test-proj"
assert data["memory_namespace"] == "project:test-proj"
assert data["profile_catalog_version"] == "2026-05-10-phase21"
PY

test_done
