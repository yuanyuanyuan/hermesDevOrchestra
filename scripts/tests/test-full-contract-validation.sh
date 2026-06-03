#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="full-contract-validation"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

VALIDATOR="$REPO_ROOT/scripts/bin/orch-full-contract-validate"
MVP_ACCEPTANCE="$REPO_ROOT/scripts/tests/test-mvp-acceptance.sh"
assert_file_exists "$VALIDATOR" "full contract validator missing"
assert_executable "$VALIDATOR" "full contract validator must be executable"
assert_file_exists "$MVP_ACCEPTANCE" "mvp acceptance test missing"
assert_executable "$MVP_ACCEPTANCE" "mvp acceptance test must be directly executable"

OUTPUT="$("$VALIDATOR" --repo "$REPO_ROOT")"

grep -Fq "PASS schema: config/schemas/orchestra.full.schema.json" <<<"$OUTPUT" || fail "full schema was not validated" "schema pass" "$OUTPUT"
grep -Fq "PASS config/debate/full/teams.json: debate_team_registry" <<<"$OUTPUT" || fail "full debate team registry was not validated" "teams pass" "$OUTPUT"
grep -Fq "PASS config/release/commands.json: release_command_registry" <<<"$OUTPUT" || fail "release command registry was not validated" "release commands pass" "$OUTPUT"
grep -Fq "PASS config/cutover/full-readiness-gates.json: full_contract_readiness_gate_policy" <<<"$OUTPUT" || fail "full readiness gate policy was not validated" "readiness gate pass" "$OUTPUT"
grep -Fq "PASS config/performance/slo-policy.json: performance_slo_policy" <<<"$OUTPUT" || fail "performance SLO policy was not validated" "slo pass" "$OUTPUT"
grep -Fq "PASS config/testing/full-fixture-policy.json: full_fixture_policy" <<<"$OUTPUT" || fail "full fixture policy was not validated" "fixture pass" "$OUTPUT"
grep -Fq "PASS config/evolution/self-evolution-review-queue.json: self_evolution_review_queue_policy" <<<"$OUTPUT" || fail "self evolution review queue policy was not validated" "evolution queue pass" "$OUTPUT"
grep -Fq "PASS release command refs: pipeline refs resolve through command registry" <<<"$OUTPUT" || fail "release command refs were not checked" "release refs pass" "$OUTPUT"
grep -Fq "PASS cutover safety policy: global cutover and historical rewrites are disabled" <<<"$OUTPUT" || fail "cutover safety policy was not checked" "cutover pass" "$OUTPUT"
grep -Fq "PASS runtime family activation: activated families satisfy cutover evidence and checks" <<<"$OUTPUT" || fail "runtime family activation was not checked" "runtime activation pass" "$OUTPUT"
grep -Fq "PASS performance run SLA policy: fixed Six-Stage completion SLA is disabled" <<<"$OUTPUT" || fail "performance run SLA policy was not checked" "slo policy pass" "$OUTPUT"
grep -Fq "PASS fixture layer split: contract fixtures and runtime fake adapters are separated" <<<"$OUTPUT" || fail "fixture layer split was not checked" "fixture split pass" "$OUTPUT"
grep -Fq "PASS fixture evidence boundary: fixtures cannot satisfy completion or release evidence" <<<"$OUTPUT" || fail "fixture evidence boundary was not checked" "fixture evidence pass" "$OUTPUT"
grep -Fq "PASS self evolution queue: proposals go through an explicit queue by default" <<<"$OUTPUT" || fail "self evolution queue was not checked" "evolution queue pass" "$OUTPUT"
grep -Fq "PASS self evolution rejected retention: rejected proposals are retained with reasons" <<<"$OUTPUT" || fail "self evolution rejected retention was not checked" "evolution retention pass" "$OUTPUT"
grep -Fq "PASS runtime knowledge deferred state: runtime knowledge backend is deferred and disabled before adapter selection" <<<"$OUTPUT" || fail "runtime knowledge deferred state was not checked" "knowledge pass" "$OUTPUT"

assert_file_exists "$REPO_ROOT/scripts/lib/gateway_improvement.py" "gateway improvement helper missing"
grep -Fq "CLASSIFICATION_TABLE" "$REPO_ROOT/scripts/lib/gateway_improvement.py" || fail "A-E classification table missing from helper" "CLASSIFICATION_TABLE" "$(sed -n '1,120p' "$REPO_ROOT/scripts/lib/gateway_improvement.py")"
grep -Fq "route_improvement" "$REPO_ROOT/scripts/lib/gateway_improvement.py" || fail "improvement router missing from helper" "route_improvement" "$(sed -n '1,220p' "$REPO_ROOT/scripts/lib/gateway_improvement.py")"
grep -Fq "submit_improvement" "$REPO_ROOT/scripts/lib/orch_gateway.py" || fail "Gateway improvement endpoint missing" "submit_improvement" "$(rg -n "submit_improvement" "$REPO_ROOT/scripts/lib/orch_gateway.py" || true)"
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_evaluation.py" "gateway evaluation helper missing"
grep -Fq "DIMENSION_NAMES" "$REPO_ROOT/scripts/lib/gateway_evaluation.py" || fail "global evaluation dimensions missing from helper" "DIMENSION_NAMES" "$(sed -n '1,120p' "$REPO_ROOT/scripts/lib/gateway_evaluation.py")"
grep -Fq "normalize_global_evaluation" "$REPO_ROOT/scripts/lib/gateway_evaluation.py" || fail "global evaluation normalizer missing from helper" "normalize_global_evaluation" "$(sed -n '1,180p' "$REPO_ROOT/scripts/lib/gateway_evaluation.py")"
grep -Fq "normalize_global_evaluation" "$REPO_ROOT/scripts/lib/orch_gateway.py" || fail "Gateway global evaluation endpoint missing helper call" "normalize_global_evaluation" "$(rg -n "normalize_global_evaluation" "$REPO_ROOT/scripts/lib/orch_gateway.py" || true)"
assert_file_exists "$REPO_ROOT/scripts/lib/gateway_closeout.py" "gateway closeout helper missing"
grep -Fq "closeout_audit_checklist" "$REPO_ROOT/scripts/lib/gateway_closeout.py" || fail "closeout audit checklist helper missing" "closeout_audit_checklist" "$(sed -n '1,160p' "$REPO_ROOT/scripts/lib/gateway_closeout.py")"
grep -Fq "protected_target_approval_blockers" "$REPO_ROOT/scripts/lib/gateway_closeout.py" || fail "protected target approval helper missing" "protected_target_approval_blockers" "$(sed -n '1,180p' "$REPO_ROOT/scripts/lib/gateway_closeout.py")"
grep -Fq "gateway_closeout" "$REPO_ROOT/scripts/lib/orch_gateway.py" || fail "Gateway closeout seam import missing" "gateway_closeout" "$(rg -n "gateway_closeout" "$REPO_ROOT/scripts/lib/orch_gateway.py" || true)"

