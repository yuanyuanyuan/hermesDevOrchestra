#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="evidence-missing-blocks"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from evidence_gate import EvidenceGateError, validate_completion_evidence


def expect(code, payload):
    try:
        validate_completion_evidence(payload, artifact_refs={"state://runs/r/artifacts/test.json"})
    except EvidenceGateError as exc:
        assert exc.code == code, (exc.code, code, exc.violations)
        return
    raise AssertionError(f"expected {code}")


valid = {
    "test_evidence": {"exit_code": 0, "stdout_summary": "passed", "coverage": None},
    "review_evidence": {"reviewer_id": "claude", "conclusion": "approve", "blockers": [], "warnings": ["minor"]},
    "commit_evidence": {"commit_hash": "abc123", "diff_stat": "1 file changed", "issue": "U8"},
    "evidence_refs": ["state://runs/r/artifacts/test.json"],
    "artifacts": [{"ref": "state://runs/r/artifacts/test.json"}],
}
assert validate_completion_evidence(valid)["result"] == "passed"

missing_test = dict(valid)
missing_test.pop("test_evidence")
expect("evidence_missing", missing_test)

missing_review = dict(valid)
missing_review.pop("review_evidence")
expect("evidence_missing", missing_review)

failed_test = {**valid, "test_evidence": {"exit_code": 1, "stdout_summary": "failed"}}
expect("test_failure", failed_test)

blocked = {**valid, "review_evidence": {"reviewer_id": "claude", "conclusion": "changes", "blockers": ["bug"], "warnings": []}}
expect("review_blockers_unresolved", blocked)

bad_ref = {**valid, "evidence_refs": ["state://runs/r/missing.json"], "artifacts": []}
expect("evidence_ref_unresolvable", bad_ref)
PY

test_done
