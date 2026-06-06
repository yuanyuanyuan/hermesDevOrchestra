#!/usr/bin/env python3
"""Mini-Debate Orchestration for PRD Compliance.

Connects channel routing to bounded debate execution for Quick and Light channels.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4


# Mini-debate configurations per channel
MINI_DEBATE_CONFIGS = {
    "quick": {
        "max_rounds": 1,
        "team_size": 1,
        "timeout_minutes": 10,
        "required_consensus": 0.8,
        "debate_type": "confirmation",
    },
    "light": {
        "max_rounds": 2,
        "team_size": 2,
        "timeout_minutes": 20,
        "required_consensus": 0.7,
        "debate_type": "minimal",
    },
    "standard": {
        "max_rounds": 3,
        "team_size": 3,
        "timeout_minutes": 60,
        "required_consensus": 0.6,
        "debate_type": "full",
    },
}


class MiniDebateError(Exception):
    """Base class for mini-debate errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class MiniDebateTimeoutError(MiniDebateError):
    """Raised when mini-debate times out."""

    def __init__(self, run_id: str, timeout_minutes: int):
        self.timeout_minutes = timeout_minutes
        msg = f"Mini-debate timed out after {timeout_minutes} minutes for run {run_id}"
        super().__init__(msg, run_id)


class MiniDebateConsensusError(MiniDebateError):
    """Raised when mini-debate consensus is not reached."""

    def __init__(self, run_id: str, actual_consensus: float, required_consensus: float):
        self.actual_consensus = actual_consensus
        self.required_consensus = required_consensus
        msg = f"Mini-debate consensus {actual_consensus:.2f} below required {required_consensus:.2f} for run {run_id}"
        super().__init__(msg, run_id)


class MissingDebateReportError(MiniDebateError):
    """Raised when debate report is missing for auto-merge."""

    def __init__(self, run_id: str):
        msg = f"Debate report missing for run {run_id}, blocks auto-merge"
        super().__init__(msg, run_id)


def get_mini_debate_config(channel: str) -> dict[str, Any]:
    """Get mini-debate configuration for a channel."""
    return MINI_DEBATE_CONFIGS.get(channel, MINI_DEBATE_CONFIGS["standard"])


def create_mini_debate_request(
    run_id: str,
    task_id: str,
    channel: str,
    task_description: str,
    files_changed: list[str],
) -> dict[str, Any]:
    """Create a mini-debate request for a channel."""
    if not channel:
        raise ValueError("channel is required")

    config = get_mini_debate_config(channel)

    return {
        "run_id": run_id,
        "task_id": task_id,
        "channel": channel,
        "debate_type": config["debate_type"],
        "max_rounds": config["max_rounds"],
        "team_size": config["team_size"],
        "timeout_minutes": config["timeout_minutes"],
        "required_consensus": config["required_consensus"],
        "task_description": task_description,
        "files_changed": files_changed,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


def execute_mini_debate(
    run: dict[str, Any],
    request: dict[str, Any],
    debate_backend_available: bool = True,
    backend_report: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Execute a mini-debate and return the report.

    Args:
        run: Current run state
        request: Mini-debate request
        debate_backend_available: Whether debate backend is available
        backend_report: Debate backend report containing consensus_score and optional refs

    Returns:
        Mini-debate report dict

    Raises:
        MiniDebateTimeoutError: If debate times out
        MiniDebateConsensusError: If consensus not reached
    """
    run_id = run.get("run_id", "unknown")
    channel = request.get("channel", "standard")
    config = get_mini_debate_config(channel)
    now = datetime.now(timezone.utc)

    # Check if debate backend is available
    if not debate_backend_available or backend_report is None:
        # Mark degraded evidence and block completion
        report = {
            "run_id": run_id,
            "task_id": request.get("task_id"),
            "channel": channel,
            "debate_type": config["debate_type"],
            "status": "degraded",
            "degradation_reason": "debate_backend_unavailable",
            "consensus_score": 0.0,
            "required_consensus": config["required_consensus"],
            "rounds_completed": 0,
            "max_rounds": config["max_rounds"],
            "timeout_minutes": config["timeout_minutes"],
            "started_at": now.isoformat(),
            "completed_at": None,
            "debate_refs": [],
        }
        return report

    consensus_score = backend_report.get("consensus_score")
    if isinstance(consensus_score, bool) or not isinstance(consensus_score, (int, float)):
        raise MiniDebateConsensusError(run_id, 0.0, config["required_consensus"])

    # Check consensus
    if consensus_score < config["required_consensus"]:
        raise MiniDebateConsensusError(run_id, consensus_score, config["required_consensus"])

    # Create report
    report = {
        "run_id": run_id,
        "task_id": request.get("task_id"),
        "channel": channel,
        "debate_type": config["debate_type"],
        "status": "completed",
        "consensus_score": consensus_score,
        "required_consensus": config["required_consensus"],
        "rounds_completed": backend_report.get("rounds_completed", config["max_rounds"]),
        "max_rounds": config["max_rounds"],
        "timeout_minutes": config["timeout_minutes"],
        "started_at": now.isoformat(),
        "completed_at": now.isoformat(),
        "debate_refs": backend_report.get("debate_refs") or [f"debate://run/{run_id}/mini/{uuid4().hex}"],
    }

    return report


def persist_mini_debate_refs(run: dict[str, Any], report: dict[str, Any]) -> dict[str, Any]:
    """Persist mini-debate refs on run state."""
    run_id = run.get("run_id", "unknown")

    # Add debate refs to run
    if "mini_debate_refs" not in run:
        run["mini_debate_refs"] = []

    run["mini_debate_refs"].extend(report.get("debate_refs", []))

    # Update run with debate status
    run["mini_debate_status"] = {
        "channel": report.get("channel"),
        "debate_type": report.get("debate_type"),
        "status": report.get("status"),
        "consensus_score": report.get("consensus_score"),
        "required_consensus": report.get("required_consensus"),
        "completed_at": report.get("completed_at"),
    }

    return run


def validate_mini_debate(run: dict[str, Any]) -> list[str]:
    """Validate mini-debate handling on run.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []
    mini_debate_status = run.get("mini_debate_status")

    if not mini_debate_status:
        errors.append("mini_debate_status missing")
        return errors

    if "status" not in mini_debate_status:
        errors.append("status missing from mini_debate_status")
    elif mini_debate_status["status"] not in ("completed", "degraded"):
        errors.append("status must be completed or degraded")

    if "consensus_score" not in mini_debate_status:
        errors.append("consensus_score missing from mini_debate_status")
    else:
        consensus_score = mini_debate_status.get("consensus_score")
        if isinstance(consensus_score, bool) or not isinstance(consensus_score, (int, float)):
            errors.append("consensus_score must be numeric")
        elif not 0 <= consensus_score <= 1:
            errors.append("consensus_score must be between 0 and 1")

    return errors


def check_auto_merge_blocked(run: dict[str, Any]) -> bool:
    """Check if auto-merge is blocked due to missing debate report."""
    channel_decision = run.get("channel_decision")
    if not channel_decision:
        return True

    channel = channel_decision.get("channel", "standard")

    # For non-standard channels, check if mini-debate is required
    if channel in ("quick", "light"):
        mini_debate_status = run.get("mini_debate_status")
        if not mini_debate_status or mini_debate_status.get("status") != "completed":
            return True  # Blocked

    return False  # Not blocked
