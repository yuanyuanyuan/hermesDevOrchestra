#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-conflict-ledger-closeout"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

HERMES_CALL_LOG="$TMP_DIR/hermes-calls.log"
export HERMES_CALL_LOG

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "create" ]; then
  printf '{"id":"kanban-%s","status":"created"}\n' "$(wc -l < "$HERMES_CALL_LOG" | tr -d ' ')"
  exit 0
fi
if [ "${1:-}" = "kanban" ] && [ "${2:-}" = "complete" ]; then
  printf '{"status":"completed"}\n'
  exit 0
fi
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

# ========================================================================
# Test 1: Closeout blocked on open high conflict
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" "$AUDIT_ROOT" <<'PY'
import json
import pathlib
import sys

repo_root, state_root, audit_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import (
    load_conflict_ledger,
    append_conflict,
    query_open_high_conflicts,
    query_unjustified_accepted_risk,
    resolve_conflict,
    closeout_conflict_blockers,
    validate_conflict_record,
    FULL_SCHEMA_VERSION,
)

# --- Test: validate_conflict_record rejects missing conflict_id ---
violations = validate_conflict_record({"run_id": "r1", "severity": "high", "resolution": "open", "created_at": "2026-01-01T00:00:00Z"})
assert len(violations) > 0, "should have violations"
assert any("conflict_id" in v for v in violations), violations

# --- Test: validate_conflict_record rejects bad severity ---
violations = validate_conflict_record({"conflict_id": "c1", "run_id": "r1", "severity": "critical", "resolution": "open", "created_at": "2026-01-01T00:00:00Z"})
assert any("severity" in v for v in violations), violations

# --- Test: validate_conflict_record rejects bad resolution ---
violations = validate_conflict_record({"conflict_id": "c1", "run_id": "r1", "severity": "high", "resolution": "resolved", "created_at": "2026-01-01T00:00:00Z"})
assert any("resolution" in v for v in violations), violations

# --- Test: append_conflict and query ---
tmp = pathlib.Path(state_root) / "test-closeout" / "runs" / "run-1"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

conflict = {
    "conflict_id": "conflict-high-open",
    "run_id": "run-1",
    "stage": "direction_debate",
    "type": "cross_team_conflict",
    "sources": [],
    "severity": "high",
    "resolution": "open",
    "resolver": "",
    "resolution_evidence": "",
    "created_at": "2026-06-04T00:00:00Z",
    "resolved_at": None,
}
ledger = append_conflict(ledger_path, conflict)
assert len(ledger["conflicts"]) == 1
assert ledger["schema_version"] == FULL_SCHEMA_VERSION

# --- Test: query_open_high_conflicts ---
open_high = query_open_high_conflicts(ledger)
assert len(open_high) == 1
assert open_high[0]["conflict_id"] == "conflict-high-open"

# --- Test: closeout_conflict_blockers blocks on open high ---
blockers = closeout_conflict_blockers(ledger)
assert len(blockers) == 1
assert "open_conflict:conflict-high-open" in blockers[0], blockers

# --- Test: resolve_conflict with auto_resolved ---
ledger = resolve_conflict(ledger_path, "conflict-high-open", "auto_resolved", resolver="system", resolution_evidence="auto-detected and merged")
open_high = query_open_high_conflicts(ledger)
assert len(open_high) == 0, open_high

# --- Test: closeout_conflict_blockers passes after resolution ---
blockers = closeout_conflict_blockers(ledger)
assert len(blockers) == 0, blockers

print("Test 1 PASSED: closeout blocks on open high, passes after resolution")
PY

# ========================================================================
# Test 2: Closeout blocked on unjustified accepted_risk
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" "$AUDIT_ROOT" <<'PY'
import json
import pathlib
import sys

repo_root, state_root, audit_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import (
    load_conflict_ledger,
    query_unjustified_accepted_risk,
    closeout_conflict_blockers,
    resolve_conflict,
    FULL_SCHEMA_VERSION,
)

tmp = pathlib.Path(state_root) / "test-accepted-risk" / "runs" / "run-2"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

