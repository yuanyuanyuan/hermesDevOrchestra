# GSD v1.41.2 用户指南

> 生成时间: 2026-05-11
> GSD 版本: 1.41.2
> 来源: GSD 官方文档 + 安装目录实际文件

---

## 目录

- [快速开始](#快速开始)
- [完整工作流详解](#完整工作流详解)
- [命令速查表](#命令速查表)
- [常用场景](#常用场景)
- [配置参考](#配置参考)
- [文件结构](#文件结构)
- [故障排除](#故障排除)
- [恢复速查](#恢复速查)

---

## 快速开始

### 安装

```bash
# 全局安装（推荐）
npx get-shit-done-cc@latest --claude --global

# 最小化安装（仅核心技能，冷启动 ~700 tokens）
npx get-shit-done-cc@latest --claude --global --minimal
```

### 三步启动

```
/gsd-new-project        # 1. 初始化项目
/gsd-plan-phase 1       # 2. 创建计划
/gsd-execute-phase 1    # 3. 执行计划
```

### 更新

```
/gsd-update             # 检查并更新到最新版本
```

---

## 完整工作流详解

### 单阶段项目完整生命周期

```
┌─────────────────────────────────────────────────────────┐
│                    /gsd-new-project                      │
│  提问 → 研究 → 需求 → 路线图                               │
└────────────────────────┬────────────────────────────────┘
                         │
         ┌───────────────▼───────────────┐
         │       FOR EACH PHASE:         │
         │                               │
         │  ┌───────────────────────┐    │
         │  │ /gsd-discuss-phase N  │    │  ← 锁定实现偏好
         │  └───────────┬───────────┘    │
         │              │                │
         │  ┌───────────▼───────────┐    │
         │  │ /gsd-ui-phase N       │    │  ← UI 设计合同（前端阶段）
         │  └───────────┬───────────┘    │
         │              │                │
         │  ┌───────────▼───────────┐    │
         │  │ /gsd-spec-phase N     │    │  ← 规范细化（可选）
         │  └───────────┬───────────┘    │
         │              │                │
         │  ┌───────────▼───────────┐    │
         │  │ /gsd-plan-phase N     │    │  ← 研究 + 计划 + 验证
         │  └───────────┬───────────┘    │
         │              │                │
         │  ┌───────────▼───────────┐    │
         │  │ /gsd-execute-phase N  │    │  ← 波浪式并行执行
         │  └───────────┬───────────┘    │
         │              │                │
         │  ┌───────────▼───────────┐    │
         │  │ /gsd-code-review N    │    │  ← 代码审查（可选）
         │  └───────────┬───────────┘    │
         │              │                │
         │  ┌───────────▼───────────┐    │
         │  │ /gsd-verify-work N    │    │  ← 人工 UAT
         │  └───────────┬───────────┘    │
         │              │                │
         │  ┌───────────▼───────────┐    │
         │  │ /gsd-ship N           │    │  ← 创建 PR
         │  └───────────┬───────────┘    │
         │              │                │
         │     Next Phase? ──────────────┘
         │              │ No
         └──────────────┼────────────────┘
                        │
           ┌────────────▼────────────┐
           │ /gsd-audit-milestone    │
           │ /gsd-complete-milestone │
           └─────────────────────────┘
```

### 第 1 步：初始化项目

```
/gsd-new-project
```

GSD 会：
1. **深度提问** — 了解你在构建什么
2. **领域研究** — 生成 4 个并行研究代理（可选）
3. **需求定义** — 带 v1/v2/out-of-scope 范围划分
4. **路线图创建** — 阶段分解和成功标准

**创建的文件：**

```
.planning/
  PROJECT.md          # 项目愿景和上下文
  REQUIREMENTS.md     # 带 REQ-ID 的范围化需求
  ROADMAP.md          # 阶段分解 + 状态追踪
  STATE.md            # 项目记忆
  config.json         # 工作流模式（interactive/yolo）
```

**从已有文档初始化：**

```
/gsd-new-project --auto @prd.md
```

**已有代码库（棕地项目）：**

```
/gsd-map-codebase       # 先分析现有代码
/gsd-new-project        # 然后初始化（问题聚焦于你要添加什么）
```

### 第 2 步：讨论阶段上下文

```
/gsd-discuss-phase 1
```

GSD 在计划前询问你的实现偏好。这是你塑造**如何**构建的地方。

**输出：** `.planning/phases/01-xxx/CONTEXT.md`

**标志：**
- `--chain` — 链式提示流
- `--analyze` — 深度假设分析
- `--power` — 扩展问题集
- `--assumptions` — 展示 Claude 的假设（无需交互式会话）
- `--batch` — 每次问 2-5 个相关问题

### 第 3 步：（可选）规范细化

```
/gsd-spec-phase 1
```

苏格拉底式规范细化，通过模糊度评分明确阶段交付物。输出 SPEC.md。

### 第 4 步：（可选）UI 设计合同

```
/gsd-ui-phase 1
```

仅限前端阶段。锁定间距、排版、颜色、文案合同。

**输出：** `.planning/phases/01-xxx/01-UI-SPEC.md`

### 第 5 步：创建计划

```
/gsd-plan-phase 1
```

GSD：
1. 生成 4 个并行研究代理（栈、特性、架构、陷阱）
2. Planner 读取 CONTEXT.md + 研究结果创建原子任务计划
3. Plan-checker 验证每个计划是否能达成阶段目标

**输出：**

```
.planning/phases/01-xxx/
  RESEARCH.md         # 研究发现
  01-01-PLAN.md       # 任务：创建核心函数
  01-02-PLAN.md       # 任务：Express 中间件包装器
```

**标志：**
- `--skip-research` — 跳过研究代理
- `--research-phase <N>` — 仅研究模式
- `--tdd` — 测试驱动顺序
- `--mvp` — 垂直切片 MVP 模式

### 第 6 步：执行

```
/gsd-execute-phase 1
```

GSD 将计划分组为波次（独立的并行，依赖的顺序执行），每个计划使用全新的 200k 上下文执行器，每个任务原子提交。

**Git 历史：**

```
a1b2c3d feat(01-01): implement validateSignature with timingSafeEqual
d4e5f6g feat(01-02): add Express middleware wrapper and 401 error format
h7i8j9k chore(01): phase 1 verification — all requirements met
```

**输出：**

```
.planning/phases/01-xxx/
  01-01-SUMMARY.md    # 执行结果和决策
  01-02-SUMMARY.md
  VERIFICATION.md     # 需求覆盖验证
```

### 第 7 步：（可选）代码审查

```
/gsd-code-review 1
```

审查阶段变更的 bug、安全和代码质量问题。

```
/gsd-code-review 1 --fix --auto   # 自动修复 + 重新审查
```

### 第 8 步：验证

```
/gsd-verify-work 1
```

GSD 从阶段目标中提取可测试交付物，逐个引导你验证。

**输出：** `.planning/phases/01-xxx/UAT.md`

如果发现问题，GSD 会自动诊断并创建修复计划。重新执行 `/gsd-execute-phase 1` 后再次验证。

### 第 9 步：发布

```
/gsd-ship 1
```

推送分支、创建 PR、自动从 SUMMARY.md 和 VERIFICATION.md 生成 PR 描述。

### 第 10 步：完成里程碑

```
/gsd-audit-milestone        # 检查所有需求是否已发布
/gsd-complete-milestone 1.0.0   # 归档、打标签、完成
```

---

## 命令速查表

### 核心流水线

| 步骤 | 命令 | 说明 |
|------|------|------|
| 初始化 | `/gsd-new-project` | 研究→需求→路线图 |
| 讨论 | `/gsd-discuss-phase N` | 锁定实现偏好 |
| 规范 | `/gsd-spec-phase N` | 明确交付物（可选） |
| UI 合同 | `/gsd-ui-phase N` | 前端设计合同（可选） |
| 计划 | `/gsd-plan-phase N` | 研究 + 计划 + 验证 |
| 执行 | `/gsd-execute-phase N` | 波浪式并行执行 |
| 审查 | `/gsd-code-review N` | 代码审查（可选） |
| 验证 | `/gsd-verify-work N` | 人工 UAT |
| 发布 | `/gsd-ship N` | 创建 PR |

### 快捷命令

| 场景 | 命令 |
|------|------|
| 快速小任务 | `/gsd-quick` 或 `/gsd-fast` |
| 不知道下一步 | `/gsd-progress` |
| 自然语言路由 | `/gsd-progress --do "描述"` |
| 恢复上下文 | `/gsd-resume-work` |
| 暂停工作 | `/gsd-pause-work` |

### 捕获想法

| 场景 | 命令 |
|------|------|
| 结构化 todo | `/gsd-capture 描述` |
| 零摩擦笔记 | `/gsd-capture --note 文本` |
| Backlog | `/gsd-capture --backlog "想法"` |
| 前瞻种子 | `/gsd-capture --seed "想法"` |
| 查看待办 | `/gsd-capture --list` |

### 阶段管理

| 场景 | 命令 |
|------|------|
| 添加阶段 | `/gsd-phase "描述"` |
| 插入紧急阶段 | `/gsd-phase --insert 7 "描述"` |
| 移除阶段 | `/gsd-phase --remove N` |
| 编辑阶段 | `/gsd-phase --edit N` |

---

## 常用场景

### 新项目（完整周期）

```
/gsd-new-project            # 回答问题、配置、审批路线图
/clear
/gsd-discuss-phase 1        # 锁定偏好
/gsd-ui-phase 1             # 设计合同（前端阶段）
/gsd-plan-phase 1           # 研究 + 计划 + 验证
/gsd-execute-phase 1        # 并行执行
/gsd-verify-work 1          # 人工 UAT
/gsd-ship 1                 # 创建 PR
/clear
/gsd-progress               # 自动检测并运行下一步
...
/gsd-audit-milestone        # 检查是否全部发布
/gsd-complete-milestone     # 归档、打标签、完成
```

### 从已有文档初始化

```
/gsd-new-project --auto @prd.md   # 全自动从文档初始化
/clear
/gsd-discuss-phase 1               # 正常流程从这里开始
```

### 已有代码库

```
/gsd-map-codebase           # 分析现有代码（并行代理）
/gsd-new-project            # 问题聚焦于你要添加什么
# （正常阶段工作流从这里开始）
```

### 快速 Bug 修复

```
/gsd-quick
> "Fix the login button not responding on mobile Safari"
```

### 中断后恢复

```
/gsd-progress               # 查看你在哪里以及下一步
# 或
/gsd-resume-work            # 完整上下文恢复
```

### 准备发布

```
/gsd-audit-milestone        # 检查需求覆盖、检测存根
/gsd-complete-milestone     # 归档、打标签、完成
```

### 中途改变范围

```
/gsd-phase "Add admin dashboard"        # 追加新阶段
/gsd-phase --insert 3 "紧急安全修复"     # 在阶段 3 后插入
/gsd-phase --remove 7                   # 移除阶段 7
```

### 探索与原型

```
/gsd-spike "can we stream LLM output over WebSockets?"  # 技术可行性验证
/gsd-spike --wrap-up                                     # 打包发现

/gsd-sketch "dashboard layout"                           # UI 设计探索
/gsd-sketch --wrap-up                                    # 打包决策
```

### 速度 vs 质量预设

| 场景 | 模式 | 配置 | 研究 | 计划检查 | 验证器 |
|------|------|------|------|----------|--------|
| 原型 | yolo | budget | 关 | 关 | 关 |
| 正常开发 | interactive | balanced | 开 | 开 | 开 |
| 生产 | interactive | quality | 开 | 开 | 开 |

---

## 配置参考

### 模型配置

```
/gsd-config --profile quality    # Opus 全场（除验证）
/gsd-config --profile balanced   # Opus 计划，Sonnet 执行（默认）
/gsd-config --profile budget     # Sonnet 写作，Haiku 研究/验证
/gsd-config --profile inherit    # 使用当前会话模型
```

### 高级配置

```
/gsd-config --advanced           # 计划调优、超时、分支模板、跨 AI 执行
/gsd-config --integrations       # 第三方 API 密钥、代码审查路由
```

### 配置文件

`.planning/config.json` 示例：

```json
{
  "model_profile": "balanced",
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "auto_advance": false,
    "skip_discuss": false,
    "nyquist_validation": true,
    "ui_phase": true,
    "ui_safety_gate": true,
    "context_coverage_gate": true
  },
  "planning": {
    "commit_docs": true,
    "search_gitignored": false
  }
}
```

### 常用配置项

| 设置 | 默认值 | 说明 |
|------|--------|------|
| `workflow.research` | `true` | 启用研究代理 |
| `workflow.plan_check` | `true` | 启用计划检查 |
| `workflow.verifier` | `true` | 启用验证器 |
| `workflow.auto_advance` | `false` | 自动推进（AI 自讨论） |
| `workflow.skip_discuss` | `false` | 跳过讨论阶段 |
| `workflow.nyquist_validation` | `true` | Nyquist 验证层 |
| `workflow.ui_phase` | `true` | UI 设计合同 |
| `workflow.context_coverage_gate` | `true` | 决策覆盖门禁 |
| `planning.commit_docs` | `true` | 规划文件提交到 git |

---

## 文件结构

```
.planning/
├── PROJECT.md              # 项目愿景
├── REQUIREMENTS.md         # 范围化需求 + REQ-ID
├── ROADMAP.md              # 阶段分解 + 状态追踪
├── STATE.md                # 项目记忆 + 上下文
├── RETROSPECTIVE.md        # 活的回顾（每里程碑更新）
├── config.json             # 工作流模式 + 门禁
├── MILESTONES.md           # 已完成里程碑归档
├── HANDOFF.json            # 结构化会话交接（/gsd-pause-work）
├── research/               # 领域研究（/gsd-new-project）
├── reports/                # 会话报告（/gsd-pause-work --report）
├── todos/
│   ├── pending/            # 等待处理的待办
│   └── done/               # 已完成待办
├── notes/                  # 零摩擦笔记（/gsd-capture --note）
├── seeds/                  # 前瞻种子（/gsd-capture --seed）
│   └── SEED-NNN-slug.md
├── debug/                  # 活跃调试会话
│   └── resolved/           # 已归档调试会话
├── spikes/                 # 可行性实验（/gsd-spike）
│   ├── MANIFEST.md
│   └── NNN-name/
├── sketches/               # HTML 草图（/gsd-sketch）
│   ├── MANIFEST.md
│   ├── themes/
│   └── NNN-name/
├── codebase/               # 棕地代码库映射（/gsd-map-codebase）
│   ├── STACK.md
│   ├── ARCHITECTURE.md
│   ├── STRUCTURE.md
│   ├── CONVENTIONS.md
│   ├── TESTING.md
│   ├── INTEGRATIONS.md
│   └── CONCERNS.md
├── milestones/             # 已归档里程碑
│   ├── v1.0-ROADMAP.md
│   ├── v1.0-REQUIREMENTS.md
│   └── v1.0-phases/
├── quick/                  # 快速任务（/gsd-quick）
│   └── NNN-slug/
├── threads/                # 持久上下文线程（/gsd-thread）
│   └── {slug}.md
└── phases/
    ├── 01-foundation/
    │   ├── CONTEXT.md          # 你的实现偏好
    │   ├── RESEARCH.md         # 生态研究发现
    │   ├── 01-01-PLAN.md       # 原子执行计划
    │   ├── 01-01-SUMMARY.md    # 执行结果和决策
    │   ├── VERIFICATION.md     # 执行后验证结果
    │   └── 01-UI-SPEC.md       # UI 设计合同（/gsd-ui-phase）
    └── 02-core-features/
```

---

## 故障排除

### 上下文退化

在主要命令之间清除上下文窗口：Claude Code 中使用 `/clear`。GSD 围绕全新上下文设计 — 每个子代理获得干净的 200K 窗口。

### 计划不对齐

在计划前运行 `/gsd-discuss-phase [N]`。大多数计划质量问题来自 Claude 做出 `CONTEXT.md` 本可以阻止的假设。

### 执行失败或产生存根

检查计划是否过于激进。计划应最多 2-3 个任务。任务太大时，会超出单个上下文窗口能可靠产出的范围。用更小的范围重新计划。

### 迷失方向

运行 `/gsd-progress`。它读取所有状态文件并告诉你确切位置和下一步。

### 执行后需要修改

不要重新运行 `/gsd-execute-phase`。使用 `/gsd-quick` 进行针对性修复，或使用 `/gsd-verify-work` 通过 UAT 系统地识别和修复问题。

### 模型成本过高

切换到 budget 配置：`/gsd-config --profile budget`。如果领域对你（或 Claude）来说很熟悉，通过 `/gsd-settings` 禁用研究和计划检查代理。

### Executor 子代理 Bash 权限被拒

在 `~/.claude/settings.json` 中添加所需模式：

```json
{
  "permissions": {
    "allow": [
      "Write",
      "Edit",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git merge:*)",
      "Bash(npm:*)",
      "Bash(npx:*)",
      "Bash(node:*)"
    ]
  }
}
```

### GSD 更新覆盖了本地修改

运行 `/gsd-update --reapply` 将你的修改合并回来。

### 并行执行构建锁错误

GSD v1.26+ 自动处理此问题。如遇旧版本问题：`/gsd-config --advanced` → 设置 `parallelization.enabled` 为 `false`。

### STATE.md 不同步

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" state validate
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" state sync
```

---

## 恢复速查

| 问题 | 解决方案 |
|------|----------|
| 丢失上下文 / 新会话 | `/gsd-resume-work` 或 `/gsd-progress` |
| 阶段出错 | `git revert` 阶段提交，然后重新计划 |
| 需要改变范围 | `/gsd-phase "描述"` 或 `/gsd-phase --insert` |
| 里程碑审计发现缺口 | `/gsd-plan-milestone-gaps` |
| 某些东西坏了 | `/gsd-debug "描述"`（加 `--diagnose` 仅分析） |
| STATE.md 不同步 | `state validate` 然后 `state sync` |
| 工作流状态似乎损坏 | `/gsd-forensics` |
| 快速针对性修复 | `/gsd-quick` |
| 计划不符合你的愿景 | `/gsd-discuss-phase [N]` 然后重新计划 |
| 成本过高 | `/gsd-config --profile budget` |
| 更新破坏了本地修改 | `/gsd-update --reapply` |
| 不知道下一步是什么 | `/gsd-progress` 或 `/gsd-progress --next` |

---

## 附录：v1.41.2 新功能速查

### 6 个命名空间路由器

| 命名空间 | 命令 | 路由内容 |
|----------|------|----------|
| 工作流 | `/gsd-ns-workflow` | discuss, plan, execute, verify, phase, progress |
| 项目 | `/gsd-ns-project` | milestones, audits, summary |
| 审查 | `/gsd-ns-review` | code review, debug, audit, security, eval, ui |
| 上下文 | `/gsd-ns-context` | map, graphify, docs, learnings |
| 构思 | `/gsd-ns-ideate` | explore, sketch, spike, spec, capture |
| 管理 | `/gsd-ns-manage` | workstreams, thread, update, ship, inbox |

### Phase 生命周期状态行

STATE.md 新增字段：
- `active_phase` — 当前活跃阶段
- `next_action` — 下一步动作
- `progress` — 完成/总计/百分比

### 上下文窗口守护

```
/gsd-health --context    # 60% 警告，70% 严重
```

### MVP 垂直切片

```
/gsd-mvp-phase 1         # 用户故事 + SPIDR 拆分 + 计划
```
