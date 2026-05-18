#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="worker-session"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 - "$REPO_ROOT" <<'PY'
import json
import stat
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_report import validate_artifact_definition
from worker_session import WorkerSessionError, WorkerSessionManager
from worker_session_sweeper import WorkerSessionSweeper


class FakeClock:
    def __init__(self, current: datetime):
        self.current = current

    def now(self) -> datetime:
        return self.current

    def advance(self, seconds: int) -> None:
        self.current = self.current + timedelta(seconds=seconds)


class FakeTmuxController:
    def __init__(self) -> None:
        self.live_sessions: set[tuple[str, str]] = set()
        self.interrupt_requests: list[tuple[str, str]] = []
        self.kill_requests: list[tuple[str, str]] = []
        self.remove_on_interrupt: set[tuple[str, str]] = set()
        self.interrupt_failures: set[tuple[str, str]] = set()
        self.kill_failures: set[tuple[str, str]] = set()

    def add(self, record: dict, remove_on_interrupt: bool = False) -> None:
        key = (record["tmux_socket_name"], record["tmux_session_name"])
        self.live_sessions.add(key)
        if remove_on_interrupt:
            self.remove_on_interrupt.add(key)

    def has_session(self, socket_name: str, session_name: str) -> bool:
        return (socket_name, session_name) in self.live_sessions

    def send_interrupt(self, socket_name: str, session_name: str) -> bool:
        key = (socket_name, session_name)
        self.interrupt_requests.append(key)
        if key in self.interrupt_failures:
            return False
        if key in self.remove_on_interrupt:
            self.live_sessions.discard(key)
        return key not in self.live_sessions

    def kill_session(self, socket_name: str, session_name: str) -> bool:
        key = (socket_name, session_name)
        self.kill_requests.append(key)
        if key in self.kill_failures:
            return False
        self.live_sessions.discard(key)
        return True


def expect_error(error_type, code: str, func):
    try:
        func()
    except error_type as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected {error_type.__name__}({code})")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


clock = FakeClock(datetime(2026, 5, 18, 8, 0, tzinfo=timezone.utc))
suffixes = iter(
    [
        "aaaabbbbcccc",
        "ddddeeeeffff",
        "111122223333",
        "444455556666",
        "777788889999",
        "aaa111bbb222",
        "ccc333ddd444",
    ]
)
manager = WorkerSessionManager(
    repo,
    clock=clock.now,
    suffix_factory=lambda: next(suffixes),
)

