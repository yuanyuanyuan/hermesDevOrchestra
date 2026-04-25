# Hermes Dev Orchestra

## What This Is

Hermes Dev Orchestra 是一套“单人多项目 AI 开发编排系统”的产品、规格与原型实现项目。v1.0 已完成可交付规格包；v1.1 开始把规格落成可运行的本地 Hermes CLI 原型，优先证明命令入口、文件总线、状态、审计、doctor/preflight 与本地决策 fallback。

## Core Value

用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。

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

### Active

- [ ] 实现本地可运行的 hermes CLI 原型入口。
- [ ] 将 v1.0 的路径、文件总线、状态、审计和命令结果 envelope 落成最小实现。
- [ ] 支持项目注册、任务追加、状态查看、doctor/preflight 和本地决策 fallback。
- [ ] 保持 L3/L4 决策显式用户审批，不允许 timeout 或 fallback 自动批准。
- [ ] 通过 smoke/fixture 检查证明原型范围，并输出下一里程碑 handoff。

### Out of Scope

- 绑定 Telegram 作为唯一远程通道 — v1 只定义 Remote Decision Channel 抽象接口与行为。
- 将能力集成进 `gbrain` — 当前目标是独立规格，不做现有项目集成。
- 面向小团队协作或 AI 工厂高吞吐 — v1 聚焦单人多项目开发与远程决策。
- 自动批准 L3/L4 高风险操作 — 危险与紧急操作必须阻塞并等待用户明确确认。

## Context

已有输入资料位于 `docs/hermes-dev-orchestra/`，包括：

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
- **Agent Stack**: 方案围绕 Hermes Agent、Claude Code CLI、Codex CLI 和 tmux — 规格需明确版本假设、认证要求和各自职责边界。
- **Safety**: L3/L4 风险不得自动批准 — 规格必须定义阻塞式确认、审计日志、默认安全动作和可恢复策略。
- **Isolation**: 多项目必须隔离 — 每个项目应拥有独立 tmux 会话、文件总线目录、任务前缀和状态文件。
- **Remote Channel**: 远程通知/决策不能绑定 Telegram — v1 使用 Remote Decision Channel 抽象，具体平台作为适配器。
- **Deliverable**: v1.1 交付物是本地 Hermes CLI 原型、验证夹具、文档和实施 handoff — 不修改现有 `gbrain` 代码，不实现生产级最终工具。

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| v1 先做可交付规格包，不直接实现工具 | 用户明确选择“只整理成产品/技术规格”，且现有方案需要先规范边界、协议和验收标准 | Accepted in Phase 1 |
| 主用户为单人多项目开发者 | 用户选择“自己单人多项目开发 + 远程手机决策”，不是小团队或 AI 工厂场景 | Accepted in Phase 1 |
| v1 优先支持随时追加任务 | 用户选择混合模式，但优先保证“随时追加任务” | Accepted in Phase 4 |
| SSH/Hermes CLI 是必需入口 | 用户明确“ssh 是要的”，因此 CLI 主链路必须可用 | Accepted in Phase 2 |
| 远程决策通道抽象化 | 用户不想绑定 Telegram，选择先抽象接口、不选具体实现 | Accepted in Phase 6 |
| 暂不集成进 `gbrain` | 用户选择规格包目标，而非“集成进现有 gbrain 项目” | Accepted in Phase 1 |

## Current State

v1.1 is active. The project is moving from the shipped v1.0 specification package into a runnable local Hermes CLI prototype. The milestone intentionally implements a minimum safe vertical slice before live Claude/Codex process orchestration.

## Current Milestone: v1.1 Hermes CLI Prototype

**Goal:** 实现一个本地可运行的 Hermes CLI 原型，把 v1.0 规格中的核心路径、项目注册、任务追加、状态查看、doctor/preflight、文件总线和本地决策 fallback 落成可验证的最小纵向切片。

**Target features:**
- Local hermes command shell with help/version and structured result envelope.
- Four-layer path resolver, state store, JSON/JSONL file bus, and audit separation.
- Project registration, task append, status read model, doctor/preflight, risk rulebook, and local decision fallback.
- Smoke fixtures, prototype documentation, coverage matrix, and handoff for live agent orchestration.


## Next Milestone Goals

- Execute Phase 8 first to establish the CLI shell and command envelope.
- Keep live Claude/Codex runner orchestration out of scope until the local CLI, bus, state, and safety invariants pass verification.
- Preserve v1.0 safety boundaries while introducing implementation code.


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
*Last updated: 2026-04-25 after starting v1.1 milestone*
