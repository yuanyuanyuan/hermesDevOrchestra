# GSD 用户指南

> **版本：** GSD v1.41.2
> **更新日期：** 2026-05-13
> **适用人群：** 使用 Claude Code、Codex 等 AI 编码工具的开发者

---

## 目录

- [快速开始](#快速开始)
- [核心概念](#核心概念)
- [完整工作流](#完整工作流)
- [命令详解](#命令详解)
- [配置参考](#配置参考)
- [文件结构](#文件结构)
- [最佳实践](#最佳实践)
- [故障排除](#故障排除)

---

## 快速开始

### 安装

```bash
# 全局安装（推荐）
npx get-shit-done-cc@latest --claude --global

# 最小化安装（仅核心技能，冷启动 ~700 tokens）
npx get-shit-done-cc@latest --claude --global --minimal
```

### 首次使用

```bash
# 1. 启动 Claude Code（跳过权限确认）
claude --dangerously-skip-permissions

# 2. 初始化新项目
/gsd-new-project

# 3. 或者，如果有现有代码库
/gsd-map-codebase
/gsd-new-project
```

### 六步核心循环

```bash
/gsd-new-project           # 1. 初始化
/gsd-discuss-phase 1       # 2. 讨论
/gsd-plan-phase 1          # 3. 计划
/gsd-execute-phase 1       # 4. 执行
/gsd-verify-work 1         # 5. 验证
/gsd-ship 1                # 6. 发布
```

### 更新

```bash
/gsd-update                # 检查并更新到最新版本
```

---

## 核心概念

### GSD 解决什么问题？

GSD 解决了 AI 编码的三个核心问题：

1. **上下文腐蚀（Context Rot）**
   - 问题：随着会话增长，AI 输出质量下降
   - 方案：每个 agent 获得干净的 200K 上下文窗口

2. **无共享记忆（No Shared Memory）**
   - 问题：跨会话/上下文重置时丢失状态
   - 方案：所有状态存储在 `.planning/` 目录的文件中

3. **无验证（No Verification）**
   - 问题："能运行"不等于"能用"
   - 方案：verify 步骤 + 专用调试 agent + 修复计划

### 层级结构

```
里程碑 (Milestone)
  └── 阶段 (Phase)
        └── 计划 (Plan)
              └── 任务 (Task)
```

### 状态机

```
未初始化 → 项目就绪 → 已讨论 → 已计划 → 已执行 → 已验证 → 已发布
    │          │          │         │         │         │         │
    └──────────┴──────────┴─────────┴─────────┴─────────┴─────────┘
                              可以用 /gsd-progress --next 自动推进
```

---

## 完整工作流

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

```bash
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

```bash
/gsd-new-project --auto @prd.md
```

**已有代码库（棕地项目）：**

```bash
/gsd-map-codebase       # 先分析现有代码
/gsd-new-project        # 然后初始化（问题聚焦于你要添加什么）
```

### 第 2 步：讨论阶段上下文

```bash
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

```bash
/gsd-spec-phase 1
```

苏格拉底式规范细化，通过模糊度评分明确阶段交付物。输出 SPEC.md。

### 第 4 步：（可选）UI 设计合同

```bash
/gsd-ui-phase 1
```

仅限前端阶段。锁定间距、排版、颜色、文案合同。

**输出：** `.planning/phases/01-xxx/01-UI-SPEC.md`

### 第 5 步：创建计划

```bash
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

### 第 6 步：执行计划

```bash
/gsd-execute-phase 1
```

GSD：
1. 分析计划依赖关系
2. 将计划分组为波次（Wave）
3. 按波次并行执行，每个执行器获得干净的 200K 上下文
4. 每个任务原子提交

**输出：**

```
.planning/phases/01-xxx/
  01-01-SUMMARY.md    # 执行摘要
  01-02-SUMMARY.md
  VERIFICATION.md     # 验证报告
```

**标志：**
- `--wave N` — 仅执行第 N 波
- `--gaps-only` — 仅执行差距修复

### 第 7 步：验证

```bash
/gsd-verify-work 1
```

GSD 会：
1. 加载 VERIFICATION.md 中的测试场景
2. 逐个展示预期行为
3. 你确认或描述差异
4. 记录问题和严重程度

**输出：** `.planning/phases/01-xxx/UAT.md`

### 第 8 步：发布

```bash
/gsd-ship 1
```

GSD 会：
1. 创建 PR 分支
2. 生成 PR 描述（从规划工件中提取）
3. 创建 GitHub PR

**标志：**
- `--draft` — 创建草稿 PR

### 第 9 步：完成里程碑

```bash
/gsd-audit-milestone        # 审计完成情况
/gsd-complete-milestone     # 归档里程碑
/gsd-new-milestone          # 开始下一个里程碑
```

---

## 命令详解

### 命令前缀

| 运行时 | 命令格式 |
|--------|----------|
| Claude Code | `/gsd-<command>` |
| Codex | `$gsd-<command>` |
| Gemini CLI | `/gsd:<command>` |

### 核心工作流命令

| 命令 | 用途 | 交互性 |
|------|------|--------|
| `/gsd-new-project` | 初始化项目 | 可选 `--auto` |
| `/gsd-discuss-phase N` | 收集偏好 | 可选 `--auto` |
| `/gsd-plan-phase N` | 创建计划 | 可选 `--auto` |
| `/gsd-execute-phase N` | 执行计划 | 非交互 |
| `/gsd-verify-work N` | UAT 验证 | 必须交互 |
| `/gsd-ship N` | 创建 PR | 非交互 |
| `/gsd-progress` | 检查进度 | 非交互 |

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

## 配置参考

### 配置文件位置

`.planning/config.json`

### 核心配置项

```json
{
  "mode": "interactive",
  "model_profile": "balanced",
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "code_review": true,
    "parallelization": {
      "enabled": true
    }
  },
  "git": {
    "base_branch": "main",
    "phase_branch_template": "gsd/{phase-slug}"
  }
}
```

### 模式

| 模式 | 说明 |
|------|------|
| `interactive` | 确认每一步 |
| `yolo` | 自动批准 |

### 模型配置

| Profile | 说明 |
|---------|------|
| `quality` | 使用最高质量模型 |
| `balanced` | 平衡质量和成本 |
| `budget` | 优先成本 |
| `inherit` | 继承运行时默认 |

### 工作流开关

| 键 | 默认 | 说明 |
|----|------|------|
| `workflow.research` | true | 启用领域研究 |
| `workflow.plan_check` | true | 启用计划检查器 |
| `workflow.verifier` | true | 启用验证器 |
| `workflow.code_review` | true | 启用代码审查 |
| `workflow.parallelization.enabled` | true | 启用并行执行 |

---

## 文件结构

### .planning/ 目录

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

## 最佳实践

### 1. 新项目最佳实践

```bash
# 1. 如有现有代码，先映射
/gsd-map-codebase

# 2. 初始化项目
/gsd-new-project

# 3. 审查研究结果
# 检查 .planning/research/ 目录

# 4. 审查路线图
# 检查 .planning/ROADMAP.md

# 5. 开始第一个阶段
/gsd-discuss-phase 1
```

### 2. 阶段执行最佳实践

```bash
# 1. 充分讨论（不要跳过）
/gsd-discuss-phase 1 --all

# 2. 计划并验证
/gsd-plan-phase 1

# 3. 审查计划
# 检查 .planning/phases/01-*/01-*-PLAN.md

# 4. 执行
/gsd-execute-phase 1

# 5. 验证（重要！）
/gsd-verify-work 1

# 6. 代码审查
/gsd-code-review 1

# 7. 发布
/gsd-ship 1
```

### 3. 质量保证最佳实践

- 不要跳过 `/gsd-verify-work`
- 使用 `/gsd-code-review --fix` 自动修复问题
- 使用 `/gsd-review --all` 获取多 AI 评审
- 定期运行 `/gsd-health` 检查规划目录健康

### 4. 上下文管理最佳实践

- 使用 `/gsd-pause-work` 暂停长会话
- 使用 `/gsd-resume-work` 恢复工作
- 使用 `/gsd-thread` 管理跨会话题
- 使用 `/gsd-capture --note` 记录想法

### 5. 调试最佳实践

```bash
# 启动调试会话
/gsd-debug "Bug description"

# 如果需要诊断
/gsd-debug --diagnose "Intermittent error"

# 继续之前的会话
/gsd-debug continue session-slug

# 后期调查
/gsd-forensics "What went wrong"
```

---

## 故障排除

### 命令不显示

```bash
# 重启运行时
# 重新安装
npx get-shit-done-cc@latest
```

### 上下文窗口满了

```bash
# 检查上下文利用率
/gsd-health --context

# 暂停工作
/gsd-pause-work

# 恢复工作
/gsd-resume-work
```

### 计划验证失败

```bash
# 查看验证结果
cat .planning/phases/*/VERIFICATION.md

# 重新计划
/gsd-plan-phase N --gaps
```

### 执行卡住了

```bash
# 检查进度
/gsd-progress

# 诊断问题
/gsd-forensics

# 恢复工作
/gsd-resume-work
```

### 配置问题

```bash
# 检查配置
cat .planning/config.json

# 重新配置
/gsd-config

# 切换配置
/gsd-config --profile balanced
```

---

## 恢复速查

| 场景 | 命令 |
|------|------|
| 上下文重置后 | `/gsd-resume-work` |
| 不知道下一步 | `/gsd-progress` |
| 想自动推进 | `/gsd-progress --next` |
| 快速修复 | `/gsd-fast "task"` |
| 捕获想法 | `/gsd-capture --note "idea"` |
| 调试问题 | `/gsd-debug "issue"` |
| 工作流失败 | `/gsd-forensics` |
| 规划目录损坏 | `/gsd-health --repair` |

---

*用户指南 v1.0 | 2026-05-13*
