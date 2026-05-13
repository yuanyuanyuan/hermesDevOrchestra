# GSD AI Agent 操作手册 — Claude Code 版

> **用途：** AI Agent（claude -p, Claude Code 等）的 GSD 操作手册
> **版本：** GSD v1.41.2
> **命令前缀：** `/gsd-<command>`
> **配套文件：** `gsd-agent-handbook.json`（机器可解析）

---

## 你的身份

你是一个使用 GSD (Get Shit Done) 框架进行项目开发的 AI Agent。GSD 是一个层级式项目规划系统，将开发工作分解为 **里程碑 → 阶段 → 计划 → 任务**。

你的目标是：
1. 理解用户意图
2. 检测当前项目状态
3. 执行正确的 GSD 命令序列来完成工作

---

## 状态检测（每次操作前必做）

在执行任何 GSD 命令前，**先读取以下文件确定当前位置**：

```bash
# 1. 项目是否已初始化？
ls .planning/PROJECT.md .planning/ROADMAP.md

# 2. 当前阶段状态
cat .planning/STATE.md | head -30

# 3. 有哪些阶段？
grep -E "^## Phase" .planning/ROADMAP.md

# 4. 当前阶段的进度
ls .planning/phases/*/
```

**状态判断规则：**

| 你看到的 | 当前状态 | 下一步命令 |
|----------|----------|-----------|
| 无 `.planning/` 目录 | 未初始化 | `/gsd-new-project` |
| PROJECT.md 存在，所有 phase 为 pending | 项目就绪 | `/gsd-discuss-phase 1` |
| CONTEXT.md 存在，无 PLAN.md | 已讨论 | `/gsd-plan-phase N` |
| PLAN.md 存在，无 SUMMARY.md | 已计划 | `/gsd-execute-phase N` |
| SUMMARY.md 存在，无 UAT.md | 已执行 | `/gsd-verify-work N` |
| UAT.md 存在，全部通过 | 已验证 | `/gsd-ship N` |
| 所有 phase 为 completed | 里程碑完成 | `/gsd-complete-milestone` |
| 不确定 | — | `/gsd-progress` |

---

## 核心工作流（单阶段）

```
/gsd-new-project        → 初始化
/gsd-discuss-phase N    → 收集偏好 → CONTEXT.md
/gsd-plan-phase N       → 研究 + 计划 → *-PLAN.md
/gsd-execute-phase N    → 波浪执行 → *-SUMMARY.md
/gsd-verify-work N      → UAT 验证 → UAT.md
/gsd-ship N             → 创建 PR
```

**阶段间的可选增强：**

```
/gsd-spec-phase N       → 规范细化（可选，在 discuss 之后）
/gsd-ui-phase N         → UI 设计合同（前端阶段）
/gsd-code-review N      → 代码审查（执行后）
/gsd-secure-phase N     → 安全审计
```

---

## 命令速查（按场景）

### 用户说"做个新项目"

```
/gsd-new-project                    # 交互式
/gsd-new-project --auto @prd.md     # 从 PRD 文件自动初始化
```

### 用户说"继续做" / "下一步" / "做到哪了"

```
/gsd-progress                       # 显示进度 + 智能路由
/gsd-progress --next                # 自动推进到下一步
/gsd-resume-work                    # 恢复上次会话上下文
```

### 用户描述了一个任务

```
# 小任务（typo、config、简单添加）
/gsd-fast "fix the typo in README"

# 中等任务（需要计划但不走完整流水线）
/gsd-quick "fix the login button on mobile Safari"

# 完整任务（走完整流水线）
/gsd-discuss-phase N → /gsd-plan-phase N → /gsd-execute-phase N → /gsd-verify-work N
```

### 用户说"加个功能" / "改一下范围"

```
/gsd-phase "Add admin dashboard"           # 追加新阶段
/gsd-phase --insert 7 "Critical fix"      # 在阶段 7 后插入 7.1
/gsd-phase --remove 7                     # 移除阶段 7
/gsd-phase --edit 3 --force               # 编辑阶段 3
```

### 用户说"记住这个想法"

```
/gsd-capture "idea description"            # 结构化 todo
/gsd-capture --note "quick note"           # 零摩擦笔记
/gsd-capture --backlog "future idea"       # Backlog 停车场
/gsd-capture --seed "idea with triggers"   # 前瞻种子
```

### 用户说"调研一下" / "能不能做"

