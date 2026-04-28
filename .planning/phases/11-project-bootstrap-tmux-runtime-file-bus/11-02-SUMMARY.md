---
phase: 11-project-bootstrap-tmux-runtime-file-bus
plan: 02
subsystem: infra
tags: [bash, tmux, codex, watcher, runtime-bus]
requires:
  - phase: 11-project-bootstrap-tmux-runtime-file-bus
    provides: project bootstrap and helper template foundation
provides:
  - Claude and Codex tmux session lifecycle helpers
  - Per-project watcher startup and stop behavior
  - Runtime task dispatch to Codex through tmux
affects: [phase-11, phase-12, orch-helpers, codex-executor]
tech-stack:
  added: []
  patterns:
    - Per-project tmux shells with health-based reuse
    - Runner scripts for safely quoted tmux command dispatch
key-files:
  created:
    - docs/hermes-dev-orchestra/scripts/bin/orch-start
    - docs/hermes-dev-orchestra/scripts/bin/orch-stop
    - docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop
  modified:
    - docs/hermes-dev-orchestra/scripts/lib/orch-common.sh
    - docs/hermes-dev-orchestra/scripts/bin/orch-status
    - docs/hermes-dev-orchestra/scripts/setup.sh
    - docs/hermes-dev-orchestra/README.md
key-decisions:
  - "orch-start creates reusable tmux shell envelopes; Codex execution remains one-shot through watcher-dispatched commands."
  - "Codex completion signal files are acceleration hints only; codex-result.md remains canonical evidence."
patterns-established:
  - "Watcher stores task hashes in State to prevent duplicate dispatch."
  - "tmux receives small runner invocations while runner files hold the full safely quoted commands."
requirements-completed: [RUN-02, RUN-03]
duration: 30min
completed: 2026-04-25
---

# Phase 11 Plan 02: tmux Runtime Lifecycle & Codex Task Dispatch Summary

**Reusable Claude/Codex tmux shells with a project watcher that dispatches JSON task envelopes to Codex**

## Performance

- **Duration:** 30 min
- **Started:** 2026-04-25T08:40:00Z
- **Completed:** 2026-04-25T09:10:00Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added tmux session naming, running, and health helpers for `hermes-<project>-claude` and `hermes-<project>-codex`.
- Implemented `orch-start` to validate tools, reuse healthy sessions, recreate stale sessions, and start one watcher PID per project.
- Implemented idempotent `orch-stop` and extended `orch-status` with watcher state and active task hash.
- Implemented `orch-bus-loop --once` and continuous polling/inotify modes for Codex task dispatch.

## Task Commits

No git commits were created during this Codex run; changes remain in the working tree for user review.

## Files Created/Modified

- `docs/hermes-dev-orchestra/scripts/bin/orch-start` - Starts/reuses Claude and Codex tmux shells and watcher process.
- `docs/hermes-dev-orchestra/scripts/bin/orch-stop` - Stops watcher and tmux sessions idempotently.
- `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` - Dispatches `task.md` to Codex with `codex exec --full-auto --json --output-last-message`.
- `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` - Adds tmux, hash, state, JSON, and archive helpers.
- `docs/hermes-dev-orchestra/scripts/bin/orch-status` - Reports watcher and task dispatch state.
- `docs/hermes-dev-orchestra/scripts/setup.sh` - Installs internal `orch-bus-loop`.
- `docs/hermes-dev-orchestra/README.md` - Documents watcher startup and dispatch behavior.

## Decisions Made

- Watcher commands are written as State-local runner scripts and tmux receives `bash <runner>` for safer quoting.
- `.codex-done` and `.codex-signal` are consumed as optional acceleration hints only.
- `codex exec resume` is not used; every continuation is a fresh `codex exec --full-auto --json --output-last-message ... -`.

## Deviations from Plan

### Implementation Detail

The plan described sending the full `cat ... | codex exec ...` command directly through `tmux send-keys`. The implementation instead writes that command into a generated runner script and sends `bash <runner>` through tmux. This preserves the required Codex invocation while reducing shell quoting risk for paths and prompt text.

**Total deviations:** 1 implementation detail.  
**Impact on plan:** Positive; behavior remains equivalent and was verified by fake tmux smoke tests.

## Issues Encountered

- GSD executor subagents were unavailable in this runtime, so the plan was executed inline.
- Git commit steps were skipped because this Codex environment requires explicit user instruction before committing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The project watcher can now dispatch tasks to Codex, enabling question/decision/review routing in Plan 11-03.

---
*Phase: 11-project-bootstrap-tmux-runtime-file-bus*
*Completed: 2026-04-25*
