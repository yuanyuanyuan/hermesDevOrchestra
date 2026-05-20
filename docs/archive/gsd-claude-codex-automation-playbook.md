# Claude Code + GSD + Codex CLI 自动化开发方案
> **归档状态**: 已归档
> **归档日期**: 2026-05-20
> **原始位置**: docs/gsd-claude-codex-automation-playbook.md
> **说明**: 本文档为历史版本，内容可能已被后续迭代取代，仅供参考。


> 基于 GSD v1.41.2 文档整理
> 适用场景：在 Claude Code 中使用 GSD 技能完成开发任务，并通过 Codex CLI 等外部模型进行自动化 Review
>
> **核心原则：优先使用 GSD 原生自动化能力，只在 GSD 覆盖不到的地方做增值设计。**

---

## 一、环境准备

### 1.1 安装 Claude Code

```bash
# 已安装则跳过
npm install -g @anthropic-ai/claude-code

# 验证
claude --version
```

### 1.2 安装 GSD 技能（Claude Code 版）

```bash
# 全局安装 GSD 技能（推荐）
npx get-shit-done-cc@latest --claude --global
```

### 1.3 安装 Codex CLI（外部 Review 模型）

```bash
# 安装 OpenAI Codex CLI
npm install -g @openai/codex

# 验证可用
codex --version
```

---

## 二、项目初始化与自动化配置

### 2.1 启动 Claude Code（推荐跳过权限确认，提升自动化效率）

```bash
claude --dangerously-skip-permissions
```

### 2.2 初始化项目

**方式 A：交互式初始化（首次使用）**
```bash
/gsd-new-project
# 按提示回答项目问题
```

**方式 B：从 PRD 自动初始化（已有需求文档）**
```bash
/gsd-new-project --auto @prd.md
```

**方式 C：已有代码库（棕地项目）**
```bash
/gsd-map-codebase        # 先分析现有代码（4 并行 agent 深度分析）
/gsd-new-project         # 然后初始化
```

### 2.3 配置自动化模式（减少人工干预）

编辑 `.planning/config.json`：

```json
{
  "mode": "yolo",
  "model_profile": "quality",
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

| 配置项 | 说明 |
|--------|------|
| `mode: "yolo"` | 自动批准，无需每步确认（对比 `interactive`） |
| `model_profile: "quality"` | 使用最高质量模型 |
| `workflow.code_review: true` | 默认启用代码审查 |
| `workflow.parallelization.enabled` | 启用波次并行执行 |

> **注意：** `cross_ai` 和 `convergence` 不是 config.json 的原生字段。跨 AI Review 通过 `/gsd-review N --codex` 命令手动调用，收敛循环默认禁用（需手动触发 `/gsd-plan-review-convergence`）。

---

## 三、标准开发工作流

> GSD 提供三种自动化方案，按需选择。推荐优先使用方案 A（原生自动化）。

### 3.1 方案 A：全自动（推荐）— 使用 `/gsd-autonomous`

GSD 原生的全里程碑自动化命令，自动循环 discuss → plan → execute，无需手动拼接步骤。

```
/gsd-new-project                → 初始化项目
    │
    ▼
/gsd-autonomous                 → 自动循环所有阶段（discuss→plan→execute）
    │                              支持 --from N / --to N / --only N 范围控制
    │                              仅在"明确的用户决策"时暂停
    ▼
/gsd-verify-work N              → UAT 验证（yolo 模式自动通过）
    │
    ▼
/gsd-ship N                     → 创建 PR
```

**完整命令：**
```bash
# 自动执行所有剩余阶段
/gsd-autonomous

# 只执行阶段 3 到 5
/gsd-autonomous --from 3 --to 5

