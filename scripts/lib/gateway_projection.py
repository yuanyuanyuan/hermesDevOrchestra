#!/usr/bin/env python3
"""Gateway projection helper — state projection and mapping tracking.

Extracted from orch_gateway.py as part of Sprint 1 seam extraction.
Consumes a NormalizedIntent from gateway_intake and projects it onto
Gateway state, producing a ProjectedState with status, refs, and issues.
"""

from __future__ import annotations

from typing import Any, TypedDict

from gateway_intake import NormalizedIntent


class GatewayContext(TypedDict, total=False):
    """Runtime context for projection decisions."""

    project_id: str
    request_type: str
    run_id: str | None
    timestamp: str


class ProjectedState(TypedDict, total=False):
    """Result of projecting an intent onto gateway state."""

    projection_status: str
    state_refs: list[str]
    mapped_entities: dict[str, Any]
    projection_issues: list[str]
    intent_type: str
    confidence: float


def project(intent: NormalizedIntent, context: GatewayContext) -> ProjectedState:
    """Project a normalized intent onto gateway state.

    Args:
        intent: Output from gateway_intake.normalize().
        context: Runtime context (project_id, request_type, etc.).

    Returns:
        ProjectedState describing the projected state, refs, and any issues.
    """
    intent_type = intent.get("intent_type", "unknown")
    confidence = intent.get("confidence", 0.0)
    validation_errors = intent.get("validation_errors", [])

    projection_status = "consistent" if not validation_errors else "inconsistent"
    state_refs = _build_state_refs(intent, context)
    mapped_entities = _map_entities(intent, context)
    projection_issues = list(validation_errors)

    if confidence < 0.5:
        projection_issues.append(f"low_confidence: {confidence:.2f}")
        projection_status = "inconsistent"

    return {
        "projection_status": projection_status,
        "state_refs": state_refs,
        "mapped_entities": mapped_entities,
        "projection_issues": projection_issues,
        "intent_type": intent_type,
        "confidence": confidence,
    }


def _build_state_refs(intent: NormalizedIntent, context: GatewayContext) -> list[str]:
    """Build state refs that this projection touches."""
    refs: list[str] = []
    project_id = context.get("project_id", "unknown")
    run_id = context.get("run_id")
    request_type = context.get("request_type", "unknown")
    if run_id:
        refs.append(f"state://runs/{run_id}/run.json")
        refs.append(f"state://runs/{run_id}/events.jsonl")
        if request_type in {"create_run", "submit_worker_output"}:
            refs.append(f"state://runs/{run_id}/tasks.json")
    refs.append(f"state://projects/{project_id}/projection.json")
    return refs


def _map_entities(intent: NormalizedIntent, context: GatewayContext) -> dict[str, Any]:
    """Map key entities from the intent into structured entities."""
    payload = intent.get("normalized_payload", {})
    entities: dict[str, Any] = {
        "intent_type": intent.get("intent_type"),
        "request_type": context.get("request_type"),
        "project_id": context.get("project_id"),
    }
    if "idempotency_key" in payload:
        entities["idempotency_key"] = payload["idempotency_key"]
    if "ticket" in payload and isinstance(payload["ticket"], dict):
        entities["ticket_title"] = payload["ticket"].get("title")
    return entities
