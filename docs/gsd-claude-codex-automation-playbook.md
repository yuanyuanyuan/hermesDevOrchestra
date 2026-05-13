# Claude Code + GSD + Codex CLI 自动化开发方案

> 基于 GSD v1.50.0 文档整理
> 适用场景：在 Claude Code 中使用 GSD 技能完成开发任务，并通过 Codex CLI 等外部模型进行自动化 Review

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

# 最小化安装（仅核心技能，冷启动 ~700 tokens）
npx get-shit-done-cc@latest --claude --global --minimal
```

### 1.3 安装 Codex CLI（外部 Review 模型）

```bash
# 安装 OpenAI Codex CLI
npm install -g @openai/codex

# 配置 API Key
codex config set api_key $OPENAI_API_KEY

# 验证可用
codex --version
```

### 1.4 可选：安装其他外部 Review CLI

```bash
# Google Gemini CLI（如需要多模型并行评审）
npm install -g @google/gemini-cli

# 本地模型（Ollama）
curl -fsSL https://ollama.com/install.sh | sh
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
/gsd-map-codebase        # 先分析现有代码
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
  },
  "review": {
    "cross_ai": {
      "enabled": true,
      "default_tools": ["codex"],
      "auto_merge": true
    }
  }
}
```

| 配置项 | 说明 |
|--------|------|
| `mode: "yolo"` | 自动批准，无需每步确认（对比 `interactive`） |
| `model_profile: "quality"` | 使用最高质量模型 |
| `workflow.code_review: true` | 默认启用代码审查 |
| `review.cross_ai.enabled` | 启用跨 AI 自动评审 |
| `review.cross_ai.default_tools` | 默认调用 codex 做 review |

---

## 三、标准开发工作流（含自动化 Review）

### 3.1 完整生命周期流程图

```
/gsd-new-project           → 初始化项目
    │
    ▼
/gsd-discuss-phase 1 --auto  → 收集偏好（自动模式）
    │
    ▼
/gsd-plan-phase 1 --auto     → 创建计划（自动模式）
    │
    ▼
/gsd-review --phase 1 --codex → 【外部模型 Review】Codex 审查计划
    │
    ▼
/gsd-execute-phase 1         → 波浪式并行执行
    │
    ▼
/gsd-verify-work 1           → UAT 验证（如需交互可保留）
    │
    ▼
/gsd-code-review 1           → Claude 代码审查
    │
    ▼
/gsd-review --phase 1 --codex → 【外部模型 Review】Codex 审查代码
    │
    ▼
/gsd-ship 1                  → 创建 PR
```

### 3.2 各阶段详细命令

#### Step 1: 讨论阶段（自动模式）

```bash
/gsd-discuss-phase 1 --auto
```
- 输出：`.planning/phases/01-xxx/01-CONTEXT.md`
- `--auto`：自动回答偏好问题，无需交互

#### Step 2: 计划阶段（自动模式）

```bash
/gsd-plan-phase 1 --auto
```
- 输出：`.planning/phases/01-xxx/01-RESEARCH.md` + `01-01-PLAN.md`
- 自动运行 4 个并行研究 agent
- 自动生成原子任务计划

#### Step 3: 外部 Review — Codex 审查计划（核心自动化点）

```bash
# 仅调用 Codex 审查当前阶段计划
/gsd-review --phase 1 --codex

# 调用所有可用 CLI 并行审查
/gsd-review --phase 1 --all

# 指定多个外部模型
/gsd-review --phase 1 --codex --gemini
```

**机制说明：**
- GSD 检测系统上可用的 AI CLI（codex, gemini, claude 等）
- 为每个 CLI 生成相同的审查提示（基于 PLAN.md + PROJECT.md + REQUIREMENTS.md）
- **并行运行**外部 AI 审查
- 收集各模型的结构化反馈
- 合并到 `.planning/phases/01-xxx/01-REVIEWS.md`

**产出文件：**
```
.planning/phases/01-xxx/
  01-REVIEWS.md       # Codex 的审查意见