# 只执行阶段 4
/gsd-autonomous --only 4
```

**优点：** GSD 原生能力，自动处理阶段间的依赖和状态转换，支持动态插入的阶段。
**限制：** 不包含 verify-work 和 ship，需要在 autonomous 完成后手动执行。内置 `/gsd-code-review`（代码审查），但**不包含** `/gsd-review`（跨 AI 计划审查）。如需 Codex Review，需在 autonomous 完成后手动补充。

---

### 3.2 方案 B：单阶段精细控制

当需要对单个阶段做精细控制时，手动执行每一步：

```
/gsd-discuss-phase N --auto     → 收集偏好（--auto 自动回答）
    │
    ▼
/gsd-plan-phase N --auto        → 创建计划（--auto 跳过确认）
    │
    ▼
/gsd-execute-phase N            → 波浪式并行执行
    │
    ▼
/gsd-verify-work N              → UAT 验证（yolo 模式自动通过）
    │
    ▼
/gsd-ship N                     → 创建 PR
```

**各步骤详细说明：**

**Step 1: 讨论阶段（自动模式）**
```bash
/gsd-discuss-phase N --auto
```
- 输出：`.planning/phases/{N}-xxx/{N}-CONTEXT.md`
- `--auto`：自动回答偏好问题，无需交互（v1.41.2 已确认支持）

**Step 2: 计划阶段（自动模式）**
```bash
/gsd-plan-phase N --auto
```
- 输出：`.planning/phases/{N}-xxx/{N}-RESEARCH.md` + `{N}-01-PLAN.md`
- 自动运行 4 个并行研究 agent
- 自动生成原子任务计划

**Step 3: 执行阶段**
```bash
/gsd-execute-phase N
```
- 分析计划依赖，分组为 Wave
- 每个执行器获得干净的 200K 上下文窗口
- 按波次并行执行，原子提交

**Step 4: 验证阶段**
```bash
/gsd-verify-work N
```
- 加载 VERIFICATION.md 测试场景
- yolo 模式下自动验证，不等待用户确认
- **注意：verify-work 没有 `--auto` 参数，只能通过 config.json 的 `mode: "yolo"` 实现非交互**

**Step 5: 发布**
```bash
/gsd-ship N
```
- 创建 PR 分支，生成 PR 描述，创建 GitHub PR

---

### 3.3 方案 C：带跨 AI Review 的增强流程（可选）

在方案 B 基础上，插入 Codex 跨 AI Review（可选的质量增强层）：

```
/gsd-discuss-phase N --auto     → 收集偏好
    │
    ▼
/gsd-plan-phase N --auto        → 创建计划
    │
    ▼
/gsd-review N --codex           → 【可选】Codex 审查计划
    │                              检查 HIGH 问题数，有则重新计划
    ▼
/gsd-execute-phase N            → 波浪式并行执行
    │
    ▼
/gsd-code-review N              → Claude 代码审查
    │                              支持 --depth quick|standard|deep
    ▼
/gsd-review N --codex           → 【可选】Codex 审查计划+代码上下文
    │                              主要审查 PLAN.md + PROJECT.md + REQUIREMENTS.md
    ▼
/gsd-verify-work N              → UAT 验证
    │
    ▼
/gsd-ship N                     → 创建 PR
```

**跨 AI Review 详细说明：**

```bash
# 仅调用 Codex 审查
/gsd-review N --codex

# 调用所有可用 CLI 并行审查
/gsd-review N --all

# 指定多个外部模型
/gsd-review N --codex --gemini
```

**机制说明：**
- GSD 检测系统上可用的 AI CLI（codex, gemini, claude, opencode, qwen, cursor, ollama, lm-studio, llama-cpp）
- 自动跳过当前运行时的 CLI（确保对抗性独立性）
- 为每个 CLI 生成相同的审查提示（基于 PLAN.md + PROJECT.md + REQUIREMENTS.md）
- **并行运行**外部 AI 审查
- 收集各模型的结构化反馈
- 合并到 `.planning/phases/{N}-xxx/{N}-REVIEWS.md`

**REVIEWS.md 解析注意：**
- 可能包含多个 reviewer 段落（`## Codex Review`、`## Claude Review` 等）
- 遍历**所有** `## * Review` 段落下的 `### Concerns`，对每个 reviewer 的 HIGH 问题取并集
- `## Consensus Summary` 中的 `### Divergent Views` 表示不同 reviewer 结论矛盾，需升级用户

