# GSD Agent Handbook

> **用途：** AI Agent（claude -p, codex exec 等）的 GSD 操作手册。
> **版本：** GSD v1.41.2 | 2026-05-11
> **配套 JSON：** `gsd-agent-handbook.json`（机器可解析的完整命令注册表）

---

## 你的身份

你是一个使用 GSD (Get Shit Done) 框架进行项目开发的 AI Agent。GSD 是一个层级式项目规划系统，将开发工作分解为 **里程碑 → 阶段 → 计划 → 任务**。你的目标是理解用户意图，检测当前项目状态，并执行正确的 GSD 命令序列来完成工作。

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
const phaseResult = await gsd.runPhase('1');

// 或执行单个计划
const planResult = await gsd.executePlan(
  '.planning/phases/01-auth/01-01-PLAN.md'
);
```

### 策略 4：进度路由器

```bash
/gsd-progress --do "fix the login button"       # 自然语言 → 正确命令
/gsd-progress --do "start a new milestone"       # 自然语言 → 正确命令
```

---

## 错误恢复

| 症状 | 原因 | 恢复命令 |
|------|------|----------|
| 执行失败/产生存根 | 计划过于激进 | `/gsd-plan-phase N --gaps` 重新计划更小范围 |
| 计划不对齐 | 缺少 CONTEXT.md | `/gsd-discuss-phase N` → 重新计划 |
| STATE.md 不同步 | 手动编辑或中断 | `gsd-tools.cjs state validate` → `state sync` |
| 验证发现问题 | 实现缺口 | GSD 自动创建修复计划 → 重新执行 |
| 并行执行锁错误 | 构建工具竞争 | `/gsd-config --advanced` → 禁用并行 |
| 上下文退化 | 上下文窗口满 | `/clear` → `/gsd-resume-work` |
| 权限被拒 | settings.json 缺少权限 | 添加 `Bash(git:*)` 等到 permissions.allow |
| 工作流状态损坏 | 意外中断 | `/gsd-forensics` 诊断 → 手动修复或 git revert |

---

## 文件约定

```
.planning/
├── PROJECT.md              # 项目愿景（必须存在才算初始化）
├── ROADMAP.md              # 阶段分解 + 状态（phase 状态的真相来源）
├── STATE.md                # 会话记忆（active_phase, next_action, progress）
├── REQUIREMENTS.md         # 需求 + REQ-ID
├── config.json             # 工作流配置
└── phases/
    └── {NN}-{slug}/
        ├── CONTEXT.md          # 实现偏好（discuss 的输出）
        ├── RESEARCH.md         # 研究发现（plan 的输入）
        ├── {NN}-{MM}-PLAN.md   # 原子执行计划
        ├── {NN}-{MM}-SUMMARY.md # 执行结果
        ├── VERIFICATION.md     # 验证结果
        └── UAT.md              # 人工验证记录
```

**文件命名规则：**
- 阶段目录：`{两位数字}-{slug}/` → `01-foundation/`, `02-auth/`
- 计划文件：`{阶段号}-{计划号}-PLAN.md` → `01-01-PLAN.md`
- 总结文件：`{阶段号}-{计划号}-SUMMARY.md` → `01-01-SUMMARY.md`

---

## 安全预算（SDK 自动模式）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `maxTurns` | 50 | 每步最多对话轮数 |
| `maxBudgetUsd` | $5.0 | 每步最大花费 |
| `allowedTools` | Read/Write/Edit/Bash/Grep/Glob | 工具白名单 |
| `max_discuss_passes` | 3 | 自讨论最大轮数 |
| `plan_check` | true | 执行前检查计划质量 |
| `verifier` | true | 执行后自动验证 |

**注意：** SDK 的 `permissionMode: 'bypassPermissions'` 会跳过所有权限确认。仅在沙箱环境中使用。

---

## 重要提示

1. **先读后写** — 执行命令前先读取 STATE.md 和 ROADMAP.md 确定当前状态
2. **每个命令后读输出** — 检查 SUMMARY.md 和 VERIFICATION.md 确认结果
3. **上下文管理** — 长会话中定期 `/clear`，用 `/gsd-resume-work` 恢复
4. **原子提交** — GSD 的每个任务执行都是原子提交，出错可安全回滚
5. **不要重执行** — 执行后需要修改用 `/gsd-quick`，不要重新运行 `/gsd-execute-phase`
