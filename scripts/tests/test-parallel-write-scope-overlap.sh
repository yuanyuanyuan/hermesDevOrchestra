#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="parallel-write-scope-overlap"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from write_scope_validator import WriteScopeError, compute_expected_write_scope


tasks = [
    {"task_id": "a", "parallel_boundary_id": "p1", "write_scope": ["src/a.py", "./src/shared.py"]},
    {"task_id": "b", "parallel_boundary_id": "p1", "write_scope": ["src/b.py"]},
]
assert compute_expected_write_scope(tasks, "a") == ["src/a.py", "src/shared.py"]

overlap = [
    {"task_id": "a", "parallel_boundary_id": "p1", "write_scope": ["src/shared.py"]},
    {"task_id": "b", "parallel_boundary_id": "p1", "write_scope": ["./src/shared.py"]},
]
try:
    compute_expected_write_scope(overlap, "a")
except WriteScopeError as exc:
    assert exc.code == "parallel_write_scope_overlap", (exc.code, exc.violations)
else:
    raise AssertionError("expected parallel_write_scope_overlap")

try:
    compute_expected_write_scope([{"task_id": "a", "write_scope": ["/abs/path"]}], "a")
except WriteScopeError as exc:
    assert exc.code == "write_scope_violation", (exc.code, exc.violations)
else:
    raise AssertionError("expected absolute path violation")
PY

test_done
