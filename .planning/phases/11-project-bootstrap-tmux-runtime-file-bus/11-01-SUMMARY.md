---
phase: 11-project-bootstrap-tmux-runtime-file-bus
plan: 01
subsystem: infra
tags: [bash, setup, project-bootstrap, file-bus, xdg-paths]
requires:
  - phase: 10-orchestra-package-installer-skills-layout
    provides: package installer layout and upstream Hermes boundary
provides:
  - Helper template installation from package source files
  - Durable per-project bootstrap metadata
  - Status command for initialized projects
affects: [phase-11, phase-12, orch-helpers, runtime-bus]
tech-stack:
  added: []
  patterns:
    - Bash helper templates copied by setup.sh
    - Four-layer Runtime/State/Audit/Cache path derivation
key-files:
  created:
    - docs/hermes-dev-orchestra/scripts/lib/orch-common.sh
    - docs/hermes-dev-orchestra/scripts/bin/orch-init
    - docs/hermes-dev-orchestra/scripts/bin/orch-status
  modified:
    - docs/hermes-dev-orchestra/scripts/setup.sh
    - docs/hermes-dev-orchestra/README.md
key-decisions:
  - "Helper bodies live as package templates under scripts/bin and scripts/lib instead of setup.sh heredocs."
  - "Runtime is active bus only; durable project metadata is written under State."
patterns-established:
  - "orch-common.sh centralizes project ID validation and four-layer path derivation."
  - "Project bootstrap writes project.env, paths.json, projects.json, and current-task.json."
requirements-completed: [RUN-01]
duration: 20min
completed: 2026-04-25
---

# Phase 11 Plan 01: Project Bootstrap & Helper Template Foundation Summary

**Template-installed `orch-*` helpers with Git-validated project bootstrap and durable State metadata**

## Performance

- **Duration:** 20 min
- **Started:** 2026-04-25T07:18:27Z
- **Completed:** 2026-04-25T08:40:00Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Extracted reusable helper logic into `orch-common.sh` and package-installed helper templates from `setup.sh`.
- Implemented `orch-init <project-id> <project-dir>` with project ID validation, Git repo validation, four-layer directories, Claude settings copy, and State metadata.
- Implemented `orch-status [project-id]` listing registered projects and project-prefixed bus/session/status markers.

## Task Commits

No git commits were created during this Codex run; changes remain in the working tree for user review.

## Files Created/Modified

- `docs/hermes-dev-orchestra/scripts/setup.sh` - Copies helper templates and installs `orch-common.sh`.
- `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` - Provides project validation, path derivation, atomic write, state/stage helpers, JSON helpers, tmux helpers, and archive helpers.
- `docs/hermes-dev-orchestra/scripts/bin/orch-init` - Initializes project Runtime/State/Audit/Cache directories and durable metadata.
- `docs/hermes-dev-orchestra/scripts/bin/orch-status` - Reports registered projects and project-prefixed bus state.
- `docs/hermes-dev-orchestra/README.md` - Documents bootstrap metadata and four-layer directories.

## Decisions Made

- Package templates are the source of truth for helper command bodies; `setup.sh` only installs them.
- `project.env`, `paths.json`, `projects.json`, and `current-task.json` live under State, not Runtime.
- Project IDs use the planned regex `^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$`.

## Deviations from Plan

None - plan executed as specified.

## Issues Encountered

- GSD executor subagents were unavailable in this runtime, so the plan was executed inline.
- Git commit steps were skipped because this Codex environment requires explicit user instruction before committing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Project bootstrap and status foundations are ready for tmux lifecycle and watcher dispatch work in Plan 11-02.

---
*Phase: 11-project-bootstrap-tmux-runtime-file-bus*
*Completed: 2026-04-25*
