from __future__ import annotations

import hashlib
import os
from pathlib import Path
from typing import Any


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
