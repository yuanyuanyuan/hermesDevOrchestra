# GSD Auto Flow — Claude Code 自动化开发工作流

> **用途**: Claude Code 读取本文件后，自动执行完整的 GSD 开发流程（含 Codex 跨 AI Review）
> **GSD 版本**: v1.41.2
> **调用方式**: `@docs/gsd-auto-flow.md 按照 'xxx.md' 要求,完成开发,并且让 codex 帮你 review`

---

## 0. 前置条件检查

```bash
# 检测外部 Review CLI（按优先级）
which codex && echo "codex: OK" || echo "codex: MISSING"
which gemini && echo "gemini: OK" || echo "gemini: MISSING"
which claude && echo "claude: OK" || echo "claude: MISSING"
```

**降级策略**（跨 AI Review 能力）：

| 级别 | 条件 | 命令 |
|------|------|------|
| L1 | Codex 可用 | `/gsd-review N --codex` |
| L2 | Codex 不可用，Gemini 可用 | `/gsd-review N --gemini` |
| L3 | 都不可用 | 仅用 `/gsd-code-review N --fix --auto`（本地审查） |

输出：`跨 AI Review: L1(Codex) / L2(Gemini) / L3(本地仅)`

---

## 1. 解析输入

从用户消息中提取单引号内的文件路径 → `REQ_FILE`。

用 Read 工具读取 `REQ_FILE`，确认存在。不存在则提示用户检查路径。

---

## 2. 检测项目状态

```bash
ls .planning/PROJECT.md .planning/STATE.md .planning/ROADMAP.md 2>/dev/null
```

读取 `.planning/STATE.md` 确定当前阶段。读取 `.planning/ROADMAP.md` 确定阶段列表。

**优先检查**：如果 `.planning/HANDOFF.json` 存在 → 说明之前 `/gsd-pause-work` 过 → 运行 `/gsd-resume-work` 恢复，而不是从头开始。

**状态路由**：

| 检测结果 | 状态 | 跳转 |
|----------|------|------|
| `.planning/HANDOFF.json` 存在 | 已暂停 | → `/gsd-resume-work` |
| `.planning/` 不存在 | 未初始化 | → §3 |
| PROJECT.md 存在，STATE.md = `Ready` | 已初始化 | → §4 |
| 阶段 N 有 CONTEXT.md，无 PLAN.md | 已讨论 | → §6 从 plan 开始 |
| 阶段 N 有 PLAN.md，无 SUMMARY.md | 已计划 | → §6 从 execute 开始 |
| 阶段 N 有 SUMMARY.md，无 REVIEW.md | 已执行 | → §6 从 code-review 开始 |
| 阶段 N 有 REVIEW.md 且 Critical > 0 | 代码待修复 | → §7 处理 REVIEW.md |
| 阶段 N 有 REVIEWS.md 且 HIGH > 0 | 跨 AI 待修复 | → §7 处理 REVIEWS.md |
| 阶段 N 有 UAT.md，`issues: 0` 且 `pending: 0` 且 `blocked: 0` | 已验证 | → §8 |
| 不确定 | — | 运行 `/gsd-progress` |

---

## 3. 项目初始化

```
运行: /gsd-new-project --auto @<REQ_FILE>
```

初始化完成后，**确保 config.json 设置正确**：

```bash
# 读取 .planning/config.json，确认 mode 字段
# 如果 mode != "yolo"，提醒用户：自动流程需要 yolo 模式
# 用户可手动修改 config.json 或运行 /gsd-settings
```

然后读取 ROADMAP.md 确认：
- 阶段总数 `PHASE_COUNT`
- 每个阶段编号和描述
- 是否存在 `depends_on` 依赖关系

---

## 4. 选择执行模式

| 条件 | 模式 | 原因 |
|------|------|------|
| `PHASE_COUNT <= 2` 且无 `depends_on` | 方案 A（全自动） | 简单无依赖项目 |
| `PHASE_COUNT >= 3` 或存在 `depends_on` | 方案 B（单阶段） | 阶段间有依赖或需精细控制 |
| 用户明确指定 | 按用户要求 | 用户优先 |

**约束**：
- 用户要求 codex review 且 `PHASE_COUNT >= 3` → 必须方案 B
- 任何阶段存在 `depends_on` → 必须方案 B（阶段间依赖需要顺序执行+逐阶段 Review）

输出：`模式选择: 方案 [A/B] | 阶段数: N | 原因: ...`

---

## 5. 方案 A — 全自动 + 事后跨 AI Review

