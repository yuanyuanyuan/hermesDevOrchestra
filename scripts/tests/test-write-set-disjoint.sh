#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="write-set-disjoint"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

export PYTHONPATH="$REPO_ROOT/scripts/lib"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$TMP_DIR/events.jsonl" <<'PY'
import json
import sys

from write_scope_validator import WriteScopeError, evaluate_parallel_write_sets

events_path = sys.argv[1]
task_a = {
    "task_id": "task-a",
    "declared_paths": [{"path": "./src/a.py", "intent": "modify", "optional": False}],
}
task_b = {
    "task_id": "task-b",
    "declared_paths": [{"path": "tests/test_a.py", "intent": "create", "optional": True}],
}
allowed = evaluate_parallel_write_sets([task_a, task_b])
assert allowed["allowed"] is True
assert allowed["disjoint"] is True

task_c = {
    "task_id": "task-c",
    "declared_paths": [{"path": "src/a.py", "intent": "modify", "optional": False}],
}
try:
    evaluate_parallel_write_sets([task_a, task_c], events_path=events_path, run_id="run-write-set", task_id="task-a")
except WriteScopeError as exc:
    assert exc.code == "parallel_write_conflict", exc.code
    assert exc.violations == ["src/a.py"], exc.violations
else:
    raise AssertionError("overlapping write sets without merge strategy were allowed")

events = [json.loads(line) for line in open(events_path, encoding="utf-8")]
assert events[0]["type"] == "parallel_write_conflict", events
assert events[0]["conflict_paths"] == ["src/a.py"], events

merged = evaluate_parallel_write_sets([task_a, task_c], merge_strategy="ordered_merge")
assert merged["allowed"] is True
assert merged["disjoint"] is False
assert merged["conflict_accepted"] is True
assert merged["merge_strategy"] == "ordered_merge"
PY

test_done