```
/gsd-spike "can we stream LLM output over WebSockets?"  # 技术可行性
/gsd-sketch "dashboard layout"                           # UI 探索
/gsd-explore                                             # 苏格拉底式构思
```

### 用户说"看看代码"

```
/gsd-map-codebase                  # 完整代码库分析
/gsd-map-codebase --fast           # 快速概览
/gsd-map-codebase --query auth     # 查询代码库情报
/gsd-graphify build                # 构建知识图谱
```

### 用户说"修 bug" / "出错了"

```
/gsd-debug "form submission fails silently"    # 开始调试会话
/gsd-debug --diagnose                          # 一次性诊断（不开会话）
/gsd-forensics                                 # 工作流失败的事后调查
/gsd-health --repair                           # 修复规划目录健康问题
```

### 用户说"配置" / "设置"

```
/gsd-config                        # 常用开关
/gsd-config --profile budget       # 切换模型配置
/gsd-config --profile quality      # 质量优先
/gsd-config --advanced             # 高级调优
```

### 用户说"更新"

```
/gsd-update                        # 检查并更新
/gsd-update --reapply              # 更新后重新应用本地修改
```

---

## 非交互模式策略

### 策略 1：--auto 标志（最常用）

```bash
/gsd-new-project --auto @prd.md
/gsd-discuss-phase 1 --auto
/gsd-plan-phase 1 --auto --skip-research
```

### 策略 2：SDK 完全无头模式

```bash
# 整个里程碑自动执行
gsd-sdk auto

# 从 PRD 初始化 + 自动执行
gsd-sdk auto --init @prd.md

# 指定模型和预算
gsd-sdk auto --model claude-opus-4-6 --max-budget 10
```

### 策略 3：程序化 API

> **注意**: `@gsd-build/sdk` 是嵌套在 `get-shit-done-cc` 包内的子包。如需使用程序化 API，请单独安装：`npm install @gsd-build/sdk`

```typescript
import { GSD } from '@gsd-build/sdk';

const gsd = new GSD({
  projectDir: '/path/to/project',
  autoMode: true,
  model: 'claude-opus-4-6',
  maxBudgetUsd: 10,
});

// 执行整个里程碑
const result = await gsd.run('');

// 或执行单个阶段
const result = await gsd.run('phase 1');
```

---

## 命令详细参考

### 核心流水线命令

| 命令 | 用途 | 输出 | 交互性 |
|------|------|------|--------|
| `/gsd-new-project` | 初始化项目 | PROJECT.md, ROADMAP.md, STATE.md | 可选 `--auto` |
| `/gsd-discuss-phase N` | 收集偏好 | CONTEXT.md | 可选 `--auto` |
| `/gsd-plan-phase N` | 创建计划 | PLAN.md, RESEARCH.md | 可选 `--auto` |
| `/gsd-execute-phase N` | 执行计划 | SUMMARY.md, 代码提交 | 非交互 |
| `/gsd-verify-work N` | UAT 验证 | UAT.md | 必须交互 |
| `/gsd-ship N` | 创建 PR | GitHub PR | 非交互 |
| `/gsd-progress` | 检查进度 | 进度报告 | 非交互 |

### 捕获命令

| 命令 | 用途 | 输出位置 |
|------|------|----------|
| `/gsd-capture "idea"` | 结构化 todo | `.planning/todos/pending/` |
| `/gsd-capture --note "text"` | 零摩擦笔记 | `.planning/notes/` |
| `/gsd-capture --backlog "idea"` | Backlog | ROADMAP.md (999.x) |
| `/gsd-capture --seed "idea"` | 前瞻种子 | `.planning/seeds/` |
| `/gsd-capture --list` | 列出待办 | 交互式浏览器 |

### 阶段管理命令

| 命令 | 用途 |
|------|------|
| `/gsd-phase "desc"` | 追加新阶段 |
| `/gsd-phase --insert N "desc"` | 插入小数阶段 |
| `/gsd-phase --remove N` | 移除阶段 |
| `/gsd-phase --edit N` | 编辑阶段 |

### 快速执行命令

| 命令 | 用途 | 复杂度 |
|------|------|--------|
| `/gsd-fast "task"` | 极简任务 | ≤ 3 文件 |
| `/gsd-quick "task"` | 中等任务 | 可配置 |
| `/gsd-quick --full "task"` | 完整管道 | 全流程 |

### 探索与调研命令

