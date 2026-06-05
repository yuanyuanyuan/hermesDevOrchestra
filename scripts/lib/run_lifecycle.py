#!/usr/bin/env python3
"""PRD Run Lifecycle State Machine.

Implements explicit lifecycle states and guarded transitions for runs.
"""

from __future__ import annotations

from typing import Any

# PRD Lifecycle States
LIFECYCLE_STATES = {
    "created",
    "intake_complete",
    "direction_debate",
    "solution_debate",
    "implementation",
    "improvement",
    "global_evaluation",
    "continuous_improvement",
    "closed",
    "paused",
    "blocked",
    "cancelled",
    "rollback_requested",
}

# Transition Guard Table: from_state -> set of allowed to_states
TRANSITION_GUARD_TABLE: dict[str, set[str]] = {
    "created": {"intake_complete", "cancelled"},
    "intake_complete": {"direction_debate", "cancelled", "blocked"},
    "direction_debate": {"solution_debate", "cancelled", "blocked", "rollback_requested"},
    "solution_debate": {"implementation", "cancelled", "blocked", "rollback_requested"},
    "implementation": {"improvement", "cancelled", "blocked", "rollback_requested"},
    "improvement": {"global_evaluation", "cancelled", "blocked", "rollback_requested"},
    "global_evaluation": {"continuous_improvement", "closed", "cancelled", "blocked", "rollback_requested"},
    "continuous_improvement": {"closed", "cancelled", "blocked", "rollback_requested"},
    "closed": set(),  # Terminal state
    "paused": {"created", "intake_complete", "direction_debate", "solution_debate", "implementation", "improvement", "global_evaluation", "continuous_improvement", "cancelled"},
    "blocked": {"created", "intake_complete", "direction_debate", "solution_debate", "implementation", "improvement", "global_evaluation", "continuous_improvement", "cancelled"},
    "cancelled": set(),  # Terminal state
    "rollback_requested": {"implementation", "cancelled", "blocked"},
}

# Backward compatibility: map old status values to lifecycle states
STATUS_TO_LIFECYCLE = {
    "queued": "created",
    "running": "intake_complete",  # Approximate mapping
    "blocked": "blocked",
    "completed": "closed",
    "cancelled": "cancelled",
    "stopped": "cancelled",
}


class InvalidTransitionError(Exception):
    """Raised when an invalid lifecycle transition is attempted."""

    def __init__(self, from_state: str, to_state: str, run_id: str | None = None):
        self.from_state = from_state
        self.to_state = to_state
        self.run_id = run_id
        msg = f"Invalid transition: {from_state} -> {to_state}"
        if run_id:
            msg = f"Run {run_id}: {msg}"
        super().__init__(msg)


def get_lifecycle_status(run: dict[str, Any]) -> str:
    """Extract lifecycle_status from run, falling back to status mapping."""
    if "lifecycle_status" in run:
        return run["lifecycle_status"]
    # Backward compatibility: map old status to lifecycle
    old_status = run.get("status", "queued")
    return STATUS_TO_LIFECYCLE.get(old_status, "created")


def can_transition(from_state: str, to_state: str) -> bool:
    """Check if a transition is allowed."""
    allowed = TRANSITION_GUARD_TABLE.get(from_state, set())
    return to_state in allowed


def validate_transition(run_id: str, from_state: str, to_state: str) -> None:
    """Validate a transition, raising InvalidTransitionError if not allowed."""
    if not can_transition(from_state, to_state):
        raise InvalidTransitionError(from_state, to_state, run_id)


def transition(run: dict[str, Any], to_state: str, reason: str | None = None) -> dict[str, Any]:
    """Transition a run to a new lifecycle state.

    Returns updated run dict with lifecycle_status set.
    Raises InvalidTransitionError if transition is not allowed.
    """
    run_id = run.get("run_id", "unknown")
    from_state = get_lifecycle_status(run)

    validate_transition(run_id, from_state, to_state)

    run["lifecycle_status"] = to_state
    run["updated_at"] = _now_iso()

    # Backward compatibility: update status field
    if to_state == "cancelled":
        run["status"] = "cancelled"
    elif to_state == "blocked":
        run["status"] = "blocked"
    elif to_state == "closed":
        run["status"] = "completed"

    return run


def is_terminal(state: str) -> bool:
    """Check if a state is terminal (no outgoing transitions)."""
    return len(TRANSITION_GUARD_TABLE.get(state, set())) == 0


def can_resume(run: dict[str, Any]) -> bool:
    """Check if a paused/blocked run can be resumed."""
    lifecycle = get_lifecycle_status(run)
    if lifecycle in ("paused", "blocked"):
        # Check if there are blocker refs that need resolution
        blocker_refs = run.get("blocker_refs", [])
        if lifecycle == "blocked" and blocker_refs:
            return False  # Cannot resume without resolving blockers
        return True
    return False


def _now_iso() -> str:
    """Get current time in ISO format."""
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()
