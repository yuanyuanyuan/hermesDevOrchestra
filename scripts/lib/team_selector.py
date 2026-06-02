from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from security_scanner import SecurityScanner


DEFAULT_MAX_TEAMS = 16
HARD_MAX_TEAMS = 64


class TeamSelectorError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True)
class TeamList:
    selected_team_ids: list[str]
    canonical_team_ids: list[str]
    extension_team_ids: list[str]
    alias_resolutions: dict[str, str]
    security_blocked_team_ids: list[str]
    config_error: str | None = None


class TeamSelector:
    def __init__(self, repo_root: Path | str, package_root: str = "config/debate/full") -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root

    def select(self, task_type: str, project_profile: dict[str, Any] | None = None) -> TeamList:
        profile = project_profile or {}
        max_teams = self._max_teams(profile)
        teams = self._load_teams()
        alias_map = self._load_alias_map()
        canonical_ids = [team["id"] for team in teams]

        requested, alias_resolutions = self._requested_team_ids(task_type, profile, alias_map)
        selected = list(canonical_ids)
        for team_id in requested:
            if team_id not in selected:
                selected.append(team_id)

        extension_ids: list[str] = []
        blocked_ids: list[str] = []
        scanner = SecurityScanner(self.repo_root)
        for custom_team in profile.get("custom_teams", []):
            team_id = custom_team.get("id")
            if not isinstance(team_id, str) or not team_id:
                continue
            report = scanner.scan(custom_team.get("prompt_injection", ""), team_id=team_id)
            if report["status"] == "blocked":
                blocked_ids.append(team_id)
                continue
            if team_id not in selected:
                selected.append(team_id)
                extension_ids.append(team_id)

        if len(selected) > max_teams:
            selected = selected[:max_teams]
            extension_ids = [team_id for team_id in extension_ids if team_id in selected]

        result = TeamList(
            selected_team_ids=selected,
            canonical_team_ids=[team_id for team_id in selected if team_id in canonical_ids],
            extension_team_ids=extension_ids,
            alias_resolutions=alias_resolutions,
            security_blocked_team_ids=blocked_ids,
        )
        self._append_selection_log(task_type, result)
        return result

    def _max_teams(self, profile: dict[str, Any]) -> int:
        max_teams = profile.get("max_teams", DEFAULT_MAX_TEAMS)
        if not isinstance(max_teams, int) or max_teams < 1:
            raise TeamSelectorError("config_error", "max_teams must be an integer between 1 and 64")
        if max_teams > HARD_MAX_TEAMS:
            raise TeamSelectorError("config_error", "max_teams exceeds hard limit 64")
        return max_teams

    def _requested_team_ids(self, task_type: str, profile: dict[str, Any], alias_map: dict[str, str]) -> tuple[list[str], dict[str, str]]:
        requested = list(profile.get("team_ids", []))
        if task_type == "refactor" and "platform" not in requested:
            requested.append("platform")
        resolved: list[str] = []
        alias_resolutions: dict[str, str] = {}
        for team_id in requested:
            if not isinstance(team_id, str):
                continue
            canonical = alias_map.get(team_id, team_id)
            if canonical != team_id:
                alias_resolutions[team_id] = canonical
            resolved.append(canonical)
        return resolved, alias_resolutions

    def _load_teams(self) -> list[dict[str, Any]]:
        data = self._load_json("teams.json")
        teams = data.get("teams")
        if not isinstance(teams, list):
            raise TeamSelectorError("config_error", "teams.json must define teams")
        return teams

    def _load_alias_map(self) -> dict[str, str]:
        data = self._load_json("alias-mapping.json")
        mappings = data.get("mappings")
        if not isinstance(mappings, list) or len(mappings) < 3:
            raise TeamSelectorError("config_error", "alias-mapping.json must define at least 3 mappings")
        return {entry["alias"]: entry["canonical_team"] for entry in mappings}

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except FileNotFoundError as exc:
            raise TeamSelectorError("config_error", f"{filename} is missing") from exc
        except json.JSONDecodeError as exc:
            raise TeamSelectorError("config_error", f"{filename} is not valid JSON: {exc.msg}") from exc
        if not isinstance(data, dict):
            raise TeamSelectorError("config_error", f"{filename} must be a JSON object")
        return data

    def _append_selection_log(self, task_type: str, result: TeamList) -> None:
        log_path = self.repo_root / "logs/team-selection.jsonl"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "task_type": task_type,
            "selected_team_ids": result.selected_team_ids,
            "alias_resolutions": result.alias_resolutions,
            "security_blocked_team_ids": result.security_blocked_team_ids,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, sort_keys=True) + "\n")
