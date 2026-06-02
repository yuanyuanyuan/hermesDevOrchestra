#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="source-isolation-collision"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$REPO_ROOT" "$TMP_DIR/audit.jsonl" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
audit = pathlib.Path(sys.argv[2])
sys.path.insert(0, str(repo / "scripts/lib"))

from dag_validator import check_source_isolation, compute_source_fingerprint

fingerprint = compute_source_fingerprint("agent-a", "/tmp/hermes-worker-a", "ctx-1")
collision = check_source_isolation(
    [
        {"task_id": "task-a", "delegate_to": "agent-a", "source_fingerprint": fingerprint},
        {"task_id": "task-b", "delegate_to": "agent-a", "source_fingerprint": fingerprint},
    ],
    audit_log_path=audit,
)
assert collision["passed"] is False, collision
assert collision["execution_mode"] == "sequential_execution", collision
assert collision["collisions"][0]["task_id"] == "task-b", collision
audit_text = audit.read_text(encoding="utf-8")
assert "source_isolation_check" in audit_text, audit_text
assert "source_collision" in audit_text, audit_text

no_collision = check_source_isolation(
    [
        {
            "task_id": "task-c",
            "delegate_to": "agent-a",
            "source": {"agent_id": "agent-a", "workspace_path": "/tmp/a", "context_hash": "ctx-c"},
        },
        {
            "task_id": "task-d",
            "delegate_to": "agent-b",
            "source": {"agent_id": "agent-b", "workspace_path": "/tmp/a", "context_hash": "ctx-d"},
        },
    ]
)
assert no_collision["passed"] is True, no_collision
assert no_collision["degraded"] is False, no_collision
PY

test_done
