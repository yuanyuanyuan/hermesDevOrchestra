from __future__ import annotations

from typing import Any


class SecurityGateError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class SecurityGate:
    def evaluate(self, scan: dict[str, Any]) -> dict[str, Any]:
        """Convert an evidence scan into an allow/block security verdict.

        Args:
            scan: Result object returned by `EvidenceScanner.scan`.

        Returns:
            A verdict object with `verdict`, `security_pass`, `block_reason`, and `scan_result`.

        Raises:
            SecurityGateError: When `scan` is not an object.
        """
        if not isinstance(scan, dict):
            raise SecurityGateError("validation_error", "scan must be an object")

        if scan.get("pii_detected") is True:
            return self._block("pii_detected", scan)
        if scan.get("sensitive_keywords"):
            return self._block("sensitive_keywords_detected", scan)
        if scan.get("hardcode_flags"):
            return self._block("hardcode_flags_detected", scan)
        if scan.get("lint_pass") is False:
            return self._block("lint_failed", scan)
        if scan.get("syntax_pass") is False:
            return self._block("syntax_failed", scan)
        if scan.get("i18n_pass") is False:
            return self._block("i18n_failed", scan)

        return {
            "verdict": "allow",
            "security_pass": True,
            "block_reason": None,
            "scan_result": dict(scan),
        }

    def _block(self, reason: str, scan: dict[str, Any]) -> dict[str, Any]:
        return {
            "verdict": "block",
            "security_pass": False,
            "block_reason": reason,
            "scan_result": dict(scan),
        }