| 命令 | 用途 |
|------|------|
| `/gsd-spike "topic"` | 技术可行性探索 |
| `/gsd-sketch "topic"` | UI 线框/布局探索 |
| `/gsd-explore` | 苏格拉底式构思 |

### 质量与审查命令

| 命令 | 用途 |
|------|------|
| `/gsd-code-review N` | 代码审查 |
| `/gsd-code-review N --fix` | 审查并修复 |
| `/gsd-code-review N --fix --auto` | 修复循环 |
| `/gsd-review --phase N --all` | 跨 AI 评审 |
| `/gsd-secure-phase N` | 安全审计 |
| `/gsd-ui-review N` | UI 审计 |
| `/gsd-eval-review N` | AI 评估审计 |

### 调试命令

| 命令 | 用途 |
|------|------|
| `/gsd-debug "issue"` | 开始调试会话 |
| `/gsd-debug --diagnose` | 一次性诊断 |
| `/gsd-debug list` | 列出活跃会话 |
| `/gsd-debug continue slug` | 继续会话 |
| `/gsd-forensics` | 工作流失败调查 |

### 代码库分析命令

| 命令 | 用途 |
|------|------|
| `/gsd-map-codebase` | 完整分析（4 并行 agent） |
| `/gsd-map-codebase --fast` | 快速概览 |
| `/gsd-map-codebase --query term` | 查询 intel |
| `/gsd-graphify build` | 构建知识图谱 |
| `/gsd-ingest-docs` | 从文档引导 |

### 里程碑命令

| 命令 | 用途 |
|------|------|
| `/gsd-new-milestone` | 开始新里程碑 |
| `/gsd-milestone-summary` | 生成摘要 |
| `/gsd-audit-milestone` | 审计完成情况 |
| `/gsd-complete-milestone` | 归档里程碑 |

### 配置命令

| 命令 | 用途 |
|------|------|
| `/gsd-config` | 常用设置 |
| `/gsd-config --advanced` | 高级设置 |
| `/gsd-config --profile quality` | 切换配置 |
| `/gsd-config --integrations` | 集成设置 |
| `/gsd-settings` | 交互式设置向导 |

### 会话管理命令

| 命令 | 用途 |
|------|------|
| `/gsd-pause-work` | 暂停工作 |
| `/gsd-resume-work` | 恢复工作 |
| `/gsd-thread "topic"` | 创建线程 |
| `/gsd-thread list` | 列出线程 |
| `/gsd-manager` | 交互式命令中心 |

---

## Agent 参考

### 研究类 Agents（可并行）

| Agent | 职责 | 调用者 |
|-------|------|--------|
| gsd-project-researcher | 项目研究（4 并行） | `/gsd-new-project` |
| gsd-phase-researcher | 阶段研究 | `/gsd-plan-phase` |
| gsd-ui-researcher | UI 设计合约 | `/gsd-ui-phase` |
| gsd-advisor-researcher | 灰色地带决策 | `discuss-phase --assumptions` |
| gsd-framework-selector | AI 框架选择 | `/gsd-ai-integration-phase` |
| gsd-pattern-mapper | 代码模式分析 | `/gsd-plan-phase` |

### 规划类 Agents

| Agent | 职责 | 调用者 |
|-------|------|--------|
| gsd-planner | 创建阶段计划 | `/gsd-plan-phase` |
| gsd-roadmapper | 创建路线图 | `/gsd-new-project` |
| gsd-eval-planner | AI 评估策略 | `/gsd-ai-integration-phase` |

### 执行类 Agents

| Agent | 职责 | 调用者 |
|-------|------|--------|
| gsd-executor | 执行计划 | `/gsd-execute-phase` |
| gsd-code-fixer | 代码修复 | `/gsd-code-review --fix` |

### 验证类 Agents

| Agent | 职责 | 调用者 |
|-------|------|--------|
| gsd-verifier | 目标验证 | `/gsd-verify-work` |
| gsd-plan-checker | 计划验证 | `/gsd-plan-phase` |
| gsd-code-reviewer | 代码审查 | `/gsd-code-review` |
| gsd-security-auditor | 安全审计 | `/gsd-secure-phase` |
| gsd-ui-auditor | UI 审计 | `/gsd-ui-review` |
| gsd-ui-checker | UI 合约验证 | `/gsd-ui-phase` |
| gsd-nyquist-auditor | 测试覆盖审计 | `/gsd-validate-phase` |
| gsd-eval-auditor | AI 评估审计 | `/gsd-eval-review` |
| gsd-integration-checker | 集成验证 | 里程碑审计 |

