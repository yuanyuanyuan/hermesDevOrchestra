#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGING_ROOT="${HERMES_STAGING_ROOT:-$REPO_ROOT/.hermes/staging}"
PROJECT_DIR="$STAGING_ROOT/project"

[ -d "$PROJECT_DIR" ] || {
    echo "staging project directory missing; run scripts/lib/staging Harness.sh first" >&2
    exit 1
}

cat > "$PROJECT_DIR/project-profile.yaml" <<'YAML'
profile:
  protected_targets:
    - category: production_release
      pattern: "deploy/production/.*"
      level: L4
quick_channel:
  rollout_phase: enabled
  auto_merge: true
  notification: compact
evaluation:
  warning_notification: summary
YAML

mkdir -p "$PROJECT_DIR/tasks" "$PROJECT_DIR/intake"
cat > "$PROJECT_DIR/tasks/protected-target-task.json" <<'JSON'
{
  "task_id": "task-protected-001",
  "title": "Update protected production release config",
  "target_path": "deploy/production/service.yaml",
  "protected_target": true,
  "approval_level": "L4"
}
JSON

cat > "$PROJECT_DIR/intake/conflict-intake.json" <<'JSON'
{
  "intake_id": "intake-conflict-001",
  "goal": "Ship strict six-stage regression",
  "conflict_markers": ["protected_target", "missing_evidence"],
  "requires_conflict_resolution": true
}
JSON

printf '%s\n' "staging_data=$PROJECT_DIR"
