from __future__ import annotations

import json
import os
import re
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
        runtime_env: dict[str, str] | None = None,
        runtime_cwd: Path | str | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        env = runtime_env or os.environ
        cwd = runtime_cwd
        self.runtime_env = dict(env)
        self.runtime_cwd = Path(cwd) if cwd is not None else Path(self.runtime_env.get("HOME", str(Path.home())))
        default_state_root = Path(self.runtime_env.get("XDG_STATE_HOME", str(Path(self.runtime_cwd) / ".local" / "state")))
        self.state_root = Path(state_root) if state_root is not None else default_state_root / "hermes-orchestra"
        self._config: dict[str, Any] | None = None

    def query(self, request: dict[str, Any]) -> dict[str, Any]:
        config = self._load_config()
        normalized_request = self._normalize_request(request, config)
        query_artifact = self._build_query_artifact(normalized_request)

        degraded_storage_refs: list[str] = []
        raw_entries, degraded_storage_refs = self._query_state_store(normalized_request)

        filtered_entries = self._filter_entries(raw_entries, normalized_request)
        result_artifact = self._build_result_artifact(
            query_artifact=query_artifact,
            entries=filtered_entries,
            degraded_backend=False,
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

    def _query_state_store(self, request: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str]]:
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
            result_refs.append(self._state_entry_ref(slug))

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
            "recovery_options": ["refresh_or_verify_entries"] if warnings else [],
            "accepted_by_ref": None,
            "completion_evidence_allowed": False if warnings else True,
            "replacement_evidence_ref": None,
            "policy_ref": "config://knowledge/runtime-kb",
        }

        return {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "runtime_knowledge_result",
            "query_id": query_artifact["query_id"],
            "backend": "state_store",
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

    def _entry_title(self, entry: dict[str, Any]) -> str:
        title = entry.get("title")
        if isinstance(title, str) and title:
            return title
        return str(entry["slug"]).rsplit("/", 1)[-1].replace("-", " ").title()

    def _max_confidence(self, current: str, candidate: str) -> str:
        order = {"low": 0, "medium": 1, "high": 2}
        return candidate if order.get(candidate, 0) > order.get(current, 0) else current

    def _state_entry_ref(self, slug: str) -> str:
        slug_tail = "/".join(slug.split("/")[1:])
        return f"state://knowledge/entries/{slug_tail}.json"

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

    def _parse_timestamp(self, value: str) -> datetime:
        normalized = value.replace("Z", "+00:00")
        return datetime.fromisoformat(normalized)

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()
