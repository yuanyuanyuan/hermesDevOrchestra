# Phase 10: Orchestra Package Installer & Skills Layout - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Requirements alignment after Phase 9 upstream baseline execution

<domain>
## Phase Boundary

This phase installs the Hermes Dev Orchestra "package" into the upstream Hermes Agent environment:
- SOUL.md (orchestrator personality definition)
- Four custom skills (dev-orchestra, claude-supervisor, codex-executor, escalation-handler)
- 4-layer directory structure (Runtime/State/Audit/Cache)
- Claude Code hooks configuration template
- `orch-*` bash helper scripts

It does NOT install or manage Claude Code CLI, Codex CLI, or upstream Hermes Agent itself — those are Phase 9's responsibility. It does NOT implement the tmux runtime loop, file bus message routing, or risk decision enforcement — those are Phases 11-12.

</domain>

<decisions>
## Implementation Decisions

### Setup Script Scope (Decision ①)
- **D-01:** `setup.sh` (or equivalent installer) installs ONLY orchestra-specific content: SOUL.md, skills, directory layout, Claude hooks template, and `orch-*` scripts.
- **D-02:** `setup.sh` does NOT install or update Claude Code CLI or Codex CLI. User manages those independently.
- **Rationale:** Keeps Phase 10 scope minimal. Avoids overwriting user's existing Claude/Codex installations.

### Claude Hooks Events Path (Decision ②)
- **D-03:** Claude Code hooks write events to TWO locations:
  1. **Per-project:** `/tmp/hermes-orchestra/{project}/claude-events.jsonl` — for project-isolated processing
  2. **Global:** `/tmp/hermes-orchestra/claude-events.jsonl` — for `orch-status` aggregated view
- **Rationale:** Per-project isolation matches the 4-layer bus design (D1); global file provides a single read point for status commands.

### orch-* Helper Form (Decision ③)
- **D-04:** `orch-init`, `orch-start`, `orch-stop`, `orch-status` are implemented as **bash scripts** placed on PATH (e.g., `~/.local/bin/` or `~/.hermes-orchestra/bin/`).
- **D-05:** If upstream Hermes Agent later supports custom commands/skills, these bash scripts may be wrapped as Hermes skill commands — but the core logic remains bash.
- **Rationale:** Bash is lightweight, has no extra dependencies, and works in the no-sudo Ubuntu target environment. No need to wait for Phase 9 upstream capability confirmation.

