---
phase: 11-project-bootstrap-tmux-runtime-file-bus
plan: 03
subsystem: infra
tags: [bash, claude, codex, json-envelope, review, audit]
requires:
  - phase: 11-project-bootstrap-tmux-runtime-file-bus
    provides: tmux lifecycle and Codex task dispatch
provides:
  - Codex question to Claude decision routing
  - Claude decision to fresh Codex continuation routing
  - Codex result to Claude review routing
  - Audit archive capture for completed bus artifacts
  - Protocol-aligned README and skill contracts
affects: [phase-12, risk-decisions, remote-decision-channel, audit]
tech-stack:
  added: []
  patterns:
    - Canonical JSON envelopes inside compatibility .md bus filenames
    - Project-prefixed status and final bus summaries
key-files:
  created: []
  modified:
    - docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop
    - docs/hermes-dev-orchestra/scripts/bin/orch-status
    - docs/hermes-dev-orchestra/scripts/lib/orch-common.sh
    - docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md
    - docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md
    - docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md
    - docs/hermes-dev-orchestra/README.md
key-decisions:
  - "L3/L4 remains blocked in Phase 11; escalation.md never becomes an automatic approval."
  - "Remote Decision Channel stays abstract; no Telegram/Discord binding is required."
  - "JSON envelopes are canonical even though bus filenames keep .md compatibility names."
patterns-established:
  - "Correlation-compatible task/question/decision routing before Codex continuation."
  - "Review-approved bus artifacts are copied to Audit archive before project completion state."
requirements-completed: [RUN-03, RUN-04, RUN-05]
duration: 35min
completed: 2026-04-25
---

# Phase 11 Plan 03: Decision Routing, Review Capture & Protocol Alignment Summary

**Question, decision, continuation, review, and audit routing through canonical JSON envelope bus files**

## Performance

- **Duration:** 35 min
- **Started:** 2026-04-25T09:10:00Z
- **Completed:** 2026-04-25T09:45:00Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added Codex question routing to Claude Supervisor and Claude decision routing back into fresh Codex one-shot executions.
- Added result review routing, `APPROVED`/`REJECTED`/`NEEDS_MODIFICATION` state handling, and Audit archive manifests.
- Extended status with project prefixes, last Codex result, last review decision, and escalation-blocked messaging.
- Aligned README and dev/Claude/Codex skills with canonical JSON envelopes, `--output-last-message`, abstract Remote Decision Channel, and L3/L4 no-auto-approval.

## Task Commits

No git commits were created during this Codex run; changes remain in the working tree for user review.

## Files Created/Modified

- `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` - Routes questions, decisions, results, reviews, and escalations through the Runtime bus.
- `docs/hermes-dev-orchestra/scripts/bin/orch-status` - Displays project-prefixed stage, bus files, Codex result, review decision, and escalation state.
- `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` - Adds JSON/correlation/archive helpers and robust review-stage handling.
- `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` - Documents Hermes task creation as JSON `task.md` envelopes and keeps Remote Decision Channel abstract.
- `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md` - Documents JSON `codex-question.md`/`codex-result.md` envelopes and `--output-last-message`.
- `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md` - Documents JSON decision/review envelopes and `execution.authority_sufficient`.
- `docs/hermes-dev-orchestra/README.md` - Documents JSON bus compatibility names, watcher behavior, troubleshooting, and notification hook semantics.

## Decisions Made

- L3/L4 remains a Phase 12 enforcement area; Phase 11 blocks on `escalation.md` and does not auto-approve.
- Stale `--channels`, `workspace-read-network-write`, and `codex exec resume` claims were removed or corrected.
- Review state now reflects `REJECTED` and `NEEDS_MODIFICATION` instead of treating every `review-result.md` as completed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Raw `task_id` JSON serialization**
- **Found during:** Phase code review
- **Issue:** `orch_write_project_state` built a JSON string in shell before passing it to Python, which could break if a task ID contained quotes or backslashes.
- **Fix:** Python now receives the raw `task_id` and serializes it safely with `json.dump`.
- **Files modified:** `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh`
- **Verification:** Regression smoke wrote a quoted task ID and validated `current-task.json` with `python3 -m json.tool`.

**2. [Rule 2 - Missing Critical] Review stage overreported completion**
- **Found during:** Phase code review
- **Issue:** `orch_stage_for_project` returned `completed` for any `review-result.md`, even when the review decision was `REJECTED` or `NEEDS_MODIFICATION`.
- **Fix:** Stage derivation now honors current task state and review decision before reporting completion.
- **Files modified:** `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh`
- **Verification:** `bash -n` and fake bus smoke passed after the change.

---

**Total deviations:** 2 auto-fixed (2 missing-critical robustness fixes).  
**Impact on plan:** Both fixes improve correctness without expanding scope.

## Issues Encountered

- GSD executor/reviewer subagents were unavailable in this runtime, so execution and review were performed inline.
- Git commit steps were skipped because this Codex environment requires explicit user instruction before committing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 12 can build on a concrete project bootstrap, tmux lifecycle, file-bus dispatch, Claude/Codex decision loop, review capture, and status/audit foundation. Remaining safety work is explicit L3/L4 rulebook enforcement and local decision fallback.

---
*Phase: 11-project-bootstrap-tmux-runtime-file-bus*
*Completed: 2026-04-25*