# Write an accepted_risk conflict without resolver/evidence directly to simulate
# an imported/corrupted ledger that bypasses append_conflict validation.
ledger = {
    "schema_version": FULL_SCHEMA_VERSION,
    "artifact_type": "conflict_ledger",
    "run_id": "run-2",
    "conflicts": [
        {
            "conflict_id": "conflict-accepted-no-resolver",
            "run_id": "run-2",
            "stage": "direction_debate",
            "type": "cross_team_conflict",
            "sources": [],
            "severity": "high",
            "resolution": "accepted_risk",
            "resolver": "",
            "resolution_evidence": "",
            "created_at": "2026-06-04T00:00:00Z",
            "resolved_at": "2026-06-04T00:01:00Z",
        }
    ],
}
ledger_path.write_text(json.dumps(ledger, indent=2, ensure_ascii=False), encoding="utf-8")
ledger = load_conflict_ledger(ledger_path)

# --- Test: query_unjustified_accepted_risk finds it ---
unjustified = query_unjustified_accepted_risk(ledger)
assert len(unjustified) == 1
assert unjustified[0]["conflict_id"] == "conflict-accepted-no-resolver"

# --- Test: closeout_conflict_blockers blocks (both unjustified and missing evidence) ---
blockers = closeout_conflict_blockers(ledger)
assert any("unjustified_accepted_risk" in b for b in blockers), blockers
assert any("missing_resolution_evidence" in b for b in blockers), blockers

# --- Test: resolve with proper evidence unblocks ---
ledger = resolve_conflict(ledger_path, "conflict-accepted-no-resolver", "accepted_risk", resolver="human-approver", resolution_evidence="risk-assessment-approved-2026-06-04")
blockers = closeout_conflict_blockers(ledger)
assert len(blockers) == 0, blockers

print("Test 2 PASSED: unjustified accepted_risk blocks, justified passes")
PY

# ========================================================================
# Test 3: Closeout passes with empty conflict ledger
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" "$AUDIT_ROOT" <<'PY'
import pathlib
import sys

repo_root, state_root, audit_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import load_conflict_ledger, closeout_conflict_blockers

# Non-existent ledger
fake_path = pathlib.Path("/tmp/nonexistent-conflict-ledger.json")
ledger = load_conflict_ledger(fake_path)
assert ledger["conflicts"] == []
blockers = closeout_conflict_blockers(ledger)
assert len(blockers) == 0

print("Test 3 PASSED: empty/missing ledger has no blockers")
PY

# ========================================================================
# Test 4: closeout_audit_checklist includes conflict_ledger check
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" "$AUDIT_ROOT" <<'PY'
import json
import pathlib
import sys

repo_root, state_root, audit_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import closeout_audit_checklist, append_conflict

tmp = pathlib.Path(state_root) / "test-checklist" / "runs" / "run-3"
(tmp / "worker-sessions").mkdir(parents=True, exist_ok=True)
audit_path = pathlib.Path(audit_root) / "test-checklist" / "audit.jsonl"
audit_path.parent.mkdir(parents=True, exist_ok=True)
audit_path.write_text("", encoding="utf-8")

# Write a minimal run.json
(tmp / "run.json").write_text(json.dumps({"intake_package": {"a": 1, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6, "g": 7, "h": 8}}), encoding="utf-8")

# Write empty events
(tmp / "events.jsonl").write_text("", encoding="utf-8")

closeout_report = {"schema_version": "orchestra.v1", "run_id": "run-3", "closeout_summary": {}, "metrics_summary": {}, "final_acceptance": {}, "completion_gate": {}}
proposals = {"proposals": []}

# Add an open high conflict
conflict = {
    "conflict_id": "c1",
    "run_id": "run-3",
    "stage": "direction_debate",
    "type": "intent_vs_inference",
    "sources": [],
    "severity": "high",
    "resolution": "open",
    "resolver": "",
    "resolution_evidence": "",
    "created_at": "2026-06-04T00:00:00Z",
    "resolved_at": None,
}
append_conflict(tmp / "conflict-ledger.json", conflict)

result = closeout_audit_checklist(tmp, audit_path, closeout_report, proposals)

# Find the conflict_ledger check
cl_check = next(c for c in result["checks"] if c["id"] == "conflict_ledger")
assert cl_check["exists"], "conflict ledger should exist"
assert not cl_check["passed"], "should fail with open high conflict"
assert len(cl_check["blockers"]) > 0, "should have blockers"

print("Test 4 PASSED: closeout_audit_checklist includes conflict_ledger check")
PY

# ========================================================================
# Test 5: Schema root dispatch validates conflict ledger
# ========================================================================
python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys

repo_root = sys.argv[1]
schema_path = pathlib.Path(repo_root) / "config" / "schemas" / "orchestra.full.schema.json"
schema = json.loads(schema_path.read_text(encoding="utf-8"))

import jsonschema
validator = jsonschema.Draft202012Validator(schema)

