# Hermes Dev Orchestra + GSD 自动化工作流设计

> 场景：一整个 Milestone 的自动化开发
> 前提：需求已定好，有 prd.md
> 架构：基于现有 Hermes Dev Orchestra 编排方式
> 版本：v5.0 | 2026-05-13

---

## 编排方式（基于现有架构）

### 入口

```bash
# 1. 启动 Hermes 主控
hermes chat

# 2. 激活编排技能
/dev-orchestra

# 3. 用自然语言描述任务
在 my-app 项目里实现用户注册 API，要求用 bcrypt 做密码哈希，返回 JWT token
```

### 现有编排流程

```
1. 派发 — Hermes 将任务写入 task.md，watcher 派发给 Codex
2. 执行 — Codex 在 hermes-my-app-codex tmux 会话中开始编码
3. 提问 — Codex 遇到不确定的问题 → 写入 codex-question.md → watcher 转发给 Claude
4. 决策 — Claude 在 hermes-my-app-claude 会话中决策 → 写入 claude-decision.md → watcher 回传给 Codex
5. 完成 — Codex 完成编码 → 写入 codex-result.md → Claude review → review-result.md
```

### 通信协议（File Bus）

```
/tmp/hermes-orchestra/{project}/
├── task.md                # Hermes → Codex/Claude: 任务描述
├── codex-question.md      # Codex → Hermes: 技术问题 / 交互请求
├── claude-decision.md     # Hermes/Claude → Codex: 决策结果
├── codex-result.md        # Codex → Hermes: 执行结果
├── review-result.md       # Claude → Hermes: 审查结果
├── escalation.md          # Claude → Hermes: 升级请求
└── .lock                  # File Bus 文件锁（防竞态）
```

---

## 唯一真相来源原则

> **`.planning/` 目录是唯一的状态真相来源。File Bus 仅做消息传递，不做状态判断。**

| 数据 | 存储位置 | 谁写入 | 谁读取 |
|------|---------|--------|--------|
| 项目状态 | `.planning/STATE.md` | GSD 原生 | Hermes + Claude + Codex |
| 阶段列表 | `.planning/ROADMAP.md` | GSD 原生 | Hermes + Claude + Codex |
| 阶段制品 | `.planning/phases/*/` | GSD 原生 | Hermes + Claude + Codex |
| 消息传递 | `/tmp/hermes-orchestra/{project}/*` | 各方 | 各方 |

**Hermes 读取状态的唯一方式：**

```bash
# 读取当前阶段状态
cat .planning/STATE.md

# 检查阶段完成情况
ls .planning/phases/*/

# 读取路线图
grep -E "^## Phase" .planning/ROADMAP.md
```

**Hermes 不再从 File Bus 文件的存在/缺失判断任务进度。** File Bus 文件仅用于：
1. 传递任务指令（task.md）
2. 传递问题和回答（codex-question.md / claude-decision.md）
3. 传递执行结果通知（codex-result.md）
4. 传递升级请求（escalation.md）

---

## GSD 交互分类与路由

### 交互类型分类

| 类型 | 说明 | 示例命令 | 处理方式 |
|------|------|---------|---------|
| **A. 非交互** | 纯执行，无用户输入 | `/gsd-execute-phase`, `/gsd-fast`, `/gsd-ship` | 直接在 tmux 中执行 |
| **B. 可自动** | 支持 `--auto` 标志跳过交互 | `/gsd-discuss-phase --auto`, `/gsd-plan-phase --auto` | 使用 `--auto` 执行 |
| **C. 必须交互** | 需要用户确认/选择 | `/gsd-verify-work`, `/gsd-capture --list` | 交互路由（见下文） |
| **D. 配置类** | 交互式设置 | `/gsd-config`, `/gsd-config --advanced` | 预设配置，跳过 |

### 交互路由机制

当 GSD 技能在 tmux session 中触发交互式 prompt 时，按以下流程处理：

