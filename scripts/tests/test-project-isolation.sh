#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="project-isolation"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

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

ALPHA_DIR="$TMP_DIR/alpha"
BETA_DIR="$TMP_DIR/beta"
mkdir -p "$ALPHA_DIR" "$BETA_DIR"
git -C "$ALPHA_DIR" init >/dev/null
git -C "$BETA_DIR" init >/dev/null

"$REPO_ROOT/scripts/bin/orch-init" alpha "$ALPHA_DIR" >/tmp/orch-project-isolation-alpha-init.out
"$REPO_ROOT/scripts/bin/orch-init" beta "$BETA_DIR" >/tmp/orch-project-isolation-beta-init.out

cat > "$ALPHA_DIR/.hermes/profiles/reviewer.override.yaml" <<'YAML'
model: alpha-model
engine:
  flags: --output-format json --allowedTools Read,Glob,Grep,LS
YAML
cat > "$ALPHA_DIR/.hermes/profiles/reviewer.project.md" <<'MD'
Alpha reviewer rule.
MD

cat > "$BETA_DIR/.hermes/profiles/reviewer.override.yaml" <<'YAML'
model: beta-model
engine:
  cli: codex
  mode: exec
  flags: --json
  fallback: claude
YAML
cat > "$BETA_DIR/.hermes/profiles/reviewer.project.md" <<'MD'
Beta reviewer rule.
MD

"$REPO_ROOT/scripts/bin/orch-profile-sync" alpha "$ALPHA_DIR" >/tmp/orch-project-isolation-alpha-sync.out
"$REPO_ROOT/scripts/bin/orch-profile-sync" beta "$BETA_DIR" >/tmp/orch-project-isolation-beta-sync.out

ALPHA_JSON="$ALPHA_DIR/.hermes/projects/alpha/project.json"
BETA_JSON="$BETA_DIR/.hermes/projects/beta/project.json"
ALPHA_CONFIG="$ALPHA_DIR/.hermes/projects/alpha/profiles/reviewer/config.yaml"
BETA_CONFIG="$BETA_DIR/.hermes/projects/beta/profiles/reviewer/config.yaml"
ALPHA_SOUL="$ALPHA_DIR/.hermes/projects/alpha/profiles/reviewer/SOUL.md"
BETA_SOUL="$BETA_DIR/.hermes/projects/beta/profiles/reviewer/SOUL.md"

assert_file_exists "$ALPHA_JSON" "alpha project metadata missing"
assert_file_exists "$BETA_JSON" "beta project metadata missing"
assert_file_exists "$ALPHA_CONFIG" "alpha reviewer config missing"
assert_file_exists "$BETA_CONFIG" "beta reviewer config missing"

assert_contains "model: alpha-model" "$ALPHA_CONFIG" "alpha override model missing"
assert_contains "model: beta-model" "$BETA_CONFIG" "beta override model missing"
assert_contains "flags: --output-format json --allowedTools Read,Glob,Grep,LS" "$ALPHA_CONFIG" "alpha engine override missing"
assert_contains "cli: codex" "$BETA_CONFIG" "beta engine cli override missing"
assert_contains "mode: exec" "$BETA_CONFIG" "beta engine mode override missing"
assert_contains "flags: --json" "$BETA_CONFIG" "beta engine flags override missing"
assert_contains "fallback: claude" "$BETA_CONFIG" "beta engine fallback override missing"
assert_contains "Alpha reviewer rule." "$ALPHA_SOUL" "alpha reviewer SOUL missing"
assert_contains "Beta reviewer rule." "$BETA_SOUL" "beta reviewer SOUL missing"

python3 - "$ALPHA_JSON" "$BETA_JSON" <<'PY'
import json, sys
alpha = json.load(open(sys.argv[1], encoding="utf-8"))
beta = json.load(open(sys.argv[2], encoding="utf-8"))
assert alpha["board_slug"] == "alpha"
assert beta["board_slug"] == "beta"
assert alpha["memory_namespace"] == "project:alpha"
assert beta["memory_namespace"] == "project:beta"
assert alpha["workspace_root"].endswith("/alpha/.hermes/projects/alpha")
assert beta["workspace_root"].endswith("/beta/.hermes/projects/beta")
assert alpha["workspace_root"] != beta["workspace_root"]
assert alpha["override_dir"] != beta["override_dir"]
PY

test_done
