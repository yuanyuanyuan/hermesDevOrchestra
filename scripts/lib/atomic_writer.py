#!/usr/bin/env python3
"""Atomic file writer with conflict detection and recovery helpers."""

from __future__ import annotations

import json
import os
from pathlib import Path
from time import time_ns
from typing import Any, Callable, TypedDict


class WriteReceipt(TypedDict, total=False):
    """Receipt describing the result of an atomic write."""

    status: str
    path: str
    temp_path: str
    previous_mtime_ns: int | None
    current_mtime_ns: int | None
    bytes_written: int
    recovered: bool


class AtomicWriter:
    """Write JSON files atomically with mtime-based conflict detection."""

    def __init__(self, before_commit_hook: Callable[[Path, Path], None] | None = None) -> None:
        self.before_commit_hook = before_commit_hook

    def write(self, path: Path, data: dict[str, Any]) -> WriteReceipt:
        path.parent.mkdir(parents=True, exist_ok=True)
        previous_mtime_ns = path.stat().st_mtime_ns if path.exists() else None
        temp_path = path.with_name(f".tmp.{path.name}.{os.getpid()}.{time_ns()}")
        payload = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
        with temp_path.open("wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())

        if self.before_commit_hook is not None:
            self.before_commit_hook(path, temp_path)

        current_mtime_ns = path.stat().st_mtime_ns if path.exists() else None
        if previous_mtime_ns != current_mtime_ns and (previous_mtime_ns is not None or current_mtime_ns is not None):
            temp_path.unlink(missing_ok=True)
            return {
                "status": "conflict",
                "path": str(path),
                "temp_path": str(temp_path),
                "previous_mtime_ns": previous_mtime_ns,
                "current_mtime_ns": current_mtime_ns,
                "bytes_written": len(payload),
            }

        os.replace(temp_path, path)
        self._fsync_parent(path.parent)
        return {
            "status": "written",
            "path": str(path),
            "temp_path": str(temp_path),
            "previous_mtime_ns": previous_mtime_ns,
            "current_mtime_ns": path.stat().st_mtime_ns if path.exists() else None,
            "bytes_written": len(payload),
        }

    def recover(self, path: Path) -> WriteReceipt:
        if path.exists():
            try:
                json.loads(path.read_text(encoding="utf-8"))
                return {"status": "present", "path": str(path), "recovered": False}
            except json.JSONDecodeError:
                pass
        candidates = sorted(path.parent.glob(f".tmp.{path.name}.*"), key=lambda item: item.stat().st_mtime_ns, reverse=True)
        for candidate in candidates:
            try:
                json.loads(candidate.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                continue
            os.replace(candidate, path)
            self._fsync_parent(path.parent)
            return {"status": "recovered", "path": str(path), "temp_path": str(candidate), "recovered": True}
        return {"status": "missing", "path": str(path), "recovered": False}

    @staticmethod
    def _fsync_parent(parent: Path) -> None:
        try:
            fd = os.open(parent, os.O_RDONLY)
        except OSError:
            return
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
