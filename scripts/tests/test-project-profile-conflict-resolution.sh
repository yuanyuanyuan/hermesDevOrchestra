#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="project-profile-conflict-resolution"
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
case "${1:-}" in
  --version) echo "hermes 0.11.0" ;;
  kanban) echo '{"status":"ok"}' ;;
  *) echo "Hermes fake" ;;
esac
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

# Run orch-init to create initial project-profile.yaml
"$REPO_ROOT/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/dev/null

# Create conflicting .hermes/project.json with name: old
mkdir -p "$PROJECT_DIR/.hermes"
cat > "$PROJECT_DIR/.hermes/project.json" <<'EOF'
{"name": "old", "project_slug": "test-proj"}
EOF

# Update .hermes/project-profile.yaml with name: new
cat > "$PROJECT_DIR/.hermes/project-profile.yaml" <<'EOF'
name: new
project_id: test-proj
profile_version: 2
source_of_truth: yaml
EOF

# Run orch-profile-sync to trigger conflict resolution
"$REPO_ROOT/scripts/bin/orch-profile-sync" test-proj "$PROJECT_DIR" >/dev/null || true

# Verify project.json in workspace has deprecated marker
WORKSPACE_JSON="$PROJECT_DIR/.hermes/projects/test-proj/project.json"
if [ -f "$WORKSPACE_JSON" ]; then
    python3 - "$WORKSPACE_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
assert data.get("deprecated") == True, "project.json should have deprecated: true"
assert data.get("superseded_by") == "project-profile.yaml", "project.json should reference yaml"
print("deprecated_marker: PASS")
PY
fi

# Verify orch-mvp-wizard report reads yaml as source of truth
REPORT="$TMP_DIR/report.json"
"$REPO_ROOT/scripts/bin/orch-mvp-wizard" \
  --yes \
  --skip-setup \
  --skip-start \
  --skip-gateway \
  --skip-tests \
  --project-id test-proj \
  --project-dir "$PROJECT_DIR" \
  --report "$REPORT" \
  >"$TMP_DIR/wizard.out"

python3 - "$REPORT" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report.get("project_config", {}).get("name") == "new", f"expected project.name='new', got {report.get('project_config', {})}"
print("yaml_source_of_truth: PASS")
PY

test_done