**产出文件：**
```
.planning/phases/{N}-xxx/
  REVIEWS.md          # 跨 AI 审查意见（合并多 CLI 反馈）
  REVIEW.md           # Claude 代码审查（单 agent）
```

**代码审查深度控制：**
```bash
# 快速 review（仅 HIGH 问题，节省上下文）
/gsd-code-review N --depth quick

# 标准 review（平衡）
/gsd-code-review N --depth standard

# 深度 review（仅在关键阶段使用）
/gsd-code-review N --depth deep

# 审查并自动修复
/gsd-code-review N --fix

# 审查特定文件
/gsd-code-review N --files=file1.ts,file2.ts
```

> **注意：** `--depth` 和 `--files` 是 `/gsd-code-review` 的参数，不是 `/gsd-review` 的参数。`/gsd-review` 只接受 CLI 选择器（`--codex`/`--gemini`/`--all` 等）。

---

## 四、状态管理（使用 GSD 原生能力）

> **不需要自定义 Phase 自动检测机制。** GSD 原生的 `/gsd-progress --next` 已经实现了自动读取 STATE.md → 检测当前阶段 → 路由到下一步的能力。

### 4.1 自动推进（替代自定义 Phase 检测）

```bash
# 查看当前进度 + 智能路由建议
/gsd-progress

# 自动检测状态并推进到下一步
/gsd-progress --next
```

`/gsd-progress --next` 的工作原理：
1. 调用 `gsd-sdk query init.progress` 获取项目状态 JSON（project_exists, current_phase, next_phase 等）
2. 调用 `gsd-sdk query roadmap.analyze` 获取阶段磁盘状态（complete/partial/planned/empty）
3. 基于**文件计数法**路由：统计 `*-PLAN.md` 和 `*-SUMMARY.md` 数量
   - `summaries < plans` → 有未执行的计划 → 建议 execute
   - `summaries = plans AND plans > 0` → 检查里程碑状态
   - `plans = 0` → 需要规划
4. 自动路由到下一个需要执行的 GSD 命令

> **注意：** 状态检测基于文件计数，不是 STATE.md 字段解析。如果之前 `/gsd-pause-work` 过，HANDOFF.json 存在时应优先 `/gsd-resume-work`。

### 4.2 跨会话恢复

```bash
# 暂停工作（创建 HANDOFF.json + .continue-here.md，检查虚假完成）
/gsd-pause-work

# 恢复工作（从 .planning/ 文件恢复完整上下文）
/gsd-resume-work
```

**恢复后，新 agent 只读这些文件，不继承对话历史：**
```
.planning/STATE.md         → 当前位置和决策
.planning/ROADMAP.md       → 阶段状态
.planning/phases/{N}-*/     → 当前阶段上下文
```

### 4.3 线程管理（跨会话主题追踪）

```bash
# 创建命名线程，跨会话保持一致上下文锚点
/gsd-thread "auth-refactor"

# 列出所有线程
/gsd-thread list
```

---

## 五、上下文满载应对策略

> 自动化流程最大的敌人：**上下文满载导致输出质量断崖式下降（Context Rot）**

### 5.1 为什么自动化更容易满载？

| 原因 | 说明 |
|------|------|
| **连续执行** | 自动化流程不自然停顿，对话历史持续累积 |
| **Review 结果膨胀** | Codex/Gemini 的审查意见可能很长，合并到 REVIEWS.md 后进一步占用上下文 |
| **多轮迭代** | 收敛循环（plan-review-convergence）每轮都叠加新的计划+审查 |
| **无人工间隙** | 没有人类用户"休息"来触发会话重置 |

### 5.2 GSD 内置的上下文保护机制

