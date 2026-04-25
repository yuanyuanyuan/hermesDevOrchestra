---
phase: 12-risk-decisions-verification-handoff
plan: 05
subsystem: testing
tags: [fixtures, fake-cli, replay-protection, risk-decisions]
requires:
  - phase: 12-risk-decisions-verification-handoff
    provides: 12-03 smoke runner infrastructure
provides:
  - Install/probe, skills, init/start/status, and file-bus fixtures
  - Risk check, risk decision, decision CLI, and replay fixtures
affects: [verification, handoff, safety]
tech-stack:
  added: [bash-fixtures]
  patterns: [fake hermes/tmux/claude/codex PATH fixtures]
key-files:
  created:
    - docs/hermes-dev-orchestra/scripts/tests/test-install-probe.sh
    - docs/hermes-dev-orchestra/scripts/tests/test-skills-load.sh
    - docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh
    - docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh
    - docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh
    - docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh
    - docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh
    - docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh
  modified: []
key-decisions:
  - "Functional smoke coverage uses disposable HOME, fake PATH, and no live service credentials."
patterns-established:
  - "Risk decision fixtures prove under-classified Claude L2 text matching L4 rules does not resume Codex."
requirements-completed: [VER-01]
duration: 52 min
completed: 2026-04-25
---

# Phase 12 Plan 05: Functional Smoke Fixtures Summary

**Deterministic fake-CLI fixtures verify install, file-bus routing, risk blocking, local decisions, and replay protection**

## Performance

- **Duration:** 52 min
- **Started:** 2026-04-25T10:20:30Z
- **Completed:** 2026-04-25T11:12:01Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added install/probe, skills-load, init/start/status, and file-bus fixtures.
- Added risk classifier, L3/L4 risk decision, decision CLI, and replay protection fixtures.
- Verified the full pure Bash smoke suite runs without live Hermes, Claude, Codex, or remote adapter auth.

## Task Commits

- **Implementation:** `0f00861` (`feat(12-01 12-02 12-03 12-04 12-05): implement risk decisions and smoke verification`)

## Verification

- `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` passes with `Smoke summary: 9 passed, 0 failed`.
- `docs/hermes-dev-orchestra/scripts/bin/orch-verify` passes with `Smoke summary: 9 passed, 0 failed`.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

The risk-decisions fixture initially stripped `.json` incorrectly from approval IDs; fixed and reran the full suite successfully.

## Self-Check: PASSED

All fixture scripts exist, are executable, and are included in the aggregate runner.
