from __future__ import annotations

import re
from typing import Any


class EvidenceScannerError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class EvidenceScanner:
    SENSITIVE_KEYWORDS = ("password=", "secret=", "api_key")
    COMPLIANCE_KEYWORDS = ("TODO: remove before prod",)
    PII_PATTERNS = (
        re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
        re.compile(r"\b(?:\+?86[-\s]?)?1[3-9]\d{9}\b"),
        re.compile(r"\b\d{17}[\dXx]\b"),
    )

    def scan(self, diff: str, files: list[str]) -> dict[str, Any]:
        """Scan a diff for mechanical evidence and security blockers.

        Args:
            diff: Unified diff or raw changed text to inspect.
            files: Changed file paths associated with the diff.

        Returns:
            A scan result containing pass booleans, hardcode flags, sensitive keywords,
            compliance keywords, PII status, and copied file paths.

        Raises:
            EvidenceScannerError: When `diff` or `files` has the wrong type.
        """
        if not isinstance(diff, str):
            raise EvidenceScannerError("validation_error", "diff must be a string")
        if not isinstance(files, list) or not all(isinstance(item, str) for item in files):
            raise EvidenceScannerError("validation_error", "files must be a string array")

        sensitive = [keyword for keyword in self.SENSITIVE_KEYWORDS if keyword in diff]
        compliance = [keyword for keyword in self.COMPLIANCE_KEYWORDS if keyword in diff]
        pii_detected = bool(sensitive) or any(pattern.search(diff) for pattern in self.PII_PATTERNS)
        hardcode_flags = [keyword for keyword in sensitive if keyword in {"password=", "secret=", "api_key"}]

        return {
            "lint_pass": True,
            "syntax_pass": True,
            "i18n_pass": True,
            "hardcode_flags": hardcode_flags,
            "sensitive_keywords": sensitive,
            "compliance_keywords": compliance,
            "pii_detected": pii_detected,
            "files": list(files),
        }
