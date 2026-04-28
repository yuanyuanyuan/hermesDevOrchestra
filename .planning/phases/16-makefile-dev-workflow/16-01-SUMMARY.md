---
phase: 16-makefile-dev-workflow
plan: "01"
subsystem: tooling
tags: [makefile, smoke-tests, json-lint, shell-lint, upstream-pin]
requires:
  - phase: 15-specification-system
    provides: Canonical spec and conformance checks used by the smoke runner
provides:
  - Root Makefile with local verification entrypoints
  - Upstream repo/runtime pin status check
affects: [developer-workflow, verification, upstream-pin]
tech-stack:
  added: []
  patterns:
    - GNU Make delegates to existing Bash smoke tests
    - Python stdlib JSON parsing avoids jq dependency
key-files:
  created:
    - Makefile
  modified: []
key-decisions:
  - "Kept Phase 16 implementation to one root Makefile that delegates to existing scripts."
  - "Shell lint skips explicitly when shellcheck is absent instead of failing local verification."
patterns-established:
  - "Make targets must reference real repository scripts and avoid placeholder workflow targets."
  - "Upstream status compares repo-local manifest pin with runtime checkout only when the runtime checkout exists."
requirements-completed: [DEV-01, DEV-02, DEV-03, DEV-04]
duration: 18 min
completed: 2026-04-28
---

# Phase 16 Plan 01: Makefile & Dev Workflow Summary

**Root Makefile with smoke, risk, JSON lint, shell lint, and upstream pin status targets**

## Performance

- **Duration:** 18 min
- **Started:** 2026-04-28T12:34:00Z
- **Completed:** 2026-04-28T12:52:36Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added a root `Makefile` with `test`, `test-unit`, `test-risk`, `lint-json`, `lint-shell`, and `upstream-status`.
- Wired `test-unit` to the existing smoke runner and `test-risk` to the three required risk/approval scripts.
- Implemented JSON lint across repository `*.json` files outside `.git`.
- Implemented explicit shellcheck skip behavior when `shellcheck` is absent.
- Implemented upstream pin reporting and match/mismatch detection using `.planning/upstream/hermes-agent-pin.json` and the runtime Hermes Agent checkout.

## Task Commits

1. **Task 1: Add root Makefile for local verification** - `7b2f7de` (feat)

## Files Created/Modified

- `Makefile` - Local developer workflow targets for smoke tests, risk tests, JSON lint, shell lint, and upstream pin status.

## Decisions Made

- Kept the target surface limited to Phase 16 requirements and the aggregate `test` target.
- Used Python stdlib for JSON/pin parsing so the workflow does not depend on `jq`.
- Treated a missing runtime Hermes checkout as report-only and a mismatched runtime checkout as failure.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope changes.

## Issues Encountered

None.

## Verification

- `make test-unit` passed with `Smoke summary: 10 passed, 0 failed`.
- `make test-risk` passed and ran `test-risk-check.sh`, `test-risk-decisions.sh`, and `test-decision-cli.sh`.
- `make lint-json` passed.
- `make lint-shell` passed and printed `shellcheck not found; skipping shell lint`.
- `make upstream-status` passed with runtime pin `023b1bff11c2a01a435f1956a0e2ac1773a065f3` and `status: match`.
- `HERMES_AGENT_DIR=/tmp/hermes-missing make upstream-status` passed and reported `runtime pin: missing`.
- `! rg -n "test-integration|test-e2e|coverage|release" Makefile` passed.
- `git diff --name-only -- docs/orchestra/scripts/tests docs/orchestra/scripts/bin .planning/upstream/hermes-agent-pin.json` printed no paths.
- `make test` passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 16 developer workflow is ready for Phase 17 agent rule consolidation. The new Makefile gives Phase 17 a single local verification entrypoint via `make test`.

---
*Phase: 16-makefile-dev-workflow*
*Completed: 2026-04-28*