> **注意**：方案 A 中 `/gsd-autonomous` 内置了 `/gsd-code-review`（代码审查），但**不包含** `/gsd-review`（跨 AI 计划审查）。如果用户要求"让 codex 帮你 review"，必须在 autonomous 完成后手动补充跨 AI Review。

### 5.1 执行所有阶段

```
运行: /gsd-autonomous
```

### 5.2 对每个已完成阶段执行代码审查

读取 ROADMAP.md，找出所有 `completed` 阶段 → `PHASES[]`。

```
FOR each phase N in PHASES[]:

    Step A1: 代码审查 + 自动修复
    → 先检查 {N}-REVIEW.md 是否已存在且 status=clean（autonomous 内置 review 可能已处理）
    → 已存在且 clean → 跳过，继续 Step A2
    → 不存在或非 clean → 运行: /gsd-code-review N --fix --auto
    产出: {N}-REVIEW.md

    → 检查产出文件是否存在且非空（见 §6.3a REVIEW.md 解析方法）
    → 文件不存在或为空 → ⚠️ 命令可能失败，暂停检查
    → Critical > 0 或 BLOCKER > 0 → §7 处理 REVIEW.md
    → Critical == 0 且 BLOCKER == 0 → 继续

    Step A1b: 跨 AI Review（用户要求 codex review 时必须执行）
    运行: /gsd-review N --codex（或 --gemini，取决于 §0 降级级别）
    产出: {N}-REVIEWS.md
    → 检查产出文件是否存在且非空（见 §6.3b REVIEWS.md 解析方法）
    → HIGH > 0 → §7 处理 REVIEWS.md
    → HIGH == 0 → 继续

    Step A2: 中间检查点（第一个阶段完成后）
    → 如果是第一个阶段且有 Critical/BLOCKER/HIGH 问题 → 暂停后续阶段，先修复
    → 如果是第一个阶段且无问题 → 继续后续阶段
    → 如果不是第一个阶段 → 继续
```

### 5.3 验证与发布

```
FOR each phase N in PHASES[]:
    运行: /gsd-verify-work N
    → 读取 UAT.md Summary（解析方法见 §6.4）
    → issues > 0 或 pending > 0 或 blocked > 0 → 回到 §5.1 重新执行该阶段
    → 全部通过 → 继续

运行: /gsd-ship <最后阶段编号>
```

---

## 6. 方案 B — 单阶段精细模式 + 每阶段 Codex Review

### 6.1 获取阶段列表

读取 ROADMAP.md，提取所有待完成阶段编号 → `PHASES[]`。
如果有 `depends_on`，按依赖顺序排列。

### 6.2 每阶段完整循环

