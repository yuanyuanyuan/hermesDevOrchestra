# Hermes Dev Orchestra + GSD 自动化工作流设计

> 场景：一整个 Milestone 的自动化开发
> 前提：需求已定好，有 prd.md
> 架构：基于现有 Hermes Dev Orchestra 编排方式
> 版本：v6.0 | 2026-05-13

---

## 与 v5 的差异清单

| 编号 | 来源 | 变更 |
|------|------|------|
| D1 | playbook | 新增跨 AI Review 步骤（`/gsd-review --phase N --codex`） |
| D2 | playbook | 新增计划-审查收敛循环（`/gsd-plan-review-convergence`） |
| D3 | playbook | 修正 verify-work：yolo 模式可跳过交互，非 `--text` |
| D4 | playbook | discuss-phase 改由 Claude Code 执行（灰色地带推理更强） |
| D5 | playbook | 新增 review 深度控制（`--depth quick/standard/deep`） |
| D6 | playbook | 新增棕地项目支持（`/gsd-map-codebase` 前置） |
| D7 | 上下文管理 | 新增「上下文健康监控」整章 |
| D8 | 上下文管理 | 新增阶段间上下文检查点 + 自动暂停/恢复 |
| D9 | 上下文管理 | 新增上下文预算分配策略 |
| D10 | phase 拆分 | 新增「Phase 自动拆分」整章 |
| D11 | phase 拆分 | 新增双 agent 咨询 + 共识决策机制 |

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
1. 派发 — Hermes 将任务写入 task.md，watcher 派发给执行者
2. 执行 — 执行者在 tmux 会话中开始工作
3. 提问 — 执行者遇到不确定的问题 → 写入 codex-question.md → watcher 转发
4. 决策 — 决策方回复 → 写入 claude-decision.md → watcher 回传
5. 完成 — 执行者完成 → 写入 codex-result.md → 审查 → review-result.md
```

### 通信协议（File Bus）

```
/tmp/hermes-orchestra/{project}/
├── task.md                # Hermes → 执行者: 任务描述
├── codex-question.md      # Codex → Hermes: 技术问题 / 交互请求
├── claude-decision.md     # Hermes/Claude → Codex: 决策结果
├── codex-result.md        # 执行者 → Hermes: 执行结果
├── review-result.md       # Claude → Hermes: 审查结果
├── escalation.md          # Claude → Hermes: 升级请求
├── context-alert.md       # 执行者 → Hermes: 上下文预警
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

**Hermes 不再从 File Bus 文件的存在/缺失判断任务进度。** File Bus 文件仅用于：
1. 传递任务指令（task.md）
2. 传递问题和回答（codex-question.md / claude-decision.md）
3. 传递执行结果通知（codex-result.md）
4. 传递升级请求（escalation.md）
5. 传递上下文预警（context-alert.md）

---

## 上下文健康监控

> 自动化流程最大的敌人：**上下文满载导致输出质量断崖式下降（Context Rot）**

### 为什么自动化更容易满载？

| 原因 | 说明 |
|------|------|
| **连续执行** | 自动化流程不自然停顿，对话历史持续累积 |
| **Review 结果膨胀** | Codex 审查意见合并到 REVIEWS.md 后进一步占用上下文 |
| **多轮迭代** | 收敛循环每轮都叠加新的计划+审查 |
| **无人工间隙** | 没有人类用户"休息"来触发会话重置 |

### GSD 内置的上下文防护

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

### 上下文预算分配

每个阶段的 Token 预算参考（200K 窗口）：

| 阶段 | 建议预算 | 满载风险 | 备注 |
|------|---------|---------|------|
| discuss-phase | ~15K | 低 | `--auto` 模式更省 |
| plan-phase | ~25K（含研究） | 中 | 4 并行研究 agent 占大头 |
| review（单模型） | ~10K | 低 | Codex 单次审查 |
| review（--all） | ~30K | **高** | 多模型并行审查 |
| execute-phase | ~40K（按 Wave 拆分） | 中 | Wave 机制天然分段 |
| verify-work | ~10K | 低 | yolo 模式更省 |
| converge 循环 | ~50K（每轮叠加） | **很高** | 必须有退出条件 |

**安全规则：**
- 执行 `/gsd-review --all` 前，先检查上下文
- 收敛循环每轮后检查，超过 60% 即退出循环
- 大 review 结果写入文件，agent 只读摘要