```

#### Step 4: 执行阶段

```bash
/gsd-execute-phase 1
```
- 分析计划依赖，分组为 Wave
- 每个执行器获得干净的 200K 上下文窗口
- 按波次并行执行，原子提交

#### Step 5: 验证阶段

```bash
/gsd-verify-work 1
```
- 加载 VERIFICATION.md 测试场景
- 如需完全自动化，后续可通过 `--auto` 或 yolo 模式跳过交互确认

#### Step 6: 代码审查（Claude 内部 Review）

```bash
/gsd-code-review 1
# 或审查并自动修复
/gsd-code-review 1 --fix
```

#### Step 7: 外部 Review — Codex 审查代码（核心自动化点）

```bash
/gsd-review --phase 1 --codex
```
- 此时 Codex 审查的是已执行的代码变更
- 输出合并到 REVIEWS.md

#### Step 8: 发布

```bash
/gsd-ship 1
```
- 创建 PR 分支
- 生成 PR 描述
- 创建 GitHub PR

---

## 四、上下文满载应对策略（核心补充）

> 自动化流程最大的敌人：**上下文满载导致输出质量断崖式下降（Context Rot）**

### 4.1 为什么自动化更容易满载？

| 原因 | 说明 |
|------|------|
| **连续执行** | 自动化流程不自然停顿，对话历史持续累积 |
| **Review 结果膨胀** | Codex/Gemini 的审查意见可能很长，合并到 REVIEWS.md 后进一步占用上下文 |
| **多轮迭代** | 收敛循环（plan-review-convergence）每轮都叠加新的计划+审查 |
| **无人工间隙** | 没有人类用户"休息"来触发会话重置 |

### 4.2 GSD 内置的上下文保护机制

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

### 4.3 预防策略（在满载前截断）

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
# ≤ 3 文件修改：用 fast（极简上下文）
/gsd-fast "fix typo in README"

# 中等任务：用 quick（可控上下文）
/gsd-quick "update login button style"

# 只有大功能才走完整 discuss → plan → execute
```

#### ③ 限制 Review 输出长度

```bash
# 快速 review（仅 HIGH 问题，节省上下文）
/gsd-code-review 1 --depth quick

# 标准 review（平衡）
/gsd-code-review 1 --depth standard

# 深度 review（仅在关键阶段使用）
/gsd-code-review 1 --depth deep
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

### 4.4 检测策略（及时发现压力）

#### ① 状态栏实时监控

GSD 安装后，Claude Code 状态栏会显示：
```
[Claude-4] | Task: phase-1-execute | CTX: ████████░░ 78%
```

- **绿色（< 70%）**：安全
- **黄色（70-85%）**：注意，下一阶段建议暂停
- **红色（> 85%）**：必须立即暂停

#### ② 自动化检查点（嵌入工作流）

```bash
# 在阶段间插入上下文健康检查
/gsd-health --context

# 输出示例：
# Context usage: 72% (145K / 200K)
# Warning threshold: 70%
# Recommendation: pause after this phase
```

#### ③ Codex Review 时的特殊注意

Codex 审查计划/代码时，会产生额外的 REVIEWS.md。建议在配置中限制：

```bash
# 仅审查核心文件，排除已审查过的 SUMMARY.md
/gsd-review --phase 1 --codex --files PLAN.md,REQUIREMENTS.md
```

### 4.5 恢复策略（满载后如何优雅恢复）

#### ① 手动恢复（人在场时）

```bash
# Step 1: 暂停当前会话，状态自动写入 .planning/
/gsd-pause-work

# Step 2: 退出 Claude Code（或开新窗口）
# 上下文窗口完全清空

# Step 3: 重新进入，从文件恢复
claude --dangerously-skip-permissions
/gsd-resume-work
```

**恢复后，新 agent 只读这些文件，不继承对话历史：**
```
.planning/STATE.md         → 当前位置和决策
.planning/ROADMAP.md       → 阶段状态
.planning/phases/01-*/     → 当前阶段上下文
```

#### ② 自动化恢复（无人值守时）

**方案 A：SDK 自动暂停+恢复**
```typescript
import { GSD } from '@gsd-build/sdk';

const gsd = new GSD({
  projectDir: '/path/to/project',
  autoMode: true,
  contextThreshold: 0.70,        // 70% 触发暂停
  contextCritical: 0.85,         // 85% 强制中断
  onContextWarning: async (usage) => {
    await gsd.pause();           // 写入 STATE.md
    await gsd.saveCheckpoint();  // 保存检查点
    // 外部调度器：新开 Claude Code 进程
    // 调用 gsd.resume() 继续
  }
});
```

**方案 B：Shell 脚本包装器**
```bash
#!/bin/bash
# gsd-auto-with-context-guard.sh

MAX_CTX_PERCENT=70

while true; do
  # 启动 Claude Code 执行一个阶段
  claude -p "/gsd-progress --next" --dangerously-skip-permissions

  # 检查上下文使用率
  CTX_USAGE=$(claude -p "/gsd-health --context --json" | jq '.usage_percent')

  if (( $(echo "$CTX_USAGE > $MAX_CTX_PERCENT" | bc -l) )); then
    echo "Context at ${CTX_USAGE}%. Pausing and restarting..."
    claude -p "/gsd-pause-work"
    sleep 2
    # 新进程 = 干净上下文
    continue
  fi

  # 检查是否完成
  if claude -p "/gsd-progress" | grep -q "All phases completed"; then
    break
  fi
done
```

#### ③ 线程管理（跨会话追踪）

```bash
# 创建命名线程，跨会话保持一致上下文锚点
/gsd-thread "auth-refactor"

