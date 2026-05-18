#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="fixture-policy"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/testing/full-fixture-policy.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/testing/full-fixture-policy.json: full_fixture_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "fixture policy config was not validated" "fixture policy pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS fixture layer split: contract fixtures and runtime fake adapters are separated" <<<"$FULL_VALIDATE_OUTPUT" || fail "fixture layer split was not validated" "fixture layer split pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS fixture evidence boundary: fixtures cannot satisfy completion or release evidence" <<<"$FULL_VALIDATE_OUTPUT" || fail "fixture evidence boundary was not validated" "fixture evidence boundary pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from fixture_policy import FixturePolicy, FixturePolicyError


def expect_error(code: str, func):
    try:
        func()
    except FixturePolicyError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected FixturePolicyError({code})")


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
    config = load_json(repo / "config/testing/full-fixture-policy.json")
    config["package_status"] = "active"
    if config_mutator is not None:
        config_mutator(config)
    write_json(tmp_repo / "config/testing/full-fixture-policy.json", config)


def contract_fixture() -> dict:
    return {
        "fixture_name": "valid_debate_member_opinion",
        "fixture_kind": "contract_fixture",
        "fixture_backend": "none",
        "degraded_fixture_only": False,
        "completion_evidence_allowed": False,
        "release_evidence_allowed": False,
        "test_scope": "schema_validation",
    }


def runtime_fake_adapter() -> dict:
    return {
        "fixture_name": "fake_api_debate_backend",
        "fixture_kind": "runtime_fake_adapter",
        "fixture_backend": "fake_api_debate_backend",
        "degraded_fixture_only": True,
        "completion_evidence_allowed": False,
        "release_evidence_allowed": False,
        "test_scope": "isolated_integration",
    }


blocked = FixturePolicy(repo)
exc = expect_error("package_not_active", lambda: blocked.validate_contract_fixture("debate", contract_fixture()))
assert "allow_staged=True" in exc.message, exc.message

disabled = FixturePolicy(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", lambda: disabled.validate_contract_fixture("debate", contract_fixture()))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    policy = FixturePolicy(tmp_repo, allow_staged=True)
    validated_contract = policy.validate_contract_fixture("debate", contract_fixture())
    assert validated_contract["fixture_name"] == "valid_debate_member_opinion", validated_contract
    assert validated_contract["completion_evidence_allowed"] is False, validated_contract
    assert validated_contract["release_evidence_allowed"] is False, validated_contract

    validated_runtime = policy.validate_runtime_fake_adapter("debate", runtime_fake_adapter())
    assert validated_runtime["degraded"] is True, validated_runtime
    assert validated_runtime["required_degradation_class"] == "template_debate_fallback", validated_runtime
    assert validated_runtime["completion_evidence_allowed"] is False, validated_runtime

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    policy = FixturePolicy(tmp_repo, allow_staged=True)
    invalid_contract = contract_fixture()
    invalid_contract["completion_evidence_allowed"] = True
    expect_error("completion_evidence_forbidden", lambda: policy.validate_contract_fixture("debate", invalid_contract))

    invalid_runtime = runtime_fake_adapter()
    invalid_runtime["degraded_fixture_only"] = False
    expect_error("runtime_fake_not_degraded", lambda: policy.validate_runtime_fake_adapter("debate", invalid_runtime))

    missing_marker = runtime_fake_adapter()
    missing_marker.pop("test_scope")
    expect_error("fixture_marker_missing", lambda: policy.validate_runtime_fake_adapter("debate", missing_marker))
PY

test_done
