---
phase: 10-orchestra-package-installer-skills-layout
verified: 2026-04-25T06:37:30Z
status: passed
score: 7/7 must-haves verified
---

# Phase 10: Orchestra Package Installer & Skills Layout — Verification

## Goal

User can install the Hermes Dev Orchestra SOUL, skills, hooks templates, directories, and helper commands into the upstream Hermes Agent environment.

## Automated Checks

| Check | Status | Evidence |
|-------|--------|----------|
| Installer syntax | passed | `bash -n docs/hermes-dev-orchestra/scripts/setup.sh` exited 0. |
| Claude settings JSON | passed | `jq empty docs/hermes-dev-orchestra/claude-config/settings.json` exited 0. |
| Installer acceptance grep suite | passed | Verified `command -v hermes`, `hermes --version`, `SOUL.md.bak`, four skills, four helpers, and four directory roots. |
| Temporary HOME install smoke | passed | Setup installed SOUL backup, four skills, four helpers, Claude template, and no-sudo roots under temporary paths. |
| `orch-init` smoke | passed | `orch-init smoke <temp-git-project>` created Runtime/State/Audit/Cache directories, copied `.claude/settings.json`, and wrote `project.env`. |
| Schema drift gate | passed | `gsd-sdk query verify.schema-drift 10` returned `"valid": true` with no issues. |
| Code review gate | passed | `10-REVIEW.md` status is `clean`; one Git worktree validation warning was fixed. |

## Must-Haves

| # | Must-have | Status | Evidence |
|---|-----------|--------|----------|
| 1 | `setup.sh` installs only Dev Orchestra package content and does not install upstream Hermes, Claude Code, or Codex. | passed | `setup.sh` has explicit preflight checks and no upstream `curl | bash` or global npm install commands. |
| 2 | `setup.sh` checks upstream `hermes` before copying package assets. | passed | `setup.sh` contains `command -v hermes` and `hermes --version`. |
| 3 | Existing `~/.hermes/SOUL.md` is backed up before overwrite. | passed | `setup.sh` contains and smoke-tested `~/.hermes/SOUL.md.bak`. |
| 4 | Four skills install directly under `~/.hermes/skills/{skill-name}/`. | passed | Smoke test verified all four target `SKILL.md` files. |
| 5 | Runtime, State, Audit, and Cache roots are created idempotently without sudo. | passed | Smoke test created temporary equivalents for all four roots. |
| 6 | `orch-init`, `orch-start`, `orch-stop`, and `orch-status` are installed as PATH helpers and do not create `hermes`. | passed | Smoke test verified all four helpers are executable; script creates no local `hermes` helper. |
| 7 | Claude hook events write to both per-project and global JSONL paths. | passed | `settings.json` contains `HERMES_ORCHESTRA_PROJECT`, `/tmp/hermes-orchestra/$project/claude-events.jsonl`, and `/tmp/hermes-orchestra/claude-events.jsonl`. |

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| PKG-01 | passed | SOUL source copies to upstream `~/.hermes/SOUL.md` with `.bak` backup logic. |
| PKG-02 | passed | Four skills copy directly to upstream `~/.hermes/skills/{skill-name}/`. |
| PKG-03 | passed | Package roots and per-project Runtime/State/Audit/Cache directories are created without sudo. |
| PKG-04 | passed | `orch-*` helpers invoke upstream `hermes`, `tmux`, `claude`, and `codex`; no custom `hermes` runtime exists. |

## Regression Gate

Prior Phase 8 verification referenced the superseded local Node CLI that Phase 9 intentionally deleted. No runnable prior-phase regression suite remains applicable to Phase 10. Phase 10 validation instead verified the upstream-first package boundary established by Phase 9.

## Human Verification

None required. Real user-home installation can be run manually later with `bash docs/hermes-dev-orchestra/scripts/setup.sh`, but the temporary HOME smoke test covered the installer behavior without mutating the user's environment.

## Result

Phase 10 passed. The package installer and helper layout are ready for Phase 11 runtime/file-bus implementation.
