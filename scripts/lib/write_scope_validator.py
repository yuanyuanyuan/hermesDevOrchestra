from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


MERGE_STRATEGIES = frozenset({"ordered_merge", "last_writer_wins", "manual_conflict_resolution", "abort_on_conflict"})
WRITE_SET_INTENTS = frozenset({"create", "modify", "delete"})


class WriteScopeError(Exception):
    def __init__(self, code: str, message: str, violations: list[str] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.violations = violations or []


def normalize_path(value: Any) -> str:
    """Normalize a relative repository path and reject traversal or absolute paths."""
    if not isinstance(value, str) or not value.strip():
        raise WriteScopeError("write_scope_violation", "write scope path must be a non-empty string", ["path"])
    if os.path.isabs(value):
        raise WriteScopeError("write_scope_violation", "write scope path must be relative", [value])
    normalized = os.path.normpath(value).lstrip("./")
    if normalized in {"", "."} or normalized == ".." or normalized.startswith("../") or "/../" in normalized:
        raise WriteScopeError("write_scope_violation", "write scope path must not escape the repository", [value])
    return normalized


def normalize_scope(scope: Any) -> list[str]:
    """Return a sorted, de-duplicated write scope after validating each path."""
    if not isinstance(scope, list):
        raise WriteScopeError("write_scope_violation", "write scope must be a list", ["write_scope"])
    return sorted({normalize_path(item) for item in scope})


def validate_merge_strategy(value: Any) -> str:
    if value not in MERGE_STRATEGIES:
        raise WriteScopeError("invalid_merge_strategy", "merge_strategy must be one of the supported enum values", [str(value)])
    return str(value)


def normalize_write_set(write_set: Any) -> dict[str, Any]:
    if not isinstance(write_set, dict):
        raise WriteScopeError("write_set_invalid", "write_set must be an object", ["write_set"])
    declared = write_set.get("declared_paths")
    if not isinstance(declared, list):
        raise WriteScopeError("write_set_invalid", "declared_paths must be a list", ["declared_paths"])
    normalized_paths = []
    for item in declared:
        if not isinstance(item, dict):
            raise WriteScopeError("write_set_invalid", "declared_paths entries must be objects", ["declared_paths"])
        intent = item.get("intent")
        if intent not in WRITE_SET_INTENTS:
            raise WriteScopeError("write_set_invalid", "declared path intent is invalid", [str(intent)])
        normalized_paths.append({"path": normalize_path(item.get("path")), "intent": intent, "optional": bool(item.get("optional", False))})
    normalized = dict(write_set)
    normalized["declared_paths"] = sorted(normalized_paths, key=lambda entry: entry["path"])
    return normalized


def evaluate_parallel_write_sets(
    write_sets: list[dict[str, Any]],
    merge_strategy: Any = None,
    *,
    events_path: Path | str | None = None,
    run_id: str | None = None,
    task_id: str | None = None,
) -> dict[str, Any]:
    normalized = [normalize_write_set(item) for item in write_sets]
    owners: dict[str, str] = {}
    conflicts: list[str] = []
    for item in normalized:
        task_id = str(item.get("task_id") or "")
        for declared in item["declared_paths"]:
            path = declared["path"]
            owner = owners.setdefault(path, task_id)
            if owner != task_id:
                conflicts.append(path)
    conflict_paths = sorted(set(conflicts))
    if not conflict_paths:
        return {"allowed": True, "disjoint": True, "conflict_paths": [], "merge_strategy": None}
    if merge_strategy is None:
        if events_path is not None:
            append_parallel_write_conflict_event(Path(events_path), run_id or "", task_id or "", conflict_paths)
        raise WriteScopeError("parallel_write_conflict", "parallel tasks require disjoint write sets or an explicit merge strategy", conflict_paths)
    strategy = validate_merge_strategy(merge_strategy)
    return {"allowed": True, "disjoint": False, "conflict_paths": conflict_paths, "merge_strategy": strategy, "conflict_accepted": True}


def append_parallel_write_conflict_event(events_path: Path, run_id: str, task_id: str, conflict_paths: list[str]) -> None:
    events_path.parent.mkdir(parents=True, exist_ok=True)
    event = {
        "schema_version": "orchestra.event.v1",
        "seq": _next_event_seq(events_path),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "task_id": task_id,
        "stage": "dispatch",
        "type": "parallel_write_conflict",
        "severity": "error",
        "status": "blocked",
        "message": "Parallel write set conflict blocked dispatch",
        "artifact_refs": [],
        "decision_id": None,
        "conflict_paths": conflict_paths,
    }
    with events_path.open("a", encoding="utf-8") as handle:
        json.dump(event, handle, ensure_ascii=False)
        handle.write("\n")


def _next_event_seq(path: Path) -> int:
    if not path.exists():
        return 1
    seq = 0
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                seq = max(seq, int(json.loads(line).get("seq", 0)))
    return seq + 1


def compute_expected_write_scope(tasks: list[dict[str, Any]], task_id: str) -> list[str]:
    """Compute the target task write scope and reject overlaps within its parallel boundary."""
    target = next((task for task in tasks if isinstance(task, dict) and task.get("task_id") == task_id), None)
    if target is None:
        raise WriteScopeError("task_not_found", "task not found", [task_id])
    boundary_id = target.get("parallel_boundary_id")
    if isinstance(boundary_id, str) and boundary_id:
        seen: dict[str, str] = {}
        overlaps: list[str] = []
        for task in tasks:
            if not isinstance(task, dict) or task.get("parallel_boundary_id") != boundary_id:
                continue
            current_task_id = str(task.get("task_id") or "")
            for path in normalize_scope(task.get("write_scope", [])):
                owner = seen.setdefault(path, current_task_id)
                if owner != current_task_id:
                    overlaps.append(path)
        if overlaps:
            raise WriteScopeError("parallel_write_scope_overlap", "parallel tasks share write scope paths", sorted(set(overlaps)))
    return normalize_scope(target.get("write_scope", []))


def validate_completion_scope(
    workspace_root: Path | str,
    computed_write_scope: list[str],
    reported_write_scope: list[str],
    file_manifest: list[dict[str, Any]],
) -> dict[str, Any]:
    """Validate reported writes and manifest hashes against the Gateway-computed scope."""
    expected = set(normalize_scope(computed_write_scope))
    reported = set(normalize_scope(reported_write_scope))
    extra_reported = sorted(reported - expected)
    if extra_reported:
        raise WriteScopeError("write_scope_violation", "reported write scope contains paths outside computed scope", extra_reported)

    workspace = Path(workspace_root).resolve()
    manifest_paths: list[str] = []
    for item in file_manifest:
        if not isinstance(item, dict):
            raise WriteScopeError("unexpected_file_detected", "file manifest entries must be objects", ["file_manifest"])
        rel_path = normalize_path(item.get("path"))
        if rel_path not in expected:
            raise WriteScopeError("unexpected_file_detected", "file manifest contains a path outside computed scope", [rel_path])
        actual_path = (workspace / rel_path).resolve()
        if not _is_within(actual_path, workspace):
            raise WriteScopeError("symlink_escape_detected", "file manifest path resolves outside workspace", [rel_path])
        declared_sha = item.get("sha256")
        if not isinstance(declared_sha, str) or len(declared_sha) != 64:
            raise WriteScopeError("file_integrity_mismatch", "file manifest sha256 must be a 64-character hex string", [rel_path])
        try:
            actual_sha = hashlib.sha256(actual_path.read_bytes()).hexdigest()
        except OSError as exc:
            raise WriteScopeError("file_integrity_mismatch", f"file is not readable: {exc}", [rel_path]) from exc
        if actual_sha.lower() != declared_sha.lower():
            raise WriteScopeError("file_integrity_mismatch", "file content does not match declared sha256", [rel_path])
        manifest_paths.append(rel_path)

    return {
        "result": "passed",
        "computed_write_scope": sorted(expected),
        "reported_write_scope": sorted(reported),
        "file_manifest_paths": sorted(manifest_paths),
    }


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True
