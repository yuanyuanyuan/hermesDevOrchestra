from __future__ import annotations

from typing import Any


class EvidenceGateError(Exception):
    def __init__(self, code: str, message: str, violations: list[str] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.violations = violations or []


def validate_completion_evidence(payload: dict[str, Any], artifact_refs: set[str] | None = None) -> dict[str, Any]:
    """Validate required completion evidence and ensure evidence_refs resolve to known artifacts."""
    missing = [field for field in ["test_evidence", "review_evidence", "commit_evidence"] if not isinstance(payload.get(field), dict) or not payload.get(field)]
    if missing:
        raise EvidenceGateError("evidence_missing", "completion payload is missing required evidence", missing)

    test_evidence = payload["test_evidence"]
    if test_evidence.get("exit_code") != 0:
        raise EvidenceGateError("test_failure", "test evidence exit_code must be 0", ["test_evidence.exit_code"])

    review_evidence = payload["review_evidence"]
    blockers = review_evidence.get("blockers")
    if isinstance(blockers, list) and blockers:
        raise EvidenceGateError("review_blockers_unresolved", "review blockers must be resolved", ["review_evidence.blockers"])

    known_refs = set(artifact_refs or set())
    artifacts = payload.get("artifacts")
    if isinstance(artifacts, list):
        for item in artifacts:
            if isinstance(item, dict) and isinstance(item.get("ref"), str):
                known_refs.add(item["ref"])
    refs = payload.get("evidence_refs", [])
    if not isinstance(refs, list):
        raise EvidenceGateError("evidence_ref_unresolvable", "evidence_refs must be a list", ["evidence_refs"])
    missing_refs = [ref for ref in refs if not isinstance(ref, str) or ref not in known_refs]
    if missing_refs:
        raise EvidenceGateError("evidence_ref_unresolvable", "evidence_refs must resolve to artifacts", missing_refs)

    return {
        "result": "passed",
        "test_exit_code": test_evidence.get("exit_code"),
        "reviewer_id": review_evidence.get("reviewer_id"),
        "warnings": review_evidence.get("warnings", []),
        "evidence_refs": refs,
    }
