#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-alias-mapping"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

assert_file_exists "$REPO_ROOT/config/debate/full/alias-mapping.json" "alias mapping missing"

MAPPING_COUNT="$(jq '.mappings | length' "$REPO_ROOT/config/debate/full/alias-mapping.json")"
[ "$MAPPING_COUNT" -ge 3 ] || fail "alias mapping count too low" ">= 3" "$MAPPING_COUNT"

python3 - "$REPO_ROOT/config/debate/full/alias-mapping.json" <<'PY'
import json
import sys
from datetime import date

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["artifact_type"] == "debate_alias_mapping", data
for entry in data["mappings"]:
    assert isinstance(entry["alias"], str) and entry["alias"], entry
    assert isinstance(entry["canonical_team"], str) and entry["canonical_team"], entry
    if entry["deprecated_since"] is not None:
        date.fromisoformat(entry["deprecated_since"])
    assert "migration_note" in entry, entry
PY

test_done
