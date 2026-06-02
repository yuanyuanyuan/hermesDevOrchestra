#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-ticket-schema"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat >"$TMP_DIR/test-ticket.json" <<'JSON'
{
  "project_background": "Existing Hermes direction debate.",
  "goal": "Decide whether the direction is worth doing.",
  "non_goal": "Do not choose implementation details.",
  "constraints": [{"id": "no_gateway_growth", "type": "hard", "text": "Gateway growth is limited."}],
  "acceptance_criteria": ["All Sprint 5 checks pass."],
  "risk_boundary": "No hard constraint may be overridden.",
  "failure_strategy": "Block and request review."
}
JSON

VALID_OUTPUT="$(python3 "$REPO_ROOT/scripts/lib/debate_ticket_generator.py" --validate "$TMP_DIR/test-ticket.json")"
for field in project_background goal non_goal constraints acceptance_criteria risk_boundary failure_strategy; do
    grep -Fq "$field" <<<"$VALID_OUTPUT" || fail "valid ticket output did not include field" "$field" "$VALID_OUTPUT"
done

python3 - "$TMP_DIR/test-ticket.json" "$TMP_DIR/missing.json" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
data = json.loads(source.read_text(encoding="utf-8"))
data.pop("failure_strategy")
target.write_text(json.dumps(data), encoding="utf-8")
PY

set +e
MISSING_OUTPUT="$(python3 "$REPO_ROOT/scripts/lib/debate_ticket_generator.py" --validate "$TMP_DIR/missing.json" 2>&1)"
MISSING_STATUS="$?"
set -e
assert_exit_code "1" "$MISSING_STATUS" "missing failure_strategy should fail"
grep -Fq "failure_strategy" <<<"$MISSING_OUTPUT" || fail "missing field was not reported" "failure_strategy" "$MISSING_OUTPUT"

test_done