```
GSD 技能触发交互 prompt
    ↓
┌─────────────────────────────────────────────────────┐
│  执行者是谁？                                        │
│                                                      │
│  ┌─────────────────┐    ┌─────────────────┐          │
│  │  Claude Code     │    │     Codex       │          │
│  │  (有 AskUserQ)   │    │  (无 AskUserQ)  │          │
│  └────────┬────────┘    └────────┬────────┘          │
│           │                      │                    │
│           ▼                      ▼                    │
│  写入 escalation.md     写入 codex-question.md       │
│  （标记 type: uat_       （标记 type: uat_            │
│   confirm / choice /      confirm / choice /         │
│   preference）            preference）                │
│           │                      │                    │
│           └──────────┬───────────┘                    │
│                      ▼                                │
│              Hermes 读取并解析                         │
│                      ▼                                │
│         ┌────────────────────────┐                    │
│         │   交互类型路由          │                    │
│         └────────┬───────────────┘                    │
│                  │                                    │
│    ┌─────────────┼─────────────┐                     │
│    ▼             ▼             ▼                      │
│  UAT 确认     偏好选择      技术决策                   │
│  (verify-     (discuss      (codex                    │
│   work)       gray-area)    question)                 │
│    │             │             │                      │
│    ▼             ▼             ▼                      │
│  转发给用户   --auto 处理   Claude 决策               │
│  等待回复     或转发用户    写入 decision.md           │
│    │                                                │
│    ▼                                                │
│  写入 claude-decision.md                            │
│  回传给执行者                                       │
└─────────────────────────────────────────────────────┘
```

### 各 GSD 命令的交互处理

| 命令 | 交互类型 | 执行者 | 处理方式 |
|------|---------|--------|---------|
| `/gsd-new-project --auto @prd.md` | B | Codex | `--auto` 自动初始化 |
| `/gsd-discuss-phase N --auto` | B | Claude | `--auto` 自动回答灰色地带 |
| `/gsd-plan-phase N --auto` | B | Claude | `--auto` 跳过确认 |
| `/gsd-execute-phase N` | A | Codex | 直接执行 |
| `/gsd-verify-work N` | **C** | Claude | **交互路由（见下方专项）** |
| `/gsd-ship N` | A | Codex | 直接执行 |
| `/gsd-code-review N` | A | Claude | 直接执行 |
| `/gsd-secure-phase N` | A | Claude | 直接执行 |
| `/gsd-fast "task"` | A | Codex | 直接执行 |
| `/gsd-quick "task"` | A | Codex | 直接执行 |
| `/gsd-progress` | A | 任一 | 直接执行 |
| `/gsd-resume-work` | A | 任一 | 直接执行 |
| `/gsd-config` | D | — | 预设配置，不执行 |
| `/gsd-capture --list` | C | 任一 | 跳过（自动化流程不需要） |

---

## verify-work 专项处理

> `/gsd-verify-work` 是核心流水线中唯一必须交互的步骤。它逐条展示预期行为，要求用户确认或描述差异。

### 方案：分层验证

将 verify-work 拆分为**自动化验证 + 人工确认**两步：

```
Step 1: 自动化验证（Claude Code 执行）
    ↓
    /gsd-verify-work N --text
    ↓
    生成 UAT.md 草稿（包含所有测试场景和预期行为）
    ↓
    通过 File Bus 发送给 Hermes
    ↓
Step 2: 人工确认（Hermes 收集用户反馈）
    ↓
    Hermes 将 UAT.md 草稿展示给用户
    ↓
    用户批量确认 or 标记差异
    ↓
    Hermes 将用户反馈写入 claude-decision.md
    ↓
Step 3: 更新 UAT（Claude Code 收到反馈）
    ↓
    Claude Code 根据用户反馈更新 UAT.md
    ↓
    如果有差距 → 触发 /gsd-plan-phase N --gaps 修复
```

### 实现细节

**Step 1：Claude Code 在 tmux 中执行**

```bash
# 在 hermes-{project}-claude tmux session 中
/gsd-verify-work N --text
```

`--text` 模式将 UAT 结果以纯文本输出，而非交互式 prompt。Claude Code 完成后写入：

```json
// escalation.md
{
  "type": "uat_review",
  "phase": "N",
  "uat_file": ".planning/phases/NN-xxx/UAT.md",
  "summary": "5 个测试场景，3 个通过，2 个待确认",
  "pending_items": [
    {"id": 1, "scenario": "用户注册-重复邮箱", "expected": "返回 409", "status": "pending"},
    {"id": 2, "scenario": "用户注册-弱密码", "expected": "返回 400", "status": "pending"}
  ]
}
```

**Step 2：Hermes 收集用户反馈**

```
Hermes: [my-app] UAT 验证完成，5 个场景中 2 个需要您确认：

  1. 用户注册-重复邮箱：预期返回 409 Conflict
     → 实际行为是否符合预期？(y/n/describe)

  2. 用户注册-弱密码：预期返回 400 Bad Request
     → 实际行为是否符合预期？(y/n/describe)

请回复（例如 "1y,2n 密码验证没做"）:
```

