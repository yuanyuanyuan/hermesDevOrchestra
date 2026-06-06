#!/usr/bin/env python3
"""User Correction and Override Approval for PRD Compliance.

Makes correction rounds and Override records complete enough for approval workflows.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


# Risk levels requiring approval
RISK_LEVELS = {
    "L1": {"requires_approval": False, "approval_authority": []},
    "L2": {"requires_approval": False, "approval_authority": []},
    "L3": {"requires_approval": True, "approval_authority": ["human", "kimi"]},
    "L4": {"requires_approval": True, "approval_authority": ["human", "kimi"]},
}

# Override statuses
OVERRIDE_STATUSES = {
    "pending",
    "pending_approval",
    "approved",
    "rejected",
    "cancelled",
}


class CorrectionError(Exception):
    """Base class for correction errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class OverrideApprovalRequiredError(CorrectionError):
    """Raised when override requires approval."""

    def __init__(self, run_id: str, override_id: str, risk_level: str):
        self.override_id = override_id
        self.risk_level = risk_level
        msg = f"Override {override_id} requires {risk_level} approval"
        super().__init__(msg, run_id)


class MissingApproverRefError(CorrectionError):
    """Raised when override is missing approver_ref."""

    def __init__(self, run_id: str, override_id: str):
        self.override_id = override_id
        msg = f"Override {override_id} missing approver_ref"
        super().__init__(msg, run_id)


class InvalidOverrideStatusError(CorrectionError):
    """Raised when override status is invalid."""

    def __init__(self, run_id: str, override_id: str, status: str):
        self.override_id = override_id
        self.status = status
        msg = f"Invalid override status: {status}"
        super().__init__(msg, run_id)


class UnauthorizedApproverError(CorrectionError):
    """Raised when approver_ref is not authorized for override risk level."""

    def __init__(self, run_id: str, override_id: str, approver_ref: str, risk_level: str):
        self.override_id = override_id
        self.approver_ref = approver_ref
        self.risk_level = risk_level
        msg = f"Approver '{approver_ref}' not authorized for {risk_level}"
        super().__init__(msg, run_id)


def create_correction_round(
    run_id: str,
    task_id: str,
    correction_type: str,
    evidence_mode: str,
    description: str,
    evidence_refs: list[str],
) -> dict[str, Any]:
    """Create a correction round record."""
    return {
        "correction_id": f"corr-{run_id}-{task_id}-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}",
        "run_id": run_id,
        "task_id": task_id,
        "correction_type": correction_type,
        "evidence_mode": evidence_mode,
        "description": description,
        "evidence_refs": evidence_refs,
        "status": "pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


def create_override_record(
    run_id: str,
    task_id: str,
    correction_rounds: list[dict[str, Any]],
    override_category: str,
    risk_level: str,
    approver_ref: str | None = None,
    evidence_refs: list[str] | None = None,
) -> dict[str, Any]:
    """Create an override record."""
    now = datetime.now(timezone.utc)
    override_id = f"override-{run_id}-{task_id}-{now.strftime('%Y%m%d%H%M%S')}"

    # Validate risk level
    if risk_level not in RISK_LEVELS:
        raise ValueError(f"Invalid risk level: {risk_level}")

    # Check if approval is required
    risk_config = RISK_LEVELS[risk_level]
    requires_approval = risk_config["requires_approval"]

    # If approval required but no approver, status is pending
    status = "pending"
    if requires_approval and not approver_ref:
        status = "pending_approval"
    elif not requires_approval:
        status = "approved"  # Auto-approve L1/L2

    return {
        "override_id": override_id,
        "run_id": run_id,
        "task_id": task_id,
        "correction_rounds": correction_rounds,
        "override_category": override_category,
        "risk_level": risk_level,
        "approver_ref": approver_ref,
        "evidence_refs": evidence_refs or [],
        "status": status,
        "requires_approval": requires_approval,
        "created_at": now.isoformat(),
        "resolved_at": None,
    }


def approve_override(
    run: dict[str, Any],
    override_id: str,
    approver_ref: str,
) -> dict[str, Any]:
    """Approve an override record.

    Note: modifies the matching override record in run in-place.
    """
    run_id = run.get("run_id", "unknown")

    # Find override in run
    overrides = run.get("override_records", [])
    override = next((o for o in overrides if o.get("override_id") == override_id), None)

    if not override:
        raise CorrectionError(f"Override {override_id} not found", run_id)

    # Check if approval is required
    if override.get("requires_approval") and not approver_ref:
        raise MissingApproverRefError(run_id, override_id)

    risk_level = override.get("risk_level")
    authority = RISK_LEVELS.get(risk_level, {}).get("approval_authority", [])
    if authority and approver_ref not in authority:
        raise UnauthorizedApproverError(run_id, override_id, approver_ref, risk_level)

    status = override.get("status")
    if status not in ("pending", "pending_approval"):
        raise InvalidOverrideStatusError(run_id, override_id, status)

    # Update override
    override["status"] = "approved"
    override["approver_ref"] = approver_ref
    override["resolved_at"] = datetime.now(timezone.utc).isoformat()

    return override


def reject_override(
    run: dict[str, Any],
    override_id: str,
    reason: str,
) -> dict[str, Any]:
    """Reject an override record.

    Note: modifies the matching override record in run in-place.
    """
    run_id = run.get("run_id", "unknown")

    # Find override in run
    overrides = run.get("override_records", [])
    override = next((o for o in overrides if o.get("override_id") == override_id), None)

    if not override:
        raise CorrectionError(f"Override {override_id} not found", run_id)

    status = override.get("status")
    if status not in ("pending", "pending_approval", "approved"):
        raise InvalidOverrideStatusError(run_id, override_id, status)

    # Update override
    override["status"] = "rejected"
    override["rejection_reason"] = reason
    override["resolved_at"] = datetime.now(timezone.utc).isoformat()

    return override


def get_pending_overrides(run: dict[str, Any]) -> list[dict[str, Any]]:
    """Get list of pending overrides for a run."""
    overrides = run.get("override_records", [])
    return [o for o in overrides if o.get("status") in ("pending", "pending_approval")]


def validate_override_record(override: dict[str, Any]) -> list[str]:
    """Validate override record structure.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []

    required_fields = ["override_id", "run_id", "task_id", "correction_rounds", "override_category", "risk_level", "status"]
    for field in required_fields:
        if field not in override:
            errors.append(f"{field} missing")

    if "risk_level" in override and override["risk_level"] not in RISK_LEVELS:
        errors.append(f"Invalid risk_level: {override['risk_level']}")

    if "status" in override and override["status"] not in OVERRIDE_STATUSES:
        errors.append(f"Invalid status: {override['status']}")

    return errors


def check_override_auto_merge_blocked(run: dict[str, Any]) -> bool:
    """Check if auto-merge is blocked due to pending overrides."""
    pending = get_pending_overrides(run)
    return len(pending) > 0
