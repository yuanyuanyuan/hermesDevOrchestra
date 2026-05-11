# Hermes Dev Orchestra

## What This Is

Hermes Dev Orchestra 是一套“单人多项目 AI 开发编排系统”的产品、规格与原型实现项目。v1.0 已完成可交付规格包；v1.1 改为基于社区 `NousResearch/hermes-agent` 实现，而不是独立重写新的 Hermes Agent。v1.3 现已把 Hermes Agent 原生工作流的 MVP 纵向切片落地：官方能力边界、项目级 profiles/overrides、外部 CLI 引擎协议、Kanban 路由、风险护栏、worker 生命周期和基础可观测性都已有可验证实现；下一里程碑转向完整闭环。

## Core Value

用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。

Architecture boundary: "10x" means lower coordination overhead across multiple projects for one developer; v1.2 does not promise same-project parallel Codex execution, team-scale concurrency, or AI-factory throughput. Same-project parallelism is out of scope for v1.2 and would require a separate design covering JSONL/event bus semantics, per-task file namespaces, per-task locks, worktrees or per-task branches, and merge/review arbitration.

## Requirements

### Validated

- [x] 定义 v1 主用户场景：单人多项目开发，优先支持随时追加任务，同时保留批量任务和无人值守扩展空间。Validated in Phase 1 and Phase 4.
- [x] 定义主入口：SSH/Hermes CLI 是必需入口，远程通知/决策通过抽象 Remote Decision Channel 扩展，不绑定 Telegram。Validated in Phase 1, Phase 2, and Phase 6.
- [x] 定义三层代理职责：Hermes 负责编排和升级，Claude Code 负责技术监督/架构决策/代码审查，Codex 负责实际实现/测试/重构。Validated in Phase 1 and Phase 5.
- [x] 定义 per-project 文件总线协议，包括任务、问题、决策、升级、执行结果和审查结果文件的写入者、读取者、格式和状态流转。Validated in Phase 3.
- [x] 定义多项目隔离与并行规则，包括项目命名、tmux 会话命名、任务前缀、轮询策略、阻塞项目让路机制。Validated in Phase 4.
- [x] 定义三级风险升级机制，包括一般技术决策、架构/安全相关决策、系统级危险操作的处理层级和用户确认规则。Validated in Phase 5 and Phase 6.
- [x] 定义可交付规格包结构，包括安装流程规格、命令契约、配置文件说明、故障排查、安全最佳实践和验收清单。Validated across Phases 1–7.
- [x] 定义后续实施 roadmap，使规格可以直接转入分阶段开发。Validated in Phase 7.
- [x] 基于 `https://github.com/NousResearch/hermes-agent` 安装、固定版本并验证本地 `hermes` 入口。Validated in Phase 9.
- [x] 将本仓库代码限制为上游 Hermes Agent 的适配层、skills、配置模板、tmux/文件总线 glue 和验证脚本；独立 Node CLI runtime 已删除。Validated in Phase 9.
- [x] 将 Dev Orchestra SOUL、4 个 skills、4 层目录根、Claude hooks 模板和 `orch-*` helper 安装路径落成上游 Hermes Agent 可加载的实现包。Validated in Phase 10.
- [x] 支持项目初始化、Claude/Codex tmux 会话启动、任务写入、问题转发、审查结果回收和 per-project 文件总线 runtime。Validated in Phase 11.
- [x] 保持 L3/L4 决策显式用户审批，不允许 timeout 或 fallback 自动批准。Validated in Phase 12.
- [x] 通过 smoke/fixture 检查证明上游集成范围，并输出下一里程碑 handoff。Validated in Phase 12.
- [x] 用可执行证据验证 phase 19 文档中引用的 Hermes 官方能力，并在实现前钉死官方边界与本地增量边界。Validated in Phase 20.
- [x] 落成 8 个工作流 profile、项目级 override 合并能力，以及多 project board 的基础隔离约定。Validated in Phase 21.
- [x] 在 Hermes 调度层之上补齐外部 CLI 引擎协议、无状态上下文累积和角色调用契约。Validated in Phase 22 and Phase 23.
- [x] 用 Kanban 状态机替换旧文件总线路由，打通 PM/Researcher/Orchestrator/Worker 的 block-resume 交接。Validated in Phase 23.
- [x] 落成风险策略、只读审查护栏、worker cleanup/timeout、结构化 handoff、基础可观测性和 MVP 端到端验收。Validated in Phases 24-25.

### Active

- [ ] 完成 curator 驱动的跨项目 learning 晋升、冲突 warning、删除传播和人工复审闭环。
- [ ] 完成滑动窗口背压、死锁升级、SRE-Observer 结构化 RCA 与故障通知闭环。
- [ ] 完成 dev/test → staging → production 三层部署、验证门控、UAT 和 production 审批。
- [ ] 完成部署回滚、git tag、结构化部署报告与完整发布审计链路。

### Out of Scope

