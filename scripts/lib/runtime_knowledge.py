from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


class RuntimeKnowledgeError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class RuntimeKnowledgeBase:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/knowledge",
        allow_staged: bool = False,
        enabled: bool = True,
        state_root: Path | str | None = None,
        gbrain_env: dict[str, str] | None = None,
        gbrain_cwd: Path | str | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self.gbrain_env = dict(gbrain_env or os.environ)
        self.gbrain_cwd = Path(gbrain_cwd) if gbrain_cwd is not None else Path(self.gbrain_env.get("HOME", str(Path.home())))
        default_state_root = Path(self.gbrain_env.get("XDG_STATE_HOME", str(Path(self.gbrain_cwd) / ".local" / "state")))
        self.state_root = Path(state_root) if state_root is not None else default_state_root / "hermes-orchestra"
        self._config: dict[str, Any] | None = None

    def query(self, request: dict[str, Any]) -> dict[str, Any]:
        config = self._load_config()
        normalized_request = self._normalize_request(request, config)
        query_artifact = self._build_query_artifact(normalized_request)

        degraded_storage_refs: list[str] = []
        backend_degraded = False
        if self._gbrain_available(config):
            raw_entries = self._query_gbrain(config, normalized_request)
        else:
            backend_degraded = True
            raw_entries, degraded_storage_refs = self._query_degraded_state(normalized_request)

        filtered_entries = self._filter_entries(raw_entries, normalized_request)
        result_artifact = self._build_result_artifact(
            query_artifact=query_artifact,
            entries=filtered_entries,
            degraded_backend=backend_degraded,
            degraded_storage_refs=degraded_storage_refs,
        )

        self._validate_definition("runtime_knowledge_query", query_artifact)
        self._validate_definition("runtime_knowledge_result", result_artifact)

        return {
            "query_artifact": query_artifact,
            "result_artifact": result_artifact,
            "degraded_storage_refs": degraded_storage_refs,
        }

    def _load_config(self) -> dict[str, Any]:
        self._require_enabled()
        if self._config is not None:
            return self._config

        data = self._load_json("runtime-kb.json")
        self._validate_definition("runtime_domain_knowledge_config", data)
        if data.get("enabled") is not True and not self.allow_staged:
            raise RuntimeKnowledgeError(
                "module_disabled",
                "runtime-kb.json is disabled; allow_staged=True is required",
            )
        backend = data.get("backend", {})
        if backend.get("enabled") is not True and not self.allow_staged:
            raise RuntimeKnowledgeError(
                "module_disabled",
                "runtime-kb.json backend is disabled; allow_staged=True is required",
            )

        self._config = data
        return self._config

    def _normalize_request(self, request: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(request, dict):
            raise RuntimeKnowledgeError("validation_error", "request must be an object")

        normalized = {
            "run_id": request.get("run_id"),
            "task_id": request.get("task_id"),
            "domain": request.get("domain"),
            "question": request.get("question"),
            "allowed_types": request.get("allowed_types") or list(config["retrieval_policy"]["default_allowed_types"]),
            "required_freshness": request.get("required_freshness") or "current",
            "max_results": request.get("max_results") or 5,
            "evidence_scope": request.get("evidence_scope") or "implementation",
        }

        for key in ["run_id", "task_id", "domain", "question", "required_freshness", "evidence_scope"]:
            value = normalized[key]
            if not isinstance(value, str) or not value:
                raise RuntimeKnowledgeError("validation_error", f"{key} must be a non-empty string")
        if not isinstance(normalized["allowed_types"], list) or not all(
            isinstance(item, str) and item for item in normalized["allowed_types"]
        ):
            raise RuntimeKnowledgeError("validation_error", "allowed_types must be a list of non-empty strings")
        if not isinstance(normalized["max_results"], int) or normalized["max_results"] < 1:
            raise RuntimeKnowledgeError("validation_error", "max_results must be an integer >= 1")

        return normalized

    def _build_query_artifact(self, request: dict[str, Any]) -> dict[str, Any]:
        return {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "runtime_knowledge_query",
            "query_id": f"runtime-knowledge-query-{uuid.uuid4().hex}",
            "run_id": request["run_id"],
            "task_id": request["task_id"],
            "domain": request["domain"],
            "question": request["question"],
            "allowed_types": list(request["allowed_types"]),
            "required_freshness": request["required_freshness"],
            "max_results": request["max_results"],
            "evidence_scope": request["evidence_scope"],
        }

    def _query_gbrain(self, config: dict[str, Any], request: dict[str, Any]) -> list[dict[str, Any]]:
        completed = self._run_gbrain_command(
            [
                config["backend"]["cli_command"],
                "query",
                request["question"],
                "--limit",
                str(request["max_results"]),
                "--detail",
                "low",
            ]
        )
        slugs = self._parse_query_slugs(completed.stdout)[: request["max_results"]]
        entries: list[dict[str, Any]] = []
        for slug in slugs:
            shadow_entry = self._load_state_entry(slug)
            if shadow_entry is not None:
                entries.append(shadow_entry)
                continue
            page = self._run_gbrain_command([config["backend"]["cli_command"], "get", slug]).stdout
            entries.append(self._parse_page_markdown(slug, page))
        return entries

    def _query_degraded_state(self, request: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str]]:
        base_dir = self.state_root / "knowledge" / "entries" / request["domain"]
        if not base_dir.exists():
            return [], []

        entries: list[dict[str, Any]] = []
        refs: list[str] = []
        question_tokens = {token.lower() for token in re.findall(r"[A-Za-z0-9_]+", request["question"])}
        for path in sorted(base_dir.rglob("*.json")):
            payload = json.loads(path.read_text(encoding="utf-8"))
            corpus = " ".join(
                [
                    payload.get("slug", ""),
                    payload.get("topic", ""),
                    *[str(value) for value in payload.get("body_sections", {}).values()],
                ]
            ).lower()
            if question_tokens and not any(token in corpus for token in question_tokens):
                continue
            entries.append(payload)
            relative = path.relative_to(self.state_root / "knowledge").as_posix()
            refs.append(f"state://knowledge/{relative}")
        return entries[: request["max_results"]], refs[: request["max_results"]]

    def _filter_entries(self, entries: list[dict[str, Any]], request: dict[str, Any]) -> list[dict[str, Any]]:
        filtered: list[dict[str, Any]] = []
        for entry in entries:
            if entry.get("domain") != request["domain"]:
                continue
            entry_type = entry.get("type")
            if entry_type not in request["allowed_types"]:
                continue
            if entry_type == "candidate_knowledge" and request["evidence_scope"] not in {"research", "debate"}:
                continue
            filtered.append(entry)
        return filtered[: request["max_results"]]

    def _load_state_entry(self, slug: str) -> dict[str, Any] | None:
        parts = slug.split("/")
        if len(parts) != 4:
            return None
        path = self.state_root / "knowledge" / "entries" / parts[1] / parts[2] / f"{parts[3]}.json"
        if not path.exists():
            return None
        payload = json.loads(path.read_text(encoding="utf-8"))
        return payload if isinstance(payload, dict) else None

    def _build_result_artifact(
        self,
        query_artifact: dict[str, Any],
        entries: list[dict[str, Any]],
        degraded_backend: bool,
        degraded_storage_refs: list[str],
    ) -> dict[str, Any]:
        warnings: list[str] = []
        freshness_status = "current"
        degradation_status = "normal"
        degradation_class = "none"
        result_refs: list[str] = []
        slugs: list[str] = []
        titles: list[str] = []
        snippets: list[str] = []
        source_refs: list[str] = []
        confidence = "low"

        for entry in entries:
            slug = str(entry["slug"])
            slugs.append(slug)
            titles.append(self._entry_title(entry))
            snippets.append(str(entry["body_sections"]["Claim"]))
            source_refs.extend([ref for ref in entry.get("source_refs", []) if isinstance(ref, str)])
            confidence = self._max_confidence(confidence, str(entry.get("confidence", "low")))
            if degraded_backend:
                result_refs.append(f"gbrain://degraded/{slug}")
            else:
                result_refs.append(f"knowledge://gbrain/{slug}")

            entry_warnings = self._entry_warnings(entry)
            for warning in entry_warnings:
                if warning not in warnings:
                    warnings.append(warning)

        if degraded_backend:
            warnings.append("backend_unavailable_state_store")

        if warnings:
            freshness_status = "warning_context"
            degradation_status = "degraded"
            degradation_class = "runtime_knowledge_warning_context"

        degradation_record = {
            "degradation_status": degradation_status,
            "degradation_class": degradation_class,
            "cause": "warning_context_returned" if warnings else "none",
            "affected_evidence_refs": list(result_refs),
            "decision_required": "none",
            "recovery_options": ["restore_gbrain_backend", "refresh_or_verify_entries"] if warnings else [],
            "accepted_by_ref": None,
            "completion_evidence_allowed": False if warnings else True,
            "replacement_evidence_ref": None,
            "policy_ref": "config://knowledge/runtime-kb",
        }

        return {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "runtime_knowledge_result",
            "query_id": query_artifact["query_id"],
            "backend": "gbrain",
            "result_refs": result_refs,
            "slugs": slugs,
            "titles": titles,
            "snippets": snippets,
            "confidence": confidence,
            "freshness_status": freshness_status,
            "degradation_status": degradation_status,
            "degradation_record": degradation_record,
            "source_refs": sorted(set(source_refs)),
            "warnings": warnings,
            "created_at": self._timestamp(),
            "degraded_storage_refs": list(degraded_storage_refs),
        }

    def _entry_warnings(self, entry: dict[str, Any]) -> list[str]:
        warnings: list[str] = []
        if entry.get("type") == "candidate_knowledge":
            warnings.append("candidate_knowledge_requires_verification")
        if self._is_entry_expired(entry):
            warnings.append("expired_entry_warning_context")
        return warnings

    def _is_entry_expired(self, entry: dict[str, Any]) -> bool:
        last_verified_at = entry.get("last_verified_at")
        if not isinstance(last_verified_at, str) or not last_verified_at:
            return entry.get("type") == "candidate_knowledge"

        verified_at = self._parse_timestamp(last_verified_at)
        source_type = entry.get("source_type")
        max_age_days = {
            "official_documentation": 30,
            "platform_rule": 30,
            "code_or_sdk_example": 30,
            "project_observation": 90,
            "human_expert_entry": 180,
            "reviewed_external_note_summary": 180,
        }.get(source_type, 30)
        return verified_at + timedelta(days=max_age_days) < datetime.now(timezone.utc)

    def _parse_query_slugs(self, output: str) -> list[str]:
        slugs: list[str] = []
        for line in output.splitlines():
            match = re.match(r"^\[[^\]]+\]\s+(\S+)\s+--", line.strip())
            if match:
                slug = match.group(1)
                if slug not in slugs:
                    slugs.append(slug)
        return slugs

    def _parse_page_markdown(self, slug: str, page_markdown: str) -> dict[str, Any]:
        lines = page_markdown.splitlines()
        if not lines or lines[0].strip() != "---":
            raise RuntimeKnowledgeError("backend_invalid", "gbrain get output is missing frontmatter")

        frontmatter_lines: list[str] = []
        body_start = None
        for index in range(1, len(lines)):
            if lines[index].strip() == "---":
                body_start = index + 1
                break
            frontmatter_lines.append(lines[index])
        if body_start is None:
            raise RuntimeKnowledgeError("backend_invalid", "gbrain get output frontmatter is unterminated")

        frontmatter = self._parse_frontmatter(frontmatter_lines)
        body_sections = self._parse_sections(lines[body_start:])
        return {
            "slug": slug,
            "type": frontmatter["type"],
            "domain": frontmatter["domain"],
            "topic": frontmatter["topic"],
            "source_type": frontmatter["source_type"],
            "source_refs": frontmatter["source_refs"],
            "confidence": frontmatter["confidence"],
            "freshness": frontmatter["freshness"],
            "valid_from": frontmatter["valid_from"],
            "last_verified_at": frontmatter["last_verified_at"],
            "tags": frontmatter["tags"],
            "owner": frontmatter["owner"],
            "verification_method": frontmatter.get("verification_method"),
            "title": frontmatter.get("title"),
            "body_sections": body_sections,
        }

    def _parse_frontmatter(self, lines: list[str]) -> dict[str, Any]:
        parsed: dict[str, Any] = {}
        current_list_key: str | None = None
        for raw_line in lines:
            line = raw_line.rstrip()
            if not line:
                continue
            if current_list_key is not None and line.startswith("  - "):
                parsed[current_list_key].append(self._strip_quotes(line[4:]))
                continue
            current_list_key = None
            if line.endswith(":"):
                current_list_key = line[:-1]
                parsed[current_list_key] = []
                continue
            key, _, value = line.partition(":")
            if not _:
                continue
            cleaned = value.strip()
            if cleaned == "null":
                parsed[key] = None
            else:
                parsed[key] = self._strip_quotes(cleaned)
        return parsed

    def _parse_sections(self, lines: list[str]) -> dict[str, str]:
        sections: dict[str, list[str]] = {}
        current_section: str | None = None
        for raw_line in lines:
            line = raw_line.rstrip()
            if line.startswith("# "):
                current_section = line[2:]
                sections[current_section] = []
                continue
            if current_section is not None:
                sections[current_section].append(line)
        return {key: "\n".join(value).strip() for key, value in sections.items()}

    def _entry_title(self, entry: dict[str, Any]) -> str:
        title = entry.get("title")
        if isinstance(title, str) and title:
            return title
        return str(entry["slug"]).rsplit("/", 1)[-1].replace("-", " ").title()

    def _max_confidence(self, current: str, candidate: str) -> str:
        order = {"low": 0, "medium": 1, "high": 2}
        return candidate if order.get(candidate, 0) > order.get(current, 0) else current

    def _gbrain_available(self, config: dict[str, Any]) -> bool:
        executable = config["backend"]["cli_command"]
        if shutil.which(executable, path=self.gbrain_env.get("PATH")) is None:
            return False
        completed = subprocess.run(
            [executable, "--version"],
            cwd=str(self.gbrain_cwd),
            env=self.gbrain_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        return completed.returncode == 0

    def _run_gbrain_command(self, argv: list[str]) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            argv,
            cwd=str(self.gbrain_cwd),
            env=self.gbrain_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            stderr = completed.stderr.strip() or completed.stdout.strip()
            raise RuntimeKnowledgeError("backend_unavailable", stderr or "gbrain command failed")
        return completed

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise RuntimeKnowledgeError("module_disabled", "runtime knowledge base is disabled")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise RuntimeKnowledgeError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise RuntimeKnowledgeError("config_invalid", f"{filename} is missing") from exc
        except PermissionError as exc:
            raise RuntimeKnowledgeError("config_invalid", f"{filename} is not readable: {exc.strerror or exc}") from exc
        if not isinstance(data, dict):
            raise RuntimeKnowledgeError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise RuntimeKnowledgeError("schema_invalid", exc.message) from exc

    def _strip_quotes(self, value: str) -> str:
        if len(value) >= 2 and ((value[0] == "'" and value[-1] == "'") or (value[0] == '"' and value[-1] == '"')):
            return value[1:-1]
        return value

    def _parse_timestamp(self, value: str) -> datetime:
        normalized = value.replace("Z", "+00:00")
        return datetime.fromisoformat(normalized)

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()
