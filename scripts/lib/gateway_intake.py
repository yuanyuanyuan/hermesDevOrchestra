#!/usr/bin/env python3
"""Gateway intake helper — input validation and normalization.

Extracted from orch_gateway.py as part of Sprint 1 seam extraction.
Provides request intake, validation, and normalization into a structured
NormalizedIntent that downstream projection and evidence helpers consume.
"""

from __future__ import annotations

from typing import Any, TypedDict


class NormalizedIntent(TypedDict, total=False):
    """Structured intent produced by the intake pipeline."""

    intent_type: str
    confidence: float
    source_trace: list[str]
    normalized_payload: dict[str, Any]
    validation_errors: list[str]


def normalize(request: dict[str, Any]) -> NormalizedIntent:
    """Normalize an incoming request into a structured intent.

    Args:
        request: Raw incoming request payload.

    Returns:
        NormalizedIntent with detected type, confidence, trace, and any
        validation errors.
    """
    intent_type = _detect_intent_type(request)
    confidence = _compute_confidence(request, intent_type)
    source_trace = _build_source_trace(request)
    normalized_payload = _normalize_payload(request)
    validation_errors = _validate_payload(request, intent_type)
    return {
        "intent_type": intent_type,
        "confidence": confidence,
        "source_trace": source_trace,
        "normalized_payload": normalized_payload,
        "validation_errors": validation_errors,
    }


def _detect_intent_type(request: dict[str, Any]) -> str:
    """Detect the high-level intent type from the request shape."""
    if "ticket" in request or "intent" in request:
        return "create_run"
    if "worker_output" in request or "artifacts" in request:
        return "submit_worker_output"
    if "verdict" in request:
        return "submit_verdict"
    if "global_evaluation" in request:
        return "submit_global_evaluation"
    if "closeout" in request:
        return "submit_closeout"
    if "failure" in request or "failure_reason" in request:
        return "submit_failure"
    if "stop_reason" in request or "resolution" in request:
        return "stop_run"
    if "module" in request and "operation" in request:
        return "module_endpoint"
    return "unknown"


def _compute_confidence(request: dict[str, Any], intent_type: str) -> float:
    """Compute a simple confidence score for the intent classification."""
    score = 0.5
    if intent_type == "create_run":
        if isinstance(request.get("idempotency_key"), str) and request["idempotency_key"]:
            score += 0.3
        if isinstance(request.get("ticket"), dict):
            score += 0.2
        elif isinstance(request.get("intent"), str):
            score += 0.15
    elif intent_type == "submit_worker_output":
        if isinstance(request.get("worker_output"), dict):
            score += 0.4
    elif intent_type == "module_endpoint":
        if isinstance(request.get("authority"), str):
            score += 0.3
    return min(score, 1.0)


def _build_source_trace(request: dict[str, Any]) -> list[str]:
    """Build a source trace for debugging and audit."""
    trace: list[str] = ["gateway_intake"]
    if "idempotency_key" in request:
        trace.append(f"idempotency_key={request['idempotency_key']}")
    if "run_id" in request:
        trace.append(f"run_id={request['run_id']}")
    return trace


def _normalize_payload(request: dict[str, Any]) -> dict[str, Any]:
    """Create a shallow-normalized copy of the payload."""
    normalized: dict[str, Any] = {}
    for key, value in request.items():
        if isinstance(value, str):
            normalized[key] = value.strip()
        elif isinstance(value, list):
            normalized[key] = [v.strip() if isinstance(v, str) else v for v in value]
        else:
            normalized[key] = value
    return normalized


def _validate_payload(request: dict[str, Any], intent_type: str) -> list[str]:
    """Validate the payload and return a list of validation error messages."""
    errors: list[str] = []
    if intent_type == "create_run":
        if not isinstance(request.get("idempotency_key"), str) or not request.get("idempotency_key", "").strip():
            errors.append("idempotency_key is required")
    elif intent_type == "module_endpoint":
        if not isinstance(request.get("authority"), str) or not request["authority"]:
            errors.append("authority is required for module endpoint")
    elif intent_type == "unknown":
        errors.append("unable to determine intent type from payload")
    return errors
