# Hermes Dev Orchestra

## What This Is

Hermes Dev Orchestra 是一套“单人多项目 AI 开发编排系统”的产品与技术规格项目。它定义 Hermes Agent 作为顶层编排器，协调 Claude Code CLI 作为监督/决策/审查代理、Codex CLI 作为编码/测试/重构执行代理，通过 per-project 文件总线和 tmux 会话支持多个项目并行推进。

v1 的交付目标不是直接实现工具，而是把现有方案整理成可交付规格包：明确用户场景、安装流程、命令契约、文件总线协议、代理协作协议、风险升级协议、验收标准和后续实施路线。

## Core Value

用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] 定义 v1 主用户场景：单人多项目开发，优先支持随时追加任务，同时保留批量任务和无人值守扩展空间。
- [ ] 定义主入口：SSH/Hermes CLI 是必需入口，远程通知/决策通过抽象 Remote Decision Channel 扩展，不绑定 Telegram。
- [ ] 定义三层代理职责：Hermes 负责编排和升级，Claude Code 负责技术监督/架构决策/代码审查，Codex 负责实际实现/测试/重构。
- [ ] 定义 per-project 文件总线协议，包括任务、问题、决策、升级、执行结果和审查结果文件的写入者、读取者、格式和状态流转。
- [ ] 定义多项目隔离与并行规则，包括项目命名、tmux 会话命名、任务前缀、轮询策略、阻塞项目让路机制。
- [ ] 定义三级风险升级机制，包括一般技术决策、架构/安全相关决策、系统级危险操作的处理层级和用户确认规则。
- [ ] 定义可交付规格包结构，包括安装流程规格、命令契约、配置文件说明、故障排查、安全最佳实践和验收清单。
- [ ] 定义后续实施 roadmap，使规格可以直接转入分阶段开发。

### Out of Scope

- 直接实现可运行工具 — 当前阶段先完成规格包，实施放入后续 roadmap。
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

用户已明确：

- 当前 GSD 项目目标是“只整理成产品/技术规格”，不是立即实现。
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
- **Deliverable**: 当前交付物是规格文档与实施 roadmap — 不修改现有 `gbrain` 代码，不实现最终工具。

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| v1 先做可交付规格包，不直接实现工具 | 用户明确选择“只整理成产品/技术规格”，且现有方案需要先规范边界、协议和验收标准 | — Pending |
| 主用户为单人多项目开发者 | 用户选择“自己单人多项目开发 + 远程手机决策”，不是小团队或 AI 工厂场景 | — Pending |
| v1 优先支持随时追加任务 | 用户选择混合模式，但优先保证“随时追加任务” | — Pending |
| SSH/Hermes CLI 是必需入口 | 用户明确“ssh 是要的”，因此 CLI 主链路必须可用 | — Pending |
| 远程决策通道抽象化 | 用户不想绑定 Telegram，选择先抽象接口、不选具体实现 | — Pending |
| 暂不集成进 `gbrain` | 用户选择规格包目标，而非“集成进现有 gbrain 项目” | — Pending |

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
*Last updated: 2026-04-25 after initialization*
