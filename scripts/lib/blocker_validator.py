#!/usr/bin/env python3
"""Validate requirement completion bundles and block on missing fields."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any, TypedDict


class ValidationResult(TypedDict, total=False):
    """Validation result for requirement completion bundles."""

    status: str
    missing_fields: list[str]
    reason: str


REQUIRED_TOP_LEVEL_FIELDS = (
    "intent_summary",
    "dependency_graph",
    "conflict_list",
    "acceptance_matrix",
    "prompt_envelope",
    "risk_flags",
)


def validate(bundle: dict[str, Any]) -> ValidationResult:
    missing_fields: list[str] = []
    if not isinstance(bundle, dict):
        return {"status": "blocked", "missing_fields": list(REQUIRED_TOP_LEVEL_FIELDS), "reason": "bundle must be an object"}
    if bundle.get("artifact_type") != "requirement_completion_bundle":
        missing_fields.append("artifact_type")
    for field in REQUIRED_TOP_LEVEL_FIELDS:
        value = bundle.get(field)
        if _is_empty(value):
            missing_fields.append(field)
    if not _is_empty(bundle.get("intent_summary")):
        summary = bundle["intent_summary"]
        if _is_empty(summary.get("source_input_hash")):
            missing_fields.append("intent_summary.source_input_hash")
        if _is_empty(summary.get("projection_timestamp")):
            missing_fields.append("intent_summary.projection_timestamp")
        if _is_empty(summary.get("conclusions")):
            missing_fields.append("intent_summary.conclusions")
    if not _is_empty(bundle.get("dependency_graph")):
        graph = bundle["dependency_graph"]
        if _is_empty(graph.get("source_input_hash")):
            missing_fields.append("dependency_graph.source_input_hash")
        if _is_empty(graph.get("projection_timestamp")):
            missing_fields.append("dependency_graph.projection_timestamp")
        dimensions = graph.get("dimensions") if isinstance(graph.get("dimensions"), dict) else {}
        for name in ("environment", "upstream", "downstream", "code"):
            if _is_empty(dimensions.get(name)):
                missing_fields.append(f"dependency_graph.dimensions.{name}")
    for field in ("conflict_list", "acceptance_matrix", "risk_flags"):
        if not _is_empty(bundle.get(field)):
            section = bundle[field]
            if _is_empty(section.get("source_input_hash")):
                missing_fields.append(f"{field}.source_input_hash")
            if _is_empty(section.get("projection_timestamp")):
                missing_fields.append(f"{field}.projection_timestamp")
            if _is_empty(section.get("items")):
                missing_fields.append(f"{field}.items")
    if not _is_empty(bundle.get("prompt_envelope")):
        prompt = bundle["prompt_envelope"]
        for key in ("source_input_hash", "projection_timestamp", "system_prompt", "user_prompt", "context_window_budget", "output_schema_ref"):
            if _is_empty(prompt.get(key)):
                missing_fields.append(f"prompt_envelope.{key}")
    if not missing_fields:
        return {"status": "passed", "missing_fields": []}
    return {"status": "blocked", "missing_fields": sorted(set(missing_fields)), "reason": "bundle is missing required completion fields"}


def _is_empty(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, str):
        return not value.strip()
    if isinstance(value, dict):
        return not value
    if isinstance(value, list):
        return not value
    return False


def _sample_bundle() -> dict[str, Any]:
    return {
        "schema_version": "orchestra.v1",
        "artifact_type": "requirement_completion_bundle",
        "run_id": "run-sample",
        "intent_summary": {
            "source_input_hash": "0" * 64,
            "projection_timestamp": "2026-06-01T00:00:00Z",
            "conclusions": [
                {
                    "text": "sample intent",
                    "source": "request.intent",
                    "confidence": 0.9,
                    "verification_method": "manual",
                }
            ],
        },
        "dependency_graph": {
            "source_input_hash": "0" * 64,
            "projection_timestamp": "2026-06-01T00:00:00Z",
            "format": "adjacency_list",
            "dimensions": {
                "environment": [{"label": "runtime", "source": "project-profile.yaml", "confidence": 0.8, "verification_method": "auto"}],
                "upstream": [{"label": "request", "source": "request.payload", "confidence": 0.8, "verification_method": "inferred"}],
                "downstream": [{"label": "structured_prd", "source": "state://runs/run-sample/projection.json", "confidence": 0.8, "verification_method": "auto"}],
                "code": [{"label": "orch_gateway", "source": "scripts/lib/orch_gateway.py", "confidence": 0.8, "verification_method": "inferred"}],
            },
        },
        "conflict_list": {
            "source_input_hash": "0" * 64,
            "projection_timestamp": "2026-06-01T00:00:00Z",
            "items": [
                {
                    "conflict_type": "semantic",
                    "severity": "info",
                    "item": "none",
                    "resolution_strategy": "none",
                    "source": "request.intent",
                    "confidence": 0.8,
                    "verification_method": "auto",
                }
            ],
        },
        "acceptance_matrix": {
            "source_input_hash": "0" * 64,
            "projection_timestamp": "2026-06-01T00:00:00Z",
            "items": [
                {
                    "ac_id": "AC-1",
                    "criterion": "sample criterion",
                    "test_script": "scripts/tests/test-completion-bundle-schema.sh",
                    "evidence_type": "auto",
                    "source": "request.ticket.acceptance_criteria",
                    "confidence": 0.9,
                    "verification_method": "manual",
                }
            ],
        },
        "prompt_envelope": {
            "source_input_hash": "0" * 64,
            "projection_timestamp": "2026-06-01T00:00:00Z",
            "system_prompt": "sample system prompt",
            "user_prompt": "sample user prompt",
            "context_window_budget": 128000,
            "output_schema_ref": "config/schemas/orchestra.full.schema.json#/$defs/requirement_completion_bundle",
        },
        "risk_flags": {
            "source_input_hash": "0" * 64,
            "projection_timestamp": "2026-06-01T00:00:00Z",
            "items": [
                {
                    "flag": "traceable_completion",
                    "severity": "info",
                    "resolution": "none",
                    "source": "request.ticket",
                    "confidence": 0.9,
                    "verification_method": "auto",
                }
            ],
        },
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-file")
    parser.add_argument("--test-missing-field")
    args = parser.parse_args(argv)

    if args.test_missing_field:
        bundle = _sample_bundle()
        bundle.pop(args.test_missing_field, None)
        result = validate(bundle)
        print(json.dumps(result, ensure_ascii=False))
        return 1 if result["status"] == "blocked" else 0

    if not args.bundle_file:
        parser.error("--bundle-file is required unless --test-missing-field is used")

    bundle = json.loads(open(args.bundle_file, encoding="utf-8").read())
    result = validate(bundle)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
