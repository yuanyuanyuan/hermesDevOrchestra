#!/usr/bin/env python3
"""Rollback Executor for PRD Compliance.

Implements rollback request handling and reporting with current-run scope
protection and protected target approval gates. This module is intentionally
report-only for PRD gate validation: non-dry-run calls still produce a
simulated rollback report and do not execute destructive repository commands.
"""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from atomic_writer import AtomicWriter


# Protected targets that require human approval for rollback
PROTECTED_TARGETS = {
    "config/release/commands.json",
    "config/schemas/orchestra.full.schema.json",
    "config/authority_matrix.json",
    "scripts/lib/orch_gateway.py",
}

# Rollback strategies
ROLLBACK_STRATEGIES = {
    "git_revert": "Revert commits using git revert",
    "file_restore": "Restore files from baseline ref",
    "state_reset": "Reset state to baseline",
}


class RollbackError(Exception):
    """Base class for rollback errors."""

    def __init__(self, message: str, run_id: str | None = None, request_id: str | None = None):
        self.run_id = run_id
        self.request_id = request_id
        super().__init__(message)


class RollbackPrereqMissingError(RollbackError):
    """Raised when rollback prerequisites are missing."""

    def __init__(self, missing: list[str], run_id: str | None = None, request_id: str | None = None):
        self.missing = missing
        msg = f"Rollback prerequisites missing: {', '.join(missing)}"
        super().__init__(msg, run_id, request_id)


class ProtectedTargetApprovalRequiredError(RollbackError):
    """Raised when rollback targets protected resources without approval."""

    def __init__(self, targets: list[str], run_id: str | None = None, request_id: str | None = None):
        self.targets = targets
        msg = f"Protected target approval required for: {', '.join(targets)}"
        super().__init__(msg, run_id, request_id)


def validate_rollback_prereqs(run: dict[str, Any], request: dict[str, Any]) -> list[str]:
    """Validate rollback prerequisites.

    Returns list of missing prerequisites. Empty list means all prerequisites met.
    """
    missing = []

    # Check baseline_ref exists
    baseline_ref = request.get("baseline_ref") or run.get("baseline_ref")
    if not baseline_ref:
        missing.append("baseline_ref")

    # Check run_id exists
    if not run.get("run_id"):
        missing.append("run_id")

    # Check request has required fields
    if not request.get("request_id"):
        missing.append("request_id")

    if not request.get("requested_stage"):
        missing.append("requested_stage")

    return missing


def check_protected_targets(changed_refs: list[str]) -> list[str]:
    """Check if any changed refs target protected resources.

    Returns list of protected targets that need approval.
    """
    protected = []
    for ref in changed_refs:
        # Normalize path
        normalized = ref.lstrip("./")
        if normalized in PROTECTED_TARGETS:
            protected.append(normalized)
    return protected


def create_rollback_request(
    run_id: str,
    requested_stage: str,
    baseline_ref: str,
    reason: str,
    authority: str = "human",
) -> dict[str, Any]:
    """Create a rollback request."""
    request_id = f"rollback-{run_id}-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
    return {
        "request_id": request_id,
        "run_id": run_id,
        "requested_stage": requested_stage,
        "baseline_ref": baseline_ref,
        "reason": reason,
        "authority": authority,
        "status": "pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


def execute_rollback(
    run: dict[str, Any],
    request: dict[str, Any],
    dry_run: bool = False,
) -> dict[str, Any]:
    """Create a rollback execution report.

    Args:
        run: Current run state
        request: Rollback request
        dry_run: If True, mark the report as dry-run. If False, perform the
            same report-only simulation while preserving approval gates.

    Returns:
        Rollback report dict

    Raises:
        RollbackPrereqMissingError: If prerequisites are missing
        ProtectedTargetApprovalRequiredError: If protected targets need approval
    """
    run_id = run.get("run_id", "unknown")
    request_id = request.get("request_id", "unknown")

    # Validate prerequisites
    missing = validate_rollback_prereqs(run, request)
    if missing:
        raise RollbackPrereqMissingError(missing, run_id, request_id)

    baseline_ref = request["baseline_ref"]
    requested_stage = request["requested_stage"]

    # Get changed refs from run
    changed_refs = run.get("changed_refs", [])

    # Check protected targets
    protected = check_protected_targets(changed_refs)
    if protected and not dry_run:
        raise ProtectedTargetApprovalRequiredError(protected, run_id, request_id)

    # Determine affected refs (current-run only)
    affected_refs = [ref for ref in changed_refs if ref.startswith("state://runs/")]

    # Execute rollback based on strategy
    strategy = request.get("rollback_strategy", "git_revert")
    result = "simulated" if not dry_run else "dry_run"

    if not dry_run:
        # Report-only gate: do not execute destructive rollback commands here.
        pass

    # Create rollback report
    report = {
        "run_id": run_id,
        "request_id": request_id,
        "requested_stage": requested_stage,
        "baseline_ref": baseline_ref,
        "rollback_strategy": strategy,
        "affected_refs": affected_refs,
        "protected_target_check": {
            "protected_targets": protected,
            "approved": len(protected) == 0,
        },
        "result": result,
        "reason": request.get("reason", ""),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": datetime.now(timezone.utc).isoformat() if not dry_run else None,
    }

    return report


def write_rollback_report(report: dict[str, Any], state_dir: str | Path) -> Path:
    """Write rollback report to state directory."""
    state_dir = Path(state_dir)
    state_dir.mkdir(parents=True, exist_ok=True)

    report_path = state_dir / "rollback_report.json"
    writer = AtomicWriter()
    writer.write_json(report_path, report)

    return report_path


def load_rollback_report(state_dir: str | Path) -> dict[str, Any] | None:
    """Load rollback report from state directory."""
    state_dir = Path(state_dir)
    report_path = state_dir / "rollback_report.json"

    if not report_path.exists():
        return None

    try:
        with open(report_path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None
