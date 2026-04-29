# Roadmap: Hermes Dev Orchestra

## Milestones

- **v1.0 Specification Package** — Phases 1-7 (shipped 2026-04-25)
- **v1.1 Upstream Hermes Agent Integration** — Phases 8-12 (shipped 2026-04-25)
- **v1.2 Hermes Dev Orchestra 规范化与迁移** — Phases 13-18 (ready for milestone completion)

## Phases

<details>
<summary>v1.0 Specification Package (Phases 1-7) — SHIPPED 2026-04-25</summary>

- [x] Phase 01: Scope, Package Coverage & Authority (1/1 plans) — completed 2026-04-25
- [x] Phase 02: Runtime, Installation & Command Contracts (1/1 plans) — completed 2026-04-25
- [x] Phase 03: File Bus, Decision Envelope, State & Audit (1/1 plans) — completed 2026-04-25
- [x] Phase 04: Multi-Project Scheduling & Isolation (1/1 plans) — completed 2026-04-25
- [x] Phase 05: Agent Protocol, Challenge & Evidence (1/1 plans) — completed 2026-04-25
- [x] Phase 06: Risk Rulebook & Remote Decision Contract (1/1 plans) — completed 2026-04-25
- [x] Phase 07: Recovery, Observability, Verification & Handoff (1/1 plans) — completed 2026-04-25

</details>

<details>
<summary>v1.1 Upstream Hermes Agent Integration (Phases 8-12) — SHIPPED 2026-04-25</summary>

- [x] Phase 8: Legacy CLI Shell Baseline — superseded scaffolding
- [x] Phase 9: Upstream Hermes Agent Baseline — install/probe/pin upstream
- [x] Phase 10: Orchestra Package Installer & Skills Layout — SOUL/skills/orch-* helpers
- [x] Phase 11: Project Bootstrap, tmux Runtime & File Bus — per-project runtime
- [x] Phase 12: Risk Decisions, Verification & Handoff — safety rulebook and smoke fixtures

[Full v1.1 roadmap archive](milestones/v1.1-ROADMAP.md)

</details>

## v1.2 Hermes Dev Orchestra 规范化与迁移

**Goal:** 通过证据盘点和 gap audit，修复根目录可发现性，按需迁移目录结构，规范化规格体系和开发工作流。

- [x] **Phase 13: Evidence Audit & Discoverability** — 盘点仓库状态，修复根目录可发现性，生成路径引用清单。 (completed 2026-04-28)
- [x] **Phase 14: Migration & Submodule ADR** — 按需迁移目录，编写 upstream pin 方案 ADR。 (completed 2026-04-28)
- [x] **Phase 15: Specification System** — 建立 specs/ 派生文档体系，保持 `.planning/SPEC.md` canonical。 (completed 2026-04-28)
- [x] **Phase 16: Makefile & Dev Workflow** — 创建只引用真实测试的 Makefile，提供本地验证入口。 (completed 2026-04-28)
- [x] **Phase 17: Agent Rules Consolidation** — 合并 Agents 规则到 `AGENTS.md`，不覆盖现有内容。 (completed 2026-04-28)
- [x] **Phase 18: Architecture Bounds & Verification** — 明确 10x 压力边界，完成 milestone 验收。 (completed 2026-04-29)

---

## Phase Details

### Phase 13: Evidence Audit & Discoverability
**Goal:** 生成完整仓库状态快照和路径引用清单，在根目录创建指向增强层的显式索引。
**Depends on:** v1.1 completion
**Requirements:** DISC-01, DISC-02, MIGR-01
**Success Criteria:**
  1. `git status --short --branch` 输出已审查，当前变更已明确归属。
  2. 迁移前路径引用清单已完整输出并归档。
  3. 根目录存在显式索引文件指向增强层文档。
  4. `AGENTS.md` 保留现有 managed blocks，已追加 Dev Orchestra 目录定位说明。
**Plans:** 1/1 plans complete

### Phase 14: Migration & Submodule ADR
**Goal:** 基于 Phase 13 的证据决定是否迁移目录；编写并决策 upstream pin 方案 ADR。
**Depends on:** Phase 13
**Requirements:** MIGR-02, UPST-01, UPST-02
**Success Criteria:**
  1. 旧路径引用清单已处理（迁移后零残留，或保留并记录不迁移的理由）。
  2. 若执行迁移，`git mv` 后所有测试仍通过。
  3. ADR 比较了四种 upstream pin 方案。
  4. 若选择 submodule，暂存区验证只包含 `.gitmodules` 和 `hermes-agent` gitlink。
