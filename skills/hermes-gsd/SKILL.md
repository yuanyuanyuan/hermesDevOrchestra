---
name: hermes-gsd
description: Hermes 项目的 GSD 简化封装技能：把 60+ 个 GSD 命令压缩为 6 个用户友好的命令，自动处理上下文满载，自动集成 Codex 跨模型 Review，面向 Hermes 多项目开发场景优化
version: 1.0.0
metadata:
  hermes:
    tags: [gsd, claude-code, codex, simplified, hermes, automation]
    category: development-workflow
    requires_version: ">=0.10.0"
    parent_skills: [dev-orchestra, claude-supervisor, codex-executor]
---

# Hermes GSD 简化开发技能

> **设计目标：** 用户不需要记住 60+ 个 `/gsd-xxx` 命令，只需 **6 个命令** 完成从规划到发布的全流程。
> **自动化：** 上下文满载自动恢复、Codex Review 自动触发、状态自动检测。
> **兼容：** 与现有 `dev-orchestra`、`claude-supervisor`、`codex-executor` 无缝协作。

---

## When to Use

当用户在 Hermes 项目中需要：
- 快速启动一个新功能/阶段开发
- 自动执行当前阶段的编码工作
- 自动获取多模型代码审查（Claude + Codex）
- 智能推进工作流（自动判断下一步）
- 一键发布当前阶段

**不需要使用此技能的场景：**
- 仅需改一个 typo → 直接用 `/gsd-fast` 或 `codex exec`
- 纯探索性调研 → 直接用 `/gsd-spike`
- 手动调试 bug → 直接用 `/gsd-debug`

---

## 用户命令速查（只需记住这 6 个）

| # | 命令 | 一句话说明 | 背后自动执行的 GSD 命令链 |
|---|------|-----------|------------------------|
| 1 | **`/dev start "描述"`** | 开始一个新功能 | `detect` → `new-project`(如需) → **自动定位当前 phase N** → `discuss-phase N` → `plan-phase N` → `codex-review` |
| 2 | **`/dev do`** | 执行当前阶段 | `detect` → **自动定位当前 phase N** → `execute-phase N` → `code-review` → `verify-work` |
| 3 | **`/dev review`** | 多模型审查代码 | **自动定位当前 phase N** → `code-review N` → `codex-review` → 合并 REVIEWS.md |
| 4 | **`/dev next`** | 自动推进下一步 | `progress --next`（智能判断当前 phase 并执行下一步） |
| 5 | **`/dev status`** | 查看项目状态 | `progress` + `health --context` + 风险评估 |
| 6 | **`/dev ship`** | 发布当前阶段 | **自动定位当前 phase N** → `verify-work N` → `ship N` → `audit-milestone` |

**记忆口诀：**
> **Start** → **Do** → **Review** → **Next** → **Status** → **Ship**
> （开始 → 做 → 审 → 继续 → 状态 → 发布）

---

## 完整使用流程示例

### 场景：添加一个新功能

```
用户: /dev start "添加用户认证模块（JWT + OAuth2）"

→ 系统自动执行：
  1. 检测状态：发现未初始化 → 执行 /gsd-new-project --auto
  2. 自动定位 phase：读取 STATE.md → 发现当前活跃 phase 为 26
  3. 讨论阶段：/gsd-discuss-phase 26 --auto
  4. 计划阶段：/gsd-plan-phase 26 --auto
  5. 外部 Review：/gsd-review --phase 26 --codex（Codex 审查计划）
  6. 上下文检查：/gsd-health --context（安全，继续）
  7. 输出结果：PLAN.md 就绪，等待执行

用户: /dev do

→ 系统自动执行：
  1. 检测状态：发现已计划 → 读取 STATE.md 定位当前 phase 为 26
  2. 执行阶段：/gsd-execute-phase 26
  3. 代码审查：/gsd-code-review 26
  4. 外部 Review：/gsd-review --phase 26 --codex（Codex 审查代码）
  5. 验证工作：/gsd-verify-work 26
  6. 上下文检查：若 >70% 自动 pause + 提示 resume
  7. 输出结果：代码已提交，UAT.md 生成

用户: /dev review

→ 系统自动执行：
  1. 读取 STATE.md 定位当前 phase 为 26
  2. 重新运行 /gsd-code-review 26 --depth deep
  3. 并行运行 /gsd-review --phase 26 --all（多模型审查）
  4. 合并结果到 REVIEWS.md

用户: /dev ship

→ 系统自动执行：
  1. 读取 STATE.md 定位当前 phase 为 26
  2. 最终验证：/gsd-verify-work 26
  3. 创建 PR：/gsd-ship 26
  4. 里程碑审计：/gsd-audit-milestone
```