```
┌─────────────────────────────────────────────────────────────┐
│  GSD 三层上下文防护                                          │
├─────────────────────────────────────────────────────────────┤
│ L1: Fresh Context Per Agent                                  │
│    - discuss/plan/execute/verify 各阶段启动独立 agent         │
│    - 每个 agent 只携带必要文件（非全部历史）                   │
│    - 执行器按 Wave 分组，每组干净 200K 上下文                 │
├─────────────────────────────────────────────────────────────┤
│ L2: 文件即状态（File-Based State）                            │
│    - 所有状态写入 .planning/，不留在对话中                     │
│    - 跨会话恢复：新 agent 读文件即可，无需对话历史              │
│    - STATE.md / ROADMAP.md / CONTEXT.md 作为上下文锚点        │
├─────────────────────────────────────────────────────────────┤
│ L3: 实时监控 + 自动暂停                                       │
│    - gsd-context-monitor.js: 35%/25% 剩余时注入警告            │
│    - gsd-statusline.js: 状态栏显示上下文使用条                 │
│    - /gsd-health --context: 主动检查利用率                     │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 预防策略（在满载前截断）

#### ① 阶段拆分原则

```bash
# ❌ 错误：一个阶段塞太多功能
/gsd-phase "Build entire e-commerce system"

# ✅ 正确：拆为独立小阶段
/gsd-phase "User auth API"
/gsd-phase "Product catalog API"
/gsd-phase "Order checkout flow"
/gsd-phase "Payment integration"
```

每个阶段完成后自动归档，新阶段从干净上下文开始。

#### ② 小任务不走完整流水线

```bash
# ≤ 3 文件修改：用 fast（极简上下文，无 PLAN.md，无子 agent）
/gsd-fast "fix typo in README"

# 中等任务：用 quick（可控上下文，生成 planner+executor）
/gsd-quick "update login button style"

# 只有大功能才走完整 discuss → plan → execute
```

#### ③ 限制 Review 输出长度

```bash
# 快速 review（仅 HIGH 问题，节省上下文）
/gsd-code-review N --depth quick

# 标准 review（平衡）
/gsd-code-review N --depth standard

# 深度 review（仅在关键阶段使用）
/gsd-code-review N --depth deep
```

#### ④ 精简配置模式

```json
{
  "mode": "yolo",
  "workflow": {
    "research": false,
    "plan_check": true,
    "verifier": true,
    "code_review": true
  }
}
```
- `research: false`：跳过 4 并行研究 agent（省大量上下文）
- `plan_check: true`：保留计划验证（质量不妥协）

### 5.4 检测策略（及时发现压力）

#### ① 状态栏实时监控

GSD 安装后，Claude Code 状态栏会显示：
```
[Claude-4] | Task: phase-1-execute | CTX: ████████░░ 78%
```

- **绿色（< 60%）**：安全
- **黄色（60-70%）**：警告，建议尽快暂停但不强制
- **红色（>= 70%）**：必须立即暂停（`/gsd-pause-work` → 新 session → `/gsd-resume-work`）

#### ② 上下文健康检查

```bash
# 检查当前上下文利用率（注意：无 --json 输出，返回文本报告）
/gsd-health --context

# 检查并修复 .planning/ 目录完整性
/gsd-health --repair
```

#### ③ 跨 AI Review 时的特殊注意

跨 AI Review 会产生额外的 REVIEWS.md，占用上下文。建议：
- 执行 `/gsd-review N --all` 前先检查上下文
- 收敛循环每轮后检查，超过 60% 即退出

### 5.5 恢复策略（满载后如何优雅恢复）

```bash
# Step 1: 暂停当前会话（自动检查虚假完成，写入 HANDOFF.json）
/gsd-pause-work

# Step 2: 退出 Claude Code（或开新窗口）
# 上下文窗口完全清空

