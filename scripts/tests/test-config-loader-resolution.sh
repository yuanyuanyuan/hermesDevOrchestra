#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="config-loader-resolution"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR/.hermes"

cat > "$PROJECT_DIR/.hermes/project-profile.yaml" <<'EOF'
name: new-app
project_id: sprint3-proj
tech_stack:
  - python
interaction:
  default_mode: summary
  confirmation_threshold: 0.6
EOF

cat > "$PROJECT_DIR/.hermes/project.json" <<'EOF'
{"name":"old-app","project_slug":"sprint3-proj","mode":"detailed"}
EOF

python3 "$REPO_ROOT/scripts/lib/project_config_loader.py" --project-dir "$PROJECT_DIR" >"$TMP_DIR/loader.json"

python3 - "$TMP_DIR/loader.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["interaction"]["default_mode"] == "summary", data
assert data["config_source"] == "project-profile.yaml", data
assert float(data["interaction"]["confirmation_threshold"]) == 0.6, data
print("loader_resolution: PASS")
PY

"$REPO_ROOT/scripts/bin/orch-mvp-wizard" --project-dir "$PROJECT_DIR" >"$TMP_DIR/summary.out"
summary_lines="$(wc -l < "$TMP_DIR/summary.out" | tr -d ' ')"
[ "$summary_lines" -le 10 ] || fail "summary preview should be at most 10 lines" "<=10" "$summary_lines"
assert_contains "mode: summary" "$TMP_DIR/summary.out" "summary mode preview missing"
assert_contains "tech_stack: python" "$TMP_DIR/summary.out" "summary preview should contain core info"

cat > "$PROJECT_DIR/.hermes/project-profile.yaml" <<'EOF'
name: new-app
project_id: sprint3-proj
interaction:
  default_mode: detailed
  confirmation_threshold: 0.6
EOF

"$REPO_ROOT/scripts/bin/orch-mvp-wizard" --project-dir "$PROJECT_DIR" >"$TMP_DIR/detailed.out"
assert_contains "mode: detailed" "$TMP_DIR/detailed.out" "detailed mode preview missing"
assert_contains "intent_summary:" "$TMP_DIR/detailed.out" "detailed preview should include intent summary"
assert_contains "dependency_graph:" "$TMP_DIR/detailed.out" "detailed preview should include dependency graph"
assert_contains "risk_flags:" "$TMP_DIR/detailed.out" "detailed preview should include risk flags"

assert_file_exists "$PROJECT_DIR/logs/config-resolution.jsonl" "config resolution log missing"
assert_jsonl_valid "$PROJECT_DIR/logs/config-resolution.jsonl"
assert_contains '"conflict_field": "default_mode"' "$PROJECT_DIR/logs/config-resolution.jsonl" "default_mode conflict not logged"
assert_contains '"yaml_value": "summary"' "$PROJECT_DIR/logs/config-resolution.jsonl" "yaml winning mode not logged"
assert_contains '"json_value": "detailed"' "$PROJECT_DIR/logs/config-resolution.jsonl" "json fallback mode not logged"
assert_contains '"resolution": "yaml_wins"' "$PROJECT_DIR/logs/config-resolution.jsonl" "yaml conflict resolution missing"

test_done
