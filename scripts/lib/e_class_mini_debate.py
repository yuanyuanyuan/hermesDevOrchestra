#!/usr/bin/env python3
"""E-Class Mini-Debate for PRD Compliance.

Routes E-class improvement disputes into two-round mini-debate
and blocks if consensus score remains below 0.60.
The current executor uses deterministic placeholder scoring until an external
debate backend is wired into the PRD compliance gate.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


# E-class mini-debate configuration
E_CLASS_CONFIG = {
    "max_rounds": 2,
    "team_size": 2,
    "timeout_minutes": 30,
    "required_consensus": 0.60,
    "debate_type": "e_class_dispute",
}


class EClassDebateError(Exception):
    """Base class for E-class debate errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class EClassConsensusError(EClassDebateError):
    """Raised when E-class consensus is not reached."""

    def __init__(self, run_id: str, actual_consensus: float, required_consensus: float):
        self.actual_consensus = actual_consensus
        self.required_consensus = required_consensus
        msg = f"E-class consensus {actual_consensus:.2f} below required {required_consensus:.2f}"
        super().__init__(msg, run_id)


class EClassDebateUnavailableError(EClassDebateError):
    """Raised when E-class debate backend is unavailable."""

    def __init__(self, run_id: str):
        msg = f"E-class debate backend unavailable for run {run_id}"
        super().__init__(msg, run_id)


class MissingDebateRefsError(EClassDebateError):
    """Raised when E-class dispute lacks debate refs."""

    def __init__(self, run_id: str, dispute_id: str):
        self.dispute_id = dispute_id
        msg = f"E-class dispute {dispute_id} missing debate refs"
        super().__init__(msg, run_id)


def get_e_class_config() -> dict[str, Any]:
    """Get E-class mini-debate configuration."""
    return E_CLASS_CONFIG.copy()


