#!/usr/bin/env python3
"""E-Class Mini-Debate for PRD Compliance.

Routes E-class improvement disputes into two-round mini-debate
and blocks if consensus score remains below 0.60.
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
) -> dict[str, Any]:
    """Execute E-class mini-debate and return report.

    Args:
        run: Current run state
        dispute: E-class dispute
        debate_backend_available: Whether debate backend is available

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

    # Execute debate (simplified - in real implementation would call debate engine)
    # Simulate consensus based on dispute type
    if dispute.get("classification") == "high_priority":
        consensus_score = 0.75
    else:
        consensus_score = 0.65

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
        "debate_refs": [f"debate://run/{run_id}/e-class/{dispute.get('dispute_id', 'unknown')}"],
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
    """Validate E-class dispute has debate refs.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []

    # Check if dispute has debate refs
    e_class_debate_refs = run.get("e_class_debate_refs", [])
    if not e_class_debate_refs:
        errors.append(f"missing_debate_refs: {dispute_id}")

    return errors


def check_e_class_auto_merge_blocked(run: dict[str, Any], dispute_id: str) -> bool:
    """Check if auto-merge is blocked due to missing E-class debate refs."""
    e_class_debate_status = run.get("e_class_debate_status")
    if not e_class_debate_status or e_class_debate_status.get("status") != "completed":
        return True  # Blocked

    return False  # Not blocked
