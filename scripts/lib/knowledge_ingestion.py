from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


class KnowledgeIngestionError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class KnowledgeIngestion:
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

    def ingest(self, entry: dict[str, Any]) -> dict[str, Any]:
        config = self._load_config()
        normalized_entry = self._normalize_entry(entry)
        page_markdown = self._render_page_markdown(normalized_entry)
        record = self._build_ingestion_record(normalized_entry)

        if self._gbrain_available(config):
            self._run_gbrain_command([config["backend"]["cli_command"], "init"])
            put_result = self._put_entry(config, normalized_entry["slug"], page_markdown)
            report_ref = self._write_report(config, normalized_entry, record)
            return {
                "entry": normalized_entry,
                "page_markdown": page_markdown,
                "storage_ref": f"knowledge://gbrain/{normalized_entry['slug']}",
                "gbrain_put_result": put_result,
                "ingestion_record": record,
                "gbrain_report_ref": report_ref,
                "degraded": False,
            }

        degraded_refs = self._write_degraded_entry(normalized_entry, record)
        return {
            "entry": normalized_entry,
            "page_markdown": page_markdown,
            "storage_ref": degraded_refs["entry_ref"],
            "gbrain_put_result": {"status": "degraded_state_store"},
            "ingestion_record": record,
            "gbrain_report_ref": degraded_refs["record_ref"],
            "degraded": True,
        }

    def _load_config(self) -> dict[str, Any]:
        self._require_enabled()
        if self._config is not None:
            return self._config

        data = self._load_json("runtime-kb.json")
        self._validate_definition("runtime_domain_knowledge_config", data)

        if data.get("enabled") is not True and not self.allow_staged:
            raise KnowledgeIngestionError(
                "module_disabled",
                "runtime-kb.json is disabled; allow_staged=True is required",
            )
        backend = data.get("backend", {})
        if backend.get("enabled") is not True and not self.allow_staged:
            raise KnowledgeIngestionError(
                "module_disabled",
                "runtime-kb.json backend is disabled; allow_staged=True is required",
            )

        self._config = data
        return self._config

    def _normalize_entry(self, entry: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(entry, dict):
            raise KnowledgeIngestionError("validation_error", "entry must be an object")

        normalized = dict(entry)
        slug = normalized.get("slug")
        if not isinstance(slug, str) or not re.fullmatch(r"domain/[^/]+/[^/]+/[^/]+", slug):
            raise KnowledgeIngestionError(
                "validation_error",
                "entry slug must match domain/<domain>/<topic>/<short-id>",
            )
        if normalized.get("type") == "domain_knowledge":
            verification_method = normalized.get("verification_method")
            if not isinstance(verification_method, str) or not verification_method:
                raise KnowledgeIngestionError(
                    "verification_required",
                    "domain_knowledge ingestion requires verification_method before promotion",
                )

        self._validate_definition("runtime_knowledge_entry", normalized)
        return normalized

    def _render_page_markdown(self, entry: dict[str, Any]) -> str:
        frontmatter_fields = [
            "type",
            "domain",
            "topic",
            "source_type",
            "source_refs",
            "confidence",
            "freshness",
            "valid_from",
            "last_verified_at",
            "tags",
            "owner",
        ]
        if isinstance(entry.get("verification_method"), str) and entry["verification_method"]:
            frontmatter_fields.append("verification_method")

        lines = ["---"]
        for field in frontmatter_fields:
            value = entry.get(field)
            if isinstance(value, list):
                lines.append(f"{field}:")
                for item in value:
                    lines.append(f"  - {item}")
            elif value is None:
                lines.append(f"{field}: null")
            else:
                lines.append(f"{field}: {value}")
        lines.append("---")
        lines.append("")

        for section in [
            "Claim",
            "Context",
            "Applies When",
            "Does Not Apply When",
            "Evidence",
            "Operational Guidance",
            "Failure Modes",
            "Review Checklist",
        ]:
            lines.append(f"# {section}")
            lines.append(str(entry["body_sections"][section]))
            lines.append("")

        return "\n".join(lines).rstrip() + "\n"

    def _build_ingestion_record(self, entry: dict[str, Any]) -> dict[str, Any]:
        operation = "promotion" if entry["type"] == "domain_knowledge" else "import"
        record = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "knowledge_ingestion_record",
            "record_id": f"knowledge-ingestion-{uuid.uuid4().hex}",
            "backend": "gbrain",
            "operation": operation,
            "affected_slugs": [entry["slug"]],
            "source_refs": list(entry["source_refs"]),
            "verification_method": entry.get("verification_method") or "pending_verification",
            "operator": str(entry["owner"]),
            "created_at": self._timestamp(),
            "resulting_status": entry["type"],
        }
        self._validate_definition("knowledge_ingestion_record", record)
        return record

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

    def _put_entry(self, config: dict[str, Any], slug: str, page_markdown: str) -> dict[str, Any]:
        completed = self._run_gbrain_command(
            [config["backend"]["cli_command"], "put", slug, "--content", page_markdown]
        )
        try:
            payload = json.loads(completed.stdout)
        except json.JSONDecodeError as exc:
            raise KnowledgeIngestionError("backend_invalid", "gbrain put did not return JSON") from exc
        if not isinstance(payload, dict):
            raise KnowledgeIngestionError("backend_invalid", "gbrain put response must be a JSON object")
        return payload

    def _write_report(self, config: dict[str, Any], entry: dict[str, Any], record: dict[str, Any]) -> str:
        report_body = json.dumps(
            {
                "record_id": record["record_id"],
                "operation": record["operation"],
                "affected_slugs": record["affected_slugs"],
                "resulting_status": record["resulting_status"],
            },
            ensure_ascii=False,
        )
        completed = self._run_gbrain_command(
            [
                config["backend"]["cli_command"],
                "report",
                "--type",
                "knowledge-ingestion",
                "--title",
                entry["slug"],
                "--content",
                report_body,
            ]
        )
        report_path = completed.stdout.strip().splitlines()[-1]
        if not report_path:
            raise KnowledgeIngestionError("backend_invalid", "gbrain report did not return a report path")
        return f"gbrain://{report_path.lstrip('./')}"

    def _write_degraded_entry(self, entry: dict[str, Any], record: dict[str, Any]) -> dict[str, str]:
        entry_dir = self.state_root / "knowledge" / "entries" / entry["domain"] / entry["topic"]
        record_dir = self.state_root / "knowledge" / "ingestion"
        entry_dir.mkdir(parents=True, exist_ok=True)
        record_dir.mkdir(parents=True, exist_ok=True)

        entry_path = entry_dir / f"{entry['slug'].rsplit('/', 1)[-1]}.json"
        record_path = record_dir / f"{record['record_id']}.json"
        entry_path.write_text(json.dumps(entry, ensure_ascii=False, indent=2), encoding="utf-8")
        record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")

        slug_tail = "/".join(entry["slug"].split("/")[1:])
        return {
            "entry_ref": f"state://knowledge/entries/{slug_tail}.json",
            "record_ref": f"state://knowledge/ingestion/{record['record_id']}.json",
        }

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
            raise KnowledgeIngestionError("backend_unavailable", stderr or "gbrain command failed")
        return completed

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise KnowledgeIngestionError("module_disabled", "knowledge ingestion is disabled")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise KnowledgeIngestionError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise KnowledgeIngestionError("config_invalid", f"{filename} is missing") from exc
        except PermissionError as exc:
            raise KnowledgeIngestionError("config_invalid", f"{filename} is not readable: {exc.strerror or exc}") from exc
        if not isinstance(data, dict):
            raise KnowledgeIngestionError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise KnowledgeIngestionError("schema_invalid", exc.message) from exc

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()