### 阶段间上下文检查点

Hermes 在**每个阶段完成后**自动插入上下文健康检查：

```python
def check_context_between_phases(project: str, session: str) -> str:
    """阶段间上下文检查点"""
    # 方式 1: 通过 GSD 原生命令
    # 在 tmux session 中执行
    send_to_session(session, "/gsd-health --context --json")

    # 方式 2: 通过 Hermes 估算（基于阶段预算累加）
    phase_budget = estimate_phase_budget(project)
    total_used = sum(phase_budget.values())

    if total_used > 160000:  # > 80%
        return "CRITICAL"
    elif total_used > 140000:  # > 70%
        return "WARNING"
    else:
        return "HEALTHY"
```

**检查点触发动作：**

```
阶段 N 完成
    ↓
Hermes 检查上下文状态
    ↓
┌─────────────────────────────────────────┐
│  状态判断                                │
│                                          │
│  HEALTHY (< 70%)                         │
│  → 继续执行阶段 N+1                      │
│                                          │
│  WARNING (70-85%)                        │
│  → 暂停当前 tmux session                 │
│  → 写入 .planning/STATE.md（检查点）      │
│  → 新建 tmux session                     │
│  → 在新 session 中 /gsd-resume-work      │
│  → 继续阶段 N+1                          │
│                                          │
│  CRITICAL (> 85%)                        │
│  → 强制暂停                              │
│  → 写入 context-alert.md 通知 Hermes     │
│  → 新建 tmux session                     │
│  → 在新 session 中 /gsd-resume-work      │
│  → 继续阶段 N+1                          │
└─────────────────────────────────────────┘
```

### 自动暂停-恢复流程

```python
def context_aware_phase_dispatch(project: str, phase_num: int):
    """带上下文保护的阶段派发"""
    # 1. 检查当前 session 上下文
    ctx_status = check_context_between_phases(project, current_session)

    if ctx_status in ("WARNING", "CRITICAL"):
        log(f"[{project}] 上下文 {ctx_status}，执行 session 切换")

        # 2. 暂停当前 session
        send_to_session(current_session, "/gsd-pause-work")
        wait_for_file(f".planning/STATE.md", timeout=60)

        # 3. 销毁旧 session，创建新 session
        destroy_tmux_session(current_session)
        create_tmux_session(project, role="claude")  # 或 codex

        # 4. 在新 session 中恢复
        send_to_session(new_session, "/gsd-resume-work")
        wait_for_file(f".planning/STATE.md", timeout=60)

        # 5. 更新 session 引用
        current_session = new_session

    # 6. 派发阶段任务
    dispatch_phase_task(project, phase_num)
```

### 预防策略

**① 小任务不走完整流水线**

```bash
# ≤ 3 文件修改：用 fast（极简上下文）
/gsd-fast "fix typo in README"

# 中等任务：用 quick（可控上下文）
/gsd-quick "update login button style"

# 只有大功能才走完整 discuss → plan → execute
```

**② 限制 Review 输出长度**

```bash
# 快速 review（仅 HIGH 问题，节省上下文）
/gsd-code-review 1 --depth quick

# 标准 review（平衡）
/gsd-code-review 1 --depth standard

# 深度 review（仅在关键阶段使用）
/gsd-code-review 1 --depth deep
```

**③ 精简配置模式**

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

**④ Thread 管理（跨会话锚点）**

```bash
# 创建命名线程，跨会话保持一致上下文锚点
/gsd-thread "auth-refactor"

# 后续恢复时指定线程
/gsd-resume-work --thread auth-refactor
```

---

## GSD 交互分类与路由

### 交互类型分类

| 类型 | 说明 | 示例命令 | 处理方式 |
|------|------|---------|---------|
| **A. 非交互** | 纯执行，无用户输入 | `/gsd-execute-phase`, `/gsd-fast`, `/gsd-ship` | 直接在 tmux 中执行 |
| **B. 可自动** | 支持 `--auto` 标志跳过交互 | `/gsd-discuss-phase --auto`, `/gsd-plan-phase --auto` | 使用 `--auto` 执行 |
| **C. 必须交互** | 需要用户确认/选择 | `/gsd-verify-work`（yolo 模式可跳过） | 交互路由（见下文） |
| **D. 配置类** | 交互式设置 | `/gsd-config`, `/gsd-config --advanced` | 预设配置，跳过 |