**Step 3：Hermes 写入 claude-decision.md**

```json
// claude-decision.md
{
  "type": "uat_feedback",
  "phase": "N",
  "results": [
    {"id": 1, "status": "pass", "feedback": ""},
    {"id": 2, "status": "fail", "feedback": "密码验证逻辑未实现，需要补充"}
  ],
  "next_action": "fix_gaps"
}
```

### verify-work 降级策略

如果 `--text` 模式不可用或行为不符合预期：

```
降级路径：
1. --text 模式 → 首选，纯文本输出
2. --ws 模式   → WebSocket 输出（如果 Hermes 有 ws 监听）
3. 回退方案    → Claude Code 直接读取 VERIFICATION.md，
                 自行生成 UAT.md，跳过逐条确认，
                 标记 status: auto_verified（需人工复核）
```

---

## File Bus 锁机制

### 问题

多个 agent 并行读写 File Bus 文件可能导致：
- 写入覆盖（Codex 写 codex-result.md 时 Hermes 正在读取）
- 状态丢失（新消息覆盖未处理的旧消息）
- 竞态条件（Hermes 和 watcher 同时检测到文件变更）

### 解决方案：flock 文件锁

```bash
#!/bin/bash
# File Bus 写入函数（带锁）
bus_write() {
    local project="$1"
    local file="$2"
    local content="$3"
    local bus_dir="/tmp/hermes-orchestra/${project}"
    local lock_file="${bus_dir}/.lock"

    # 确保目录存在
    mkdir -p "$bus_dir"

    # 获取排他锁（超时 10 秒）
    (
        flock -w 10 200 || { echo "LOCK_TIMEOUT"; exit 1; }

        # 原子写入：先写临时文件，再 rename
        local tmp_file="${bus_dir}/.tmp.${file}.$$"
        echo "$content" > "$tmp_file"
        mv -f "$tmp_file" "${bus_dir}/${file}"

    ) 200>"$lock_file"
}

# File Bus 读取函数（带锁）
bus_read() {
    local project="$1"
    local file="$2"
    local bus_dir="/tmp/hermes-orchestra/${project}"
    local lock_file="${bus_dir}/.lock"

    (
        flock -s -w 10 200 || { echo "LOCK_TIMEOUT"; exit 1; }
        cat "${bus_dir}/${file}" 2>/dev/null
    ) 200>"$lock_file"
}

# File Bus 原子消费（读取 + 删除）
bus_consume() {
    local project="$1"
    local file="$2"
    local bus_dir="/tmp/hermes-orchestra/${project}"
    local lock_file="${bus_dir}/.lock"

    (
        flock -w 10 200 || { echo "LOCK_TIMEOUT"; exit 1; }

        if [[ -f "${bus_dir}/${file}" ]]; then
            cat "${bus_dir}/${file}"
            rm -f "${bus_dir}/${file}"
            return 0
        else
            return 1  # 文件不存在
        fi
    ) 200>"$lock_file"
}
```

### 锁策略

| 操作 | 锁类型 | 超时 | 说明 |
|------|--------|------|------|
| 写入 | 排他锁 (LOCK_EX) | 10s | 原子写入：tmpfile + mv |
| 读取 | 共享锁 (LOCK_SH) | 10s | 允许并发读 |
| 消费 | 排他锁 (LOCK_EX) | 10s | 读取后删除，防止重复处理 |

---

## tmux Session 健康监控

### 心跳机制

Hermes 每 **60 秒**检查一次 tmux session 存活状态：

```bash
#!/bin/bash
# tmux 健康检查
check_tmux_health() {
    local project="$1"
    local claude_session="hermes-${project}-claude"
    local codex_session="hermes-${project}-codex"
    local status="healthy"

    # 检查 Claude session
    if ! tmux has-session -t "$claude_session" 2>/dev/null; then
        echo "[${project}] ALERT: Claude session ${claude_session} is DOWN"
        status="degraded"
    fi

    # 检查 Codex session
    if ! tmux has-session -t "$codex_session" 2>/dev/null; then
        echo "[${project}] ALERT: Codex session ${codex_session} is DOWN"
        status="degraded"
    fi

    # 检查 GSD 状态文件是否可访问
    local planning_dir="/path/to/${project}/.planning"
    if [[ ! -f "${planning_dir}/STATE.md" ]]; then
        echo "[${project}] ALERT: STATE.md not found"
        status="critical"
    fi

    echo "$status"
}
```

