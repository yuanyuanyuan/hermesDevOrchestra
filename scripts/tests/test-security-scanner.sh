#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="security-scanner"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from security_scanner import DENYLIST, SecurityScanner

assert len(DENYLIST) >= 20, DENYLIST
scanner = SecurityScanner(repo)
for payload, expected in [
    ("rm -rf /tmp/example", "rm -rf"),
    ("DROP TABLE users", "DROP TABLE"),
    ("eval(request.body)", "eval("),
]:
    report = scanner.scan(payload, team_id="scanner_test")
    assert report["status"] == "blocked", report
    assert expected in report["blocked_keywords"], report
PY

assert_file_exists "$REPO_ROOT/logs/security-scan.jsonl" "security scan log missing"
assert_jsonl_valid "$REPO_ROOT/logs/security-scan.jsonl"
python3 - "$REPO_ROOT/logs/security-scan.jsonl" <<'PY'
import json
import sys
from datetime import datetime

entries = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
entry = entries[-1]
for field in ["team_id", "prompt_hash", "scan_result", "blocked_keywords", "timestamp"]:
    assert field in entry, entry
datetime.fromisoformat(entry["timestamp"])
PY

test_done
