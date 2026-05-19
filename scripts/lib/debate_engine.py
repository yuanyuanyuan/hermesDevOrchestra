from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_QUESTION_MAX_LENGTH = 4000
_METADATA_MAX_LENGTH = 4000


class DebateEngineError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class DebateEngine:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/debate/full",
        allow_staged: bool = False,
        enabled: bool = True,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self._registries: dict[str, Any] | None = None

    def load_registries(self) -> dict[str, Any]:
        self._require_enabled()
        teams_data = self._load_json("teams.json")
        modes_data = self._load_json("modes.json")
        self._require_package_active(teams_data, "teams.json")
        self._require_package_active(modes_data, "modes.json")

        teams = self._require_list(teams_data, "teams")
        modes = self._require_list(modes_data, "modes")
        if not teams or not modes:
            raise DebateEngineError("empty_registry", "teams and modes registries must not be empty")

        member_team_index: dict[str, str] = {}
        team_ids: list[str] = []
        for team in teams:
            team_id = self._require_string(team, "id", "team entry")
            self._require_string(team, "name", f"team {team_id}")
            members = self._require_list(team, "members")
            if len(members) < 3:
                raise DebateEngineError("config_invalid", f"team {team_id} must contain at least 3 members")
            team_ids.append(team_id)
            for member in members:
                member_id = self._require_string(member, "id", f"team {team_id} member")
                if member_id in member_team_index:
                    raise DebateEngineError("config_invalid", f"member {member_id} is defined more than once")
                member_team_index[member_id] = team_id

        mode_ids: list[str] = []
        for mode in modes:
            mode_id = self._require_string(mode, "id", "mode entry")
            self._require_string(mode, "name", f"mode {mode_id}")
            mode_ids.append(mode_id)

        self._registries = {
            "teams": teams,
            "modes": modes,
            "team_ids": team_ids,
            "mode_ids": mode_ids,
            "member_team_index": member_team_index,
            "package_root": self.package_root,
            "package_status": teams_data.get("package_status"),
        }
        return self._registries

    def create_run(
        self,
        question: str,
        mode_id: str,
        selected_member_ids: list[str] | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        registries = self.load_registries()
        if not isinstance(question, str) or not question.strip():
            raise DebateEngineError("validation_error", "question must be a non-empty string")
        if len(question.strip()) > _QUESTION_MAX_LENGTH:
            raise DebateEngineError("validation_error", f"question must be <= {_QUESTION_MAX_LENGTH} characters")
        if not isinstance(mode_id, str) or not mode_id:
            raise DebateEngineError("validation_error", "mode_id must be a non-empty string")
        if mode_id not in registries["mode_ids"]:
            raise DebateEngineError("mode_not_found", f"unknown debate mode: {mode_id}")
        if metadata is None:
            metadata = {}
        if not isinstance(metadata, dict):
            raise DebateEngineError("validation_error", "metadata must be an object")
        if len(json.dumps(metadata, ensure_ascii=False, sort_keys=True)) > _METADATA_MAX_LENGTH:
            raise DebateEngineError("validation_error", f"metadata must be <= {_METADATA_MAX_LENGTH} characters")

        if selected_member_ids is None:
            selected_member_ids = []
        if not isinstance(selected_member_ids, list):
            raise DebateEngineError("validation_error", "selected_member_ids must be a list")

        selected_team_ids = set()
        for member_id in selected_member_ids:
            if not isinstance(member_id, str) or not member_id:
                raise DebateEngineError("validation_error", "selected_member_ids entries must be non-empty strings")
            team_id = registries["member_team_index"].get(member_id)
            if team_id is None:
                raise DebateEngineError("member_not_found", f"unknown debate member: {member_id}")
            selected_team_ids.add(team_id)

        return {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "debate_run",
            "debate_id": f"debate-{uuid.uuid4().hex}",
            "status": "initialized",
            "question": question.strip(),
            "mode_id": mode_id,
            "selected_member_ids": selected_member_ids,
            "selected_team_ids": sorted(selected_team_ids),
            "package_ref": self.package_root,
            "package_status": registries["package_status"],
            "created_at": datetime.now(timezone.utc).isoformat(),
            "metadata": metadata,
        }

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise DebateEngineError("module_disabled", "debate engine is disabled")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise DebateEngineError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise DebateEngineError("config_invalid", f"{filename} is missing") from exc
        if not isinstance(data, dict):
            raise DebateEngineError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise DebateEngineError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise DebateEngineError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _require_list(self, data: dict[str, Any], key: str) -> list[dict[str, Any]]:
        value = data.get(key)
        if not isinstance(value, list):
            raise DebateEngineError("config_invalid", f"{key} must be a list")
        return value

    def _require_string(self, data: dict[str, Any], key: str, label: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise DebateEngineError("config_invalid", f"{label} is missing {key}")
        return value
