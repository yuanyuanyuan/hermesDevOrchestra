#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="role-engine-protocol"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

ROOT="$REPO_ROOT/docs/orchestra/hermes/role-engine-protocol/v1"

assert_file_exists "$ROOT/common-envelope.md" "common envelope missing"
assert_file_exists "$ROOT/roles/pm.md" "pm contract missing"
assert_file_exists "$ROOT/roles/implementer.md" "implementer contract missing"
assert_file_exists "$ROOT/roles/reviewer.md" "reviewer contract missing"

assert_contains "summary + recent N raw turns" "$ROOT/common-envelope.md" "compaction rule missing"
assert_contains "Comments are audit-only" "$ROOT/common-envelope.md" "audit-only comment rule missing"
assert_contains "question" "$ROOT/roles/pm.md" "pm status docs missing"
assert_contains "task_complete" "$ROOT/roles/implementer.md" "implementer status docs missing"
assert_contains "findings" "$ROOT/roles/reviewer.md" "reviewer status docs missing"

python3 - "$ROOT" <<'PY'
import json
import os
import sys

root = sys.argv[1]


def load(name):
    path = os.path.join(root, "examples", name)
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


shared_next_actions = {
    "continue",
    "wait_for_user",
    "create_tasks",
    "create_research_task",
    "block",
    "complete",
    "defer_to_human",
}


def check_history(history):
    assert isinstance(history, dict)
    assert "summary" in history
    assert "recent_turns" in history
    assert isinstance(history["recent_turns"], list)
    for turn in history["recent_turns"]:
        assert {"turn", "role", "content", "decision_tags"} <= set(turn)


pm_request = load("pm.request.json")
assert pm_request["protocol"] == "hermes-role-engine/v1"
assert pm_request["role"] == "pm"
for field in (
    "task_type",
    "correlation_id",
    "turn",
    "project_workspace",
    "task_id",
    "task_body",
    "task_summary",
    "current_stage",
    "conversation_history",
    "handoff_from_parent",
    "last_engine_error",
    "rollback_count",
    "instructions",
):
    assert field in pm_request
check_history(pm_request["conversation_history"])

pm_response = load("pm.response.question.json")
assert pm_response["status"] == "question"
assert pm_response["next_action"] == "wait_for_user"
assert pm_response["next_action"] in shared_next_actions
question = pm_response["role_specific_payload"]["question"]
assert question["recommended_option"] == "device_bound"
assert len(question["options"]) >= 2

implementer_request = load("implementer.request.json")
assert implementer_request["role"] == "implementer"
assert implementer_request["current_stage"] == "implementation"
check_history(implementer_request["conversation_history"])
handoff = implementer_request["handoff_from_parent"]
assert isinstance(handoff["artifact_refs"], list)
assert handoff["artifact_refs"]

implementer_response = load("implementer.response.complete.json")
assert implementer_response["status"] == "task_complete"
assert implementer_response["next_action"] == "complete"
assert implementer_response["next_action"] in shared_next_actions
verification = implementer_response["role_specific_payload"]["verification"]
assert verification["outcome"] == "passed"
assert verification["commands"]

reviewer_request = load("reviewer.request.json")
assert reviewer_request["role"] == "reviewer"
assert reviewer_request["instructions"]["review_scope"]["changed_files"]
check_history(reviewer_request["conversation_history"])

reviewer_response = load("reviewer.response.findings.json")
assert reviewer_response["status"] == "findings"
assert reviewer_response["next_action"] == "block"
assert reviewer_response["next_action"] in shared_next_actions
findings = reviewer_response["role_specific_payload"]["findings"]
assert findings
for finding in findings:
    assert {"severity", "path", "line", "issue", "recommended_fix"} <= set(finding)
PY

test_done
