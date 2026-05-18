#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="staged-cutover"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/cutover/full-readiness-gates.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/cutover/full-readiness-gates.json: full_contract_readiness_gate_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "full readiness gate policy was not validated" "readiness gate pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS cutover safety policy: global cutover and historical rewrites are disabled" <<<"$FULL_VALIDATE_OUTPUT" || fail "cutover safety policy was not validated" "cutover safety pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import shutil
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from staged_cutover import FullSchemaCutover, StagedCutoverError


def expect_error(code: str, func):
    try:
        func()
    except StagedCutoverError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected StagedCutoverError({code})")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def copy_schema(target_repo: Path) -> None:
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/schemas/orchestra.full.schema.json", schema_dir / "orchestra.full.schema.json")


def prepare_active_repo(tmp_repo: Path, mutator=None) -> None:
    copy_schema(tmp_repo)
    cutover_path = tmp_repo / "config/cutover/full-readiness-gates.json"
    payload = load_json(repo / "config/cutover/full-readiness-gates.json")
    payload["package_status"] = "active"
    if mutator is not None:
        mutator(payload)
    write_json(cutover_path, payload)


blocked = FullSchemaCutover(repo)
exc = expect_error("package_not_active", lambda: blocked.evaluate_family("gateway_authority"))
assert "allow_staged=True" in exc.message, exc.message

disabled = FullSchemaCutover(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", lambda: disabled.evaluate_family("gateway_authority"))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    cutover = FullSchemaCutover(tmp_repo, allow_staged=True)
    family = cutover.evaluate_family("gateway_authority")
    assert family["gate_ready"] is True, family
    assert family["rollback_policy"]["preserve_written_full_artifacts"] is True, family
    assert family["historical_policy"]["rewrite_in_place_allowed"] is False, family

    activation = cutover.can_activate(
        "gateway_authority",
        evidence=family["required_gate_evidence"],
        completed_checks=family["required_checks"],
    )
    assert activation["allowed"] is True, activation
    assert activation["missing_evidence"] == [], activation
    assert activation["missing_checks"] == [], activation

    blocked_activation = cutover.can_activate(
        "gateway_authority",
        evidence=["full_contract_validation_report"],
        completed_checks=["runtime_consumption_tests"],
    )
    assert blocked_activation["allowed"] is False, blocked_activation
    assert "explicit_cutover_decision" in blocked_activation["missing_evidence"], blocked_activation
    assert "explicit_cutover_decision" in blocked_activation["missing_checks"], blocked_activation

    inactive_plan = cutover.plan_artifact_write("gateway_authority", family_activated=False)
    assert inactive_plan["write_full_artifacts"] is False, inactive_plan
    assert inactive_plan["schema_ref"] == "config://schemas/orchestra.schema.json", inactive_plan

    active_plan = cutover.plan_artifact_write("gateway_authority", family_activated=True)
    assert active_plan["write_full_artifacts"] is True, active_plan
    assert active_plan["schema_ref"] == "config://schemas/orchestra.full.schema.json", active_plan

    historical_plan = cutover.plan_artifact_write(
        "gateway_authority",
        family_activated=True,
        historical_run=True,
        existing_schema_version="orchestra.v1",
    )
    assert historical_plan["write_full_artifacts"] is False, historical_plan
    assert historical_plan["preserve_original_schema_version"] is True, historical_plan
    assert historical_plan["schema_version"] == "orchestra.v1", historical_plan
    assert historical_plan["rewrite_in_place_allowed"] is False, historical_plan

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo, mutator=lambda payload: payload["artifact_families"][0].pop("rollback_policy"))
    cutover = FullSchemaCutover(tmp_repo, allow_staged=True)
    expect_error("config_invalid", lambda: cutover.evaluate_family("gateway_authority"))
PY

test_done
