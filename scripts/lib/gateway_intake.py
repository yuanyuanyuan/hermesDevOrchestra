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


def normalize(request: dict[str, Any], expected_intent_type: str | None = None) -> NormalizedIntent:
    """Normalize an incoming request into a structured intent.

    Args:
        request: Raw incoming request payload.
        expected_intent_type: Optional request type from the Gateway route.

    Returns:
        NormalizedIntent with detected type, confidence, trace, and any
        validation errors.
    """
    intent_type = _detect_intent_type(request, expected_intent_type)
    confidence = _compute_confidence(request, intent_type, expected_intent_type)
    source_trace = _build_source_trace(request, expected_intent_type)
    normalized_payload = _normalize_payload(request)
    validation_errors = _validate_payload(request, intent_type)
    return {
        "intent_type": intent_type,
        "confidence": confidence,
        "source_trace": source_trace,
        "normalized_payload": normalized_payload,
        "validation_errors": validation_errors,
    }


def _detect_intent_type(request: dict[str, Any], expected_intent_type: str | None = None) -> str:
    """Detect the high-level intent type from the request shape."""
    candidate = _canonical_intent_type(expected_intent_type)
    if candidate is not None:
        return candidate
    for intent_type in (
        "create_run",
        "submit_worker_output",
        "submit_verdict",
        "submit_global_evaluation",
        "submit_closeout",
        "submit_failure",
        "stop_run",
        "module_endpoint",
    ):
        if _matches_request_shape(request, intent_type):
            return intent_type
    return "unknown"


def _compute_confidence(request: dict[str, Any], intent_type: str, expected_intent_type: str | None = None) -> float:
    """Compute a simple confidence score for the intent classification."""
    canonical_expected = _canonical_intent_type(expected_intent_type)
    if canonical_expected == intent_type and _matches_request_shape(request, intent_type):
        return 0.95
    if intent_type != "unknown" and _matches_request_shape(request, intent_type):
        return 0.85
    if canonical_expected == intent_type:
        return 0.6
    return 0.2


def _build_source_trace(request: dict[str, Any], expected_intent_type: str | None = None) -> list[str]:
    """Build a source trace for debugging and audit."""
    trace: list[str] = ["gateway_intake"]
    canonical_expected = _canonical_intent_type(expected_intent_type)
    if canonical_expected is not None:
        trace.append(f"expected_intent_type={canonical_expected}")
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


def _canonical_intent_type(expected_intent_type: str | None) -> str | None:
    if not isinstance(expected_intent_type, str) or not expected_intent_type:
        return None
    if expected_intent_type.startswith("module:"):
        return "module_endpoint"
    if expected_intent_type in {
        "create_run",
        "submit_worker_output",
        "submit_verdict",
        "submit_global_evaluation",
        "submit_closeout",
        "submit_failure",
        "stop_run",
        "module_endpoint",
    }:
        return expected_intent_type
    return None


def _matches_request_shape(request: dict[str, Any], intent_type: str) -> bool:
    if intent_type == "create_run":
        return _non_empty_string(request.get("idempotency_key")) and (
            isinstance(request.get("ticket"), dict) or _non_empty_string(request.get("intent"))
        )
    if intent_type == "submit_worker_output":
        return (
            _non_empty_string(request.get("idempotency_key"))
            and _non_empty_string(request.get("task_id"))
            and isinstance(request.get("worker_response"), dict)
        )
    if intent_type == "submit_verdict":
        return (
            _non_empty_string(request.get("idempotency_key"))
            and _non_empty_string(request.get("task_id"))
            and isinstance(request.get("verdict"), dict)
        )
    if intent_type == "submit_global_evaluation":
        return _non_empty_string(request.get("idempotency_key")) and isinstance(request.get("report"), dict)
    if intent_type == "submit_closeout":
        return (
            _non_empty_string(request.get("idempotency_key"))
            and isinstance(request.get("iteration_closeout_report"), dict)
            and isinstance(request.get("system_improvement_proposals"), dict)
        )
    if intent_type == "submit_failure":
        return _non_empty_string(request.get("idempotency_key")) and isinstance(request.get("failure_report"), dict)
    if intent_type == "stop_run":
        return _non_empty_string(request.get("idempotency_key")) and _non_empty_string(request.get("reason"))
    if intent_type == "module_endpoint":
        return (
            _non_empty_string(request.get("authority"))
            and _non_empty_string(request.get("module"))
            and _non_empty_string(request.get("operation"))
        )
    return False


def _non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())
