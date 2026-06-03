#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-global-evaluation-notification-levels"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
sys.path.insert(0, str(repo_root / "scripts" / "lib"))

from gateway_evaluation import DIMENSION_NAMES, normalize_global_evaluation

run_id = "run-notification-levels"


def report(level):
    return {
        "schema_version": "orchestra.v1",
        "artifact_type": "global_evaluation_report",
        "run_id": run_id,
        "stage": "global_evaluation",
        "input_artifact_refs": [f"state://runs/{run_id}/run.json"],
        "structured_prd_ref": f"state://runs/{run_id}/structured_prd.json",
        "development_plan_ref": f"state://runs/{run_id}/development_plan.json",
        "debate_report_refs": [],
        "implementation_evidence_refs": [],
        "review_verdict_refs": [],
        "qa_verdict_refs": [],
        "test_execution_refs": [f"state://runs/{run_id}/tests.json"],
        "improvement_report_refs": [],
        "downgrade_refs": [],
        "unresolved_decision_refs": [],
        "audit_refs": [],
        "verdict": "pass_with_warnings",
        "warnings": [],
        "residual_risks": [
            {"severity": "low", "title": "Minor doc follow-up"},
            {"severity": "high", "title": "L4 rollout ambiguity"},
            {"severity": "medium", "title": "Perf sample small"},
        ],
        "blocking_issues": [],
        "authority_required": "kimi",
        "notification_level": level,
        "final_acceptance_ref": None,
        "next_actions": ["Request final acceptance"],
        "created_at": "2026-05-17T00:00:00Z",
    }


none = normalize_global_evaluation(report("none"), run_id, repo_root)
assert none["notification"]["sent"] is False, none
assert none["notification"]["body"] == "", none

summary = normalize_global_evaluation(report("summary"), run_id, repo_root)
assert summary["notification"]["sent"] is True, summary
assert "dimensions" not in summary["notification"]["body"], summary
assert summary["notification"]["body"]["risk_counts"] == {"high": 1, "medium": 1, "low": 1}, summary
assert summary["notification"]["body"]["highest_risk"] == "L4 rollout ambiguity", summary

full = normalize_global_evaluation(report("full"), run_id, repo_root)
assert full["notification"]["sent"] is True, full
assert [item["name"] for item in full["notification"]["body"]["dimensions"]] == DIMENSION_NAMES, full
assert full["notification"]["body"]["residual_risks"][0]["severity"] == "high", full
assert full["notification"]["body"]["authority_route"]["next_stage"] == "approval_required", full
PY

test_done
