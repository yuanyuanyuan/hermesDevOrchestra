#!/usr/bin/env python3
"""Unified project config loader for Sprint 3 intake flows."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml


SUMMARY_LINES = [
    ("mode", "interaction.default_mode"),
    ("project", "name"),
    ("tech_stack", "tech_stack"),
    ("goal", "goal"),
    ("risk", "risk_level"),
    ("protected_targets", "protected_targets"),
]

DETAILED_SECTIONS = [
    ("intent_summary", "Requirement summary ready for confirmation"),
    ("dependency_graph", "Environment / upstream / downstream / code dependencies prepared"),
    ("conflict_list", "Detected config and intent conflicts are listed"),
    ("acceptance_matrix", "Acceptance criteria and verification hooks are available"),
    ("prompt_envelope", "Prompt envelope and output schema are traceable"),
    ("risk_flags", "Risk flags and manual confirmation markers are attached"),
]


class ProjectConfigLoader:
    """Load project-profile.yaml first, then fall back to project.json."""

    def load(self, project_dir: str | Path, project_id: str | None = None) -> dict[str, Any]:
        root = Path(project_dir).resolve()
        yaml_path, json_path = self._candidate_paths(root, project_id)
        yaml_data = self._load_yaml(yaml_path)
        json_data = self._load_json(json_path)

        source_path = yaml_path if yaml_data else json_path
        source_name = source_path.name if source_path else "default"
        base = dict(yaml_data or json_data or {})
        interaction = self._resolve_interaction(yaml_data, json_data)
        unified = dict(base)
        unified["interaction"] = interaction
        unified["config_source"] = source_name
        unified["config_path"] = str(source_path) if source_path else ""
        unified["config_version"] = (
            unified.get("profile_version")
            or unified.get("schema_version")
            or (2 if yaml_data else 1)
        )
        if not unified.get("project_id") and project_id:
            unified["project_id"] = project_id

        self._log_resolution(root, yaml_path, json_path, yaml_data, json_data, unified)
        return unified

    def render_preview(self, unified: dict[str, Any]) -> str:
        mode = unified.get("interaction", {}).get("default_mode", "detailed")
        if mode == "summary":
            return self._render_summary(unified)
        return self._render_detailed(unified)

    def _candidate_paths(self, root: Path, project_id: str | None) -> tuple[Path | None, Path | None]:
        yaml_candidates = [
            root / ".hermes" / "project-profile.yaml",
        ]
        json_candidates = [
            root / ".hermes" / "project.json",
        ]
        if project_id:
            yaml_candidates.append(root / ".hermes" / "projects" / project_id / "project-profile.yaml")
            json_candidates.append(root / ".hermes" / "projects" / project_id / "project.json")
        return self._first_existing(yaml_candidates), self._first_existing(json_candidates)

    @staticmethod
    def _first_existing(paths: list[Path]) -> Path | None:
        for path in paths:
            if path.exists():
                return path
        return None

    @staticmethod
    def _load_yaml(path: Path | None) -> dict[str, Any]:
        if path is None:
            return {}
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except Exception:
            return {}
        return data if isinstance(data, dict) else {}

    @staticmethod
    def _load_json(path: Path | None) -> dict[str, Any]:
        if path is None:
            return {}
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            return {}
        return data if isinstance(data, dict) else {}

    def _resolve_interaction(self, yaml_data: dict[str, Any], json_data: dict[str, Any]) -> dict[str, Any]:
        yaml_mode = self._normalize_mode(
            self._dig(yaml_data, "interaction", "default_mode")
            or self._dig(yaml_data, "intake", "default_mode")
        )
        json_mode = self._normalize_mode(
            self._dig(json_data, "interaction", "default_mode")
            or json_data.get("mode")
        )
        threshold = self._coerce_float(
            self._dig(yaml_data, "interaction", "confirmation_threshold"),
            self._dig(json_data, "interaction", "confirmation_threshold"),
            0.5,
        )
        return {
            "default_mode": yaml_mode or json_mode or "detailed",
            "confirmation_threshold": threshold,
        }

    def _log_resolution(
        self,
        root: Path,
        yaml_path: Path | None,
        json_path: Path | None,
        yaml_data: dict[str, Any],
        json_data: dict[str, Any],
        unified: dict[str, Any],
    ) -> None:
        log_path = root / "logs" / "config-resolution.jsonl"
        log_path.parent.mkdir(parents=True, exist_ok=True)

        records = [
            {
                "event": "config_resolution",
                "config_source": unified["config_source"],
                "config_path": unified["config_path"],
                "config_version": unified["config_version"],
                "default_mode": unified["interaction"]["default_mode"],
                "confirmation_threshold": unified["interaction"]["confirmation_threshold"],
                "yaml_present": bool(yaml_data),
                "json_present": bool(json_data),
            }
        ]

        conflicts = self._detect_conflicts(yaml_data, json_data)
        for conflict in conflicts:
            records.append(
                {
                    "event": "config_conflict",
                    "config_source": unified["config_source"],
                    "yaml_path": str(yaml_path) if yaml_path else "",
                    "json_path": str(json_path) if json_path else "",
                    **conflict,
                }
            )

        with log_path.open("a", encoding="utf-8") as handle:
            for record in records:
                json.dump(record, handle, ensure_ascii=False)
                handle.write("\n")

    def _detect_conflicts(self, yaml_data: dict[str, Any], json_data: dict[str, Any]) -> list[dict[str, Any]]:
        if not yaml_data or not json_data:
            return []

        conflicts: list[dict[str, Any]] = []
        yaml_mode = self._normalize_mode(
            self._dig(yaml_data, "interaction", "default_mode")
            or self._dig(yaml_data, "intake", "default_mode")
        )
        json_mode = self._normalize_mode(
            self._dig(json_data, "interaction", "default_mode")
            or json_data.get("mode")
        )
        if yaml_mode and json_mode and yaml_mode != json_mode:
            conflicts.append(
                {
                    "conflict_field": "default_mode",
                    "yaml_value": yaml_mode,
                    "json_value": json_mode,
                    "resolution": "yaml_wins",
                }
            )

        for field in sorted(set(yaml_data.keys()) & set(json_data.keys())):
            if field in {"interaction", "intake", "mode"}:
                continue
            if yaml_data.get(field) != json_data.get(field):
                conflicts.append(
                    {
                        "conflict_field": field,
                        "yaml_value": yaml_data.get(field),
                        "json_value": json_data.get(field),
                        "resolution": "yaml_wins",
                    }
                )
        return conflicts

    def _render_summary(self, unified: dict[str, Any]) -> str:
        lines = [
            "mode: summary",
            f"config_source: {unified.get('config_source', 'default')}",
            f"project: {unified.get('name') or unified.get('project_id') or 'unknown'}",
            f"tech_stack: {self._join_list(unified.get('tech_stack'))}",
            f"goal: {unified.get('goal') or unified.get('description') or 'pending confirmation'}",
            f"risk: {self._join_list(unified.get('risk_flags')) or unified.get('risk_level') or 'unknown'}",
            f"protected_targets: {self._join_list(unified.get('protected_targets')) or 'none'}",
            f"confirmation_threshold: {unified.get('interaction', {}).get('confirmation_threshold', 0.5)}",
        ]
        return "\n".join(lines[:10])

    def _render_detailed(self, unified: dict[str, Any]) -> str:
        lines = [
            "mode: detailed",
            f"config_source: {unified.get('config_source', 'default')}",
            f"project: {unified.get('name') or unified.get('project_id') or 'unknown'}",
        ]
        for label, detail in DETAILED_SECTIONS:
            lines.append(f"{label}: {detail}")
        return "\n".join(lines)

    @staticmethod
    def _dig(data: dict[str, Any], *keys: str) -> Any:
        current: Any = data
        for key in keys:
            if not isinstance(current, dict):
                return None
            current = current.get(key)
        return current

    @staticmethod
    def _join_list(value: Any) -> str:
        if isinstance(value, list) and value:
            return ", ".join(str(item) for item in value)
        return ""

    @staticmethod
    def _normalize_mode(value: Any) -> str | None:
        if not isinstance(value, str) or not value.strip():
            return None
        lowered = value.strip().lower()
        aliases = {
            "summary": "summary",
            "compact": "summary",
            "detailed": "detailed",
            "verbose": "detailed",
        }
        return aliases.get(lowered)

    @staticmethod
    def _coerce_float(*values: Any) -> float:
        for value in values:
            try:
                if value is None or value == "":
                    continue
                return float(value)
            except (TypeError, ValueError):
                continue
        return 0.5


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-dir", default=".")
    parser.add_argument("--project-id")
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args(argv)

    loader = ProjectConfigLoader()
    unified = loader.load(args.project_dir, args.project_id)
    if args.preview:
        print(loader.render_preview(unified))
    else:
        print(json.dumps(unified, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
