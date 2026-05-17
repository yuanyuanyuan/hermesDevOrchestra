# Roadmap: Hermes Dev Orchestra

## Milestones

- ✅ **v1.0 Specification Package** — Phases 1-7 (shipped 2026-04-25)
- ✅ **v1.1 Upstream Hermes Agent Integration** — Phases 8-12 (shipped 2026-04-25)
- ✅ **v1.2 Hermes Dev Orchestra 规范化与迁移** — Phases 13-18 (completed 2026-04-29)
- ✅ **v1.3 Hermes 原生工作流 MVP 实现** — Phases 20-25 (shipped 2026-05-11)
- 📋 **v1.4 Hermes 原生工作流完整实现** — next milestone preview captured below

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

<details>
<summary>✅ v1.1 Upstream Hermes Agent Integration (Phases 8-12) — SHIPPED 2026-04-25</summary>

- [x] Phase 8: Legacy CLI Shell Baseline — superseded scaffolding
- [x] Phase 9: Upstream Hermes Agent Baseline — install/probe/pin upstream
- [x] Phase 10: Orchestra Package Installer & Skills Layout — SOUL/skills/orch-* helpers
- [x] Phase 11: Project Bootstrap, tmux Runtime & File Bus — per-project runtime
- [x] Phase 12: Risk Decisions, Verification & Handoff — safety rulebook and smoke fixtures

[Full v1.1 roadmap archive](milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.3 Hermes 原生工作流 MVP 实现 (Phases 20-25) — SHIPPED 2026-05-11</summary>

- [x] Phase 20: Capability Verification & Boundary Lock — capability matrix and official/local boundary lock
- [x] Phase 21: Profiles, Overrides & Board Isolation — project-scoped profiles, overrides, and isolation
- [x] Phase 22: External CLI Engine Protocol & Role Invocation — `hermes-role-engine/v1` and failure normalization
- [x] Phase 23: Stateful Routing & Kanban Handoff — metadata-driven Kanban routing and handoff
- [x] Phase 24: Risk Policy & Role Guardrails — canonical policy, hook guardrails, implementer block contract
- [x] Phase 25: Worker Lifecycle, Observability & MVP Acceptance — timeout/reclaim, observability, structured handoff, MVP acceptance
- [x] Phase 25.1 (INSERTED): Documentation & DX Overhaul — 文档重写、安装指南、工具链脚本 (completed 2026-05-12)

[Full v1.3 roadmap archive](milestones/v1.3-ROADMAP.md)
[v1.3 requirements archive](milestones/v1.3-REQUIREMENTS.md)
[v1.3 milestone audit](milestones/v1.3-MILESTONE-AUDIT.md)

</details>

## v1.4 Hermes 原生工作流完整实现（Planned）

**Goal:** 在 v1.3 的外部 CLI 引擎基线与 MVP 主链路稳定后，补全 curator/self-evolution、死锁升级、SRE RCA、三层部署与 UAT/production 审批，移除遗留 file bus 代码，形成完整的 Hermes-native 工作流闭环。

- **Scope 1: Curator & Learnings** — 语义相似聚类（R7b）、冲突 warning（R7c）、删除传播（R7d）、显式 cross-project 晋升审批（R7e）、skill_manage 运行时边界确认。
- **Scope 2: Advanced Scheduling & RCA** — 滑动窗口背压（R18）、死锁升级（R17）、SRE-Observer 结构化根因报告（R21）、QA/deploy 故障告警与责任归因（R23, R24）、Gateway 消息投递闭环验证。
- **Scope 3: Deployment & Release** — dev/test → staging → production 分层部署（R25）、验证门控（R26）、UAT（R27）、production 批准（R28）、回滚（R29）与 git tag、结构化部署报告（R30）。
- **Scope 4: Dispatcher Migration & File Bus Removal** — 按 Phase 19 §4.4 + §5.1 设计，将调度核心从 `orch-bus-loop`（文件轮询 + tmux）迁移到 Hermes 原生 Kanban Dispatcher（嵌入 Gateway、SQLite 持久化、API 驱动）；迁移 9 个关键功能（任务派发、问题路由、决策恢复、review 路由、L3/L4 阻塞、role-engine handoff、active run 回收、背压暂停、review finalization）；重写 10 个测试脚本入口；移除 `orch-bus-loop`、`specs/file-bus.md`、BUS-01..06 规范、运行时 bus 文件目录、tmux 手动 spawn 逻辑；清理文档和测试中的 file bus 残留引用。详见 `orch-bus-loop` 调用链分析报告。
- **New Requirements:**
  - **R39 (Reviewer 只读终端代理):** 在 Hermes 层拦截 reviewer 的 terminal() 写操作，实现技术层面的只读约束（DESIGN 附录 C），作为 R8 的具体实现指导。
  - **R40 (PM 引擎澄清上限强制):** PM 引擎超过 15 轮澄清时强制生成 requirement_ready（REQUIREMENTS R36），防止无限澄清循环。
  - **R41 (E2E 验收闭环):** 至少一个真实项目能从需求澄清 → PM 拆解 → Research/POC → Implementer TDD → Reviewer 审查 → QA 验收 → DevOps 三层部署 → SRE 根因分析的完整链路走通（DESIGN §10）。
  - **R42 (Gateway 消息投递验证):** 为 Hermes Gateway 建立可复现的最小消息投递验证路径，至少一种平台的真实通知闭环可用（Phase 20 carry-forward）。
- **Completion signal:** 一个真实项目能从需求澄清一路流到生产发布，并保留完整审计、RCA 和发布报告链路；调度核心已迁移到 Hermes 原生 Kanban Dispatcher，file bus 代码已完全移除，所有 IPC 通过 Kanban 原生机制完成。

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

### Phase 20 carry-forward: Gateway delivery closure → PROMOTED to v1.4 R42

**Status:** Promoted to v1.4 Scope 2 as R42 (Gateway 消息投递验证).

### Phase 20 carry-forward: skill_manage runtime boundary → PROMOTED to v1.4 Scope 1

**Status:** Promoted to v1.4 Scope 1 (Curator & Learnings).

---

## Archives

- [v1.0 roadmap archive](milestones/v1.0-ROADMAP.md)
- [v1.0 requirements archive](milestones/v1.0-REQUIREMENTS.md)
- [v1.0 audit](milestones/v1.0-MILESTONE-AUDIT.md)
- [v1.0 phase artifacts](milestones/v1.0-phases/)
- [v1.1 roadmap archive](milestones/v1.1-ROADMAP.md)
- [v1.3 roadmap archive](milestones/v1.3-ROADMAP.md)
- [v1.3 requirements archive](milestones/v1.3-REQUIREMENTS.md)
- [v1.3 audit](milestones/v1.3-MILESTONE-AUDIT.md)
