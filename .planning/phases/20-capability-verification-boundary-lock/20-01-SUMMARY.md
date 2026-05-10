---
phase: 20-capability-verification-boundary-lock
plan: "01"
subsystem: verification
tags: [capability-verification, hermes, boundary-lock, official-vs-local]
requires:
  - phase: 19-hermes-workflow-design
    provides: Official capability claims, workflow projections, and R1/R2 verification contract
provides:
  - Capability verification matrix for phase 19 official claims
  - Phase 19 official/local boundary reclassification
  - Backlog carry-forward entries for unsupported and downgraded claims
  - Phase 20 verification evidence
affects: [phase-19-design, roadmap, requirements, state]
tech-stack:
  added: []
  patterns:
    - Official capability claims are audited in a matrix before any downstream document writeback
key-files:
  created:
    - .planning/phases/20-capability-verification-boundary-lock/20-CAPABILITY-MATRIX.md
    - .planning/phases/20-capability-verification-boundary-lock/20-VERIFICATION.md
    - .planning/phases/20-capability-verification-boundary-lock/20-01-SUMMARY.md
  modified:
    - .planning/phases/19-hermes-workflow-design/DESIGN.md
    - .planning/phases/19-hermes-workflow-design/REQUIREMENTS.md
    - .planning/phases/19-hermes-workflow-design/WORKFLOW-EXPLAINED.md
    - .planning/phases/19-hermes-workflow-design/WORKFLOW-ASCII-DIAGRAMS.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/STATE.md
key-decisions:
  - "Phase 20 uses the local runtime `Hermes Agent v0.13.0 (2026.5.7)` as the primary verification anchor, with official docs as secondary evidence."
  - "Gateway delivery closure and skill_manage workflow automation are not treated as proven official coverage in the current environment."
  - "Unsupported or downgraded official claims must create roadmap backlog entries before the project advances."
patterns-established:
  - "Capability boundary lock is matrix-first: collect verdicts, then write back to design/requirements/workflow docs."
  - "Hybrid and doc-only evidence are allowed only when local closure is clearly impractical; they must be labeled explicitly."
requirements-completed: [VFY-01, VFY-02]
duration: 15 min
completed: 2026-05-10
---

# Phase 20 Plan 01: Capability Verification & Boundary Lock Summary

**Built a capability verification matrix, reclassified phase 19 official claims, and locked the Hermes official/local boundary for v1.3**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-10T10:06:14Z
- **Completed:** 2026-05-10T10:21:31Z
- **Tasks:** 4
- **Files modified:** 7 planning/design files plus 3 new Phase 20 artifacts

## Accomplishments

- Created `20-CAPABILITY-MATRIX.md` and populated it with runtime, hybrid, and doc-only evidence for phase 19 official capability claims.
- Verified locally runnable Hermes capability surfaces for Kanban, Profile, Dispatcher, block/unblock flow, sessions, tools/toolsets, and `approvals.mode`.
- Used official docs plus temp `HERMES_HOME` probes to verify hooks, curator, memory, and the `skill_manage` official surface.
- Downgraded two phase 19 assumptions:
  - `GATEWAY-DELIVERY-CLOSURE` → `unsupported`
  - `SKILL-MANAGE-WORKFLOW-AUTOMATION` → `local-extension`
- Wrote those downgraded claims into `.planning/ROADMAP.md` backlog and updated phase 19 source docs so official labels now defer to the Phase 20 matrix.
- Marked `VFY-01` and `VFY-02` complete in `.planning/REQUIREMENTS.md` and recorded Phase 20 verification evidence.

## Task Commits

1. **Planning artifacts** - `cd53f15` (`docs(20): add phase planning artifacts`)
2. **Phase execution artifacts and writeback** - `ab8838a` (`docs(20): execute capability boundary lock`)

## Files Created/Modified

- `.planning/phases/20-capability-verification-boundary-lock/20-CAPABILITY-MATRIX.md` - Capability-by-capability verdicts with commands, exit codes, key outputs, and writeback targets.
- `.planning/phases/20-capability-verification-boundary-lock/20-VERIFICATION.md` - Phase 20 verification result, including the external aggregate-gate blocker.
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` - Appendix A reclassified to `verified / unsupported / local-extension`.
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` - Added explicit Phase 0 verification outcome note.
- `.planning/phases/19-hermes-workflow-design/WORKFLOW-EXPLAINED.md` - Official-label authority now points to the Phase 20 matrix.
- `.planning/phases/19-hermes-workflow-design/WORKFLOW-ASCII-DIAGRAMS.md` - Added Phase 20 boundary-lock note.
- `.planning/ROADMAP.md` - Marked Phase 20 complete and added carry-forward backlog entries.
- `.planning/REQUIREMENTS.md` - Marked `VFY-01` and `VFY-02` complete.
- `.planning/STATE.md` - Updated current focus and blocker state for post-Phase-20 advancement.

## Decisions Made

- Chose the local Hermes runtime as the primary verification anchor and did not let official docs override local runtime facts.
- Allowed `hybrid` and `doc-only` evidence only where a real local end-to-end closure was clearly unsafe or impractical.
- Preserved the official `skill_manage` tool surface while explicitly downgrading phase 19’s stronger automation claim to local workflow logic.
- Treated the current gateway command/service surface as official, but did not overclaim real message delivery closure in this environment.

## Deviations from Plan

- The plan assumed a clean aggregate `rtk make test` closeout gate. In execution, the repository-level `upstream-status` check failed because the local Hermes runtime pin does not match `.planning/upstream/hermes-agent-pin.json`.

**Total deviations:** 1 documented external blocker.
**Impact on plan:** Phase 20 scope still completed; the blocker is recorded in verification and state, and should be resolved separately from the capability-boundary work.

## Issues Encountered

- `rtk make test` failed only at `upstream-status`:
  - repo pin: `023b1bff11c2a01a435f1956a0e2ac1773a065f3`
  - runtime pin: `93e25ceb1326770b369b8c4151cd3b9c3cdc0688`
  - status: `mismatch`
- This mismatch is external to the Phase 20 matrix/writeback logic, but it prevents calling the repository-wide gate fully green.

## Verification

- Phase 20 static matrix/writeback checks passed.
- All planned writeback markers exist in the target docs.
- `20-VERIFICATION.md` records a passed scope result with one external aggregate-gate blocker.
- `rtk make test` partially passed:
  - Smoke suite: all 10 checks passed
  - Risk checks: `risk-check`, `risk-decisions`, and `decision-cli` passed
  - Shell lint skipped with `shellcheck not found; skipping shell lint`
  - Upstream pin status failed with `status: mismatch`

## Self-Check: PASSED WITH EXTERNAL BLOCKER

Phase 20’s own scope is complete: matrix created, official/local boundary locked, failed claims reclassified, and VFY traceability updated. The only remaining issue is the external runtime pin mismatch surfaced by the aggregate repo gate.

## User Setup Required

- If a fully green `rtk make test` is required before Phase 21 or milestone closure, resolve the local Hermes runtime pin mismatch first.

## Next Phase Readiness

Phase 20 is ready to hand off to Phase 21 from a planning/workflow perspective. The next logical GSD step is Phase 21 context gathering, with awareness that the repository-wide upstream pin mismatch remains open.

---
*Phase: 20-capability-verification-boundary-lock*
*Completed: 2026-05-10*
