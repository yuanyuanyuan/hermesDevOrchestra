from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


class MergeRejectedError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class AutoMergeController:
    def __init__(
        self,
        repo_root: Path | str,
        policy_path: str = "config/performance/slo-policy.json",
        audit_log_path: str = "logs/auto-merge-audit.jsonl",
    ) -> None:
        self.repo_root = Path(repo_root)
        self.policy_path = policy_path
        self.audit_log_path = audit_log_path
        self._policy: dict[str, Any] | None = None

    def merge(self, target_branch: str, pr_number: int, audit_context: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(target_branch, str) or not target_branch:
            raise MergeRejectedError("validation_error", "target_branch must be a non-empty string")
        if not isinstance(pr_number, int) or pr_number <= 0:
            raise MergeRejectedError("validation_error", "pr_number must be a positive integer")
        if not isinstance(audit_context, dict):
            raise MergeRejectedError("validation_error", "audit_context must be an object")

        policy = self._auto_merge_policy()
        if target_branch == "main":
            self._audit("auto_merge_blocked", "main_protected", target_branch, pr_number, audit_context)
            raise MergeRejectedError("protected_branch", "target branch main is protected")
        if target_branch not in policy["allowed_target_branches"]:
            self._audit("auto_merge_blocked", "target_branch_not_allowed", target_branch, pr_number, audit_context)
            raise MergeRejectedError("target_branch_not_allowed", f"target branch {target_branch} is not allowed")

        gate_verdict = audit_context.get("gate_verdict")
        if isinstance(gate_verdict, dict) and gate_verdict.get("security_pass") is False:
            reason = str(gate_verdict.get("block_reason") or "security_gate_blocked")
            self._audit("auto_merge_blocked", reason, target_branch, pr_number, audit_context)
            raise MergeRejectedError("auto_merge_blocked", reason)

        required_reviews = int(policy["required_reviews"])
        if int(audit_context.get("reviews", 0)) < required_reviews:
            self._audit("auto_merge_blocked", "branch_protection_reviews_missing", target_branch, pr_number, audit_context)
            raise MergeRejectedError("branch_protection_failed", "required review count was not met")
        if audit_context.get("ci_pass") is not True:
            self._audit("auto_merge_blocked", "branch_protection_ci_failed", target_branch, pr_number, audit_context)
            raise MergeRejectedError("branch_protection_failed", "required CI status was not met")

        receipt = {
            "status": "merged",
            "target_branch": target_branch,
            "pr_number": pr_number,
            "merged_at": self._timestamp(),
            "audit_ref": f"{self.audit_log_path}#{pr_number}",
        }
        self._audit("auto_merge_merged", "branch_protection_passed", target_branch, pr_number, audit_context)
        return receipt

    def _auto_merge_policy(self) -> dict[str, Any]:
        policy = self._load_policy().get("auto_merge", {})
        allowed = policy.get("allowed_target_branches", ["staging"])
        if not isinstance(allowed, list) or not all(isinstance(item, str) for item in allowed):
            raise MergeRejectedError("config_invalid", "auto_merge.allowed_target_branches must be a string array")
        return {
            "allowed_target_branches": allowed,
            "required_reviews": policy.get("required_reviews", 1),
        }

    def _load_policy(self) -> dict[str, Any]:
        if self._policy is None:
            path = self.repo_root / self.policy_path
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise MergeRejectedError("config_invalid", f"slo-policy.json is not valid JSON: {exc.msg}") from exc
            except FileNotFoundError as exc:
                raise MergeRejectedError("config_invalid", "slo-policy.json is missing") from exc
            if not isinstance(data, dict):
                raise MergeRejectedError("config_invalid", "slo-policy.json must contain an object")
            self._policy = data
        return self._policy

    def _audit(self, action: str, reason: str, target_branch: str, pr_number: int, audit_context: dict[str, Any]) -> None:
        path = self.repo_root / self.audit_log_path
        path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "logged_at": self._timestamp(),
            "action": action,
            "reason": reason,
            "original_target_branch": target_branch,
            "pr_number": pr_number,
            "auto_merge": bool(audit_context.get("auto_merge")),
        }
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()


class NotificationDispatcher:
    def __init__(
        self,
        repo_root: Path | str,
        log_path: str = "logs/notifications.jsonl",
        sender: Callable[[str], Any] | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.log_path = log_path
        self.sender = sender

    def send(self, level: str, scan_result: dict[str, Any]) -> dict[str, Any]:
        if level not in {"silent", "compact", "verbose"}:
            raise ValueError("level must be silent, compact, or verbose")
        if not isinstance(scan_result, dict):
            raise ValueError("scan_result must be an object")

        message = ""
        sent = False
        if level == "compact":
            message = self._compact_message(scan_result)
            sent = True
        elif level == "verbose":
            message = "ScanResult: " + json.dumps(scan_result, ensure_ascii=False, sort_keys=True)
            sent = True

        if sent and self.sender is not None:
            self.sender(message)
        self._log(level, sent, message)
        return {"level": level, "sent": sent, "message": message}

    def _compact_message(self, scan_result: dict[str, Any]) -> str:
        sensitive = ",".join(scan_result.get("sensitive_keywords", [])) or "none"
        pii = "yes" if scan_result.get("pii_detected") is True else "no"
        message = f"Security scan: pii={pii}; sensitive={sensitive}"
        return message[:200]

    def _log(self, level: str, sent: bool, message: str) -> None:
        path = self.repo_root / self.log_path
        path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "logged_at": datetime.now(timezone.utc).isoformat(),
            "level": level,
            "sent": sent,
            "message": message,
        }
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
