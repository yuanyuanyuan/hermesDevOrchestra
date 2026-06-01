from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class ChannelRouterError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class ChannelRouter:
    QUICK_TASKS = {"lint", "syntax", "i18n", "hardcoded_scan", "hardcode_scan"}

    def __init__(
        self,
        repo_root: Path | str,
        policy_path: str = "config/performance/slo-policy.json",
        routing_log_path: str = "logs/channel-routing.jsonl",
    ) -> None:
        self.repo_root = Path(repo_root)
        self.policy_path = policy_path
        self.routing_log_path = routing_log_path
        self._policy: dict[str, Any] | None = None

    def classify(self, intent: dict[str, Any], project_age_weeks: int, profile: dict[str, Any] | None = None) -> dict[str, Any]:
        if not isinstance(intent, dict):
            raise ChannelRouterError("validation_error", "intent must be an object")
        if not isinstance(project_age_weeks, int) or project_age_weeks < 1:
            raise ChannelRouterError("validation_error", "project_age_weeks must be a positive integer")

        policy = self._load_policy()
        channels = self._channels(policy)
        task_type = str(intent.get("task_type") or intent.get("type") or "").strip()
        files_count = self._files_count(intent)

        if self._is_quick_candidate(task_type, files_count, project_age_weeks):
            if project_age_weeks <= 2 and files_count > 1:
                return self._decision("standard", "week_1_2_quick_file_limit_exceeded", task_type, files_count, project_age_weeks)
            if project_age_weeks == 3 and files_count > 1:
                return self._decision("standard", "week_3_quick_file_limit_exceeded", task_type, files_count, project_age_weeks)
            if project_age_weeks >= 4 and files_count > int(channels["quick"]["max_files"]):
                return self._decision("standard", "week_4_plus_quick_file_limit_exceeded", task_type, files_count, project_age_weeks)
            return self._apply_kill_switch("quick", task_type, files_count, project_age_weeks, channels)

        if files_count <= int(channels["light"]["max_files"]):
            return self._decision("light", "medium_complexity_light_channel", task_type, files_count, project_age_weeks)

        return self._decision("standard", "standard_required_for_complexity", task_type, files_count, project_age_weeks)

    def _is_quick_candidate(self, task_type: str, files_count: int, project_age_weeks: int) -> bool:
        if task_type in self.QUICK_TASKS:
            return True
        if project_age_weeks == 3 and task_type == "single_file_refactor" and files_count == 1:
            return True
        if project_age_weeks >= 4 and task_type in {"refactor", "single_file_refactor"} and files_count <= 3:
            return True
        return False

    def _apply_kill_switch(
        self,
        channel: str,
        task_type: str,
        files_count: int,
        project_age_weeks: int,
        channels: dict[str, Any],
    ) -> dict[str, Any]:
        if channel != "quick" or channels["quick"].get("enabled") is True:
            return self._decision(channel, "quick_rollout_allowed", task_type, files_count, project_age_weeks)

        routed = "light" if channels["light"].get("enabled") is True else "standard"
        decision = self._decision(routed, "quick_channel_disabled", task_type, files_count, project_age_weeks)
        decision["original_channel"] = "quick"
        decision["downgrade_reason"] = "kill_switch_enabled"
        self._write_routing_log(decision)
        return decision

    def _decision(self, channel: str, reason: str, task_type: str, files_count: int, project_age_weeks: int) -> dict[str, Any]:
        return {
            "channel": channel,
            "reason": reason,
            "task_type": task_type,
            "files_count": files_count,
            "project_age_weeks": project_age_weeks,
        }

    def _files_count(self, intent: dict[str, Any]) -> int:
        raw = intent.get("files_count")
        if raw is None and isinstance(intent.get("files"), list):
            raw = len(intent["files"])
        if raw is None:
            raw = 1
        if not isinstance(raw, int) or raw < 0:
            raise ChannelRouterError("validation_error", "files_count must be a non-negative integer")
        return raw

    def _load_policy(self) -> dict[str, Any]:
        if self._policy is None:
            path = self.repo_root / self.policy_path
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise ChannelRouterError("config_invalid", f"slo-policy.json is not valid JSON: {exc.msg}") from exc
            except FileNotFoundError as exc:
                raise ChannelRouterError("config_invalid", "slo-policy.json is missing") from exc
            if not isinstance(data, dict):
                raise ChannelRouterError("config_invalid", "slo-policy.json must contain an object")
            self._policy = data
        return self._policy

    def _channels(self, policy: dict[str, Any]) -> dict[str, Any]:
        channels = policy.get("channels")
        if not isinstance(channels, dict):
            raise ChannelRouterError("config_invalid", "slo-policy.json must define channels")
        for name in ("quick", "light", "standard"):
            channel = channels.get(name)
            if not isinstance(channel, dict):
                raise ChannelRouterError("config_invalid", f"channels.{name} must be an object")
            if not isinstance(channel.get("enabled"), bool):
                raise ChannelRouterError("config_invalid", f"channels.{name}.enabled must be a boolean")
            if not isinstance(channel.get("max_files"), int):
                raise ChannelRouterError("config_invalid", f"channels.{name}.max_files must be an integer")
            if not isinstance(channel.get("required_evidence"), list):
                raise ChannelRouterError("config_invalid", f"channels.{name}.required_evidence must be an array")
        return channels

    def _write_routing_log(self, decision: dict[str, Any]) -> None:
        path = self.repo_root / self.routing_log_path
        path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "logged_at": datetime.now(timezone.utc).isoformat(),
            "original_channel": decision["original_channel"],
            "routed_channel": decision["channel"],
            "downgrade_reason": decision["downgrade_reason"],
            "reason": decision["reason"],
            "project_age_weeks": decision["project_age_weeks"],
            "files_count": decision["files_count"],
            "task_type": decision["task_type"],
        }
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
