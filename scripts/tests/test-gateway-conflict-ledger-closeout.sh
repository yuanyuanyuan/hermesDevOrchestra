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
assert "open_high_conflict:conflict-high-open" in blockers[0], blockers

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
    append_conflict,
    query_unjustified_accepted_risk,
    closeout_conflict_blockers,
    resolve_conflict,
)

tmp = pathlib.Path(state_root) / "test-accepted-risk" / "runs" / "run-2"
tmp.mkdir(parents=True, exist_ok=True)
ledger_path = tmp / "conflict-ledger.json"

# Add accepted_risk without resolver - should block
conflict = {
    "conflict_id": "conflict-accepted-no-resolver",
    "run_id": "run-2",
    "stage": "direction_debate",
    "type": "cross_team_conflict",
    "severity": "high",
    "resolution": "accepted_risk",
    "resolver": "",
    "resolution_evidence": "",
    "created_at": "2026-06-04T00:00:00Z",
    "resolved_at": "2026-06-04T00:01:00Z",
}
ledger = append_conflict(ledger_path, conflict)

# --- Test: query_unjustified_accepted_risk finds it ---
unjustified = query_unjustified_accepted_risk(ledger)
assert len(unjustified) == 1
assert unjustified[0]["conflict_id"] == "conflict-accepted-no-resolver"

# --- Test: closeout_conflict_blockers blocks ---
blockers = closeout_conflict_blockers(ledger)
assert any("unjustified_accepted_risk" in b for b in blockers), blockers

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
    "type": "test",
    "severity": "high",
    "resolution": "open",
    "created_at": "2026-06-04T00:00:00Z",
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

test_done
