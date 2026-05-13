# Get Shit Done (GSD) 架构深度分析报告

> 项目版本: v1.50.0-canary.0
> 分析日期: 2026-05-12
> 源码: https://github.com/gsd-build/get-shit-done

---

## 目录

1. [项目概述](#1-项目概述)
2. [核心设计哲学](#2-核心设计哲学)
3. [系统架构](#3-系统架构)
4. [组件分析](#4-组件分析)
5. [数据流与状态管理](#5-数据流与状态管理)
6. [设计亮点与洞察](#6-设计亮点与洞察)
7. [优缺点分析](#7-优缺点分析)

---

## 1. 项目概述

### 1.1 定位

GSD 是一个**轻量级元提示（meta-prompting）、上下文工程（context engineering）和规范驱动开发（spec-driven development）系统**，专为 Claude Code、OpenCode、Gemini CLI、Kilo、Codex、Copilot、Cursor、Windsurf 等 AI 编码代理设计。

核心解决的问题：**上下文腐蚀（context rot）** —— 随着 AI 填充上下文窗口，输出质量逐渐下降的现象。

### 1.2 作者背景

> *"我是独立开发者。我不写代码 —— Claude Code 写。"*
> — TÂCHES（项目作者）

GSD 专为**独立开发者 + AI 协作**场景设计，反对企业级复杂性（无冲刺仪式、故事点、利益相关者同步）。

### 1.3 技术栈

- **运行时**: Node.js >= 22.0.0
- **依赖**: @anthropic-ai/claude-agent-sdk, ws
- **语言**: TypeScript (SDK), JavaScript (CLI), Markdown (Workflows/Agents)
- **支持运行时**: 15+ 种 AI 编码工具

---

## 2. 核心设计哲学

### 2.1 三大问题与解决方案

GSD 解决了大多数 AI 编码设置的三个核心问题：

```
┌─────────────────────────────────────────────────────────────┐
│ 问题 1: 上下文膨胀 (Context Bloat)                          │
│ ─────────────────────────────────────────────────────────── │
│ 现象: 会话增长时，质量下降                                    │
│ 方案: 每个 agent 获得干净的上下文窗口（最多 200K tokens）      │
│ 技术: 研究者、规划者、执行者各自独立启动，只携带必要信息        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 问题 2: 无共享记忆 (No Shared Memory)                        │
│ ─────────────────────────────────────────────────────────── │
│ 现象: 跨会话/上下文重置时丢失状态                              │
│ 方案: 结构化文件工件（.planning/ 目录）                       │
│ 文件: PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md     │
│ 优势: 人类可读、可检查、可提交到 git                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 问题 3: 无验证 (No Verification)                             │
│ ─────────────────────────────────────────────────────────── │
│ 现象: "能运行"不等于"能用"                                    │
│ 方案: verify 步骤 + 专用调试 agent + 修复计划                 │
│ 流程: 构建 -> 验证 -> 诊断 -> 修复计划 -> 重新执行            │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 设计原则

| 原则 | 描述 |
|------|------|
| **Fresh Context Per Agent** | 每个 agent 获得干净的上下文窗口，消除上下文腐蚀 |
| **Thin Orchestrators** | Workflow 文件只做编排，不做重活 |
| **File-Based State** | 所有状态以 Markdown/JSON 存储在 `.planning/` |
| **Absent = Enabled** | 特性标志缺失时默认启用，用户只需显式禁用 |
| **Defense in Depth** | 多层防护：计划验证 -> 原子提交 -> 后执行验证 -> UAT |

---

## 3. 系统架构

### 3.1 整体架构图

```
┌──────────────────────────────────────────────────────────────┐
│                         USER                                 │
│                    /gsd-command [args]                        │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│                    COMMAND LAYER                              │
│          commands/gsd/*.md — 用户入口点                       │
│          (Claude Code 自定义斜杠命令 / Codex skills)          │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│                   WORKFLOW LAYER                              │
│       get-shit-done/workflows/*.md — 编排逻辑                │
│       (读取引用、启动 agent、管理状态)                        │
└──────┬──────────────┬─────────────────┬──────────────────────┘
       │              │                 │
┌──────▼──────┐ ┌─────▼─────┐ ┌────────▼───────┐
│   AGENT     │ │   AGENT   │ │    AGENT       │
│  (干净上下文)│ │ (干净上下文)│ │  (干净上下文)  │
└──────┬──────┘ └─────┬─────┘ └────────┬───────┘
       │              │                 │
┌──────▼──────────────▼─────────────────▼──────────────────────┐
│                   CLI TOOLS LAYER                             │
│           gsd-sdk query + gsd-tools.cjs                       │
│           程序化 SDK 桥接                                     │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                   FILE SYSTEM (.planning/)                    │
│     PROJECT.md | REQUIREMENTS.md | ROADMAP.md                │
│     STATE.md | config.json | phases/ | research/             │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 层级详解

#### Command Layer（命令层）

用户入口点，每个命令是一个 Markdown 文件，包含：
- YAML 前置数据（name, description, allowed-tools）
- 启动工作流的提示词体

安装方式因运行时而异：
- **Claude Code**: 自定义斜杠命令 (`/gsd-command-name`)
- **Codex**: Skills (`$gsd-command-name`)
- **Gemini CLI**: `gsd:` 命名空间 (`/gsd:command-name`)
- **其他**: 各自适配

**统计**: 64 个命令，分布在 14 个功能类别中

#### Workflow Layer（工作流层）

编排逻辑，负责：
- 通过 `gsd-sdk query` 加载上下文
- 启动专注的 agent
- 收集结果并路由到下一步
- 更新状态

**统计**: 87 个工作流文件

#### Agent Layer（代理层）

专业化 agent，每个都有：
- 干净的 200K token 上下文窗口
- 专注的职责
- 明确的工具权限

**统计**: 33 个 agent 定义

#### CLI Tools Layer（工具层）

Node.js CLI 工具（`gsd-tools.cjs`），提供：
- 状态解析和更新
- 模板填充
- 验证逻辑
- 配置管理

**统计**: 20+ 个模块

#### File System（文件系统）

所有状态存储在 `.planning/` 目录，人类可读的 Markdown 和 JSON。

---

## 4. 组件分析

### 4.1 Commands/Skills（64 个）

按功能分类：

| 类别 | 数量 | 代表命令 |
|------|------|----------|
| 核心工作流 | 6 | discuss, plan, execute, verify, progress, autonomous |
| 项目管理 | 7 | new-project, new-milestone, complete-milestone, phase, manager, workstreams |
| 规划与设计 | 8 | spec, mvp, ui, ai-integration, sketch, spike |
| 代码质量 | 5 | code-review, review, secure, eval-review, ui-review |
| 审计与修复 | 4 | audit-uat, audit-milestone, audit-fix, validate-phase |
| 上下文管理 | 5 | capture, thread, pause-work, resume-work, explore |
| 代码库分析 | 4 | map-codebase, graphify, ingest-docs, extract-learnings |
| 文档 | 2 | docs-update, profile-user |
| Git 与部署 | 3 | pr-branch, ship, undo |
| 工具 | 8 | help, fast, quick, config, stats, health, update, import |
| 路由 | 6 | context, ideate, manage, project, quality, workflow |
| 调试 | 4 | debug, forensics, review-backlog, inbox |
| 工作区 | 1 | workspace |

### 4.2 Agents（33 个）

按职责分类：

| 分类 | 数量 | 代表 Agent |
|------|------|-----------|
| Researchers（研究类） | 10 | project-researcher, phase-researcher, ui-researcher, advisor-researcher |
| Planners（规划类） | 3 | planner, roadmapper, eval-planner |
| Executors（执行类） | 2 | executor, code-fixer |
| Verifiers（验证类） | 9 | verifier, plan-checker, code-reviewer, integration-checker |
| Documenters（文档类） | 3 | doc-writer, doc-classifier, doc-synthesizer |
| Synthesizers（综合类） | 2 | research-synthesizer, intel-updater |
| Debuggers（调试类） | 2 | debugger, debug-session-manager |

**工具使用统计**:
- Read: 33（所有 agent）
- Bash: 30
- Grep: 30
- Glob: 29
- Write: 25
- WebSearch: 8（研究类）
- AskUserQuestion: 3

### 4.3 Workflows（87 个）

按功能分类：

| 分类 | 数量 | 说明 |
|------|------|------|
| 核心阶段生命周期 | 9 | discuss -> plan -> execute -> verify 完整链路 |
| 阶段管理 | 10 | 增删改查、MVP/UI/AI 特殊阶段 |
| 项目初始化 | 4 | 新项目、新里程碑、代码库映射 |
| 执行模式 | 5 | 自主执行、管理器、快速任务 |
| 质量与审查 | 8 | 代码审查、跨 AI 审查、UI 审查 |
| 验证与审计 | 4 | 里程碑审计、UAT 审计、自动修复 |
| 里程碑生命周期 | 4 | 完成、总结、差距规划 |
| 状态管理 | 6 | 进度、恢复、暂停、撤销 |
| 捕获与组织 | 7 | TODO、笔记、种子、探索 |
| 文档 | 3 | 更新、学习提取 |
| 基础设施 | 9 | 设置、清理、健康、更新 |
| 调试 | 4 | 调试、诊断、取证 |
| 研究与探索 | 5 | Spike、Sketch |
| 工作区 | 3 | 新建、删除、列出 |
| PR 与发布 | 3 | PR 分支、发布 |
| 用户画像 | 1 | 开发者行为分析 |

### 4.4 Hooks（11 个）

| Hook | 事件 | 用途 |
|------|------|------|
| gsd-statusline.js | statusLine | 显示模型、任务、目录、上下文使用条 |
| gsd-context-monitor.js | PostToolUse | 在 35%/25% 剩余时注入上下文警告 |
| gsd-check-update.js | SessionStart | 后台更新检查 |
| gsd-prompt-guard.js | PreToolUse | 扫描 .planning/ 写入的注入模式 |
| gsd-read-injection-scanner.js | PostToolUse | 扫描 Read 输出的注入指令 |
| gsd-workflow-guard.js | PreToolUse | 检测工作流外的文件编辑 |
| gsd-read-guard.js | PreToolUse | 防止编辑未读文件 |
| gsd-session-state.sh | PostToolUse | 会话状态跟踪 |
| gsd-validate-commit.sh | PostToolUse | 提交验证 |
| gsd-phase-boundary.sh | PostToolUse | 阶段边界检测 |

---

## 5. 数据流与状态管理

### 5.1 新项目流程

```
用户输入（想法描述）
    │
    ▼
提问（questioning.md 哲学）
    │
    ▼
4x 项目研究者（并行）
    ├── 技术栈 -> STACK.md
    ├── 功能 -> FEATURES.md
    ├── 架构 -> ARCHITECTURE.md
    └── 陷阱 -> PITFALLS.md
    │
    ▼
研究综合器 -> SUMMARY.md
    │
    ▼
需求提取 -> REQUIREMENTS.md
    │
    ▼
路线图器 -> ROADMAP.md
    │
    ▼
用户批准 -> STATE.md 初始化
```

### 5.2 阶段执行流程

```
discuss-phase -> CONTEXT.md（用户偏好）
    │
    ▼
ui-phase -> UI-SPEC.md（设计合约，可选）
    │
    ▼
plan-phase
    ├── 研究门控（阻塞如果 RESEARCH.md 有未解决问题）
    ├── 阶段研究者 -> RESEARCH.md
    │       └── 包合法性门控：slopcheck 检查每个包
    ├── 规划器 -> PLAN.md 文件
    │       └── 检查点：human-verify
    ├── 计划检查器 -> 验证循环（最多 3 次）
    ├── 需求覆盖门控（REQ-IDs -> 计划）
    └── 决策覆盖门控（CONTEXT.md decisions -> 计划）
    │
    ▼
state planned-phase -> STATE.md（Planned/Ready）
    │
    ▼
execute-phase
    ├── 波次分析（依赖分组）
    ├── 执行器/计划 -> 代码 + 原子提交
    ├── SUMMARY.md/计划
    └── 验证器 -> VERIFICATION.md
    │
    ▼
verify-work -> UAT.md（用户验收测试）
    │
    ▼
ui-review -> UI-REVIEW.md（视觉审计，可选）
```

### 5.3 文件系统布局

```
.planning/
├── PROJECT.md              # 项目愿景、约束、决策
├── REQUIREMENTS.md         # 范围需求（v1/v2/out-of-scope）
├── ROADMAP.md              # 阶段分解与状态跟踪
├── STATE.md                # 活跃记忆：位置、决策、阻塞
├── config.json             # 工作流配置
├── MILESTONES.md           # 已完成里程碑归档
├── research/               # 领域研究
│   ├── SUMMARY.md
│   ├── STACK.md
│   ├── FEATURES.md
│   ├── ARCHITECTURE.md
│   └── PITFALLS.md
├── codebase/               # 棕地映射
│   ├── STACK.md
│   ├── ARCHITECTURE.md
│   ├── CONVENTIONS.md
│   └── ...
├── phases/
│   └── XX-phase-name/
│       ├── XX-CONTEXT.md       # 用户偏好
│       ├── XX-RESEARCH.md      # 生态研究
│       ├── XX-YY-PLAN.md       # 执行计划
│       ├── XX-YY-SUMMARY.md    # 执行结果
│       ├── XX-VERIFICATION.md  # 后执行验证
│       ├── XX-UI-SPEC.md       # UI 设计合约
│       └── XX-UAT.md           # 用户验收测试
├── quick/                  # 快速任务跟踪
├── todos/                  # 捕获的想法
├── threads/                # 持久化上下文线程
├── seeds/                  # 前瞻性想法
└── debug/                  # 活跃调试会话
```

---

## 6. 设计亮点与洞察

### 6.1 Fresh Context Per Agent — 解决上下文腐蚀

这是 GSD 最核心的创新。传统 AI 编码工具在长会话中质量下降，因为：
- 上下文窗口被历史对话填满
- 无关信息干扰当前任务
- 模型注意力分散

GSD 的解决方案：
```
传统方式:
┌─────────────────────────────────────┐
│ 200K 上下文                          │
│ [历史对话] [无关信息] [当前任务]      │
│ 质量：随时间下降 ↓                   │
└─────────────────────────────────────┘

GSD 方式:
┌─────────────────────────────────────┐
│ 200K 上下文（每个 agent 独立）        │
│ [必要上下文] [专注任务]               │
│ 质量：始终稳定 ✓                     │
└─────────────────────────────────────┘
```

### 6.2 Wave-Based Parallel Execution — 智能并行

执行阶段使用波次并行：
```
Wave Analysis:
  Plan 01 (无依赖)      ─┐
  Plan 02 (无依赖)      ─┤── Wave 1（并行）
  Plan 03 (依赖: 01)    ─┤── Wave 2（等待 Wave 1）
  Plan 04 (依赖: 02)    ─┘
  Plan 05 (依赖: 03,04) ── Wave 3（等待 Wave 2）
```

每个执行器获得：
- 干净的 200K 上下文窗口
- 特定的 PLAN.md
- 项目上下文（PROJECT.md, STATE.md）
- 阶段上下文（CONTEXT.md, RESEARCH.md）

### 6.3 Package Legitimacy Gate — 防止供应链攻击

GSD 实现了三层防护：

| 层级 | 组件 | 行为 |
|------|------|------|
| 研究 | gsd-phase-researcher | 运行 slopcheck；写审计表；剥离 [SLOP] 包 |
| 规划 | gsd-planner | 插入 human-verify 检查点；添加 STRIDE 行 |
| 执行 | gsd-executor | 排除包安装的自动修复范围 |

### 6.4 Adaptive Context Enrichment — 1M 模型优化

当上下文窗口 >= 500K tokens 时：
- 执行器 agent 接收先前波次的 SUMMARY.md 和 CONTEXT.md
- 验证器接收所有 PLAN.md、SUMMARY.md、CONTEXT.md、REQUIREMENTS.md

这使得 agent 能跨计划感知，实现更智能的验证。

### 6.5 Thin Orchestrators — 编排与执行分离

Workflow 文件从不做重活：
```markdown
# execute-phase.md 的典型模式

1. 加载上下文: gsd-sdk query init.execute-phase <phase>
2. 解析模型: gsd-sdk query resolve-model <agent-name>
3. 启动 Agent: Task/SubAgent 调用
   ├── Agent 提示词 (agents/*.md)
   ├── 上下文负载 (init JSON)
   ├── 模型分配
   └── 工具权限
4. 收集结果
5. 更新状态: gsd-sdk query state.update
```

---

## 7. 优缺点分析

### 7.1 优势

| 优势 | 说明 |
|------|------|
| **解决上下文腐蚀** | Fresh Context Per Agent 是真正的创新 |
| **文件即状态** | 人类可读、可检查、可版本控制 |
| **多运行时支持** | 15+ 种 AI 编码工具适配 |
| **防御深度** | 多层验证确保质量 |
| **供应链安全** | Package Legitimacy Gate 防止 slopsquatting |
| **渐进式披露** | 两阶段路由减少 token 成本 |
| **自适应上下文** | 根据模型能力调整上下文丰富度 |

### 7.2 劣势

| 劣势 | 说明 |
|------|------|
| **学习曲线** | 64 个命令 + 87 个工作流，新手需要时间熟悉 |
| **配置复杂** | config.json 选项众多，需要理解才能优化 |
| **依赖 Claude** | 虽然支持多运行时，但核心设计围绕 Claude |
| **文件系统依赖** | 大型项目可能面临 .planning/ 目录管理挑战 |
| **调试困难** | 多层抽象使得问题定位困难 |

### 7.3 适用场景

**最佳适用**:
- 独立开发者 + AI 协作
- 中小型项目（< 100K 行代码）
- 需要长期维护的项目
- 重视代码质量的团队

**不太适用**:
- 大型企业团队（GSD 反企业设计）
- 极简项目（过度工程）
- 需要实时协作的场景

---

## 总结

GSD 是一个精心设计的元提示系统，通过 Fresh Context Per Agent、文件状态管理、多层验证等创新，解决了 AI 编码中的核心痛点。它的设计哲学（反企业、独立开发者友好）使其在特定场景下表现出色。

对于独立开发者来说，GSD 提供了一个可靠的 AI 协作框架，让 Claude Code 真正成为"可靠的编码伙伴"而非"不可预测的代码生成器"。

---

*报告生成: 2026-05-12*
*分析工具: MyCodeMap + 人工分析*
