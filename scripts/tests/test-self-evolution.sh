#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="self-evolution"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/evolution/self-evolution-review-queue.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/evolution/self-evolution-review-queue.json: self_evolution_review_queue_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "self evolution queue config was not validated" "self evolution queue pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS self evolution queue: proposals go through an explicit queue by default" <<<"$FULL_VALIDATE_OUTPUT" || fail "self evolution queue default policy was not validated" "self evolution queue policy pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS self evolution protected targets: protected targets require Human Approval and cannot auto-apply" <<<"$FULL_VALIDATE_OUTPUT" || fail "protected target policy was not validated" "self evolution protected targets pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_report import validate_artifact_definition
from self_evolution import SelfEvolutionError, SelfEvolutionQueue


def expect_error(code: str, func):
    try:
        func()
    except SelfEvolutionError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected SelfEvolutionError({code})")


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
    config = load_json(repo / "config/evolution/self-evolution-review-queue.json")
    config["package_status"] = "active"
    if config_mutator is not None:
        config_mutator(config)
    write_json(tmp_repo / "config/evolution/self-evolution-review-queue.json", config)


def non_protected_proposal() -> dict:
    return {
        "proposal_id": "P-knowledge-001",
        "target_class": "knowledge_asset",
        "target": ".workflow/knowledge/release-checklist.md",
        "target_area": "workflow_docs",
        "summary": "Clarify release checklist after repeated review comments.",
        "rationale": "The same review class repeated twice across successful closeouts.",
        "severity": "medium",
        "evidence_quality": "high",
        "source_run_ids": ["run-self-1"],
        "artifact_refs": ["state://runs/run-self-1/reviews/release-gap.json"],
        "repeated_failure_count": 2,
        "source_run_count": 1,
    }


def protected_proposal() -> dict:
    return {
        "proposal_id": "P-rules-001",
        "target_class": "root_rules",
        "target": "AGENTS.md",
        "target_area": "root_rules",
        "summary": "Tighten root rule wording after a decision-exposed gap.",
        "rationale": "A closeout decision exposed an authority gap in the root rules.",
        "severity": "high",
        "evidence_quality": "high",
        "source_run_ids": ["run-self-1"],
        "artifact_refs": ["state://runs/run-self-1/decisions/rules-gap.json"],
        "repeated_failure_count": 1,
        "source_run_count": 1,
        "proposed_patch_ref": "state://runs/run-self-1/patches/root-rules.diff",
        "approval_impact": "authority_boundary",
    }


blocked = SelfEvolutionQueue(repo)
exc = expect_error("module_disabled", lambda: blocked.generate_stage6_sweep(run_id="run-blocked", source_refs=[], proposals=[], trigger_matches=[]))
assert "allow_staged=True" in exc.message, exc.message

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    queue = SelfEvolutionQueue(tmp_repo, allow_staged=True)
    artifact = queue.generate_stage6_sweep(
        run_id="run-empty",
        source_refs=["state://runs/run-empty/closeout.json"],
        proposals=[],
        trigger_matches=[],
    )
    validate_artifact_definition(tmp_repo, "system_improvement_proposals", artifact)
    assert artifact["queued_item_refs"] == [], artifact
    assert artifact["candidate_only"] is True, artifact

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    queue = SelfEvolutionQueue(tmp_repo, allow_staged=True)
    expect_error(
        "trigger_required",
        lambda: queue.generate_stage6_sweep(
            run_id="run-missing-trigger",
            source_refs=["state://runs/run-missing-trigger/closeout.json"],
            proposals=[non_protected_proposal()],
            trigger_matches=[],
        ),
    )

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    queue = SelfEvolutionQueue(tmp_repo, allow_staged=True)
    bad_protected = protected_proposal()
    bad_protected.pop("proposed_patch_ref")
    expect_error(
        "proposal_invalid",
        lambda: queue.generate_stage6_sweep(
            run_id="run-bad-protected",
            source_refs=["state://runs/run-bad-protected/closeout.json"],
            proposals=[bad_protected],
            trigger_matches=["decision_exposed_rule_or_doc_gap"],
        ),
    )

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    queue = SelfEvolutionQueue(tmp_repo, allow_staged=True)
    artifact = queue.generate_stage6_sweep(
        run_id="run-self-1",
        source_refs=[
            "state://runs/run-self-1/closeout.json",
            "state://runs/run-self-1/reviews/release-gap.json",
        ],
        proposals=[non_protected_proposal(), protected_proposal()],
        trigger_matches=["review_or_qa_same_class_repeated", "decision_exposed_rule_or_doc_gap"],
    )
    validate_artifact_definition(tmp_repo, "system_improvement_proposals", artifact)
    enqueued = queue.enqueue(artifact)
    pending = queue.list_pending(enqueued["queue_items"])
    assert len(enqueued["queue_items"]) == 2, enqueued
    assert len(artifact["queued_item_refs"]) == 2, artifact
    assert pending[0]["protected_target_class"] == "root_rules", pending
    protected_item = next(item for item in enqueued["queue_items"] if item["protected_target_class"] == "root_rules")
    non_protected_item = next(item for item in enqueued["queue_items"] if item["protected_target_class"] == "none")
    assert protected_item["human_approval_required"] is True, protected_item
    assert protected_item["kimi_review_required"] is True, protected_item
    assert protected_item["batch_key"] is None, protected_item
    assert non_protected_item["batch_key"] == "review_or_qa_same_class_repeated|workflow_docs|none", non_protected_item
    assert artifact["approval_required"] == ["P-rules-001"], artifact

    expect_error(
        "transition_invalid",
        lambda: queue.transition(
            protected_item,
            "accepted",
            decision_ref="state://runs/run-self-1/decisions/accept.json",
        ),
    )
    protected_item = queue.transition(protected_item, "under_review")
    protected_item = queue.transition(
        protected_item,
        "accepted",
        decision_ref="state://runs/run-self-1/decisions/rules-accept.json",
        kimi_review_ref="state://runs/run-self-1/reviews/kimi-rules-review.json",
        human_approval_ref="state://runs/run-self-1/approvals/rules.json",
    )
    protected_item = queue.transition(
        protected_item,
        "applied",
        decision_ref="state://runs/run-self-1/decisions/rules-applied.json",
        kimi_review_ref="state://runs/run-self-1/reviews/kimi-rules-review.json",
        human_approval_ref="state://runs/run-self-1/approvals/rules.json",
    )
    assert protected_item["status"] == "applied", protected_item

    non_protected_item = queue.transition(non_protected_item, "under_review")
    non_protected_item = queue.transition(
        non_protected_item,
        "needs_more_evidence",
        decision_ref="state://runs/run-self-1/decisions/more-evidence.json",
    )
    non_protected_item = queue.transition(non_protected_item, "queued")
    assert non_protected_item["status"] == "queued", non_protected_item

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    queue = SelfEvolutionQueue(tmp_repo, allow_staged=True)
    artifact = queue.generate_stage6_sweep(
        run_id="run-bypass",
        source_refs=["state://runs/run-bypass/closeout.json"],
        proposals=[{**protected_proposal(), "queue_bypass_requested": True}],
        trigger_matches=["decision_exposed_rule_or_doc_gap"],
    )
    expect_error("queue_bypass_forbidden", lambda: queue.enqueue(artifact))
PY

test_done
