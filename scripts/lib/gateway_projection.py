#!/usr/bin/env python3
"""Gateway projection helper — state projection and mapping tracking.

Extracted from orch_gateway.py as part of Sprint 1 seam extraction.
Consumes a NormalizedIntent from gateway_intake and projects it onto
Gateway state, producing a ProjectedState with status, refs, and issues.
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any, TypedDict

from gateway_intake import NormalizedIntent


class EvidenceTriple(TypedDict):
    """Provenance triple used throughout requirement completion bundles."""

    source: str
    confidence: float
    verification_method: str


class BundleConclusion(TypedDict, total=False):
    """A single annotated conclusion in the completion bundle."""

    text: str
    source: str
    confidence: float
    verification_method: str


class RequirementCompletionBundle(TypedDict, total=False):
    """Structured six-class requirement completion bundle."""

    schema_version: str
    artifact_type: str
    run_id: str
    intent_summary: dict[str, Any]
    dependency_graph: dict[str, Any]
    conflict_list: dict[str, Any]
    acceptance_matrix: dict[str, Any]
    prompt_envelope: dict[str, Any]
    risk_flags: dict[str, Any]


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
    requirement_completion_bundle: RequirementCompletionBundle


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
    payload = intent.get("normalized_payload", {})
    ticket = payload.get("ticket") if isinstance(payload.get("ticket"), dict) else {}

    requirement_completion_bundle = build_requirement_completion_bundle(intent, context)
    bundle_confidence = _bundle_confidence(intent, ticket)
    confidence = min(confidence, bundle_confidence)

    projection_status = "consistent" if not validation_errors and confidence >= 0.5 else "inconsistent"
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
        "requirement_completion_bundle": requirement_completion_bundle,
    }


def build_requirement_completion_bundle(intent: NormalizedIntent, context: GatewayContext) -> RequirementCompletionBundle:
    """Build the six-class completion bundle for a normalized intent."""
    payload = intent.get("normalized_payload", {})
    ticket = payload.get("ticket") if isinstance(payload.get("ticket"), dict) else {}
    intent_text = _first_non_empty_string(
        [
            payload.get("intent"),
            ticket.get("goal") if isinstance(ticket, dict) else None,
            ticket.get("background") if isinstance(ticket, dict) else None,
        ]
    )
    summary_confidence = _bundle_confidence(intent, ticket)
    source_input_hash = _source_input_hash(payload)
    projection_timestamp = context.get("timestamp") or _utc_now()
    manual_review_required = summary_confidence < 0.5
    bundle_meta = {
        "source_input_hash": source_input_hash,
        "projection_timestamp": projection_timestamp,
    }

    acceptance_criteria = _normalize_list(ticket.get("acceptance_criteria") if isinstance(ticket, dict) else None)
    if not acceptance_criteria:
        acceptance_criteria = [intent_text or "确认需求补全包"]

    bundle = {
        "schema_version": "orchestra.v1",
        "artifact_type": "requirement_completion_bundle",
        "run_id": context.get("run_id") or "unknown",
        "intent_summary": {
            **bundle_meta,
            "conclusions": _intent_conclusions(intent_text, payload, ticket, summary_confidence, manual_review_required),
        },
        "dependency_graph": {
            **bundle_meta,
            "format": "adjacency_list",
            "dimensions": _dependency_dimensions(payload, context, summary_confidence, manual_review_required),
        },
        "conflict_list": {
            **bundle_meta,
            "items": _conflict_items(intent_text, payload, ticket, summary_confidence, manual_review_required),
        },
        "acceptance_matrix": {
            **bundle_meta,
            "items": _acceptance_matrix(intent_text, acceptance_criteria, ticket, summary_confidence, manual_review_required),
        },
        "prompt_envelope": {
            **bundle_meta,
            "system_prompt": _system_prompt(context, summary_confidence, manual_review_required),
            "user_prompt": _user_prompt(intent_text, payload, ticket),
            "context_window_budget": 128000,
            "output_schema_ref": "config/schemas/orchestra.full.schema.json#/$defs/requirement_completion_bundle",
        },
        "risk_flags": {
            **bundle_meta,
            "items": _risk_flags(payload, ticket, summary_confidence, manual_review_required),
        },
    }
    return bundle


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


def _bundle_confidence(intent: NormalizedIntent, ticket: dict[str, Any]) -> float:
    confidence = float(intent.get("confidence", 0.0) or 0.0)
    if not isinstance(ticket, dict) or not ticket:
        return min(confidence, 0.25)
    return round(confidence, 2)


def _intent_conclusions(
    intent_text: str,
    payload: dict[str, Any],
    ticket: dict[str, Any],
    summary_confidence: float,
    manual_review_required: bool,
) -> list[BundleConclusion]:
    conclusions: list[BundleConclusion] = [
        {
            "text": intent_text or "需求补全已完成",
            "source": "request.intent" if _first_non_empty_string([payload.get("intent")]) else "request.ticket.goal",
            "confidence": summary_confidence,
            "verification_method": "inferred" if manual_review_required else "manual",
        }
    ]
    if manual_review_required:
        conclusions.append(
            {
                "text": "信息不足，进入人工确认节点补齐验收与约束",
                "source": "request.intent",
                "confidence": 0.2,
                "verification_method": "inferred",
            }
        )
    elif _normalize_list(ticket.get("acceptance_criteria")):
        conclusions.append(
            {
                "text": "补全包可直接驱动后续阶段",
                "source": "request.ticket.acceptance_criteria",
                "confidence": min(0.95, summary_confidence + 0.05),
                "verification_method": "auto",
            }
        )
    return conclusions


def _dependency_dimensions(
    payload: dict[str, Any],
    context: GatewayContext,
    summary_confidence: float,
    manual_review_required: bool,
) -> dict[str, list[dict[str, Any]]]:
    project_id = context.get("project_id", "unknown")
    request_type = context.get("request_type", "unknown")
    return {
        "environment": [
            _dependency_item(
                "runtime / tooling / execution environment",
                "project-profile.yaml",
                max(0.45, summary_confidence),
                "inferred" if manual_review_required else "auto",
            )
        ],
        "upstream": [
            _dependency_item(
                f"{request_type} input and upstream constraints",
                "request.payload",
                max(0.45, summary_confidence),
                "inferred",
            )
        ],
        "downstream": [
            _dependency_item(
                "structured_prd.json, development_plan.json, test_plan.json",
                f"state://projects/{project_id}/projection.json",
                0.8,
                "auto",
            )
        ],
        "code": [
            _dependency_item(
                "orch_gateway.py and gateway_projection.py seams",
                "scripts/lib/orch_gateway.py",
                0.8,
                "inferred",
            )
        ],
    }


def _conflict_items(
    intent_text: str,
    payload: dict[str, Any],
    ticket: dict[str, Any],
    summary_confidence: float,
    manual_review_required: bool,
) -> list[dict[str, Any]]:
    if manual_review_required:
        return [
            {
                "conflict_type": "semantic",
                "severity": "blocking",
                "item": intent_text or "ambiguous intent",
                "resolution_strategy": "request human confirmation and completion criteria",
                **_evidence_meta("request.intent", 0.2, "inferred"),
            }
        ]
    return [
        {
            "conflict_type": "semantic",
            "severity": "info",
            "item": intent_text or "no blocking conflict detected",
            "resolution_strategy": "none",
            **_evidence_meta("request.ticket", max(0.6, summary_confidence), "auto"),
        }
    ]


def _acceptance_matrix(
    intent_text: str,
    acceptance_criteria: list[Any],
    ticket: dict[str, Any],
    summary_confidence: float,
    manual_review_required: bool,
) -> list[dict[str, Any]]:
    matrix: list[dict[str, Any]] = []
    for index, criterion in enumerate(acceptance_criteria, start=1):
        matrix.append(
            {
                "ac_id": f"AC-{index}",
                "criterion": str(criterion),
                "test_script": "scripts/tests/test-completion-bundle-schema.sh" if index == 1 else "manual-review",
                "evidence_type": "auto" if index == 1 and not manual_review_required else "manual",
                **_evidence_meta("request.ticket.acceptance_criteria", max(0.5, summary_confidence), "manual" if manual_review_required else "auto"),
            }
        )
    if not matrix:
        matrix.append(
            {
                "ac_id": "AC-1",
                "criterion": intent_text or "Clarify the requested change",
                "test_script": "scripts/tests/test-completion-bundle-schema.sh",
                "evidence_type": "manual",
                **_evidence_meta("request.intent", 0.25, "inferred"),
            }
        )
    return matrix


def _system_prompt(context: GatewayContext, summary_confidence: float, manual_review_required: bool) -> str:
    project_id = context.get("project_id", "unknown")
    mode = "manual confirmation required" if manual_review_required else "direct execution allowed"
    return f"Produce a six-class requirement completion bundle for {project_id}; {mode}; confidence={summary_confidence:.2f}."


def _user_prompt(intent_text: str, payload: dict[str, Any], ticket: dict[str, Any]) -> str:
    if _normalize_list(ticket.get("acceptance_criteria")):
        return str(ticket.get("goal") or intent_text or payload.get("intent") or "需求补全")
    return str(intent_text or payload.get("intent") or "需求补全")


def _risk_flags(
    payload: dict[str, Any],
    ticket: dict[str, Any],
    summary_confidence: float,
    manual_review_required: bool,
) -> list[dict[str, Any]]:
    flags: list[dict[str, Any]] = []
    if manual_review_required:
        flags.append(
            {
                "flag": "manual_confirmation_required",
                "severity": "blocking",
                "resolution": "collect structured ticket and re-run projection",
                **_evidence_meta("request.intent", 0.2, "inferred"),
            }
        )
    else:
        flags.append(
            {
                "flag": "traceable_completion",
                "severity": "info",
                "resolution": "bundle is ready for downstream stages",
                **_evidence_meta("request.ticket", max(0.6, summary_confidence), "auto"),
            }
        )
    if _normalize_list(ticket.get("hard_constraints")):
        flags.append(
            {
                "flag": "scope_bounded",
                "severity": "info",
                "resolution": "hard constraints preserved in downstream plan",
                **_evidence_meta("request.ticket.hard_constraints", max(0.5, summary_confidence), "manual"),
            }
        )
    elif _first_non_empty_string([payload.get("intent")]):
        flags.append(
            {
                "flag": "ambiguous_intent",
                "severity": "warning",
                "resolution": "clarify acceptance criteria and constraints",
                **_evidence_meta("request.intent", 0.25, "inferred"),
            }
        )
    return flags


def _dependency_item(label: str, source: str, confidence: float, verification_method: str) -> dict[str, Any]:
    return {
        "label": label,
        **_evidence_meta(source, confidence, verification_method),
    }


def _evidence_meta(source: str, confidence: float, verification_method: str) -> dict[str, Any]:
    return {
        "source": source,
        "confidence": round(float(confidence), 2),
        "verification_method": verification_method,
    }


def _normalize_list(value: Any) -> list[Any]:
    return list(value) if isinstance(value, list) and value else []


def _first_non_empty_string(values: list[Any]) -> str:
    for value in values:
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def _source_input_hash(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
