# Phase 10 Research: Orchestra Package Installer & Skills Layout

## Research Complete

Phase 10 should adapt the existing Dev Orchestra package assets to the upstream Hermes Agent baseline proven in Phase 9. The main implementation work is not a new runtime; it is a no-sudo installer and helper layout that copies the orchestra package into upstream-native locations, creates the agreed Runtime/State/Audit/Cache directories, and exposes `orch-*` shell helpers without shadowing the upstream `hermes` command.

## Source Inputs

- `.planning/phases/10-orchestra-package-installer-skills-layout/10-CONTEXT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md`
- `.planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md`
- `docs/hermes-dev-orchestra/README.md`
- `docs/hermes-dev-orchestra/scripts/setup.sh`
- `docs/hermes-dev-orchestra/claude-config/settings.json`
- `docs/hermes-dev-orchestra/hermes/SOUL.md`
- `docs/hermes-dev-orchestra/skills/*/SKILL.md`

## Key Findings

### Upstream boundary

- Phase 9 established upstream Hermes Agent v0.11.0 at `~/.hermes/hermes-agent`, with the `hermes` binary symlinked at `~/.local/bin/hermes`.
- Upstream SOUL loading is native: `~/.hermes/SOUL.md`.
- Upstream skills loading is native: `~/.hermes/skills/{skill-name}/`.
- The package installer must not call the upstream installer, must not install Claude Code CLI, and must not install Codex CLI.
- The local package must not recreate a `hermes` command; all local commands must use the `orch-*` namespace.

### Existing installer gaps

- `docs/hermes-dev-orchestra/scripts/setup.sh` currently tries to install upstream Hermes Agent, Claude Code CLI, and Codex CLI. That violates D-01, D-02, D-10, and D-11.
- `SCRIPT_DIR` points to `docs/hermes-dev-orchestra/scripts`, but package assets live under `docs/hermes-dev-orchestra/`; skill and SOUL copy paths should use a package root such as `PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"`.
- The skill destination is currently nested under `~/.hermes/skills/dev-orchestra/{skill}`. Phase 10 requires direct upstream layout: `~/.hermes/skills/{skill-name}/`.
- Existing SOUL copy overwrites `~/.hermes/SOUL.md` without backing up the upstream file.
- Current helpers are internal scripts plus shell aliases. Phase 10 requires real bash commands named `orch-init`, `orch-start`, `orch-stop`, and `orch-status` placed on PATH.
- Existing directory creation only covers `~/.hermes-orchestra/` and `/tmp/hermes-orchestra/`; it does not create the full State/Audit/Cache roots.
- Current Claude settings append only the global event file and contain the typo `CLAUAD_SESSION_NAME`. Hooks need per-project and global event writes.
- The setup script includes Telegram-specific setup text. v1 keeps Remote Decision Channel abstract, so Phase 10 should not bind the installer to Telegram.

### Required install targets

| Item | Source | Destination |
|------|--------|-------------|
| SOUL | `docs/hermes-dev-orchestra/hermes/SOUL.md` | `~/.hermes/SOUL.md` |
| SOUL backup | existing `~/.hermes/SOUL.md` | `~/.hermes/SOUL.md.bak` |
| `dev-orchestra` skill | `docs/hermes-dev-orchestra/skills/dev-orchestra/` | `~/.hermes/skills/dev-orchestra/` |
| `claude-supervisor` skill | `docs/hermes-dev-orchestra/skills/claude-supervisor/` | `~/.hermes/skills/claude-supervisor/` |
| `codex-executor` skill | `docs/hermes-dev-orchestra/skills/codex-executor/` | `~/.hermes/skills/codex-executor/` |
| `escalation-handler` skill | `docs/hermes-dev-orchestra/skills/escalation-handler/` | `~/.hermes/skills/escalation-handler/` |
| Claude hooks template | `docs/hermes-dev-orchestra/claude-config/settings.json` | `~/.hermes-orchestra/claude-config-template/.claude/settings.json` |
| Helpers | generated bash scripts | `~/.hermes-orchestra/bin/orch-*` and PATH links in `~/.local/bin/orch-*` |

### Directory roots

The installer should create roots idempotently:

- Runtime root: `/tmp/hermes-orchestra`
- State root: `~/.local/state/hermes-orchestra`
- Audit root: `~/.local/share/hermes-orchestra`
- Cache root: `~/.cache/hermes-orchestra`
- Package root: `~/.hermes-orchestra`
- Helper root: `~/.hermes-orchestra/bin`
- Template root: `~/.hermes-orchestra/claude-config-template/.claude`
- Backup root: `~/.hermes-orchestra/backups`

`orch-init <project-id> <project-dir>` may create the per-project directories under all four roots, but it should not implement the Phase 11 routing loop.

## Implementation Guidance

### Installer preflight

`setup.sh` should fail fast only when the package cannot be installed safely:

- `command -v hermes` must succeed.
- `hermes --version` must succeed or return a readable failure that points users back to Phase 9.
- `tmux` should be required because `orch-*` helpers are installed in this phase and runtime sessions depend on tmux.
- `git`, `claude`, and `codex` may be checked and reported, but the script must not install or update them.
- The script should create `~/.local/bin` and warn if it is not currently on PATH.

