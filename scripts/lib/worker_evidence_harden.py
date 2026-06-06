#!/usr/bin/env python3
"""Worker Evidence Hardening for PRD Compliance.

Makes Gateway consume computed write scope, actual changes, DAG validation,
review evidence, and commit evidence before stage advancement.

This module is a worker advancement gate. It intentionally complements the
gateway-level write_scope_validator and completion-level evidence_gate modules:
those validate dispatch/completion payloads, while this module validates the
stage advancement evidence bundle assembled from worker output and task state.
"""

from __future__ import annotations

from pathlib import PurePosixPath
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


class InvalidEvidenceInputError(WorkerEvidenceError):
    """Raised when evidence input has an invalid shape or type."""

    def __init__(self, run_id: str, field: str, expected: str):
        self.field = field
        self.expected = expected
        msg = f"Invalid evidence input: {field} must be {expected}"
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


class DAGValidationFailedError(WorkerEvidenceError):
    """Raised when DAG validation reports a non-cycle failure."""

    def __init__(self, run_id: str, errors: list[str]):
        self.errors = errors
        msg = f"DAG validation failed: {errors}"
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
REVIEW_EVIDENCE_STAGES = {"implementation", "improvement", "global_evaluation"}

# Stages that require commit evidence
COMMIT_EVIDENCE_STAGES = {"implementation"}

SCOPE_REQUIRED_STAGES = DAG_VALIDATION_STAGES | REVIEW_EVIDENCE_STAGES | COMMIT_EVIDENCE_STAGES


def validate_write_scope(
    run_id: str,
    expected_scope: list[str],
    actual_changed_files: list[str],
) -> None:
    """Validate that actual changed files are within expected write scope.

    An empty expected_scope is intentionally permissive and means no scope was
    configured for this task; callers that require strict scoping must provide
    at least one scope prefix.

    Raises WriteScopeViolationError if any file is outside expected scope.
    """
    if not isinstance(expected_scope, list) or not all(isinstance(scope, str) for scope in expected_scope):
        raise InvalidEvidenceInputError(run_id, "expected_scope", "a list of strings")
    if not isinstance(actual_changed_files, list) or not all(isinstance(path, str) for path in actual_changed_files):
        raise InvalidEvidenceInputError(run_id, "actual_changed_files", "a list of strings")

    if not expected_scope:
        return  # No scope defined, allow all

    normalized_scope = [_normalize_relative_path(scope) for scope in expected_scope]
    violating = []
    for filepath in actual_changed_files:
        normalized = _normalize_relative_path(filepath)
        # Check if file is in expected scope
        if not any(_path_in_scope(normalized, scope) for scope in normalized_scope):
            violating.append(filepath)

    if violating:
        raise WriteScopeViolationError(run_id, violating, expected_scope)


def _normalize_relative_path(path: str) -> str:
    parts = PurePosixPath(path).parts
    if path.startswith("/") or ".." in parts:
        return "__invalid_path__"
    normalized = PurePosixPath(path).as_posix()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized.rstrip("/")


def _path_in_scope(path: str, scope: str) -> bool:
    return path == scope or path.startswith(f"{scope}/")


def validate_dag_evidence(
    run_id: str,
    stage: str,
    dag_validation_result: dict[str, Any] | None,
) -> None:
    """Validate DAG validation evidence for stage.

    Raises MissingDAGValidationError if result missing for required stage.
    Raises DAGCycleDetectedError if cycles detected.
    Raises DAGValidationFailedError if DAG validation failed without cycles.
    """
    if stage not in DAG_VALIDATION_STAGES:
        return  # DAG validation not required for this stage

    if not dag_validation_result:
        raise MissingDAGValidationError(run_id, stage)
    if not isinstance(dag_validation_result, dict):
        raise InvalidEvidenceInputError(run_id, "dag_validation_result", "a dictionary")

    # Accept both this module's original schema and dag_validator.validate_dag output.
    cycles = dag_validation_result.get("cycles") or dag_validation_result.get("back_edges") or []
    if not isinstance(cycles, list):
        raise InvalidEvidenceInputError(run_id, "dag_validation_result.cycles", "a list")
    cycle_detected = dag_validation_result.get("cycle_detected", bool(cycles))
    if cycle_detected or cycles:
        raise DAGCycleDetectedError(run_id, cycles)

    result_valid = dag_validation_result.get("valid", dag_validation_result.get("passed", True))
    if result_valid is False:
        errors = dag_validation_result.get("errors") or ["invalid_dag_result"]
        if not isinstance(errors, list):
            errors = [str(errors)]
        raise DAGValidationFailedError(run_id, [str(error) for error in errors])


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

    Error strings are the API contract for shell/gateway callers. Typed
    exceptions remain available from the lower-level validation functions.

    Error strings use the stable format "<code>: <payload>", where code is one
    of: missing_current_stage, invalid_evidence_input, missing_write_scope,
    write_scope_violation, missing_dag_validation, dag_cycle_detected,
    dag_validation_failed, missing_review_evidence, missing_commit_evidence.
    Payloads are human-readable strings; list payloads use Python list repr.

    Returns list of validation errors. Empty list means valid.
    """
    run_id = run.get("run_id", "unknown")
    stage = task.get("current_stage", run.get("current_stage", ""))
    expected_scope = task.get("write_scope", [])
    scope_unrestricted = task.get("write_scope_unrestricted") is True
    dag_result = task.get("dag_validation_result")
    review_evidence = task.get("review_evidence")
    commit_evidence = task.get("commit_evidence")

    errors = []

    if not isinstance(stage, str) or not stage:
        return ["missing_current_stage: current_stage"]

    # Validate write scope
    if not expected_scope and stage in SCOPE_REQUIRED_STAGES and not scope_unrestricted:
        errors.append(f"missing_write_scope: {stage}")
    else:
        try:
            validate_write_scope(run_id, expected_scope, actual_changed_files)
        except InvalidEvidenceInputError as e:
            errors.append(f"invalid_evidence_input: {e.field}")
        except WriteScopeViolationError as e:
            errors.append(f"write_scope_violation: files={e.violating_files}; expected_scope={e.expected_scope}")

    # Validate DAG evidence
    try:
        validate_dag_evidence(run_id, stage, dag_result)
    except InvalidEvidenceInputError as e:
        errors.append(f"invalid_evidence_input: {e.field}")
    except MissingDAGValidationError as e:
        errors.append(f"missing_dag_validation: {e.stage}")
    except DAGCycleDetectedError as e:
        errors.append(f"dag_cycle_detected: {e.cycles}")
    except DAGValidationFailedError as e:
        errors.append(f"dag_validation_failed: {e.errors}")

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
