#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="schema-doc-sync"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

"$REPO_ROOT/scripts/bin/orch-schema-doc-sync" --repo "$REPO_ROOT" >/dev/null

DOC_MUTATION="$TMP_DIR/schema-extra-field.md"
cp "$REPO_ROOT/docs/sprints/prd-by-kimi-user-flow-strict/schema.md" "$DOC_MUTATION"
python3 - "$DOC_MUTATION" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = "| `metric_id` | string | 必填，对应 PRD §11 指标 |\n"
replacement = needle + "| `undocumented_runtime_field` | string | negative test only |\n"
path.write_text(text.replace(needle, replacement, 1), encoding="utf-8")
PY

set +e
MISSING_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-schema-doc-sync" --repo "$REPO_ROOT" --schema-doc "$DOC_MUTATION" 2>&1)"
MISSING_STATUS="$?"
set -e
[ "$MISSING_STATUS" -ne 0 ] || fail "doc-only field should fail schema sync" "non-zero" "$MISSING_STATUS"
grep -Fq "missing field in schema: success_metrics_summary.undocumented_runtime_field" <<<"$MISSING_OUTPUT" || fail "missing field was not reported" "success_metrics_summary.undocumented_runtime_field" "$MISSING_OUTPUT"

GATEWAY_MUTATION="$TMP_DIR/orch_gateway.py"
cp "$REPO_ROOT/scripts/lib/orch_gateway.py" "$GATEWAY_MUTATION"
printf '\nLEGACY_FIELD_FOR_NEGATIVE_TEST = "legacy_run_status"\n' >> "$GATEWAY_MUTATION"

set +e
DRIFT_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-schema-doc-sync" --repo "$REPO_ROOT" --gateway "$GATEWAY_MUTATION" 2>&1)"
DRIFT_STATUS="$?"
set -e
[ "$DRIFT_STATUS" -ne 0 ] || fail "legacy hardcoded field should fail schema sync" "non-zero" "$DRIFT_STATUS"
grep -Fq "implementation drift: legacy_run_status" <<<"$DRIFT_OUTPUT" || fail "implementation drift was not reported" "legacy_run_status" "$DRIFT_OUTPUT"

test_done
