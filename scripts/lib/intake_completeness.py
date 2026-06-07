#!/usr/bin/env python3
"""Intake Completeness for PRD Compliance.

Completes PRD intake bundle fields with CI/CD detection, 8-part prompt envelope,
and verified facts vs unverified assumptions separation.

Integration:
    Gateway/project discovery callers use this module to create and validate
    PRD intake bundles before stage advancement. The CLI wrapper
    scripts/bin/orch-intake-completeness exposes the same validation to agents.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import PurePosixPath
from typing import Any


# PRD-required prompt envelope parts
PROMPT_ENVELOPE_PARTS = [
    "task_description",
    "acceptance_criteria",
    "technical_constraints",
    "dependencies",
    "success_metrics",
    "risks_and_assumptions",
    "verification_plan",
    "rollback_strategy",
]


class IntakeError(Exception):
    """Base class for intake errors."""

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


class MissingPromptEnvelopePartError(IntakeError):
    """Raised when prompt envelope is missing required parts."""

    def __init__(self, run_id: str, missing_parts: list[str]):
        self.missing_parts = missing_parts
        msg = f"Missing prompt envelope parts: {', '.join(missing_parts)}"
        super().__init__(msg, run_id)


class MissingCIDiscoveryError(IntakeError):
    """Raised when CI/CD discovery fields are missing."""

    def __init__(self, run_id: str, missing_fields: list[str]):
        self.missing_fields = missing_fields
        msg = f"Missing CI/CD discovery fields: {', '.join(missing_fields)}"
        super().__init__(msg, run_id)


def detect_cicd_config(files_changed: list[str], file_contents: dict[str, str] | None = None) -> dict[str, Any]:
    """Detect CI/CD configuration from changed files.

    Returns dict with detected CI/CD systems and their configs.
    """
    cicd_config = {
        "detected_systems": [],
        "config_files": [],
        "has_tests": False,
        "has_linting": False,
        "has_deployment": False,
    }

    def normalize_path(filepath: str) -> str:
        path = PurePosixPath(filepath).as_posix()
        while path.startswith("./"):
            path = path[2:]
        return path

    def matches_cicd_config(filepath: str, system: str) -> bool:
        path = normalize_path(filepath)
        name = PurePosixPath(path).name

        if system == "github_actions":
            return path.startswith(".github/workflows/") or path.startswith(".github/actions/")
        if system == "gitlab_ci":
            return path == ".gitlab-ci.yml" or path.startswith(".gitlab-ci/")
        if system == "circleci":
            return path == ".circleci/config.yml"
        if system == "jenkins":
            return name == "Jenkinsfile" or path.startswith("jenkins/")
        if system == "travis":
            return path == ".travis.yml"
        if system == "docker":
            return name == "Dockerfile" or path in {"docker-compose.yml", "docker-compose.yaml"}
        if system == "kubernetes":
            return path.startswith("kubernetes/") or path.startswith("k8s/") or path.startswith("helm/")
        return False

    cicd_systems = [
        "github_actions",
        "gitlab_ci",
        "circleci",
        "jenkins",
        "travis",
        "docker",
        "kubernetes",
    ]

    # Check file paths
    for filepath in files_changed:
        for system in cicd_systems:
            if matches_cicd_config(filepath, system):
                if system not in cicd_config["detected_systems"]:
                    cicd_config["detected_systems"].append(system)
                cicd_config["config_files"].append(filepath)

    # Check file contents for CI/CD indicators
    if file_contents:
        for filepath, content in file_contents.items():
            content_lower = content.lower()
            if "test" in filepath.lower() or "test" in content_lower:
                cicd_config["has_tests"] = True
            if "lint" in filepath.lower() or "lint" in content_lower:
                cicd_config["has_linting"] = True
            if "deploy" in filepath.lower() or "deploy" in content_lower:
                cicd_config["has_deployment"] = True

    return cicd_config


def validate_prompt_envelope(
    run_id: str,
    prompt_envelope: dict[str, Any],
) -> None:
    """Validate that prompt envelope contains all 8 PRD-required parts.

    Raises MissingPromptEnvelopePartError if parts are missing.
    """
    missing = []
    for part in PROMPT_ENVELOPE_PARTS:
        if part not in prompt_envelope or _is_blank_prompt_value(prompt_envelope[part]):
            missing.append(part)

    if missing:
        raise MissingPromptEnvelopePartError(run_id, missing)


def validate_cicd_discovery(
    run_id: str,
    cicd_discovery: dict[str, Any],
) -> None:
    """Validate that CI/CD discovery fields are present.

    Raises MissingCIDiscoveryError if required fields are missing.
    """
    required_fields = ["detected_systems", "config_files"]
    missing = []
    for field in required_fields:
        if field not in cicd_discovery or not cicd_discovery[field]:
            missing.append(field)

    has_ci_capability = any(
        bool(cicd_discovery.get(field))
        for field in ("has_tests", "has_linting", "has_deployment")
    )
    if not has_ci_capability:
        missing.append("ci_capability")

    if missing:
        raise MissingCIDiscoveryError(run_id, missing)


def _is_blank_prompt_value(value: Any) -> bool:
    if not value:
        return True
    if isinstance(value, str):
        return not value.strip()
    if isinstance(value, list):
        return all(not isinstance(item, str) or not item.strip() for item in value)
    return False


def separate_facts_and_assumptions(
    facts: list[str],
    assumptions: list[str],
) -> dict[str, Any]:
    """Separate verified facts from unverified assumptions."""
    return {
        "verified_facts": facts,
        "unverified_assumptions": assumptions,
        "facts_count": len(facts),
        "assumptions_count": len(assumptions),
    }


def create_intake_bundle(
    run_id: str,
    task_description: str,
    acceptance_criteria: list[str],
    technical_constraints: list[str],
    dependencies: list[str],
    success_metrics: list[str],
    risks_and_assumptions: list[str],
    verification_plan: list[str],
    rollback_strategy: str,
    files_changed: list[str],
    file_contents: dict[str, str] | None = None,
    verified_facts: list[str] | None = None,
    unverified_assumptions: list[str] | None = None,
) -> dict[str, Any]:
    """Create a complete intake bundle with all PRD-required fields."""
    # Create prompt envelope
    prompt_envelope = {
        "task_description": task_description,
        "acceptance_criteria": acceptance_criteria,
        "technical_constraints": technical_constraints,
        "dependencies": dependencies,
        "success_metrics": success_metrics,
        "risks_and_assumptions": risks_and_assumptions,
        "verification_plan": verification_plan,
        "rollback_strategy": rollback_strategy,
    }

    # Detect CI/CD config
    cicd_discovery = detect_cicd_config(files_changed, file_contents)

    # Separate facts and assumptions
    facts_assumptions = separate_facts_and_assumptions(
        verified_facts or [],
        unverified_assumptions or []
    )

    return {
        "run_id": run_id,
        "prompt_envelope": prompt_envelope,
        "cicd_discovery": cicd_discovery,
        "facts_and_assumptions": facts_assumptions,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


def validate_intake_bundle(run_id: str, bundle: dict[str, Any]) -> list[str]:
    """Validate intake bundle completeness.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []

    # Validate prompt envelope
    try:
        validate_prompt_envelope(run_id, bundle.get("prompt_envelope", {}))
    except MissingPromptEnvelopePartError as e:
        errors.append(f"missing_prompt_envelope_parts: {e.missing_parts}")

    # Validate CI/CD discovery
    try:
        validate_cicd_discovery(run_id, bundle.get("cicd_discovery", {}))
    except MissingCIDiscoveryError as e:
        errors.append(f"missing_cicd_discovery_fields: {e.missing_fields}")

    return errors
