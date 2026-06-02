#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="sensitive-keyword-pii"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from evidence_scanner import EvidenceScanner
from security_gate import SecurityGate


diff = """
+ password=secret123
+ owner_email = "owner@example.com"
+ # TODO: remove before prod
"""
scan = EvidenceScanner().scan(diff, ["settings.py"])
assert scan["sensitive_keywords"] == ["password="], scan
assert scan["pii_detected"] is True, scan
assert scan["compliance_keywords"] == ["TODO: remove before prod"], scan

verdict = SecurityGate().evaluate(scan)
assert verdict["verdict"] == "block", verdict
assert verdict["security_pass"] is False, verdict
assert verdict["block_reason"] == "pii_detected", verdict
PY

test_done
