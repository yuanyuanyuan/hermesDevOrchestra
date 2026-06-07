#!/usr/bin/env python3
"""Worker Evidence Hardening for PRD Compliance.

Makes Gateway consume computed write scope, actual changes, DAG validation,
review evidence, and commit evidence before stage advancement.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


class WorkerEvidenceError(Exception):
    """Base class for worker evidence errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class WriteScopeViolationError(WorkerEvidenceError):
    """Raised when changed files exceed expected write scope."""

    def __init__(self, run_id: str, violating_files: list[str], expected_scope: list[str]):
        self.violating_files = violating_files
        self.expected_scope = expected_scope
        msg = f"Write scope violation: files {violating_files} outside expected scope"
        super().__init__(msg, run_id)


class MissingDAGValidationError(WorkerEvidenceError):
    """Raised when DAG validation result is missing."""

    def __init__(self, run_id: str, stage: str):
        self.stage = stage
        msg = f"Missing DAG validation result for stage: {stage}"
        super().__init__(msg, run_id)


class DAGCycleDetectedError(WorkerEvidenceError):
    """Raised when DAG validation detects cycles."""

    def __init__(self, run_id: str, cycles: list[list[str]]):
        self.cycles = cycles
        msg = f"DAG cycle detected: {cycles}"
        super().__init__(msg, run_id)


class MissingReviewEvidenceError(WorkerEvidenceError):
    """Raised when review evidence is missing."""

    def __init__(self, run_id: str, stage: str):
        self.stage = stage
        msg = f"Missing review evidence for stage: {stage}"
        super().__init__(msg, run_id)


class MissingCommitEvidenceError(WorkerEvidenceError):
    """Raised when commit evidence is missing."""

    def __init__(self, run_id: str, stage: str):
        self.stage = stage
        msg = f"Missing commit evidence for stage: {stage}"
        super().__init__(msg, run_id)


# Stages that require DAG validation
DAG_VALIDATION_STAGES = {"solution_debate", "implementation"}

# Stages that require review evidence
REVIEW_EVIDENCE_STAGES = {"implementation", "improvement"}

# Stages that require commit evidence
COMMIT_EVIDENCE_STAGES = {"implementation"}


def _path_in_scope(filepath: str, scope: str) -> bool:
    """Return True when filepath is exactly scope or inside its directory."""
    normalized_file = filepath.lstrip("./")
    normalized_scope = scope.lstrip("./").rstrip("/")
    return normalized_file == normalized_scope or normalized_file.startswith(f"{normalized_scope}/")


def validate_write_scope(
    run_id: str,
    expected_scope: list[str],
    actual_changed_files: list[str],
) -> None:
    """Validate that actual changed files are within expected write scope.

    Raises WriteScopeViolationError if any file is outside expected scope.
    Fails closed when no scope is declared: an undefined scope is treated as a
    security violation rather than a permissive default.
    """
    if not expected_scope:
        raise WriteScopeViolationError(run_id, list(actual_changed_files), [])

    violating = []
    for filepath in actual_changed_files:
        # Check if file is in expected scope
        if not any(_path_in_scope(filepath, scope) for scope in expected_scope):
            violating.append(filepath)

    if violating:
        raise WriteScopeViolationError(run_id, violating, expected_scope)


def validate_dag_evidence(
    run_id: str,
    stage: str,
    dag_validation_result: dict[str, Any] | None,
) -> None:
    """Validate DAG validation evidence for stage.

    Raises MissingDAGValidationError if result missing for required stage.
    Raises DAGCycleDetectedError if cycles detected.
    """
    if stage not in DAG_VALIDATION_STAGES:
        return  # DAG validation not required for this stage

    if not dag_validation_result:
        raise MissingDAGValidationError(run_id, stage)

    # Check for cycles
    cycles = dag_validation_result.get("cycles", [])
    if cycles:
        raise DAGCycleDetectedError(run_id, cycles)


def validate_review_evidence(
    run_id: str,
    stage: str,
    review_evidence: dict[str, Any] | None,
) -> None:
    """Validate review evidence for stage.

    Raises MissingReviewEvidenceError if evidence missing for required stage.
    """
    if stage not in REVIEW_EVIDENCE_STAGES:
        return  # Review evidence not required for this stage

    if not review_evidence:
        raise MissingReviewEvidenceError(run_id, stage)


def validate_commit_evidence(
    run_id: str,
    stage: str,
    commit_evidence: dict[str, Any] | None,
) -> None:
    """Validate commit evidence for stage.

    Raises MissingCommitEvidenceError if evidence missing for required stage.
    """
    if stage not in COMMIT_EVIDENCE_STAGES:
        return  # Commit evidence not required for this stage

    if not commit_evidence:
        raise MissingCommitEvidenceError(run_id, stage)


def validate_worker_advancement(
    run: dict[str, Any],
    task: dict[str, Any],
    actual_changed_files: list[str],
) -> list[str]:
    """Validate all worker advancement evidence.

    Returns list of validation errors. Empty list means valid.
    """
    run_id = run.get("run_id", "unknown")
    stage = task.get("current_stage", run.get("current_stage", ""))
    expected_scope = task.get("write_scope", [])
    dag_result = task.get("dag_validation_result")
    review_evidence = task.get("review_evidence")
    commit_evidence = task.get("commit_evidence")

    errors = []

    # Validate write scope
    try:
        validate_write_scope(run_id, expected_scope, actual_changed_files)
    except WriteScopeViolationError as e:
        errors.append(f"write_scope_violation: {e.violating_files}")

    # Validate DAG evidence
    try:
        validate_dag_evidence(run_id, stage, dag_result)
    except MissingDAGValidationError as e:
        errors.append(f"missing_dag_validation: {e.stage}")
    except DAGCycleDetectedError as e:
        errors.append(f"dag_cycle_detected: {e.cycles}")

    # Validate review evidence
    try:
        validate_review_evidence(run_id, stage, review_evidence)
    except MissingReviewEvidenceError as e:
        errors.append(f"missing_review_evidence: {e.stage}")

    # Validate commit evidence
    try:
        validate_commit_evidence(run_id, stage, commit_evidence)
    except MissingCommitEvidenceError as e:
        errors.append(f"missing_commit_evidence: {e.stage}")

    return errors
