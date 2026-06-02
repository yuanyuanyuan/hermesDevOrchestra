#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="dispatch-token-forgery"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from worker_session import WorkerSessionError, WorkerSessionManager


class Clock:
    def __init__(self):
        self.value = datetime(2026, 6, 2, 0, 0, tzinfo=timezone.utc)

    def now(self):
        return self.value


def expect(code, func):
    try:
        func()
    except WorkerSessionError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return
    raise AssertionError(f"expected {code}")


clock = Clock()
manager = WorkerSessionManager(repo, clock=clock.now, suffix_factory=lambda: "aaaabbbbcccc")
with tempfile.TemporaryDirectory() as tmp:
    record = manager.create_dispatch_session(
        run_id="run-1",
        task_id="task-1",
        assigned_actor="codex",
        workspace_root=Path(tmp) / "worker-sessions",
        computed_write_scope=["src/login.py"],
        context_bundle_id="bundle-task-1",
        token_ttl_seconds=10,
    )

    assert manager.validate_dispatch_token(record, record["dispatch_token"], now=clock.now())["result"] == "passed"
    expect("dispatch_token_invalid", lambda: manager.validate_dispatch_token(record, "not-a-uuid", now=clock.now()))

    clock.value = clock.value + timedelta(seconds=11)
    expect("dispatch_token_expired", lambda: manager.validate_dispatch_token(record, record["dispatch_token"], now=clock.now()))
PY

test_done
