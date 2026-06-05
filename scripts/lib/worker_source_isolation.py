#!/usr/bin/env python3
"""Worker Source Isolation for PRD Compliance.

Enforces that review, audit, and cross_check workers are not sourced from
the same model/source as the upper-level adjudicator.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


# Valid model sources
VALID_MODEL_SOURCES = {
    "kimi", "claude", "codex", "human", "openai", "anthropic", "other"
}

# Roles that require source isolation
ISOLATED_ROLES = {"reviewer", "auditor", "cross_checker"}


class SourceIsolationError(Exception):
    """Base class for source isolation errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class SourceIsolationViolationError(SourceIsolationError):
    """Raised when source isolation is violated."""

    def __init__(self, run_id: str, worker_source: str, adjudicator_source: str, role: str):
        self.worker_source = worker_source
        self.adjudicator_source = adjudicator_source
        self.role = role
        msg = f"Source isolation violation: {role} worker source '{worker_source}' matches adjudicator source '{adjudicator_source}'"
        super().__init__(msg, run_id)


class MissingModelSourceError(SourceIsolationError):
    """Raised when model_source is missing for isolated role."""

    def __init__(self, run_id: str, role: str):
        self.role = role
        msg = f"Missing model_source for {role} worker"
        super().__init__(msg, run_id)


class UnknownSourceError(SourceIsolationError):
    """Raised when model_source is unknown and not configured as 'other'."""

    def __init__(self, run_id: str, source: str):
        self.source = source
        msg = f"Unknown model_source: {source}"
        super().__init__(msg, run_id)


def validate_model_source(source: str) -> bool:
    """Validate that model_source is valid."""
    return source in VALID_MODEL_SOURCES


def get_adjudicator_source(run: dict[str, Any], task: dict[str, Any] | None = None) -> str | None:
    """Get the adjudicator source from run or task context."""
    # Check task first, then run
    if task and "adjudicator_source" in task:
        return task["adjudicator_source"]
    if "adjudicator_source" in run:
        return run["adjudicator_source"]
    return None


def check_source_isolation(
    run_id: str,
    worker_source: str,
    adjudicator_source: str | None,
    role: str,
) -> None:
    """Check if worker source violates isolation with adjudicator.

    Raises SourceIsolationViolationError if isolation is violated.
    """
    if role not in ISOLATED_ROLES:
        return  # No isolation check needed for non-isolated roles

    if adjudicator_source is None:
        return  # No adjudicator source to compare against

    if worker_source == adjudicator_source:
        raise SourceIsolationViolationError(run_id, worker_source, adjudicator_source, role)


def create_worker_session(
    run_id: str,
    task_id: str,
    worker_id: str,
    role: str,
    model_source: str,
    run: dict[str, Any],
    task: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create a worker session with source isolation validation.

    Raises:
        MissingModelSourceError: If model_source missing for isolated role
        UnknownSourceError: If model_source unknown
        SourceIsolationViolationError: If source isolation violated
    """
    # Validate role
    if role not in {"implementer", "reviewer", "auditor", "cross_checker"}:
        raise ValueError(f"Invalid role: {role}")

    # Check model_source for isolated roles
    if role in ISOLATED_ROLES:
        if not model_source:
            raise MissingModelSourceError(run_id, role)

        if not validate_model_source(model_source):
            raise UnknownSourceError(run_id, model_source)

        # Get adjudicator source
        adjudicator_source = get_adjudicator_source(run, task)

        # Check source isolation
        check_source_isolation(run_id, model_source, adjudicator_source, role)

    # Create session
    session = {
        "session_id": f"session-{run_id}-{task_id}-{worker_id}",
        "run_id": run_id,
        "task_id": task_id,
        "worker_id": worker_id,
        "role": role,
        "model_source": model_source,
        "source_isolation_status": "passed" if role in ISOLATED_ROLES else "not_applicable",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    return session


def validate_worker_session(session: dict[str, Any]) -> list[str]:
    """Validate worker session structure.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []

    required_fields = ["session_id", "run_id", "task_id", "worker_id", "role", "model_source"]
    for field in required_fields:
        if field not in session:
            errors.append(f"{field} missing")

    if "role" in session and session["role"] not in {"implementer", "reviewer", "auditor", "cross_checker"}:
        errors.append(f"Invalid role: {session['role']}")

    if "model_source" in session and not validate_model_source(session["model_source"]):
        errors.append(f"Unknown model_source: {session['model_source']}")

    return errors