```
FOR each phase N in PHASES[]:

    Step 1: 讨论
    运行: /gsd-discuss-phase N --auto
    产出: {N}-CONTEXT.md

    Step 2: 计划
    运行: /gsd-plan-phase N --auto
    产出: {N}-PLAN.md, {N}-RESEARCH.md

    Step 2b: 计划质量门控（默认对所有阶段执行，除非上下文使用率 > 50%）
    运行: /gsd-review N --codex（或 --gemini，取决于 §0 降级级别）
    产出: {N}-REVIEWS.md
    → 检查产出文件是否存在且非空
    → 解析方法见 §6.3b（REVIEWS.md）
    → HIGH > 0 → 重新计划（最多 2 轮）
    → HIGH == 0 → 继续 Step 3

    Step 3: 执行
    运行: /gsd-execute-phase N
    产出: {N}-SUMMARY.md, {N}-VERIFICATION.md

    Step 4: Claude 代码审查 + 自动修复
    运行: /gsd-code-review N --fix --auto
    产出: {N}-REVIEW.md
    → 检查产出文件是否存在且非空
    → 解析方法见 §6.3a（REVIEW.md）
    → Critical > 0 或 BLOCKER > 0 → §7 处理 REVIEW.md
    → 无 Critical/BLOCKER → 继续 Step 5

    Step 5: 跨 AI Review（代码审查后）
    运行: /gsd-review N --codex（或 --gemini，取决于 §0 降级级别）
    产出: {N}-REVIEWS.md
    → 检查产出文件是否存在且非空
    → 解析方法见 §6.3b（REVIEWS.md）
    （注 1：/gsd-review 的主要审查对象是 PLAN.md + PROJECT.md + REQUIREMENTS.md（计划级），
      但也会读取已执行的代码作为上下文。代码级审查是 /gsd-code-review 的职责，已在 Step 4 完成。）
    （注 2：/gsd-review 会自动检测系统上所有已安装的 AI CLI，
      并为每个 CLI 生成独立的审查结果。如果同时安装了 Codex 和 Claude CLI，
      REVIEWS.md 会包含多个 reviewer 的段落（## Codex Review、## Claude Review 等）。
      解析时需要遍历所有 `## * Review` 段落下的 `### Concerns`，对每个 reviewer 的 HIGH 问题取并集。）

    Step 6: 检查跨 AI Review 结果
    → HIGH > 0 → §7 处理 REVIEWS.md
    → Divergent Views 非空 → §7 升级用户
    → HIGH == 0 → 继续 Step 7

    Step 7: 验证
    运行: /gsd-verify-work N
    （注：verify-work 不支持 --auto 标志。yolo 模式下大部分交互会被自动跳过，
     但某些 UAT 测试步骤可能仍需用户确认。如果流程卡住，等待用户输入。）
    产出: {N}-UAT.md
    → 读取 UAT.md Summary（解析方法见 §6.4）
    → issues > 0 或 pending > 0 或 blocked > 0 → 回到 Step 3 重新执行（最多 2 轮）
    → 全部通过 → 继续 Step 8

    Step 8: 上下文健康检查
    → 如果是最后一个阶段 → 跳到 §8 发布
    → 如果还有后续阶段 → 检查上下文使用率
      运行: /gsd-health --context
      → >= 70% (critical) → 运行 /gsd-pause-work → 提示用户新开 session → /gsd-resume-work
      → 60-70% (warning) → 输出警告，建议尽快 pause，但继续当前阶段
      → < 60% (healthy) → 继续下一个阶段

    注：主控 Claude Code 的上下文会随日志输出和文件读取持续增长。
    GSD 的 subagent 层有独立的 200K 上下文隔离，但主控 session 没有。
    如果上下文满载，主控会丢失状态，导致后续阶段行为不可预测。
```

### 6.3a REVIEW.md 解析方法（来自 `/gsd-code-review`）

REVIEW.md 是 `/gsd-code-review N` 的产出，使用 **Critical/Warning/Info** 分级体系。

**YAML frontmatter**（关键字段）：
```yaml
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found  # 或 pass
```

**正文结构**：
```markdown
## Critical Issues
### CR-01: {标题}
**File:** `{文件}:{行号}`
**Issue:** {描述}
**Fix:** {修复建议}

## Warnings
### WR-01: {标题}
**File:** `{文件}:{行号}`
**Issue:** {描述}
**Fix:** {修复建议}
```

**检测方法**：
```
方法 1 (推荐): 读取 YAML frontmatter 中 findings.critical 的值
方法 2 (备选): 计数 "## Critical Issues" 段落下 "### CR-" 开头的行数
```

- `critical == 0` → 通过，继续
- `critical > 0` → 需要处理，→ §7

**文件存在性检查**：如果 REVIEW.md 不存在或为空 → `/gsd-code-review` 可能失败 → 暂停检查。

### 6.3b REVIEWS.md 解析方法（来自 `/gsd-review`）

REVIEWS.md 是 `/gsd-review N --codex` 的产出，使用 **HIGH/MEDIUM/LOW** 分级体系。

**正文结构**（每个 reviewer 一个段落）：
```markdown
## Codex Review

### Concerns
- **[HIGH] {标题}**: {描述}
- **[MEDIUM] {标题}**: {描述}
- **[LOW] {标题}**: {描述}

## Claude Review

### Concerns
- **[HIGH] {标题}**: {描述}

## Consensus Summary
### Divergent Views
- {分歧描述}
```

**检测方法**：
```
HIGH_COUNT = 所有 Concerns 段落中 "- **[HIGH]" 开头的行数之和
（注意：可能有多个 reviewer 的 Concerns 段落，需要遍历所有）
```

- `HIGH_COUNT == 0` → 通过，继续
- `HIGH_COUNT > 0` → 需要处理，→ §7

**分歧检测**：如果 REVIEWS.md 中 `### Divergent Views` 段落非空 → 不同 reviewer 结论矛盾 → 升级用户。

**文件存在性检查**：如果 REVIEWS.md 不存在或为空 → `/gsd-review` 可能失败（CLI 未安装、认证失败等）→ 降级到 L3 或暂停检查。

### 6.4 UAT.md 解析方法

UAT.md Summary 段落格式：

```
## Summary
total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0
```

**通过条件**：`issues == 0` 且 `pending == 0` 且 `blocked == 0`。