### 文档类 Agents

| Agent | 职责 | 调用者 |
|-------|------|--------|
| gsd-doc-writer | 写文档 | `/gsd-docs-update` |
| gsd-doc-classifier | 文档分类 | `/gsd-ingest-docs` |
| gsd-doc-synthesizer | 文档综合 | `/gsd-ingest-docs` |

### 综合类 Agents

| Agent | 职责 | 调用者 |
|-------|------|--------|
| gsd-research-synthesizer | 研究综合 | `/gsd-new-project` |
| gsd-intel-updater | Intel 更新 | `/gsd-map-codebase` |

### 调试类 Agents

| Agent | 职责 | 调用者 |
|-------|------|--------|
| gsd-debugger | Bug 调查 | `/gsd-debug` |
| gsd-debug-session-manager | 调试会话管理 | `/gsd-debug` |

---

## Workflow 参考

### 核心生命周期

| Workflow | 触发命令 | 产出 |
|----------|----------|------|
| discuss-phase | `/gsd-discuss-phase` | CONTEXT.md |
| plan-phase | `/gsd-plan-phase` | PLAN.md, RESEARCH.md |
| execute-phase | `/gsd-execute-phase` | SUMMARY.md, 代码 |
| verify-work | `/gsd-verify-work` | UAT.md |
| ship | `/gsd-ship` | PR |

### 项目初始化

| Workflow | 触发命令 | 产出 |
|----------|----------|------|
| new-project | `/gsd-new-project` | PROJECT.md 等 |
| new-milestone | `/gsd-new-milestone` | 更新的 PROJECT.md |
| map-codebase | `/gsd-map-codebase` | 代码库分析 |
| ingest-docs | `/gsd-ingest-docs` | .planning/ 结构 |

### 阶段管理

| Workflow | 触发命令 | 产出 |
|----------|----------|------|
| add-phase | `/gsd-phase` | 更新 ROADMAP.md |
| insert-phase | `/gsd-phase --insert` | 小数阶段 |
| edit-phase | `/gsd-phase --edit` | 编辑的阶段 |
| mvp-phase | `/gsd-mvp-phase` | MVP 计划 |
| ui-phase | `/gsd-ui-phase` | UI-SPEC.md |
| ai-integration-phase | `/gsd-ai-integration-phase` | AI-SPEC.md |

### 质量与审查

| Workflow | 触发命令 | 产出 |
|----------|----------|------|
| code-review | `/gsd-code-review` | REVIEW.md |
| code-review-fix | `/gsd-code-review --fix` | 修复的代码 |
| review | `/gsd-review` | 跨 AI 评审 |
| secure-phase | `/gsd-secure-phase` | SECURITY.md |
| eval-review | `/gsd-eval-review` | EVAL-REVIEW.md |
| ui-review | `/gsd-ui-review` | UI-REVIEW.md |

### 调试

| Workflow | 触发命令 | 产出 |
|----------|----------|------|
| debug | `/gsd-debug` | 调试会话 |
| diagnose-issues | `/gsd-debug --diagnose` | 诊断结果 |
| forensics | `/gsd-forensics` | 调查报告 |
| node-repair | 自动触发 | 修复的节点 |

### 捕获与组织

| Workflow | 触发命令 | 产出 |
|----------|----------|------|
| add-todo | `/gsd-capture` | todo 文件 |
| note | `/gsd-capture --note` | 笔记文件 |
| add-backlog | `/gsd-capture --backlog` | backlog 条目 |
| explore | `/gsd-explore` | 探索结果 |
| thread | `/gsd-thread` | 线程文件 |

---

## 最佳实践

1. **总是先检测状态** — 在执行任何命令前，先读取 STATE.md 和 ROADMAP.md
2. **使用 --auto** — 非交互模式下，使用 `--auto` 标志
3. **从 PRD 初始化** — 使用 `/gsd-new-project --auto @prd.md` 快速启动
4. **小任务用 fast** — 简单任务用 `/gsd-fast`，不要走完整流水线
5. **捕获想法** — 随时用 `/gsd-capture --note` 记录灵感
6. **恢复用 resume** — 新会话开始时用 `/gsd-resume-work` 恢复上下文

---

*AI Agent 操作手册 v1.0 | Claude Code 版 | 2026-05-13*
