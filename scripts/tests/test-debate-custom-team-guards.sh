#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-custom-team-guards"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from security_scanner import SecurityScanner
from team_selector import TeamSelector

report = SecurityScanner(repo).scan('eval(request.body)', team_id="unsafe_custom")
assert report["status"] == "blocked", report
assert report["blocked_keywords"] == ["eval("], report

result = TeamSelector(repo).select(
    task_type="refactor",
    project_profile={
        "max_teams": 32,
        "custom_teams": [{"id": "unsafe_custom", "prompt_injection": "eval(request.body)"}],
    },
)
assert "unsafe_custom" in result.security_blocked_team_ids, result
assert "unsafe_custom" not in result.selected_team_ids, result
PY

test_done
