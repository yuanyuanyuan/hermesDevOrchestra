#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="evidence-missing-blocks"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import hashlib
import json
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from dispatch_gate import submit_completion_payload
from evidence_gate import EvidenceGateError, validate_completion_evidence
from worker_session import WorkerSessionManager


def expect(code, payload):
    try:
        validate_completion_evidence(payload, artifact_refs={"state://runs/r/artifacts/test.json"})
    except EvidenceGateError as exc:
        assert exc.code == code, (exc.code, code, exc.violations)
        return
    raise AssertionError(f"expected {code}")


valid = {
    "test_evidence": {"exit_code": 0, "stdout_summary": "passed", "coverage": None},
    "review_evidence": {"reviewer_id": "claude", "conclusion": "approve", "blockers": [], "warnings": ["minor"]},
    "commit_evidence": {"commit_hash": "abc123", "diff_stat": "1 file changed", "issue": "U8"},
    "evidence_refs": ["state://runs/r/artifacts/test.json"],
    "artifacts": [{"ref": "state://runs/r/artifacts/test.json"}],
}
assert validate_completion_evidence(valid)["result"] == "passed"

missing_test = dict(valid)
missing_test.pop("test_evidence")
expect("evidence_missing", missing_test)

missing_review = dict(valid)
missing_review.pop("review_evidence")
expect("evidence_missing", missing_review)

failed_test = {**valid, "test_evidence": {"exit_code": 1, "stdout_summary": "failed"}}
expect("test_failure", failed_test)

blocked = {**valid, "review_evidence": {"reviewer_id": "claude", "conclusion": "changes", "blockers": ["bug"], "warnings": []}}
expect("review_blockers_unresolved", blocked)

bad_ref = {**valid, "evidence_refs": ["state://runs/r/missing.json"], "artifacts": []}
expect("evidence_ref_unresolvable", bad_ref)


class Store:
    def __init__(self, root):
        self.root = root
        self.project_id = "project-1"

    def run_dir(self, run_id):
        return self.root / "runs" / run_id

    def run_path(self, run_id):
        return self.run_dir(run_id) / "run.json"

    def tasks_path(self, run_id):
        return self.run_dir(run_id) / "tasks.json"

    def audit_path(self):
        return self.root / "audit.jsonl"

    def state_ref(self, run_id, rel_path):
        return f"state://runs/{run_id}/{rel_path}"


class App:
    schema_version = "orchestra.full.v1"
    repo_root = repo

    def __init__(self, root):
        self.store = Store(root)

    def find_projected_task(self, tasks, task_id):
        return next((task for task in tasks["tasks"] if task["task_id"] == task_id), None)

    def error(self, code, message):
        return {"error": {"code": code, "message": message}}


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    app = App(root / "state")
    run_id = "run-1"
    task_id = "task-1"
    run_dir = app.store.run_dir(run_id)
    run_dir.mkdir(parents=True)
    app.store.run_path(run_id).write_text("{}\n", encoding="utf-8")

    manager = WorkerSessionManager(repo, suffix_factory=lambda: "aaaabbbbcccc")
    record = manager.create_dispatch_session(
        run_id=run_id,
        task_id=task_id,
        assigned_actor="codex",
        workspace_root=root / "worker-sessions",
        computed_write_scope=["src/login.py"],
        context_bundle_id="bundle-task-1",
    )
    manager.persist_record(record, run_dir / "worker-sessions")

    target = Path(record["workspace_path"]) / "src" / "login.py"
    target.parent.mkdir(parents=True)
    target.write_text("print('ok')\n", encoding="utf-8")
    digest = hashlib.sha256(target.read_bytes()).hexdigest()

    session_ref = app.store.state_ref(run_id, f"worker-sessions/{record['session_id']}.json")
    tasks = {
        "tasks": [
            {
                "task_id": task_id,
                "status": "dispatched",
                "worker_session_ref": session_ref,
            }
        ]
    }
    app.store.tasks_path(run_id).write_text(json.dumps(tasks) + "\n", encoding="utf-8")

    status, body = submit_completion_payload(
        app,
        run_id,
        {
            "task_id": task_id,
            "dispatch_token": record["dispatch_token"],
            "completion_payload": {
                "reported_write_scope": ["src/login.py"],
                "file_manifest": [{"path": "src/login.py", "sha256": digest}],
                "test_evidence": {"exit_code": 0},
                "review_evidence": {"reviewer_id": "x", "conclusion": "approve", "blockers": []},
                "commit_evidence": {"commit_hash": "abc"},
                "evidence_refs": ["state://runs/run-1/missing.json"],
                "artifacts": [],
            },
        },
    )
    assert status == 200, status
    assert body["gate_result"] == "blocked", body
    assert body["failure_class"] == "evidence_ref_unresolvable", body
    audit_records = [json.loads(line) for line in app.store.audit_path().read_text(encoding="utf-8").splitlines()]
    assert audit_records[-1]["type"] == "evidence_gate_check", audit_records
PY

test_done
