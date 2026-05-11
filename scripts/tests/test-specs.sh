#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="specs-contract"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

SPECS_DIR="$REPO_ROOT/specs"
SPEC_INDEX="$SPECS_DIR/README.md"
EXPECTED_SPECS=("commands.md" "file-bus.md" "risk-decisions.md")
REQUIRED_SECTIONS=("## Source" "## Consumers" "## Drift Check" "## Conformance Checks")

assert_file_exists "$SPEC_INDEX" "specs index missing"
assert_contains ".planning/SPEC.md" "$SPEC_INDEX" "specs index must state canonical source"

expected_inventory="$(printf '%s\n' "README.md" "${EXPECTED_SPECS[@]}" | sort)"
actual_inventory="$(find "$SPECS_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort)"
[ "$expected_inventory" = "$actual_inventory" ] || fail "unexpected specs inventory" "$expected_inventory" "$actual_inventory"

for spec in "${EXPECTED_SPECS[@]}"; do
    spec_file="$SPECS_DIR/$spec"
    assert_file_exists "$spec_file" "derived spec missing"
    for section in "${REQUIRED_SECTIONS[@]}"; do
        assert_contains "$section" "$spec_file" "derived spec missing required section"
    done
    assert_contains ".planning/SPEC.md" "$spec_file" "derived spec must cite canonical source"
    assert_contains "$spec" "$SPEC_INDEX" "spec index missing derived spec"
    assert_contains "bash scripts/tests/test-specs.sh" "$spec_file" "derived spec missing self conformance check"
done

python3 - "$REPO_ROOT" "$SPEC_INDEX" "${EXPECTED_SPECS[@]/#/$SPECS_DIR/}" <<'PY' || fail "spec metadata validation failed"
import os
import pathlib
import re
import sys

repo_root = sys.argv[1]
index_path = sys.argv[2]
spec_paths = sys.argv[3:]

with open(index_path, encoding="utf-8") as handle:
    index_text = handle.read()


def die(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def section_body(text, heading, spec_path):
    match = re.search(rf"^{re.escape(heading)}\s*$", text, re.MULTILINE)
    if not match:
        messages = {
            "## Consumers": "missing Consumers section",
            "## Drift Check": "missing Drift Check section",
            "## Conformance Checks": "missing Conformance Checks section",
        }
        die(f"{messages.get(heading, f'missing {heading} section')}: {spec_path}")
    start = match.end()
    next_match = re.search(r"^##\s+", text[start:], re.MULTILINE)
    end = start + next_match.start() if next_match else len(text)
    return text[start:end]


for spec_path in spec_paths:
    with open(spec_path, encoding="utf-8") as handle:
        text = handle.read()

    consumers = section_body(text, "## Consumers", spec_path)
    paths = re.findall(r"`([^`]+)`", consumers)
    if not paths:
        die(f"missing consumer paths: {spec_path}")

    for path in paths:
        if os.path.isabs(path):
            die(f"absolute consumer path rejected: {path}")
        if ".." in pathlib.PurePosixPath(path).parts:
            die(f"traversal consumer path rejected: {path}")
        if not os.path.exists(os.path.join(repo_root, path)):
            die(f"consumer path does not exist: {path}")
        if path not in index_text:
            die(f"consumer path missing from specs index: {path}")

    drift = section_body(text, "## Drift Check", spec_path)
    if not re.search(r"```bash\s+[\s\S]*?\S[\s\S]*?```", drift):
        die(f"missing Drift Check bash block: {spec_path}")

    conformance = section_body(text, "## Conformance Checks", spec_path)
    if "bash scripts/tests/test-specs.sh" not in conformance:
        die(f"missing Conformance Checks section entry for test-specs.sh: {spec_path}")
PY

test_done