### 各 GSD 命令的交互处理

| 命令 | 交互类型 | 执行者 | 处理方式 |
|------|---------|--------|---------|
| `/gsd-new-project --auto @prd.md` | B | Codex | `--auto` 自动初始化 |
| `/gsd-discuss-phase N --auto` | B | **Claude** | `--auto` 自动回答灰色地带 |
| `/gsd-plan-phase N --auto` | B | Claude | `--auto` 跳过确认 |
| `/gsd-execute-phase N` | A | Codex | 直接执行 |
| `/gsd-verify-work N` | **C** | Claude | **yolo 模式跳过 / 交互路由** |
| `/gsd-review --phase N --codex` | A | Codex | Codex 跨 AI 审查 |
| `/gsd-code-review N` | A | Claude | 直接执行 |
| `/gsd-secure-phase N` | A | Claude | 直接执行 |
| `/gsd-ship N` | A | Codex | 直接执行 |
| `/gsd-fast "task"` | A | Codex | 直接执行 |
| `/gsd-quick "task"` | A | Codex | 直接执行 |
| `/gsd-progress` | A | 任一 | 直接执行 |
| `/gsd-resume-work` | A | 任一 | 直接执行 |
| `/gsd-health --context` | A | 任一 | 上下文检查 |
| `/gsd-pause-work` | A | 任一 | 暂停+写入检查点 |
| `/gsd-config` | D | — | 预设配置，不执行 |
| `/gsd-capture --list` | C | 任一 | 跳过（自动化流程不需要） |

### 交互路由机制

当 GSD 技能在 tmux session 中触发交互式 prompt 时：

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

---

## verify-work 专项处理

> `/gsd-verify-work` 是核心流水线中唯一默认交互的步骤。

### 方案：yolo 模式 + 降级路由

**首选：yolo 模式自动通过**

```bash
# config.json 中 mode: "yolo" 时，verify-work 自动通过交互确认
/gsd-verify-work N
```

yolo 模式下 GSD 自动验证测试场景，不等待用户确认，直接生成 UAT.md。

**降级：交互路由**

如果 yolo 模式不可用或项目配置为 `interactive`：

```
Claude Code 生成 UAT.md 草稿
    ↓
写入 escalation.md (type: uat_review)
    ↓
Hermes 读取，展示给用户
    ↓
用户批量确认 or 标记差异
    ↓
Hermes 写入 claude-decision.md (type: uat_feedback)
    ↓
Claude Code 读取反馈，更新 UAT.md
    ↓
如果有差距 → /gsd-plan-phase N --gaps 修复
```

---

## 跨 AI Review（来自 playbook）

> Codex 的代码生成视角能发现 Claude 计划中的实现盲区。不同模型捕获不同盲点。

### 完整 Review 流程

```
/gsd-plan-phase N --auto        → Claude 创建计划
    ↓
/gsd-review --phase N --codex   → Codex 审查计划（发现实现盲区）
    ↓
检查 HIGH 问题数
    ↓
┌──────────────────────────────┐
│  有 HIGH 问题？               │
│  YES → 重新计划（最多 3 轮）  │
│  NO  → 继续执行               │
└──────────────────────────────┘
    ↓
/gsd-execute-phase N            → Codex 执行代码
    ↓
/gsd-code-review N              → Claude 审查代码
    ↓
/gsd-review --phase N --codex   → Codex 审查代码（第二轮）
    ↓
/gsd-verify-work N              → UAT 验证
    ↓
/gsd-ship N                     → 发布
```

### 关键阶段：收敛循环

对于架构决策类阶段，使用自动收敛循环：

```bash
/gsd-plan-review-convergence N --codex --max-cycles 3
```

自动执行链：
```
plan-phase → codex review → 检查 HIGH 问题数
    ↑_______________________________│
         （如有 HIGH 问题，自动重新计划）
```

- `--max-cycles 3`：最多迭代 3 轮
- 内置停滞检测：连续两轮无改善则自动退出
- 每轮后检查上下文，超过 60% 即退出循环

### Review 深度控制