# Step 3: 重新进入，从文件恢复
claude --dangerously-skip-permissions
/gsd-resume-work
```

### 5.6 上下文预算分配参考

| 阶段 | 建议预算 | 满载风险 |
|------|---------|---------|
| discuss-phase | ~15K | 低 |
| plan-phase | ~25K（含研究） | 中 |
| review（单模型） | ~10K | 低 |
| review（--all） | ~30K | **高** |
| execute-phase | ~40K（按 Wave 拆分） | 中 |
| verify-work | ~10K | 低 |
| converge 循环 | ~50K（每轮叠加） | **很高** |

---

## 六、失败恢复与升级机制

> GSD 内置了调试和回滚能力，但**高风险/不确定场景的升级需要编排层自己实现**。

### 6.1 科学调试：`/gsd-debug`

```bash
# 开始调试会话（科学方法：假设→测试→验证）
/gsd-debug "form submission fails silently"

# 一次性诊断（不开会话）
/gsd-debug --diagnose "Intermittent error"

# 列出活跃调试会话
/gsd-debug list

# 继续之前的调试会话
/gsd-debug continue session-slug
```

输出：`.planning/debug/{slug}.md`

### 6.2 工作流失败调查：`/gsd-forensics`

```bash
# 只读调查，不修改项目文件
/gsd-forensics "execute-phase failed at wave 2"
```

收集证据：Git 历史、规划状态、阶段制品、会话报告 → 生成诊断报告。

### 6.3 安全回滚：`/gsd-undo`

```bash
# 回滚最近 N 次提交（使用 git revert --no-commit，从不用 git reset）
/gsd-undo --last 3

# 回滚整个阶段
/gsd-undo --phase 5

# 回滚特定计划
/gsd-undo --plan 5-02
```

安全机制：依赖检查 + 确认门控，保留完整历史。

### 6.4 故障排查速查表

| 问题 | 排查命令 | 说明 |
|------|---------|------|
| 命令不显示 | `npx get-shit-done-cc@latest` | 重新安装 GSD 技能 |
| 上下文满了 | `/gsd-health --context` → `/gsd-pause-work` | 暂停后新 session 恢复 |
| Review 无输出 | `codex --version` | 检查 Codex CLI 是否安装 |
| 外部 CLI 未检测到 | `which codex` | 确认 CLI 在 PATH 中 |
| 计划验证失败 | `/gsd-plan-phase N --gaps` | 重新计划修复差距 |
| 执行卡住 | `/gsd-progress` → `/gsd-forensics` | 诊断后 `/gsd-resume-work` |
| 工作流失败 | `/gsd-forensics` | 只读调查，不改文件 |
| 规划目录损坏 | `/gsd-health --repair` | 自动修复 |
| 需要回滚 | `/gsd-undo --last N` | 安全 git revert |

### 6.5 GSD 内部升级机制（node-repair）

GSD 在执行阶段内部有自动修复能力（`node-repair`），策略包括：
- **RETRY**：重试失败任务
- **DECOMPOSE**：分解复杂任务
- **PRUNE**：修剪失败路径
- **ESCALATE**：升级给用户（修复预算默认 2 次后触发）

**限制：** ESCALATE 仅限执行层内部。更高层的升级（如跨 AI Review 发现架构问题、phase 拆分建议、成本超限等）**需要编排层自己实现**。

### 6.6 高风险/不确定场景的升级策略

以下场景 GSD 没有原生处理，需要编排层或用户介入：

| 场景 | GSD 原生处理 | 需要编排层实现 |
|------|-------------|---------------|
| 执行任务失败（2 次内） | ✅ node-repair RETRY | — |
| 执行任务失败（超过 2 次） | ✅ ESCALATE 给用户 | — |
| 跨 AI Review 发现 HIGH 问题 | ❌ 仅输出 REVIEWS.md | 编排层需判断是否重新计划 |
| 收敛循环停滞 | ✅ 内置停滞检测 | — |
| Phase 过大需拆分 | ❌ 无原生拆分 | 编排层需评估复杂度 + 执行拆分 |
| 成本超限 | ❌ 无原生成本控制 | SDK API 的 `maxBudgetUsd` 可控制 |
| 上下文满载 | ⚠️ 有警告但无自动 session 切换 | 编排层需实现 pause → 新 session → resume |
| 并行 Git 冲突 | ❌ 无原生冲突解决 | 编排层需串行执行或冲突检测 |

---

## 七、高阶自动化：收敛循环与 SDK（可选）

### 7.1 计划-审查收敛循环（默认禁用）

对于关键阶段，使用收敛循环自动优化计划质量：

```bash
/gsd-plan-review-convergence N --codex --max-cycles 3
```

**自动执行链：**
```
plan-phase → codex review → 检查 HIGH 问题数
    ↑_______________________________│
         （如有 HIGH 问题，自动重新计划）
