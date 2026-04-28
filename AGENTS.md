<!-- GSD:project-start source:PROJECT.md -->
## Project

Hermes Dev Orchestra is a specification-package project for a single-developer, multi-project AI development orchestration system.

The v1 deliverable is documentation and planning artifacts, not a runnable orchestrator. The spec defines Hermes Agent as the top-level orchestrator, Claude Code CLI as supervisor/reviewer, Codex CLI as executor, per-project file-bus coordination, tmux session isolation, risk escalation, and an abstract Remote Decision Channel.

Primary constraints:
- SSH/Hermes CLI is the required user entry point.
- Remote decisions are abstracted; do not bind v1 to Telegram or any concrete transport.
- `gbrain` is not part of v1 implementation scope.
- L3/L4 decisions must never be auto-approved.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

The v1 specification targets a Linux-first local stack:

- Ubuntu/Linux host with no-sudo installation assumptions
- SSH for primary user access
- tmux for persistent PTY/session envelopes
- Git as the project safety and rollback boundary
- Claude Code CLI for supervision/review decisions
- Codex CLI for bounded execution
- JSON/JSONL as canonical file-bus protocol
- Markdown as human-readable projection only
- XDG-style Runtime, State, Audit, and Cache paths

Do not treat tmux scrollback, raw Markdown, or `/tmp` audit files as the source of truth.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

- Keep changes focused on `.planning/` unless the user explicitly asks for implementation work.
- Treat requirements, specifications, roadmap, and state as the authoritative planning artifacts.
- Preserve the spec-first boundary: write contracts, schemas, scenarios, and roadmap steps before code.
- Prefer structured, checkable requirements over prose-only intent.
- Do not modify `gbrain/` as part of this project unless explicitly requested.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:research/ARCHITECTURE.md -->
## Architecture

The target architecture is a three-agent control plane:

- Hermes owns orchestration, scheduling, state, process lifecycle, escalation, audit, archive, and user communication.
- Claude Supervisor owns technical decisions, risk classification, code review, confidence, and escalation recommendations within authority limits.
- Codex Executor owns implementation, tests, refactors, pause/questions, and structured execution results.

The specification should keep these boundaries explicit:
- Hermes enforces static risk-rule floors and writes final user decisions.
- Claude may upgrade risk but must not downgrade below the rulebook floor.
- Codex may challenge when it finds new risk context, but never approves risk decisions.
- User is the final authority for L3/L4.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project-local skills are defined yet. Use GSD workflow commands and the `.planning/` artifacts for project context.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before file-changing work, start through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `$gsd-plan-phase <n>` for planned specification work
- `$gsd-execute-phase <n>` for executing phase plans
- `$gsd-progress` to inspect roadmap/state
- `$gsd-extract_learnings <n>` after a phase completes

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `$gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` — do not edit manually.
<!-- GSD:profile-end -->

<!-- hermes-dev-orchestra-start -->
## Hermes Dev Orchestra

Project-specific rules for the Hermes Dev Orchestra adaptation layer.
These complement (not replace) the Architecture section above.

### Package Boundary

- This repository is an **adapter layer**, not a standalone runtime.
- Local entrypoints are limited to `orch-*` helpers: `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-audit`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-verify`.
- Spec authority lives in `docs/hermes-dev-orchestra/`; `.planning/SPEC.md` is canonical for planning artifacts.

### Agent Role Boundary

- **Hermes** must not auto-approve L3/L4 escalations. Blocking flows through `escalation.md` or high-risk `claude-decision.md`, `orch-bus-loop`, pending decisions, and explicit user action via `orch-decisions`, `orch-approve`, or `orch-reject`.
- **Claude** must not modify upstream `NousResearch/hermes-agent` core code.
- **Codex** must not modify `~/.hermes-orchestra/rules.json`.
- `orch-risk-check` is a risk classifier/helper; it is not a replacement for the L3/L4 blocking and user-decision flow.

### Directory Navigation

| Directory | Purpose |
|-----------|---------|
| `docs/hermes-dev-orchestra/` | Product behavior baseline, SOUL, skills, scripts |
| `.planning/SPEC.md` | Canonical specification |
| `.planning/STATE.md` | Project state and decisions |
<!-- hermes-dev-orchestra-end -->

