# Roadmap: Hermes Dev Orchestra

## Milestones

- ✅ **v1.0 Specification Package** — Phases 1-7 (shipped 2026-04-25)
- 🚧 **v1.1 Hermes CLI Prototype** — Phases 8-12 (planned)

## Phases

<details>
<summary>✅ v1.0 Specification Package (Phases 1-7) — SHIPPED 2026-04-25</summary>

- [x] Phase 01: Scope, Package Coverage & Authority (1/1 plans) — completed 2026-04-25
- [x] Phase 02: Runtime, Installation & Command Contracts (1/1 plans) — completed 2026-04-25
- [x] Phase 03: File Bus, Decision Envelope, State & Audit (1/1 plans) — completed 2026-04-25
- [x] Phase 04: Multi-Project Scheduling & Isolation (1/1 plans) — completed 2026-04-25
- [x] Phase 05: Agent Protocol, Challenge & Evidence (1/1 plans) — completed 2026-04-25
- [x] Phase 06: Risk Rulebook & Remote Decision Contract (1/1 plans) — completed 2026-04-25
- [x] Phase 07: Recovery, Observability, Verification & Handoff (1/1 plans) — completed 2026-04-25

</details>

## v1.1 Hermes CLI Prototype

**Goal:** 实现一个本地可运行的 Hermes CLI 原型，把 v1.0 规格中的核心路径、项目注册、任务追加、状态查看、doctor/preflight、文件总线和本地决策 fallback 落成可验证的最小纵向切片。

- [x] **Phase 8: CLI Shell, Packaging & Command Envelope** - Establishes the runnable local hermes command, no-sudo dev/install entry, help/version output, and structured command result envelope. (completed 2026-04-25)
- [ ] **Phase 9: Path Resolver, State Store & File Bus Foundation** - Implements the four-layer path resolver, paths.json, canonical JSON/JSONL envelope helpers, atomic writes, and state/audit separation.
- [ ] **Phase 10: Project Registry, Task Queue & Status Read Model** - Implements project init, project validation, task append/deduplication, durable queue state, and status output.
- [ ] **Phase 11: Doctor, Risk Rulebook & Local Decision Fallback** - Implements doctor/preflight probes, static risk rule matching, local decision request/list/approve/reject, and L3/L4 blocking invariants.
- [ ] **Phase 12: Prototype Verification, Docs & Implementation Handoff** - Adds smoke fixtures, user docs, prototype coverage matrix, and next-milestone handoff for live agent orchestration.

## Phase Details

### Phase 8: CLI Shell, Packaging & Command Envelope
**Goal**: User can run a local no-sudo hermes CLI prototype, inspect help/version output, and receive structured JSON success/error envelopes for supported commands.
**Depends on**: v1.0 specification package
**Requirements**: CLI-01, CLI-02, CLI-03
**Success Criteria** (what must be TRUE):
  1. hermes --help lists prototype commands and exits successfully.
  2. hermes --version reports a prototype version.
  3. Supported commands can emit JSON success/error objects with stable fields.
  4. The prototype can run without sudo or global system installation.
**Plans**: TBD

### Phase 9: Path Resolver, State Store & File Bus Foundation
**Goal**: User can trust the prototype's resolved Runtime, State, Audit, and Cache locations and inspect canonical bus/state/audit files written with safe file semantics.
**Depends on**: Phase 8
**Requirements**: BUS-01, BUS-02, BUS-03, BUS-04
**Success Criteria** (what must be TRUE):
  1. CLI startup writes a State-layer paths.json manifest with resolved absolute paths.
  2. Runtime, State, Audit, and Cache files are physically separated.
  3. Bus/state/audit records use JSON/JSONL envelopes with schema-ready fields.
  4. Atomic write helper uses temp-file plus rename in the target filesystem.
**Plans**: TBD

### Phase 10: Project Registry, Task Queue & Status Read Model
**Goal**: User can register a project, append tasks, and inspect current project/task status through durable state rather than terminal scrollback.
**Depends on**: Phase 9
**Requirements**: PROJ-01, PROJ-02, TASK-01, TASK-02, STAT-01
**Success Criteria** (what must be TRUE):
  1. hermes init <project-id> <project-dir> creates or updates a project registry entry idempotently.
  2. Invalid project IDs, unsafe paths, and non-Git project directories are rejected with structured errors.
  3. hermes task <project-id> <task-file> writes a durable task record, queue state, event, and audit evidence.
  4. Duplicate task behavior is deterministic and documented.
  5. hermes status shows project, task, cwd, heartbeat age, risk wait, last event, and next action.
**Plans**: TBD

### Phase 11: Doctor, Risk Rulebook & Local Decision Fallback
**Goal**: User can run preflight checks, see risk floors applied, and resolve local decision requests without any remote transport.
**Depends on**: Phase 10
**Requirements**: DOC-01, SAFE-01, SAFE-02, DEC-01, DEC-02
**Success Criteria** (what must be TRUE):
  1. hermes doctor reports Node, Git, tmux, Claude Code CLI, Codex CLI, auth hints, sandbox capability, and JSON behavior checks.
  2. Static rulebook matching produces minimum risk levels for representative operations.
  3. L3/L4 decisions remain blocked unless an explicit user approve/reject command validates successfully.
  4. hermes decisions lists pending local fallback decisions.
  5. hermes approve and hermes reject enforce one-time use, TTL, project ID, task ID, and approval ID binding.
**Plans**: TBD

### Phase 12: Prototype Verification, Docs & Implementation Handoff
**Goal**: Reviewer can verify the CLI prototype against the v1.1 requirements and understand exactly what remains for live agent orchestration.
**Depends on**: Phase 11
**Requirements**: VER-01, VER-02, VER-03, VER-04
**Success Criteria** (what must be TRUE):
  1. Smoke/fixture checks cover init, task, status, doctor, decisions, path resolution, and structured errors.
  2. Documentation describes commands, environment variables, path layout, manual verification, implemented scope, and limits.
  3. Coverage matrix maps v1.0 specification contracts to implemented, stub/dry-run, or deferred status.
  4. Handoff orders next work for tmux lifecycle, Claude/Codex runners, review loop, and remote adapters.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 8 → 9 → 10 → 11 → 12

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 8. CLI Shell, Packaging & Command Envelope | v1.1 | 1/1 | Complete    | 2026-04-25 |
| 9. Path Resolver, State Store & File Bus Foundation | v1.1 | 0/TBD | Not started | - |
| 10. Project Registry, Task Queue & Status Read Model | v1.1 | 0/TBD | Not started | - |
| 11. Doctor, Risk Rulebook & Local Decision Fallback | v1.1 | 0/TBD | Not started | - |
| 12. Prototype Verification, Docs & Implementation Handoff | v1.1 | 0/TBD | Not started | - |

## Archives

- [v1.0 roadmap archive](milestones/v1.0-ROADMAP.md)
- [v1.0 requirements archive](milestones/v1.0-REQUIREMENTS.md)
- [v1.0 audit](milestones/v1.0-MILESTONE-AUDIT.md)
- [v1.0 phase artifacts](milestones/v1.0-phases/)
