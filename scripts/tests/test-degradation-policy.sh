#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="degradation-policy"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/degradation/policy.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/degradation/policy.json: degradation_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "degradation policy config was not validated" "degradation policy pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_report import validate_artifact_definition
from degradation_policy import DegradationPolicy, DegradationPolicyError


def expect_error(code: str, func):
    try:
        func()
    except DegradationPolicyError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected DegradationPolicyError({code})")


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
    config = load_json(repo / "config/degradation/policy.json")
    config["package_status"] = "active"
    if config_mutator is not None:
        config_mutator(config)
    write_json(tmp_repo / "config/degradation/policy.json", config)


blocked = DegradationPolicy(repo)
exc = expect_error("package_not_active", lambda: blocked.transition("normal", "degraded"))
assert "allow_staged=True" in exc.message, exc.message

disabled = DegradationPolicy(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", lambda: disabled.transition("normal", "degraded"))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    policy = DegradationPolicy(tmp_repo, allow_staged=True)
    assert policy.transition("normal", "degraded") == "degraded"
    assert policy.transition("degraded", "recovered") == "recovered"
    assert policy.transition("blocked_due_to_degradation", "recovered") == "recovered"
    expect_error("transition_invalid", lambda: policy.transition("normal", "recovered"))

    expect_error(
        "acceptance_required",
        lambda: policy.build_record(
            degradation_status="degraded",
            degradation_class="optional_debate_member_failed",
            policy_key="partial_debate_optional_member_failure",
            cause="optional_member_timeout",
            affected_evidence_refs=["state://runs/run-1/debate/opinion-1.json"],
            recovery_options=["retry_optional_member"],
        ),
    )

    allowed_record = policy.build_record(
        degradation_status="degraded",
        degradation_class="optional_debate_member_failed",
        policy_key="partial_debate_optional_member_failure",
        cause="optional_member_timeout",
        affected_evidence_refs=["state://runs/run-1/debate/opinion-1.json"],
        recovery_options=["retry_optional_member"],
        accepted_by_ref="state://runs/run-1/decisions/kimi-accept.json",
    )
    validate_artifact_definition(tmp_repo, "degradation_record", allowed_record)
    assert allowed_record["completion_evidence_allowed"] is True, allowed_record
    assert allowed_record["decision_required"] == "kimi", allowed_record
    assert policy.allows_completion_evidence(allowed_record) is True

    blocked_record = policy.build_record(
        degradation_status="degraded",
        degradation_class="template_debate_fallback",
        cause="template_backend_only",
        affected_evidence_refs=["state://runs/run-1/debate/opinion-2.json"],
        recovery_options=["rerun_with_real_backend"],
    )
    validate_artifact_definition(tmp_repo, "degradation_record", blocked_record)
    assert blocked_record["completion_evidence_allowed"] is False, blocked_record
    assert policy.allows_completion_evidence(blocked_record) is False

    expect_error(
        "replacement_evidence_required",
        lambda: policy.build_record(
            degradation_status="recovered",
            degradation_class="template_debate_fallback",
            cause="real_backend_replayed",
            affected_evidence_refs=["state://runs/run-1/debate/opinion-2.json"],
            recovery_options=["attach replacement evidence"],
            accepted_by_ref="state://runs/run-1/decisions/recovered.json",
        ),
    )

    recovered_record = policy.build_record(
        degradation_status="recovered",
        degradation_class="template_debate_fallback",
        cause="real_backend_replayed",
        affected_evidence_refs=["state://runs/run-1/debate/opinion-2.json"],
        recovery_options=["attach replacement evidence"],
        accepted_by_ref="state://runs/run-1/decisions/recovered.json",
        replacement_evidence_ref="state://runs/run-1/debate/opinion-2-replacement.json",
    )
    validate_artifact_definition(tmp_repo, "degradation_record", recovered_record)
    assert policy.allows_completion_evidence(recovered_record) is True
PY

test_done
