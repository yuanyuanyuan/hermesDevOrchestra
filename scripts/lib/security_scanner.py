from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DENYLIST = [
    "rm -rf",
    "mkfs.",
    "dd if=",
    "chmod -R 777",
    "chown -R",
    "DROP TABLE",
    "DELETE FROM",
    "TRUNCATE TABLE",
    "ALTER TABLE",
    "UPDATE users SET",
    "eval(",
    "exec(",
    "subprocess.call",
    "subprocess.Popen",
    "os.system",
    "curl | sh",
    "wget | sh",
    "bash -c",
    "powershell -enc",
    "Runtime.getRuntime().exec",
]

INJECTION_PATTERNS = [
    re.compile(r"\b(?:sudo\s+)?(?:rm|mkfs|dd)\b.*(?:/|\*)", re.IGNORECASE),
    re.compile(r"\b(?:eval|exec)\s*\(", re.IGNORECASE),
    re.compile(r"\b(?:DROP|DELETE|TRUNCATE)\s+(?:TABLE|FROM)\b", re.IGNORECASE),
]


class SecurityScanner:
    def __init__(self, repo_root: Path | str) -> None:
        self.repo_root = Path(repo_root)

    def scan(self, prompt_injection: str, team_id: str | None = None, write_log: bool = True) -> dict[str, Any]:
        text = prompt_injection or ""
        blocked_keywords = [keyword for keyword in DENYLIST if keyword.lower() in text.lower()]
        pattern_hits = [pattern.pattern for pattern in INJECTION_PATTERNS if pattern.search(text)]
        status = "blocked" if blocked_keywords or pattern_hits else "clear"
        report = {
            "status": status,
            "blocked_keywords": blocked_keywords,
            "pattern_hits": pattern_hits,
        }
        if write_log and team_id:
            self._append_log(team_id, text, report)
        return report

    def _append_log(self, team_id: str, text: str, report: dict[str, Any]) -> None:
        log_path = self.repo_root / "logs/security-scan.jsonl"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "team_id": team_id,
            "prompt_hash": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "scan_result": report["status"],
            "blocked_keywords": report["blocked_keywords"],
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, sort_keys=True) + "\n")