### 超时检测

每个任务执行都有超时限制：

| 任务类型 | 超时时间 | 超时后动作 |
|----------|---------|-----------|
| `/gsd-discuss-phase --auto` | 10 分钟 | 重试 1 次 → 切换执行者 |
| `/gsd-plan-phase --auto` | 15 分钟 | 重试 1 次 → 切换执行者 |
| `/gsd-execute-phase` | 30 分钟 | 重试 1 次 → 切换执行者 |
| `/gsd-verify-work --text` | 10 分钟 | 标记 auto_verified → 跳过 |
| `/gsd-ship` | 5 分钟 | 重试 1 次 → 升级给用户 |
| File Bus 等待回复 | 5 分钟 | 重发 → 升级给用户 |

### 崩溃恢复流程

```
检测到 tmux session 崩溃
    ↓
检查 .planning/STATE.md 获取最后已知状态
    ↓
检查 .planning/phases/*/ 下的文件完整性
    ↓
┌─────────────────────────────────────┐
│  文件完整性判断                      │
│                                      │
│  PLAN.md 写了一半？                  │
│  → 删除不完整文件                    │
│  → 重新执行 /gsd-plan-phase          │
│                                      │
│  SUMMARY.md 写了一半？               │
│  → 删除不完整文件                    │
│  → 重新执行 /gsd-execute-phase       │
│                                      │
│  文件完整？                          │
│  → 检查 git 提交状态                 │
│  → 恢复 tmux session                 │
│  → 执行 /gsd-resume-work            │
└─────────────────────────────────────┘
```

---

## GSD 集成方案

### 核心思路

**在现有的 Hermes Dev Orchestra 架构上，让 Codex 和 Claude Code 在各自的 tmux session 中执行 GSD 命令。**

```
┌─────────────────────────────────────────────────────────────────────┐
│                     HERMES (Dev Orchestra Manager)                   │
│                                                                     │
│  入口：hermes chat → /dev-orchestra → 自然语言描述任务               │
│                                                                     │
│  职责：                                                              │
│  • 解析任务，写入 task.md                                            │
│  • 通过 watcher 派发给 Codex/Claude                                  │
│  • 处理交互路由（verify-work UAT 确认、偏好选择）                    │
│  • 处理 Codex 的提问（转发给 Claude 或用户）                         │
│  • 处理升级（L3/L4）                                                 │
│  • 监控 tmux session 健康状态                                        │
│  • 归档审计日志                                                      │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          │ File Bus（带 flock 锁）
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  CLAUDE CODE    │ │     CODEX       │ │   FILE BUS      │
│  (tmux session) │ │  (tmux session) │ │   (Communication)│
│                 │ │                 │ │                 │
│ hermes-{proj}   │ │ hermes-{proj}   │ │ 文件（带锁）：  │
│ -claude         │ │ -codex          │ │ • task.md       │
│                 │ │                 │ │ • codex-question│
│ 执行 GSD：      │ │ 执行 GSD：      │ │ • claude-decision│
│ • /gsd-discuss  │ │ • $gsd-execute  │ │ • codex-result  │
│ • /gsd-plan     │ │ • $gsd-fast     │ │ • review-result │
│ • /gsd-verify   │ │ • $gsd-quick    │ │ • escalation    │
│ • /gsd-review   │ │ • $gsd-ship     │ │ • .lock         │
│ • /gsd-debug    │ │ • $gsd-audit-fix│ │                 │
│                 │ │                 │ │                 │
│ 交互处理：      │ │ 交互处理：      │ │                 │
│ → escalation.md │ │ → codex-        │ │                 │
│   (type: uat/   │ │   question.md   │ │                 │
│    choice)      │ │   (type: uat/   │ │                 │
│                 │ │    choice)      │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### 任务分发策略

| 任务类型 | 执行者 | GSD 命令 | 交互处理 |
|----------|--------|----------|---------|
| 项目初始化 | Codex | `$gsd-new-project --auto @prd.md` | `--auto` |
| 阶段讨论 | Claude Code | `/gsd-discuss-phase N --auto` | `--auto` |
| 计划创建 | Claude Code | `/gsd-plan-phase N --auto` | `--auto` |
| 阶段执行 | Codex | `$gsd-execute-phase N` | 非交互 |
| **UAT 验证** | **Claude Code** | **`/gsd-verify-work N --text`** | **交互路由** |
| 代码审查 | Claude Code | `/gsd-code-review N` | 非交互 |
| 安全审计 | Claude Code | `/gsd-secure-phase N` | 非交互 |
| 发布 | Codex | `$gsd-ship N` | 非交互 |
| 快速任务 | Codex | `$gsd-fast "task"` | 非交互 |
| 中等任务 | Codex | `$gsd-quick "task"` | 非交互 |
| 调试 | Claude Code | `/gsd-debug "issue"` | 非交互 |
| 代码修复 | Codex | `$gsd-audit-fix` | 非交互 |

---

## 完整工作流

### 阶段 0：项目初始化

```bash
# 在 hermes chat 中
/dev-orchestra

