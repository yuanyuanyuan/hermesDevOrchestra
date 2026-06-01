#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="blocker-validator"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

set +e
OUTPUT="$(python3 "$REPO_ROOT/scripts/lib/blocker_validator.py" --test-missing-field intent_summary 2>&1)"
STATUS=$?
set -e

[ "$STATUS" -eq 1 ] || fail "missing field should block" "exit code 1" "$OUTPUT"

python3 - "$OUTPUT" "$REPO_ROOT" <<'PY'
import json
import sys
from pathlib import Path

output = json.loads(sys.argv[1])
repo_root = Path(sys.argv[2])
sys.path.insert(0, str(repo_root / "scripts" / "lib"))

from blocker_validator import validate
from gateway_intake import normalize
from gateway_projection import project

assert output["status"] == "blocked", output
assert output["missing_fields"] == ["intent_summary"], output

payload = {
    "idempotency_key": "validator-pass",
    "ticket": {
        "title": "Fix flaky login",
        "goal": "Stabilize login retries",
        "acceptance_criteria": ["Login retry test passes"],
        "hard_constraints": ["Stay within auth module"],
        "failure_strategy": "Block if tests fail",
    },
}
bundle = project(
    normalize(payload, expected_intent_type="create_run"),
    {
        "project_id": "validator-pass",
        "request_type": "create_run",
        "run_id": "run-validator-pass",
        "timestamp": "2026-06-01T00:00:00Z",
    },
)["requirement_completion_bundle"]
assert validate(bundle)["status"] == "passed"
print("PASS blocker validator")
PY

test_done