```bash
# 快速 review（仅 HIGH 问题，节省上下文）
/gsd-code-review 1 --depth quick

# 标准 review（平衡）
/gsd-code-review 1 --depth standard

# 深度 review（仅在关键阶段使用）
/gsd-code-review 1 --depth deep
```

---

## Phase 自动拆分

> 太大的 phase 会导致：上下文满载、执行超时、质量下降、难以定位问题。

### 什么时候需要拆分？

```
plan-phase 完成后
    ↓
Hermes 检查 phase 复杂度指标
    ↓
┌─────────────────────────────────────────────────────┐
│  复杂度判断（任一触发即需拆分评估）                    │
│                                                      │
│  1. PLAN.md 中任务数 > 8                             │
│  2. 预估涉及文件数 > 15                              │
│  3. PLAN.md 行数 > 300                               │
│  4. 预估上下文消耗 > 40K tokens                      │
│  5. 执行超时（30 分钟内未完成）                       │
│  6. 存在多个独立的功能模块                            │
└─────────────────────────────────────────────────────┘
         │
         ▼ 任一条件触发
    进入拆分咨询流程
```

### 双 Agent 咨询 + 共识决策

```
Hermes 发现 phase 过大
    ↓
┌─────────────────────────────────────────────────────┐
│  并行咨询 Claude 和 Codex                            │
│                                                      │
│  Hermes → Claude Code (tmux):                        │
│    "Phase N 预估 50K tokens，建议如何拆分？"          │
│    附带: PLAN.md, ROADMAP.md, 上下文预算              │
│                                                      │
│  Hermes → Codex (tmux):                              │
│    "Phase N 预估 50K tokens，建议如何拆分？"          │
│    附带: PLAN.md, ROADMAP.md, 上下文预算              │
│                                                      │
│  等待双方回复（写入各自的 result 文件）               │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  共识判断                                            │
│                                                      │
│  Claude 和 Codex 的拆分建议一致？                     │
│                                                      │
│  ✅ 一致 → 直接执行拆分                              │
│                                                      │
│  ❌ 不一致 → Hermes 综合两方意见                      │
│     → 选择更保守的方案（拆得更细）                    │
│     → 如果差异过大，升级给用户决策                    │
│                                                      │
│  ⚠️ 两方都不建议拆分 → 保持原样                       │
│     → 但加强上下文监控频率                            │
└─────────────────────────────────────────────────────┘
         │
         ▼ 拆分决策达成
┌─────────────────────────────────────────────────────┐
│  执行拆分                                            │
│                                                      │
│  方式 1: 插入子阶段（推荐）                           │
│    /gsd-phase --insert N "Phase N 的子任务 A"        │
│    /gsd-phase --insert N "Phase N 的子任务 B"        │
│    → 原 Phase N 变为 N.1, N.2                        │
│                                                      │
│  方式 2: 拆分为独立阶段                               │
│    /gsd-phase --remove N                             │
│    /gsd-phase "Phase N part A: 用户认证"             │
│    /gsd-phase "Phase N part B: 权限管理"             │
│    → 新阶段追加到 ROADMAP 末尾                       │
│                                                      │
│  方式 3: 拆分为功能模块                               │
│    按垂直切片拆分：                                   │
│    Phase N.1: 用户注册（API + 前端 + 测试）           │
│    Phase N.2: 用户登录（API + 前端 + 测试）           │
│    Phase N.3: 密码重置（API + 前端 + 测试）           │
└─────────────────────────────────────────────────────┘
         │
         ▼
    更新 ROADMAP.md
    从原 Phase N 的 CONTEXT.md 继承决策
    重新开始执行拆分后的阶段
```

### 拆分策略参考

| 策略 | 适用场景 | 示例 |
|------|---------|------|
| **按功能模块** | 多个独立功能 | 注册 → 登录 → 密码重置 |
| **按 CRUD** | 资源管理 | 创建 → 列表 → 更新 → 删除 |
| **按垂直切片** | 全栈功能 | API + 前端 + 测试 为一个切片 |
| **按依赖层次** | 有先后依赖 | 数据模型 → API → 业务逻辑 → 前端 |
| **按风险隔离** | 高风险+低风险 | 核心逻辑单独一个 phase |

### 拆分后的继承

