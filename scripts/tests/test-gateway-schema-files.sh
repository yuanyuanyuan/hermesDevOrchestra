#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-schema-files"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

SCHEMA_FILE="$REPO_ROOT/config/schemas/orchestra.schema.json"

assert_file_exists "$SCHEMA_FILE" "machine-readable Orchestra schema bundle missing"

python3 - "$SCHEMA_FILE" <<'PY'
import json
import sys

schema_path = sys.argv[1]
schema = json.load(open(schema_path, encoding="utf-8"))

assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema", schema
assert schema["title"] == "Hermes Orchestra MVP Schemas", schema
defs = schema["$defs"]

required_defs = {
    "run_create_request",
    "run_response",
    "run_status",
    "run_lineage",
    "run_failure_report",
    "event",
    "event_query_response",
    "command_record",
    "command_reconciliation_report",
    "task_projection",
    "artifact_reference",
    "structured_prd",
    "development_plan",
    "debate_report",
    "stage_report",
    "global_evaluation_report",
    "improvement_report",
    "iteration_closeout_report",
    "system_improvement_proposals",
    "test_plan",
    "test_execution_report",
    "review_or_qa_verdict",
    "worker_response",
    "state_advancing_worker_output",
    "worker_context_envelope",
    "worker_context_bundle",
    "worker_backend_registry_entry",
    "worker_role_registry_entry",
    "worker_selection_record",
    "decision_request",
    "decision_command_request",
    "decision_response",
    "stop_run_request",
    "stop_run_response",
    "capabilities_response",
}
missing = sorted(required_defs - set(defs))
assert not missing, missing

assert "idempotency_key" in defs["run_create_request"]["required"]
assert set(defs["run_response"]["properties"]["status"]["enum"]) == {"queued", "running", "blocked", "failed", "completed", "stopped"}
assert "authority_chain_corrupt" in defs["run_failure_report"]["properties"]["terminal_failure_reason"]["enum"]
assert "run_failed" in defs["event"]["properties"]["type"]["enum"]
assert "stage_completed" in defs["event"]["properties"]["type"]["enum"]
assert "structured_prd_ref" in defs["global_evaluation_report"]["required"]
assert "parallelism_policy" in defs["development_plan"]["required"]
assert "commands" in defs["test_execution_report"]["required"]
assert "context_bundle_refs" in defs["worker_context_envelope"]["required"]
assert "fallback_allowed_failure_classes" in defs["worker_role_registry_entry"]["required"]
assert "run_failure_report" in defs["run_failure_report"]["properties"]["artifact_type"]["const"]
PY

test_done
