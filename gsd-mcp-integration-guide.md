# GSD + MCP 跨 AI 协作集成指南

> 场景：Claude TUI 作为主控，通过 MCP 工具调用 Codex 等外部 AI 进行 review/discuss
> 版本：GSD v1.41.2 | 2026-05-11

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                     Claude TUI (主控)                        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ GSD Skills  │  │ GSD Agents  │  │  MCP Tools          │  │
│  │ (编排层)     │  │ (执行层)     │  │  (外部 AI 调用)      │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┼─────────────────────┘             │
│                          │                                   │
│                    ┌─────▼─────┐                             │
│                    │ .planning/ │                             │
│                    │ (状态中心)  │                             │
│                    └───────────┘                             │
└─────────────────────────────────────────────────────────────┘

数据流：
  GSD discuss/plan → 产出上下文文件 → MCP 调用 Codex review → 结果写入 REVIEWS.md → GSD plan --reviews 反馈
```

---

## 方案对比

| 方案 | 优点 | 缺点 | 推荐场景 |
|------|------|------|----------|
| **A: CLI 调用** (原生 `/gsd-review --codex`) | GSD 原生支持，零配置 | 依赖 codex CLI 安装，子进程模式 | 已安装 codex CLI |
| **B: MCP 调用** (本指南方案) | 利用已有 MCP 配置，结果直接返回上下文，可追问 | 需要手动编排流程 | 已配置 MCP 工具 |
| **C: 混合模式** | 灵活选择最合适的调用方式 | 流程稍复杂 | 多 AI 协作 |

**本指南聚焦方案 B（MCP 调用）和方案 C（混合模式）。**

---

## 核心工作流：MCP 调用模式

### 流程 1：Plan Review（计划审查）

**什么时候用：** `/gsd-plan-phase` 完成后，执行前，让 Codex 审查计划质量。

```
步骤 1: Claude TUI 执行 /gsd-plan-phase N
        → 产出 .planning/phases/{NN}-{slug}/*-PLAN.md

步骤 2: Claude TUI 读取计划文件，构建 review prompt

步骤 3: Claude TUI 通过 MCP 调用 Codex review
        → MCP 工具返回结构化审查意见

步骤 4: Claude TUI 将审查意见写入 REVIEWS.md

步骤 5: Claude TUI 执行 /gsd-plan-phase N --reviews
        → Planner 将审查反馈纳入重新规划
```

**Step 2 的 Prompt 模板：**

```markdown
# Plan Review Request

请审查以下实现计划，从以下维度给出意见：

1. **完整性** — 是否覆盖了所有需求？
2. **可行性** — 技术方案是否合理？
3. **风险** — 是否有遗漏的边界情况或安全隐患？
4. **依赖** — 任务顺序是否正确？
5. **建议** — 具体的改进点

## 项目上下文
{PROJECT.md 前 80 行}

## 阶段目标
{ROADMAP.md 中该阶段部分}

## 需求
{REQUIREMENTS.md 相关 REQ}

## 实现计划
{所有 PLAN.md 内容}

## 用户决策
{CONTEXT.md 内容}
```

### 流程 2：Code Review（代码审查）

**什么时候用：** `/gsd-execute-phase` 完成后，让 Codex 审查实际代码。

```
步骤 1: Claude TUI 执行 /gsd-execute-phase N
        → 产出代码变更 + SUMMARY.md

步骤 2: Claude TUI 收集变更文件列表（git diff 或 SUMMARY.md）

步骤 3: Claude TUI 通过 MCP 调用 Codex review 代码
        → MCP 工具返回 bug/安全/质量问题

步骤 4: Claude TUI 根据审查结果决定：
        a) 自动修复（小问题）→ 直接 Edit/Write
        b) 创建修复计划 → /gsd-quick 或追加 PLAN.md
        c) 记录为已知问题 → 写入 REVIEW.md
```

### 流程 3：Phase Discuss（阶段讨论）

**什么时候用：** `/gsd-discuss-phase` 前后，让 Codex 对实现方向提出独立意见。

```
步骤 1: Claude TUI 读取阶段定义和 CONTEXT.md

步骤 2: Claude TUI 通过 MCP 调用 Codex 讨论
        → "对于这个阶段，你认为最佳实现路径是什么？"
        → MCP 工具返回独立观点

步骤 3: Claude TUI 综合 Claude + Codex 两个视角
        → 更新 CONTEXT.md 或创建补充决策
```

---

## 实操模板

### 模板 1：MCP Plan Review

以下是在 Claude TUI 中实际执行的步骤：

```
# 1. 先执行 GSD 计划阶段
/gsd-plan-phase 1

# 2. 读取产出的计划文件
# (Claude 会自动读取 .planning/phases/01-xxx/ 下的文件)

# 3. 调用 MCP 工具进行审查
#    使用你配置的 MCP 工具，例如：
#    - mcp__serena__* (如果 Serena 配置了 review 能力)
#    - mcp__spec-workflow__* (规格审查)
#    - 或其他你配置的 MCP review 工具

# 4. 将 MCP 返回的审查意见整合
#    写入 .planning/phases/01-xxx/01-REVIEWS.md

# 5. 根据审查反馈重新规划（如果需要）
/gsd-plan-phase 1 --reviews
```

### 模板 2：MCP Code Review

```
# 1. 执行阶段
/gsd-execute-phase 1

# 2. 收集变更
# Claude 读取 SUMMARY.md 或 git diff 获取变更文件列表

# 3. 调用 MCP 工具审查代码
# 将变更文件内容传给 MCP 工具的 review/analyze 接口

# 4. 处理审查结果
# - Critical 问题 → 立即修复
# - Warning 问题 → 创建修复计划
# - Info 问题 → 记录

# 5. 验证修复
/gsd-verify-work 1
```

### 模板 3：MCP Cross-AI Discuss

```
# 1. 让 Claude 先讨论
/gsd-discuss-phase 1
# → 产出 CONTEXT.md (Claude 视角)

# 2. 让 Codex 独立讨论同一阶段
# 读取阶段定义，通过 MCP 让 Codex 给出独立观点

# 3. 综合两个视角
# Claude 对比两个观点的差异和共识
# 更新 CONTEXT.md 或添加补充决策

# 4. 基于综合讨论进行计划
/gsd-plan-phase 1
```

---

## 关键设计原则

### 1. GSD 状态文件是唯一的真相来源

```
无论 Claude 还是 Codex 的意见，最终都沉淀到：
- CONTEXT.md  → 实现决策
- REVIEWS.md  → 审查意见
- PLAN.md     → 执行计划
- SUMMARY.md  → 执行结果
```

### 2. MCP 调用的结果需要结构化

每次 MCP 调用返回后，Claude 应该提取：
- **Strengths** — 好的设计点
- **Concerns** — 问题和风险（HIGH/MEDIUM/LOW）
- **Suggestions** — 具体改进建议

### 3. 审查反馈通过 GSD 标准流程消化

```
MCP review 结果 → REVIEWS.md → /gsd-plan-phase --reviews → 更新 PLAN.md
```

不要跳过 GSD 的计划流程直接改代码。

### 4. Codex 作为"第二视角"而非"决策者"

Codex 的审查意见是参考，Claude（主控）做最终决策。

---

## MCP 工具选择建议

| 任务类型 | 推荐 MCP 工具 | 原因 |
|----------|---------------|------|
| Plan Review | `mcp__spec-workflow__*` | 规格审查专长 |
| Code Review | `mcp__serena__*` 或专用 review MCP | 代码分析能力 |
| Discuss | 任何支持对话的 MCP 工具 | 需要多轮交互 |
| Research | `mcp__context7__*`, `mcp__exa__*` | 文档和搜索 |

> **注意：** 具体可用的 MCP 工具取决于你的配置。检查 `~/.claude/settings.json` 中的 `mcpServers` 部分确认可用工具。

---

## 与 GSD 原生命令的对照

| GSD 原生命令 | CLI 调用方式 | MCP 替代方案 |
|-------------|-------------|-------------|
| `/gsd-review --codex` | `codex exec` 子进程 | MCP 工具调用 + 手动写 REVIEWS.md |
| `/gsd-plan-review-convergence --codex` | 多轮 CLI 调用 | MCP 多轮对话 + 手动收敛 |
| `/gsd-code-review` | gsd-code-reviewer Agent | MCP 代码审查 + 手动写 REVIEW.md |
| `/gsd-discuss-phase` | Claude 交互式 | Claude + MCP 双视角讨论 |

**MCP 方案的核心优势：**
- 结果直接返回 Claude 上下文（无需读取临时文件）
- 可以基于 Codex 的回答追问
- 利用已有 MCP 配置，无需额外安装 CLI
- Claude 可以实时综合多个 AI 的意见

**MCP 方案的注意事项：**
- 审查结果需要手动写入 GSD 标准文件（REVIEWS.md/REVIEW.md）
- 收敛循环需要手动编排（不像 `/gsd-plan-review-convergence` 自动化）
- 需要 Claude 主动构建合适的 prompt 传给 MCP 工具

---

## 完整示例：Phase 1 从零到 PR

```
# === 阶段 1：初始化 ===
/gsd-new-project

# === 阶段 2：讨论 ===
/gsd-discuss-phase 1
# Claude 收集用户偏好 → CONTEXT.md

# [MCP] 让 Codex 独立审视阶段目标
# → Codex 返回独立观点
# → Claude 综合后更新 CONTEXT.md

# === 阶段 3：计划 ===
/gsd-plan-phase 1
# → RESEARCH.md + PLAN.md

# [MCP] 让 Codex 审查计划
# → Codex 返回 Concerns/Suggestions
# → Claude 写入 REVIEWS.md

# 如果有 HIGH concerns:
/gsd-plan-phase 1 --reviews
# → 更新 PLAN.md 纳入反馈

# === 阶段 4：执行 ===
/gsd-execute-phase 1
# → 代码 + SUMMARY.md

# [MCP] 让 Codex 审查代码
# → Codex 返回 bug/安全问题
# → Claude 分类处理

# === 阶段 5：验证 ===
/gsd-verify-work 1
# → UAT.md

# === 阶段 6：发布 ===
/gsd-ship 1
```
