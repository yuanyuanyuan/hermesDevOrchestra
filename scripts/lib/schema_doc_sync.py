#!/usr/bin/env python3
"""Schema, Docs, and Success Metrics Sync for PRD Compliance.

Synchronizes schema/docs/metrics for all remediation artifacts before final e2e audit.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


# Required success metrics from PRD
REQUIRED_SUCCESS_METRICS = {
    "conflict_gate_block_rate",
    "rollback_traceability",
    "channel_escape_accuracy",
    "source_isolation_enforced",
    "strict_audit_green",
}

# Required artifact definitions in schema
REQUIRED_ARTIFACT_DEFINITIONS = {
    "conflict_ledger",
    "rollback_report",
    "channel_decision",
    "worker_session_record",
    "override_record",
    "global_evaluation_report",
}


class SchemaSyncError(Exception):
    """Base class for schema sync errors."""

    def __init__(self, message: str):
        super().__init__(message)


class MissingSuccessMetricError(SchemaSyncError):
    """Raised when success metric is missing."""

    def __init__(self, metric_name: str):
        self.metric_name = metric_name
        msg = f"Missing success metric: {metric_name}"
        super().__init__(msg)


class MissingArtifactDefinitionError(SchemaSyncError):
    """Raised when artifact definition is missing in schema."""

    def __init__(self, artifact_name: str):
        self.artifact_name = artifact_name
        msg = f"Missing artifact definition in schema: {artifact_name}"
        super().__init__(msg)


class SchemaDocMismatchError(SchemaSyncError):
    """Raised when schema and docs are mismatched."""

    def __init__(self, mismatches: list[str]):
        self.mismatches = mismatches
        msg = f"Schema-doc mismatches: {', '.join(mismatches)}"
        super().__init__(msg)


def validate_success_metrics(metrics: dict[str, Any]) -> list[str]:
    """Validate that all required success metrics are present.

    Returns list of missing metrics. Empty list means all present.
    """
    missing = []
    for metric in REQUIRED_SUCCESS_METRICS:
        if metric not in metrics:
            missing.append(metric)
    return missing


def validate_artifact_definitions(schema: dict[str, Any]) -> list[str]:
    """Validate that all required artifact definitions are in schema.

    Returns list of missing artifacts. Empty list means all present.
    """
    missing = []
    defs = schema.get("$defs", {})

    for artifact in REQUIRED_ARTIFACT_DEFINITIONS:
        if artifact not in defs:
            missing.append(artifact)

    return missing


def sync_schema_with_docs(
    schema: dict[str, Any],
    docs: dict[str, Any],
) -> list[str]:
    """Synchronize schema with documentation.

    Returns list of mismatches. Empty list means synchronized.
    """
    mismatches = []

    # Check that all schema artifacts have doc sections
    schema_artifacts = set(schema.get("$defs", {}).keys())
    doc_artifacts = set(docs.get("artifacts", {}).keys())

    for artifact in schema_artifacts:
        if artifact not in doc_artifacts and artifact in REQUIRED_ARTIFACT_DEFINITIONS:
            mismatches.append(f"missing_doc_section: {artifact}")

    # Check that all doc artifacts are in schema
    for artifact in doc_artifacts:
        if artifact not in schema_artifacts:
            mismatches.append(f"missing_schema_definition: {artifact}")

    return mismatches


def create_sync_report(
    schema: dict[str, Any],
    docs: dict[str, Any],
    metrics: dict[str, Any],
) -> dict[str, Any]:
    """Create a schema/docs/metrics sync report."""
    missing_metrics = validate_success_metrics(metrics)
    missing_artifacts = validate_artifact_definitions(schema)
    mismatches = sync_schema_with_docs(schema, docs)

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "success_metrics": {
            "required": list(REQUIRED_SUCCESS_METRICS),
            "present": list(set(REQUIRED_SUCCESS_METRICS) - set(missing_metrics)),
            "missing": missing_metrics,
        },
        "artifact_definitions": {
            "required": list(REQUIRED_ARTIFACT_DEFINITIONS),
            "present": list(set(REQUIRED_ARTIFACT_DEFINITIONS) - set(missing_artifacts)),
            "missing": missing_artifacts,
        },
        "schema_doc_sync": {
            "mismatches": mismatches,
            "synchronized": len(mismatches) == 0,
        },
        "all_synced": len(missing_metrics) == 0 and len(missing_artifacts) == 0 and len(mismatches) == 0,
    }


def validate_sync_report(report: dict[str, Any]) -> list[str]:
    """Validate sync report structure.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []

    required_sections = ["success_metrics", "artifact_definitions", "schema_doc_sync"]
    for section in required_sections:
        if section not in report:
            errors.append(f"{section} missing")

    if "all_synced" not in report:
        errors.append("all_synced missing")

    return errors
