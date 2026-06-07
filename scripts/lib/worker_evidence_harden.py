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


class DAGValidationFailedError(WorkerEvidenceError):
    """Raised when DAG validation result is present but explicitly failed.

    The DAG validator can return a result whose ``valid`` / ``passed`` flag is
    False, an ``errors`` list, a ``cycle_detected`` flag, or a non-empty
    ``back_edges`` list. Any of these signals — even when ``cycles`` is empty
    — must block worker advancement.
    """

    def __init__(self, run_id: str, reason: str, details: Any = None):
        self.reason = reason
        self.details = details
        msg = f"DAG validation failed ({reason}): {details}"
        super().__init__(msg, run_id)


class InvalidEvidenceInputError(WorkerEvidenceError):
    """Raised when a worker advancement evidence input has the wrong type.

    Mirrors the CLI/library contract: validators must reject non-dict inputs
    rather than crash with ``AttributeError`` or treat them as valid.
    """

    def __init__(self, run_id: str, field: str, expected: str, actual: Any):
        self.field = field
        self.expected = expected
        self.actual = actual
        msg = f"Invalid evidence input for {field}: expected {expected}, got {type(actual).__name__}"
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


# Single source of truth for stage requirements. Sprint 8 contract
# (see AGENTS.md / worker-evidence gate) derives all per-stage evidence
# requirements from this map. Adding a new stage here automatically
# participates in DAG / review / commit evidence validation.
STAGE_REQUIREMENTS: dict[str, dict[str, bool]] = {
    "implementation": {
        "dag": True,
        "review": True,
        "commit": True,
    },
    "solution_debate": {
        "dag": True,
        "review": False,
        "commit": False,
    },
    "improvement": {
        "dag": False,
        "review": True,
        "commit": False,
    },
}

# Order in which stages are permitted to advance. Used to detect
# stage_order_violation when a task claims a stage out of order.
STAGE_ORDER: tuple[str, ...] = ("solution_debate", "implementation", "improvement")


# Stages that require DAG validation — derived from STAGE_REQUIREMENTS so the
# single source of truth in this module drives every validator.
DAG_VALIDATION_STAGES: frozenset[str] = frozenset(
    stage for stage, req in STAGE_REQUIREMENTS.items() if req.get("dag")
)

# Stages that require review evidence — also derived from STAGE_REQUIREMENTS.
REVIEW_EVIDENCE_STAGES: frozenset[str] = frozenset(
    stage for stage, req in STAGE_REQUIREMENTS.items() if req.get("review")
)

# Stages that require commit evidence — also derived from STAGE_REQUIREMENTS.
COMMIT_EVIDENCE_STAGES: frozenset[str] = frozenset(
    stage for stage, req in STAGE_REQUIREMENTS.items() if req.get("commit")
)


def _path_in_scope(filepath: str, scope: str) -> bool:
    """Return True when filepath is exactly scope or inside its directory.

    The filepath is required to be a relative POSIX path: absolute paths
    (starting with ``/``), Windows-style backslashes, and traversal segments
    (``..``) are rejected. The scope and filepath are normalized through
    ``posixpath.normpath`` so a scope of ``scripts/lib`` cannot match
    ``scripts/libary/...`` or escape the directory via ``scripts/lib/..``.
    """
    if not isinstance(filepath, str) or not isinstance(scope, str):
        return False
    if not filepath or not scope:
        return False
    # Reject absolute paths and Windows separators.
    if filepath.startswith("/") or "\\" in filepath:
        return False
    if filepath != filepath.strip():
        return False

    import posixpath

    normalized_file = posixpath.normpath(filepath)
    normalized_scope = posixpath.normpath(scope.rstrip("/"))
    if normalized_file.startswith("..") or normalized_scope.startswith(".."):
        return False

    return normalized_file == normalized_scope or normalized_file.startswith(
        f"{normalized_scope}/"
    )


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
    dag_validation_result: Any,
) -> None:
    """Validate DAG validation evidence for stage.

    The ``stage`` argument is normalized internally (strip + lower) so callers
    cannot bypass the stage gate with malformed strings like ``"Implementation "``.

    A DAG result is considered "passed" only when:
    * the result is a dict (not None / not a list / not a string),
    * ``valid`` is True (or ``passed`` is True),
    * ``cycle_detected`` is not True,
    * ``cycles`` is empty,
    * ``back_edges`` is empty, and
    * ``errors`` is empty.

    Any other state — including a dict with ``valid: False`` — raises a
    ``DAGValidationFailedError`` so worker advancement is blocked.

    Raises:
        InvalidEvidenceInputError: If dag_validation_result is not a dict.
        MissingDAGValidationError: If result missing for required stage.
        DAGValidationFailedError: If any failure signal is set.
        DAGCycleDetectedError: If cycles are present.
    """
    stage = _normalize_stage(stage)
    if stage not in DAG_VALIDATION_STAGES:
        return  # DAG validation not required for this stage

    if dag_validation_result is None:
        raise MissingDAGValidationError(run_id, stage)

    if not isinstance(dag_validation_result, dict):
        raise InvalidEvidenceInputError(
            run_id, "dag_validation_result", "dict", dag_validation_result
        )

    # Fail-loud on explicit failure signals. ``valid`` / ``passed`` take
    # precedence and short-circuit; the other signals are checked
    # defensively for validators that use alternative keys.
    valid_flag = dag_validation_result.get("valid")
    passed_flag = dag_validation_result.get("passed")
    if valid_flag is False or passed_flag is False:
        raise DAGValidationFailedError(
            run_id,
            "valid_or_passed_false",
            {"valid": valid_flag, "passed": passed_flag},
        )

    errors = dag_validation_result.get("errors")
    if isinstance(errors, list) and errors:
        raise DAGValidationFailedError(run_id, "errors_non_empty", errors)

    if dag_validation_result.get("cycle_detected") is True:
        raise DAGValidationFailedError(
            run_id, "cycle_detected_true", dag_validation_result.get("cycles", [])
        )

    back_edges = dag_validation_result.get("back_edges")
    if isinstance(back_edges, list) and back_edges:
        raise DAGValidationFailedError(run_id, "back_edges_non_empty", back_edges)

    cycles = dag_validation_result.get("cycles", [])
    if cycles:
        raise DAGCycleDetectedError(run_id, cycles)