- 绑定 Telegram 作为唯一远程通道 — v1 只定义 Remote Decision Channel 抽象接口与行为。
- 将能力集成进 `gbrain` — 当前目标是上游 Hermes Agent 适配包，不做现有项目集成。
- 面向小团队协作或 AI 工厂高吞吐 — v1 聚焦单人多项目开发与远程决策。
- 自动批准 L3/L4 高风险操作 — 危险与紧急操作必须阻塞并等待用户明确确认。
- 高级 curator 跨项目语义合并、冲突仲裁和 learning 删除传播策略 — 延后到 v1.4 完整实现。
- staging/production UAT、分层部署回滚和 SRE 自动根因分析闭环 — 延后到 v1.4 完整实现。

## Context

已有输入资料位于 `docs/orchestra/`，包括：

- `README.md`：描述多项目 AI 开发编排系统、三层代理架构、文件通信总线、三级决策流转、多项目管理、部署步骤、日常使用、配置文件、故障排查、安全最佳实践和扩展路线。
- `hermes/SOUL.md`：定义 Hermes 顶层编排器人格，强调“管理者而非编码者”、信任 Claude 技术决策、只在危险/产品级问题上升级用户、多项目隔离和审计记录。
- `skills/dev-orchestra/SKILL.md`：定义主编排技能，包括项目初始化、启动 Claude/Codex 会话、任务分发、Codex 疑问处理、危险决策升级和多项目并行管理。
- `skills/claude-supervisor/SKILL.md`：定义 Claude Code 监督者职责，包括审查 Codex 输出、处理技术疑问、标记高风险操作和写入决策文件。
- `skills/codex-executor/SKILL.md`：定义 Codex 执行者职责，包括读取任务、实现代码、写测试、遇到疑问暂停并写入问题文件、完成后写入结果文件。
- `skills/escalation-handler/SKILL.md`：定义风险守门员职责，包括 L1-L4 风险分级、用户决策请求、审计日志和超时处理。
- `scripts/setup.sh`：提供无 sudo Ubuntu 环境下的安装脚本草案，包括依赖检查、目录创建、skills 安装、SOUL.md 安装、Claude 配置模板和 `orch-*` 辅助命令。
- `claude-config/settings.json`：提供 Claude Code hooks 配置模板，将权限请求、通知、会话开始和停止事件写入 `/tmp/hermes-orchestra/claude-events.jsonl`。

v1.0 规格阶段的用户输入与决策：

- v1.0 GSD 项目目标是“只整理成产品/技术规格”，不直接实现最终工具。
- v1 完成标准是“可交付规格包”，需要明确安装流程、命令契约、文件总线协议、风险升级协议。
- 核心用户场景是“单人多项目开发 + 远程决策”。
- v1 优先保证“随时追加任务”，同时保留批量任务、夜间无人值守和混合模式扩展。
- SSH/Hermes CLI 是必须入口；远程通知/决策通道需要抽象，不绑定 Telegram。

## Constraints

- **Runtime**: 目标运行环境是局域网 Ubuntu 开发机，用户通过 Windows SSH 远程接入 — 规格必须覆盖 SSH 断连、tmux 会话持久和无 sudo 安装。
- **Privileges**: 目标环境可能无 sudo 权限 — 安装、配置和运行路径必须优先使用 `$HOME`、`~/.hermes-orchestra/`、`~/.hermes/` 和 `/tmp/hermes-orchestra/`。
- **Agent Stack**: 方案围绕社区 `NousResearch/hermes-agent`、Claude Code CLI、Codex CLI 和 tmux — 规格需明确版本假设、认证要求、上游边界和各自职责。
- **Safety**: L3/L4 风险不得自动批准 — 规格必须定义阻塞式确认、审计日志、默认安全动作和可恢复策略。
- **Isolation**: 多项目必须隔离 — 每个项目应拥有独立 board、workspace、profile override 和状态上下文。
- **Remote Channel**: 远程通知/决策不能绑定 Telegram — v1 使用 Remote Decision Channel 抽象，具体平台作为适配器。
- **Deliverable**: 下一里程碑的交付物是 Hermes Agent 原生工作流的完整闭环：在已完成的 v1.3 MVP 上补齐 curator、死锁/RCA、部署/UAT 和发布审计，而不是重新设计另一套 runtime。

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| v1 先做可交付规格包，不直接实现工具 | 用户明确选择“只整理成产品/技术规格”，且现有方案需要先规范边界、协议和验收标准 | Accepted in Phase 1 |
| 主用户为单人多项目开发者 | 用户选择“自己单人多项目开发 + 远程手机决策”，不是小团队或 AI 工厂场景 | Accepted in Phase 1 |
| v1 优先支持随时追加任务 | 用户选择混合模式，但优先保证“随时追加任务” | Accepted in Phase 4 |
| SSH/Hermes CLI 是必需入口 | 用户明确“ssh 是要的”，因此 CLI 主链路必须可用 | Accepted in Phase 2 |
| 远程决策通道抽象化 | 用户不想绑定 Telegram，选择先抽象接口、不选具体实现 | Accepted in Phase 6 |
| 暂不集成进 `gbrain` | 用户选择规格包目标，而非“集成进现有 gbrain 项目” | Accepted in Phase 1 |
| 基于社区 Hermes Agent 实现 | 用户确认原方案要求基于 `NousResearch/hermes-agent`，而不是独立实现新的 Hermes Agents | Accepted in direction correction on 2026-04-25 |
| phase 19 设计包拆成两个执行 milestone | `gsd-new-milestone` 只允许一个当前 milestone，因此将 MVP 和完整实现分层能同时满足规划与执行语义 | Accepted on 2026-05-10 |
| 执行 phase 编号从 20 开始 | `.planning/phases/19-hermes-workflow-design/` 已作为设计源目录存在，复用 19 会与后续 GSD phase 目录冲突 | Accepted on 2026-05-10 |

