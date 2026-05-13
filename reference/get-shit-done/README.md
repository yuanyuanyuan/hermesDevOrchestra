# GSD (Get Shit Done) 参考文档

> 基于官方源代码的深度分析和使用指南
> 版本: v1.50.0 | 更新日期: 2026-05-13 | 工作流设计: v5.0

---

## 文档索引

### AI Agent 使用

| 文档 | 用途 | 命令前缀 |
|------|------|----------|
| [AI_AGENT_GUIDE_CLAUDE.md](AI_AGENT_GUIDE_CLAUDE.md) | Claude Code 版 AI Agent 操作手册 | `/gsd-<command>` |
| [AI_AGENT_GUIDE_CODEX.md](AI_AGENT_GUIDE_CODEX.md) | Codex 版 AI Agent 操作手册 | `$gsd-<command>` |

### 人类阅读

| 文档 | 用途 |
|------|------|
| [HUMAN_GUIDE.md](HUMAN_GUIDE.md) | 完整用户指南 |
| [HUMAN_QUICK_REFERENCE.md](HUMAN_QUICK_REFERENCE.md) | 快速参考卡片（可打印） |

### 架构分析

| 文档 | 用途 |
|------|------|
| [ANALYSIS_REPORT.md](ANALYSIS_REPORT.md) | 架构深度分析报告 |
| [HERMES_DEV_ORCHESTRA_WORKFLOW.md](HERMES_DEV_ORCHESTRA_WORKFLOW.md) | Hermes Dev Orchestra 自动化工作流设计 (v5) |

### 详细参考

| 文档 | 用途 |
|------|------|
| [workflows/analysis.md](workflows/analysis.md) | 87 个 workflows 详细分析 |

---

## 快速开始

### 安装

```bash
npx get-shit-done-cc@latest --claude --global
```

### 首次使用

```bash
# Claude Code 用户
/gsd-new-project

# Codex 用户
$gsd-new-project
```

### 六步核心循环

```bash
# Claude Code
/gsd-new-project
/gsd-discuss-phase 1
/gsd-plan-phase 1
/gsd-execute-phase 1
/gsd-verify-work 1
/gsd-ship 1

# Codex
$gsd-new-project
$gsd-discuss-phase 1
$gsd-plan-phase 1
$gsd-execute-phase 1
$gsd-verify-work 1
$gsd-ship 1
```

---

## 命令前缀速查

| 运行时 | 前缀 | 示例 |
|--------|------|------|
| Claude Code | `/gsd-` | `/gsd-new-project` |
| Codex | `$gsd-` | `$gsd-new-project` |
| Gemini CLI | `/gsd:` | `/gsd:new-project` |

---

## 核心概念

### GSD 解决什么问题？

1. **上下文腐蚀** — 每个 agent 获得干净的 200K 上下文
2. **无共享记忆** — 所有状态存储在 `.planning/` 目录
3. **无验证** — verify 步骤 + 专用调试 agent

### 层级结构

```
里程碑 (Milestone)
  └── 阶段 (Phase)
        └── 计划 (Plan)
              └── 任务 (Task)
```

### 文件结构

```
.planning/
├── PROJECT.md          # 项目愿景
├── REQUIREMENTS.md     # 需求
├── ROADMAP.md          # 路线图
├── STATE.md            # 当前状态
├── config.json         # 配置
├── phases/             # 阶段工件
├── research/           # 研究成果
├── todos/              # 捕获的待办
└── debug/              # 调试会话
```

---

## 最常用命令

| 场景 | Claude Code | Codex |
|------|-------------|-------|
| 查看状态 | `/gsd-progress` | `$gsd-progress` |
| 自动推进 | `/gsd-progress --next` | `$gsd-progress --next` |
| 快速修复 | `/gsd-fast "task"` | `$gsd-fast "task"` |
| 恢复工作 | `/gsd-resume-work` | `$gsd-resume-work` |
| 捕获想法 | `/gsd-capture --note "idea"` | `$gsd-capture --note "idea"` |
| 调试问题 | `/gsd-debug "issue"` | `$gsd-debug "issue"` |

---

## 组件规模

| 组件 | 数量 |
|------|------|
| Commands/Skills | 64 个 |
| Agents | 33 个 |
| Workflows | 87 个 |
| Hooks | 11 个 |
| 支持运行时 | 15+ 种 |

---

## 设计亮点

1. **Fresh Context Per Agent** — 解决上下文腐蚀
2. **File-Based State** — 人类可读、可版本控制
3. **Defense in Depth** — 多层验证
4. **Package Legitimacy Gate** — 防止供应链攻击
5. **Wave-Based Parallel Execution** — 智能并行

---

*文档索引 v1.0 | 2026-05-13*