# Valid conflict ledger should pass
valid = {"artifact_type": "conflict_ledger", "schema_version": "orchestra.full.v1", "run_id": "r1", "conflicts": []}
errors = list(validator.iter_errors(valid))
assert len(errors) == 0, f"valid ledger should pass: {errors}"

# Malformed ledger missing run_id should fail
bad = {"artifact_type": "conflict_ledger", "schema_version": "orchestra.full.v1", "conflicts": []}
errors = list(validator.iter_errors(bad))
assert any("run_id" in str(e.validator_value) or "required" in e.validator for e in errors), f"missing run_id should fail: {errors}"

# Invalid conflict record should fail
bad_record = {"artifact_type": "conflict_ledger", "schema_version": "orchestra.full.v1", "run_id": "r1", "conflicts": [{"bad": True}]}
errors = list(validator.iter_errors(bad_record))
assert len(errors) > 0, "invalid record should fail"

print("Test 5 PASSED: schema root dispatches and rejects malformed conflict ledgers")
PY

# ========================================================================
# Test 6: append_conflict populates run_id on empty ledger
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" <<'PY'
import pathlib
import sys

repo_root, state_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import append_conflict, load_conflict_ledger

tmp = pathlib.Path(state_root) / "test-runid" / "runs" / "run-6"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

conflict = {
    "conflict_id": "c-runid",
    "run_id": "run-6",
    "stage": "direction_debate",
    "type": "intent_vs_inference",
    "sources": [],
    "severity": "medium",
    "resolution": "open",
    "resolver": "",
    "resolution_evidence": "",
    "created_at": "2026-06-04T00:00:00Z",
    "resolved_at": None,
}
ledger = append_conflict(ledger_path, conflict)
assert ledger["run_id"] == "run-6", f"run_id should be populated from conflict: {ledger['run_id']}"

# Reload and verify
reloaded = load_conflict_ledger(ledger_path)
assert reloaded["run_id"] == "run-6", f"persisted run_id mismatch: {reloaded['run_id']}"

print("Test 6 PASSED: append_conflict populates run_id")
PY

# ========================================================================
# Test 7: conflict_counts and enrich_closeout_report_conflict_counts
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" <<'PY'
import pathlib
import sys

repo_root, state_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import (
    append_conflict,
    conflict_counts,
    enrich_closeout_report_conflict_counts,
    load_conflict_ledger,
)

tmp = pathlib.Path(state_root) / "test-counts" / "runs" / "run-7"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

append_conflict(ledger_path, {"conflict_id": "c1", "run_id": "run-7", "stage": "direction_debate", "type": "intent_vs_inference", "sources": [], "severity": "high", "resolution": "open", "resolver": "", "resolution_evidence": "", "created_at": "2026-06-04T00:00:00Z", "resolved_at": None})
append_conflict(ledger_path, {"conflict_id": "c2", "run_id": "run-7", "stage": "direction_debate", "type": "intent_vs_inference", "sources": [], "severity": "medium", "resolution": "open", "resolver": "", "resolution_evidence": "", "created_at": "2026-06-04T00:00:00Z", "resolved_at": None})
append_conflict(ledger_path, {"conflict_id": "c3", "run_id": "run-7", "stage": "direction_debate", "type": "intent_vs_inference", "sources": [], "severity": "high", "resolution": "auto_resolved", "resolver": "", "resolution_evidence": "auto-detected-and-merged", "created_at": "2026-06-04T00:00:00Z", "resolved_at": None})

ledger = load_conflict_ledger(ledger_path)
counts = conflict_counts(ledger)
assert counts["total"] == 3
assert counts["by_severity"]["high"] == 2
assert counts["by_severity"]["medium"] == 1
assert counts["by_resolution"]["open"] == 2
assert counts["by_resolution"]["auto_resolved"] == 1

closeout_report = {}
enriched = enrich_closeout_report_conflict_counts(closeout_report, ledger)
assert enriched["conflict_counts"]["total"] == 3
assert enriched["conflict_counts"]["by_severity"]["high"] == 2

print("Test 7 PASSED: conflict_counts and enrichment work correctly")
PY

# ========================================================================}
# Test 8: Schema dispatch does not affect objects without artifact_type}
# ========================================================================}
python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys

repo_root = sys.argv[1]
schema_path = pathlib.Path(repo_root) / "config" / "schemas" / "orchestra.full.schema.json"
schema = json.loads(schema_path.read_text(encoding="utf-8"))

import jsonschema
validator = jsonschema.Draft202012Validator(schema)

