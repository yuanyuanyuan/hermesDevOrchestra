#!/usr/bin/env python3
"""Channel Routing Propagation for PRD Compliance.

Persists Quick/Light/Standard channel decisions and makes them affect
run creation, required evidence, and stage behavior.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from channel_router import ChannelRouter


# Channel configurations with required debate rounds and evidence
CHANNEL_CONFIGS = {
    "quick": {
        "required_debate_rounds": 1,
        "required_evidence": ["task_description"],
        "allowed_stage_skips": ["direction_debate", "solution_debate"],
        "max_files": 5,
        "timeout_minutes": 30,
    },
    "light": {
        "required_debate_rounds": 2,
        "required_evidence": ["task_description", "impact_analysis"],
        "allowed_stage_skips": ["direction_debate"],
        "max_files": 15,
        "timeout_minutes": 60,
    },
    "standard": {
        "required_debate_rounds": 3,
        "required_evidence": ["task_description", "impact_analysis", "risk_assessment", "test_plan"],
        "allowed_stage_skips": [],
        "max_files": 50,
        "timeout_minutes": 120,
    },
}

# Rollout evidence requirements for non-standard channels
ROLLOUT_EVIDENCE_REQUIRED = {
    "quick": ["rollout_approval", "risk_assessment"],
    "light": ["rollout_approval"],
}


class ChannelRoutingError(Exception):
    """Base class for channel routing errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class ChannelPolicyInvalidError(ChannelRoutingError):
    """Raised when channel configuration is invalid."""

    def __init__(self, channel: str, run_id: str | None = None):
        self.channel = channel
        msg = f"Channel policy invalid: {channel}"
        super().__init__(msg, run_id)


class RolloutEvidenceMissingError(ChannelRoutingError):
    """Raised when rollout evidence is missing for non-standard channel."""

    def __init__(self, missing: list[str], run_id: str | None = None):
        self.missing = missing
        msg = f"Rollout evidence missing: {', '.join(missing)}"
        super().__init__(msg, run_id)


def classify_and_persist(
    run: dict[str, Any],
    task_description: str,
    files_changed: list[str],
    project_age_weeks: int,
    force_standard: bool = False,
    force_standard_reasons: list[str] | None = None,
) -> dict[str, Any]:
    """Classify channel and persist decision on run state.

    Returns updated run dict with channel_decision persisted.
    """
    run_id = run.get("run_id")
    if not run_id:
        raise ValueError("run_id required")

    # If forced to Standard, use Standard channel
    if force_standard:
        decision = {
            "channel": "standard",
            "reason": "forced",
            "project_age_weeks": project_age_weeks,
            "files_count": len(files_changed),
            "required_debate_rounds": CHANNEL_CONFIGS["standard"]["required_debate_rounds"],
            "required_evidence": CHANNEL_CONFIGS["standard"]["required_evidence"],
            "forced_standard": True,
            "forced_standard_reasons": force_standard_reasons or [],
        }
    else:
        # Use ChannelRouter to classify
        router = ChannelRouter(repo_root=".")
        intent = {
            "task_type": "feature",
            "files_count": len(files_changed),
            "files": files_changed,
        }
        result = router.classify(intent, project_age_weeks)
        selected_channel = result.get("channel", "standard")
        decision = {
            "channel": selected_channel,
            "reason": result.get("reason", "default"),
            "project_age_weeks": project_age_weeks,
            "files_count": len(files_changed),
            "required_debate_rounds": CHANNEL_CONFIGS[selected_channel]["required_debate_rounds"],
            "required_evidence": CHANNEL_CONFIGS[selected_channel]["required_evidence"],
            "forced_standard": False,
            "forced_standard_reasons": [],
        }

    # Validate channel configuration
    if decision["channel"] not in CHANNEL_CONFIGS:
        raise ChannelPolicyInvalidError(decision["channel"], run_id)

    # Check rollout evidence for non-standard channels
    if decision["channel"] != "standard":
        required_evidence = ROLLOUT_EVIDENCE_REQUIRED.get(decision["channel"], [])
        provided_evidence = run.get("rollout_evidence", [])
        missing = [e for e in required_evidence if e not in provided_evidence]
        if missing:
            raise RolloutEvidenceMissingError(missing, run_id)

    # Get channel config
    config = CHANNEL_CONFIGS[decision["channel"]]

    # Persist channel decision on run
    run["channel_decision"] = {
        "channel": decision["channel"],
        "reason": decision["reason"],
        "project_age_weeks": decision["project_age_weeks"],
        "files_count": decision["files_count"],
        "required_debate_rounds": decision["required_debate_rounds"],
        "required_evidence": decision["required_evidence"],
        "forced_standard": decision["forced_standard"],
        "forced_standard_reasons": decision["forced_standard_reasons"],
        "decision_ref": f"channel://run/{run_id}/{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}",
        "classified_at": datetime.now(timezone.utc).isoformat(),
    }

    # Persist channel-specific requirements
    run["channel_requirements"] = {
        "required_debate_rounds": config["required_debate_rounds"],
        "required_evidence": config["required_evidence"],
        "allowed_stage_skips": config["allowed_stage_skips"],
        "max_files": config["max_files"],
        "timeout_minutes": config["timeout_minutes"],
    }

    return run


def get_channel_requirements(run: dict[str, Any]) -> dict[str, Any]:
    """Get channel requirements for a run."""
    return run.get("channel_requirements", CHANNEL_CONFIGS["standard"])


def can_skip_stage(run: dict[str, Any], stage: str) -> bool:
    """Check if a stage can be skipped based on channel decision."""
    requirements = get_channel_requirements(run)
    allowed_skips = requirements.get("allowed_stage_skips", [])
    return stage in allowed_skips


def get_required_evidence(run: dict[str, Any]) -> list[str]:
    """Get required evidence for a run based on channel decision."""
    requirements = get_channel_requirements(run)
    return requirements.get("required_evidence", [])


def get_required_debate_rounds(run: dict[str, Any]) -> int:
    """Get required debate rounds for a run based on channel decision."""
    requirements = get_channel_requirements(run)
    return requirements.get("required_debate_rounds", 3)


def validate_channel_decision(run: dict[str, Any]) -> list[str]:
    """Validate channel decision on run.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []
    channel_decision = run.get("channel_decision")

    if not channel_decision:
        errors.append("channel_decision missing")
        return errors

    if "channel" not in channel_decision:
        errors.append("channel missing from channel_decision")

    if "required_debate_rounds" not in channel_decision:
        errors.append("required_debate_rounds missing from channel_decision")

    if "required_evidence" not in channel_decision:
        errors.append("required_evidence missing from channel_decision")

    return errors
