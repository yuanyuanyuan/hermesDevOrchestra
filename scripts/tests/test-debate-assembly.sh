#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-assembly"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys
assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/debate/full/coverage-policy.json
python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/debate/full/assembly-policy.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/debate/full/coverage-policy.json: debate_coverage_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "full debate coverage contract validation failed" "coverage pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/debate/full/assembly-policy.json: debate_assembly_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "full debate assembly contract validation failed" "assembly pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys
import tempfile

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_assembly import DebateAssembly, DebateAssemblyError


def expect_error(code, func):
    try:
        func()
    except DebateAssemblyError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected DebateAssemblyError({code})")


blocked = DebateAssembly(repo)
exc = expect_error("package_not_active", blocked.load_policy)
assert "staged_target" in exc.message, exc.message

assembly = DebateAssembly(repo, allow_staged=True)
policy = assembly.load_policy()
assert policy["coverage_policy"]["artifact_type"] == "debate_coverage_policy", policy
assert policy["assembly_policy"]["artifact_type"] == "debate_assembly_policy", policy
assert policy["stage_requirements"]["direction_debate"]["minimum_member_count"] == 6, policy["stage_requirements"]
assert policy["assembly_policy"]["deterministic_selector"] is True, policy["assembly_policy"]

selection = assembly.select_for_stage(
    stage="direction_debate",
    task_type="release_deploy",
    risk_level="L3",
)
assert selection["artifact_type"] == "debate_audit_trail", selection
assert selection["stage"] == "direction_debate", selection
assert selection["assembly_input"]["task_type_tags"] == ["release_deploy"], selection["assembly_input"]
assert selection["risk_overlay_applied"]["risk_level"] == "L3", selection["risk_overlay_applied"]
assert "release_deploy" in selection["task_type_overlays_applied"], selection["task_type_overlays_applied"]
assert selection["required_modes"] == [
    "adversarial_debate",
    "dynamic_assembly",
    "risk_priority_matrix",
], selection["required_modes"]
assert selection["selected_team_ids"] == [
    "business",
    "compliance",
    "devops_sre",
    "documentation",
    "observability",
    "platform",
    "security",
], selection["selected_team_ids"]
assert len(selection["selected_member_ids"]) == 7, selection["selected_member_ids"]
assert "selected_team_ids" in selection["matched_assembly_rules"], selection["matched_assembly_rules"]

first_scores = selection["member_selection_scores"]["security"]
assert first_scores[0]["member_id"] == "policy_guardian", first_scores
assert first_scores[0]["score"] >= first_scores[1]["score"], first_scores

repeat = assembly.select_for_stage(
    stage="direction_debate",
    task_type="release_deploy",
    risk_level="L3",
)
assert repeat["selected_team_ids"] == selection["selected_team_ids"], repeat["selected_team_ids"]
assert repeat["selected_member_ids"] == selection["selected_member_ids"], repeat["selected_member_ids"]
assert repeat["member_selection_scores"] == selection["member_selection_scores"], repeat["member_selection_scores"]

override_selection = assembly.select_for_stage(
    stage="solution_debate",
    task_type="api_contract",
    risk_level="L2",
    project_overrides={
        "additional_team_ids": ["business"],
        "additional_required_modes": ["jury_panel"],
        "minimum_member_count": 9,
        "focus_keywords": ["contract", "security"],
    },
)
assert "api_design" in override_selection["selected_team_ids"], override_selection["selected_team_ids"]
assert "business" in override_selection["selected_team_ids"], override_selection["selected_team_ids"]
assert "jury_panel" in override_selection["required_modes"], override_selection["required_modes"]
assert len(override_selection["selected_member_ids"]) == 9, override_selection["selected_member_ids"]
assert override_selection["project_overrides_applied"]["minimum_member_count"] == 9, override_selection["project_overrides_applied"]

expect_error("validation_error", lambda: assembly.select_for_stage("", "release_deploy", "L1"))
expect_error("stage_not_found", lambda: assembly.select_for_stage("missing", "release_deploy", "L1"))
expect_error("risk_level_not_found", lambda: assembly.select_for_stage("direction_debate", "release_deploy", "LX"))

disabled = DebateAssembly(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", disabled.load_policy)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    config_dir = tmp_repo / "config/debate/full"
    config_dir.mkdir(parents=True)
    (config_dir / "coverage-policy.json").write_text(json.dumps({
        "schema_version": "orchestra.full.v1",
        "artifact_type": "debate_coverage_policy",
        "package_kind": "full_debate_package",
        "policy_authority": "project",
        "package_status": "active",
        "project_overrides_may_only_increase_coverage": True,
        "stage_requirements": {},
    }), encoding="utf-8")
    (config_dir / "assembly-policy.json").write_text("{ bad json", encoding="utf-8")
    malformed = DebateAssembly(tmp_repo, allow_staged=True)
    expect_error("config_invalid", malformed.load_policy)
PY

test_done