## Current State

v1.1 is complete. Phases 9-12 validated the upstream Hermes Agent baseline, package installer layer, local project runtime slice, risk rulebook enforcement, SSH/local decision fallback, durable Audit JSONL, smoke verification fixtures, coverage matrix, and next-milestone handoff.

v1.2 Phase 18 clarified architecture bounds across `.planning/SPEC.md`, `specs/file-bus.md`, `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md`, and `.planning/PROJECT.md`. The fixed Runtime bus is documented as one active task slot per project, same-project parallelism is out of scope for v1.2, and the "10x" claim is limited to single-developer multi-project coordination.

Phase 19 produced a full Hermes-native workflow design package under `.planning/phases/19-hermes-workflow-design/`. On 2026-05-11, commit `3976c42` added the External CLI Engine architecture and standardized the design around “Hermes scheduling + external CLI execution”. That package remains the source for two execution milestones: v1.3 covered the MVP implementation path, and v1.4 remains the full implementation path. Execution phase numbering starts at 20 so the phase 19 design directory remains a stable reference set.

v1.3 shipped on 2026-05-11. Phases 20-25 landed the official/local capability boundary lock, project-scoped profile assembly, the `hermes-role-engine/v1` protocol, Kanban-native routing, canonical risk policy and role guardrails, task-level timeout/reclaim, structured handoff validation, hook-based observability, environment snapshots, and one MVP acceptance chain. Milestone closeout stats: 6 phases, 6 plans, timeline 2026-05-10 to 2026-05-11, and roughly 29 files changed with +1860/-175 diff in the active worktree during closeout. The only inherited blocker is the unresolved `upstream-status` runtime pin mismatch.

## Milestone: v1.1 Upstream Hermes Agent Integration

**Status:** ✅ Complete (2026-04-25)
**Phases:** 9–12
**Goal:** 基于社区 `NousResearch/hermes-agent` 实现单人多项目开发编排适配包，把原方案中的 Hermes Agent 顶层编排器、SOUL/skills、Claude/Codex tmux 会话、文件总线和风险决策 fallback 落成可验证的本地纵向切片。

**Delivered:**
- Upstream Hermes Agent install/probe with pinned commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`.
- SOUL.md and 4 custom skills installed into the upstream Hermes Agent skill layout.
- `orch-init`, `orch-start`, `orch-stop`, and `orch-status` helpers that wrap upstream Hermes Agent plus tmux.
- Per-project file bus connecting Hermes Agent, Claude Supervisor, and Codex Executor.
- Risk rulebook, local decision fallback, smoke fixtures, integration docs, and handoff for remote adapters.

## Latest Shipped Milestone: v1.3 Hermes 原生工作流 MVP 实现

**Status:** ✅ Shipped (2026-05-11)  
**Phases:** 20–25

**Delivered:**
- Capability-verification matrix and official/local boundary lock for the phase 19 design package.
- Project-scoped profiles, repo-local overrides, and baseline multi-project isolation.
- `hermes-role-engine/v1` external CLI engine contract plus failure normalization.
- Kanban-native routing, parent-linked handoff metadata, and metadata-first block/resume.
- Canonical `risk-policy.yaml`, reviewer/orchestrator guardrails, and implementer block contract.
- Timeout/reclaim, structured handoff hardening, sidecar observability, environment snapshots, conservative backpressure, and MVP acceptance evidence.

**Residual issue:** `rtk make test` still inherits the known `upstream-status` pin mismatch and is not globally green yet.

## Next Milestone Goals

- 完成 curator 驱动的跨项目 learning 晋升、冲突警告、删除传播与人工复审闭环。
- 完成滑动窗口背压、死锁升级、SRE-Observer 结构化 RCA 与故障通知闭环。
- 完成 dev/test → staging → production 三层部署、验证门控、UAT 和 production 审批。
- 完成部署回滚、git tag、结构化部署报告与完整发布审计链路。

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-11 after shipping v1.3 milestone*