# 后续恢复时指定线程
/gsd-resume-work --thread auth-refactor
```

### 4.6 自动化流程中的上下文预算分配

建议为每个阶段设定 Token 预算：

| 阶段 | 建议预算 | 满载风险 |
|------|---------|---------|
| discuss-phase | ~15K | 低 |
| plan-phase | ~25K（含研究） | 中 |
| review（单模型） | ~10K | 低 |
| review（--all） | ~30K | **高** |
| execute-phase | ~40K（按 Wave 拆分） | 中 |
| verify-work | ~10K | 低 |
| converge 循环 | ~50K（每轮叠加） | **很高** |

**安全规则：**
- 执行 `/gsd-review --all` 前，先 `/gsd-health --context`
- 收敛循环每轮后检查，超过 60% 即退出循环
- 大 review 结果写入文件，agent 只读摘要

---

## 五、高阶自动化：计划-审查收敛循环

### 5.1 自动循环（Plan → Review → 修正）

对于关键阶段，使用收敛循环自动优化计划质量：

```bash
/gsd-plan-review-convergence 1 --codex --max-cycles 3
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
- 默认禁用，需在 config.json 中开启或手动调用

### 4.2 完全无人值守模式（SDK API）

如需 CI/CD 或脚本化调用：

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

// 执行单个阶段（自动包含 plan → review → execute → verify）
const result = await gsd.run('phase 1');
```

---

## 六、快速参考：常用命令速查表

### 5.1 日常开发（Claude Code）

| 场景 | 命令 |
|------|------|
| 查看当前进度 | `/gsd-progress` |
| 自动推进下一步 | `/gsd-progress --next` |
| 恢复上次会话 | `/gsd-resume-work` |
| 小任务（≤3 文件） | `/gsd-fast "fix typo in README"` |
| 中等任务 | `/gsd-quick "fix mobile Safari button"` |
| 添加新阶段 | `/gsd-phase "Add admin dashboard"` |
| 暂停工作 | `/gsd-pause-work` |

### 5.2 质量与 Review

| 场景 | 命令 |
|------|------|
| Claude 代码审查 | `/gsd-code-review 1` |
| 审查并自动修复 | `/gsd-code-review 1 --fix` |
| **Codex 审查计划/代码** | **`/gsd-review --phase 1 --codex`** |
| 多模型并行审查 | `/gsd-review --phase 1 --all` |
| 计划-审查收敛循环 | `/gsd-plan-review-convergence 1 --codex` |
| 安全审计 | `/gsd-secure-phase 1` |
| UI 审计 | `/gsd-ui-review 1` |

### 5.3 外部 Review CLI 支持列表

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

## 七、最佳实践与注意事项

### 6.1 Review 策略建议

1. **计划阶段必做 Codex Review**
   - 执行前用 `/gsd-review --phase N --codex` 审查 PLAN.md
   - Codex 的代码生成视角能发现 Claude 计划中的实现盲区

2. **执行后做跨 AI Review**
   - 代码执行后用 `/gsd-review --phase N --all` 做多模型并行审查
   - 不同模型捕获不同盲点（Claude 偏架构，Codex 偏实现细节）

3. **关键阶段使用收敛循环**
   - 架构决策类阶段：`/gsd-plan-review-convergence N --codex --max-cycles 3`
   - 自动迭代直到无 HIGH 级别问题

### 6.2 成本控制

```bash
# 查看当前预算消耗
/gsd-config --profile budget

# SDK 模式设置硬预算上限
gsd-sdk auto --model claude-opus-4-6 --max-budget 5
```

### 6.3 故障排查

| 问题 | 排查命令 |
|------|---------|
| 命令不显示 | `npx get-shit-done-cc@latest` 重新安装 |
| 上下文满了 | `/gsd-health --context` → `/gsd-pause-work` |
| Review 无输出 | 检查 Codex CLI 是否安装：`codex --version` |
| 外部 CLI 未检测到 | 确认 CLI 在 PATH 中：`which codex` |
| 计划验证失败 | `cat .planning/phases/*/VERIFICATION.md` |

---

## 八、自动化程度分级

| 级别 | 人工参与 | 配置方式 | 适用场景 |
|------|---------|---------|---------|
| **L1 手动** | 每步确认 | `mode: "interactive"` | 探索性项目 |
| **L2 半自动** | 关键节点确认 | `mode: "yolo"` + 手动 review | 日常开发 |
| **L3 自动+Review** | 仅 UAT 确认 | `mode: "yolo"` + `/gsd-review --codex` | 标准迭代 |
| **L4 全自动化** | 零人工 | `gsd-sdk auto` + 收敛循环 | CI/CD、标准任务 |

**推荐：** 日常使用 **L3 自动+Review**，在 Claude Code 自动执行开发流程的同时，通过 Codex CLI 进行独立的外部审查，兼顾效率与质量。

---

*整理日期: 2026-05-12*
*基于: GSD v1.50.0 官方文档*
