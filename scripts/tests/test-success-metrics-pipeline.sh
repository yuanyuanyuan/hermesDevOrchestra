#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="success-metrics-pipeline"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STATE_ROOT="$TMP_DIR/state"
RUN_ID="run-success"
RUN_DIR="$STATE_ROOT/project/runs/$RUN_ID"
mkdir -p "$RUN_DIR"

cat > "$RUN_DIR/events.jsonl" <<'JSONL'
{"event_type":"run.created","timestamp":"2026-06-03T00:00:00Z","run_id":"run-success","payload":{"has_intent_only":true,"hydration_time_ms":1200}}
{"event_type":"intake.completed","timestamp":"2026-06-03T00:00:01Z","run_id":"run-success","payload":{"has_env_deps":true,"has_upstream":true,"has_downstream":true,"has_implicit":true,"has_acceptance_matrix":true}}
{"event_type":"conflict.resolved","timestamp":"2026-06-03T00:00:02Z","run_id":"run-success","payload":{"resolution":"auto_resolved","severity":"medium","auto_resolved_rate":1.0}}
{"event_type":"direction_debate.blocked","timestamp":"2026-06-03T00:00:03Z","run_id":"run-success","payload":{"reason":"direction_error"}}
{"event_type":"implementation.completed","timestamp":"2026-06-03T00:00:04Z","run_id":"run-success","payload":{"has_test_evidence":true,"has_review_evidence":true,"write_scope_verified":true}}
{"event_type":"improvement.closed","timestamp":"2026-06-03T00:00:05Z","run_id":"run-success","payload":{"a_fixed":true,"b_escalated":false,"c_blocked":false,"d_regression_loops":2,"e_debated":true}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:06Z","run_id":"run-success","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:07Z","run_id":"run-success","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:08Z","run_id":"run-success","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"global_evaluation.pass_with_warnings","timestamp":"2026-06-03T00:00:09Z","run_id":"run-success","payload":{"warn_dimensions_count":1,"residual_risks_high":0,"residual_risks_medium":1}}
{"event_type":"closeout.completed","timestamp":"2026-06-03T00:00:10Z","run_id":"run-success","payload":{"proposals_generated":2,"proposals_applied":1,"proposals_rejected":1}}
{"event_type":"gateway.blocked","timestamp":"2026-06-03T00:00:11Z","run_id":"run-success","payload":{"reason":"missing_evidence"}}
{"event_type":"run.closed","timestamp":"2026-06-03T00:00:12Z","run_id":"run-success","payload":{"human_intervention_count":0}}
{"event_type":"heartbeat.delivered","timestamp":"2026-06-03T00:00:13Z","run_id":"run-success","payload":{"latency_ms":1000,"delivery_rate":1.0}}
{"event_type":"quick_channel.merged","timestamp":"2026-06-03T00:00:14Z","run_id":"run-success","payload":{"auto_merged":true,"downgrade_count":0}}
{"event_type":"global_evaluation.notified","timestamp":"2026-06-03T00:00:15Z","run_id":"run-success","payload":{"notification_level":"summary","delivery_confirmed":true}}
JSONL

METRICS="$TMP_DIR/metrics_summary.json"
"$REPO_ROOT/scripts/bin/orch-audit" --run-id "$RUN_ID" --state-root "$STATE_ROOT" --output "$METRICS" >/dev/null

python3 - "$REPO_ROOT/config/performance/slo-policy.json" "$METRICS" <<'PY'
import json
import sys

policy_path, metrics_path = sys.argv[1:]
policy = json.load(open(policy_path, encoding="utf-8"))
metrics = json.load(open(metrics_path, encoding="utf-8"))
required_policy_keys = {"metric_id", "source_events", "aggregation_rule", "threshold", "validation_script_ref"}
success_metrics = policy.get("success_metrics", [])
assert len(success_metrics) == 14, len(success_metrics)
for metric in success_metrics:
    assert required_policy_keys <= set(metric), metric
    assert metric["validation_script_ref"] == "scripts/tests/test-success-metrics-pipeline.sh", metric
summary = metrics.get("metrics", [])
assert len(summary) == 14, len(summary)
assert {item["metric_id"] for item in summary} == {item["metric_id"] for item in success_metrics}
for item in summary:
    assert "observed_value" in item, item
    assert item.get("status") in {"pass", "warn", "fail"}, item
    assert item["status"] == "pass", item
PY

"$REPO_ROOT/scripts/bin/orch-verify" --metrics "$METRICS" --thresholds "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null

FAIL_RUN_ID="run-fail"
FAIL_RUN_DIR="$STATE_ROOT/project/runs/$FAIL_RUN_ID"
mkdir -p "$FAIL_RUN_DIR"
sed "s/run-success/$FAIL_RUN_ID/g; s/\"auto_merged\":true/\"auto_merged\":false/" "$RUN_DIR/events.jsonl" > "$FAIL_RUN_DIR/events.jsonl"
FAIL_METRICS="$TMP_DIR/metrics_summary_fail.json"
"$REPO_ROOT/scripts/bin/orch-audit" --run-id "$FAIL_RUN_ID" --state-root "$STATE_ROOT" --output "$FAIL_METRICS" >/dev/null

set +e
VERIFY_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-verify" --metrics "$FAIL_METRICS" --thresholds "$REPO_ROOT/config/performance/slo-policy.json" 2>&1)"
VERIFY_STATUS="$?"
set -e
[ "$VERIFY_STATUS" -ne 0 ] || fail "orch-verify should fail when a metric is below threshold" "non-zero" "$VERIFY_STATUS"
grep -Fq "metric_failed:quick_channel_auto_merge_rate" <<<"$VERIFY_OUTPUT" || fail "failed metric was not reported" "metric_failed:quick_channel_auto_merge_rate" "$VERIFY_OUTPUT"

test_done
