#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="e2e-strict-six-stage-flow"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

HARNESS="$REPO_ROOT/scripts/lib/staging Harness.sh"
INJECT="$REPO_ROOT/scripts/lib/staging inject-data.sh"
TEARDOWN="$REPO_ROOT/scripts/lib/staging teardown.sh"
STAGING_ROOT="$REPO_ROOT/.hermes/staging"
RUN_ID="run-strict-001"
RUN_ROOT="$STAGING_ROOT/state/strict-six-stage/runs/$RUN_ID"
AUDIT_ROOT="$STAGING_ROOT/audit/strict-six-stage"

trap '"$TEARDOWN" >/dev/null 2>&1 || true' EXIT

assert_executable "$HARNESS" "staging harness should be executable"
assert_executable "$INJECT" "staging data injection should be executable"
assert_executable "$TEARDOWN" "staging teardown should be executable"

"$HARNESS" >/dev/null
BASELINE_ONE="$(cd "$REPO_ROOT" && find .hermes/staging -type d | sort)"
"$TEARDOWN" >/dev/null
"$HARNESS" >/dev/null
BASELINE_TWO="$(cd "$REPO_ROOT" && find .hermes/staging -type d | sort)"
assert_eq "$BASELINE_ONE" "$BASELINE_TWO" "staging harness should be idempotent"

"$INJECT" >/dev/null
assert_file_exists "$STAGING_ROOT/project/project-profile.yaml" "project profile should be injected"
assert_contains "protected_targets" "$STAGING_ROOT/project/project-profile.yaml" "project profile should include protected targets"
assert_contains "quick_channel" "$STAGING_ROOT/project/project-profile.yaml" "project profile should include quick channel"
assert_contains "evaluation" "$STAGING_ROOT/project/project-profile.yaml" "project profile should include evaluation"
assert_file_exists "$STAGING_ROOT/project/tasks/protected-target-task.json" "protected target task should be injected"
assert_file_exists "$STAGING_ROOT/project/intake/conflict-intake.json" "conflict intake should be injected"

mkdir -p "$RUN_ROOT" "$AUDIT_ROOT"
cat > "$RUN_ROOT/run.json" <<'JSON'
{
  "schema_version": "orchestra.full.v1",
  "run_id": "run-strict-001",
  "status": "completed",
  "stages": ["intake", "direction", "solution", "implementation", "improvement", "global_evaluation", "closeout"]
}
JSON

cat > "$RUN_ROOT/tasks.json" <<'JSON'
{
  "run_id": "run-strict-001",
  "tasks": [
    {"task_id": "task-intake", "stage": "intake", "status": "completed"},
    {"task_id": "task-direction", "stage": "direction", "status": "completed"},
    {"task_id": "task-solution", "stage": "solution", "status": "completed"},
    {"task_id": "task-implementation", "stage": "implementation", "status": "completed"},
    {"task_id": "task-improvement", "stage": "improvement", "status": "completed"},
    {"task_id": "task-global-evaluation", "stage": "global_evaluation", "status": "completed"},
    {"task_id": "task-closeout", "stage": "closeout", "status": "completed"}
  ]
}
JSON

