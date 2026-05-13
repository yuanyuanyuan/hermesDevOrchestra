# GSD v1.41.2 命令与代理完整参考手册

> 生成时间: 2026-05-11
> GSD 版本: 1.41.2
> 来源目录: `~/.claude/skills/` 和 `~/.claude/agents/`
> 适用平台: Claude Code (`.md`) / Codex (`.toml`)
>
> **命令前缀差异：** Claude Code 使用 `/gsd-<command>` 格式，Codex 使用 `$gsd-<command>` 格式。本文档示例均以 `/` 前缀为准，Codex 用户请将 `/` 替换为 `$`。

---

## 目录

1. [v1.41.2 重要变更](#v1412-重要变更)
2. [GSD Skills（用户可直接执行的命令）](#gsd-skills)
3. [命名空间路由（元技能）](#命名空间路由)
4. [GSD Agents（由 Orchestrator 调用的子代理）](#gsd-agents)
5. [通用说明](#通用说明)
6. [交互模式参考](#交互模式参考)

---

## v1.41.2 重要变更

### 技能表面整合 86 → 59

v1.41.0 将 86 个扁平技能合并为 59 个，通过 4 个新的分组技能替代微技能集群：

| 旧命令 | 新统一入口 | 子命令 |
|--------|-----------|--------|
| `gsd-add-todo`, `gsd-note`, `gsd-add-backlog`, `gsd-plant-seed`, `gsd-check-todos` | **`/gsd-capture`** | `[--note \| --backlog \| --seed \| --list]` |
| `gsd-add-phase`, `gsd-insert-phase`, `gsd-remove-phase`, `gsd-edit-phase` | **`/gsd-phase`** | `[--insert \| --remove \| --edit]` |
| `gsd-settings`, `gsd-settings-advanced`, `gsd-settings-integrations`, `gsd-set-profile` | **`/gsd-config`** | `[--advanced \| --integrations \| --profile <name>]` |
| `gsd-new-workspace`, `gsd-list-workspaces`, `gsd-remove-workspace` | **`/gsd-workspace`** | `[--new \| --list \| --remove]` |

其他合并：
- `gsd-sync-skills` → `/gsd-update --sync`
- `gsd-reapply-patches` → `/gsd-update --reapply`
- `gsd-scan` → `/gsd-map-codebase --fast`
- `gsd-intel` → `/gsd-map-codebase --query <term>`
- `gsd-research-phase` → `/gsd-plan-phase --research-phase <N>`
- `gsd-code-review-fix` → `/gsd-code-review <phase> --fix`
- `gsd-do`, `gsd-next` → `/gsd-progress --do "<text>"` / `/gsd-progress --next`

### 新增命令

| 命令 | 描述 |
|------|------|
| `/gsd-mvp-phase` | 垂直 MVP 切片规划（用户故事 + SPIDR 拆分） |
| `/gsd-spec-phase` | 苏格拉底式规范细化，输出 SPEC.md |
| `/gsd-ultraplan-phase` | [BETA] 将计划阶段卸载到 Claude Code ultraplan 云端 |
| `/gsd-plan-review-convergence` | 跨 AI 计划收敛循环（支持云端和本地模型） |

### 命名空间元技能（6 个）

v1.41.0 引入两级层次路由，模型看到 6 个命名空间路由器而非 60+ 扁平条目，冷启动系统提示从 ~2,150 tokens 降至 ~120：

`gsd:workflow` | `gsd:project` | `gsd:review` | `gsd:context` | `gsd:manage` | `gsd:ideate`

### 其他增强

- **Phase 生命周期状态行**：STATE.md 新增 `active_phase`, `next_action`, `progress` 字段
- **`/gsd-health --context`**：上下文窗口利用率守护（60% 警告，70% 严重）
- **`--minimal` 安装标志**：仅安装核心技能，冷启动 ~700 tokens
- **Post-merge build & test gate**：执行阶段后自动检测构建命令并运行
- **扩展运行时模型配置**：支持 gemini, qwen, opencode, copilot
- **Workstream 配置继承**：根 config.json 与 workstream config 深度合并

---

## GSD Skills

### 核心工作流命令

| 命令 | 描述 | 参数格式 | 交互模式 |
|------|------|----------|----------|
| `/gsd-new-project` | 初始化新项目（研究→需求→路线图） | `[--auto @file.md]` | 可选 `--auto` |
| `/gsd-discuss-phase` | 计划前收集阶段上下文 | `<phase> [--chain\|--analyze\|--power\|--assumptions] [--batch[=N]]` | 可选 `--auto` |
| `/gsd-plan-phase` | 创建详细阶段计划 | `<phase> [--research] [--skip-research] [--research-phase <N>] [--view] [--gaps] [--skip-verify] [--tdd] [--mvp]` | 可选 `--auto` |
| `/gsd-execute-phase` | 波浪式并行执行阶段计划 | `<phase> [--wave N] [--gaps-only] [--tdd]` | 非交互 |
| `/gsd-verify-work` | 通过对话式 UAT 验证功能 | `[phase]` | 必须交互 |
| `/gsd-ship` | 推送分支 + 创建 PR | `[phase] [--draft]` | 非交互 |
| `/gsd-progress` | 检查进度并智能路由下一步 | `[--next] [--forensic] [--do "<text>"]` | 非交互 |

### 分组技能（v1.41.0 新统一入口）

#### `/gsd-capture` — 捕获想法、任务、笔记和种子

| 子命令 | 目标 | 用法 |
|--------|------|------|
| (默认) | 结构化 todo → `.planning/todos/pending/` | `/gsd-capture Add auth token refresh` |
| `--note` | 零摩擦笔记 → `.planning/notes/` | `/gsd-capture --note refactor hook system` |
| `--backlog` | Backlog 停车场 (999.x) | `/gsd-capture --backlog "real-time notifications"` |
| `--seed` | 前瞻性想法 + 触发条件 | `/gsd-capture --seed "add collab when WebSocket ready"` |
| `--list` | 列出待办并选择一个开始 | `/gsd-capture --list [area]` |

#### `/gsd-phase` — ROADMAP.md 阶段 CRUD

| 子命令 | 动作 | 用法 |
|--------|------|------|
| (默认) | 在里程碑末尾添加新阶段 | `/gsd-phase "Add admin dashboard"` |
| `--insert` | 插入小数阶段（如 7.1） | `/gsd-phase --insert 7 "Fix critical auth bug"` |
| `--remove` | 移除阶段并重编号 | `/gsd-phase --remove 17` |
| `--edit` | 编辑现有阶段字段 | `/gsd-phase --edit 3 [--force]` |

#### `/gsd-config` — 配置 GSD 设置

| 子命令 | 动作 | 用法 |
|--------|------|------|
| (默认) | 常用开关（模型、研究、验证器） | `/gsd-config` |
| `--advanced` | 高级调优（超时、分支模板、跨 AI 执行） | `/gsd-config --advanced` |
| `--integrations` | 第三方 API 密钥、代码审查路由 | `/gsd-config --integrations` |
| `--profile` | 切换模型配置 (quality\|balanced\|budget\|inherit) | `/gsd-config --profile budget` |

#### `/gsd-workspace` — 管理隔离工作区

| 子命令 | 动作 | 用法 |
|--------|------|------|
| `--new` | 创建隔离工作区 | `/gsd-workspace --new --name feature-b --repos .` |
| `--list` | 列出活跃工作区 | `/gsd-workspace --list` |
| `--remove` | 移除工作区 | `/gsd-workspace --remove feature-b` |

### 计划与执行

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-mvp-phase` | 垂直 MVP 切片规划 | `<phase> [--force]` | 必须交互 |
| `/gsd-spec-phase` | 苏格拉底式规范细化 | `<phase> [--auto] [--text]` | 可选 `--auto` |
| `/gsd-ultraplan-phase` | [BETA] ultraplan 云端计划 | `[phase]` | 非交互 |
| `/gsd-plan-review-convergence` | 跨 AI 计划收敛循环 | `<phase> [--codex] [--gemini] [--claude] [--all] [--max-cycles N]` | 非交互 |
| `/gsd-autonomous` | 自动运行所有剩余阶段 | `[--from N] [--to N] [--only N] [--interactive]` | 非交互 |
| `/gsd-quick` | 快速任务（原子提交 + 状态追踪） | `[--full] [--validate] [--discuss] [--research]` | 可选 flag 组合 |
| `/gsd-fast` | 内联极简任务（无子代理） | `[description]` | 必须交互 |

### 质量、审查与验证

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-code-review` | 审查阶段源码 | `<phase> [--depth=quick\|standard\|deep] [--fix [--all] [--auto]]` | 非交互 |
| `/gsd-secure-phase` | 安全审计阶段 | `[phase]` | 非交互 |
| `/gsd-validate-phase` | 回溯填补 Nyquist 验证缺口 | `[phase]` | 非交互 |
| `/gsd-ui-phase` | UI 设计合同 | `[phase]` | 必须交互 |
| `/gsd-ui-review` | 6 维度视觉审计 | `[phase]` | 非交互 |
| `/gsd-eval-review` | AI 阶段评估覆盖审计 | `[phase]` | 非交互 |
| `/gsd-audit-fix` | 自动审计到修复流水线 | `--source <audit-uat> [--severity medium\|high\|all] [--max N] [--dry-run]` | 可选 `--dry-run` |
| `/gsd-add-tests` | 为已完成阶段生成测试 | `<phase> [instructions]` | 非交互 |
| `/gsd-review` | 跨 AI 同行评审 | `--phase N [--gemini] [--claude] [--codex] [--all]` | 非交互 |

### 发现与规范

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-explore` | 苏格拉底式构思和想法路由 | 无 | 必须交互 |
| `/gsd-spike` | 技术探索/原型 | `[idea] [--quick] [--wrap-up]` | 可选 `--quick` |
| `/gsd-sketch` | HTML 草图探索设计方向 | `[idea] [--quick] [--wrap-up]` | 可选 `--quick` |
| `/gsd-import` | 导入外部计划并检测冲突 | `--from <filepath>` | 必须交互 |
| `/gsd-ingest-docs` | 从现有文档引导 `.planning/` | `[path] [--mode new\|merge] [--resolve auto]` | 可选 `--resolve auto` |
| `/gsd-ai-integration-phase` | AI 系统阶段生成 AI-SPEC.md | `[phase]` | 必须交互 |

### 里程碑管理

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-new-milestone` | 开始新里程碑周期 | `[name] [--reset-phase-numbers]` | 必须交互 |
| `/gsd-complete-milestone` | 归档里程碑并准备下一版本 | `<version>` | 非交互 |
| `/gsd-audit-milestone` | 归档前审计里程碑完成情况 | `[version]` | 非交互 |
| `/gsd-milestone-summary` | 生成里程碑项目摘要 | `[version]` | 非交互 |

### 进度与会话管理

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-progress` | 检查进度 + 智能路由 | `[--next] [--forensic] [--do "<text>"]` | 非交互 |
| `/gsd-resume-work` | 恢复暂停的工作 | 无 | 非交互 |
| `/gsd-pause-work` | 暂停工作时创建上下文交接 | `[--report]` | 非交互 |
| `/gsd-manager` | 多阶段管理交互中心 | `[--analyze-deps]` | 必须交互 |

### 调试与诊断

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-debug` | 系统化调试（跨上下文持久化） | `[issue] [--diagnose]` | 必须交互 |
| `/gsd-forensics` | GSD 工作流失败的事后调查 | `[problem]` | 必须交互 |
| `/gsd-health` | 诊断规划目录健康 | `[--repair] [--context]` | 非交互 |
| `/gsd-undo` | 安全 git 回滚 | `--last N \| --phase NN \| --plan NN-MM` | 必须交互 |

### 知识与上下文

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-graphify` | 构建/查询项目知识图谱 | `[build\|query <term>\|status\|diff]` | 非交互 |
| `/gsd-map-codebase` | 并行映射代码库 | `[area] [--fast] [--focus <area>] [--query <term>]` | 非交互 |
| `/gsd-thread` | 管理持久上下文线程 | `[list\|close\|status] [slug]` | 必须交互 |
| `/gsd-profile-user` | 生成开发者行为档案 | `[--questionnaire] [--refresh]` | 必须交互 |
| `/gsd-stats` | 显示项目统计 | 无 | 非交互 |
| `/gsd-extract-learnings` | 从已完成阶段提取经验教训 | `<phase>` | 非交互 |
| `/gsd-docs-update` | 生成/更新项目文档 | `[--force] [--verify-only]` | 可选 `--force` |

### 仓库集成

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-inbox` | 审查 GitHub issues/PRs | `[--issues] [--prs] [--label] [--close-incomplete]` | 非交互 |
| `/gsd-pr-branch` | 过滤 .planning/ 提交创建 PR | `[target branch]` | 非交互 |
| `/gsd-review-backlog` | 审查 backlog 并提升/保留/删除 | 无 | 必须交互 |

### 工具与维护

| 命令 | 描述 | 参数 | 交互模式 |
|------|------|------|----------|
| `/gsd-update` | 更新 GSD | `[--sync] [--reapply]` | 必须交互 |
| `/gsd-cleanup` | 归档已完成里程碑的阶段目录 | 无 | 非交互 |
| `/gsd-help` | 显示命令参考 | 无 | 非交互 |
| `/gsd-workstreams` | 管理并行工作流 | `[list\|create\|switch\|complete\|resume]` | 必须交互 |

---

## 命名空间路由

v1.41.0 引入 6 个命名空间元技能，实现两级层次路由。可直接调用来浏览某分类下的所有命令：

| 命名空间 | 路由内容 | 包含的子技能 |
|----------|----------|-------------|
| `/gsd-ns-workflow` | 阶段流水线 | discuss-phase, spec-phase, plan-phase, execute-phase, verify-work, phase, progress, ultraplan-phase, plan-review-convergence |
| `/gsd-ns-project` | 项目生命周期 | new-project, new-milestone, complete-milestone, audit-milestone, milestone-summary, cleanup |
| `/gsd-ns-review` | 质量门禁 | code-review, secure-phase, validate-phase, ui-phase, ui-review, eval-review, audit-fix, add-tests, review |
| `/gsd-ns-context` | 代码库智能 | map-codebase, graphify, docs-update, extract-learnings, stats, profile-user |
| `/gsd-ns-ideate` | 探索/捕获 | explore, sketch, spike, spec-phase, capture |
| `/gsd-ns-manage` | 配置与工作区 | workstreams, thread, update, ship, inbox, workspace, config, settings |

---

## GSD Agents

由 Orchestrator 调用的子代理，位于 `~/.claude/agents/gsd-*.md`。

| 代理名 | 描述 | 触发命令 | 工具集 |
|--------|------|----------|--------|
| `gsd-executor` | 执行 GSD 计划（原子提交等） | `/gsd-execute-phase` | Read, Write, Edit, Bash, Grep, Glob |
| `gsd-planner` | 创建可执行阶段计划 | `/gsd-plan-phase` | + WebFetch, mcp__context7__* |
| `gsd-plan-checker` | 验证计划能否达成阶段目标 | `/gsd-plan-phase` | Read, Bash, Glob, Grep |
| `gsd-phase-researcher` | 研究阶段实现方式 | `/gsd-plan-phase` | + WebSearch, WebFetch, mcp__context7__* |
| `gsd-pattern-mapper` | 分析代码库模式 | `/gsd-plan-phase` (planning 前) | + Write |
| `gsd-verifier` | 验证阶段目标达成 | `/gsd-verify-work` | Read, Write, Bash, Grep, Glob |
| `gsd-code-reviewer` | 审查源码 bug/安全/质量问题 | `/gsd-code-review` | Read, Write, Bash, Grep, Glob |
| `gsd-code-fixer` | 应用代码审查发现的问题修复 | `/gsd-code-review --fix` | Read, Edit, Write, Bash, Grep, Glob |
| `gsd-debugger` | 科学方法调试 | `/gsd-debug` | + WebSearch |
| `gsd-debug-session-manager` | 管理多周期调试会话 | `/gsd-debug` (多周期) | + Task, AskUserQuestion |
| `gsd-project-researcher` | 路线图创建前研究领域生态 | `/gsd-new-project` | + WebSearch, WebFetch, mcp__context7__* |
| `gsd-research-synthesizer` | 合成并行研究员输出 | `/gsd-new-project` | Read, Write, Bash |
| `gsd-roadmapper` | 创建项目路线图 | `/gsd-new-project` | Read, Write, Bash, Glob, Grep |
| `gsd-codebase-mapper` | 探索代码库并写结构化分析文档 | `/gsd-map-codebase` | + Write |
| `gsd-intel-updater` | 分析代码库并写情报文件 | `/gsd-map-codebase --query` | Read, Write, Bash, Glob, Grep |
| `gsd-doc-classifier` | 分类规划文档类型 | `/gsd-ingest-docs` | Read, Write, Grep, Glob |
| `gsd-doc-synthesizer` | 合成分类后的文档 | `/gsd-ingest-docs` | + Bash |
| `gsd-doc-writer` | 编写/更新项目文档 | `/gsd-docs-update` | Read, Bash, Grep, Glob, Write |
| `gsd-doc-verifier` | 验证文档事实声明 | `/gsd-docs-update --verify-only` | Read, Write, Bash, Grep, Glob |
| `gsd-ui-researcher` | 产出前端设计合同 | `/gsd-ui-phase` | + WebSearch, WebFetch, mcp__context7__* |
| `gsd-ui-checker` | 验证 UI-SPEC.md 设计合同 | `/gsd-ui-phase` | Read, Bash, Glob, Grep |
| `gsd-ui-auditor` | 6 维度视觉审计前端代码 | `/gsd-ui-review` | Read, Write, Bash, Grep, Glob |
| `gsd-security-auditor` | 验证威胁缓解措施 | `/gsd-secure-phase` | Read |
| `gsd-nyquist-auditor` | 填补 Nyquist 验证缺口 | `/gsd-validate-phase` | Read |
| `gsd-integration-checker` | 验证跨阶段集成和 E2E 流程 | `/gsd-validate-phase` | Read, Bash, Grep, Glob |
| `gsd-eval-auditor` | 回溯审计 AI 阶段评估覆盖 | `/gsd-eval-review` | Read, Write, Bash, Grep, Glob |
| `gsd-eval-planner` | 设计结构化评估策略 | `/gsd-ai-integration-phase` | + AskUserQuestion |
| `gsd-ai-researcher` | 研究 AI 框架官方文档 | `/gsd-ai-integration-phase` | + Write |
| `gsd-domain-researcher` | 研究业务领域和真实应用上下文 | `/gsd-ai-integration-phase` | + WebSearch, WebFetch, mcp__context7__* |
| `gsd-framework-selector` | AI/LLM 框架交互式选择 | `/gsd-ai-integration-phase` | + AskUserQuestion |
| `gsd-advisor-researcher` | 研究单个灰区决策 | `/gsd-discuss-phase` (advisor 模式) | Read, Bash, Grep, Glob, WebSearch, WebFetch |
| `gsd-assumptions-analyzer` | 深度分析代码库假设 | `/gsd-discuss-phase` (assumptions 模式) | Read, Bash, Grep, Glob |
| `gsd-user-profiler` | 分析开发者行为档案 | `/gsd-profile-user` | Read |

---

## 通用说明

### 平台差异

- `~/.claude/agents/gsd-*.md` — Claude Code 使用的 Markdown 格式代理定义
- `~/.codex/agents/gsd-*.toml` — Codex 使用的 TOML 格式代理定义
- 两者是**同一套代理的两种平台适配**，功能完全一致

### 前置要求

1. 所有 GSD 命令都需要项目根目录存在 `.planning/` 目录结构（由 `/gsd-new-project` 初始化）
2. 部分命令需要额外安装 `gsd-sdk`：
   ```bash
   npm install -g @gsd-build/sdk
   ```
3. `/gsd-inbox` 需要 GitHub CLI (`gh`) 已认证
4. `/gsd-config --profile` 依赖 `gsd-sdk`

### 典型工作流

```
/gsd-new-project      -> 初始化项目（研究→需求→路线图）
/clear
/gsd-discuss-phase 1  -> 讨论阶段上下文
/gsd-plan-phase 1     -> 创建阶段计划
/clear
/gsd-execute-phase 1  -> 执行计划
/gsd-verify-work 1    -> 验证工作
/gsd-ship 1           -> 推送并创建 PR
```

### 参考文件

- GSD 工作流定义: `$HOME/.claude/get-shit-done/workflows/`
- 项目配置: `.planning/config.json`
- 路线图: `.planning/ROADMAP.md`
- 项目说明: `.planning/PROJECT.md`

---

## 交互模式参考

GSD 命令按交互需求分为三类：

| 类别 | 含义 | 识别方式 |
|------|------|----------|
| **必须交互** | 命令设计为向用户提问、确认或选择，无官方非交互退出路径 | 表格中标记为"必须交互" |
| **可选 `--flag`** | 默认交互，但可通过特定 flag 跳过交互直接进入自动模式 | 表格中标记为"可选 `...`" |
| **非交互** | 纯执行命令，全程无需人工介入 | 表格中标记为"非交互" |

### 必须交互的命令（无自动化退出路径）

- `/gsd-phase --insert` — 插入位置和内容需确认
- `/gsd-phase --remove` — 删除确认
- `/gsd-mvp-phase` — 用户故事需交互式构建
- `/gsd-verify-work` — 验证工作需人工审阅
- `/gsd-ui-phase` — UI 设计决策需确认
- `/gsd-ai-integration-phase` — 交互式决策矩阵
- `/gsd-undo` — 确认门（confirmation gate）
- `/gsd-update` — changelog 预览需确认
- `/gsd-debug` — 调试诊断需交互
- `/gsd-forensics` — 如省略 problem 则提示
- `/gsd-import` — 冲突解决需人工介入
- `/gsd-explore` — 苏格拉底式构思
- `/gsd-fast` — 如省略 task 则提示
- `/gsd-manager` — 交互式指挥中心
- `/gsd-new-milestone` — 命名和配置新里程碑
- `/gsd-profile-user` — 生成行为档案需同意
- `/gsd-thread` — 创建/恢复线程需交互
- `/gsd-workstreams` — 创建/切换/完成/恢复工作流
- `/gsd-review-backlog` — 逐项：Promote/Keep/Remove

### 支持非交互模式的命令（加 flag 跳过交互）

| 命令 | 非交互 flag | 用法示例 |
|------|------------|----------|
| `/gsd-new-project` | `--auto @file.md` | `/gsd-new-project --auto @idea.md` |
| `/gsd-discuss-phase` | `--auto`, `--power` | `/gsd-discuss-phase 3 --auto` |
| `/gsd-plan-phase` | `--auto` | `/gsd-plan-phase 3 --auto --skip-research` |
| `/gsd-quick` | flag 组合 | `/gsd-quick --full --validate` |
| `/gsd-ingest-docs` | `--resolve auto` | `/gsd-ingest-docs --resolve auto` |
| `/gsd-code-review` | `--fix --auto` | `/gsd-code-review 3 --fix --auto` |
| `/gsd-audit-fix` | `--dry-run` | `/gsd-audit-fix --dry-run` |
| `/gsd-docs-update` | `--force` | `/gsd-docs-update --force` |
| `/gsd-spike` | `--quick` | `/gsd-spike --quick` |
| `/gsd-sketch` | `--quick`, `--text` | `/gsd-sketch --quick` |
| `/gsd-spec-phase` | `--auto` | `/gsd-spec-phase 3 --auto` |

### 本来就是非交互的命令（纯执行）

`/gsd-execute-phase` `/gsd-ship` `/gsd-progress` `/gsd-resume-work` `/gsd-pause-work` `/gsd-next` `/gsd-quick` `/gsd-ultraplan-phase` `/gsd-plan-review-convergence` `/gsd-autonomous` `/gsd-code-review` `/gsd-review` `/gsd-secure-phase` `/gsd-validate-phase` `/gsd-ui-review` `/gsd-eval-review` `/gsd-audit-uat` `/gsd-audit-milestone` `/gsd-complete-milestone` `/gsd-milestone-summary` `/gsd-add-tests` `/gsd-map-codebase` `/gsd-graphify` `/gsd-stats` `/gsd-health` `/gsd-cleanup` `/gsd-help` `/gsd-inbox` `/gsd-pr-branch` `/gsd-extract-learnings` `/gsd-docs-update` `/gsd-spike --wrap-up` `/gsd-sketch --wrap-up`

### 避免交互式的 5 种方法

#### 方法 1：使用 `--auto` 标志（最常用）

```bash
/gsd-new-project --auto @project-idea.md
/gsd-discuss-phase 3 --auto
/gsd-plan-phase 3 --auto
```

#### 方法 2：使用 `--force` / `--dry-run` 标志

```bash
/gsd-docs-update --force
/gsd-audit-fix --dry-run
```

#### 方法 3：提供所有必需参数

```bash
/gsd-workspace --new --name my-project --repos ./src --auto
```

#### 方法 4：使用 GSD SDK CLI（完全无头模式）

```bash
gsd-sdk init
gsd-sdk auto
```

#### 方法 5：安装时选择 `--minimal` 模式

```bash
npx get-shit-done-cc --claude --global --minimal
```

### 自动化流水线推荐组合

```
1. /gsd-new-project --auto @idea.md           -> 全自动初始化
2. /gsd-plan-phase 1 --auto --skip-research   -> 全自动计划
3. /gsd-execute-phase 1                        -> 执行（本身非交互）
4. /gsd-verify-work 1                          -> 验证
5. /gsd-progress --next                         -> 推进
6. 重复 2-5 直到完成
```

或一步到位：

```bash
gsd-sdk auto  # 完全无头，自动走完整个流程
```
