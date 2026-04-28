# Phase 11: Pattern Map

**Created:** 2026-04-25
**Status:** Ready for planning

## Scope

Phase 11 should extend the package helpers created in Phase 10 without creating a new local Hermes runtime. The package remains upstream-first: local code is adapter glue, tmux/file-bus helpers, skills, templates, and verification only.

## File Map

| Target | Role | Closest Existing Analog | Reuse Pattern |
|--------|------|-------------------------|---------------|
| `docs/hermes-dev-orchestra/scripts/setup.sh` | Installer that places package files into user home | Current Phase 10 `setup.sh` | Keep no-sudo roots, upstream preflight, SOUL/skills install, helper install, temp-HOME smokeability |
| `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` | Shared shell library for paths, state, bus, locks, tmux helpers | Current repeated root variables in `setup.sh` heredocs | Centralize `RUNTIME_ROOT`, `STATE_ROOT`, `AUDIT_ROOT`, `CACHE_ROOT`, project validation, atomic write, bus stage detection |
| `docs/hermes-dev-orchestra/scripts/bin/orch-init` | User command: register project | Current generated `orch-init` heredoc | Preserve Git worktree-compatible validation via `git -C ... rev-parse --is-inside-work-tree` |
| `docs/hermes-dev-orchestra/scripts/bin/orch-start` | User command: start/reuse sessions and watcher | Current generated `orch-start` heredoc | Preserve `hermes-{project}-claude` and `hermes-{project}-codex` naming, add health checks and watcher PID |
| `docs/hermes-dev-orchestra/scripts/bin/orch-stop` | User command: stop sessions and watcher | Current generated `orch-stop` heredoc | Keep idempotent kill behavior, extend to watcher PID cleanup |
| `docs/hermes-dev-orchestra/scripts/bin/orch-status` | User command: detailed project status | Current generated `orch-status` heredoc | Preserve global/project views, add stage, active task, file markers, project prefixes |
| `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` | Internal watcher used by `orch-start` | No existing dedicated file; behavior described in README §6 | Implement inotify/poll fallback, Codex dispatch, Claude decision/review routing |
| `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md` | Codex protocol contract | Current skill docs | Replace stale long-running/interactivity assumptions with `codex exec --json -o ...` and JSON envelope rules |
| `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md` | Claude protocol contract | Current skill docs | Replace raw Markdown decision examples with JSON envelope outputs and `claude -p --output-format json` |
| `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` | Hermes orchestration contract | Current skill docs and README examples | Align with watcher behavior, no concrete Remote Decision Channel, no L3/L4 auto-approval |
| `docs/hermes-dev-orchestra/README.md` | User-facing runtime docs | Existing deployment and daily-use sections | Update examples to match template helper files and JSON-envelope bus behavior |

## Concrete Patterns to Preserve

- `setup.sh` remains package-only and never installs upstream Hermes, Claude Code, or Codex.
- `orch-init` accepts `orch-init <project-id> <project-dir>`.
- `orch-start` accepts `orch-start <project-id> <project-dir>`.
- `orch-stop` accepts `orch-stop <project-id>`.
- `orch-status` accepts optional `project-id`.
- All roots stay user-overridable with environment variables:
  - `RUNTIME_ROOT="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"`
  - `STATE_ROOT="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"`
  - `AUDIT_ROOT="${AUDIT_ROOT:-$HOME/.local/share/hermes-orchestra}"`
  - `CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hermes-orchestra}"`
- Claude hooks template already dual-writes per-project and global JSONL files; do not break that format.

## Landmines

- The current skill docs mention `--channels`, `workspace-read-network-write`, and raw Markdown bus content. These should not be carried forward without current verification.
- Do not rely on an undocumented `notification_hook` key for correctness.
- Do not use `--dangerously-skip-permissions` or `--dangerously-bypass-approvals-and-sandbox`.
- Do not treat tmux scrollback as source of truth; use Runtime bus plus State/Audit records.