```python
def split_phase_inheritance(project: str, original_phase: int, new_phases: list):
    """拆分后的上下文继承"""
    original_dir = find_phase_dir(project, original_phase)

    for new_phase in new_phases:
        new_dir = create_phase_dir(project, new_phase)

        # 继承 CONTEXT.md（共享决策）
        if (original_dir / "CONTEXT.md").exists():
            shutil.copy(
                original_dir / "CONTEXT.md",
                new_dir / "CONTEXT.md"
            )

        # 继承 RESEARCH.md（共享研究）
        if (original_dir / "RESEARCH.md").exists():
            shutil.copy(
                original_dir / "RESEARCH.md",
                new_dir / "RESEARCH.md"
            )

        # 不继承 PLAN.md（每个子阶段需要自己的计划）
        # 不继承 SUMMARY.md（每个子阶段需要自己的执行结果）
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
│  • 监控上下文使用，必要时触发 session 切换                           │
│  • 评估 phase 复杂度，必要时触发自动拆分                             │
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
│ • /gsd-review   │ │ • $gsd-ship     │ │ • context-alert │
│ • /gsd-health   │ │ • $gsd-audit-fix│ │ • .lock         │
│ • /gsd-pause    │ │                 │ │                 │
│ • /gsd-resume   │ │                 │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### 任务分发策略

| 任务类型 | 执行者 | GSD 命令 | 交互处理 |
|----------|--------|----------|---------|
| 棕地分析 | Claude | `/gsd-map-codebase` | 非交互 |
| 项目初始化 | Codex | `$gsd-new-project --auto @prd.md` | `--auto` |
| **阶段讨论** | **Claude** | **`/gsd-discuss-phase N --auto`** | **`--auto`** |
| 计划创建 | Claude | `/gsd-plan-phase N --auto` | `--auto` |
| **跨 AI Review（计划）** | **Codex** | **`$gsd-review --phase N --codex`** | 非交互 |
| **收敛循环** | **Claude** | **`/gsd-plan-review-convergence N --codex`** | 非交互 |
| 阶段执行 | Codex | `$gsd-execute-phase N` | 非交互 |
| 代码审查 | Claude | `/gsd-code-review N --depth quick` | 非交互 |
| **跨 AI Review（代码）** | **Codex** | **`$gsd-review --phase N --codex`** | 非交互 |
| UAT 验证 | Claude | `/gsd-verify-work N` | yolo / 交互路由 |
| 安全审计 | Claude | `/gsd-secure-phase N` | 非交互 |
| 发布 | Codex | `$gsd-ship N` | 非交互 |
| 快速任务 | Codex | `$gsd-fast "task"` | 非交互 |
| 中等任务 | Codex | `$gsd-quick "task"` | 非交互 |
| 上下文检查 | 任一 | `/gsd-health --context` | 非交互 |
| 暂停恢复 | 任一 | `/gsd-pause-work` / `/gsd-resume-work` | 非交互 |

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

```
1. 判断是否棕地项目？
   → YES: 派发 /gsd-map-codebase 给 Claude（分析现有代码）
   → NO:  跳过

2. 派发 $gsd-new-project --auto @docs/prd.md 给 Codex

3. Codex 完成 → 写入 codex-result.md（带锁）

4. Hermes 读取 codex-result.md（消费模式）

5. Hermes 检查 .planning/STATE.md 确认初始化成功

6. Hermes 检查 .planning/ROADMAP.md 中的 phase 数量和复杂度
   → 如果初始 phase 过大 → 触发自动拆分（见 Phase 自动拆分）
```

### 阶段 N：完整循环（带上下文保护和跨 AI Review）

```
Step 1: 上下文检查点
    ↓
    check_context_between_phases()
    ↓
    HEALTHY/WARNING → session 切换或继续
    ↓
Step 2: 阶段讨论（Claude Code）
    ↓
    /gsd-discuss-phase N --auto
    ↓
    产出: CONTEXT.md
    ↓
Step 3: 计划创建（Claude Code）
    ↓
    /gsd-plan-phase N --auto
    ↓
    产出: PLAN.md, RESEARCH.md
    ↓
Step 4: Phase 复杂度评估 + 自动拆分
    ↓
    检查 PLAN.md 任务数、文件数、行数
    ↓
    超标 → 双 Agent 咨询 → 共识 → 拆分
    ↓