# 描述任务
在 my-app 项目里实现用户注册功能，PRD 在 docs/prd.md
```

**Hermes 自动执行：**
1. 解析任务，写入 `task.md`（带锁）
2. watcher 派发给 Codex
3. Codex 在 tmux session 中执行 `$gsd-new-project --auto @docs/prd.md`
4. 完成后写入 `codex-result.md`（带锁）
5. Hermes 读取 `codex-result.md`（消费模式）
6. Hermes 检查 `.planning/STATE.md` 确认初始化成功
7. Claude review → `review-result.md`

### 阶段 1：规划循环（Claude Code 主导）

**Hermes 派发任务给 Claude Code：**

```json
// task.md
{
  "task": "规划阶段 1：用户注册 API",
  "commands": [
    "/gsd-discuss-phase 1 --auto",
    "/gsd-plan-phase 1 --auto"
  ]
}
```

**Claude Code 在 tmux session 中执行：**
```bash
# 在 hermes-my-app-claude tmux session 中
/gsd-discuss-phase 1 --auto
/gsd-plan-phase 1 --auto
```

**完成后：**
- GSD 自动创建 `.planning/phases/01-user-registration/CONTEXT.md`
- GSD 自动创建 `.planning/phases/01-user-registration/01-01-PLAN.md`
- Hermes 通过检查 `.planning/` 文件确认完成
- Claude 写入 `codex-result.md` 或 `review-result.md`

### 阶段 2：执行循环（Codex 主导）

**Hermes 派发任务给 Codex：**

```json
// task.md
{
  "task": "执行阶段 1：用户注册 API",
  "commands": [
    "$gsd-execute-phase 1"
  ]
}
```

**Codex 在 tmux session 中执行：**
```bash
# 在 hermes-my-app-codex tmux session 中
$gsd-execute-phase 1
```

**如果 Codex 有技术问题：**
```json
// codex-question.md
{
  "question": "密码哈希应该用什么算法？bcrypt 还是 argon2？",
  "context": "正在实现用户注册 API"
}
```

**Claude Code 决策：**
```json
// claude-decision.md
{
  "decision": "使用 bcrypt，因为：1) 更成熟稳定 2) 社区支持更好 3) 性能足够",
  "confidence": "high"
}
```

**完成后：**
- GSD 自动创建 `.planning/phases/01-user-registration/01-01-SUMMARY.md`
- Hermes 通过检查 `.planning/` 文件确认完成
- Codex 写入 `codex-result.md`（带锁）

### 阶段 3：验证循环（Claude Code 主导 + 交互路由）

**Hermes 派发任务给 Claude Code：**

```json
// task.md
{
  "task": "验证阶段 1：用户注册 API",
  "commands": [
    "/gsd-verify-work 1 --text",
    "/gsd-secure-phase 1"
  ]
}
```

**Claude Code 在 tmux session 中执行：**
```bash
# 在 hermes-my-app-claude tmux session 中
/gsd-verify-work 1 --text
```

**verify-work 交互路由：**

```
Claude Code 生成 UAT.md 草稿
    ↓
写入 escalation.md (type: uat_review)
    ↓
Hermes 读取，展示给用户：
    ↓
  [my-app] UAT 验证结果：
  ✅ 场景1: 用户注册-正常流程 — 通过
  ❓ 场景2: 用户注册-重复邮箱 — 预期 409，请确认
  ❓ 场景3: 用户注册-弱密码 — 预期 400，请确认
  ✅ 场景4: 用户注册-密码哈希 — 通过
  ✅ 场景5: 用户注册-JWT返回 — 通过

  请确认场景 2 和 3（回复 "2y,3y" 或 "2n 原因,3y"）:
    ↓
用户回复
    ↓
Hermes 写入 claude-decision.md (type: uat_feedback)
    ↓
Claude Code 读取反馈，更新 UAT.md
    ↓
