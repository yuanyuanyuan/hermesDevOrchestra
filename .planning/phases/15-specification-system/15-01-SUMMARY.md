---
phase: 15-specification-system
plan: "01"
subsystem: docs
tags: [specs, file-bus, risk-decisions, commands, smoke-tests]

requires:
  - phase: 14-migration-submodule-adr
    provides: active Dev Orchestra package path under docs/orchestra/
provides:
  - Consumer-scoped derived specifications under specs/
  - Derived-spec conformance smoke test discovered by run-all.sh
affects: [phase-16, phase-17, docs-orchestra, verification]

tech-stack:
  added: []
  patterns:
    - Derived specs cite .planning/SPEC.md as canonical source
    - Bash smoke tests validate documentation contracts

key-files:
  created:
    - specs/README.md
    - specs/file-bus.md
    - specs/risk-decisions.md
    - specs/commands.md
    - docs/orchestra/scripts/tests/test-specs.sh
  modified: []

key-decisions:
  - "Created only derived specs with current repository consumers."
  - "Kept .planning/SPEC.md as the only canonical specification."
  - "Used the existing smoke runner instead of adding Makefile or runtime wiring."

patterns-established:
  - "Derived specs use fixed Source, Consumers, Drift Check, and Conformance Checks sections."
  - "Spec conformance tests extract concrete backticked consumer paths and reject missing, absolute, or traversal paths."

requirements-completed:
  - SPEC-01
  - SPEC-02

duration: 10 min
completed: 2026-04-28
---

# Phase 15 Plan 01: Specification System Summary

**Consumer-scoped derived specs with executable conformance checks while preserving `.planning/SPEC.md` as canonical**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-28T11:08:59Z
- **Completed:** 2026-04-28T11:19:12Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `specs/README.md` as the derived specification index with canonical-source, conflict, read-order, and inventory rules.
- Added derived projections for file bus, risk decisions, and command contracts, each with concrete current consumers and drift commands.
- Added `docs/orchestra/scripts/tests/test-specs.sh`, which fails on missing sections, missing canonical source, malformed or missing consumers, missing drift commands, missing self-conformance checks, and unindexed specs.
- Verified the existing smoke runner discovers and runs the new spec conformance checks without Makefile or runtime changes.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create consumer-scoped derived spec documents** - `5838ff5` (`feat(15-01): create derived specification documents`)
2. **Task 2: Add failing derived-spec conformance checks** - `5fca842` (`test(15-01): add derived spec conformance checks`)

## Files Created/Modified

- `specs/README.md` - Derived spec index and `.planning/SPEC.md` authority relationship.
- `specs/file-bus.md` - File-bus contract projection for bus loop, file-bus tests, README, and workflow consumers.
- `specs/risk-decisions.md` - Risk and decision contract projection for rulebook, decision helpers, and risk/decision tests.
- `specs/commands.md` - Command contract projection for local `orch-*` helpers and docs tests.
- `docs/orchestra/scripts/tests/test-specs.sh` - Executable conformance smoke test for derived specs.

## Decisions Made

- Created only the three derived specs with current repository consumers: file bus, risk decisions, and commands.
- Kept `.planning/SPEC.md` as the sole canonical specification; derived specs are projections only.
- Relied on `docs/orchestra/scripts/tests/run-all.sh` discovery so Phase 15 adds no Makefile or runtime wiring.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope creep; Phase 15 stayed within the planned documentation and smoke-test boundary.

## Issues Encountered

- The initial executor did not return a completion signal. Filesystem and git spot-checks showed Task 1 had completed, then Task 2 and metadata were finished in the main thread using the documented fallback path.

## Verification

- `bash docs/orchestra/scripts/tests/test-specs.sh` - passed.
- `bash docs/orchestra/scripts/tests/run-all.sh` - passed, 10 smoke tests.
- `test -x docs/orchestra/scripts/tests/test-specs.sh` - passed.
- `find specs -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort` - printed only `README.md`, `commands.md`, `file-bus.md`, and `risk-decisions.md`.
- Guarded diff for `.planning/SPEC.md`, `Makefile`, `docs/orchestra/scripts/bin`, `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md`, and `docs/orchestra/scripts/tests/run-all.sh` - no paths.
- Negative mutation checks for missing required section and absolute consumer path - both failed as expected, then restored docs passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 16 can add Makefile and local developer workflow targets against the existing smoke runner and the new `test-specs.sh` contract.

---
*Phase: 15-specification-system*
*Completed: 2026-04-28*
