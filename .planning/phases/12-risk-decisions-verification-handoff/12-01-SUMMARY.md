---
phase: 12-risk-decisions-verification-handoff
plan: 01
subsystem: safety
tags: [risk-rulebook, audit, bash, jsonl]
requires:
  - phase: 11-project-bootstrap-tmux-runtime-file-bus
    provides: Runtime bus and orch helper baseline
provides:
  - Static L3/L4 risk rulebook
  - `orch-risk-check` classifier
  - Durable per-project Audit JSONL helper and viewer
affects: [risk, audit, local-decision-fallback]
tech-stack:
  added: [bash, python-json]
  patterns: [package-relative helper lookup, XDG-style audit paths]
key-files:
  created:
    - docs/hermes-dev-orchestra/config/rules.json
    - docs/hermes-dev-orchestra/scripts/bin/orch-risk-check
    - docs/hermes-dev-orchestra/scripts/bin/orch-audit
  modified:
    - docs/hermes-dev-orchestra/scripts/lib/orch-common.sh
    - docs/hermes-dev-orchestra/scripts/bin/orch-init
    - docs/hermes-dev-orchestra/scripts/bin/orch-start
    - docs/hermes-dev-orchestra/scripts/bin/orch-stop
    - docs/hermes-dev-orchestra/scripts/setup.sh
key-decisions:
  - "Audit records are durable JSONL under ~/.local/share/hermes-orchestra/{project}/audit.jsonl."
  - "Default rules install only when ~/.hermes-orchestra/rules.json is absent."
patterns-established:
  - "Risk checks return shell-friendly exit codes: 0 for L0, 2 for L3, 3 for L4."
requirements-completed: [SAFE-01]
duration: 52 min
completed: 2026-04-25
---

# Phase 12 Plan 01: Safety Rulebook & Audit Foundation Summary

**Static risk floors and durable Audit JSONL for Hermes Dev Orchestra safety decisions**

## Performance

- **Duration:** 52 min
- **Started:** 2026-04-25T10:20:30Z
- **Completed:** 2026-04-25T11:12:01Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added the five locked static risk rules with L3/L4 floors.
- Added `orch-risk-check` with package/default-rule lookup and deterministic JSON output.
- Added `orch_append_audit`, rotation, `orch-audit`, and lifecycle audit events for init/start/stop.

## Task Commits

- **Implementation:** `0f00861` (`feat(12-01 12-02 12-03 12-04 12-05): implement risk decisions and smoke verification`)

## Verification

- `orch-risk-check "npm install lodash"` exits 0 with `L0`.
- `orch-risk-check "CREATE TABLE users"` exits 2 with `rule-004`.
- `orch-risk-check "docker system prune"` exits 3 with `rule-003`.
- Audit JSONL append and `orch-audit --limit 1` parser checks pass.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

None.

## Self-Check: PASSED

All key files exist, static checks pass, and the implementation commit is present in git history.
