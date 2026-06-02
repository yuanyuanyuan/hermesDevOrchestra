#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="quick-channel-rollout-gate"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

jq -e '.channels.quick.enabled | type == "boolean"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.quick.max_files | type == "number"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.quick.required_evidence | type == "array"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.light.enabled | type == "boolean"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.light.max_files | type == "number"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.light.required_evidence | type == "array"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.standard.enabled | type == "boolean"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.standard.max_files | type == "number"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null
jq -e '.channels.standard.required_evidence | type == "array"' "$REPO_ROOT/config/performance/slo-policy.json" >/dev/null

python3 - "$REPO_ROOT" <<'PY'
import json
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from channel_router import ChannelRouter
from rollout_gate import RolloutGate


router = ChannelRouter(repo)
week_one_decision = router.classify(
    {"task_type": "lint", "files_count": 5},
    project_age_weeks=1,
    profile={},
)
assert week_one_decision["channel"] == "standard", week_one_decision
assert week_one_decision["reason"] == "week_1_2_quick_file_limit_exceeded", week_one_decision

week_three_refactor = router.classify(
    {"task_type": "single_file_refactor", "files_count": 1},
    project_age_weeks=3,
    profile={},
)
assert week_three_refactor["channel"] == "quick", week_three_refactor

week_four_multifile = router.classify(
    {"task_type": "refactor", "files_count": 3},
    project_age_weeks=4,
    profile={},
)
assert week_four_multifile["channel"] == "quick", week_four_multifile

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    config_dir = tmp_repo / "config/performance"
    config_dir.mkdir(parents=True)
    config = json.loads((repo / "config/performance/slo-policy.json").read_text(encoding="utf-8"))
    config["channels"]["quick"]["max_files"] = 5
    (config_dir / "slo-policy.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
    configurable_router = ChannelRouter(tmp_repo)
    five_file_refactor = configurable_router.classify(
        {"task_type": "refactor", "files_count": 5},
        project_age_weeks=4,
        profile={},
    )
    assert five_file_refactor["channel"] == "quick", five_file_refactor

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    config_dir = tmp_repo / "config/performance"
    config_dir.mkdir(parents=True)
    config = json.loads((repo / "config/performance/slo-policy.json").read_text(encoding="utf-8"))
    config["channels"]["quick"]["week_4_plus_allowed_tasks"] = ["lint", "syntax", "i18n", "hardcoded_scan"]
    (config_dir / "slo-policy.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
    configurable_router = ChannelRouter(tmp_repo)
    configured_out_refactor = configurable_router.classify(
        {"task_type": "refactor", "files_count": 3},
        project_age_weeks=4,
        profile={},
    )
    assert configured_out_refactor["channel"] == "light", configured_out_refactor

gate = RolloutGate(repo)
forced = gate.allow(
    "quick",
    project_age_weeks=4,
    calibration_evidence={"confidence": 0.5, "coverage": 0.3},
)
assert forced["forced_standard"] is True, forced
assert forced["channel"] == "standard", forced
assert forced["reason"] == "insufficient_calibration_evidence", forced

allowed = gate.allow(
    "quick",
    project_age_weeks=4,
    calibration_evidence={"confidence": 0.8, "coverage": 0.7},
)
assert allowed["allowed"] is True, allowed
assert allowed["channel"] == "quick", allowed
assert allowed["forced_standard"] is False, allowed
PY

test_done