---

## 自动机制（用户无感知）

### 1. 智能状态检测 + Phase 编号自动定位

无需用户手动检查 STATE.md，每次 `/dev` 命令自动执行：

```bash
# Step 1: 读取 STATE.md 获取当前活跃 phase 编号
cat .planning/STATE.md | grep -E "Phase:|stopped_at:|Current Position:" | head -5

# Step 2: 如果 STATE.md 不明确，扫描 phases/ 目录找最新 pending phase
ls -td .planning/phases/*/ 2>/dev/null | head -1 | xargs basename

# Step 3: 如果仍不明确，使用 /gsd-progress 获取当前活跃 phase
/gsd-progress

# 自动路由到正确的下一步，并自动填充 phase 编号
```

**Phase 编号自动检测逻辑（优先级从高到低）：**

```
1. 读取 STATE.md 的 stopped_at / Current Position 字段
   例："stopped_at: Phase 25.1 execution complete" → phase = 25.1
   例："Current Position: Phase 26 (in progress)" → phase = 26

2. 若 STATE.md 为 "Awaiting next milestone"，扫描 phases/ 目录
   例：找到 .planning/phases/26-auth-module/ → phase = 26

3. 若仍不明确，使用 /gsd-progress --json 解析当前活跃 phase
   例：progress 报告 "Current active phase: 26" → phase = 26

4. 若项目未初始化（无 .planning/），phase = null，触发 new-project
```

**自动判断规则：**

| 检测到 | 自动执行 |
|--------|---------|
| 无 `.planning/` | `new-project` |
| 有 CONTEXT.md，无 PLAN.md | `plan-phase N`（N 从 STATE.md 自动获取） |
| 有 PLAN.md，无 SUMMARY.md | `execute-phase N`（N 从 STATE.md 自动获取） |
| 有 SUMMARY.md，无 UAT.md | `verify-work N` + `code-review N` |
| 有 UAT.md，未 ship | `ship N` |
| 不确定 | `progress`（显示状态报告，含当前 phase 编号） |

### 2. 上下文满载自动防护（每次命令后自动执行）

```bash
# 命令完成后自动检查
/gsd-health --context --json

# 若使用率 > 70%：
→ 自动执行 /gsd-pause-work
→ 提示用户："上下文接近满载，已自动保存状态。请退出 Claude Code 后重新进入，再执行 /dev next 继续。"

# 若使用率 > 85%：
→ 强制中断当前操作
→ 自动保存所有状态到 .planning/
→ 提示用户："上下文已满载，强制暂停。新会话执行 /dev resume 恢复。"
```

**与 GSD 三层防护的协作：**
- L1：每个阶段启动独立 agent（GSD 原生）
- L2：状态写入文件不留在对话中（GSD 原生）
- L3：`hermes-gsd` 在命令级别做自动检查和恢复

### 3. Codex Review 自动触发

**自动触发时机（N 自动从 STATE.md / phases/ 目录获取）：**

| 触发点 | 自动执行的 Review |
|--------|------------------|
| `/dev start` 计划完成后 | `/gsd-review --phase N --codex`（审查计划，N 自动定位） |
| `/dev do` 执行完成后 | `/gsd-review --phase N --codex`（审查代码，N 自动定位） |
| `/dev review` 手动触发 | `/gsd-code-review N --depth deep` + `/gsd-review --phase N --all` |
| `/dev ship` 发布前 | `/gsd-secure-phase N`（安全审计，N 自动定位） |

**自动配置：**
```json
{
  "hermes_gsd": {
    "auto_review": true,
    "review_tools": ["codex"],
    "review_depth": "standard",
    "review_on_plan": true,
    "review_on_execute": true
  }
}
```

### 4. 与 Hermes 现有技能的协作

```
用户 → /dev start/do/review/next/status/ship
       ↓
   hermes-gsd（本技能）
       ↓
   自动检测 + 路由 + 上下文防护
       ↓
   ├─ 需要规划/决策 → 调用 claude-supervisor
   ├─ 需要编码执行 → 调用 codex-executor
   ├─ 需要多项目编排 → 调用 dev-orchestra
   └─ 需要升级/危险操作 → 调用 escalation-handler
```

---

## 配置说明

### 用户级配置（`~/.config/hermes/gsd.json`）

