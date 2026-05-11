#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="observability-plugin"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DB_PATH="$TMP_DIR/observability_trace.db"
PLUGIN_PATH="$REPO_ROOT/hermes/plugins/observability/__init__.py"

OBSERVABILITY_DB_PATH="$DB_PATH" HERMES_ORCHESTRA_PROJECT="plugin-proj" HERMES_KANBAN_TASK="task-plugin-1" python3 - "$PLUGIN_PATH" "$DB_PATH" <<'PY'
import importlib.util
import sqlite3
import sys

plugin_path, db_path = sys.argv[1:]
spec = importlib.util.spec_from_file_location("observability_plugin", plugin_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class FakeCtx:
    def __init__(self):
        self.hooks = {}
    def register_hook(self, name, handler):
        self.hooks[name] = handler

ctx = FakeCtx()
module.register(ctx)
ctx.hooks["post_tool_call"]("terminal", {"command": "pytest"}, {"_duration_ms": 42, "error": "boom"})
ctx.hooks["on_session_end"]({"completed": True, "interrupted": False, "model": "codex", "platform": "linux", "total_tools": 3, "ok_count": 2, "error_count": 1, "duration_ms": 420})

conn = sqlite3.connect(db_path)
trace = conn.execute("select tool_name, result_status, duration_ms from tool_call_traces").fetchone()
assert trace == ("terminal", "error", 42)
summary = conn.execute("select completed, interrupted, model, total_tools, error_count from session_summaries").fetchone()
assert summary == (1, 0, "codex", 3, 1)
conn.close()
PY

assert_file_exists "$DB_PATH" "observability trace db should be created"
test_done
