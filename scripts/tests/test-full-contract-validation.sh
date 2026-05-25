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

test_done