如果有差距 → /gsd-plan-phase 1 --gaps 修复
```

**安全审计（非交互）：**
```bash
/gsd-secure-phase 1
```

**完成后：**
- GSD 自动创建 `.planning/phases/01-user-registration/UAT.md`
- Hermes 通过检查 `.planning/` 文件确认完成

### 阶段 4：发布（Codex 主导）

**Hermes 派发任务给 Codex：**

```json
// task.md
{
  "task": "发布阶段 1：用户注册 API",
  "commands": [
    "$gsd-pr-branch",
    "$gsd-ship 1"
  ]
}
```

**Codex 在 tmux session 中执行：**
```bash
# 在 hermes-my-app-codex tmux session 中
$gsd-pr-branch
$gsd-ship 1
```

### 阶段 5：里程碑完成

**Hermes 派发任务：**

```json
// task.md
{
  "task": "完成里程碑 v1.0",
  "commands": [
    "/gsd-audit-milestone",
    "$gsd-complete-milestone"
  ]
}
```

---

## 状态管理（利用 GSD 原生）

### GSD 状态文件

```
.planning/
├── STATE.md              # 当前状态（active_phase, next_action, progress）
├── ROADMAP.md            # 阶段分解和状态
├── config.json           # 配置
├── phases/
│   └── 01-xxx/
│       ├── CONTEXT.md    # 讨论结果
│       ├── RESEARCH.md   # 研究
│       ├── PLAN.md       # 计划
│       ├── SUMMARY.md    # 执行摘要
│       ├── UAT.md        # 验证
│       └── VERIFICATION.md  # 验证场景
└── ...
```

### Hermes 读取 GSD 状态

```python
def read_gsd_state(project_dir: str) -> dict:
    """读取 GSD 状态 — 唯一真相来源"""
    import re
    from pathlib import Path

    planning_dir = Path(project_dir) / ".planning"

    # 读取 STATE.md
    state_file = planning_dir / "STATE.md"
    if not state_file.exists():
        return {"status": "uninitialized"}

    content = state_file.read_text()

    state = {
        "status": "unknown",
        "active_phase": None,
        "next_action": None,
        "progress": None
    }

    # 提取关键字段
    match = re.search(r'active_phase:\s*(\S+)', content)
    if match:
        state["active_phase"] = match.group(1)

    match = re.search(r'next_action:\s*(\S+)', content)
    if match:
        state["next_action"] = match.group(1)

    return state


def read_gsd_roadmap(project_dir: str) -> list:
    """读取 ROADMAP.md 获取阶段列表"""
    import re
    from pathlib import Path

    roadmap_file = Path(project_dir) / ".planning" / "ROADMAP.md"
    if not roadmap_file.exists():
        return []

    content = roadmap_file.read_text()
    phases = []

    for match in re.finditer(r'## Phase (\d+):\s*(.+)', content):
        phase_num = match.group(1)
        phase_name = match.group(2).strip()

        # 检查状态
        status = "pending"
        if f"**Status:** completed" in content[match.start():match.start()+500]:
            status = "completed"
        elif f"**Status:** in_progress" in content[match.start():match.start()+500]:
            status = "in_progress"

        phases.append({
            "number": phase_num,
            "name": phase_name,
            "status": status
        })

    return phases
```

### 完成检测

```python
def is_phase_complete(project_dir: str, phase_num: str) -> bool:
    """检查阶段是否完成 — 基于 .planning/ 文件"""
    from pathlib import Path
    import glob

    planning_dir = Path(project_dir) / ".planning" / "phases"

    # 查找阶段目录
    phase_dirs = list(planning_dir.glob(f"{phase_num}-*"))
    if not phase_dirs:
        return False

    phase_dir = phase_dirs[0]

    # 检查关键文件
    has_plan = list(phase_dir.glob("*-PLAN.md"))
    has_summary = list(phase_dir.glob("*-SUMMARY.md"))
    has_uat = list(phase_dir.glob("UAT.md"))

    return bool(has_plan and has_summary and has_uat)


def is_milestone_complete(project_dir: str) -> bool:
    """检查里程碑是否完成"""
    phases = read_gsd_roadmap(project_dir)

    for phase in phases:
        if not is_phase_complete(project_dir, phase["number"]):
            return False

    return True
