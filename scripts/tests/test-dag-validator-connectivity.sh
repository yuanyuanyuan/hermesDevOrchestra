#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="dag-validator-connectivity"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from dag_validator import validate_dag

orphaned = {
    "root_id": "root",
    "nodes": ["root", "reachable", "orphan"],
    "edges": [{"from": "root", "to": "reachable"}],
}
result = validate_dag(orphaned)
assert result["connectivity_passed"] is False, result
assert result["orphan_task_ids"] == ["orphan"], result
assert "orphan_task" in result["errors"], result

connected = {
    "root_id": "root",
    "nodes": [
        {"id": "root"},
        {"id": "task-a", "dependencies": ["root"]},
        {"id": "task-b", "dependencies": ["task-a"]},
    ],
    "edges": [{"from": "root", "to": "task-a"}, {"from": "task-a", "to": "task-b"}],
}
passed = validate_dag(connected)
assert passed["connectivity_passed"] is True, passed
assert passed["orphan_task_ids"] == [], passed
assert passed["topological_sort_consistent"] is True, passed
PY

test_done