```json
{
  "default_mode": "yolo",
  "model_profile": "quality",
  "auto_review": {
    "enabled": true,
    "tools": ["codex"],
    "depth": "standard"
  },
  "context_guard": {
    "warning_threshold": 0.70,
    "critical_threshold": 0.85,
    "auto_pause": true
  },
  "workflow": {
    "research": false,
    "plan_check": true,
    "verifier": true,
    "code_review": true
  },
  "integrations": {
    "claude_code": {
      "permission_mode": "auto"
    },
    "codex": {
      "model": "gpt-5.3-codex",
      "full_auto": true
    }
  }
}
```

### 项目级配置（`.planning/config.json` 自动注入）

当 `/dev start` 初始化项目时，自动写入：

```json
{
  "mode": "yolo",
  "model_profile": "quality",
  "workflow": {
    "research": false,
    "plan_check": true,
    "verifier": true,
    "code_review": true,
    "parallelization": { "enabled": true }
  },
  "review": {
    "cross_ai": {
      "enabled": true,
      "default_tools": ["codex"],
      "auto_merge": true
    }
  },
  "hermes_gsd": {
    "initialized": true,
    "version": "1.0.0"
  }
}
```

---

## 完整 GSD 命令对照表

如果用户需要手动干预或调试，以下是 `/dev` 命令背后的完整映射：

| /dev 命令 | 背后调用的 GSD 命令 | 条件/说明 |
|-----------|-------------------|-----------|
| `/dev start` | `/gsd-new-project --auto` | 未初始化时 |
| | `/gsd-discuss-phase N --auto` | 已初始化，未讨论时 |
| | `/gsd-plan-phase N --auto` | 已讨论，未计划时 |
| | `/gsd-review --phase N --codex` | 计划完成后，自动触发 |
| `/dev do` | `/gsd-execute-phase N` | 已计划，未执行时 |
| | `/gsd-code-review N` | 执行完成后，自动触发 |
| | `/gsd-review --phase N --codex` | code-review 后，自动触发 |
| | `/gsd-verify-work N` | 审查完成后，自动触发 |
| `/dev review` | `/gsd-code-review N --depth deep` | 手动触发 |
| | `/gsd-review --phase N --all` | 手动触发，多模型 |
| `/dev next` | `/gsd-progress --next` | 智能判断下一步并执行 |
| `/dev status` | `/gsd-progress` | 显示进度 |
| | `/gsd-health --context` | 显示上下文健康 |
| | `/gsd-health` | 显示规划目录健康 |
| `/dev ship` | `/gsd-verify-work N` | 发布前最终验证 |
| | `/gsd-ship N` | 创建 PR |
| | `/gsd-audit-milestone` | 里程碑审计 |

---

## 故障排查

### /dev start 无响应

```bash
# 检查 GSD 是否安装
npx get-shit-done-cc@latest --claude --global

# 检查项目状态
/gsd-progress
```

### Codex Review 未触发

```bash
# 检查 Codex CLI
which codex && codex --version

# 手动触发 Review
/gsd-review --phase 1 --codex
```

### 上下文频繁满载

```bash
# 检查当前使用率
/gsd-health --context

# 降低阶段粒度：每个阶段只做一件事
/dev start "拆分为更小的功能"

# 跳过研究环节（省大量上下文）
# 在配置中设置 "workflow.research": false
```

### /dev next 卡住

```bash
# 查看详细状态
/gsd-progress

# 手动指定下一步
/gsd-execute-phase 1    # 或 /gsd-verify-work 1 等
```

---

## 与原始 GSD 的关系

```
原始 GSD（64 个命令）        hermes-gsd（6 个命令）
─────────────────────────────────────────────────
/gsd-new-project              →  /dev start
/gsd-discuss-phase            →  /dev start
/gsd-plan-phase               →  /dev start
/gsd-execute-phase            →  /dev do
/gsd-code-review              →  /dev do / review
/gsd-review --codex           →  /dev do / review
/gsd-verify-work              →  /dev do / ship
/gsd-ship                     →  /dev ship
/gsd-progress --next          →  /dev next
/gsd-health --context         →  /dev status
/gsd-pause-work               →  （自动触发）
/gsd-resume-work              →  /dev next
```

**保留原始命令：** 所有 `/gsd-xxx` 命令仍然可用，`/dev` 只是封装层。高级用户可以随时回退到原生 GSD 命令。

---

*技能版本: 1.0.0 | Hermes 项目专用 | 基于 GSD v1.50.0*