# Object without artifact_type should pass as generic object
doc = {"schema_version": "orchestra.full.v1", "run_id": "r1", "some_field": "value"}
errors = list(validator.iter_errors(doc))
assert len(errors) == 0, f"object without artifact_type should pass: {errors}"

print("Test 8 PASSED: schema dispatch guarded by required artifact_type")
PY

# ========================================================================}
# Test 9: Unreadable conflict ledger blocks closeout}
# ========================================================================}
python3 - "$REPO_ROOT" "$STATE_ROOT" <<'PY'
import pathlib
import sys

repo_root, state_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import closeout_audit_checklist

tmp = pathlib.Path(state_root) / "test-unreadable" / "runs" / "run-9"
(tmp / "worker-sessions").mkdir(parents=True, exist_ok=True)
audit_path = pathlib.Path(state_root) / "test-unreadable" / "audit.jsonl"
audit_path.parent.mkdir(parents=True, exist_ok=True)
audit_path.write_text("", encoding="utf-8")

(tmp / "run.json").write_text('{"intake_package": {"a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8}}', encoding="utf-8")
(tmp / "events.jsonl").write_text("", encoding="utf-8")

# Write corrupted conflict ledger
(tmp / "conflict-ledger.json").write_text("this is not json{!", encoding="utf-8")

closeout_report = {"schema_version": "orchestra.v1", "run_id": "run-9", "closeout_summary": {}, "metrics_summary": {}, "final_acceptance": {}, "completion_gate": {}}
proposals = {"proposals": []}

result = closeout_audit_checklist(tmp, audit_path, closeout_report, proposals)
cl_check = next(c for c in result["checks"] if c["id"] == "conflict_ledger")
assert cl_check["exists"], "conflict ledger should exist"
assert not cl_check["passed"], "should fail with unreadable ledger"
assert any("unreadable_conflict_ledger" in b for b in cl_check["blockers"]), cl_check["blockers"]

print("Test 9 PASSED: unreadable conflict ledger blocks closeout")
PY

# ========================================================================}
# Test 10: validate_conflict_record rejects missing stage and type}
# ========================================================================}
python3 - "$REPO_ROOT" <<'PY'
import pathlib
import sys

repo_root = sys.argv[1]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import validate_conflict_record

# Missing stage
violations = validate_conflict_record({
    "conflict_id": "c1", "run_id": "r1", "severity": "high",
    "resolution": "open", "created_at": "2026-01-01T00:00:00Z",
    "sources": [], "resolver": "", "resolution_evidence": "", "resolved_at": None,
})
assert any("stage" in v for v in violations), violations

# Missing type
violations = validate_conflict_record({
    "conflict_id": "c1", "run_id": "r1", "stage": "direction_debate",
    "severity": "high", "resolution": "open", "created_at": "2026-01-01T00:00:00Z",
    "sources": [], "resolver": "", "resolution_evidence": "", "resolved_at": None,
})
assert any("type" in v for v in violations), violations

# Valid record passes
violations = validate_conflict_record({
    "conflict_id": "c1", "run_id": "r1", "stage": "direction_debate", "type": "intent_vs_inference",
    "severity": "high", "resolution": "open", "created_at": "2026-01-01T00:00:00Z",
    "sources": [], "resolver": "", "resolution_evidence": "", "resolved_at": None,
})
assert len(violations) == 0, violations

print("Test 10 PASSED: validate_conflict_record checks stage and type")
PY

# ========================================================================
# Test 11: All open severities block closeout (not just high)
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" <<'PY'
import pathlib
import sys

repo_root, state_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import append_conflict, closeout_conflict_blockers, resolve_conflict, load_conflict_ledger

tmp = pathlib.Path(state_root) / "test-all-open" / "runs" / "run-11"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

# Append a medium severity open conflict
append_conflict(ledger_path, {
    "conflict_id": "c-medium-open",
    "run_id": "run-11",
    "stage": "direction_debate",
    "type": "intent_vs_inference",
    "sources": [],
    "severity": "medium",
    "resolution": "open",
    "resolver": "",
    "resolution_evidence": "",
    "created_at": "2026-06-04T00:00:00Z",
    "resolved_at": None,
})

# Append a low severity open conflict
append_conflict(ledger_path, {
    "conflict_id": "c-low-open",
    "run_id": "run-11",
    "stage": "direction_debate",
    "type": "intent_vs_inference",
    "sources": [],
    "severity": "low",
    "resolution": "open",
    "resolver": "",
    "resolution_evidence": "",
    "created_at": "2026-06-04T00:00:00Z",
    "resolved_at": None,
})

