#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="dag-validator-cycle"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$REPO_ROOT" "$TMP_DIR/events.jsonl" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
events = pathlib.Path(sys.argv[2])
sys.path.insert(0, str(repo / "scripts/lib"))

from dag_validator import validate_dag

cyclic = {
    "root_id": "A",
    "nodes": ["A", "B", "C"],
    "edges": [{"from": "A", "to": "B"}, {"from": "B", "to": "C"}, {"from": "C", "to": "A"}],
}
result = validate_dag(cyclic, event_log_path=events)
assert result["cycle_detected"] is True, result
assert result["acyclicity_passed"] is False, result
assert "cycle_detected" in result["errors"], result
assert "dag_cycle_detected" in events.read_text(encoding="utf-8")

acyclic = {
    "root_id": "root",
    "nodes": [{"id": "root"}, {"id": "A", "dependencies": ["root"]}, {"id": "B", "dependencies": ["A"]}],
    "edges": [{"from": "root", "to": "A"}, {"from": "A", "to": "B"}],
}
passed = validate_dag(acyclic)
assert passed["passed"] is True, passed
assert passed["cycle_detected"] is False, passed
assert passed["topological_order"] == ["root", "A", "B"], passed
PY

test_done
