#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="auto-merge-security"
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

from auto_merge_controller import AutoMergeController, MergeRejectedError
from evidence_scanner import EvidenceScanner
from security_gate import SecurityGate


with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    config_dir = tmp_repo / "config/performance"
    config_dir.mkdir(parents=True)
    policy = json.loads((repo / "config/performance/slo-policy.json").read_text(encoding="utf-8"))
    (config_dir / "slo-policy.json").write_text(json.dumps(policy, indent=2), encoding="utf-8")

    controller = AutoMergeController(tmp_repo)
    try:
        controller.merge(
            target_branch="main",
            pr_number=42,
            audit_context={"auto_merge": True, "reviews": 1, "ci_pass": True},
        )
    except MergeRejectedError as exc:
        assert "target branch main is protected" in exc.message, exc.message
    else:
        raise AssertionError("expected main branch merge rejection")

    scan = EvidenceScanner().scan("+ password=secret123\n+ email = 'user@example.com'\n", ["settings.py"])
    verdict = SecurityGate().evaluate(scan)
    try:
        controller.merge(
            target_branch="staging",
            pr_number=43,
            audit_context={
                "auto_merge": True,
                "reviews": 1,
                "ci_pass": True,
                "scan_result": scan,
                "gate_verdict": verdict,
            },
        )
    except MergeRejectedError as exc:
        assert exc.code == "auto_merge_blocked", exc.code
        assert exc.message == "pii_detected", exc.message
    else:
        raise AssertionError("expected PII auto_merge rejection")

    audit_path = tmp_repo / "logs/auto-merge-audit.jsonl"
    rows = [json.loads(line) for line in audit_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert rows[-1]["action"] == "auto_merge_blocked", rows[-1]
    assert rows[-1]["reason"] == "pii_detected", rows[-1]
    assert rows[-1]["original_target_branch"] == "staging", rows[-1]

    receipt = controller.merge(
        target_branch="staging",
        pr_number=44,
        audit_context={"auto_merge": True, "reviews": 1, "ci_pass": True},
    )
    assert receipt["status"] == "merged", receipt
    assert receipt["target_branch"] == "staging", receipt
PY

test_done
