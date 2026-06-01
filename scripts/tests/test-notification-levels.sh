#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="notification-levels"
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

from auto_merge_controller import NotificationDispatcher


scan_result = {
    "lint_pass": True,
    "syntax_pass": True,
    "i18n_pass": True,
    "hardcode_flags": [],
    "sensitive_keywords": ["password="],
    "pii_detected": True,
}

with tempfile.TemporaryDirectory() as tmp:
    sent = []
    dispatcher = NotificationDispatcher(Path(tmp), sender=sent.append)

    silent = dispatcher.send("silent", scan_result)
    assert silent["sent"] is False, silent
    assert len(sent) == 0, sent

    compact = dispatcher.send("compact", scan_result)
    assert compact["sent"] is True, compact
    assert len(sent) == 1, sent
    assert len(sent[-1]) <= 200, sent[-1]

    verbose = dispatcher.send("verbose", scan_result)
    assert verbose["sent"] is True, verbose
    assert len(sent) == 2, sent
    assert json.dumps(scan_result, sort_keys=True) in sent[-1], sent[-1]

    log_path = Path(tmp) / "logs/notifications.jsonl"
    rows = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert rows[0]["level"] == "silent", rows
    assert rows[0]["sent"] is False, rows
PY

test_done
