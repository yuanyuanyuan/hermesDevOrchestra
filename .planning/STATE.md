---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Upstream Hermes Agent Integration
status: ready_to_plan
stopped_at: Phase 12 context gathered; next action is `$gsd-plan-phase 12`.
last_updated: "2026-04-25T10:30:00.000Z"
last_activity: 2026-04-25 -- Phase 12 discuss-phase complete, 4 gray areas explored
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 6
  completed_plans: 6
  percent: 80
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-25)

**Core value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。  
**Current focus:** Phase 12 — Risk Decisions, Verification & Handoff

## Current Position

Phase: 12 — READY TO PLAN
Plan: 0 of TBD
Status: Phase 12 context gathered; ready for planning
Last activity: 2026-04-25 -- Phase 12 discuss-phase complete, 4 gray areas explored

Progress: [████████░░] 80%

## Requirements Alignment

Nine decisions locked after README.md baseline review and Phase 9 clarification:

- **D1:** 4-layer path structure (Runtime/State/Audit/Cache) per REQUIREMENTS-REV1.md
- **D2:** Minimal viable risk rulebook (3-5 core rules)
- **D3:** File-based decision fallback as primary channel, Telegram optional
- **D4:** Local adapter completes upstream capability gaps to preserve README.md UX
- **D5:** Real current-user upstream Hermes Agent install/probe is allowed, with preflight stop-on-conflict.
- **D6:** Independent Node CLI scaffolding is deleted, not migrated or retained as a shim.
- **D7:** Upstream Hermes Agent is pinned to a concrete commit SHA.
- **D8:** Phase 9 records upstream capability gaps only; implementation moves to Phases 10-12.
- **D9:** Upstream owns `hermes`; local entrypoints are `orch-*` only.

## Performance Metrics

**Velocity:**

- Total plans completed: 6
- Average duration: N/A
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 8 | 1 | - | - |
| 9 | 1 | - | - |
| 10 | 1 | 7 min | 7 min |
| 11 | 3 | 85 min | 28 min |

**Recent Trend:**

- Last 5 plans: N/A
- Trend: New milestone started

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting current work:

- v1.0 shipped as a specification package; v1.1 now starts implementation via upstream Hermes Agent integration, not standalone Agent reimplementation.
- SSH/Hermes CLI remains the required user entry point.
- Community `NousResearch/hermes-agent` is the required foundation for Hermes Agent behavior.
- Local code should be limited to orchestra adapter glue, skills, templates, tmux/file-bus helpers, and verification.
- Runtime Bus, State, Audit, and Cache must remain physically separated where the adapter writes local files.
- JSON/JSONL is canonical for the local file bus and audit projections; Markdown is projection/documentation.
- L3/L4 decisions never auto-approve.
- Concrete remote adapters remain deferred; live Claude/Codex tmux orchestration is restored to v1.1 scope because the upstream Hermes Agent is the top-level orchestrator.
- Phase 11 validates the concrete local Runtime bus slice: `orch-init`, `orch-start`, `orch-stop`, `orch-status`, watcher-dispatched JSON envelopes, Claude decision routing, Codex review capture, and Audit archive manifests.

**Phase 10 Decisions (2026-04-25, post Phase 9 execution):**

- **D-01:** `setup.sh` installs ONLY orchestra content (SOUL, skills, directories, hooks, orch-*). Does NOT manage Claude/Codex CLI.
- **D-02:** `setup.sh` does NOT install upstream Hermes Agent — checks `hermes --version` and errors if missing.
- **D-03:** Claude hooks write events to BOTH per-project (`/tmp/hermes-orchestra/{project}/claude-events.jsonl`) AND global (`/tmp/hermes-orchestra/claude-events.jsonl`) paths.
- **D-04:** `orch-*` helpers are bash scripts (core), optionally wrapped as Hermes skills later.
- **D-05:** SOUL.md installation: backup upstream's `~/.hermes/SOUL.md` to `.bak`, then overwrite with orchestra SOUL.
- **D-06:** Skills installation: direct copy to `~/.hermes/skills/{name}/` (no naming conflicts with 74 upstream bundled skills).
- **D-07:** 4-layer directory structure created idempotently: Runtime (`/tmp/`), State (`~/.local/state/`), Audit (`~/.local/share/`), Cache (`~/.cache/`).