cat > "$RUN_ROOT/events.jsonl" <<'JSONL'
{"event_type":"run.created","timestamp":"2026-06-03T00:00:00Z","run_id":"run-strict-001","payload":{"has_intent_only":true,"hydration_time_ms":1100}}
{"event_type":"intake.completed","timestamp":"2026-06-03T00:00:01Z","run_id":"run-strict-001","payload":{"has_env_deps":true,"has_upstream":true,"has_downstream":true,"has_implicit":true,"has_acceptance_matrix":true}}
{"event_type":"conflict.resolved","timestamp":"2026-06-03T00:00:02Z","run_id":"run-strict-001","payload":{"resolution":"auto_resolved","severity":"medium","auto_resolved_rate":1.0}}
{"event_type":"direction_debate.blocked","timestamp":"2026-06-03T00:00:03Z","run_id":"run-strict-001","payload":{"reason":"direction_error"}}
{"event_type":"implementation.completed","timestamp":"2026-06-03T00:00:04Z","run_id":"run-strict-001","payload":{"has_test_evidence":true,"has_review_evidence":true,"write_scope_verified":true}}
{"event_type":"improvement.closed","timestamp":"2026-06-03T00:00:05Z","run_id":"run-strict-001","payload":{"a_fixed":true,"b_escalated":false,"c_blocked":false,"d_regression_loops":2,"e_debated":true}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:06Z","run_id":"run-strict-001","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:07Z","run_id":"run-strict-001","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:08Z","run_id":"run-strict-001","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:09Z","run_id":"run-strict-001","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"closeout.completed","timestamp":"2026-06-03T00:00:10Z","run_id":"run-strict-001","payload":{"proposals_generated":2,"proposals_applied":1,"proposals_rejected":1}}
{"event_type":"gateway.blocked","timestamp":"2026-06-03T00:00:11Z","run_id":"run-strict-001","payload":{"reason":"missing_evidence"}}
{"event_type":"run.closed","timestamp":"2026-06-03T00:00:12Z","run_id":"run-strict-001","payload":{"human_intervention_count":0}}
{"event_type":"heartbeat.delivered","timestamp":"2026-06-03T00:00:13Z","run_id":"run-strict-001","payload":{"latency_ms":1000,"delivery_rate":1.0}}
{"event_type":"quick_channel.merged","timestamp":"2026-06-03T00:00:14Z","run_id":"run-strict-001","payload":{"auto_merged":true,"downgrade_count":0}}
{"event_type":"global_evaluation.notified","timestamp":"2026-06-03T00:00:15Z","run_id":"run-strict-001","payload":{"notification_level":"summary","delivery_confirmed":true}}
JSONL

cat > "$AUDIT_ROOT/audit.jsonl" <<'JSONL'
{"timestamp":"2026-06-03T00:00:00Z","project":"strict-six-stage","level":"L1","type":"intake","decision":"accepted","details":"intent hydrated"}
{"timestamp":"2026-06-03T00:00:01Z","project":"strict-six-stage","level":"L2","type":"direction","decision":"blocked_then_resolved","details":"direction debate intercepted error"}
{"timestamp":"2026-06-03T00:00:02Z","project":"strict-six-stage","level":"L3","type":"implementation","decision":"completed","details":"evidence verified"}
{"timestamp":"2026-06-03T00:00:03Z","project":"strict-six-stage","level":"L4","type":"closeout","decision":"completed","details":"release gates satisfied"}
JSONL

METRICS="$RUN_ROOT/metrics_summary.json"
"$REPO_ROOT/scripts/bin/orch-audit" --run-id "$RUN_ID" --state-root "$STAGING_ROOT/state" --output "$METRICS" >/dev/null
"$REPO_ROOT/scripts/bin/orch-verify" --metrics "$METRICS" --thresholds "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null

assert_file_exists "$RUN_ROOT/run.json" "run artifact should exist"
assert_file_exists "$RUN_ROOT/tasks.json" "tasks artifact should exist"
assert_file_exists "$RUN_ROOT/events.jsonl" "events artifact should exist"
assert_file_exists "$AUDIT_ROOT/audit.jsonl" "audit artifact should exist"
assert_file_exists "$METRICS" "metrics summary should exist"
assert_jsonl_valid "$RUN_ROOT/events.jsonl"
assert_jsonl_valid "$AUDIT_ROOT/audit.jsonl"

python3 - "$REPO_ROOT/config/schemas/orchestra.full.schema.json" "$RUN_ROOT/run.json" "$RUN_ROOT/tasks.json" "$RUN_ROOT/events.jsonl" "$AUDIT_ROOT/audit.jsonl" "$METRICS" <<'PY'
import json
import sys
from pathlib import Path

import jsonschema

schema_path, run_path, tasks_path, events_path, audit_path, metrics_path = map(Path, sys.argv[1:])
schema = json.loads(schema_path.read_text(encoding="utf-8"))
run = json.loads(run_path.read_text(encoding="utf-8"))
tasks = json.loads(tasks_path.read_text(encoding="utf-8"))
metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
assert run["status"] == "completed", run
assert run["stages"] == ["intake", "direction", "solution", "implementation", "improvement", "global_evaluation", "closeout"], run
assert [item["stage"] for item in tasks["tasks"]] == run["stages"], tasks
for path in (events_path, audit_path):
    assert path.read_text(encoding="utf-8").strip(), path
jsonschema.validate(metrics, {"$ref": "#/$defs/metrics_summary", "$defs": schema["$defs"]})
assert len(metrics["metrics"]) == 14, metrics
PY

test_done
