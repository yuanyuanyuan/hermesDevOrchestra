#!/usr/bin/env python3
"""Worker Source Isolation for PRD Compliance.

Enforces that review, audit, and cross_check workers are not sourced from
the same model/source as the upper-level adjudicator.

Integration: Gateway worker-session creation should call create_worker_session
before dispatching review, audit, or cross_check workers.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4


# Valid model sources. Provider names ("openai", "anthropic") and product
# aliases ("codex", "claude") are both accepted so callers can record either
# the vendor-level source or the concrete worker surface.
VALID_MODEL_SOURCES = {
    "kimi", "claude", "codex", "human", "openai", "anthropic", "other"
}

SOURCE_ALIASES = {
    "claude": "anthropic",
    "anthropic": "anthropic",
    "codex": "openai",
    "openai": "openai",
    "kimi": "kimi",
    "human": "human",
    "other": "other",
}

# All supported worker roles.
ALL_ROLES = {"implementer", "reviewer", "auditor", "cross_checker"}

# The implementer is the only role that does not require adjudicator isolation.
ISOLATED_ROLES = ALL_ROLES - {"implementer"}


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
        self.code = "source_isolation_violation"
        self.source_isolation_status = "rejected"
        msg = f"Source isolation violation (code: source_isolation_violation): {role} worker source '{worker_source}' matches adjudicator source '{adjudicator_source}'"
        super().__init__(msg, run_id)


class MissingModelSourceError(SourceIsolationError):
    """Raised when model_source is missing for isolated role."""

    def __init__(self, run_id: str, role: str):
        self.role = role
        msg = f"Missing model_source for {role} worker"
        super().__init__(msg, run_id)


class MissingAdjudicatorSourceError(SourceIsolationError):
    """Raised when adjudicator_source is missing for isolated role."""

    def __init__(self, run_id: str, role: str):
        self.role = role
        msg = f"Missing adjudicator_source for {role} worker"
        super().__init__(msg, run_id)


class UnknownSourceError(SourceIsolationError):
    """Raised when a model source is unknown and not configured as 'other'."""

    def __init__(self, run_id: str, source: Any, field_name: str = "model_source"):
        self.source = source
        self.field_name = field_name
        msg = f"Unknown {field_name}: {source}"
        super().__init__(msg, run_id)


def validate_model_source(source: Any) -> bool:
    """Validate that model_source is valid."""
    return isinstance(source, str) and source in VALID_MODEL_SOURCES


def normalize_model_source(source: str) -> str:
    """Normalize model source aliases to provider-level source."""
    return SOURCE_ALIASES[source]


def get_adjudicator_source(run: dict[str, Any], task: dict[str, Any] | None = None) -> str | None:
    """Get the adjudicator source from run or task context."""
    # Check task first, then run
    if task and task.get("adjudicator_source") is not None:
        return task["adjudicator_source"]
    if "adjudicator_source" in run:
        return run["adjudicator_source"]
    return None


def check_worker_source_isolation(
    run_id: str,
    worker_source: str,
    adjudicator_source: str | None,
    role: str,
) -> None:
    """Check if worker source violates isolation with adjudicator.

    Raises SourceIsolationViolationError if isolation is violated.
    """
    if role not in ALL_ROLES:
        raise ValueError(f"Invalid role: {role}")

    if role not in ISOLATED_ROLES:
        return  # No isolation check needed for non-isolated roles

    if not validate_model_source(worker_source):
        raise UnknownSourceError(run_id, worker_source)

    if adjudicator_source is None:
        raise MissingAdjudicatorSourceError(run_id, role)

    if not validate_model_source(adjudicator_source):
        raise UnknownSourceError(run_id, adjudicator_source, "adjudicator_source")

    if normalize_model_source(worker_source) == normalize_model_source(adjudicator_source):
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

    Isolation failures raise before session creation; rejected sessions are not
    returned. Non-isolated roles emit source_isolation_status="degraded" with
    a reason because no isolation check is required for that role.

    Raises:
        MissingModelSourceError: If model_source missing for isolated role
        UnknownSourceError: If model_source unknown
        SourceIsolationViolationError: If source isolation violated
    """
    # Validate role
    if role not in ALL_ROLES:
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
        check_worker_source_isolation(run_id, model_source, adjudicator_source, role)

    # Create session
    isolation_required = role in ISOLATED_ROLES
    session = {
        "session_id": f"session-{run_id}-{task_id}-{worker_id}-{uuid4().hex[:8]}",
        "run_id": run_id,
        "task_id": task_id,
        "worker_id": worker_id,
        "role": role,
        "model_source": model_source,
        "source_isolation_status": "passed" if isolation_required else "degraded",
        "source_isolation_reason": "source_isolation_passed" if isolation_required else "not_required_for_role",
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

    if "role" in session and session["role"] not in ALL_ROLES:
        errors.append(f"Invalid role: {session['role']}")

    if "model_source" in session and not validate_model_source(session["model_source"]):
        errors.append(f"Unknown model_source: {session['model_source']}")

    if "source_isolation_status" in session and session["source_isolation_status"] not in {"passed", "rejected", "degraded"}:
        errors.append(f"Invalid source_isolation_status: {session['source_isolation_status']}")

    return errors