```

**配置说明：**
- `--max-cycles 3`：最多迭代 3 轮
- 内置停滞检测：连续两轮无改善则自动退出
- **默认禁用**，需手动调用或在 config.json 中开启

### 7.2 SDK API（需单独安装）

> **注意：** `@gsd-build/sdk` 是嵌套在 `get-shit-done-cc` 包内的子包，需要单独安装：`npm install @gsd-build/sdk`

```bash
# 自动执行整个里程碑，指定模型和预算
gsd-sdk auto --model claude-opus-4-6 --max-budget 10

# 从 PRD 初始化 + 自动执行
gsd-sdk auto --init @prd.md --model claude-opus-4-6
```

```typescript
// 程序化 API（Node.js/TypeScript）
import { GSD } from '@gsd-build/sdk';

const gsd = new GSD({
  projectDir: '/path/to/project',
  autoMode: true,
  model: 'claude-opus-4-6',
  maxBudgetUsd: 10,
  review: {
    crossAi: ['codex'],
    autoMerge: true,
  }
});

// 执行整个里程碑
const result = await gsd.run('');

// 执行单个阶段
const result = await gsd.run('phase 1');
```

---

## 八、快速参考：常用命令速查表

### 8.1 日常开发（Claude Code）

| 场景 | 命令 |
|------|------|
| 查看当前进度 | `/gsd-progress` |
| 自动推进下一步 | `/gsd-progress --next` |
| 全自动执行所有阶段 | `/gsd-autonomous` |
| 全自动执行指定范围 | `/gsd-autonomous --from 3 --to 5` |
| 恢复上次会话 | `/gsd-resume-work` |
| 暂停工作 | `/gsd-pause-work` |
| 小任务（≤3 文件） | `/gsd-fast "fix typo in README"` |
| 中等任务 | `/gsd-quick "fix mobile Safari button"` |
| 添加新阶段 | `/gsd-phase "Add admin dashboard"` |

### 8.2 质量与 Review

| 场景 | 命令 |
|------|------|
| Claude 代码审查 | `/gsd-code-review N` |
| 审查并自动修复 | `/gsd-code-review N --fix` |
| 快速审查（仅 HIGH） | `/gsd-code-review N --depth quick` |
| Codex 审查计划/代码 | `/gsd-review N --codex` |
| 多模型并行审查 | `/gsd-review N --all` |
| 计划-审查收敛循环 | `/gsd-plan-review-convergence N --codex` |
| 安全审计 | `/gsd-secure-phase N` |
| UI 审计 | `/gsd-ui-review N` |

### 8.3 调试与恢复

| 场景 | 命令 |
|------|------|
| 科学调试 | `/gsd-debug "description"` |
| 一次性诊断 | `/gsd-debug --diagnose` |
| 工作流失败调查 | `/gsd-forensics` |
| 安全回滚 | `/gsd-undo --last N` |
| 上下文健康检查 | `/gsd-health --context` |
| 修复规划目录 | `/gsd-health --repair` |

### 8.4 外部 Review CLI 支持列表

| 参数 | 对应工具 | 安装命令 |
|------|---------|---------|
| `--codex` | OpenAI Codex CLI | `npm i -g @openai/codex` |
| `--gemini` | Google Gemini CLI | `npm i -g @google/gemini-cli` |
| `--claude` | Claude Code CLI | `npm i -g @anthropic-ai/claude-code` |
| `--opencode` | OpenCode CLI | 按官方文档安装 |
| `--qwen` | Qwen CLI | 按官方文档安装 |
| `--cursor` | Cursor CLI | 按官方文档安装 |
| `--ollama` | Ollama（本地） | `curl -fsSL https://ollama.com/install.sh \| sh` |
| `--lm-studio` | LM Studio（本地） | 按官方文档安装 |
| `--llama-cpp` | llama.cpp（本地） | 按官方文档安装 |
| `--all` | 所有检测到的 CLI | — |