### SOUL and Skills Installation (Decision ④ — Updated after Phase 9)
- **D-06:** Before installing our SOUL.md, **backup** the upstream's existing `~/.hermes/SOUL.md` to `~/.hermes/SOUL.md.bak`.
- **D-07:** Copy our SOUL.md to `~/.hermes/SOUL.md` (overwriting upstream's after backup).
- **D-08:** Copy our 4 skills directly to `~/.hermes/skills/{skill-name}/` directories.
- **D-09:** Do NOT use `hermes skills install` for local paths — direct copy is more reliable since local path support through the upstream skill command is unverified.
- **Rationale:** Phase 9 confirmed upstream SOUL path (`~/.hermes/SOUL.md`) and skills path (`~/.hermes/skills/`) are upstream-native. Backup preserves upstream defaults for rollback. Skills coexist with upstream's 74 bundled skills (no naming conflicts detected).

### Setup Script Positioning (Decision ⑤ — New)
- **D-10:** `setup.sh` checks `hermes --version` before proceeding. If upstream Hermes Agent is not installed, it prints an error message directing the user to complete Phase 9 first.
- **D-11:** `setup.sh` does NOT call the upstream installer or reimplement upstream installation logic.
- **Rationale:** Clear separation of concerns — Phase 9 installs upstream, Phase 10 installs orchestra package on top. Avoids duplicating the SSH/HTTPS clone workaround discovered in Phase 9.

### Directory Layout (Locked by D1)
- **D-12:** Create 4-layer directory structure idempotently:
  - Runtime: `/tmp/hermes-orchestra/{project}/` (per-project bus files)
  - State: `~/.local/state/hermes-orchestra/{project}/` (persistent snapshots)
  - Audit: `~/.local/share/hermes-orchestra/{project}/` (decision logs, escalation records)
  - Cache: `~/.cache/hermes-orchestra/{project}/` (temporary computation caches)
- **Rationale:** D1 from Phase 9 context locks this 4-layer structure. README.md's original 2-layer design is insufficient for durable audit trails.

### Claude's Discretion
- Exact `orch-*` script implementation details (argument parsing, error messages) are left to implementation discretion.
- Whether to create shell aliases in `.bashrc` for `orch-*` or rely on PATH alone is left to implementation discretion.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — v1.1 requirement list (PKG-01..PKG-04, RUN-01..RUN-05, SAFE-01..VER-04)
- `.planning/ROADMAP.md` — Phase 10 goals, success criteria, execution order
- `.planning/PROJECT.md` — Vision, constraints, key decisions, current state

### Product Intent
- `docs/hermes-dev-orchestra/README.md` — Product behavior baseline: Step 1 (setup.sh), Step 4 (orch-init), architecture, file bus, deployment steps
- `docs/hermes-dev-orchestra/hermes/SOUL.md` — Hermes orchestrator personality definition

### Skills & Setup
- `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` — Main orchestration skill
- `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md` — Claude supervisor role
- `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md` — Codex executor role
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` — Risk gatekeeper role
- `docs/hermes-dev-orchestra/scripts/setup.sh` — Installation script draft (upstream-first baseline)

### Upstream Baseline (Phase 9 Output)
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md` — Upstream install evidence, capability matrix, commit SHA pin, gap analysis
- `.planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md` — Phase 9 locked decisions (D1-D9)

</canonical_refs>

<code_context>
## Existing Code Insights

### Upstream Environment (from Phase 9)
- **Hermes Agent v0.11.0** installed at `/home/stark/.hermes/hermes-agent`, binary at `~/.local/bin/hermes`
- **Pinned commit:** `023b1bff11c2a01a435f1956a0e2ac1773a065f3`
- **SOUL loading:** Upstream-native — `~/.hermes/SOUL.md` loaded by `agent/prompt_builder.py`
- **Skills system:** Upstream-native — `~/.hermes/skills/` with 74 bundled skills; `hermes skills` command supports browse/search/install/list/audit/config
- **Upstream directories:** `~/.hermes/cron/`, `sessions/`, `logs/` exist; no 4-layer Runtime/State/Audit/Cache layout

### Local Assets to Install
- `docs/hermes-dev-orchestra/hermes/SOUL.md` — Orchestra SOUL definition
- `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md`
- `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md`
- `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md`
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md`
- `docs/hermes-dev-orchestra/scripts/setup.sh` — Baseline installer (may need adaptation)

### Deleted Assets (Phase 9 Cleanup)
- `package.json`, `bin/hermes.js`, `src/cli.js`, `src/result.js`, `src/version.js` — deleted
- `src/atomic.js`, `src/envelope.js`, `src/paths.js` — confirmed absent
- No local `hermes` wrapper remains

</code_context>

<specifics>
## Specific Ideas

1. **SOUL.md backup strategy:** Before overwriting `~/.hermes/SOUL.md`, save upstream's original as `~/.hermes/SOUL.md.bak` with a timestamp comment.

2. **Skills coexistence:** Our 4 skills (`dev-orchestra`, `claude-supervisor`, `codex-executor`, `escalation-handler`) have names distinct from upstream's 74 bundled skills (`claude-code`, `codex`, `hermes-agent`, etc.). No naming collision.

3. **Idempotent directory creation:** All `mkdir -p` operations should silently succeed if directories already exist. No error on re-running setup.sh.

4. **Installer HTTPS workaround:** Phase 9 discovered upstream installer prefers SSH clone and may hang. Phase 10's setup.sh should NOT replicate this — it assumes upstream is already installed.

5. **Claude hooks template:** Per-project `.claude/settings.json` should include:
   - `PermissionRequest` and `Notification` hooks writing to both per-project and global events files
   - `permissionMode: autoEdit` (as per README.md §7.2)

</specifics>

<deferred>
## Deferred Ideas

- Wrapping `orch-*` bash scripts as upstream Hermes skill commands — deferred until upstream custom command support is verified
- Tmux session lifecycle implementation — Phase 11
- File bus message routing loop — Phase 11
- Risk decision enforcement and file-based fallback — Phase 12
- Smoke fixture verification — Phase 12
- Coverage matrix documentation — Phase 12

</deferred>

---

*Phase: 10-orchestra-package-installer-skills-layout*
*Context gathered: 2026-04-25*
*Decisions updated: 2026-04-25 (after Phase 9 execution)*
