#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="channel-kill-switch"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import json
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from channel_router import ChannelRouter


with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    config_dir = tmp_repo / "config/performance"
    config_dir.mkdir(parents=True)
    source_policy = json.loads((repo / "config/performance/slo-policy.json").read_text(encoding="utf-8"))
    source_policy["channels"]["quick"]["enabled"] = False
    (config_dir / "slo-policy.json").write_text(json.dumps(source_policy, indent=2), encoding="utf-8")

    router = ChannelRouter(tmp_repo)
    decision = router.classify(
        {"task_type": "lint", "files_count": 1},
        project_age_weeks=1,
        profile={},
    )

    assert decision["channel"] in {"light", "standard"}, decision
    assert decision["downgrade_reason"] == "kill_switch_enabled", decision

    log_path = tmp_repo / "logs/channel-routing.jsonl"
    assert log_path.exists(), "channel routing log was not written"
    rows = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert rows, "channel routing log is empty"
    assert rows[-1]["downgrade_reason"] == "kill_switch_enabled", rows[-1]
    assert rows[-1]["original_channel"] == "quick", rows[-1]
    assert rows[-1]["routed_channel"] in {"light", "standard"}, rows[-1]
PY

test_done