```

### 进度查询（Hermes 用）

```python
def get_progress_report(project_dir: str) -> dict:
    """生成进度报告 — 仅基于 .planning/"""
    phases = read_gsd_roadmap(project_dir)
    state = read_gsd_state(project_dir)

    completed = sum(1 for p in phases if p["status"] == "completed")
    in_progress = sum(1 for p in phases if p["status"] == "in_progress")
    pending = sum(1 for p in phases if p["status"] == "pending")

    return {
        "total_phases": len(phases),
        "completed": completed,
        "in_progress": in_progress,
        "pending": pending,
        "active_phase": state.get("active_phase"),
        "next_action": state.get("next_action"),
        "phases": phases
    }
```

---

## 错误处理（利用现有架构）

### 1. Codex 提问 → Claude 决策

```
Codex 写入 codex-question.md（带锁）
    ↓
Hermes 消费 codex-question.md（读取 + 删除）
    ↓
Hermes 判断问题类型：
  - 技术决策 → 转发给 Claude 的 tmux session
  - 交互请求（UAT 等） → 转发给用户
    ↓
Claude 写入 claude-decision.md（带锁）
    ↓
Hermes 消费 claude-decision.md，回传给 Codex
    ↓
Codex 继续执行
```

### 2. 交互式问题的特殊处理

当 Codex（没有 AskUserQuestion）遇到需要用户输入的场景：

```
Codex 执行 $gsd-discuss-phase 1 --auto
    ↓
GSD 内部触发交互 prompt（灰色地带选择）
    ↓
Codex 无法直接询问用户
    ↓
Codex 写入 codex-question.md：
{
  "type": "interaction_required",
  "skill": "discuss-phase",
  "prompt": "请选择要讨论的灰色地带：...",
  "options": ["A: 认证方式", "B: 数据库选择", "C: 错误处理"]
}
    ↓
Hermes 读取，转发给用户
    ↓
用户选择
    ↓
Hermes 写入 claude-decision.md：
{
  "type": "interaction_response",
  "selected": "A, C"
}
    ↓
Codex 读取回复，继续执行
```

### 3. 升级处理（L3/L4）

```
Claude 写入 escalation.md（带锁）
    ↓
Hermes 消费 escalation.md
    ↓
orch-risk-check 评估风险等级
    ↓
┌─────────────────────────────────────┐
│  风险等级判断                        │
│                                      │
│  L1: 低风险 → 自动批准，继续         │
│  L2: 中风险 → 通知用户，继续         │
│  L3: 高风险 → 阻塞，等待用户批准     │
│  L4: 危险   → 阻塞，必须显式批准     │
│                                      │
│  ⚠️ 静态规则是最低门槛               │
│  Claude 可以升级但不能降级            │
│  超时、回退、Hermes 都不能自动批准    │
└─────────────────────────────────────┘
    ↓
用户执行 orch-approve 或 orch-reject
    ↓
继续或终止
```

### 4. 断点恢复

```bash
# 使用 GSD 原生的恢复功能
# 在 Claude 的 tmux session 中
/gsd-resume-work

# 或者使用 /gsd-progress --next 自动推进
/gsd-progress --next
```

### 5. 失败重试

```python
def handle_failure(project: str, task_id: str, error: str):
    """处理任务失败 — 基于 .planning/ 状态"""
    # 1. 读取当前状态（唯一真相来源）
    state = read_gsd_state(project)

    # 2. 检查重试次数
    retry_count = get_retry_count(project, task_id)

    if retry_count < 3:
        # 重试
        log(f"[{project}] 重试任务 {task_id} ({retry_count + 1}/3)")
        retry_task(project, task_id)
    else:
        # 切换执行者
        if get_executor(project, task_id) == "codex":
            log(f"[{project}] 切换到 Claude Code")
            switch_executor(project, task_id, "claude")
            retry_task(project, task_id)
        else:
            # 升级给用户
            log(f"[{project}] 升级给用户")
            escalate_to_user(project, task_id, error)
```

### 6. tmux Session 崩溃恢复

```python
def recover_from_crash(project: str, crashed_session: str):
    """tmux session 崩溃恢复 — 基于 .planning/ 完整性检查"""
    from pathlib import Path

    state = read_gsd_state(project)
    active_phase = state.get("active_phase")

    if not active_phase:
        log(f"[{project}] 无活跃阶段，无需恢复")
        return

    phase_dir = find_phase_dir(project, active_phase)

    # 检查文件完整性
    for pattern in ["*-PLAN.md", "*-SUMMARY.md", "CONTEXT.md", "UAT.md"]:
        files = list(phase_dir.glob(pattern))
        for f in files:
            content = f.read_text()
            # 检查文件是否以正常结尾（非截断）
            if not content.strip().endswith(("#", "---", "```", ".")):
                log(f"[{project}] 检测到截断文件: {f.name}，删除")
                f.unlink()

    # 重新创建 tmux session
    recreate_tmux_session(project, crashed_session)

    # 执行恢复
    send_to_session(project, crashed_session, "/gsd-resume-work")
