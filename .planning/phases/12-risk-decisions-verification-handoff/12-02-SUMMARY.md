---
phase: 12-risk-decisions-verification-handoff
plan: 02
subsystem: decisions
tags: [approval-id, replay-protection, risk-gate, file-bus]
requires:
  - phase: 12-risk-decisions-verification-handoff
    provides: 12-01 risk rulebook and Audit JSONL
provides:
  - `orch-decisions`, `orch-approve`, and `orch-reject`
  - Pending decision state under State layer
  - L3/L4 blocking integration in `orch-bus-loop`
affects: [safe-decisions, file-bus, status]
tech-stack:
  added: [bash, python-json]
  patterns: [one-time approval IDs, fail-closed TTL validation]
key-files:
  created:
    - docs/hermes-dev-orchestra/scripts/bin/orch-decisions
    - docs/hermes-dev-orchestra/scripts/bin/orch-approve
    - docs/hermes-dev-orchestra/scripts/bin/orch-reject
  modified:
    - docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop
    - docs/hermes-dev-orchestra/scripts/bin/orch-status
    - docs/hermes-dev-orchestra/scripts/lib/orch-common.sh
    - docs/hermes-dev-orchestra/scripts/setup.sh
key-decisions:
  - "Local fallback is adapter-owned `orch-*`, not upstream `hermes` subcommands."
  - "Used, expired, project-mismatched, and task-mismatched approvals fail closed."
patterns-established:
  - "L3/L4 decisions require `author: user` plus a used matching approval record."
requirements-completed: [SAFE-02, DEC-01, DEC-02]
duration: 52 min
completed: 2026-04-25
---

# Phase 12 Plan 02: Local Decision Fallback & Blocking Integration Summary

**SSH/local approval commands with one-time approval IDs and rulebook-backed Codex blocking**

## Performance

- **Duration:** 52 min
- **Started:** 2026-04-25T10:20:30Z
- **Completed:** 2026-04-25T11:12:01Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Implemented pending decision creation, lookup, approval, rejection, and audit recording.
- Updated `orch-bus-loop` to block L3/L4 escalations and under-classified Claude decisions.
- Updated `orch-status` to print pending approval IDs with exact approve/reject command hints.

## Task Commits

- **Implementation:** `0f00861` (`feat(12-01 12-02 12-03 12-04 12-05): implement risk decisions and smoke verification`)

## Verification

- `orch-decisions` lists pending records with `ID	Project	Level	Task	Age	Status	Summary`.
- `orch-approve <approval_id>` writes a user-authored APPROVED decision envelope.
- `orch-reject <approval_id>` writes a user-authored REJECTED decision envelope.
- `test-risk-decisions.sh`, `test-decision-cli.sh`, and `test-decision-replay.sh` pass.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

One fixture assertion initially kept `.json` in the approval ID; the test was corrected and rerun successfully.

## Self-Check: PASSED

All key files exist, replay protections are exercised, and the implementation commit is present in git history.
