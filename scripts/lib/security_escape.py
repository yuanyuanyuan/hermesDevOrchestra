#!/usr/bin/env python3
"""Security Escape Rules for PRD Compliance.

Forces sensitive diffs to Standard channel and records forced_standard_reasons.
"""

from __future__ import annotations

import re
from typing import Any


# Security patterns that force Standard channel
SECURITY_PATTERNS = [
    # Authentication patterns
    r"\b(password|passwd|secrets?|token|api_key|apikey|access_key|private_key)\b",
    # PII patterns
    r"(ssn|social_security|credit_card|bank_account|passport)",
    # Protected target patterns
    r"(config/release/|config/authority_matrix|config/schemas/)",
    # Database patterns
    r"(DROP\s+TABLE|DELETE\s+FROM|TRUNCATE|ALTER\s+TABLE)",
    # Encryption patterns
    r"\b(encrypt|decrypt|cipher|bcrypt|scrypt)\b",
    # Network patterns
    r"\b(firewall|proxy|vpn|tls|ssl|certificate)\b",
]

# Compiled patterns for efficiency
COMPILED_PATTERNS = [re.compile(p, re.IGNORECASE) for p in SECURITY_PATTERNS]


class SecurityEscapeError(Exception):
    """Raised when security escape detection fails."""
    # Reserved for future validation failures in this module's public API.

    def __init__(self, message: str, run_id: str | None = None):
        self.run_id = run_id
        super().__init__(message)


def detect_security_escape(files_changed: list[str], file_contents: dict[str, str] | None = None) -> list[str]:
    """Detect security escape patterns in changed files.

    Args:
        files_changed: List of file paths changed
        file_contents: Optional dict mapping file paths to their contents

    Returns:
        List of matched security patterns
    """
    matched_patterns = []

    # Check file paths for protected targets
    for filepath in files_changed:
        for i, pattern in enumerate(COMPILED_PATTERNS):
            if pattern.search(filepath):
                matched_patterns.append(SECURITY_PATTERNS[i])

    # Check file contents if provided
    if file_contents:
        for filepath, content in file_contents.items():
            for i, pattern in enumerate(COMPILED_PATTERNS):
                if pattern.search(content):
                    matched_patterns.append(SECURITY_PATTERNS[i])

    return list(set(matched_patterns))  # Deduplicate


def force_standard_for_security(
    run: dict[str, Any],
    files_changed: list[str],
    file_contents: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Force Standard channel for security-sensitive diffs.

    Modifies ``run`` in-place.

    Returns updated run dict with forced_standard=True and forced_standard_reasons.
    """
    # Detect security escape patterns
    matched = detect_security_escape(files_changed, file_contents)

    if matched:
        # Force Standard channel
        run["channel_decision"] = run.get("channel_decision", {})
        run["channel_decision"]["forced_standard"] = True
        run["channel_decision"]["forced_standard_reasons"] = [
            f"security_pattern:{pattern}" for pattern in matched
        ]
        run["channel_decision"]["channel"] = "standard"

        # Update channel requirements to Standard
        run["channel_requirements"] = {
            "required_debate_rounds": 3,
            "required_evidence": ["task_description", "impact_analysis", "risk_assessment", "test_plan"],
            "allowed_stage_skips": [],
            "max_files": 50,
            "timeout_minutes": 120,
        }

    return run


def validate_security_escape(run: dict[str, Any]) -> list[str]:
    """Validate security escape handling on run.

    Returns list of validation errors. Empty list means valid.
    """
    errors = []
    channel_decision = run.get("channel_decision", {})

    if channel_decision.get("forced_standard") and not channel_decision.get("forced_standard_reasons"):
        errors.append("forced_standard=True but forced_standard_reasons missing")

    if channel_decision.get("forced_standard") and channel_decision.get("channel") != "standard":
        errors.append("forced_standard=True but channel is not standard")

    reasons = channel_decision.get("forced_standard_reasons")
    if channel_decision.get("forced_standard") and reasons:
        if not isinstance(reasons, list):
            errors.append("forced_standard_reasons must be a list")
        else:
            for reason in reasons:
                if not isinstance(reason, str) or not reason.startswith("security_pattern:"):
                    errors.append("forced_standard_reasons entries must start with security_pattern:")
                    break

    return errors