```

---

## 使用示例

### 示例 1：完整的里程碑自动化

```bash
# 1. 启动 Hermes
hermes chat

# 2. 激活编排技能
/dev-orchestra

# 3. 描述任务
在 my-app 项目里实现用户注册功能，PRD 在 docs/prd.md，自动执行整个里程碑

# Hermes 自动：
# - 读取 PRD
# - 初始化 GSD 项目
# - 派发任务给 Codex/Claude Code
# - 监控进度（基于 .planning/）
# - 处理交互路由（verify-work UAT 确认）
# - 处理提问和升级
# - 监控 tmux session 健康状态
```

### 示例 2：从断点恢复

```bash
# 1. 启动 Hermes
hermes chat

# 2. 激活编排技能
/dev-orchestra

# 3. 描述任务
继续 my-app 项目，从上次中断的地方恢复

# Hermes 自动：
# - 读取 .planning/STATE.md（唯一真相来源）
# - 检查 tmux session 健康状态
# - 检查 .planning/phases/*/ 文件完整性
# - 恢复或重建 tmux session
# - 派发下一个任务
```

### 示例 3：执行单个阶段

```bash
# 1. 启动 Hermes
hermes chat

# 2. 激活编排技能
/dev-orchestra

# 3. 描述任务
在 my-app 项目里执行阶段 2：添加登录功能

# Hermes 自动：
# - 派发规划任务给 Claude Code（--auto 模式）
# - 派发执行任务给 Codex
# - 派发验证任务给 Claude Code（--text 模式 + 交互路由）
# - 收集用户 UAT 反馈
```

---

## 配置

### .planning/config.json

```json
{
  "mode": "yolo",
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
  "hermes_orchestra": {
    "verify_mode": "text_with_routing",
    "timeout_minutes": {
      "discuss": 10,
      "plan": 15,
      "execute": 30,
      "verify": 10,
      "ship": 5,
      "file_bus_wait": 5
    },
    "retry_max": 3,
    "health_check_interval_sec": 60
  }
}
```

### 风险策略（risk-policy.yaml）

```yaml
risk_levels:
  L1:
    description: "低风险"
    auto_approve: true

  L2:
    description: "中风险"
    auto_approve: true
    notify_user: true

  L3:
    description: "高风险"
    auto_approve: false
    require_approval: true

  L4:
    description: "危险"
    auto_approve: false
    require_explicit_approval: true
```

---

## 优势总结

| 优势 | 说明 |
|------|------|
| **基于现有架构** | 使用 Hermes Dev Orchestra 的 File Bus + tmux session |
| **零额外开发** | 直接用 GSD 原生能力 |
| **状态管理可靠** | GSD 的 `.planning/` 是唯一真相来源 |
| **交互路由完善** | verify-work 等交互命令通过 File Bus 回退到用户 |
| **文件锁防竞态** | flock 机制保证 File Bus 读写原子性 |
| **健康监控** | tmux session 心跳检测 + 崩溃恢复 |
| **错误恢复内置** | `/gsd-resume-work` + 文件完整性检查 |
| **进度追踪内置** | `/gsd-progress` + `.planning/` 状态读取 |
| **并行执行内置** | `/gsd-execute-phase --wave` 已实现 |
| **风险管控内置** | L1-L4 分级处理已实现 |

---

## 已知限制

1. **GSD 版本要求**：需要 v1.50.0+ 支持 `--auto` 和 `--text` 标志
2. **verify-work --text 可用性**：需要验证 GSD 是否支持 `--text` 模式，如不支持需要降级方案
3. **Codex 交互能力**：Codex 没有 AskUserQuestion，所有交互必须通过 File Bus 回退
4. **flock 可移植性**：需要系统支持 `flock` 命令（Linux 标准，macOS 需要安装）
5. **成本**：Claude Code + Codex 双重消耗，长 milestone 成本较高
6. **并行 Git 冲突**：多 executor 并行修改同一文件时仍可能冲突，需要人工介入

---

*工作流设计文档 v5.0 | 基于 Hermes Dev Orchestra 现有架构 | 2026-05-13*
*变更：新增交互路由层、File Bus 锁机制、tmux 健康监控、统一真相来源、verify-work 专项处理*
