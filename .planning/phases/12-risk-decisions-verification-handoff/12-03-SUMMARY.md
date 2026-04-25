---
phase: 12-risk-decisions-verification-handoff
plan: 03
subsystem: testing
tags: [smoke-tests, bash, orch-verify]
requires:
  - phase: 12-risk-decisions-verification-handoff
    provides: 12-01 risk/audit and 12-02 decision commands
provides:
  - Pure Bash assertion library
  - Aggregate smoke runner
  - Public `orch-verify`
  - Documentation contract fixture
affects: [verification, handoff]
tech-stack:
  added: [bash-test-runner]
  patterns: [temp HOME fixtures, fake PATH CLIs]
key-files:
  created:
    - docs/hermes-dev-orchestra/scripts/tests/lib/assert.sh
    - docs/hermes-dev-orchestra/scripts/tests/run-all.sh
    - docs/hermes-dev-orchestra/scripts/bin/orch-verify
    - docs/hermes-dev-orchestra/scripts/tests/test-docs.sh
  modified:
    - docs/hermes-dev-orchestra/scripts/setup.sh
key-decisions:
  - "Smoke fixtures stay pure Bash and avoid live Claude/Codex authentication."
patterns-established:
  - "Installed tests live under ~/.hermes-orchestra/tests and package tests remain runnable in-tree."
requirements-completed: [VER-01]
duration: 52 min
completed: 2026-04-25
---

# Phase 12 Plan 03: Smoke Runner Infrastructure & Docs Fixture Summary

**Self-contained Bash smoke runner with public `orch-verify` and executable docs contract checks**

## Performance

- **Duration:** 52 min
- **Started:** 2026-04-25T10:20:30Z
- **Completed:** 2026-04-25T11:12:01Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added assertion helpers for equality, content, executable files, JSONL, exit codes, and fake PATH setup.
- Added `run-all.sh` with PASS/FAIL output and non-zero aggregate failure behavior.
- Added `orch-verify` and installer wiring for public smoke verification.
- Added `test-docs.sh` for README, coverage matrix, and handoff contract checks.

## Task Commits

- **Implementation:** `0f00861` (`feat(12-01 12-02 12-03 12-04 12-05): implement risk decisions and smoke verification`)

## Verification

- `bash docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` passes.
- `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` passes with 9/9 tests.
- `docs/hermes-dev-orchestra/scripts/bin/orch-verify` passes with 9/9 tests.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

None.

## Self-Check: PASSED

All runner files exist, are executable where required, and the full smoke suite passes.
