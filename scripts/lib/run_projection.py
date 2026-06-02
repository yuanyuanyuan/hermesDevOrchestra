"""Run Projection aggregation for Gateway state files."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from actor_auth import authenticate_actor, authority_matrix_view, require_actor_capability


PROJECTION_SCHEMA_VERSION = "1.0.0"
REFRESH_REASONS = {"stage_advance", "heartbeat_sync", "audit_rebuild", "manual_refresh"}


def _read_json(path: Path, default: dict[str, Any] | None = None) -> dict[str, Any]:
    if not path.exists():
        return default or {}
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    return data if isinstance(data, dict) else (default or {})


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                row = json.loads(line)
                if isinstance(row, dict):
                    rows.append(row)
    return rows


def _file_checksum(path: Path) -> str | None:
    if not path.exists():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _artifact_entries(run_dir: Path, run_id: str) -> list[dict[str, Any]]:
    entries = []
    for path in sorted(run_dir.rglob("*.json")):
        rel = path.relative_to(run_dir).as_posix()
        if rel in {"run.json", "tasks.json"} or rel.startswith("commands/"):
            continue
        entries.append(
            {
                "artifact_id": rel.replace("/", "-").removesuffix(".json"),
                "type": rel.rsplit("/", 1)[-1].removesuffix(".json"),
                "path": f"state://runs/{run_id}/{rel}",
                "checksum": _file_checksum(path),
                "produced_by_task": None,
                "verified_by_gate": None,
            }
        )
    return entries


def _decision_entries(run_dir: Path, audit_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    decisions = []
    for row in audit_rows:
        if row.get("decision") in {"PENDING", "APPROVED", "REJECTED", "BLOCKED"} or row.get("type") == "decision_required":
            decisions.append(
                {
                    "decision_id": row.get("approval_id") or row.get("command_id") or f"decision-{len(decisions) + 1}",
                    "type": row.get("type"),
                    "actor": row.get("agent_source"),
                    "timestamp": row.get("timestamp"),
                    "rationale": row.get("details"),
                    "approval_level": row.get("level"),
                }
            )
    for path in sorted((run_dir / "commands").glob("*.json")):
        command = _read_json(path)
        decisions.append(
            {
                "decision_id": command.get("command_id"),
                "type": command.get("intent"),
                "actor": "gateway",
                "timestamp": command.get("updated_at") or command.get("created_at"),
                "rationale": command.get("status"),
                "approval_level": None,
            }
        )
    return decisions


def _intake_projection(run: dict[str, Any], tasks: list[dict[str, Any]]) -> dict[str, Any]:
    existing = run.get("intake_projection")
    if isinstance(existing, dict):
        return existing
    return {
        "original_intent_source": run.get("artifact_refs", {}).get("structured_prd") if isinstance(run.get("artifact_refs"), dict) else None,
        "confidence_score": 1.0 if run.get("status") != "blocked" else 0.5,
        "conflict_summary": [],
        "dependency_projection": {
            "environment": [],
            "upstream": [],
            "downstream": [task.get("task_id") for task in tasks if isinstance(task, dict)],
            "code": [],
        },
    }


def build_projection(
    *,
    run_id: str,
    state_dir: Path,
    audit_dir: Path,
    project_id: str,
    authority_matrix_view: dict[str, str],
    actor: dict[str, Any],
) -> dict[str, Any] | None:
    run_dir = state_dir / "runs" / run_id
    run_path = run_dir / "run.json"
    if not run_path.exists():
        return None
    run = _read_json(run_path)
    tasks_doc = _read_json(run_dir / "tasks.json", {"tasks": []})
    tasks = tasks_doc.get("tasks") if isinstance(tasks_doc.get("tasks"), list) else []
    events = _read_jsonl(run_dir / "events.jsonl")
    audit_rows = [row for row in _read_jsonl(audit_dir / "audit.jsonl") if row.get("run_id") == run_id]
    projected_run = dict(run)
    projected_run["actor_tokens"] = [actor.get("token_id")]
    projected_run["current_blockers"] = [run.get("blocked_reason")] if run.get("blocked_reason") else []
    projected_run["intake_projection"] = _intake_projection(run, tasks)
    return {
        "projection_schema_version": PROJECTION_SCHEMA_VERSION,
        "schema_version": "run_projection.v1",
        "project": project_id,
        "run_id": run_id,
        "run": projected_run,
        "tasks": tasks,
        "artifacts": _artifact_entries(run_dir, run_id),
        "decisions": _decision_entries(run_dir, audit_rows),
        "audits": audit_rows,
        "events": events,
        "authority_matrix_view": authority_matrix_view,
        "projection_checksums": {
            "run": _file_checksum(run_path),
            "tasks": _file_checksum(run_dir / "tasks.json"),
            "events": _file_checksum(run_dir / "events.jsonl"),
            "audit": _file_checksum(audit_dir / "audit.jsonl"),
        },
    }


def projection_response(app: Any, run_id: str, token: str | None) -> tuple[int, dict[str, Any]]:
    actor = authenticate_actor(app, token)
    if isinstance(actor, tuple):
        return actor
    denied = require_actor_capability(app, actor, "hydrate_requirements")
    if denied is not None:
        return denied
    projection = build_projection(
        run_id=run_id,
        state_dir=app.store.state_dir,
        audit_dir=app.store.audit_dir,
        project_id=app.store.project_id,
        authority_matrix_view=authority_matrix_view(app.authority_matrix, actor.actor_type),
        actor={"actor_type": actor.actor_type, "actor_id": actor.actor_id, "token_id": actor.token_id},
    )
    if projection is None:
        body = app.error("run_not_found", "run not found")
        body["run_id"] = run_id
        return 404, body
    return 200, projection


def refresh_projection_response(app: Any, run_id: str, payload: dict[str, Any], token: str | None) -> tuple[int, dict[str, Any]]:
    if payload.get("reason") not in REFRESH_REASONS:
        return 409, app.error("invalid_refresh_reason", "refresh reason is not supported")
    return projection_response(app, run_id, token)