blockers = closeout_conflict_blockers(load_conflict_ledger(ledger_path))
assert any("open_conflict:c-medium-open" in b for b in blockers), blockers
assert any("open_conflict:c-low-open" in b for b in blockers), blockers

# Resolve both
resolve_conflict(ledger_path, "c-medium-open", "auto_resolved", resolver="system", resolution_evidence="merged")
resolve_conflict(ledger_path, "c-low-open", "auto_resolved", resolver="system", resolution_evidence="merged")

blockers = closeout_conflict_blockers(load_conflict_ledger(ledger_path))
assert len(blockers) == 0, blockers

print("Test 11 PASSED: all open severities block closeout, resolved passes")
PY

# ========================================================================
# Test 12: append_conflict rejects non-array conflicts ledger
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" <<'PY'
import json
import pathlib
import sys

repo_root, state_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import append_conflict

tmp = pathlib.Path(state_root) / "test-nonarray" / "runs" / "run-12"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

# Write ledger with conflicts as a string (corrupt)
ledger_path.write_text(json.dumps({"schema_version": "orchestra.full.v1", "artifact_type": "conflict_ledger", "run_id": "run-12", "conflicts": "not-an-array"}, indent=2, ensure_ascii=False), encoding="utf-8")

try:
    append_conflict(ledger_path, {"conflict_id": "c1", "run_id": "run-12", "stage": "direction_debate", "type": "intent_vs_inference", "sources": [], "severity": "high", "resolution": "open", "resolver": "", "resolution_evidence": "", "created_at": "2026-06-04T00:00:00Z", "resolved_at": None})
    assert False, "should have raised ValueError for non-array conflicts"
except ValueError as e:
    assert "conflicts is not a list" in str(e), e

print("Test 12 PASSED: append_conflict rejects non-array conflicts ledger")
PY

# ========================================================================
# Test 13: closeout blocks schema-invalid ledger
# ========================================================================
python3 - "$REPO_ROOT" "$STATE_ROOT" <<'PY'
import json
import pathlib
import sys

repo_root, state_root = sys.argv[1:]
sys.path.insert(0, str(pathlib.Path(repo_root) / "scripts" / "lib"))

from gateway_closeout import closeout_conflict_blockers, load_conflict_ledger, FULL_SCHEMA_VERSION

tmp = pathlib.Path(state_root) / "test-schema-invalid" / "runs" / "run-13"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

# Write ledger with schema-invalid conflict records directly
ledger = {
    "schema_version": FULL_SCHEMA_VERSION,
    "artifact_type": "conflict_ledger",
    "run_id": "run-13",
    "conflicts": [
        {
            "conflict_id": "c-invalid-resolution",
            "run_id": "run-13",
            "stage": "direction_debate",
            "type": "intent_vs_inference",
            "sources": [],
            "severity": "high",
            "resolution": "resolved",  # invalid enum
            "resolver": "",
            "resolution_evidence": "some-evidence",
            "created_at": "2026-06-04T00:00:00Z",
            "resolved_at": None,
        },
        {
            "conflict_id": "c-invalid-severity",
            "run_id": "run-13",
            "stage": "direction_debate",
            "type": "intent_vs_inference",
            "sources": [],
            "severity": "critical",  # invalid enum
            "resolution": "open",
            "resolver": "",
            "resolution_evidence": "",
            "created_at": "2026-06-04T00:00:00Z",
            "resolved_at": None,
        },
        {
            "conflict_id": "c-missing-type",
            "run_id": "run-13",
            "stage": "direction_debate",
            # missing type
            "sources": [],
            "severity": "high",
            "resolution": "open",
            "resolver": "",
            "resolution_evidence": "",
            "created_at": "2026-06-04T00:00:00Z",
            "resolved_at": None,
        },
    ],
}
ledger_path.write_text(json.dumps(ledger, indent=2, ensure_ascii=False), encoding="utf-8")

ledger = load_conflict_ledger(ledger_path)
blockers = closeout_conflict_blockers(ledger)
assert any("schema_invalid_conflict:c-invalid-resolution" in b for b in blockers), blockers
assert any("schema_invalid_conflict:c-invalid-severity" in b for b in blockers), blockers
assert any("schema_invalid_conflict:c-missing-type" in b for b in blockers), blockers

print("Test 13 PASSED: closeout blocks schema-invalid ledger")
PY

test_done