**v1.1 Requirements Alignment (2026-04-25):**

- **D1 — 4-layer paths:** Runtime (`/tmp/`) + State (`~/.local/state/`) + Audit (`~/.local/share/`) + Cache (`~/.cache/`) per REQUIREMENTS-REV1.md §2.3.1. README.md's 2-layer structure is insufficient for durability.
- **D2 — Minimal rulebook:** 3-5 core static JSON rules (database schema, auth, destructive ops, system commands, secrets) with Hermes enforcement. Extensible; more rules added post-v1.1.
- **D3 — File fallback primary:** `hermes decisions/approve/reject` CLI commands implement REMOTE-05. Telegram remains optional, not required.
- **D4 — Adapter completes gaps:** If upstream lacks capabilities README.md assumes (todo/memory, process registry, clarify/send_message, notify_on_complete), local adapter provides lightweight supplements. Does not replace upstream.
- **D5 — Real install allowed:** Phase 9 may install/update upstream `NousResearch/hermes-agent` in the current user environment because no other Hermes system is installed. Stop and report if an unexpected existing `hermes` or conflicting `~/.hermes` state is found.
- **D6 — Delete local CLI:** Delete independent Node CLI scaffolding instead of migrating or wrapping it. Avoid any local `hermes` command that can shadow upstream.
- **D7 — Pin commit:** Lock upstream Hermes Agent to a concrete commit SHA and document upgrade procedure.
- **D8 — Gap report only in Phase 9:** Phase 9 records upstream capability gaps only. Adapter implementation belongs to Phases 10-12.
- **D9 — Command entry boundary:** Keep upstream `hermes` untouched; this repo provides `orch-*` helper commands only.

### Pending Todos

- ~~Existing Phase 9 Node modules (`src/atomic.js`, `src/envelope.js`, `src/paths.js`) and `src/cli.js` path initialization changes are stale independent-runtime work unless explicitly retained as a shim.~~
  - **Resolved (D6, 2026-04-25):** These files are classified as provisional standalone-runtime scaffolding to be **deleted**. Local adapter code will be written fresh under `orch-*` helpers where later phases require it.

### Blockers/Concerns

None for Phase 12 planning. Optional upstream browser/TUI dependency warnings remain recorded in `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md`.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Remote adapters | Concrete Remote Decision Channel adapter | Deferred to adapter milestone | v1.0 / v1.1 planning |
| Product extensions | gbrain integration, dashboards, team workflows, unattended budgets | Deferred to v2+ | v1.0 |
| Runtime internals | Reimplementing Hermes Agent core runtime locally | Rejected; use upstream `NousResearch/hermes-agent` | direction correction |

## Session Continuity

Last session: 2026-04-25
Stopped at: Phase 12 context gathered; next action is `$gsd-plan-phase 12`.
Resume file: `.planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md`

**Completed Phase:** 11 (Project Bootstrap, tmux Runtime & File Bus) — 3/3 plans — project bootstrap, Claude/Codex tmux lifecycle, task dispatch, question routing, review capture, and project-prefixed status validated; summaries at `.planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-01-SUMMARY.md`, `11-02-SUMMARY.md`, and `11-03-SUMMARY.md`; verification at `.planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md`.

**Completed Phase:** 10 (orchestra-package-installer-skills-layout) — package-only setup script, SOUL/skills install layout, 4-layer directories, Claude hooks template, and `orch-*` helpers validated; summary at `.planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md`.

**Review:** Phase 10 code review clean after one Git worktree validation fix; report at `.planning/phases/10-orchestra-package-installer-skills-layout/10-REVIEW.md`.

**Completed Phase:** 09 (upstream-hermes-agent-baseline) — pinned upstream commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`; summary at `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md`.