**失败条件**：任何一个计数 > 0。读取具体的 `result: fail` 测试项，确定需要修复的内容。

### 6.5 所有阶段完成后

```
运行: /gsd-ship <最后阶段编号>
```

---

## 7. 处理 Review 分歧（升级机制）

### 7.1 两种 Review 产物的处理

本工作流产生两种 Review 产物，使用不同的 severity 体系：

| 产物 | 来源 | Severity 体系 | 检查字段 |
|------|------|---------------|----------|
| `{N}-REVIEW.md` | `/gsd-code-review N` | Critical/Warning/Info | `findings.critical` 或 `### CR-` |
| `{N}-REVIEWS.md` | `/gsd-review N --codex` | HIGH/MEDIUM/LOW | `**[HIGH]` |

### 7.2 判断分歧类型

**REVIEW.md（代码审查）**：

| 情况 | 处理方式 |
|------|----------|
| Critical == 0 且 BLOCKER == 0 | 通过，继续 |
| Critical <= 2，可自动修复 | → §7.3 自动修复 |
| Critical >= 3 或 BLOCKER > 0 | → §7.4 升级用户 |

**REVIEWS.md（跨 AI 审查）**：

| 情况 | 处理方式 |
|------|----------|
| HIGH == 0 | 通过，继续 |
| HIGH <= 2，可自动修复 | → §7.3 自动修复 |
| HIGH >= 3，或涉及架构变更 | → §7.4 升级用户 |
| Divergent Views 非空 | → §7.4 升级用户 |
| 同一问题修复 3 轮仍未解决 | → §7.4 升级用户 |

### 7.3 自动修复循环（最多 3 轮）

```
FOR attempt = 1 to 3:

    如果是 REVIEW.md 的问题：
      读取 {N}-REVIEW.md 中 "### CR-" 开头的条目
      对每个 Critical 问题：
        - 代码缺陷 → 运行: /gsd-code-review N --fix

    如果是 REVIEWS.md 的问题：
      读取 {N}-REVIEWS.md 中所有 Concerns 段落下 "- **[HIGH]" 开头的行
      对每个 HIGH 问题判断修复方式：
        - 代码缺陷 → 运行: /gsd-code-review N --fix
        - 计划缺陷 → 运行: /gsd-plan-phase N --auto
          （注：重新计划前，先重新运行 /gsd-discuss-phase N --auto 更新 CONTEXT.md，
           因为代码已变更，CONTEXT.md 可能已过时）
        - 执行缺陷 → 运行: /gsd-execute-phase N

    修复后重新 Review：
      如果是 REVIEW.md 问题 → 运行: /gsd-code-review N --fix --auto
      如果是 REVIEWS.md 问题 → 运行: /gsd-review N --codex（或按 §0 降级级别）

    上下文检查点：
      运行: /gsd-health --context
      → >= 60% → 暂停修复循环，升级用户（§7.4），提示需要新开 session
      → < 60% → 继续

    检查新产出：
      REVIEW.md: critical == 0 → 退出循环
      REVIEWS.md: HIGH == 0 → 退出循环
      数量减少 → 继续下一轮
      数量不变 → 停止 → §7.4
```

### 7.4 升级用户

向用户报告，**等待回复后**执行：

```
⚠️ Review 发现问题需要您决策

阶段: Phase N — {阶段名称}
Review 来源: [代码审查(Claude) / 跨AI(Codex/Gemini/Claude)]
问题数: X 个 [Critical/BLOCKER/HIGH]
已尝试修复: Y 轮

关键问题:
1. {severity} {标题}: {描述}
2. {severity} {标题}: {描述}

请指示:
- "继续" → 跳过这些问题，继续下一步
- "修复" → 告诉我具体怎么修
- "重新计划" → /gsd-discuss-phase N --auto + /gsd-plan-phase N --auto 重新规划
- "停止" → 中止当前阶段
```

**不要自行跳过 Critical/BLOCKER/HIGH 问题。**

---

## 8. 发布

```
运行: /gsd-ship <最后阶段编号>
```

**发布前自检**：
- 所有阶段 UAT.md 的 Summary 中 `issues == 0`、`pending == 0`、`blocked == 0`
- 工作树干净
- 在正确的分支上

---

## 9. 异常恢复

