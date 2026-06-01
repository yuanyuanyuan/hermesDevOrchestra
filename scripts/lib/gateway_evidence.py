#!/usr/bin/env python3
"""Gateway evidence helper — evidence collection and confidence marking.

Extracted from orch_gateway.py as part of Sprint 1 seam extraction.
Consumes a ProjectedState from gateway_projection and gathers evidence
bundles with confidence markers for downstream audit and compliance.
"""

from __future__ import annotations

from typing import Any, TypedDict

from gateway_projection import ProjectedState


class EvidenceBundle(TypedDict, total=False):
    """Collected evidence with confidence markers."""

    evidence_refs: list[str]
    confidence_markers: dict[str, float]
    audit_trail: list[dict[str, Any]]
    degraded: bool
    degradation_reason: str | None


def gather(projected: ProjectedState) -> EvidenceBundle:
    """Gather evidence from a projected state.

    Args:
        projected: Output from gateway_projection.project().

    Returns:
        EvidenceBundle with refs, confidence markers, and audit trail.
    """
    intent_type = projected.get("intent_type", "unknown")
    confidence = projected.get("confidence", 0.0)
    projection_status = projected.get("projection_status", "unknown")
    state_refs = projected.get("state_refs", [])
    projection_issues = projected.get("projection_issues", [])

    evidence_refs = list(state_refs)
    confidence_markers = {
        "intent_classification": confidence,
        "projection_integrity": 1.0 if projection_status == "consistent" else 0.5,
    }
    audit_trail = _build_audit_trail(projected)
    degraded = projection_status != "consistent" or confidence < 0.5
    degradation_reason = None
    if projection_issues:
        degradation_reason = "; ".join(projection_issues)
    elif confidence < 0.5:
        degradation_reason = f"low_confidence: {confidence:.2f}"

    return {
        "evidence_refs": evidence_refs,
        "confidence_markers": confidence_markers,
        "audit_trail": audit_trail,
        "degraded": degraded,
        "degradation_reason": degradation_reason,
    }


def _build_audit_trail(projected: ProjectedState) -> list[dict[str, Any]]:
    """Build an audit trail entry from the projected state."""
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return [
        {
            "timestamp": now,
            "level": "L1",
            "type": "gateway_evidence_gathered",
            "intent_type": projected.get("intent_type"),
            "confidence": projected.get("confidence"),
            "projection_status": projected.get("projection_status"),
            "state_refs": projected.get("state_refs", []),
            "projection_issues": projected.get("projection_issues", []),
        }
    ]