def validate_review_evidence(
    run_id: str,
    stage: str,
    review_evidence: Any,
) -> None:
    """Validate review evidence for stage.

    The ``stage`` argument is normalized internally (strip + lower) so callers
    cannot bypass the stage gate with malformed strings. Non-dict evidence
    raises ``InvalidEvidenceInputError`` so the gate is fail-loud.

    Raises MissingReviewEvidenceError if evidence missing for required stage.
    """
    stage = _normalize_stage(stage)
    if stage not in REVIEW_EVIDENCE_STAGES:
        return  # Review evidence not required for this stage

    if review_evidence is None:
        raise MissingReviewEvidenceError(run_id, stage)
    if not isinstance(review_evidence, dict):
        raise InvalidEvidenceInputError(
            run_id, "review_evidence", "dict", review_evidence
        )


def validate_commit_evidence(
    run_id: str,
    stage: str,
    commit_evidence: Any,
) -> None:
    """Validate commit evidence for stage.

    The ``stage`` argument is normalized internally (strip + lower) so callers
    cannot bypass the stage gate with malformed strings. Non-dict evidence
    raises ``InvalidEvidenceInputError`` so the gate is fail-loud.

    Raises MissingCommitEvidenceError if evidence missing for required stage.
    """
    stage = _normalize_stage(stage)
    if stage not in COMMIT_EVIDENCE_STAGES:
        return  # Commit evidence not required for this stage

    if commit_evidence is None:
        raise MissingCommitEvidenceError(run_id, stage)
    if not isinstance(commit_evidence, dict):
        raise InvalidEvidenceInputError(
            run_id, "commit_evidence", "dict", commit_evidence
        )


def _normalize_stage(stage: Any) -> str:
    """Normalize a stage string to a canonical lower-case form.

    Empty / non-string / whitespace-only stages are returned as ``""`` so
    downstream checks can fail-loud on ``unknown_stage``.
    """
    if not isinstance(stage, str):
        return ""
    return stage.strip().lower()


def validate_worker_advancement(
    run: Any,
    task: Any,
    actual_changed_files: Any,
) -> list[str]:
    """Validate all worker advancement evidence.

    Returns list of validation errors. Empty list means valid.

    The CLI / library contract requires that non-dict ``run`` or ``task``
    inputs produce an ``invalid_evidence_input`` error rather than a
    ``TypeError`` from attribute access. The same applies to
    ``actual_changed_files``: it must be an iterable of strings.
    """
    # Guard against non-dict envelope at the CLI boundary.
    if not isinstance(run, dict) or not isinstance(task, dict):
        return [f"invalid_evidence_input: run/task must be dict (got {type(run).__name__}/{type(task).__name__})"]
    if not isinstance(actual_changed_files, list):
        return ["invalid_evidence_input: actual_changed_files must be a list"]

    run_id = run.get("run_id", "unknown")
    raw_stage = task.get("current_stage", run.get("current_stage", ""))
    stage = _normalize_stage(raw_stage)
    expected_scope = task.get("write_scope", [])
    dag_result = task.get("dag_validation_result")
    review_evidence = task.get("review_evidence")
    commit_evidence = task.get("commit_evidence")

    errors: list[str] = []

    # Stage normalization: surface unknown / missing stages explicitly.
    if not stage:
        errors.append(f"missing_current_stage: run_id={run_id}")
    elif stage not in STAGE_REQUIREMENTS:
        errors.append(f"unknown_stage: {stage!r}")

    # Validate write scope
    try:
        validate_write_scope(run_id, expected_scope, actual_changed_files)
    except WriteScopeViolationError as e:
        errors.append(f"write_scope_violation: {e.violating_files}")
    except InvalidEvidenceInputError as e:
        errors.append(f"invalid_evidence_input: {e.field} {e.expected} {type(e.actual).__name__}")

    # Validate DAG evidence
    try:
        validate_dag_evidence(run_id, stage, dag_result)
    except MissingDAGValidationError as e:
        errors.append(f"missing_dag_validation: {e.stage}")
    except DAGCycleDetectedError as e:
        errors.append(f"dag_cycle_detected: {e.cycles}")
    except DAGValidationFailedError as e:
        errors.append(f"dag_validation_failed: {e.reason}")
    except InvalidEvidenceInputError as e:
        errors.append(f"invalid_evidence_input: {e.field} {e.expected} {type(e.actual).__name__}")

    # Validate review evidence
    try:
        validate_review_evidence(run_id, stage, review_evidence)
    except MissingReviewEvidenceError as e:
        errors.append(f"missing_review_evidence: {e.stage}")
    except InvalidEvidenceInputError as e:
        errors.append(f"invalid_evidence_input: {e.field} {e.expected} {type(e.actual).__name__}")

    # Validate commit evidence
    try:
        validate_commit_evidence(run_id, stage, commit_evidence)
    except MissingCommitEvidenceError as e:
        errors.append(f"missing_commit_evidence: {e.stage}")
    except InvalidEvidenceInputError as e:
        errors.append(f"invalid_evidence_input: {e.field} {e.expected} {type(e.actual).__name__}")

    return errors
