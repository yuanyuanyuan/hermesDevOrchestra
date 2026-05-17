from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from debate_engine import DebateEngine, DebateEngineError


class DebateAssemblyError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class DebateAssembly:
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
        self._policy: dict[str, Any] | None = None

    def load_policy(self) -> dict[str, Any]:
        self._require_enabled()
        coverage_policy = self._load_json("coverage-policy.json")
        assembly_policy = self._load_json("assembly-policy.json")
        self._require_package_active(coverage_policy, "coverage-policy.json")
        self._require_package_active(assembly_policy, "assembly-policy.json")

        stage_requirements = coverage_policy.get("stage_requirements")
        if not isinstance(stage_requirements, dict) or not stage_requirements:
            raise DebateAssemblyError("config_invalid", "coverage-policy.json must define stage_requirements")
        task_type_overlays = assembly_policy.get("task_type_overlays")
        if not isinstance(task_type_overlays, dict):
            raise DebateAssemblyError("config_invalid", "assembly-policy.json must define task_type_overlays")
        risk_overlays = assembly_policy.get("risk_overlays")
        if not isinstance(risk_overlays, dict):
            raise DebateAssemblyError("config_invalid", "assembly-policy.json must define risk_overlays")

        engine = DebateEngine(
            self.repo_root,
            package_root=self.package_root,
            allow_staged=self.allow_staged,
            enabled=self.enabled,
        )
        registries = engine.load_registries()
        team_map = {team["id"]: team for team in registries["teams"]}
        mode_ids = set(registries["mode_ids"])

        self._policy = {
            "coverage_policy": coverage_policy,
            "assembly_policy": assembly_policy,
            "stage_requirements": stage_requirements,
            "task_type_overlays": task_type_overlays,
            "risk_overlays": risk_overlays,
            "team_map": team_map,
            "mode_ids": mode_ids,
            "package_root": self.package_root,
            "package_status": coverage_policy["package_status"],
        }
        return self._policy

    def select_for_stage(
        self,
        stage: str,
        task_type: str,
        risk_level: str,
        project_overrides: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        policy = self.load_policy()
        if not isinstance(stage, str) or not stage:
            raise DebateAssemblyError("validation_error", "stage must be a non-empty string")
        if not isinstance(task_type, str) or not task_type:
            raise DebateAssemblyError("validation_error", "task_type must be a non-empty string")
        if not isinstance(risk_level, str) or not risk_level:
            raise DebateAssemblyError("validation_error", "risk_level must be a non-empty string")

        stage_requirements = policy["stage_requirements"].get(stage)
        if not isinstance(stage_requirements, dict):
            raise DebateAssemblyError("stage_not_found", f"unknown debate stage: {stage}")
        risk_overlay = policy["risk_overlays"].get(risk_level)
        if not isinstance(risk_overlay, dict):
            raise DebateAssemblyError("risk_level_not_found", f"unknown risk level: {risk_level}")

        project_overrides = project_overrides or {}
        if not isinstance(project_overrides, dict):
            raise DebateAssemblyError("validation_error", "project_overrides must be a dict")

        task_type_tags = self._task_type_tags(task_type)
        overlay_ids = self._match_task_type_overlays(policy["task_type_overlays"], task_type_tags)

        selected_team_ids = set(stage_requirements["minimum_team_ids"])
        required_modes = set(stage_requirements["required_modes"])

        for overlay_id in overlay_ids:
            overlay = policy["task_type_overlays"][overlay_id]
            selected_team_ids.update(overlay.get("add_team_ids", []))
        selected_team_ids.update(risk_overlay.get("add_team_ids", []))
        required_modes.update(risk_overlay.get("required_modes", []))

        selected_team_ids.update(project_overrides.get("additional_team_ids", []))
        required_modes.update(project_overrides.get("additional_required_modes", []))

        minimum_member_count = stage_requirements["minimum_member_count"]
        override_count = project_overrides.get("minimum_member_count")
        if override_count is not None:
            if not isinstance(override_count, int) or override_count < minimum_member_count:
                raise DebateAssemblyError(
                    "validation_error",
                    "project_overrides minimum_member_count must be an int that does not lower coverage",
                )
            minimum_member_count = override_count

        unknown_teams = sorted(team_id for team_id in selected_team_ids if team_id not in policy["team_map"])
        if unknown_teams:
            raise DebateAssemblyError("config_invalid", f"assembly selected unknown teams: {unknown_teams}")

        unknown_modes = sorted(mode_id for mode_id in required_modes if mode_id not in policy["mode_ids"])
        if unknown_modes:
            raise DebateAssemblyError("config_invalid", f"assembly selected unknown modes: {unknown_modes}")

        selected_team_ids_list = sorted(selected_team_ids)
        focus_keywords = self._focus_keywords(task_type_tags, risk_level, project_overrides)
        member_selection_scores = self._score_members(
            policy["team_map"],
            selected_team_ids_list,
            task_type_tags,
            focus_keywords,
        )
        selected_member_ids = self._select_members(member_selection_scores, minimum_member_count)
        skipped_team_ids = sorted(set(policy["team_map"]) - set(selected_team_ids_list))

        return {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "debate_audit_trail",
            "audit_id": f"audit-{uuid.uuid4().hex}",
            "debate_id": f"debate-{uuid.uuid4().hex}",
            "run_id": f"assembly-{uuid.uuid4().hex}",
            "stage": stage,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "package_ref": self.package_root,
            "assembly_input": {
                "stage": stage,
                "risk_level": risk_level,
                "task_type_tags": task_type_tags,
                "project_overrides": project_overrides,
            },
            "matched_assembly_rules": [
                f"stage_floor:{stage}",
                *[f"task_type_overlay:{overlay_id}" for overlay_id in overlay_ids],
                f"risk_overlay:{risk_level}",
                "selected_team_ids",
            ],
            "risk_overlay_applied": {
                "risk_level": risk_level,
                "add_team_ids": sorted(risk_overlay.get("add_team_ids", [])),
                "required_modes": sorted(risk_overlay.get("required_modes", [])),
                "authority_required_for_stage_decision": risk_overlay.get("authority_required_for_stage_decision"),
            },
            "task_type_overlays_applied": overlay_ids,
            "project_overrides_applied": {
                "additional_team_ids": sorted(project_overrides.get("additional_team_ids", [])),
                "additional_required_modes": sorted(project_overrides.get("additional_required_modes", [])),
                "minimum_member_count": minimum_member_count,
                "focus_keywords": focus_keywords,
            },
            "selected_team_ids": selected_team_ids_list,
            "skipped_team_ids": skipped_team_ids,
            "selected_member_ids": selected_member_ids,
            "member_selection_scores": member_selection_scores,
            "coverage_requirements": {
                "minimum_team_ids": sorted(stage_requirements["minimum_team_ids"]),
                "minimum_member_count": minimum_member_count,
                "required_modes": sorted(stage_requirements["required_modes"]),
            },
            "required_modes": sorted(required_modes),
        }

    def _task_type_tags(self, task_type: str) -> list[str]:
        return [part for part in task_type.replace(",", " ").split() if part]

    def _focus_keywords(
        self,
        task_type_tags: list[str],
        risk_level: str,
        project_overrides: dict[str, Any],
    ) -> list[str]:
        keywords = list(task_type_tags)
        if risk_level in {"L3", "L4"}:
            keywords.extend(["risk", "policy", "authority"])
        extra_keywords = project_overrides.get("focus_keywords", [])
        if extra_keywords:
            if not isinstance(extra_keywords, list) or not all(isinstance(item, str) and item for item in extra_keywords):
                raise DebateAssemblyError("validation_error", "focus_keywords must be a list of non-empty strings")
            keywords.extend(extra_keywords)
        return sorted(set(keywords))

    def _match_task_type_overlays(self, overlays: dict[str, Any], task_type_tags: list[str]) -> list[str]:
        matched: list[str] = []
        tag_set = set(task_type_tags)
        for overlay_id in sorted(overlays):
            aliases = overlays[overlay_id].get("tag_aliases", [])
            if overlay_id in tag_set or tag_set.intersection(aliases):
                matched.append(overlay_id)
        return matched

    def _score_members(
        self,
        team_map: dict[str, Any],
        selected_team_ids: list[str],
        task_type_tags: list[str],
        focus_keywords: list[str],
    ) -> dict[str, list[dict[str, Any]]]:
        score_map: dict[str, list[dict[str, Any]]] = {}
        lowered_tags = {tag.lower() for tag in task_type_tags}
        lowered_keywords = {keyword.lower() for keyword in focus_keywords}

        for team_id in selected_team_ids:
            entries: list[dict[str, Any]] = []
            for member_index, member in enumerate(team_map[team_id]["members"]):
                dimension_refs = [ref.lower() for ref in member.get("dimension_refs", [])]
                checklist_refs = [ref.lower() for ref in member.get("checklist_refs", [])]
                focus = str(member.get("focus", "")).lower()

                dimension_hits = sum(1 for tag in lowered_tags if any(tag in ref for ref in dimension_refs))
                checklist_hits = sum(1 for tag in lowered_tags if any(tag in ref for ref in checklist_refs))
                keyword_hits = sum(1 for keyword in lowered_keywords if keyword in focus)
                score = (dimension_hits * 4) + (checklist_hits * 3) + (keyword_hits * 2) + 1

                entries.append(
                    {
                        "member_id": member["id"],
                        "score": score,
                        "dimension_hits": dimension_hits,
                        "checklist_hits": checklist_hits,
                        "focus_keyword_hits": keyword_hits,
                        "registry_order": member_index,
                    }
                )

            entries.sort(key=lambda item: (-item["score"], item["registry_order"], item["member_id"]))
            score_map[team_id] = entries
        return score_map

    def _select_members(
        self,
        member_selection_scores: dict[str, list[dict[str, Any]]],
        minimum_member_count: int,
    ) -> list[str]:
        selected: list[str] = []
        used_ids: set[str] = set()
        cursors = {team_id: 0 for team_id in member_selection_scores}

        for team_id in sorted(member_selection_scores):
            member_id = member_selection_scores[team_id][0]["member_id"]
            selected.append(member_id)
            used_ids.add(member_id)
            cursors[team_id] = 1

        while len(selected) < minimum_member_count:
            candidates: list[tuple[int, int, str, str]] = []
            for team_id in sorted(member_selection_scores):
                cursor = cursors[team_id]
                if cursor >= len(member_selection_scores[team_id]):
                    continue
                candidate = member_selection_scores[team_id][cursor]
                if candidate["member_id"] in used_ids:
                    continue
                candidates.append((-candidate["score"], candidate["registry_order"], team_id, candidate["member_id"]))

            if not candidates:
                raise DebateAssemblyError("coverage_unmet", "not enough members available to satisfy minimum_member_count")

            _, _, team_id, member_id = sorted(candidates)[0]
            selected.append(member_id)
            used_ids.add(member_id)
            cursors[team_id] += 1

        return selected

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise DebateAssemblyError("module_disabled", "debate assembly is disabled")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise DebateAssemblyError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise DebateAssemblyError("config_invalid", f"{filename} is missing") from exc
        if not isinstance(data, dict):
            raise DebateAssemblyError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise DebateAssemblyError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise DebateAssemblyError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )
