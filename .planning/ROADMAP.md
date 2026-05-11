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

[Full v1.3 roadmap archive](milestones/v1.3-ROADMAP.md)
[v1.3 requirements archive](milestones/v1.3-REQUIREMENTS.md)
[v1.3 milestone audit](milestones/v1.3-MILESTONE-AUDIT.md)

</details>

## v1.4 Hermes 原生工作流完整实现（Planned）

**Goal:** 在 v1.3 的外部 CLI 引擎基线与 MVP 主链路稳定后，补全 curator/self-evolution、死锁升级、SRE RCA、三层部署与 UAT/production 审批，形成完整的 Hermes-native 工作流闭环。

- **Scope 1: Curator & Learnings** — 语义相似聚类、冲突 warning、删除传播、显式 cross-project 晋升审批。
- **Scope 2: Advanced Scheduling & RCA** — 滑动窗口背压、死锁升级、SRE-Observer 结构化根因报告、QA/deploy 故障告警与责任归因。
- **Scope 3: Deployment & Release** — dev/test → staging → production 分层部署、验证门控、UAT、production 批准、回滚与 git tag。
- **Completion signal:** 一个真实项目能从需求澄清一路流到生产发布，并保留完整审计、RCA 和发布报告链路。

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

### Phase 20 carry-forward: Gateway delivery closure (BACKLOG)

**Goal:** [Captured from Phase 20] 为 Hermes Gateway 建立一个可复现的最小消息投递验证路径，消除 `hermes status` / `hermes gateway status` / `hermes gateway list` 在 2026-05-10 暴露的服务态分裂，并验证至少一种平台的真实通知闭环。  
**Requirements:** TBD  
**Plans:** 0 plans

Plans:
- [ ] Promote a gateway-delivery verification phase from `GATEWAY-DELIVERY-CLOSURE`

### Phase 20 carry-forward: skill_manage runtime boundary (BACKLOG)

**Goal:** [Captured from Phase 20] 明确 `skill_manage` 在当前 Hermes runtime 中的可验证边界：要么增加一个可复现的运行时 probe，要么正式把“自动创建 skill + 自动演进 workflow”固定为本地 orchestration 逻辑。  
**Requirements:** TBD  
**Plans:** 0 plans

Plans:
- [ ] Promote a skill-manage boundary phase from `SKILL-MANAGE-WORKFLOW-AUTOMATION`

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
