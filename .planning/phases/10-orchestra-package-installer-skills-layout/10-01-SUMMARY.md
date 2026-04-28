---
phase: 10-orchestra-package-installer-skills-layout
plan: 01
subsystem: packaging
tags: [bash, hermes-agent, skills, hooks, tmux, codex, claude-code]
requires:
  - phase: 09-upstream-hermes-agent-baseline
    provides: upstream Hermes Agent install path, SOUL path, skills path, and command boundary
provides:
  - package-only setup script for Dev Orchestra assets
  - direct upstream SOUL and skill installation layout
  - Runtime/State/Audit/Cache directory root creation
  - PATH-installed `orch-*` helper scripts
  - dual-write Claude hooks event template
affects: [phase-11-project-bootstrap, phase-12-risk-verification]
tech-stack:
  added: []
  patterns:
    - package-only user-space bash installer
    - direct upstream Hermes skill layout copy
    - per-project and global JSONL hook event writes
key-files:
  created:
    - .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md
    - .planning/phases/10-orchestra-package-installer-skills-layout/10-REVIEW.md
    - .planning/phases/10-orchestra-package-installer-skills-layout/10-VERIFICATION.md
  modified:
    - docs/hermes-dev-orchestra/scripts/setup.sh
    - docs/hermes-dev-orchestra/claude-config/settings.json
    - docs/hermes-dev-orchestra/README.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/PROJECT.md
key-decisions:
  - "Installer now requires existing upstream `hermes` and `tmux` instead of installing upstream tools."
  - "Local package exposes only `orch-*` helpers; no local `hermes` wrapper is created."
  - "Claude hooks append to both per-project and global event JSONL files."
patterns-established:
  - "Use `PACKAGE_DIR` for package assets and user-overridable root env vars for install targets."
  - "Install custom Hermes skills directly to `~/.hermes/skills/{skill-name}/`."
requirements-completed: [PKG-01, PKG-02, PKG-03, PKG-04]
duration: 7 min
completed: 2026-04-25
---

# Phase 10 Plan 01: Orchestra Package Installer & Skills Layout Summary

**Package-only Dev Orchestra installer with upstream SOUL/skills layout, four-layer directory roots, PATH helpers, and dual-write Claude hooks**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-25T06:28:18Z
- **Completed:** 2026-04-25T06:34:56Z
- **Tasks:** 5
- **Files modified:** 6

## Commands Run

- `bash -n docs/hermes-dev-orchestra/scripts/setup.sh`
- `jq empty docs/hermes-dev-orchestra/claude-config/settings.json`
- Plan acceptance grep checks for installer, hooks, and README requirements
- Temporary HOME smoke test:
  - `bash docs/hermes-dev-orchestra/scripts/setup.sh`
  - `orch-init smoke <temp-git-project>`
  - file checks for SOUL backup, four skills, four helpers, per-project roots, Claude template, and `project.env`
- Local code review gate:
  - one Git worktree validation warning found and fixed
  - post-fix temporary HOME smoke test rerun successfully

## Installer Changes

- Converted `docs/hermes-dev-orchestra/scripts/setup.sh` into a package-only installer.
- Removed upstream Hermes Agent install/update, Claude Code global npm install, and Codex global npm install behavior.
- Added explicit `command -v hermes`, `hermes --version`, and `command -v tmux` preflight gates.
- Added SOUL backup to `~/.hermes/SOUL.md.bak` before overwriting `~/.hermes/SOUL.md`.
- Installed `dev-orchestra`, `claude-supervisor`, `codex-executor`, and `escalation-handler` directly to `~/.hermes/skills/{skill-name}/`.
- Generated real PATH helpers: `orch-init`, `orch-start`, `orch-stop`, and `orch-status`.

## Installed Layout

