#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-member-invocation"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys
assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/debate/full/backend-policy.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/debate/full/backend-policy.json: debate_backend_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "full debate backend policy contract validation failed" "backend policy pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys
import tempfile

import jsonschema

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_assembly import DebateAssembly
from debate_backend_adapter import DebateBackendAdapterRegistry, TemplateFixtureDebateAdapter
from debate_engine import DebateEngine
from debate_member_invocation import DebateMemberInvocationError, DebateMemberInvocationService


schema = json.loads((repo / "config/schemas/orchestra.full.schema.json").read_text(encoding="utf-8"))


def validate_definition(name, instance):
    jsonschema.validate(
        instance=instance,
        schema={
            "$schema": schema["$schema"],
            "$ref": f"#/$defs/{name}",
            "$defs": schema["$defs"],
        },
    )


def expect_error(code, func):
    try:
        func()
    except DebateMemberInvocationError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected DebateMemberInvocationError({code})")


engine = DebateEngine(repo, allow_staged=True)
assembly = DebateAssembly(repo, allow_staged=True)
run = engine.create_run(
    question="Should Hermes accept template debate fallback for Sprint 3 integration?",
    mode_id="parallel_debate",
    metadata={"sprint": "S3"},
)
selection = assembly.select_for_stage(
    stage="direction_debate",
    task_type="release_deploy",
    risk_level="L3",
    project_overrides={"focus_keywords": ["gateway", "audit"]},
)

input_refs = [
    f"state://runs/{run['debate_id']}/artifacts/structured-prd.json",
    f"state://runs/{run['debate_id']}/artifacts/development-plan.json",
]
context_refs = [
    f"state://runs/{run['debate_id']}/context/gateway-integration-architecture.md",
]
option_refs = [
    f"state://runs/{run['debate_id']}/options/template-fallback.json",
]

registry = DebateBackendAdapterRegistry(repo, allow_staged=True)
policy = registry.load_policy()
assert policy["artifact_type"] == "debate_backend_policy", policy
backend = registry.select_backend(stage="direction_debate")
assert backend["id"] == "template_fixture", backend
assert backend["family"] == "template", backend

service = DebateMemberInvocationService(repo, allow_staged=True)
expect_error(
    "validation_error",
    lambda: service.build_invocation(
        run=run,
        assembly=selection,
        member_id="",
        input_refs=input_refs,
        context_refs=context_refs,
        option_refs=option_refs,
    ),
)
invocation = service.build_invocation(
    run=run,
    assembly=selection,
    member_id=selection["selected_member_ids"][0],
    input_refs=input_refs,
    context_refs=context_refs,
    option_refs=option_refs,
    affected_scopes=["gateway", "release"],
)
validate_definition("debate_member_invocation", invocation)
assert invocation["backend_id"] == "template_fixture", invocation
assert invocation["backend_family"] == "template", invocation
assert invocation["redaction_required"] is True, invocation
assert invocation["secret_scan_required"] is True, invocation
assert invocation["raw_prompt_persistence_allowed"] is False, invocation
assert invocation["raw_stdout_persistence_allowed"] is False, invocation

adapter = TemplateFixtureDebateAdapter(backend)
opinion, receipt = adapter.invoke(invocation)
validate_definition("debate_member_opinion", opinion)
assert opinion["degraded"] is True, opinion
assert opinion["degradation_status"] == "degraded", opinion
assert opinion["backend_id"] == "template_fixture", opinion
assert receipt["status"] == "completed", receipt
assert receipt["degraded"] is True, receipt

result = service.execute(
    run=run,
    assembly=selection,
    input_refs=input_refs,
    context_refs=context_refs,
    option_refs=option_refs,
    affected_scopes=["gateway", "release"],
)

assert len(result["invocations"]) == len(selection["selected_member_ids"]), result["invocations"]
assert len(result["opinions"]) == len(selection["selected_member_ids"]), result["opinions"]
assert len(result["audit_trail"]["invocations"]) == len(selection["selected_member_ids"]), result["audit_trail"]["invocations"]
validate_definition("debate_report", result["report"])
validate_definition("debate_audit_trail", result["audit_trail"])

opinion_ids = {opinion["opinion_id"] for opinion in result["opinions"]}
assert len(opinion_ids) == len(result["opinions"]), opinion_ids
assert len(result["report"]["opinion_refs"]) == len(result["opinions"]), result["report"]["opinion_refs"]
assert result["report"]["degraded"] is True, result["report"]
assert result["report"]["coverage_satisfied"] is False, result["report"]
assert result["report"]["authority_required"] == "kimi", result["report"]
assert result["audit_trail"]["report_ref"] == result["report_ref"], result["audit_trail"]
assert result["audit_trail"]["secret_scan_status"] == "clear", result["audit_trail"]
assert result["audit_trail"]["raw_prompt_persisted"] is False, result["audit_trail"]
assert result["audit_trail"]["raw_stdout_persisted"] is False, result["audit_trail"]

recorded_invocation_ids = {entry["invocation_id"] for entry in result["audit_trail"]["invocations"]}
expected_invocation_ids = {entry["invocation_id"] for entry in result["invocations"]}
assert recorded_invocation_ids == expected_invocation_ids, (recorded_invocation_ids, expected_invocation_ids)

blocked = DebateMemberInvocationService(repo)
exc = expect_error("package_not_active", blocked.load_backend_policy)
assert "staged_target" in exc.message, exc.message

disabled = DebateMemberInvocationService(repo, allow_staged=True, enabled=False)
expect_error(
    "module_disabled",
    lambda: disabled.execute(
        run=run,
        assembly=selection,
        input_refs=input_refs,
        context_refs=context_refs,
        option_refs=option_refs,
    ),
)


class SecretLeakingTemplateAdapter(TemplateFixtureDebateAdapter):
    def invoke(self, invocation):
        opinion, receipt = super().invoke(invocation)
        opinion["position"] = "Use token sk-live-1234567890 before rollout."
        return opinion, receipt


secret_leak_service = DebateMemberInvocationService(
    repo,
    allow_staged=True,
    adapter_overrides={"template_fixture": SecretLeakingTemplateAdapter(backend)},
)
expect_error(
    "secret_scan_failed",
    lambda: secret_leak_service.execute(
        run=run,
        assembly=selection,
        input_refs=input_refs,
        context_refs=context_refs,
        option_refs=option_refs,
    ),
)


class RawPromptTemplateAdapter(TemplateFixtureDebateAdapter):
    def invoke(self, invocation):
        opinion, receipt = super().invoke(invocation)
        opinion["raw_prompt"] = "persisted raw prompt"
        return opinion, receipt


raw_prompt_service = DebateMemberInvocationService(
    repo,
    allow_staged=True,
    adapter_overrides={"template_fixture": RawPromptTemplateAdapter(backend)},
)
expect_error(
    "persistence_forbidden",
    lambda: raw_prompt_service.execute(
        run=run,
        assembly=selection,
        input_refs=input_refs,
        context_refs=context_refs,
        option_refs=option_refs,
    ),
)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    config_dir = tmp_repo / "config/debate/full"
    config_dir.mkdir(parents=True)
    (config_dir / "backend-policy.json").write_text("{ not valid json }", encoding="utf-8")
    malformed = DebateMemberInvocationService(tmp_repo, allow_staged=True)
    expect_error("config_invalid", malformed.load_backend_policy)
PY

test_done
