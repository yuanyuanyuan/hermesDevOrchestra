#!/usr/bin/env python3
"""Global Evaluation Veto and Residual Risk for PRD Compliance.

Adds one-vote veto and residual-risk threshold logic to global evaluation routing.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


# Veto dimensions from PRD
VETO_DIMENSIONS = {
    "security_compliance",
    "completion_correctness",
    "data_integrity",
    "api_contract",
    "performance_slo",
}

# Residual risk severity levels
RESIDUAL_RISK_SEVERITY = {
    "high": {"requires_approval": True, "approval_authority": ["human", "kimi"]},
    "medium": {"requires_approval": False, "approval_authority": []},
    "low": {"requires_approval": False, "approval_authority": []},
}


class GlobalEvaluationError(Exception):
    """Base class for global evaluation errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class VetoDimensionError(GlobalEvaluationError):
    """Raised when a veto dimension blocks closeout."""

    def __init__(self, run_id: str, dimension: str, score: float, threshold: float):
        self.dimension = dimension
        self.score = score
        self.threshold = threshold
        msg = f"Veto dimension '{dimension}' score {score:.2f} below threshold {threshold:.2f}"
        super().__init__(msg, run_id)


class ResidualRiskError(GlobalEvaluationError):
    """Raised when high residual risk blocks closeout."""

    def __init__(self, run_id: str, risks: list[dict[str, Any]]):
        self.risks = risks
        msg = f"High residual risks block closeout: {len(risks)} risks require approval"
        super().__init__(msg, run_id)


class UnknownRiskSeverityError(GlobalEvaluationError):
    """Raised when residual risk severity is unknown."""

    def __init__(self, run_id: str, severity: str):
        self.severity = severity
        msg = f"Unknown residual risk severity: {severity}"
        super().__init__(msg, run_id)


def validate_veto_dimension(
    dimension: str,
    score: float,
    threshold: float = 0.6,
    run_id: str = "unknown",
) -> None:
    """Validate that veto dimension score meets threshold.

    Raises VetoDimensionError if score below threshold.
    """
    if dimension not in VETO_DIMENSIONS:
        return  # Not a veto dimension

    if score < threshold:
        raise VetoDimensionError(run_id, dimension, score, threshold)


def validate_residual_risks(
    run_id: str,
    residual_risks: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Validate residual risks and return high risks requiring approval.

    Each risk must include a severity value of "high", "medium", or "low".
    Missing or unknown severity values raise UnknownRiskSeverityError.
    """
    high_risks = []

    for risk in residual_risks:
        severity = risk.get("severity", "")

        if severity not in RESIDUAL_RISK_SEVERITY:
            raise UnknownRiskSeverityError(run_id, severity)

        risk_config = RESIDUAL_RISK_SEVERITY[severity]
        if risk_config["requires_approval"]:
            high_risks.append(risk)

    return high_risks


def check_authority_approval(
    run: dict[str, Any],
    risks: list[dict[str, Any]],
) -> bool:
    """Check if high residual risks have authority route approval."""
    authority_route = run.get("authority_route", {})

    for risk in risks:
        risk_id = risk.get("risk_id")
        if risk_id not in authority_route.get("approved_risks", []):
            return False  # Not approved

    return True  # All approved


def sort_residual_risks_by_severity(risks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Sort residual risks by severity (high first)."""
    severity_order = {"high": 0, "medium": 1, "low": 2}
    return sorted(risks, key=lambda r: severity_order.get(r.get("severity", ""), 3))


def attach_required_action(risks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Return residual risks with required action attached."""
    risks_with_actions = []
    for risk in risks:
        risk_with_action = risk.copy()
        severity = risk.get("severity", "")
        if severity == "high":
            risk_with_action["required_action"] = "human_approval_required"
        elif severity == "medium":
            risk_with_action["required_action"] = "monitor_and_review"
        else:
            risk_with_action["required_action"] = "accept"
        risks_with_actions.append(risk_with_action)
    return risks_with_actions


def validate_global_evaluation(
    run_id: str,
    veto_scores: dict[str, float],
    residual_risks: list[dict[str, Any]],
    veto_threshold: float = 0.6,
) -> list[str]:
    """Validate global evaluation for closeout.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []

    # Check veto dimensions
    for dimension, score in veto_scores.items():
        if dimension in VETO_DIMENSIONS and score < veto_threshold:
            errors.append(f"veto_dimension_blocked: {dimension} score {score:.2f} below {veto_threshold}")

    # Check residual risks
    try:
        high_risks = validate_residual_risks(run_id, residual_risks)
        if high_risks:
            errors.append(f"high_residual_risks: {len(high_risks)} risks require approval")
    except UnknownRiskSeverityError as e:
        errors.append(f"unknown_risk_severity: {e.severity}")

    return errors


def create_global_evaluation_report(
    run_id: str,
    veto_scores: dict[str, float],
    residual_risks: list[dict[str, Any]],
    veto_threshold: float = 0.6,
) -> dict[str, Any]:
    """Create global evaluation report with veto and residual risk info."""
    # Sort and attach actions to residual risks
    sorted_risks = sort_residual_risks_by_severity(residual_risks)
    risks_with_actions = attach_required_action(sorted_risks)

    # Check for veto blocks
    veto_blocks = []
    for dimension, score in veto_scores.items():
        if dimension in VETO_DIMENSIONS and score < veto_threshold:
            veto_blocks.append({
                "dimension": dimension,
                "score": score,
                "threshold": veto_threshold,
                "blocked": True,
            })

    # Check high residual risks
    high_risks = [r for r in risks_with_actions if r.get("severity") == "high"]

    return {
        "run_id": run_id,
        "veto_scores": veto_scores,
        "veto_blocks": veto_blocks,
        "residual_risks": risks_with_actions,
        "high_risk_count": len(high_risks),
        "requires_approval": len(high_risks) > 0,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