Step 5: 跨 AI Review — Codex 审查计划
    ↓
    /gsd-review --phase N --codex
    ↓
    产出: REVIEWS.md
    ↓
    有 HIGH 问题？→ 收敛循环（最多 3 轮）
    ↓
Step 6: 阶段执行（Codex）
    ↓
    $gsd-execute-phase N
    ↓
    产出: SUMMARY.md, 代码提交
    ↓
Step 7: 代码审查（Claude Code）
    ↓
    /gsd-code-review N --depth quick
    ↓
    产出: REVIEW.md
    ↓
Step 8: 跨 AI Review — Codex 审查代码
    ↓
    /gsd-review --phase N --codex
    ↓
    更新: REVIEWS.md
    ↓
Step 9: UAT 验证（Claude Code）
    ↓
    /gsd-verify-work N（yolo 模式）
    ↓
    产出: UAT.md
    ↓
Step 10: 安全审计（Claude Code）
    ↓
    /gsd-secure-phase N
    ↓
    产出: SECURITY.md
    ↓
Step 11: 发布（Codex）
    ↓
    $gsd-pr-branch
    $gsd-ship N
    ↓
Step 12: 阶段完成 → 回到 Step 1（下一阶段）
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
│       ├── REVIEWS.md    # 跨 AI Review 结果
│       ├── SUMMARY.md    # 执行摘要
│       ├── REVIEW.md     # 代码审查
│       ├── UAT.md        # 验证
│       ├── SECURITY.md   # 安全审计
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
    state_file = planning_dir / "STATE.md"

    if not state_file.exists():
        return {"status": "uninitialized"}

    content = state_file.read_text()
    state = {"status": "unknown", "active_phase": None, "next_action": None}

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

    for match in re.finditer(r'## Phase (\d+[\.\d]*):\s*(.+)', content):
        phase_num = match.group(1)
        phase_name = match.group(2).strip()

        status = "pending"
        snippet = content[match.start():match.start()+500]
        if "**Status:** completed" in snippet:
            status = "completed"
        elif "**Status:** in_progress" in snippet:
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

    planning_dir = Path(project_dir) / ".planning" / "phases"
    phase_dirs = list(planning_dir.glob(f"{phase_num}-*"))
    if not phase_dirs:
        return False

    phase_dir = phase_dirs[0]
    has_plan = list(phase_dir.glob("*-PLAN.md"))
    has_summary = list(phase_dir.glob("*-SUMMARY.md"))
    has_uat = list(phase_dir.glob("UAT.md"))

    return bool(has_plan and has_summary and has_uat)


def is_milestone_complete(project_dir: str) -> bool:
    """检查里程碑是否完成"""
    phases = read_gsd_roadmap(project_dir)
    return all(is_phase_complete(project_dir, p["number"]) for p in phases)
```

### Phase 复杂度评估

```python
def assess_phase_complexity(project_dir: str, phase_num: str) -> dict:
    """评估 phase 复杂度，判断是否需要拆分"""
    from pathlib import Path

    phase_dir = find_phase_dir(project_dir, phase_num)
    plan_file = list(phase_dir.glob("*-PLAN.md"))

    if not plan_file:
        return {"needs_split": False, "reason": "no plan found"}

    content = plan_file[0].read_text()
    lines = content.split("\n")

    # 统计指标
    task_count = len([l for l in lines if l.strip().startswith(("- [", "* [", "1.", "2."))])
    file_mentions = set()
    for line in lines:
        if "`" in line:
            import re
            files = re.findall(r'`([a-zA-Z_/]+\.[a-zA-Z]+)`', line)
            file_mentions.update(files)
    line_count = len(lines)

    # 判断是否需要拆分
    reasons = []
    if task_count > 8:
        reasons.append(f"任务数 {task_count} > 8")
    if len(file_mentions) > 15:
        reasons.append(f"涉及文件 {len(file_mentions)} > 15")
    if line_count > 300:
        reasons.append(f"PLAN 行数 {line_count} > 300")

    return {
        "needs_split": len(reasons) > 0,
        "reasons": reasons,
        "task_count": task_count,
        "file_count": len(file_mentions),
        "line_count": line_count
    }
