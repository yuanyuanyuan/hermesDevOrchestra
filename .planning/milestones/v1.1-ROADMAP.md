# Roadmap: Hermes Dev Orchestra

## Milestones

- ✅ **v1.0 Specification Package** — Phases 1-7 (shipped 2026-04-25)
- 🚧 **v1.1 Upstream Hermes Agent Integration** — Phases 8-12 (replanned from Phase 9)

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

## v1.1 Upstream Hermes Agent Integration

**Goal:** 基于社区 `NousResearch/hermes-agent` 实现本地 Hermes Dev Orchestra 适配包，而不是独立重写新的 Hermes Agent。v1.1 要验证上游安装、SOUL/skills 加载、`orch-*` helper、Claude/Codex tmux 会话、文件总线、风险阻塞和本地决策 fallback。

- [x] **Phase 8: Legacy CLI Shell Baseline** - Created a local Node CLI shell before direction correction; now treated as superseded scaffolding to delete. (completed 2026-04-25; superseded by upstream-first direction)
- [x] **Phase 9: Upstream Hermes Agent Baseline** - Installed/probed `NousResearch/hermes-agent`, pinned commit, documented capabilities, and deleted standalone local Node CLI scaffolding. (completed 2026-04-25)
- [x] **Phase 10: Orchestra Package Installer & Skills Layout** - Installed SOUL.md, four orchestra skills, directory layout, Claude hooks templates, and `orch-*` helpers into the upstream Hermes Agent environment. (completed 2026-04-25)
- [x] **Phase 11: Project Bootstrap, tmux Runtime & File Bus** - Implements project bootstrap, Claude/Codex tmux session lifecycle, task dispatch, Codex question routing, Claude decision routing, review/result capture, and status readout. (completed 2026-04-25)
- [x] **Phase 12: Risk Decisions, Verification & Handoff** - Enforces L3/L4 blocking, local decision fallback, audit records, smoke fixtures, coverage matrix, docs, and handoff for remote adapters/production hardening. (completed 2026-04-25)

## Phase Details

### Phase 8: Legacy CLI Shell Baseline
**Goal**: Capture the already-created local Node CLI shell as provisional scaffolding only; it is not the target Hermes Agent runtime.
**Depends on**: v1.0 specification package
**Requirements**: Historical Phase 8 only; superseded by UP-03/UP-04
**Success Criteria** (what must be TRUE):
  1. Existing Node CLI files are identified as provisional.
  2. Phase 9 deletes the scaffolding instead of migrating or wrapping it.
  3. No new feature work treats the local Node CLI as the core Agent runtime.
**Plans**: 08-01 complete before direction correction

### Phase 9: Upstream Hermes Agent Baseline
**Goal**: User can install/probe the real community Hermes Agent and understand exactly which capabilities the orchestra adapter can rely on.
**Depends on**: Phase 8
**Requirements**: UP-01, UP-02, UP-03, UP-04
**Success Criteria** (what must be TRUE):
  1. Upstream `hermes` can be installed or located without sudo.
  2. Upstream version/commit and observed commands/capabilities are recorded.
  3. Gaps between README assumptions and upstream behavior are documented.
  4. Existing local Node CLI scaffolding is deleted so upstream `hermes` remains the only `hermes` command.
**Plans**: 09-01

### Phase 10: Orchestra Package Installer & Skills Layout
**Goal**: User can install the Hermes Dev Orchestra SOUL, skills, hooks templates, directories, and helper commands into the upstream Hermes Agent environment.
**Depends on**: Phase 9
**Requirements**: PKG-01, PKG-02, PKG-03, PKG-04
**Success Criteria** (what must be TRUE):
  1. SOUL.md is installed where upstream Hermes Agent loads it.
  2. Four custom skills are installed with names and triggers matching the README.
  3. No-sudo directories and project bus paths are created idempotently.
  4. `orch-*` helpers invoke upstream Hermes Agent and tmux, not a reimplemented core.
**Plans**: 10-01

### Phase 11: Project Bootstrap, tmux Runtime & File Bus
**Goal**: User can initialize a project, start Claude/Codex tmux sessions, dispatch a task, route Codex questions to Claude, and collect results through the per-project file bus.
**Depends on**: Phase 10
**Requirements**: RUN-01, RUN-02, RUN-03, RUN-04, RUN-05
**Success Criteria** (what must be TRUE):
  1. `orch-init` validates Git project directories and writes bus/config files.
  2. `orch-start` starts or reuses `hermes-{project}-claude` and `hermes-{project}-codex`.
  3. User tasks reach Codex through `task.md`.
  4. `codex-question.md` flows to Claude and `claude-decision.md` flows back to Codex.
  5. `codex-result.md`, `review-result.md`, and status output are project-prefixed.
**Plans**: 11-01, 11-02, 11-03

### Phase 12: Risk Decisions, Verification & Handoff
**Goal**: Reviewer can verify the upstream-based orchestra slice against safety requirements and understand exactly what remains for remote adapters or production hardening.
**Depends on**: Phase 11
**Requirements**: SAFE-01, SAFE-02, DEC-01, DEC-02, VER-01, VER-02, VER-03, VER-04
**Success Criteria** (what must be TRUE):
  1. L3/L4 decisions block until explicit user approval or rejection.
  2. Local decision fallback records one-time, TTL-bound, project/task-bound decisions.
  3. Smoke fixtures cover upstream install/probe, skill load, helpers, file bus, risk block, and status.
  4. Coverage matrix separates upstream-native, adapter-provided, and deferred capabilities.
  5. Handoff orders remote adapter, audit hardening, isolation, and optional product extension work.
**Plans**: 5 plans

Plans:
- [x] 12-01-PLAN.md — Safety rulebook and durable audit foundation
- [x] 12-02-PLAN.md — Local decision fallback and L3/L4 blocking integration
- [x] 12-03-PLAN.md — Smoke runner infrastructure, `orch-verify`, and docs fixture
- [x] 12-04-PLAN.md — Documentation, coverage matrix, and handoff alignment
- [x] 12-05-PLAN.md — Functional smoke fixtures for safety and file-bus behavior

## Progress

**Execution Order:**
Phases execute in numeric order: 8 → 9 → 10 → 11 → 12

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 8. Legacy CLI Shell Baseline | v1.1 | 1/1 | Complete / superseded | 2026-04-25 |
| 9. Upstream Hermes Agent Baseline | v1.1 | 1/1 | Complete | 2026-04-25 |
| 10. Orchestra Package Installer & Skills Layout | v1.1 | 1/1 | Complete | 2026-04-25 |
| 11. Project Bootstrap, tmux Runtime & File Bus | v1.1 | 3/3 | Complete | 2026-04-25 |
| 12. Risk Decisions, Verification & Handoff | v1.1 | 5/5 | Complete    | 2026-04-25 |

## Archives

- [v1.0 roadmap archive](milestones/v1.0-ROADMAP.md)
- [v1.0 requirements archive](milestones/v1.0-REQUIREMENTS.md)
- [v1.0 audit](milestones/v1.0-MILESTONE-AUDIT.md)
- [v1.0 phase artifacts](milestones/v1.0-phases/)
