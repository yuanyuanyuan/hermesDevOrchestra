#!/usr/bin/env python3
"""Completion bundle schema smoke test."""

from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


TEST_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEST_DIR.parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts" / "lib"))

from gateway_intake import normalize  # noqa: E402
from gateway_projection import project  # noqa: E402


def _assert_bundle(bundle: dict[str, object]) -> None:
    required = {
        "schema_version",
        "artifact_type",
        "run_id",
        "intent_summary",
        "dependency_graph",
        "conflict_list",
        "acceptance_matrix",
        "prompt_envelope",
        "risk_flags",
    }
    assert required.issubset(bundle), bundle

    for section in ("intent_summary", "dependency_graph", "conflict_list", "acceptance_matrix", "prompt_envelope", "risk_flags"):
        assert isinstance(bundle[section], dict), section
        assert bundle[section]["source_input_hash"]
        assert bundle[section]["projection_timestamp"]

    intent_conclusions = bundle["intent_summary"]["conclusions"]
    assert intent_conclusions, bundle
    for conclusion in intent_conclusions:
        assert conclusion["source"], conclusion
        assert 0.0 <= conclusion["confidence"] <= 1.0, conclusion
        assert conclusion["verification_method"] in {"manual", "auto", "inferred"}, conclusion

    dependency_dims = bundle["dependency_graph"]["dimensions"]
    assert set(dependency_dims) == {"environment", "upstream", "downstream", "code"}, dependency_dims
    assert all(dependency_dims[name] for name in dependency_dims), dependency_dims

    conflicts = bundle["conflict_list"]["items"]
    assert conflicts, bundle
    for conflict in conflicts:
        assert conflict["conflict_type"] in {"semantic", "version", "resource", "permission"}, conflict
        assert conflict["severity"] in {"blocking", "warning", "info"}, conflict
        assert conflict["resolution_strategy"], conflict

    matrix = bundle["acceptance_matrix"]["items"]
    assert matrix, bundle
    for criterion in matrix:
        assert criterion["ac_id"], criterion
        assert criterion["criterion"], criterion
        assert criterion["test_script"], criterion
        assert criterion["evidence_type"], criterion

    prompt = bundle["prompt_envelope"]
    for key in ("system_prompt", "user_prompt", "context_window_budget", "output_schema_ref"):
        assert key in prompt, prompt

    risks = bundle["risk_flags"]["items"]
    assert risks, bundle
    for risk in risks:
        assert risk["flag"], risk
        assert risk["severity"] in {"blocking", "warning", "info"}, risk
        assert risk["resolution"], risk


def main() -> int:
    tmp_dir = Path(tempfile.mkdtemp(prefix="completion-bundle-"))
    bundle_path = tmp_dir / "requirement-completion-bundle.json"

    full_ticket = {
        "idempotency_key": "bundle-schema-full",
        "intent": "fix flaky login",
        "ticket": {
            "title": "Fix flaky login",
            "background": "Login flow flakes in CI",
            "goal": "Stabilize login retries",
            "deliverables": ["Regression test", "Implementation fix"],
            "acceptance_criteria": ["Login retry test passes"],
            "hard_constraints": ["Stay within auth module"],
            "soft_constraints": ["Prefer existing helpers"],
            "failure_strategy": "Block if tests fail",
        },
    }
    intent = normalize(full_ticket, expected_intent_type="create_run")
    projected = project(
        intent,
        {
            "project_id": "bundle-schema",
            "request_type": "create_run",
            "run_id": "run-bundle-schema",
            "timestamp": "2026-06-01T00:00:00Z",
        },
    )
    bundle = projected["requirement_completion_bundle"]
    bundle_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _assert_bundle(bundle)

    ambiguous_intent = normalize({"idempotency_key": "bundle-schema-ambiguous", "intent": "帮我改点东西"}, expected_intent_type="create_run")
    ambiguous_bundle = project(
        ambiguous_intent,
        {
            "project_id": "bundle-schema",
            "request_type": "create_run",
            "run_id": "run-bundle-ambiguous",
            "timestamp": "2026-06-01T00:00:00Z",
        },
    )["requirement_completion_bundle"]
    _assert_bundle(ambiguous_bundle)
    assert ambiguous_bundle["intent_summary"]["conclusions"][0]["confidence"] < 0.3, ambiguous_bundle
    assert any(item["flag"] == "manual_confirmation_required" for item in ambiguous_bundle["risk_flags"]["items"]), ambiguous_bundle
    assert ambiguous_bundle["conflict_list"]["items"][0]["severity"] == "blocking", ambiguous_bundle

    print(f"PASS completion bundle schema: {bundle_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