- **SOUL:** `~/.hermes/SOUL.md`
- **SOUL backup:** `~/.hermes/SOUL.md.bak`
- **Skills:** `~/.hermes/skills/{dev-orchestra,claude-supervisor,codex-executor,escalation-handler}/SKILL.md`
- **Package home:** `~/.hermes-orchestra/`
- **Helpers:** `~/.hermes-orchestra/bin/orch-*` linked into `~/.local/bin/orch-*`
- **Runtime:** `/tmp/hermes-orchestra/`
- **State:** `~/.local/state/hermes-orchestra/`
- **Audit:** `~/.local/share/hermes-orchestra/`
- **Cache:** `~/.cache/hermes-orchestra/`

## Validation

- `bash -n docs/hermes-dev-orchestra/scripts/setup.sh` passed.
- `jq empty docs/hermes-dev-orchestra/claude-config/settings.json` passed.
- Acceptance grep checks passed for all `PKG-01` through `PKG-04` plan criteria.
- Temporary HOME smoke test passed without mutating the real user home:
  - Existing SOUL backup created.
  - Four skill `SKILL.md` files installed.
  - Four helper commands installed and executable.
  - `orch-init` created Runtime/State/Audit/Cache project directories.
  - `orch-init` copied `.claude/settings.json` and wrote `project.env`.

## Task Commits

No git commits were created. The execution ran in the main working tree and preserved the repository's existing uncommitted GSD changes per Codex local instruction not to commit unless explicitly requested.

## Files Created/Modified

- `docs/hermes-dev-orchestra/scripts/setup.sh` — package-only installer and generated `orch-*` helpers.
- `docs/hermes-dev-orchestra/claude-config/settings.json` — dual-write hook events and corrected `CLAUDE_SESSION_NAME`.
- `docs/hermes-dev-orchestra/README.md` — install instructions aligned with upstream-first package scope and abstract Remote Decision Channel.
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-REVIEW.md` — advisory code review result.
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md` — execution evidence.
- `.planning/REQUIREMENTS.md` — `PKG-01` through `PKG-04` marked completed.
- `.planning/ROADMAP.md` and `.planning/STATE.md` — Phase 10 progress recorded.
- `.planning/PROJECT.md` — validated requirements/current state advanced after Phase 10.

## Decisions Made

- Kept `orch-start` as session bootstrap only; Phase 11 remains responsible for file-bus task routing.
- Kept Remote Decision Channel documentation abstract; no Telegram-specific installer binding remains.
- Used temporary-home smoke validation to prove install behavior without touching the real user install.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Git worktree-compatible project validation**
- **Found during:** Code review gate
- **Issue:** `orch-init` used a `.git` directory check, which rejects valid Git worktrees where `.git` is a file.
- **Fix:** Replaced the directory check with `git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree` and added an explicit `git` command check.
- **Files modified:** `docs/hermes-dev-orchestra/scripts/setup.sh`
- **Verification:** `bash -n docs/hermes-dev-orchestra/scripts/setup.sh`; temporary HOME smoke test with `orch-init smoke <temp-git-project>`.
- **Committed in:** Not committed; workspace-only execution.

**Total deviations:** 1 auto-fixed (missing critical project validation). **Impact on plan:** Improves correctness without expanding phase scope.

## Issues Encountered

- `state.begin-phase` did not accept the attempted flag syntax and temporarily wrote malformed Phase state. This was corrected in `.planning/STATE.md` during completion tracking.
- GSD subagents were unavailable/timeout-prone in this runtime, so execution followed the workflow's inline fallback path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 11 can build on installed `orch-*` helper names, per-project Runtime/State/Audit/Cache roots, and Claude hook event files. Remaining runtime work is task dispatch, Codex question routing, Claude decision routing, result capture, and status readout.

## Self-Check: PASSED

- [x] All tasks executed
- [x] SUMMARY.md created
- [x] Requirements `PKG-01`, `PKG-02`, `PKG-03`, and `PKG-04` completed
- [x] Validation commands passed
- [x] No local `hermes` wrapper created

---
*Phase: 10-orchestra-package-installer-skills-layout*
*Completed: 2026-04-25*