**Plans:** 1/1 plans complete

### Phase 15: Specification System
**Goal:** 建立 specs/ 派生文档体系，确保 `.planning/SPEC.md` 的 canonical 地位不受挑战。
**Depends on:** Phase 14
**Requirements:** SPEC-01, SPEC-02
**Success Criteria:**
  1. 每个 `specs/*.md` 文件都声明了 source、consumer 和 drift check 方法。
  2. 每个派生 spec 至少有一个可失败的 conformance check。
  3. 没有当前 consumer 的 spec 未被创建。
  4. `specs/README.md` 索引存在，说明与 `.planning/SPEC.md` 的主从关系。
**Plans:** 1/1 plans complete

### Phase 16: Makefile & Dev Workflow
**Goal:** 创建只引用真实存在测试的 Makefile，提供本地验证入口。
**Depends on:** Phase 15
**Requirements:** DEV-01, DEV-02, DEV-03, DEV-04
**Success Criteria:**
  1. `make test-unit` 调用现有 smoke/unit fixtures 且通过。
  2. `make test-risk` 调用三个风险审批测试且通过。
  3. `make lint-json` 验证所有 JSON 文件语法正确。
  4. `make lint-shell` 在无 shellcheck 时明确 skip，不返回伪失败。
  5. `make upstream-status` 正确报告 repo-local 和 runtime pin 状态。
  6. 不存在的 target 未出现在 Makefile 中。
**Plans:** 1/1 plans complete

### Phase 17: Agent Rules Consolidation
**Goal:** 在 `AGENTS.md` 中追加 Dev Orchestra 规则和 Agent 职责边界，不覆盖现有 managed sections。
**Depends on:** Phase 16
**Requirements:** AGNT-01, AGNT-02
**Success Criteria:**
  1. `AGENTS.md` 中的现有规则仍然完整。
  2. 已追加 "Dev Orchestra Package Boundary" 和 "Agent Role Boundary" 章节。
  3. 若创建 `CLAUDE.md`，它指向 `AGENTS.md` 和 `.planning/SPEC.md` 作为权威。
  4. 合并验证通过。
**Plans:** 1/1 plans complete

### Phase 18: Architecture Bounds & Verification
**Goal:** 明确 10x 压力边界限制，完成 milestone 验收。
**Depends on:** Phase 17
**Requirements:** ARCH-01, ARCH-02
**Success Criteria:**
  1. 文档明确固定文件名 file bus 表示单活动任务限制。
  2. 若需支持多任务并行，文档描述另起设计方案并明确不属于 v1.2 范围。
  3. 10x 承诺被限定为"单人多项目，每项目单活动任务"。
  4. 所有 v1.2 需求通过验收验证。
**Plans:** 1/1 plans complete

---

## Progress

**Execution Order:**
Phases execute in numeric order: 13 → 14 → 15 → 16 → 17 → 18

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 13. Evidence Audit & Discoverability | v1.2 | 1/1 | Complete    | 2026-04-28 |
| 14. Migration & Submodule ADR | v1.2 | 1/1 | Complete    | 2026-04-28 |
| 15. Specification System | v1.2 | 1/1 | Complete    | 2026-04-28 |
| 16. Makefile & Dev Workflow | v1.2 | 1/1 | Complete | 2026-04-28 |
| 17. Agent Rules Consolidation | v1.2 | 1/1 | Complete    | 2026-04-28 |
| 18. Architecture Bounds & Verification | v1.2 | 1/1 | Complete | 2026-04-29 |

---

## Backlog

### Phase 999.1: Supervisor Execution Audit Gap — Codex sandbox 失败后 Supervisor 直接执行，审计日志断流 (BACKLOG)

**Goal:** [Captured for future planning] 修复 Supervisor 职责分离违规、审计日志完整性、文件总线状态一致性。
**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

### Phase 999.2: Collaborative Planning Mode — 多轮对抗式协作规划协议 (BACKLOG)

**Goal:** [Captured for future planning] 引入 adversarial collaborative planning mode，让 Codex 和 Claude 在任务执行前进行多轮讨论并产出共识计划。
**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

---

## Archives

- [v1.0 roadmap archive](milestones/v1.0-ROADMAP.md)
- [v1.0 requirements archive](milestones/v1.0-REQUIREMENTS.md)
- [v1.0 audit](milestones/v1.0-MILESTONE-AUDIT.md)
- [v1.0 phase artifacts](milestones/v1.0-phases/)
- [v1.1 roadmap archive](milestones/v1.1-ROADMAP.md)