```

---

## File Bus 锁机制

### 解决方案：flock 文件锁

```bash
#!/bin/bash
# File Bus 写入函数（带锁）
bus_write() {
    local project="$1" file="$2" content="$3"
    local bus_dir="/tmp/hermes-orchestra/${project}"
    local lock_file="${bus_dir}/.lock"

    mkdir -p "$bus_dir"

    (
        flock -w 10 200 || { echo "LOCK_TIMEOUT"; exit 1; }
        local tmp_file="${bus_dir}/.tmp.${file}.$$"
        echo "$content" > "$tmp_file"
        mv -f "$tmp_file" "${bus_dir}/${file}"
    ) 200>"$lock_file"
}

# File Bus 原子消费（读取 + 删除）
bus_consume() {
    local project="$1" file="$2"
    local bus_dir="/tmp/hermes-orchestra/${project}"
    local lock_file="${bus_dir}/.lock"

    (
        flock -w 10 200 || { echo "LOCK_TIMEOUT"; exit 1; }
        if [[ -f "${bus_dir}/${file}" ]]; then
            cat "${bus_dir}/${file}"
            rm -f "${bus_dir}/${file}"
            return 0
        else
            return 1
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
check_tmux_health() {
    local project="$1"
    local claude_session="hermes-${project}-claude"
    local codex_session="hermes-${project}-codex"
    local status="healthy"

    if ! tmux has-session -t "$claude_session" 2>/dev/null; then
        echo "[${project}] ALERT: Claude session DOWN"
        status="degraded"
    fi

    if ! tmux has-session -t "$codex_session" 2>/dev/null; then
        echo "[${project}] ALERT: Codex session DOWN"
        status="degraded"
    fi

    local planning_dir="/path/to/${project}/.planning"
    if [[ ! -f "${planning_dir}/STATE.md" ]]; then
        echo "[${project}] ALERT: STATE.md not found"
        status="critical"
    fi

    echo "$status"
}
```

### 超时检测

| 任务类型 | 超时时间 | 超时后动作 |
|----------|---------|-----------|
| `/gsd-discuss-phase --auto` | 10 分钟 | 重试 1 次 → 切换执行者 |
| `/gsd-plan-phase --auto` | 15 分钟 | 重试 1 次 → 切换执行者 |
| `/gsd-review --codex` | 10 分钟 | 跳过 review → 继续 |
| `/gsd-execute-phase` | 30 分钟 | 重试 1 次 → 拆分 phase |
| `/gsd-verify-work` | 10 分钟 | 标记 auto_verified → 跳过 |
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

## 错误处理

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

### 2. 升级处理（L3/L4）

```
Claude 写入 escalation.md（带锁）
    ↓
Hermes 消费 escalation.md
    ↓
orch-risk-check 评估风险等级
    ↓
L1: 低风险 → 自动批准，继续
L2: 中风险 → 通知用户，继续
L3: 高风险 → 阻塞，等待用户批准
L4: 危险   → 阻塞，必须显式批准
    ↓
⚠️ 静态规则是最低门槛
   Claude 可以升级但不能降级
   超时、回退、Hermes 都不能自动批准
    ↓
用户执行 orch-approve 或 orch-reject
```

### 3. 失败重试 + 执行者切换

```python
def handle_failure(project: str, task_id: str, error: str):
    """处理任务失败 — 基于 .planning/ 状态"""
    state = read_gsd_state(project)
    retry_count = get_retry_count(project, task_id)

    if retry_count < 3:
        log(f"[{project}] 重试任务 {task_id} ({retry_count + 1}/3)")
        retry_task(project, task_id)
    else:
        if get_executor(project, task_id) == "codex":
            log(f"[{project}] Codex 失败 3 次，切换到 Claude Code")
            switch_executor(project, task_id, "claude")
            retry_task(project, task_id)
        else:
            log(f"[{project}] 升级给用户")
            escalate_to_user(project, task_id, error)
```

### 4. 执行超时 → Phase 拆分

```python
def handle_execution_timeout(project: str, phase_num: str):
    """执行超时 → 可能需要拆分 phase"""
    log(f"[{project}] Phase {phase_num} 执行超时")

    # 评估复杂度
    complexity = assess_phase_complexity(project, phase_num)

    if complexity["needs_split"]:
        log(f"[{project}] Phase {phase_num} 复杂度过高，触发自动拆分")
        trigger_phase_split(project, phase_num)
    else:
        # 超时但不复杂 → 重试
        log(f"[{project}] Phase {phase_num} 重试")
        retry_task(project, f"execute-{phase_num}")
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
    "cross_ai_review": true,
    "convergence": false,
    "parallelization": {
      "enabled": true
    }
  },
  "hermes_orchestra": {
    "context_management": {
      "enabled": true,
      "warning_threshold": 0.70,
      "critical_threshold": 0.85,
      "auto_session_switch": true
    },
    "phase_split": {
      "enabled": true,
      "max_tasks_per_phase": 8,
      "max_files_per_phase": 15,
      "max_plan_lines": 300,
      "require_consensus": true
    },
    "review": {
      "cross_ai": true,
      "depth": "quick",
      "convergence_max_cycles": 3
    },
    "verify_mode": "yolo",
    "timeout_minutes": {
      "discuss": 10,
      "plan": 15,
      "review": 10,
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

## 使用示例

### 示例 1：完整的里程碑自动化

```bash
hermes chat
/dev-orchestra

在 my-app 项目里实现用户注册功能，PRD 在 docs/prd.md，自动执行整个里程碑

# Hermes 自动：
# - 读取 PRD
# - 初始化 GSD 项目
# - 检查初始 phase 复杂度 → 必要时拆分
# - 每个阶段执行完整循环（discuss → plan → cross-AI review → execute → code review → cross-AI review → verify → ship）
# - 阶段间检查上下文 → 必要时切换 session
# - 处理交互路由和升级
```

### 示例 2：从断点恢复

```bash
hermes chat
/dev-orchestra

继续 my-app 项目，从上次中断的地方恢复

# Hermes 自动：
# - 读取 .planning/STATE.md
# - 检查 tmux session 健康状态
# - 检查 .planning/phases/*/ 文件完整性
# - 恢复或重建 tmux session
# - /gsd-resume-work → /gsd-progress --next
```

### 示例 3：单阶段执行（带跨 AI Review）

```bash
hermes chat
/dev-orchestra

在 my-app 项目里执行阶段 2：添加登录功能

# Hermes 自动：
# - 上下文检查 → 必要时切换 session
# - Claude: /gsd-discuss-phase 2 --auto
# - Claude: /gsd-plan-phase 2 --auto
# - 复杂度评估 → 必要时拆分
# - Codex: $gsd-review --phase 2 --codex（审查计划）
# - Codex: $gsd-execute-phase 2
# - Claude: /gsd-code-review 2 --depth quick
# - Codex: $gsd-review --phase 2 --codex（审查代码）
# - Claude: /gsd-verify-work 2（yolo 模式）
# - Codex: $gsd-ship 2
```

---

## 自动化程度分级

| 级别 | 人工参与 | 配置方式 | 适用场景 |
|------|---------|---------|---------|
| **L1 手动** | 每步确认 | `mode: "interactive"` | 探索性项目 |
| **L2 半自动** | 关键节点确认 | `mode: "yolo"` + 手动 review | 日常开发 |
| **L3 自动+Review** | 仅 UAT 确认 | `mode: "yolo"` + cross-AI review | 标准迭代 |
| **L4 全自动化** | 零人工 | `gsd-sdk auto` + 收敛循环 | CI/CD、标准任务 |

---

## 已知限制

1. **GSD 版本要求**：需要 v1.50.0+ 支持 `--auto` 标志
2. **yolo 模式 verify-work**：需验证 yolo 模式是否确实跳过 UAT 交互确认
3. **Codex 交互能力**：Codex 没有 AskUserQuestion，所有交互必须通过 File Bus 回退
4. **flock 可移植性**：需要系统支持 `flock` 命令（Linux 标准，macOS 需要安装）
5. **成本**：Claude Code + Codex 双重消耗 + 跨 AI Review，长 milestone 成本较高
6. **并行 Git 冲突**：多 executor 并行修改同一文件时仍可能冲突
7. **Phase 拆分依赖 agent 质量**：拆分建议的质量取决于 Claude/Codex 对项目的理解深度
8. **上下文预算估算**：基于经验值，实际消耗因项目复杂度而异

---

*工作流设计文档 v6.0 | 基于 Hermes Dev Orchestra 现有架构 | 2026-05-13*
*v6 变更：跨 AI Review、收敛循环、上下文健康监控、Phase 自动拆分、yolo 模式修正、review 深度控制*