BASE_COMMIT="$(git -C "$REPO_ROOT" merge-base HEAD origin/main 2>/dev/null || true)"
if [ -n "$BASE_COMMIT" ]; then
  GATEWAY_ADDED="$(git -C "$REPO_ROOT" diff --numstat "$BASE_COMMIT" -- scripts/lib/orch_gateway.py | awk '{print $1}')"
  GATEWAY_ADDED="${GATEWAY_ADDED:-0}"
  if [ "$GATEWAY_ADDED" -gt 50 ]; then
    fail "orch_gateway.py grew beyond Sprint 12 seam budget" "added lines <= 50" "$GATEWAY_ADDED"
  fi
fi

python3 - "$REPO_ROOT" <<'PY'
import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
schema = json.loads((repo_root / "config" / "schemas" / "orchestra.full.schema.json").read_text(encoding="utf-8"))
assert "requirement_completion_bundle" in schema["$defs"], schema["$defs"].keys()

sys.path.insert(0, str(repo_root / "scripts" / "lib"))
from blocker_validator import validate
from gateway_evaluation import DIMENSION_NAMES, normalize_global_evaluation
from gateway_improvement import CLASSIFICATION_TABLE, route_improvement
from gateway_closeout import protected_target_for
from gateway_intake import normalize
from gateway_projection import project

assert set(CLASSIFICATION_TABLE) == {"A", "B", "C", "D", "E"}, CLASSIFICATION_TABLE.keys()
for classification in ("A", "B", "C", "D", "E"):
    route = route_improvement({"classification": classification, "outcome": "failed", "cycles_count": 0})
    assert route.classification == classification
assert route_improvement({"classification": "D", "outcome": "failed", "cycles_count": 2}).status == "regression_budget_exceeded"
try:
    route_improvement({"classification": "F", "outcome": "failed"})
except ValueError:
    pass
else:
    raise AssertionError("unknown classification accepted")

payload = {
    "idempotency_key": "full-contract-bundle",
    "ticket": {
        "title": "Fix flaky login",
        "goal": "Stabilize login retries",
        "acceptance_criteria": ["Login retry test passes"],
        "hard_constraints": ["Stay within auth module"],
        "failure_strategy": "Block if tests fail",
    },
}
bundle = project(
    normalize(payload, expected_intent_type="create_run"),
    {
        "project_id": "full-contract-bundle",
        "request_type": "create_run",
        "run_id": "run-full-contract-bundle",
        "timestamp": "2026-06-01T00:00:00Z",
    },
)["requirement_completion_bundle"]
dims = bundle["dependency_graph"]["dimensions"]
assert set(dims) == {"environment", "upstream", "downstream", "code"}, dims
assert all(dims[key] for key in dims), dims
assert validate(bundle)["status"] == "passed"
print("PASS requirement completion bundle: dependency graph covers four dimensions")

report = {
    "schema_version": "orchestra.v1",
    "artifact_type": "global_evaluation_report",
    "run_id": "run-full-contract-eval",
    "stage": "global_evaluation",
    "input_artifact_refs": ["state://runs/run-full-contract-eval/run.json"],
    "structured_prd_ref": "state://runs/run-full-contract-eval/structured_prd.json",
    "development_plan_ref": "state://runs/run-full-contract-eval/development_plan.json",
    "debate_report_refs": [],
    "implementation_evidence_refs": [],
    "review_verdict_refs": [],
    "qa_verdict_refs": [],
    "test_execution_refs": [],
    "improvement_report_refs": [],
    "downgrade_refs": [],
    "unresolved_decision_refs": [],
    "audit_refs": [],
    "verdict": "pass",
    "warnings": [],
    "residual_risks": [],
    "blocking_issues": [],
    "authority_required": "kimi",
    "final_acceptance_ref": None,
    "next_actions": ["Start Stage 6"],
    "created_at": "2026-06-03T00:00:00Z",
}
evaluation = normalize_global_evaluation(report, "run-full-contract-eval", repo_root)
assert [item["name"] for item in evaluation["dimensions"]] == DIMENSION_NAMES
assert evaluation["authority_route"]["next_stage"] == "closeout"
print("PASS global evaluation helper: eight-dimension scoring and route contract")
assert protected_target_for("terraform/main.tf")[2] == "L4"
assert protected_target_for("docs/api/spec.yaml")[2] == "L3"
print("PASS closeout helper: protected target approval levels resolve")
PY

test_done