| 异常 | 恢复方式 |
|------|----------|
| 上下文满载 (>=70%) | `/gsd-pause-work` → 新 session → `/gsd-resume-work` |
| 上下文警告 (60-70%) | 输出警告，建议尽快 pause，但不强制 |
| 执行卡住 | `/gsd-forensics` → 诊断 → `/gsd-resume-work` |
| 规划目录损坏 | `/gsd-health --repair` |
| 需要回滚 | `/gsd-undo --last N` 或 `/gsd-undo --phase N` |
| 跨 AI CLI 不可用 | 降级：Codex→Gemini→仅本地审查（见 §0） |
| Review 产出文件缺失 | 暂停，检查命令是否成功，不要默认通过 |
| 阶段过大 | `/gsd-phase --insert N "子阶段描述"` → 重新开始 |
| config.json mode 不是 yolo | 提醒用户修改或运行 `/gsd-settings` |

---

## 10. 执行日志

每完成一个关键步骤，输出一行：

```
[Step X] {操作} | 产出: {文件} | 状态: ✅/❌/⚠️
```

示例（方案 B，Phase 1）：
```
[Step 0] 跨 AI Review 能力: L1(Codex) | ✅
[1-1] /gsd-discuss-phase 1 --auto | 产出: 01-CONTEXT.md | ✅
[1-2] /gsd-plan-phase 1 --auto | 产出: 01-PLAN.md | ✅
[1-3] /gsd-execute-phase 1 | 产出: 01-SUMMARY.md | ✅
[1-4] /gsd-code-review 1 --fix --auto | 产出: 01-REVIEW.md | critical: 0 | ✅
[1-5] /gsd-review 1 --codex | 产出: 01-REVIEWS.md | HIGH: 1 | ⚠️
[1-5b] 自动修复 HIGH 问题 (轮次 1/3) | ✅
[1-5c] /gsd-review 1 --codex | HIGH: 0 | ✅
[1-7] /gsd-verify-work 1 | 产出: 01-UAT.md | issues: 0 | ✅
[1-8] 上下文检查 | 使用率: 42% | healthy | ✅
```

---

## 附录：完整流程图

```
@docs/gsd-auto-flow.md 按照 'prd.md' 要求,完成开发,并且让 codex 帮你 review
    │
    ▼
前置检查: codex/gemini 可用性 → 确定降级级别(L1/L2/L3)
    │
    ▼
读取 prd.md → 检查 .planning/ 状态
    │
    ├─ 无 .planning/ → /gsd-new-project --auto @prd.md → 确认 config.json mode=yolo
    │
    ▼
读取 ROADMAP.md → PHASE_COUNT + depends_on → 选择模式
    │
    ├─ 方案 A (<=2, 无依赖)              ├─ 方案 B (>=3 或有依赖)
    │   │                               │   │
    │   ▼                               │   ▼
    │   /gsd-autonomous                 │   FOR each phase N (按依赖顺序):
    │   (discuss→plan→execute)          │     /gsd-discuss-phase N --auto
    │   │                               │     /gsd-plan-phase N --auto
    │   ▼                               │     [/gsd-review N --codex] (计划门控)
    │   FOR each phase:                 │     /gsd-execute-phase N
    │     /gsd-code-review N --fix      │     /gsd-code-review N --fix --auto
    │     /gsd-review N --codex (跨AI)  │       → 解析 REVIEW.md (Critical/Warning)
    │     解析 REVIEW.md + REVIEWS.md:  │     /gsd-review N --codex (跨AI计划审查)
    │     ├─ Critical/HIGH>0 → §7       │       → 解析 REVIEWS.md (HIGH/MEDIUM/LOW)
    │     └─ 全部通过 → 继续            │     │
    │     第一阶段后中间检查点           │     │
    │                                   │     ├─ HIGH>0 或 Critical>0 → §7 修复循环(3轮)
    │                                   │     │   └─ 仍失败 → 升级用户
    │                                   │     ├─ Divergent Views → 升级用户
    │                                   │     └─ 全部通过 → 继续
    │                                   │     /gsd-verify-work N
    │                                   │     ├─ issues>0/blocked>0 → 重新执行(2轮)
    │                                   │     └─ 全部通过 → 上下文检查
    │                                   │       ├─ >=70% → pause→新session→resume
    │                                   │       ├─ 60-70% → 警告，继续
    │                                   │       └─ <60% → 下一阶段
    ▼                                   ▼
所有阶段完成
    │
    ▼
/gsd-ship <N> → 创建 PR
```

---

*基于 GSD v1.41.2 | 2026-05-14*
*v2 修复: 方案A增加跨AI Review、HANDOFF.json检测、verify-work交互性说明、修复循环上下文检查点、reviewer遍历说明、autonomous内置review去重、CLI检测补全*
