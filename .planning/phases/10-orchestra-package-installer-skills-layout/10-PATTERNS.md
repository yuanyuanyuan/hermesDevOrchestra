# Phase 10 Pattern Map

## Scope

This phase updates package assets rather than adding application runtime code. The closest analogs are the existing installer draft, Claude settings template, and Phase 9 plan/summary conventions for upstream-boundary verification.

## Files to Modify or Create

| Target | Role | Closest Analog | Pattern to Reuse |
|--------|------|----------------|------------------|
| `docs/hermes-dev-orchestra/scripts/setup.sh` | no-sudo package installer and helper generator | `docs/hermes-dev-orchestra/scripts/setup.sh` | Keep a single bash installer with `set -euo pipefail`, colorized logging helpers, and explicit phases. Remove upstream/CLI installation side effects. |
| `docs/hermes-dev-orchestra/claude-config/settings.json` | per-project Claude hooks template | `docs/hermes-dev-orchestra/claude-config/settings.json` | Preserve JSON template shape with `env`, `hooks`, `permissionMode`, and tool allowlist. Fix event targets and variable typo. |
| `docs/hermes-dev-orchestra/README.md` | user-facing install docs | existing README Step 1-5 | Keep command-oriented setup instructions; update only statements invalidated by Phase 9/10 decisions. |
| `.planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md` | execution evidence | `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md` | Record commands run, outputs, deviations, final paths, and next-phase inputs. |

## Concrete Existing Patterns

### Bash installer structure

The current installer already uses:

```bash
#!/usr/bin/env bash
set -euo pipefail
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERR]${NC} $1"; }
```

Keep this style, but change the behavior to package-only installation.

### Phase summary evidence structure

Phase 9 summary uses frontmatter plus sections for preflight, commands, output, deviations, final baseline, and next phase inputs. Phase 10 execution should write the same kind of evidence to `10-01-SUMMARY.md`.

### Planner task specificity

Phase 9 plan tasks include concrete command strings and grep-verifiable acceptance criteria. Phase 10 plans should follow that style so the executor can work without guessing.

## Data Flow

1. `setup.sh` reads package assets from `docs/hermes-dev-orchestra/`.
2. `setup.sh` copies SOUL and skills into upstream Hermes locations under `~/.hermes/`.
3. `setup.sh` creates orchestra roots under `/tmp`, `~/.local/state`, `~/.local/share`, `~/.cache`, and `~/.hermes-orchestra`.
4. `setup.sh` installs helper scripts into `~/.hermes-orchestra/bin` and links/copies them into `~/.local/bin`.
5. `orch-init` copies the Claude settings template into each project and creates per-project directory roots.
6. Claude hooks append project events to both per-project and global JSONL files.

## Landmines

- Do not use `SCRIPT_DIR/skills`; the source path should resolve to the package root.
- Do not install to `~/.hermes/skills/dev-orchestra/{skill}`; upstream skill layout is direct.
- Do not call `curl ... hermes-agent ... | bash`, `npm install -g @anthropic-ai/claude-code`, or `npm install -g @openai/codex`.
- Do not create `hermes` aliases, bins, wrappers, or package metadata.
- Do not make Telegram a required installer step.

## PATTERN MAPPING COMPLETE