with tempfile.TemporaryDirectory() as tmp:
    tmp_path = Path(tmp)
    workspace_root = tmp_path / "workspaces"
    records_root = tmp_path / "records"

    record = manager.create_session(
        run_id="run-1",
        task_id="task-1",
        role="implementer",
        backend_id="codex",
        workspace_root=workspace_root,
        write_scope_ref="state://runs/run-1/write-scopes/task-1.json",
        context_bundle_ref="state://runs/run-1/context/task-1.json",
        timeout_seconds=30,
    )
    validate_artifact_definition(repo, "worker_session_record", record)
    assert record["status"] == "planned", record
    assert record["cleanup_owner"] == "gateway_worker_session_sweeper", record
    assert record["cleanup_status"] == "not_started", record
    assert record["output_envelope_ref"] is None, record
    assert record["session_id"] == "run-1-task-1-aaaabbbbcccc", record
    assert record["tmux_socket_name"] == "hermes-worker-aaaabbbbcccc", record
    assert record["tmux_launch_args"][:2] == ["-L", "hermes-worker-aaaabbbbcccc"], record
    workspace_path = Path(record["workspace_path"])
    assert workspace_path.name == "run-1-task-1-aaaabbbbcccc", record
    assert stat.S_IMODE(workspace_path.stat().st_mode) == 0o700, oct(workspace_path.stat().st_mode)

    second = manager.create_session(
        run_id="run-1",
        task_id="task-1",
        role="implementer",
        backend_id="codex",
        workspace_root=workspace_root,
        write_scope_ref="state://runs/run-1/write-scopes/task-1.json",
        context_bundle_ref="state://runs/run-1/context/task-1.json",
        timeout_seconds=30,
    )
    assert second["session_id"] != record["session_id"], (record, second)
    assert second["tmux_socket_name"] != record["tmux_socket_name"], (record, second)

    rollback_manager = WorkerSessionManager(
        repo,
        clock=clock.now,
        suffix_factory=lambda: "aaa111bbb222",
    )
    original_validate_record = rollback_manager.validate_record

    def fail_validation(record):
        raise WorkerSessionError("record_invalid", "forced validation failure")

    rollback_manager.validate_record = fail_validation
    rollback_workspace = workspace_root / "run-rollback-task-rollback-aaa111bbb222"
    expect_error(
        WorkerSessionError,
        "record_invalid",
        lambda: rollback_manager.create_session(
            run_id="run-rollback",
            task_id="task-rollback",
            role="implementer",
            backend_id="codex",
            workspace_root=workspace_root,
            write_scope_ref="state://runs/run-rollback/write-scopes/task-rollback.json",
            context_bundle_ref="state://runs/run-rollback/context/task-rollback.json",
            timeout_seconds=30,
        ),
    )
    rollback_manager.validate_record = original_validate_record
    assert not rollback_workspace.exists(), rollback_workspace

    record_path = manager.persist_record(record, records_root)
    loaded_record = manager.load_record(record_path)
    validate_artifact_definition(repo, "worker_session_record", loaded_record)
    assert loaded_record["session_id"] == record["session_id"], loaded_record

    expect_error(
        WorkerSessionError,
        "validation_error",
        lambda: manager.create_session(
            run_id="run-1",
            task_id="bad-timeout",
            role="implementer",
            backend_id="codex",
            workspace_root=workspace_root,
            write_scope_ref="state://runs/run-1/write-scopes/bad-timeout.json",
            context_bundle_ref="state://runs/run-1/context/bad-timeout.json",
            timeout_seconds=0,
        ),
    )
    expect_error(
        WorkerSessionError,
        "invalid_transition",
        lambda: manager.transition(record, "completed"),
    )
    expect_error(
        WorkerSessionError,
        "invalid_transition",
        lambda: manager.record_heartbeat(record),
    )
    expect_error(
        WorkerSessionError,
        "record_invalid",
        lambda: manager.transition({**record, "status": "bogus"}, "running"),
    )

    record = manager.transition(record, "starting")
    clock.advance(5)
    record = manager.record_heartbeat(record)
    clock.advance(5)
    record = manager.transition(record, "running")
    clock.advance(5)
    record = manager.transition(record, "stopping")
    clock.advance(5)
    record = manager.transition(
        record,
        "completed",
        output_envelope_ref="state://runs/run-1/worker-output/task-1.json",
        cleanup_status="cleaned",
    )
    validate_artifact_definition(repo, "worker_session_record", record)
    assert record["ended_at"] is not None, record
    assert record["status"] == "completed", record

    timed_out_record = manager.create_session(
        run_id="run-2",
        task_id="task-2",
        role="implementer",
        backend_id="codex",
        workspace_root=workspace_root,
        write_scope_ref="state://runs/run-2/write-scopes/task-2.json",
        context_bundle_ref="state://runs/run-2/context/task-2.json",
        timeout_seconds=10,
    )
    timed_out_record = manager.transition(timed_out_record, "starting")
    timed_out_record = manager.record_heartbeat(timed_out_record)
    timed_out_record = manager.transition(timed_out_record, "running")
    timed_out_path = manager.persist_record(timed_out_record, records_root)

    missing_record = manager.create_session(
        run_id="run-3",
        task_id="task-3",
        role="reviewer",
        backend_id="claude",
        workspace_root=workspace_root,
        write_scope_ref="state://runs/run-3/write-scopes/task-3.json",
        context_bundle_ref="state://runs/run-3/context/task-3.json",
        timeout_seconds=10,
    )
    missing_record = manager.transition(missing_record, "starting")
    missing_record = manager.record_heartbeat(missing_record)
    missing_record = manager.transition(missing_record, "running")
    missing_path = manager.persist_record(missing_record, records_root)

    cleanup_failure_record = manager.create_session(
        run_id="run-4",
        task_id="task-4",
        role="implementer",
        backend_id="codex",
        workspace_root=workspace_root,
        write_scope_ref="state://runs/run-4/write-scopes/task-4.json",
        context_bundle_ref="state://runs/run-4/context/task-4.json",
        timeout_seconds=10,
    )
    cleanup_failure_record = manager.transition(cleanup_failure_record, "starting")
    cleanup_failure_record = manager.record_heartbeat(cleanup_failure_record)
    cleanup_failure_record = manager.transition(cleanup_failure_record, "running")
    cleanup_failure_path = manager.persist_record(cleanup_failure_record, records_root)

    fake_tmux = FakeTmuxController()
    fake_tmux.add(load_json(timed_out_path))
    cleanup_failure_loaded = load_json(cleanup_failure_path)
    cleanup_failure_key = (
        cleanup_failure_loaded["tmux_socket_name"],
        cleanup_failure_loaded["tmux_session_name"],
    )
    fake_tmux.add(cleanup_failure_loaded)
    fake_tmux.interrupt_failures.add(cleanup_failure_key)
    fake_tmux.kill_failures.add(cleanup_failure_key)

    sweeper = WorkerSessionSweeper(
        repo,
        clock=clock.now,
        tmux_controller=fake_tmux,
    )

    clock.advance(15)
    sweep_result = sweeper.sweep_directory(records_root)
    assert sweep_result["updated_records"] == 3, sweep_result
    assert sweep_result["timed_out_records"] == 2, sweep_result
    assert sweep_result["missing_records"] == 1, sweep_result
    assert sweep_result["invalid_records"] == 0, sweep_result

    timed_out_loaded = manager.load_record(timed_out_path)
    validate_artifact_definition(repo, "worker_session_record", timed_out_loaded)
    assert timed_out_loaded["status"] == "timed_out", timed_out_loaded
    assert timed_out_loaded["cleanup_status"] == "cleaned", timed_out_loaded
    assert timed_out_loaded["termination_reason"] == "heartbeat_timeout", timed_out_loaded
    assert timed_out_loaded["ended_at"] == clock.now().isoformat(), timed_out_loaded
    assert ("hermes-worker-111122223333", "run-2-task-2-111122223333") in fake_tmux.interrupt_requests
    assert ("hermes-worker-111122223333", "run-2-task-2-111122223333") in fake_tmux.kill_requests

    missing_loaded = manager.load_record(missing_path)
    validate_artifact_definition(repo, "worker_session_record", missing_loaded)
    assert missing_loaded["status"] == "abandoned", missing_loaded
    assert missing_loaded["cleanup_status"] == "not_found", missing_loaded
    assert missing_loaded["termination_reason"] == "tmux_session_missing", missing_loaded
    assert missing_loaded["ended_at"] == clock.now().isoformat(), missing_loaded

    cleanup_failed = manager.load_record(cleanup_failure_path)
    validate_artifact_definition(repo, "worker_session_record", cleanup_failed)
    assert cleanup_failed["status"] == "timed_out", cleanup_failed
    assert cleanup_failed["cleanup_status"] == "failed", cleanup_failed
    assert cleanup_failed["cleanup_error"] == "tmux_cleanup_failed", cleanup_failed

    broken_record = records_root / "broken.json"
    broken_record.write_text("{broken", encoding="utf-8")
    resilient_sweep = sweeper.sweep_directory(records_root)
    assert resilient_sweep["invalid_records"] == 1, resilient_sweep
PY

test_done
