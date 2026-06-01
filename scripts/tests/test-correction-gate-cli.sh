#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="correction-gate-cli"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR/.hermes"

cat > "$PROJECT_DIR/.hermes/project-profile.yaml" <<'EOF'
name: sprint3-proj
project_id: sprint3-proj
protected_targets:
  - config/risk-policy.yaml
interaction:
  default_mode: summary
  confirmation_threshold: 0.5
EOF

python3 "$REPO_ROOT/scripts/lib/correction_gate.py" --list-nodes >"$TMP_DIR/nodes.out"
for node_id in low_confidence conflict l3_l4_target protected_target goal_divergence unreliable_inference; do
    assert_contains "$node_id" "$TMP_DIR/nodes.out" "missing confirmation node"
done

printf 'N\nExplain\nY\n' | "$REPO_ROOT/scripts/bin/orch-mvp-wizard" --interactive --mock --project-dir "$PROJECT_DIR" >"$TMP_DIR/interactive.out"
assert_contains '"override": false' "$TMP_DIR/interactive.out" "interactive flow should not force override"
assert_contains '"rounds_completed": 2' "$TMP_DIR/interactive.out" "interactive flow should complete two rounds"

"$REPO_ROOT/scripts/bin/orch-mvp-wizard" --batch --project-dir "$PROJECT_DIR" >"$TMP_DIR/batch.out"
assert_contains '"warn": "non-interactive: two-round correction degraded to single-round confirmation"' "$TMP_DIR/batch.out" "batch warning missing"
assert_contains '"mode": "non-interactive"' "$TMP_DIR/batch.out" "batch mode marker missing"

printf 'N\nExplain\nN\n' | "$REPO_ROOT/scripts/bin/orch-mvp-wizard" --interactive --mock --project-dir "$PROJECT_DIR" >"$TMP_DIR/override.out"
assert_file_exists "$PROJECT_DIR/.hermes/override-log.jsonl" "override log missing"
assert_jsonl_valid "$PROJECT_DIR/.hermes/override-log.jsonl"
assert_contains '"original_intent"' "$PROJECT_DIR/.hermes/override-log.jsonl" "override log should store original intent"
assert_contains '"user_override"' "$PROJECT_DIR/.hermes/override-log.jsonl" "override log should store override detail"
assert_contains '"approval_status"' "$PROJECT_DIR/.hermes/override-log.jsonl" "override log should store approval status"
assert_contains '.tmp.override-log.jsonl.' "$TMP_DIR/override.out" "atomic temp path should be reported"

test_done
