import hashlib
import json
import os
import sqlite3
from pathlib import Path
from typing import Any


def _trace_db_path() -> Path:
    explicit = os.environ.get("OBSERVABILITY_DB_PATH")
    if explicit:
        return Path(explicit)

    audit_root = os.environ.get("AUDIT_ROOT")
    project_id = os.environ.get("HERMES_ORCHESTRA_PROJECT")
    if audit_root and project_id:
        return Path(audit_root) / project_id / "observability_trace.db"

    orchestra_home = os.environ.get("ORCHESTRA_HOME") or os.path.join(os.path.expanduser("~"), ".hermes-orchestra")
    return Path(orchestra_home) / "observability" / "observability_trace.db"


def _connect() -> sqlite3.Connection:
    path = _trace_db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute(
        """
        create table if not exists tool_call_traces (
          id integer primary key autoincrement,
          project_id text,
          task_id text,
          tool_name text,
          params_hash text,
          result_status text,
          duration_ms integer,
          recorded_at text,
          payload_json text
        )
        """
    )
    conn.execute(
        """
        create table if not exists session_summaries (
          id integer primary key autoincrement,
          project_id text,
          task_id text,
          completed integer,
          interrupted integer,
          model text,
          platform text,
          total_tools integer,
          ok_count integer,
          error_count integer,
          duration_ms integer,
          recorded_at text,
          payload_json text
        )
        """
    )
    return conn


def _json_dumps(payload: Any) -> str:
    return json.dumps(payload, ensure_ascii=False, sort_keys=True, default=str)


def _params_hash(payload: Any) -> str:
    return hashlib.sha256(_json_dumps(payload).encode("utf-8")).hexdigest()


def _project_id() -> str:
    return os.environ.get("HERMES_ORCHESTRA_PROJECT", "")


def _task_id() -> str:
    return os.environ.get("HERMES_KANBAN_TASK", "")


def register(ctx: Any) -> None:
    def on_post_tool_call(tool_name: str, params: Any = None, result: Any = None, **kwargs: Any) -> None:
        result = result or {}
        payload = {
            "tool_name": tool_name,
            "params": params,
            "result": result,
            "extra": kwargs,
        }
        duration_ms = 0
        if isinstance(result, dict):
            try:
                duration_ms = int(result.get("_duration_ms") or result.get("duration_ms") or 0)
            except Exception:
                duration_ms = 0
            result_status = "error" if result.get("error") else "ok"
        else:
            result_status = "ok"

        conn = _connect()
        conn.execute(
            """
            insert into tool_call_traces(project_id, task_id, tool_name, params_hash, result_status, duration_ms, recorded_at, payload_json)
            values (?, ?, ?, ?, ?, ?, datetime('now'), ?)
            """,
            (
                _project_id(),
                _task_id(),
                tool_name,
                _params_hash(params),
                result_status,
                duration_ms,
                _json_dumps(payload),
            ),
        )
        conn.commit()
        conn.close()

    def on_session_end(session_info: Any = None, **kwargs: Any) -> None:
        session_info = session_info or {}
        payload = {"session_info": session_info, "extra": kwargs}

        total_tools = int(session_info.get("total_tools") or kwargs.get("total_tools") or 0) if isinstance(session_info, dict) else 0
        ok_count = int(session_info.get("ok_count") or kwargs.get("ok_count") or 0) if isinstance(session_info, dict) else 0
        error_count = int(session_info.get("error_count") or kwargs.get("error_count") or 0) if isinstance(session_info, dict) else 0
        duration_ms = int(session_info.get("duration_ms") or kwargs.get("duration_ms") or 0) if isinstance(session_info, dict) else 0
        completed = 1 if bool(session_info.get("completed")) else 0 if isinstance(session_info, dict) else 0
        interrupted = 1 if bool(session_info.get("interrupted")) else 0 if isinstance(session_info, dict) else 0
        model = session_info.get("model", "") if isinstance(session_info, dict) else ""
        platform = session_info.get("platform", "") if isinstance(session_info, dict) else ""

        conn = _connect()
        conn.execute(
            """
            insert into session_summaries(project_id, task_id, completed, interrupted, model, platform, total_tools, ok_count, error_count, duration_ms, recorded_at, payload_json)
            values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), ?)
            """,
            (
                _project_id(),
                _task_id(),
                completed,
                interrupted,
                model,
                platform,
                total_tools,
                ok_count,
                error_count,
                duration_ms,
                _json_dumps(payload),
            ),
        )
        conn.commit()
        conn.close()

    ctx.register_hook("post_tool_call", on_post_tool_call)
    ctx.register_hook("on_session_end", on_session_end)