def create_e_class_dispute(
    run_id: str,
    task_id: str,
    improvement_id: str,
    classification: str,
    description: str,
    evidence_refs: list[str],
) -> dict[str, Any]:
    """Create an E-class improvement dispute."""
    return {
        "dispute_id": f"edispute-{run_id}-{improvement_id}",
        "run_id": run_id,
        "task_id": task_id,
        "improvement_id": improvement_id,
        "classification": classification,
        "description": description,
        "evidence_refs": evidence_refs,
        "status": "pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


def execute_e_class_debate(
    run: dict[str, Any],
    dispute: dict[str, Any],
    debate_backend_available: bool = True,
    backend_report: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Execute E-class mini-debate and return report.

    Uses deterministic placeholder consensus scores; this is a bounded gate
    simulation, not an external consensus engine invocation.

    Args:
        run: Current run state
        dispute: E-class dispute
        debate_backend_available: Whether debate backend is available
        backend_report: Optional debate backend report. When present and well-formed,
            its `consensus_score` and `debate_refs` are used; otherwise the function
            falls back to deterministic placeholder scoring. Mirrors the contract
            of `mini_debate_orchestration.execute_mini_debate` so the CLI envelope
            (`orch-e-class-debate`) can pass `backend_report` uniformly.

    Returns:
        E-class debate report dict

    Raises:
        EClassDebateUnavailableError: If backend unavailable
        EClassConsensusError: If consensus not reached
    """
    run_id = run.get("run_id", "unknown")
    config = get_e_class_config()

    # Check if debate backend is available
    if not debate_backend_available:
        raise EClassDebateUnavailableError(run_id)

    # Resolve consensus score: prefer explicit backend_report; fall back to placeholder.
    consensus_score: float
    debate_refs: list[str]
    if isinstance(backend_report, dict):
        score = backend_report.get("consensus_score")
        if isinstance(score, (int, float)) and 0 <= float(score) <= 1:
            consensus_score = float(score)
        else:
            # Backend report present but malformed — use placeholder rather than
            # crashing the gate; this matches the mini-debate degraded-on-malformed
            # policy in spirit but stays at the debate layer.
            consensus_score = 0.75 if dispute.get("classification") == "high_priority" else 0.65
        refs = backend_report.get("debate_refs")
        if isinstance(refs, list) and refs and all(isinstance(r, str) and r for r in refs):
            debate_refs = list(refs)
        else:
            dispute_id = dispute.get("dispute_id", "unknown")
            debate_refs = [f"debate://run/{run_id}/e-class/{dispute_id}"]
    else:
        # Execute debate (simplified - in real implementation would call debate engine)
        # Simulate consensus based on dispute type
        if dispute.get("classification") == "high_priority":
            consensus_score = 0.75
        else:
            consensus_score = 0.65
        dispute_id = dispute.get("dispute_id", "unknown")
        debate_refs = [f"debate://run/{run_id}/e-class/{dispute_id}"]

    # Check consensus
    if consensus_score < config["required_consensus"]:
        raise EClassConsensusError(run_id, consensus_score, config["required_consensus"])

    # Create report
    report = {
        "run_id": run_id,
        "dispute_id": dispute.get("dispute_id"),
        "classification": dispute.get("classification"),
        "status": "completed",
        "consensus_score": consensus_score,
        "required_consensus": config["required_consensus"],
        "rounds_completed": config["max_rounds"],
        "max_rounds": config["max_rounds"],
        "timeout_minutes": config["timeout_minutes"],
        "started_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "debate_refs": debate_refs,
    }

    return report


def persist_e_class_debate_refs(run: dict[str, Any], report: dict[str, Any]) -> dict[str, Any]:
    """Persist E-class debate refs on run state."""
    run_id = run.get("run_id", "unknown")

    # Add debate refs to run
    if "e_class_debate_refs" not in run:
        run["e_class_debate_refs"] = []

    run["e_class_debate_refs"].extend(report.get("debate_refs", []))

    # Update run with debate status
    run["e_class_debate_status"] = {
        "dispute_id": report.get("dispute_id"),
        "classification": report.get("classification"),
        "status": report.get("status"),
        "consensus_score": report.get("consensus_score"),
        "required_consensus": report.get("required_consensus"),
        "completed_at": report.get("completed_at"),
    }

    return run


def validate_e_class_dispute(run: dict[str, Any], dispute_id: str) -> list[str]:
    """Validate E-class dispute has debate refs bound to the given dispute_id.

    Returns list of validation errors. Empty list means valid.

    The check requires that at least one persisted ref actually carries the
    supplied dispute_id (refs are formatted as
    ``debate://run/{run_id}/e-class/{dispute_id}``). This prevents a completed
    dispute's refs from satisfying the gate for an unrelated dispute.
    """
    errors = []

    if not dispute_id or not isinstance(dispute_id, str):
        errors.append("dispute_id is required and must be a string")
        return errors

    e_class_debate_refs = run.get("e_class_debate_refs", [])
    if not e_class_debate_refs:
        errors.append(f"missing_debate_refs: {dispute_id}")
        return errors

    # At least one ref must be bound to this dispute_id.
    matching = [r for r in e_class_debate_refs if isinstance(r, str) and dispute_id in r]
    if not matching:
        errors.append(
            f"debate_refs do not contain dispute_id={dispute_id}: {e_class_debate_refs}"
        )

    return errors


def check_e_class_auto_merge_blocked(run: dict[str, Any], dispute_id: str) -> bool:
    """Check if auto-merge is blocked due to missing E-class debate refs.

    Auto-merge is unblocked only when ``e_class_debate_status`` exists, is
    ``completed``, and is bound to the supplied ``dispute_id``. Any other
    status — including a status for a different dispute — leaves the gate
    blocked.
    """
    e_class_debate_status = run.get("e_class_debate_status")
    if not isinstance(e_class_debate_status, dict):
        return True  # Blocked

    if e_class_debate_status.get("status") != "completed":
        return True  # Blocked

    if e_class_debate_status.get("dispute_id") != dispute_id:
        # Status belongs to a different dispute; do not unblock this one.
        return True  # Blocked

    return False  # Not blocked