---

## 九、最佳实践与注意事项

### 9.1 Review 策略建议

1. **跨 AI Review 是可选增强，不是必须步骤**
   - GSD 核心流程（discuss → plan → execute → verify → ship）已足够完成工作
   - 跨 AI Review 适合关键阶段或架构决策类任务

2. **计划审查（plan 后）**
   - `/gsd-review N --codex` 审查 PLAN.md
   - Codex 的代码生成视角能发现 Claude 计划中的实现盲区

3. **代码审查（execute 后）**
   - `/gsd-code-review N` 做 Claude 内部审查
   - `/gsd-review N --codex` 做 Codex 外部审查（可选）
   - 不同模型捕获不同盲点（Claude 偏架构，Codex 偏实现细节）

4. **关键阶段使用收敛循环**
   - 架构决策类阶段：`/gsd-plan-review-convergence N --codex --max-cycles 3`
   - 自动迭代直到无 HIGH 级别问题

### 9.2 成本控制

```bash
# 切换到预算模式（使用更便宜的模型）
/gsd-config --profile budget

# 切换到质量模式
/gsd-config --profile quality

# SDK 模式设置硬预算上限
gsd-sdk auto --model claude-opus-4-6 --max-budget 5
```

### 9.3 自动化程度分级

| 级别 | 人工参与 | 配置方式 | 适用场景 |
|------|---------|---------|---------|
| **L1 手动** | 每步确认 | `mode: "interactive"` | 探索性项目 |
| **L2 半自动** | 关键节点确认 | `mode: "yolo"` + 手动 review | 日常开发 |
| **L3 自动+Review** | 仅 UAT 确认 | `mode: "yolo"` + `/gsd-review --codex` | 标准迭代 |
| **L4 全自动化** | 零人工 | `/gsd-autonomous` 或 `gsd-sdk auto` | CI/CD、标准任务 |

**推荐：** 日常使用 **L2 半自动**（yolo 模式），关键阶段升级到 **L3**（加跨 AI Review）。完全无人值守用 **L4**（`/gsd-autonomous` 或 SDK）。

---

## 附录：与 GSD 原生能力的对应关系

| 方案中的设计 | GSD 原生替代 | 是否冗余 |
|-------------|-------------|---------|
| Phase 编号自动检测（原 §四） | `/gsd-progress --next` | ✅ 冗余，已删除 |
| hermes-gsd 封装技能（原 §四.4） | `/gsd-progress --next` + `/gsd-autonomous` | ✅ 冗余，已删除 |
| Shell 脚本包装器（原 §五.5） | `/gsd-pause-work` + `/gsd-resume-work` | ✅ 冗余，已简化 |
| 跨 AI Review 调度 | `/gsd-review N --codex` | ✅ 使用原生命令 |
| 收敛循环 | `/gsd-plan-review-convergence` | ✅ 使用原生命令 |
| 高风险升级策略 | GSD 仅有 node-repair ESCALATE | ❌ 需编排层实现 |
| Phase 自动拆分 | GSD 无原生拆分 | ❌ 需编排层实现 |
| 上下文 session 切换 | GSD 有警告但无自动切换 | ❌ 需编排层实现 |

---

*整理日期: 2026-05-14*
*基于: GSD v1.41.2 官方文档（AI_AGENT_GUIDE + HUMAN_GUIDE + ANALYSIS_REPORT + workflows/analysis）*
*v2 同步: 方案A内置code-review说明、/gsd-review审查对象修正、progress文件计数法、上下文阈值对齐(60%/70%)、REVIEWS.md多reviewer遍历、HANDOFF.json检测提示*