### SOUL backup and copy

Use idempotent behavior:

- If `~/.hermes/SOUL.md` exists and differs from the package SOUL, copy it to `~/.hermes/SOUL.md.bak` only when that backup does not already exist.
- Then copy the package SOUL to `~/.hermes/SOUL.md`.
- If the current SOUL already matches the package SOUL, report that it is already installed.

### Skill copy

Copy each required skill directory directly to `~/.hermes/skills/{skill-name}/`:

- Delete or replace only the four managed destination directories.
- Do not modify upstream bundled skills.
- Verify each destination has `SKILL.md`.
- Preserve the names from the README trigger table.

### Hooks template

`docs/hermes-dev-orchestra/claude-config/settings.json` should write events to both:

- `/tmp/hermes-orchestra/{project}/claude-events.jsonl`
- `/tmp/hermes-orchestra/claude-events.jsonl`

Use a project ID derived from `HERMES_ORCHESTRA_PROJECT`, falling back to `basename "$PWD"`. The hook commands should ensure the per-project runtime directory exists before appending.

### Helper commands

Install bash scripts with these command names:

- `orch-init`
- `orch-start`
- `orch-stop`
- `orch-status`

Expected Phase 10 behavior:

- `orch-init <project-id> <project-dir>` validates arguments, checks that the project directory exists and is a Git repository, creates per-project Runtime/State/Audit/Cache directories, copies the Claude settings template if `.claude/settings.json` is absent, and writes a small project metadata file under the State root.
- `orch-start <project-id> <project-dir>` validates upstream tools with `command -v hermes`, `command -v tmux`, `command -v claude`, and `command -v codex`; it may start or reuse basic Claude/Codex tmux sessions, but it must not implement file-bus routing beyond invoking the tools.
- `orch-stop <project-id>` stops the Claude and Codex tmux sessions for that project.
- `orch-status [project-id]` reports upstream `hermes --version`, matching tmux sessions, runtime bus files, state metadata, and global Claude event tail if present.

These helpers should call upstream tools by command name and should never call a local `bin/hermes.js`, `src/cli.js`, or custom runtime module.

## Phase Risks

- **Overwriting user SOUL:** Mitigate with a one-time backup to `~/.hermes/SOUL.md.bak` before replacement.
- **Skill path mismatch:** Mitigate by copying to `~/.hermes/skills/{skill-name}/` and verifying `SKILL.md` for all four required skills.
- **PATH shadowing:** Mitigate by using only `orch-*` helper names and never creating `hermes`.
- **Scope creep into Phase 11:** Mitigate by limiting helpers to install/preflight/session shell glue and deferring file-bus routing, runtime loop, and risk enforcement.
- **Remote-channel binding:** Mitigate by removing Telegram-specific installer instructions and keeping remote decision setup abstract.

## Validation Architecture

### Automated checks

- `bash -n docs/hermes-dev-orchestra/scripts/setup.sh`
- `jq empty docs/hermes-dev-orchestra/claude-config/settings.json`
- `grep -q 'command -v hermes' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q 'hermes --version' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q '~/.hermes/SOUL.md.bak\\|SOUL.md.bak' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q '~/.hermes/skills/\\$skill\\|\\.hermes/skills' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q 'orch-init' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q 'orch-start' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q 'orch-stop' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q 'orch-status' docs/hermes-dev-orchestra/scripts/setup.sh`
- `grep -q '/tmp/hermes-orchestra/.*/claude-events.jsonl\\|HERMES_ORCHESTRA_PROJECT' docs/hermes-dev-orchestra/claude-config/settings.json`
- `grep -q '/tmp/hermes-orchestra/claude-events.jsonl' docs/hermes-dev-orchestra/claude-config/settings.json`

### Optional smoke fixture

A safe smoke fixture can run with a temporary HOME:

```bash
tmp_home="$(mktemp -d)"
mkdir -p "$tmp_home/.hermes/skills" "$tmp_home/.local/bin"
printf '# upstream soul\n' > "$tmp_home/.hermes/SOUL.md"
PATH="$PATH" HOME="$tmp_home" bash docs/hermes-dev-orchestra/scripts/setup.sh
test -f "$tmp_home/.hermes/SOUL.md.bak"
test -f "$tmp_home/.hermes/skills/dev-orchestra/SKILL.md"
test -x "$tmp_home/.local/bin/orch-init"
```

If this smoke fixture depends on the real `hermes` binary, it should first verify `command -v hermes`; otherwise it should be documented as a manual environment check.

### Manual checks

- Confirm `hermes --version` still reports upstream Hermes Agent after install.
- Confirm no `hermes` wrapper is created in this repository or in the installed helper directory.
- Confirm re-running `setup.sh` succeeds without duplicate aliases, duplicate backup churn, or directory errors.

## Planning Recommendation

Use one implementation plan in wave 1. The phase has one cohesive file set and the work is safest when the installer, hooks template, and helper layout are updated together:

- `docs/hermes-dev-orchestra/scripts/setup.sh`
- `docs/hermes-dev-orchestra/claude-config/settings.json`
- optional documentation notes in `docs/hermes-dev-orchestra/README.md`
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md`

## RESEARCH COMPLETE
