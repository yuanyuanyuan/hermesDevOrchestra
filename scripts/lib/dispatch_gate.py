from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from evidence_gate import EvidenceGateError, validate_completion_evidence
from worker_session import WorkerSessionError, WorkerSessionManager
from write_scope_validator import WriteScopeError, compute_expected_write_scope, validate_completion_scope


def dispatch_task(app: Any, run_id: str, task_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
    run_path = app.store.run_path(run_id)
    tasks_path = app.store.tasks_path(run_id)
    if not run_path.exists() or not tasks_path.exists():
        return 404, app.error("not_found", "run or task projection not found")
    tasks = _read_json(tasks_path)
    task = app.find_projected_task(tasks, task_id)
    if task is None:
        return 404, app.error("not_found", "task not found")
    actor = payload.get("actor")
    assigned_actor = str(task.get("assigned_actor") or _default_actor(task))
    if not _actor_matches_assignment(actor, assigned_actor):
        return 403, app.error("dispatch_actor_forbidden", "actor is not the assigned task actor")
    if task.get("status") not in {"queued", "ready_for_dispatch"}:
        return 409, app.error("task_not_ready_for_dispatch", "task is not ready for dispatch")
    try:
        computed_scope = compute_expected_write_scope(tasks.get("tasks", []), task_id)
    except WriteScopeError as exc:
        return 409, app.error(exc.code, exc.message)

    manager = WorkerSessionManager(app.repo_root)
    context_bundle_id = str(task.get("context_bundle_id") or f"bundle-{task_id}")
    workspace_root = Path(os.environ.get("WORKER_SESSIONS_ROOT", str(app.store.state_dir / "worker-sessions")))
    record = manager.create_dispatch_session(
        run_id=run_id,
        task_id=task_id,
        assigned_actor=assigned_actor,
        workspace_root=workspace_root,
        computed_write_scope=computed_scope,
        context_bundle_id=context_bundle_id,
        token_ttl_seconds=int(payload.get("token_ttl_seconds") or 3600),
    )
    record_ref = app.store.state_ref(run_id, f"worker-sessions/{record['session_id']}.json")
    manager.persist_record(record, app.store.run_dir(run_id) / "worker-sessions")
    task.update(
        {
            "status": "dispatched",
            "assigned_actor": assigned_actor,
            "workspace_path": record["workspace_path"],
            "context_bundle_id": context_bundle_id,
            "computed_write_scope": computed_scope,
            "worker_session_ref": record_ref,
        }
    )
    tasks["updated_at"] = app.utc_now() if hasattr(app, "utc_now") else record["created_at"]
    _write_json(tasks_path, tasks)
    _append_jsonl(
        app.store.audit_path(),
        {
            "timestamp": record["created_at"],
            "level": "L1",
            "project": app.store.project_id,
            "type": "worker_dispatched",
            "decision": "RECORDED",
            "task_id": task_id,
            "run_id": run_id,
            "session_id": record["session_id"],
            "computed_write_scope": computed_scope,
        },
    )
    return 200, {
        "schema_version": app.schema_version,
        "run_id": run_id,
        "task_id": task_id,
        "session_id": record["session_id"],
        "workspace_path": record["workspace_path"],
        "context_bundle_id": context_bundle_id,
        "dispatch_token": record["dispatch_token"],
        "computed_write_scope": computed_scope,
        "worker_session_record_ref": record_ref,
    }


def submit_completion_payload(app: Any, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
    task_id = payload.get("task_id")
    completion = payload.get("completion_payload")
    if not isinstance(task_id, str) or not isinstance(completion, dict):
        return 400, app.error("validation_error", "task_id and completion_payload are required")
    if not isinstance(payload.get("dispatch_token"), str):
        return 400, app.error("dispatch_token_required", "stage advancement requires a Gateway dispatch token")
    tasks = _read_json(app.store.tasks_path(run_id))
    task = app.find_projected_task(tasks, task_id)
    if task is None:
        return 404, app.error("not_found", "task not found")
    manager = WorkerSessionManager(app.repo_root)
    session_ref = task.get("worker_session_ref")
    if not isinstance(session_ref, str):
        return 400, app.error("dispatch_token_required", "task has no Gateway worker session")
    record_path = app.store.run_dir(run_id) / "worker-sessions" / Path(session_ref).name
    record = manager.load_record(record_path)
    try:
        manager.validate_dispatch_token(record, payload["dispatch_token"])
        write_scope_result = validate_completion_scope(
            record["workspace_path"],
            record.get("computed_write_scope", []),
            completion.get("reported_write_scope", []),
            completion.get("file_manifest", []),
        )
        evidence_result = validate_completion_evidence(completion, artifact_refs=set(completion.get("evidence_refs", [])))
    except (WorkerSessionError, WriteScopeError, EvidenceGateError) as exc:
        _append_jsonl(app.store.audit_path(), _audit(run_id, task_id, "write_scope_check", getattr(exc, "code", "failed"), getattr(exc, "violations", [])))
        return 200, {"schema_version": app.schema_version, "run_id": run_id, "task_id": task_id, "gate_result": "blocked", "failure_class": exc.code}

    now = record.get("created_at")
    task.update({"status": "completed", "write_scope_check": write_scope_result, "evidence_gate_result": evidence_result})
    _write_json(app.store.tasks_path(run_id), tasks)
    _append_jsonl(app.store.audit_path(), _audit(run_id, task_id, "write_scope_check", "passed", []))
    _append_jsonl(app.store.audit_path(), _audit(run_id, task_id, "evidence_gate_result", "passed", []))
    return {"completed": (200, {"schema_version": app.schema_version, "run_id": run_id, "task_id": task_id, "gate_result": "accepted", "updated_at": now})}["completed"]


def _default_actor(task: dict[str, Any]) -> str:
    return "codex" if task.get("stage") == "implementation" else "claude"


def _actor_matches_assignment(actor: Any, assigned_actor: str) -> bool:
    if actor == assigned_actor:
        return True
    if assigned_actor == "claude_codex" and actor in {"claude", "codex"}:
        return True
    return False


def _audit(run_id: str, task_id: str, event_type: str, result: str, violations: list[str]) -> dict[str, Any]:
    return {"type": event_type, "run_id": run_id, "task_id": task_id, "result": result, "violations": violations}


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".tmp.{path.name}.{os.getpid()}")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def _append_jsonl(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        json.dump(record, handle, ensure_ascii=False)
        handle.write("\n")
