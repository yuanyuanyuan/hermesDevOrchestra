# Roadmap: Hermes Dev Orchestra

## Milestones

- **v1.0 Specification Package** — Phases 1-7 (shipped 2026-04-25)
- **v1.1 Upstream Hermes Agent Integration** — Phases 8-12 (shipped 2026-04-25)
- **v1.2 Hermes Dev Orchestra 规范化与迁移** — Phases 13-18 (completed 2026-04-29)
- **v1.3 Hermes 原生工作流 MVP 实现** — Phases 20-25 (planned)
- **v1.4 Hermes 原生工作流完整实现** — next milestone preview captured below

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

## v1.3 Hermes 原生工作流 MVP 实现

**Goal:** 以 `.planning/phases/19-hermes-workflow-design/` 非归档文档为来源，先把 Hermes Agent 原生工作流的 MVP 纵向切片落地：验证官方能力边界、落成 profile/override、多项目基础隔离、Kanban 路由、风险护栏、worker 生命周期与基础可观测性。

- [x] **Phase 20: Capability Verification & Boundary Lock** — 验证 Hermes 官方能力，锁定哪些设计点属于官方覆盖、哪些必须本地实现。
- [ ] **Phase 21: Profiles, Overrides & Board Isolation** — 落成 8 个 active profiles、3 个 reserved profiles、项目级 override 和多项目基础隔离约定。
- [ ] **Phase 22: State-Machine Routing & Kanban Handoff** — 将需求拆解、角色派发、block-resume 交接全部切到 Kanban 状态机。
- [ ] **Phase 23: Risk Policy & Role Guardrails** — 落成 L1/L2/L3 风险策略、Reviewer/Orchestrator allowlist、只读终端护栏和 Implementer block 契约。
- [ ] **Phase 24: Worker Lifecycle, Cleanup & Admission Control** — 落成 timeout、worktree cleanup、structured handoff 与基础背压准入控制。
- [ ] **Phase 25: Observability, Env Snapshot & MVP Acceptance** — 落成 hook 级 traces、环境快照、MVP 端到端验证和 v1.4 handoff。

---

## Phase Details

### Phase 20: Capability Verification & Boundary Lock
**Goal:** 为 phase 19 设计包引用的 Hermes 官方能力建立可执行证据，并在实现前锁定官方边界与本地增量边界。  
**Depends on:** v1.2 completion  
**Requirements:** VFY-01, VFY-02
**Success Criteria:**
  1. capability-verification matrix 覆盖 Kanban、Profile、Dispatcher、Curator、Memory、Gateway 和 hooks。
  2. 每个 phase 19 文档里的“官方能力”声明都有 verified / unsupported / local-extension 标记。
  3. 所有 unsupported 声明都已回写为可追踪的本地需求，再进入实现阶段。
**Plans:** 1/1 plans complete

### Phase 21: Profiles, Overrides & Board Isolation
**Goal:** 落成可执行的 profile 包装、项目级 override 合并规则和多项目基础隔离约定。  
**Depends on:** Phase 20  
**Requirements:** PROF-01, PROF-02, FLOW-02, MEM-01
**Success Criteria:**
  1. 全局 profile 与项目 override 的合并路径已定义且不会污染 `~/.hermes/profiles/`。
  2. 8 个 active profiles 与 3 个 reserved profiles 的 toolsets/SOUL 边界已落在仓库产物中。
  3. board、workspace、profile 和 memory 命名约定已防止多项目串线。
**Plans:** 0/1 plans complete

### Phase 22: State-Machine Routing & Kanban Handoff
**Goal:** 用 Kanban 状态机替换旧文件总线路由，打通 PM、Orchestrator 和 Worker 的主链路交接。  
**Depends on:** Phase 21  
**Requirements:** ROUTE-01, ROUTE-02
**Success Criteria:**
  1. PM 可以从需求文档生成带 parents 的任务图并分配到目标 profile。
  2. Worker 的澄清、阻塞、恢复和完成流全部通过 Kanban 原语完成。
  3. 至少一个从需求 → 实现 → 审查/测试的主链路可跑通且不依赖旧文件总线。
**Plans:** 0/1 plans complete

### Phase 23: Risk Policy & Role Guardrails
**Goal:** 落成风险策略、只读护栏和 Implementer 的显式 block 契约，防止角色越权。  
**Depends on:** Phase 22  
**Requirements:** SAFE-01, SAFE-02, SAFE-03
**Success Criteria:**
  1. 风险策略 YAML 经 `pre_tool_call` hook 拦截后，L3 操作无法自动通过。
  2. Reviewer 和 Orchestrator 的 allowlist/tool guards 能阻止 shell 写操作或代码执行越权。
  3. Implementer 在架构不确定、外部依赖异常、关键测试失败时会显式 `kanban_block`。
**Plans:** 0/1 plans complete

### Phase 24: Worker Lifecycle, Cleanup & Admission Control
**Goal:** 落成 worker timeout、dirty cleanup、structured handoff 与基础背压控制。  
**Depends on:** Phase 23  
**Requirements:** EXEC-01, EXEC-02, EXEC-03, FLOW-01
**Success Criteria:**
  1. worker task metadata 明确包含 `expected_duration_max`，超时后可触发回收和重派。
  2. crash、timeout 或 cancel 后，worktree 能恢复到任务开始前的干净状态。
  3. handoff metadata 有 schema 约束，且下游消费路径以 untrusted input 处理。
  4. dispatcher 能依据 ready-depth 做基础限流，避免上游把审查/测试队列压垮。
**Plans:** 0/1 plans complete

### Phase 25: Observability, Env Snapshot & MVP Acceptance
**Goal:** 落成 hook 级 trace、环境快照与 MVP 验收，为 v1.4 提供明确 handoff。  
**Depends on:** Phase 24  
**Requirements:** OBS-01, OBS-02
**Success Criteria:**
  1. `post_tool_call` 和 `on_session_end` traces 已落到可查询存储，不修改 Hermes 核心。
  2. worker spawn 时自动采集 `git status`、`df -h` 前 5 行和 `hermes status`。
  3. 至少一个 MVP 端到端场景通过验收，覆盖多角色 handoff 与基础多项目隔离。
  4. v1.4 handoff 已明确记录 curator 语义、SRE RCA 和 deploy/UAT 延后项。
**Plans:** 0/1 plans complete

---

## Progress

**Execution Order:**  
Phases execute in numeric order: 20 → 21 → 22 → 23 → 24 → 25

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 20. Capability Verification & Boundary Lock | v1.3 | 1/1 | Complete | 2026-05-10 |
| 21. Profiles, Overrides & Board Isolation | v1.3 | 0/1 | Planned | — |
| 22. State-Machine Routing & Kanban Handoff | v1.3 | 0/1 | Planned | — |
| 23. Risk Policy & Role Guardrails | v1.3 | 0/1 | Planned | — |
| 24. Worker Lifecycle, Cleanup & Admission Control | v1.3 | 0/1 | Planned | — |
| 25. Observability, Env Snapshot & MVP Acceptance | v1.3 | 0/1 | Planned | — |

---

## v1.4 Hermes 原生工作流完整实现（Preview）

**Goal:** 在 v1.3 MVP 的主链路稳定后，补全 curator/self-evolution、死锁升级、SRE RCA、三层部署与 UAT/production 审批，形成完整的 Hermes-native 工作流闭环。

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
