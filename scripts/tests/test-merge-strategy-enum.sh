#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="merge-strategy-enum"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

export PYTHONPATH="$REPO_ROOT/scripts/lib"

python3 - <<'PY'
from write_scope_validator import MERGE_STRATEGIES, WriteScopeError, validate_merge_strategy

expected = {"ordered_merge", "last_writer_wins", "manual_conflict_resolution", "abort_on_conflict"}
assert MERGE_STRATEGIES == expected
for strategy in expected:
    assert validate_merge_strategy(strategy) == strategy

for invalid in ["three_way_merge", "", None]:
    try:
        validate_merge_strategy(invalid)
    except WriteScopeError as exc:
        assert exc.code == "invalid_merge_strategy", exc.code
    else:
        raise AssertionError(f"invalid strategy was accepted: {invalid!r}")
PY

test_done
