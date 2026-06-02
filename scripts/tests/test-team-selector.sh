#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="team-selector"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from team_selector import TeamSelector

custom_teams = [
    {"id": f"extension_{index}", "name": f"Extension {index}", "prompt_injection": "review only"}
    for index in range(16)
]

result = TeamSelector(repo).select(
    task_type="refactor",
    project_profile={
        "max_teams": 32,
        "team_ids": ["architecture", "ux"],
        "custom_teams": custom_teams,
    },
)

assert len(result.canonical_team_ids) == 16, result
assert "platform" in result.selected_team_ids, result
assert "frontend" in result.selected_team_ids, result
assert len(result.extension_team_ids) == 16, result
assert len(result.selected_team_ids) == 32, result
assert result.alias_resolutions["architecture"] == "platform", result.alias_resolutions
assert result.alias_resolutions["ux"] == "frontend", result.alias_resolutions
PY

assert_file_exists "$REPO_ROOT/logs/team-selection.jsonl" "team selection log missing"
assert_jsonl_valid "$REPO_ROOT/logs/team-selection.jsonl"

test_done
