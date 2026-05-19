#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="performance-slo"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/performance/slo-policy.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/performance/slo-policy.json: performance_slo_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "performance slo config was not validated" "performance slo pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS performance run SLA policy: fixed Six-Stage completion SLA is disabled" <<<"$FULL_VALIDATE_OUTPUT" || fail "fixed SLA disablement was not validated" "performance run SLA policy pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS performance component budgets: required component budgets are present" <<<"$FULL_VALIDATE_OUTPUT" || fail "component budgets were not validated" "performance component budgets pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from performance_slo import PerformanceSLOError, PerformanceBudgetPolicy


def expect_error(code: str, func):
    try:
        func()
    except PerformanceSLOError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected PerformanceSLOError({code})")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def copy_schema(target_repo: Path) -> None:
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    schema_dir.joinpath("orchestra.full.schema.json").write_text(
        (repo / "config/schemas/orchestra.full.schema.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )


def prepare_active_repo(tmp_repo: Path, config_mutator=None) -> None:
    copy_schema(tmp_repo)
    config = load_json(repo / "config/performance/slo-policy.json")
    config["package_status"] = "active"
    if config_mutator is not None:
        config_mutator(config)
    write_json(tmp_repo / "config/performance/slo-policy.json", config)


blocked = PerformanceBudgetPolicy(repo)
exc = expect_error("module_disabled", lambda: blocked.evaluate("gateway_api", {"health_p95_ms": 200}))
assert "allow_staged=True" in exc.message, exc.message

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    policy = PerformanceBudgetPolicy(tmp_repo, allow_staged=True)
    on_budget = policy.evaluate(
        "gateway_api",
        {
            "health_p95_ms": 200,
            "capabilities_p95_ms": 450,
            "status_projection_p95_ms": 700,
            "tasks_projection_p95_ms": 900,
            "event_poll_p95_ms": 900,
            "mutating_command_ack_p95_ms": 1500,
        },
    )
    assert on_budget["budget_status"] == "on_budget", on_budget
    assert on_budget["degradation_status"] == "normal", on_budget

    projection_miss = policy.evaluate(
        "event_projection",
        {
            "post_commit_emit_target_ms": 1400,
            "gap_detection_target_ms": 1800,
            "rebuild_target_ms": 9000,
        },
    )
    assert projection_miss["budget_status"] == "budget_missed", projection_miss
    assert projection_miss["degradation_status"] == "degraded", projection_miss
    assert projection_miss["degradation_action"] == "return_projection_degraded_command_result", projection_miss
    assert projection_miss["completion_evidence_allowed"] is False, projection_miss

    runtime_warning = policy.evaluate(
        "runtime_knowledge",
        {
            "query_target_ms": 12000,
            "ingestion_operation_target_ms": 1200,
        },
    )
    assert runtime_warning["degradation_status"] == "degraded", runtime_warning
    assert runtime_warning["degradation_action"] == "continue_with_warning_context_only", runtime_warning

    release_timeout = policy.evaluate(
        "release_pipeline",
        {
            "command_timed_out": True,
        },
    )
    assert release_timeout["degradation_status"] == "blocked_due_to_degradation", release_timeout
    assert release_timeout["degradation_action"] == "write_timed_out_deployment_report_and_block", release_timeout

    expect_error("observation_missing", lambda: policy.evaluate("gateway_api", {"health_p95_ms": 200}))
    expect_error("component_unknown", lambda: policy.evaluate("unknown_component", {}))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/performance"
    config_dir.mkdir(parents=True, exist_ok=True)
    config_dir.joinpath("slo-policy.json").write_text("{ bad json", encoding="utf-8")
    malformed = PerformanceBudgetPolicy(tmp_repo, allow_staged=True)
    expect_error("config_invalid", malformed.load_policy)
PY

test_done
