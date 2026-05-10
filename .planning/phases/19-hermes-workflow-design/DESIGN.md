# Hermes 多项目 AI 开发工作流设计

> 版本: 1.0.0
> 日期: 2026-05-09
> 状态: Draft

---

## 1. 设计目标

使用 Hermes Agent 作为顶层编排器，通过原生 Kanban 系统管理 10+ 项目的并行 AI 辅助开发。角色由 Profile 定义（SOUL.md + Skills + Toolsets），与具体 CLI/模型解耦。支持自我进化机制，经验自动沉淀为可复用知识。

**核心原则：**
- 以 Hermes 官方能力为主，不重复造轮子
- 角色是抽象的，实现是可替换的
- Kanban 管理任务生命周期和 Agent 间通信
- 自我进化走 Hermes 原生的 memory + skill_manage + curator 机制

**官方背书：** Hermes RFC #16102 明确将 "approval gates" 列为 v1 不实现的功能，并指明应通过 **plugins 或 profile conventions** 在 user-space 构建。本设计的 L1/L2/L3 风险分级、Risk Policy Engine、Sentinel 拦截均属于此范畴，是官方鼓励的扩展方向。

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│  Jacky (用户)                                                │
│  · 提需求 · 回答澄清 · 审核改进提案 · Pin/Unpin skills       │
└──────────────────────────┬──────────────────────────────────┘
                           │ clarify / gateway (Telegram/Discord/CLI)
┌──────────────────────────▼──────────────────────────────────┐
│  Hermes Agent (Master)                                       │
│  · Kanban: 任务生命周期管理                                   │
│  · Dispatcher: 自动按 Profile 派发 worker                    │
│  · Curator: Skill 生命周期维护                                │
│  · Memory: 跨会话持久记忆                                    │
│  · Plugin Hooks: 风险拦截 + 可观测性                          │
└───────┬──────────────┬──────────────┬───────────────────────┘
        │              │              │
   ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
   │   PM    │   │  Orch   │   │Researcher│
   │ 需求分析 │   │ 中枢路由 │   │ 技术调研  │
   └────┬────┘   └────┬────┘   └─────────┘
        │              │
   ┌────▼──────────────▼───────────────────┐
   │         状态机路由表                     │
   │  pm_analyzed → researcher/implementer  │
   │  research_done → implementer           │
   │  poc_success → implementer             │
   │  impl_done → reviewer                  │
   │  review_pass → qa-tester               │
   │  qa_pass → devops                      │
   └────┬──────────────┬───────────────────┘
        │              │
   ┌────▼────┐   ┌────▼────┐   ┌─────────┐
   │Implementer│ │Reviewer │   │QA-Tester │
   │ 编码/POC  │ │ 只读审查 │   │ 功能验收  │
   └─────────┘  └─────────┘   └─────────┘
        │              │
   ┌────▼────┐   ┌────▼────┐
   │ DevOps  │   │  SRE   │
   │ 发布部署 │   │ 根因分析 │
   └─────────┘   └─────────┘
```

每个 Profile 是一个独立的角色定义单元：

```
Profile = config.yaml (model + toolsets)
        + SOUL.md (身份、职责、边界)
        + skills/ (工作流程、检查清单)
        + .env (API keys)
```

---

## 3. Profile 设计（角色定义）

### 3.1 设计原则

**角色 ≠ CLI。** Profile 定义的是"谁"（身份、职责、能力边界），不是"用什么工具执行"。同一个 `implementer` 角色，底层模型可以随时从 Codex 切换到 Claude，只需改 `config.yaml` 中的 model 字段。

### 3.2 标准角色表

> **MVP 阶段启用（8 个）**：PM、Orchestrator、Researcher、Implementer、Reviewer、QA-Tester、DevOps-Engineer、SRE-Observer
> **占坑预留（3 个）**：调研（市场）、设计、运营——Profile 目录预创建但 `toolsets.enabled: []`，不进入 Dispatcher 派发池

| Profile | 状态 | 职责 | SOUL.md 核心规则 | Toolsets | 典型 Model |
|---------|------|------|-----------------|----------|------------|
| `pm` | 🟢 启用 | 需求澄清、技术研判、任务拆解、分配 | "只分析不执行；需求必须澄清到无歧义才拆解；判断技术不确定性决定是否需要 Research" | `kanban`, `memory`, `clarify`, `file_read` | kimi-coding / mimo 2.5pro |
| `orchestrator` | 🟢 启用 | 中枢路由、进度监控、审计追踪 | "按状态机路由表执行；所有角色通信经由本角色中转；不做分析不做执行" | `kanban`, `memory`, `clarify` | kimi-coding / mimo 2.5pro |
| `researcher` | 🟢 启用 | 技术方案调研、POC 建议 | "只分析不写代码；产出技术方案文档；建议是否需要 POC" | `file_read`, `web`, `clarify`, `kanban`, `memory` | claude |
| `implementer` | 🟢 启用 | 编码、测试、重构、POC 验证 | "只执行编码，不做架构决策；POC 在独立 worktree 中执行" | `terminal`, `file`, `code_execution`, `memory`, `kanban` | codex / claude |
| `reviewer` | 🟢 启用 | 代码审查、安全审计（硬门禁） | "审查质量，标记危险操作；只读；block 直到 pass" | `file_read`, `kanban_read`, `kanban_block`, `kanban_complete`, `clarify` | claude |
| `qa-tester` | 🟢 启用 | 功能验收、集成测试、场景验证 | "站在用户角度验收，不站在开发者角度" | `terminal`, `file`, `code_execution`, `browser`, `kanban`, `memory` | claude |
| `devops-engineer` | 🟢 启用 | 三层部署（dev/test→staging→production）、验证门控、UAT 配合、回滚、git tag | "发布前必须通过 QA 验收；staging/production 必须用户批准；不能修改业务代码" | `terminal`, `file`, `code_execution`, `kanban`, `memory` | codex |
| `sre-observer` | 🟢 启用 | 故障根因分析（人工升级触发） | "只观测不修复；输出结构化根因报告" | `file`, `kanban`, `memory`, `clarify`, `web` | claude |
| `pm-researcher` | ⚪ 预留 | 竞品分析、用户画像、市场调研 | （预留，暂不启用） | `[]`（禁用） | — |
| `product-designer` | ⚪ 预留 | PRD 撰写、功能设计、验收标准 | （预留，暂不启用） | `[]`（禁用） | — |
| `growth-marketer` | ⚪ 预留 | 内容创作、SEO、社媒运营、数据分析 | （预留，暂不启用） | `[]`（禁用） | — |

### 3.3 Profile 创建命令

```bash
# 创建 profile（从当前 profile 克隆配置）
hermes profile create orchestrator --clone
hermes profile create implementer --clone
hermes profile create reviewer --clone

# 为每个 profile 配置独立模型
hermes -p orchestrator model    # 选择 kimi-coding 或其他
hermes -p implementer model     # 选择 codex 或 claude
hermes -p reviewer model        # 选择 claude sonnet
```

### 3.4 SOUL.md 示例（implementer）

```markdown
# SOUL.md — Implementer

## Identity
You are a full-stack engineer. You execute coding tasks assigned to you using strict TDD.

## TDD Mandate (强制)
Every task MUST follow Test-Driven Development. No exceptions.

### TDD Workflow per Task
1. Read the task from kanban_show() — extract acceptance criteria.
2. Derive a behavior list (2-3 behaviors) from the acceptance criteria.
   - Each behavior = one testable outcome (e.g., "valid login returns 200 + token").
   - You decide the granularity, not the PM.
3. Run the full test suite to establish baseline.
   - If baseline fails → kanban_block(reason="baseline-failed: {failing tests}") → STOP.
   - Do NOT fix unrelated test failures.
4. For each behavior, execute RED→GREEN cycle:
   - RED: Write a failing test that describes the behavior.
     - Run it. It MUST fail.
     - If it unexpectedly passes → strengthen assertions until it fails.
   - GREEN: Write the minimal implementation to make the test pass.
     - Run it. It MUST pass.
5. After all behaviors: run full regression test suite.
   - If regression fails → fix → re-run until all pass.
6. kanban_complete() with TDD evidence (see Completion Metadata).

### What NOT to Do
- Do NOT write implementation code before a failing test exists.
- Do NOT write all tests first then all implementation (horizontal slicing).
- Do NOT skip the RED phase ("tests pass anyway" means the test is wrong).
- Do NOT make architecture decisions — block the task and ask.
- Do NOT touch production databases, credentials, or CI/CD configs.

## Rules
1. Work within $HERMES_KANBAN_WORKSPACE only.
2. Use kanban_heartbeat() for long-running tasks (>2 min).
3. Use kanban_block() when you need human input.
4. Use kanban_complete() with structured metadata when done.

## Completion Metadata Shape
Always include in kanban_complete metadata:
- behaviors: list of {name, test_file, test_name, status}
- regression: {tests_run, tests_passed, tests_failed}
- changed_files: list of modified file paths
- decisions: list of technical decisions made
- pitfalls: list of gotchas discovered
```

### 3.5 Toolsets 配置

每个 profile 的 `config.yaml` 中通过 `toolsets` 控制可用工具：

```yaml
# pm/config.yaml
toolsets:
  enabled: [kanban, memory, clarify, file_read]
  disabled: [terminal, code_execution, web, browser, delegation]

# orchestrator/config.yaml
toolsets:
  enabled: [kanban, memory, clarify]
  disabled: [terminal, file, code_execution, web, browser, delegation]

# researcher/config.yaml
toolsets:
  enabled: [file_read, web, clarify, kanban, memory]
  disabled: [terminal, code_execution, delegation]

# implementer/config.yaml
toolsets:
  enabled: [terminal, file, code_execution, memory, kanban]
  disabled: [delegation, messaging]

# reviewer/config.yaml
toolsets:
  enabled: [file_read, kanban_read, kanban_block, kanban_complete, clarify]
  disabled: [code_execution, delegation, messaging, file_write, terminal]

# qa-tester/config.yaml
toolsets:
  enabled: [terminal, file, code_execution, browser, kanban, memory]
  disabled: [delegation, messaging]

# devops-engineer/config.yaml
toolsets:
  enabled: [terminal, file, code_execution, kanban, memory]
  disabled: [delegation, messaging, web]

# sre-observer/config.yaml
toolsets:
  enabled: [file, kanban, memory, clarify, web]
  disabled: [terminal, code_execution, delegation]

# --- 预留角色（toolsets 全禁，确保不会被 Dispatcher spawn）---
# pm-researcher/config.yaml (reserved — 市场调研，非技术调研)
# product-designer/config.yaml (reserved)
# growth-marketer/config.yaml (reserved)
toolsets:
  enabled: []
  disabled: [terminal, file, code_execution, web, browser, kanban, memory, clarify, delegation]
```

### 3.6 Project-Level Profile Override Registry

Phase 21 执行后，canonical base profile catalog 存放在仓库 `docs/orchestra/hermes/profile-distribution/`，每个项目通过 `.hermes/profiles/` 提供 override source，运行时由 `orch-profile-sync` 编译到 `.hermes/projects/{project_slug}/`。这样项目的 SOUL.md 与 config 修改仅影响本项目，不污染全局 `~/.hermes/profiles/`。

**覆盖规则：**
- `toolsets.enabled/disabled`：取并集后按 project_override 优先
- `SOUL.md`：项目使用 `{role}.project.md` 作为 SOUL fragment，运行时按顺序拼接：通用规则 → 项目规则 → 角色规则
- `config.yaml` 中的 `model`：project_override 可覆盖全局配置

**示例：**
```yaml
# project-alpha/.hermes/profiles/implementer.override.yaml
toolsets:
  enabled: [terminal, file, code_execution, memory, kanban, web]
  disabled: [delegation]

model: codex
```

```markdown
# project-alpha/.hermes/profiles/implementer.project.md
Project-only rule: prefer local service fixtures over shared staging resources.
```

**目的**：防止一个项目的经验（如新增检查清单、工具陷阱）自动污染所有项目的全局 profile，同时保留全局更新的传播能力。

### 3.7 预留角色占位配置

`pm-researcher`、`product-designer`、`growth-marketer` 三个角色占坑但不启用：

```bash
# 预创建目录结构（实施阶段一次性执行）
mkdir -p docs/orchestra/hermes/profile-distribution/profiles/{pm-researcher,product-designer,growth-marketer}
```

每个预留 Profile 的最小配置：

```yaml
# config.yaml — 全禁用，Dispatcher 不会 spawn
toolsets:
  enabled: []
  disabled: [terminal, file, code_execution, web, browser, kanban, memory, clarify, delegation]
model: none
```

```markdown
<!-- SOUL.md — 占位状态 -->
# SOUL.md — {Role} (RESERVED)

> 状态：占位预留，暂不启用。
> 启用条件：产品开发进入规模化阶段，需要系统化的 {职责}。

## Identity (Future)
You are a {role}. {职责描述}.
```

**启用流程**：未来需要启用时，只需：
1. 修改 `config.yaml` 的 `toolsets.enabled` 和 `model`
2. 完善 `SOUL.md` 的行为规则
3. 在 Orchestrator 的分解剧本中加入该角色的 `assignee` 映射

---

## 4. Kanban 任务管理

### 4.1 Board 设计：每个项目一个 Board

```bash
# 创建项目 board
hermes kanban boards create project-alpha --name "Project Alpha"
hermes kanban boards create project-beta --name "Project Beta"
# ... 10+ 个 board，完全隔离

# 切换当前 board
hermes kanban boards switch project-alpha
```

每个 board 拥有：
- 独立的 SQLite 数据库
- 独立的 workspace 目录
- 独立的 dispatcher 循环
- 任务不可跨 board 引用

### 4.2 任务状态机

```
triage → todo → ready → running → blocked → done → archived
```

| 状态 | 含义 | 触发条件 |
|------|------|---------|
| `triage` | 粗糙想法 | 用户提交原始需求 |
| `todo` | 具体任务 | Orchestrator 拆解后 |
| `ready` | 可执行 | 所有 parents 已 done |
| `running` | 执行中 | Dispatcher 派发 worker |
| `blocked` | 等待输入 | Worker 调用 kanban_block() |
| `done` | 完成 | Worker 调用 kanban_complete() |
| `archived` | 归档 | 手动或 gc 归档 |

### 4.3 依赖链（parents）

```python
# Orchestrator 拆解任务
t1 = kanban_create(
    title="实现用户认证模块",
    assignee="implementer",
    body="JWT token 认证，支持登录/注册/刷新...",
    workspace="worktree"
)

t2 = kanban_create(
    title="编写认证模块测试",
    assignee="implementer",
    body="单元测试 + 集成测试，覆盖正常/异常流程",
    parents=[t1]  # T1 完成后才就绪
)

t3 = kanban_create(
    title="审查认证模块代码",
    assignee="reviewer",
    body="检查安全性、代码规范、错误处理...",
    parents=[t1]  # T1 完成后就绪，与 T2 并行
)

t4 = kanban_create(
    title="修复审查发现的问题",
    assignee="implementer",
    body="根据 reviewer 的 findings 修复代码",
    parents=[t3]  # T3 完成后才就绪
)
```

任务图：
```
T1 (implementer: 实现认证)
 ├── T2 (implementer: 编写测试)    ← 并行
 └── T3 (reviewer: 审查代码)       ← 并行
      └── T4 (implementer: 修复问题)
```

### 4.4 Dispatcher 工作机制

Dispatcher 嵌入 Hermes Gateway 进程，每 60 秒执行一次循环：

```
1. 回收超时 claim（worker 卡死）
2. 回收崩溃 worker（PID 不存在）
3. 将 parents 全 done 的 todo 任务提升为 ready
4. 原子性 claim ready 任务
5. 按 assignee（profile 名）spawn worker 进程
```

Spawn 时的行为：
- 设置 `HERMES_KANBAN_TASK=t_xxx` 环境变量
- 设置 `HERMES_KANBAN_BOARD=<slug>` 环境变量
- 添加 `--skills kanban-worker`（自动注入 worker 生命周期）
- Worker 只看到分配给它的任务和工具

### 4.5 Handoff 机制

任务完成时通过 `kanban_complete()` 传递结构化经验：

```python
kanban_complete(
    summary="shipped JWT auth (TDD) — login/register/refresh, 14 tests pass",
    metadata={
        "behaviors": [
            {"name": "valid login returns token", "test": "test_valid_login", "status": "passed"},
            {"name": "expired token returns 401", "test": "test_expired_token", "status": "passed"}
        ],
        "regression": {"run": 14, "passed": 14, "failed": 0},
        "changed_files": ["auth/jwt.py", "auth/tests/test_jwt.py"],
        "decisions": ["RS256 over HS256 for key rotation support"],
        "pitfalls": ["token refresh needs sliding window, not fixed TTL"],
        "duration_minutes": 25,
    }
)
```

下游任务通过 `kanban_show()` 读取 parent 的 handoff 数据，获得完整上下文。

### 4.6 阻塞任务休眠（Blocked Task Hibernation）

当 worker 调用 `kanban_block()` 进入 L3 等待时，dispatcher 执行以下操作：

1. Worker 进程退出（`claude -p` 正常结束或 hook `defer` 导致 `tool_deferred`）
2. 在 SQLite 中写入 `hibernation_snapshot`：
   - `task_id`, `session_id`（用于 `--resume`）, `git_worktree_ref`, `workspace_snapshot_ref`
3. 释放该 worker 占用的 API context window 和内存资源

**恢复流程：**
1. 用户 unblock 并附带决策
2. dispatcher 校验 workspace 和 session 一致性
3. 若一致，`claude -p --resume <session-id>` 恢复 worker；若不一致，从 snapshot 恢复后重新派发
4. worker 继续执行

**目的**：L3 决策可能持续几小时到几天，避免挂起 worker 长期占用资源。

### 4.7 Worker 崩溃状态回滚（Dirty-State Rollback）

worker 启动前，dispatcher 创建 workspace 的 pre-task 快照：

```bash
git stash push -m "pre-task:${task_id}"
# 或 cp -a workspace/ .snapshots/${task_id}/
```

**崩溃检测：**
- PID 不存在
- 心跳超时（>2 个 dispatcher 循环无 heartbeat）

**回滚流程：**
1. 将 task 状态回退到 `ready`
2. 执行 `git stash pop --index` 或从快照恢复 workspace
3. 在 kanban metadata 中记录 `rollback_count`
4. 重新派发 worker

**目的**：崩溃时 worker 可能已经修改了一半文件，确保下一个 worker 看到干净的初始状态。

### 4.8 背压感知任务准入（Backpressure-Aware Admission）

Dispatcher 在每次轮询时计算全局队列深度比：

```python
backpressure_ratio = ready_implementer_tasks / max(ready_reviewer_tasks, 1)
```

**阈值策略：**
- `ratio <= 2.0`：正常派发
- `2.0 < ratio <= 4.0`：降低 implementer 派发频率（每隔 1 个循环派 1 个）
- `ratio > 4.0`：暂停向 implementer 派发，直至 reviewer 消化积压

**目的**：防止 implementer 生成速度持续超过 reviewer 审查速度，导致待审队列无限膨胀。

---

## 5. Agent 间通信：Kanban Block + Defer

### 5.1 设计决策

**不用 tmux，不用文件总线。** 所有 Agent 间通信通过 Kanban 原生机制（block/unblock）和 Claude Code 的 PreToolUse hook（defer 模式）实现。消息持久化在 SQLite 中，永不丢失。

### 5.2 通信场景

| 场景 | 机制 | 说明 |
|------|------|------|
| 任务分派 | Kanban create/claim | Dispatcher 自动 |
| 任务完成 | Kanban complete | summary + metadata |
| 任务阻塞 | Kanban block | 等待用户/Reviewer 输入 |
| 依赖等待 | Kanban parents | 自动 promote |
| Claude 主动提问 | PreToolUse hook → defer → resume | Worker 退出 → 路由 → 恢复 |
| 用户决策 | clarify() | Hermes 直接问用户 |

### 5.3 技术疑问处理：两条路径

当 Worker（如 implementer）执行中遇到技术疑问，有两条触发路径：

**路径 A：Implementer 主动 block（主流程）**

Implementer 的 system prompt 规定"遇到架构决策必须 block"，Implementer 主动调用 `kanban_block()`：

```
1. Implementer 遇到 "RS256 vs HS256?" 选型问题
2. 调用 kanban_block(reason="reviewer-needed: 用 RS256 还是 HS256?")
3. Dispatcher 检测到 "reviewer-needed:" 前缀
4. 自动创建高优先级 Reviewer 子任务
5. Reviewer 通过 claude -p 一次性给出决策，kanban_complete()
6. Dispatcher 将决策写入原 task metadata，unblock
7. Implementer 读取 handoff 继续执行
```

- **优点**：零额外基础设施，消息永不丢失（SQLite 持久化），天然支持重试
- **触发条件**：Implementer 遵守 prompt 指令，主动 block

**路径 B：Claude Code AskUserQuestion → defer（兜底）**

当 Claude Code 运行时自行决定调用 `AskUserQuestion`（Implementer 未遵守 block 指令，或问题不在架构决策范围内）：

```
1. Claude Code 调用 AskUserQuestion 工具
2. PreToolUse hook 拦截，返回 permissionDecision: "defer"
3. Worker 进程退出，stop_reason: "tool_deferred"
   deferred_tool_use 包含完整问题内容：
   {
     "name": "AskUserQuestion",
     "input": {
       "questions": [{
         "question": "用 RS256 还是 HS256?",
         "header": "JWT算法",
         "options": [{"label": "RS256"}, {"label": "HS256"}],
         "multiSelect": false
       }]
     }
   }
4. Dispatcher 读取 deferred_tool_use，路由给 Reviewer 或用户
5. 拿到答案后，claude -p --resume <session-id> 恢复 Worker
6. PreToolUse hook 再次触发，这次返回 allow + answers：
   {
     "permissionDecision": "allow",
     "updatedInput": {
       "questions": [...],
       "answers": {"用 RS256 还是 HS256?": "RS256"}
     }
   }
7. Worker 继续执行，完全无感知
```

- **优点**：原生 Claude Code 机制，不依赖 prompt 遵守
- **限制**：defer 仅在 `claude -p` 非交互模式生效，且单次 turn 只能有一个工具调用
- **版本要求**：Claude Code >= 2.1.89

### 5.4 决策路由优先级

```
技术疑问
    │
    ├── Implementer 主动调用 kanban_block()?  ──→ 路径 A（主流程）
    │
    └── Claude 自动调用 AskUserQuestion?      ──→ 路径 B（defer 兜底）
                                                    │
                                                    ▼
                                              Dispatcher 读取问题
                                                    │
                                                    ├── 架构/技术选型 ──→ Reviewer
                                                    └── 安全/产品方向  ──→ 用户
```

### 5.5 Session 管理

Worker 通过 `claude -p` 启动，退出后 session 保留在磁盘上。Dispatcher 通过 `session_id` 追踪：

- **正常完成**：`stop_reason: "end_turn"`，任务标记 done
- **defer 等待**：`stop_reason: "tool_deferred"`，任务保持 running，等待 resume
- **崩溃/超时**：Dispatcher 通过 PID 探测（R12）判定，Hermes 官方自动回收任务到 ready；通知用户后由用户决定是否创建 SRE 分析任务（见 §9.3）

---

## 6. 决策矩阵（三级）

> **[项目设计概念，非官方机制]** L1/L2/L3 风险分级是本项目的独创设计。Hermes 官方的安全模型只有两层（Hardline Blocklist + Dangerous Command Approval），属于命令级拦截。本设计将其扩展为任务级分级决策系统。Hermes RFC #16102 明确将 "approval gates" 列为 v1 不做，鼓励通过 plugins/profile conventions 在 user-space 构建。

| 级别 | 决策者 | 场景 | 响应方式 | 响应时间 |
|------|--------|------|---------|---------|
| L1 | Worker 自行决定 | 代码实现细节、变量命名 | 直接执行 | 秒级 |
| L2 | Reviewer 决策 | 技术方案、API 设计 | `claude -p` 一次性调用 | 秒~分钟 |
| L3 | 用户决策 | 安全凭证、破坏性重构、产品方向 | `clarify()` 问用户 | 分钟~小时 |

### L3 升级流程

```
Worker 遇到危险操作
    │
    ▼
Worker kanban_block(reason="需要用户决策：{具体问题}")
    │
    ▼
Dispatcher 通知用户（Gateway 推送 / Dashboard 标记）
    │
    ▼
用户通过 CLI / Dashboard / Gateway unblock 并附带决策
    │
    ▼
Dispatcher 重新派发 Worker 继续执行
```

### 6.2 声明式风险策略引擎（Declarative Risk Policy Engine）

> **[项目增量，非官方机制]** Risk Policy YAML 是本项目独创。Hermes 官方无此机制，但 RFC #16102 明确支持通过 Plugin 层实现。

将 L0-L3 决策矩阵提取为 `policies/risk.yaml`：

```yaml
policies:
  - pattern: "rm -rf /*"
    level: L3
    approver: user
    timeout: 0  # 永不自动通过

  - pattern: "git push --force"
    level: L3
    approver: user
    timeout: 300  # 5 分钟无响应则 escalate

  - pattern: "修改 CI/CD 配置"
    level: L2
    approver: reviewer
    timeout: 600

  - pattern: "变量重命名"
    level: L1
    approver: self
```

**消费方式（三层实现）：**
1. **Plugin 层（硬拦截）**：通过 `pre_tool_call` hook 注册 Risk Policy Plugin，在工具调用前拦截匹配 L3 规则的命令，调用 `kanban_block()` 阻塞任务
2. **SOUL.md 层（软约束）**：worker 的 SOUL.md 中引用 risk.yaml 做 L1/L2 决策依据
3. **Toolsets 白名单层（主防线）**：reviewer 等角色通过 toolsets 白名单限制可用工具（见 R10），无需依赖 prompt 遵守

**实现路径推荐：Plugin 层**（`plugins/risk-gate/`）
- 利用 Hermes 官方 `pre_tool_call` hook（已验证存在）
- 读取 `policies/risk.yaml`，匹配 pattern → 分级
- 与 Hermes 核心解耦，升级安全

**目的**：将概念层面的风险矩阵转化为可执行、可维护的声明式配置。

---

## 7. 多项目并行管理（10+ 项目）

### 7.1 Board 隔离

```
Hermes Gateway (dispatcher 嵌入)
    │
    ├── Board: project-alpha
    │   ├── T1 running (implementer)
    │   ├── T2 ready (implementer)
    │   └── T3 todo (reviewer)
    │
    ├── Board: project-beta
    │   ├── T1 running (implementer)
    │   └── T2 todo (orchestrator)
    │
    ├── Board: project-gamma
    │   └── ...
    │
    └── Board: project-juliet
        └── ...
```

### 7.2 管理方式

| 方式 | 命令 | 适用场景 |
|------|------|---------|
| Dashboard GUI | `hermes dashboard` → Kanban | 可视化总览 |
| CLI | `hermes kanban --board project-alpha list` | 快速查看 |
| Gateway 消息 | `/kanban list` (Telegram/Discord) | 移动端管理 |
| 手机通知 | Gateway 自动推送 | 任务完成/阻塞提醒 |

### 7.3 跨项目经验共享

虽然 Board 隔离了任务，但经验通过以下机制跨项目共享：

- **Memory**：全局 MEMORY.md 中的经验对所有项目生效
- **Skills**：agent 创建的 skill 全局可用
- **Session Search**：可搜索所有项目的历史会话
- **Profile SOUL.md**：角色定义全局共享

---

## 8. 自我进化机制

### 8.1 设计原则

以 Hermes 原生能力为主，借鉴 self-improving-agent 的分类捕获和升级规则。

### 8.2 三层架构

```
┌─────────────────────────────────────────────┐
│  锁定层（不可自动修改）                        │
│  · Bundled skills（Hermes 内置）              │
│  · Hub-installed skills（skills.sh 安装）     │
│  · Pinned skills（用户手动 pin）              │
│  Curator 永远不碰这些。                       │
├─────────────────────────────────────────────┤
│  可变层（Agent 可创建/patch）                  │
│  · Agent-created skills                      │
│  · MEMORY.md（2200 字符上限）                 │
│  · USER.md（1375 字符上限）                   │
│  · Profile SOUL.md（用户审核后修改）           │
│  Curator 定期审查清理。                       │
├─────────────────────────────────────────────┤
│  事实表（只增不改）                            │
│  · Kanban task_runs + metadata               │
│  · Session SQLite（FTS5 可搜索）              │
│  · .learnings/ 目录（经验分类归档）           │
│  永远不修改历史记录。                         │
└─────────────────────────────────────────────┘
```

### 8.3 进化循环

#### 实时层（任务执行中自动触发）

| 触发条件 | 动作 | 存储位置 |
|---------|------|---------|
| 命令/操作失败 | `memory add` 记录错误原因和修复方法 | MEMORY.md |
| 用户纠正 agent | `memory add` 记录纠正内容 | MEMORY.md |
| 发现新工作流（5+ tool calls） | `skill_manage create` 创建新 skill | ~/.hermes/skills/ |
| 知识过时 | `memory replace` 更新过时条目 | MEMORY.md |
| 找到更好的方法 | `memory add` 记录最佳实践 | MEMORY.md |

#### 定期层（自动 + 手动触发）

| 机制 | 频率 | 动作 |
|------|------|------|
| Curator 自动审查 | 每 7 天 | 清理过时 skills、合并重叠 skills、patch 改进 |
| Memory 容量检查 | 任务完成时 | >80% 容量时合并精简条目 |
| Cron 复盘任务 | 可配置（如每周） | 分析近期任务模式，提炼跨项目经验 |

#### 持久层（数据积累）

| 数据源 | 内容 | 消费方式 |
|--------|------|---------|
| Kanban metadata | 每个任务的结构化经验 | 下游任务读取 parent handoff |
| Session SQLite | 全量对话历史 | `session_search` FTS5 搜索 |
| Curator 日志 | skill 变更历史 | `hermes curator status` 查看 |

### 8.4 升级规则（借鉴 self-improving-agent）

| 经验类型 | 存储位置 | 升级路径 |
|---------|---------|---------|
| 纠正（correction） | MEMORY.md | → SOUL.md（行为规则） |
| 洞察（insight） | MEMORY.md | → Skill（工作流程） |
| 知识缺口（knowledge_gap） | MEMORY.md | → Research task（调研任务） |
| 最佳实践（best_practice） | MEMORY.md + Skill | → SOUL.md（永久规则） |
| 错误修复（error_fix） | MEMORY.md | → Skill pitfall 条目 |
| 工具陷阱（tool_gotcha） | MEMORY.md | → Skill pitfall 条目 |

### 8.5 人工审核点

| 审核点 | 机制 | 说明 |
|--------|------|------|
| Skill Pin/Unpin | `hermes curator pin/unpin` | 保护重要 skill 不被清理 |
| Skill Restore | `hermes curator restore` | 恢复误归档的 skill |
| Block 审批 | Kanban block/unblock | Worker 等待用户决策后继续 |
| SOUL.md 编辑 | 手动编辑 | 角色行为永久修改 |
| Memory 检视 | Dashboard / CLI | 查看和编辑持久记忆 |

### 8.6 Curator 质量评分与分级（Quality Score）

为每个 skill 和 memory 条目维护 0-100 自动质量分：

| 维度 | 权重 | 计算方式 |
|------|------|---------|
| 使用频率 | 30% | 最近 30 天内被调用的次数 |
| 任务成功率 | 30% | 使用该 skill 的任务完成率 |
| 最近访问时间 | 20% | 距今天数衰减（半衰期 14 天） |
| 适用范围 | 20% | 跨项目调用次数 / 总调用次数 |

**分级策略：**
- `>= 80`：优质，优先保留
- `40-79`：普通，正常维护
- `< 40`：劣质，自动进入清理候选池
- `< 20`：危险，立即锁定待人工审核

**目的**：将"过时"和"重叠"的主观判断转化为可量化的 curator 审查标准。

### 8.7 Skill 沙箱与 Dry-Run 验证（Skill Sandbox）

任何新创建或升级的 skill 必须先通过沙箱验证：

**流程：**
1. 创建隔离 branch：`sandbox/skill-{name}-{timestamp}`
2. 在 branch 上执行 skill 的 tool calls 序列
3. 检查清单：
   - 是否有文件系统越界（访问 sandbox 外路径）
   - 是否包含危险命令（`rm -rf`, `DROP TABLE`, `git push --force` 等）
   - 是否修改了锁定层 skill
4. 通过后合并到主分支，进入可变层
5. 失败则丢弃 branch，记录失败原因

**目的**：把安全拦截从"7 天后 curator 发现"提前到"skill 诞生即刻"。

### 8.8 分层经验归档（Hierarchical Learnings）

将 `.learnings/` 重构为两级命名空间：

```
.learnings/
├── <project-name>/
│   └── 项目私有经验（默认写入位置）
├── _global/
│   └── 经 curator 审核的跨项目经验
└── _pending/
    └── 待审核的跨项目晋升请求
```

**规则：**
- 经验默认写入项目命名空间
- 只有显式标记为 `cross-project: true` 且通过 curator 审核（quality score >= 60）的条目才进入 `_global/`
- agent 查找经验时同时查询项目池和全局池，项目池优先

**目的**：用文件系统级隔离实现"默认私有、审核后共享"，从根上阻断跨项目经验污染。

---

## 9. 全链路可观测性与故障定位

### 9.1 设计目标

当任何任务失败（`crashed` / `timed_out` / `gave_up`）或反复回滚（`rollback_count ≥ 2`）时，系统能在 **1 分钟内**自动定位根因，输出结构化报告。可观测性覆盖：

```
代码层 → 审查层 → 验收层 → 环境层 → 资源层 → 部署层 → 外部层 → 策略层
```

### 9.2 Observability Plugin（零侵入采集）

> **Hook 验证状态（2026-05-10）**：`post_tool_call`、`on_session_end` 已通过 Hermes 官方文档确认存在（Event Hooks 页面）。Plugin 注册方式：`ctx.register_hook("post_tool_call", handler)`。

通过 Hermes 官方 Plugin + Hook 机制实现，**不修改 Hermes 核心代码**：

```python
# ~/.hermes/plugins/observability/__init__.py

def register(ctx):
    # 1. 采集每个 tool call
    def on_post_tool_call(tool_name, params, result):
        trace_db.record(
            task_id=os.environ.get("HERMES_KANBAN_TASK"),
            tool_name=tool_name,
            params_hash=hash_params(params),
            result_status="ok" if not result.get("error") else "error",
            duration_ms=result.get("_duration_ms", 0),
            timestamp=utcnow(),
        )
    ctx.register_hook("post_tool_call", on_post_tool_call)

    # 2. 会话结束时汇总
    def on_session_end(session_info):
        task_id = os.environ.get("HERMES_KANBAN_TASK")
        trace_db.summarize_session(task_id, session_info)
    ctx.register_hook("on_session_end", on_session_end)
```

**采集数据源：**

| 数据源 | 采集方式 | 内容 |
|--------|---------|------|
| Tool Call Trace | `post_tool_call` hook | 工具名、参数摘要、结果状态、耗时 |
| Session Summary | `on_session_end` hook | 总 tool 数、成功/失败数、运行时长 |
| Kanban Runs | 读取 `kanban.db` | `task_runs` 的 outcome、summary、metadata、elapsed、rollback_count |
| Kanban Events | 读取 `task_events` | 状态变迁历史、block 原因、unblock 决策、claim 时间 |
| Worker Logs | 文件系统读取 | `~/.hermes/kanban/logs/<task_id>/` 终端输出 |
| Audit Logs | 读取风险策略记录 | L3 拦截、Reviewer 写操作拦截 |
| Environment Snapshot | Worker spawn 时采集 | `git status`、`df -h`、`hermes status` |

### 9.3 SRE-Observer 角色

**触发条件**：人工升级触发（不自动创建分析任务）

Hermes 官方已内置 crash/timed_out/gave_up 的自动回收机制（任务回退到 ready），Worker 启动时会读到之前的 outcome 信息自行决策。SRE-Observer 仅在**人工判断需要深度分析**时介入。

**人工升级场景：**
1. 用户/Gateway 收到故障通知后手动创建 SRE 分析任务
2. Orchestrator 在监控循环中发现反复失败（同一任务多次 crash）时建议升级
3. QA-Tester 的 block reason 包含 `regression` / `critical_bug` / `security_flaw` 时建议升级

**分析流程：**

```
1. kanban_show() → 读取故障任务基本信息
2. 查询 trace.db → 获取该 task 最近 3 次 run 的 tool call 序列
3. 读取 worker logs → 终端错误输出与堆栈
4. 读取 task_events → 状态变迁时间线
5. 读取 audit logs → 策略拦截记录
6. 对比 parent handoff → 上游交付物是否携带缺陷
7. 生成根因报告 → kanban_complete(metadata={...})
```

**根因报告 Metadata Schema：**

```json
{
  "fault_task_id": "t_xxx",
  "fault_run_id": "r_xxx",
  "root_cause_category": "environment|code|deployment|external|policy",
  "confidence": "high|medium|low",
  "symptom": "pytest failed with ImportError: No module named 'jwt'",
  "root_cause": "requirements.txt missing pyjwt",
  "responsible_profile": "implementer",
  "upstream_fault": null,
  "recommended_action": "add pyjwt==2.8.0 to requirements.txt and re-run T2",
  "trace_anchor": "tool_call_#7 terminal('pip install ...') exited 1"
}
```

### 9.4 故障定位层次

| 层级 | 典型症状 | 定位方式 |
|------|---------|---------|
| **代码层** | 语法错误、测试失败、逻辑缺陷 | 读取 worker logs + tool call trace |
| **审查层** | Reviewer 拒绝、安全审计不通过 | 读取 reviewer 的 `kanban_complete` findings |
| **验收层** | QA 功能测试未通过、回归 Bug | 读取 qa-tester 的 block reason + test output |
| **环境层** | 依赖缺失、配置错误、权限不足 | Environment Snapshot + `git status` 对比 |
| **资源层** | 磁盘满、内存不足、API 限流 | `df -h` / `hermes status` + 工具调用耗时异常 |
| **部署层** | CI/CD 失败、发布脚本错误 | DevOps worker logs + deployment trace |
| **外部层** | 第三方服务不可用、网络超时 | `web` / `browser` tool 调用失败记录 |
| **策略层** | Risk Policy 拦截、L3 未审批 | audit logs + `kanban_block` reason |

### 9.5 全链路 Dashboard 视图

基于现有 Kanban Dashboard 扩展（通过 dashboard plugin）：

- **链路追踪图**：展开 task 的完整 parents→children 链路，显示每个节点耗时、状态、handoff
- **故障热力图**：按 Profile / 项目 / 时间维度展示失败率
- **实时背压看板**：各角色 ready 队列深度、吞吐率、阻塞任务
- **SRE 报告列表**：历史根因分析报告，可按 category / confidence 筛选
- **Audit 时间线**：L3 拦截、写操作拒绝、权限事件的时序展示

---

## 10. 端到端流程示例

### 场景：用户要求"改善登录体验"（老板只给一句话，不带技术细节）

```
═══════════════════════════════════════════════════════════════
 Phase 1: 需求提交 + 技术发现 + 需求澄清
═══════════════════════════════════════════════════════════════

用户 → Hermes: "登录体验太差了，每次都要重新登录"
  （不带技术细节，只描述问题）

Hermes (pm profile):
  kanban_create(title="改善登录体验", assignee="pm", triage=true)

PM 被 dispatcher 派发：

  第1步: 自动技术发现（从入口出发，按需深入）
    读 AGENTS.md → 项目入口和路由指引
    按指引读 Cargo.toml → Axum 0.7, sqlx, argon2, 无 JWT 依赖
    按指引读 src/ → 现有代码结构
    按需深入: src/routes/users.rs:45-72 → session-based 登录
    按需深入: src/middleware/mod.rs:8-15 → 无 auth 中间件
    输出: 技术发现报告（含 8 项代码证据，具体到文件:行号）

  第2步: 需求澄清（一次一问，逐步收缩）
    Q1: 核心目标？→ "7天免登录"（排除了无限期/短会话）
    Q2: 用户群体？→ "外部客户"（安全标准确定）
    Q3: 时间压力？→ "1-2周"（复杂度上界确定）
    Q4: 登录方式？→ "邮箱+密码"（排除第三方登录）
    Q5: 处理方式？→ "替换session"（排除叠加方案）
    Q6: 过期交互？→ "静默刷新"（排除弹窗/跳转）
    Q7: 验收方式？→ "自动化+手动"
    Q8: 影响范围？→ "仅登录接口"
    Q9: 可观测性？→ "基础日志"
    Q10: MVP范围？→ "完整认证流程"
    Q11: 实现方式？→ "第三方库"
    （每个问题: ⭐推荐标签 + 大白话理由 + "其他"选项）
    （选了"其他"→ 追加一次一问细化）

  第3步: 可行性检查
    检查需求 vs 代码现实 → 发现冲突？
    冲突示例: 范围(完整认证+密码重置) vs 时间(本周) → 不可行
    → 主动沟通Jacky，给出证据和建议选项
    → Jacky选择缩小范围 → 冲突解决

  → 生成标准化需求文档（含证据索引 + 可行性确认表）
  → 所有判断有代码证据（文件:行号），任何角色可无歧义理解

═══════════════════════════════════════════════════════════════
 Phase 1.5: 技术研判（Research + POC，按需）
═══════════════════════════════════════════════════════════════

PM 判断："JWT 认证"涉及项目中从未用过的 JWT 技术栈 → 需要 Research

PM 创建子任务:
  T0.1 = kanban_create(
      title="JWT 技术方案调研",
      assignee="researcher",
      body="调研 JWT 签名方案（RS256 vs HS256）、库选型、安全性考虑",
      parents=[T0]  # 依赖原始需求任务
  )

Researcher 被唤醒:
  kanban_show() → 读取需求文档
  读取 AGENTS.md → 路由到 Cargo.toml（当前无 JWT 依赖）
  web research → 对比 jsonwebtoken vs jwt-simple

  kanban_complete(
      summary="技术方案: 推荐 RS256 + jsonwebtoken 库",
      metadata={
          "proposal": "RS256 支持密钥轮换，jsonwebtoken 是 Rust 生态最成熟的 JWT 库",
          "needs_poc": true,
          "poc_scope": "验证 RS256 签名性能和密钥轮换流程"
      }
  )

PM 判断 Researcher 建议 POC:
  T0.2 = kanban_create(
      title="JWT RS256 POC 验证",
      assignee="implementer",
      body="在独立 worktree 中验证 RS256 签名性能和密钥轮换",
      parents=[T0.1]
  )

Implementer 执行 POC:
  git worktree add .worktrees/poc-jwt-rs256 -b poc/jwt-rs256
  # ... POC 代码 ...
  kanban_complete(
      summary="RS256 POC 通过: 签名 1000 次/秒，密钥轮换正常",
      metadata={"poc_result": "success", "benchmark": "1000 ops/sec"}
  )

═══════════════════════════════════════════════════════════════
 Phase 2: 任务拆解（PM）
═══════════════════════════════════════════════════════════════

PM 读取澄清后的需求文档（含证据链）和技术方案，执行：

  kanban_show() → 读取需求文档（含 8 项代码证据）

  # 拆解为子任务
  T1 = kanban_create(
      title="实现 JWT 认证模块",
      assignee="implementer",
      body="实现登录/注册/刷新接口，使用 RS256...",
      workspace="worktree"
  )
  T2 = kanban_create(
      title="编写认证模块测试",
      assignee="implementer",
      body="单元测试 + 集成测试...",
      parents=[T1]
  )
  T3 = kanban_create(
      title="审查认证模块代码",
      assignee="reviewer",
      body="安全性、代码规范、错误处理...",
      parents=[T1]
  )
  T4 = kanban_create(
      title="修复审查问题",
      assignee="implementer",
      body="根据 reviewer findings 修复...",
      parents=[T3]
  )

  kanban_complete(
      summary="拆解为 4 个子任务：实现→测试+审查→修复",
      metadata={"task_graph": {...}}
  )

═══════════════════════════════════════════════════════════════
 Phase 3: 执行（Implementer · TDD 强制）
═══════════════════════════════════════════════════════════════

Dispatcher 发现 T1 ready, spawn implementer worker:

  hermes -p implementer --skills kanban-worker

Implementer (TDD 流程):
  kanban_show() → 读取 T1 详情 + 验收标准
  cd $HERMES_KANBAN_WORKSPACE

  # TDD 第一步：从验收标准推导行为清单（Implementer 自行决定粒度）
  # 验收: "有效凭证返回 token，无效凭证返回 401"
  # → 行为 A: 有效登录 → 200 + token
  # → 行为 B: 无效登录 → 401
  # → 行为 C: 过期 token → Expired 错误

  # TDD 门禁：跑全量测试建立基线
  terminal(command="cargo test --lib")
  # 如果基线失败 → kanban_block(reason="baseline-failed: ...") → 停止

  # TDD 循环：对每个行为执行 RED→GREEN
  # 行为 A: RED (写测试 → 必须失败) → GREEN (写最简实现 → 必须通过)
  # 行为 B: RED → GREEN
  # 行为 C: RED → GREEN

  # 遇到疑问（如不确定用 RS256 还是 HS256）
  # 路径 A: kanban_block(reason="reviewer-needed: ...") → Dispatcher 创建 Reviewer 任务
  # 路径 B: AskUserQuestion → PreToolUse hook defer → Dispatcher 路由 → --resume 恢复

  # 全量回归测试
  terminal(command="cargo test --lib")

  # 完成（TDD metadata 格式）
  kanban_complete(
      summary="JWT 签发已实现 (TDD)，3 个行为各有对应测试，回归通过",
      metadata={
          "behaviors": [
              {"name": "有效登录→200", "test": "test_valid_login", "status": "passed"},
              {"name": "无效登录→401", "test": "test_invalid_login", "status": "passed"},
              {"name": "过期token→Expired", "test": "test_expired_token", "status": "passed"}
          ],
          "regression": {"run": 15, "passed": 15, "failed": 0},
          "changed_files": ["src/auth/jwt.rs", "tests/auth/test_jwt.py"],
          "decisions": ["RS256 for key rotation support"],
          "pitfalls": ["token refresh needs sliding window"]
      }
  )

═══════════════════════════════════════════════════════════════
 Phase 4: 测试 + 审查（并行）
═══════════════════════════════════════════════════════════════

T1 done → T2 和 T3 同时 promoted to ready

Dispatcher 并行 spawn:
  hermes -p implementer --skills kanban-worker  (T2: 测试)
  hermes -p reviewer --skills kanban-worker     (T3: 审查)

Reviewer:
  kanban_show() → 读取 T1 的 handoff（changed_files, decisions...）
  cd $HERMES_KANBAN_WORKSPACE

  # 审查代码
  terminal(command="claude -p '审查 src/auth/ 下的代码变更，\
            检查安全性、代码规范、错误处理...' --max-turns 3")

  kanban_complete(
      summary="审查完成，发现 1 个安全问题",
      metadata={
          "findings": [
              {"severity": "high", "file": "src/auth/jwt.rs",
               "issue": "token 过期时间硬编码，应可配置"}
          ],
          "approved": false
      }
  )

═══════════════════════════════════════════════════════════════
 Phase 5: 修复 + 自我进化
═══════════════════════════════════════════════════════════════

T3 done → T4 promoted to ready

Implementer (T4):
  kanban_show() → 读取 T3 的 handoff（findings...）

  # 修复问题（TDD：先写失败测试，再修复）
  # RED: 写测试 test_token_expiry_is_configurable → 失败（当前硬编码）
  # GREEN: 修改为环境变量配置 → 测试通过
  terminal(command="cargo test --lib")

  kanban_complete(
      summary="已修复，token 过期时间改为环境变量配置 (TDD)",
      metadata={
          "behaviors": [
              {"name": "token 过期时间可配置", "test": "test_token_expiry_is_configurable", "status": "passed"}
          ],
          "regression": {"run": 15, "passed": 15, "failed": 0},
          "changed_files": ["src/auth/jwt.rs", "config/default.toml"]
      }
  )

  # 自我进化：记录经验
  memory add "JWT token 过期时间应可配置，不要硬编码"
  skill_manage create "jwt-auth-checklist" → 新 skill

═══════════════════════════════════════════════════════════════
 Phase 5.5: 故障场景 — 部署失败触发 SRE-Observer（异常分支）
═══════════════════════════════════════════════════════════════

> 📎 正常部署流程参见 Phase 5.6（三层环境部署）。以下为 Phase 5.6 中任一层部署失败时的异常分支。

T-deploy (devops-engineer: 部署发布) crashed：
  - 部署脚本在某层环境返回 exit code 1（dev/test / staging / production）
  - devops-engineer 尝试修复部署脚本/配置失败
  - Dispatcher 检测到 outcome='crashed'
  - 自动创建 T-deploy-sre = kanban_create(
      title="根因分析: T-deploy 部署失败",
      assignee="sre-observer",
      body="T-deploy (devops-engineer) 部署失败，请定位根因",
      parents=[T-deploy],
  )

SRE-Observer:
  kanban_show() → 读取 T-deploy 详情
  查询 trace.db → T-deploy 的 tool call 序列
  读取 worker logs → 部署脚本的 stderr
  读取 task_events → T-deploy 的 claim → crashed 时间线
  Environment Snapshot → production git status / hermes status

  kanban_complete(
      summary="根因定位: 生产环境缺少环境变量 DATABASE_URL",
      metadata={
          "fault_task_id": "T-deploy",
          "root_cause_category": "environment",
          "confidence": "high",
          "symptom": "deploy.sh exited 1: 'DATABASE_URL: parameter not set'",
          "responsible_profile": "devops-engineer",
          "recommended_action": "在 ~/.env.production 中补全 DATABASE_URL 并重新部署",
          "trace_anchor": "tool_call_#3 terminal('deploy.sh production') exited 1",
      }
  )

Dispatcher 通知 CEO：
  "项目 Alpha 部署失败，SRE-Observer 已定位根因：
   类别: environment | 置信度: high
   建议: 补全 DATABASE_URL 后重新部署 T-deploy"

═══════════════════════════════════════════════════════════════
 Phase 6: 完成通知
═══════════════════════════════════════════════════════════════

所有任务 done → Gateway 推送通知用户：
  "项目 Alpha 用户认证模块已完成并通过审查。
   变更文件: src/auth/jwt.rs, src/auth/routes.rs, config/default.toml
   测试: 12/12 通过
   经验沉淀: 2 条 memory, 1 个新 skill"
```

---

## 11. 与现有 dev-orchestra skill 的迁移路径

| 组件 | 当前设计 | 新设计 | 迁移动作 |
|------|---------|--------|---------|
| 任务管理 | 文件总线 + todo 工具 | Kanban boards | 删除文件总线逻辑 |
| 任务依赖 | inotifywait 轮询 | Kanban parents | 替换为依赖链 |
| 进程管理 | tmux 手动 spawn | Kanban dispatcher + claude -p | 删除手动 spawn |
| Agent 间通信 | 文件总线 JSON envelope | Kanban block/unblock + defer | 删除文件总线和 tmux |
| 角色定义 | 绑定 CLI (claude-supervisor/codex-executor) | 抽象 Profile | 重写 SOUL.md |
| 决策流转 | 三级决策矩阵 | 保留（不冲突） | 无需修改 |
| 多项目 | process(action="list") | Kanban 多 board | 替换为 board |
| 持久化 | 无 | SQLite + memory | 新增 |
| 自我进化 | 无 | curator + memory + skill_manage | 新增 |

---

## 12. 前置条件

| 依赖 | 最低版本 | 检查命令 |
|------|---------|---------|
| Hermes Agent | >= 0.11.0 | `hermes --version` |
| Claude Code CLI | >= 2.1.110 (含 defer 支持) | `claude --version` |
| Codex CLI | >= 0.122.0 | `codex --version` |
| Node.js | >= 18 | `node --version` |

---

## 13. 配置文件结构

```
~/.hermes/
├── config.yaml              # 主配置（model, toolsets, curator 等）
├── .env                     # API keys
├── SOUL.md                  # 默认 profile 的角色定义
├── memories/
│   ├── MEMORY.md            # 持久记忆（2200 字符）
│   └── USER.md              # 用户画像（1375 字符）
├── profiles/
│   ├── orchestrator/          # 🟢 启用：AI 项目经理
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   ├── implementer/           # 🟢 启用：开发工程师
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   ├── reviewer/              # 🟢 启用：技术审查员
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   ├── qa-tester/             # 🟢 启用：测试验收员
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   ├── devops-engineer/       # 🟢 启用：发布工程师
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   ├── sre-observer/          # 🟢 启用：可观测性工程师
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   ├── pm-researcher/         # ⚪ 预留：产品调研员
│   │   ├── config.yaml        #   toolsets.enabled: []
│   │   ├── SOUL.md            #   占位状态
│   │   └── .env
│   ├── product-designer/      # ⚪ 预留：产品设计师
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   └── growth-marketer/       # ⚪ 预留：增长运营官
│       ├── config.yaml
│       ├── SOUL.md
│       └── .env
├── skills/
│   ├── .bundled_manifest    # 内置 skills 清单
│   ├── kanban-worker/       # 内置 worker 生命周期
│   ├── kanban-orchestrator/ # 内置编排 playbook
│   └── ...                  # agent-created skills
├── kanban/
│   ├── boards/
│   │   ├── project-alpha/
│   │   │   ├── kanban.db    # 项目 A 的 SQLite
│   │   │   └── workspaces/  # 项目 A 的 workspace
│   │   ├── project-beta/
│   │   │   ├── kanban.db
│   │   │   └── workspaces/
│   │   └── ...
│   └── current              # 当前活跃 board slug
└── state.db                 # 全局 session SQLite
```

---

## 附录 A：Hermes 官方能力引用

> **Capability verification status:** Phase 20 已将本附录中的“官方能力”声明统一回写到 `.planning/phases/20-capability-verification-boundary-lock/20-CAPABILITY-MATRIX.md`。状态值只使用 `verified` / `unsupported` / `local-extension` 三种。

| 能力 | 官方来源 | 本文使用方式 | Capability verification status |
|------|---------|-------------|--------------------------------|
| Kanban 系统 | `hermes kanban --help` + 官方文档 | 任务生命周期管理 | `verified (runtime)` |
| Profile 系统 | `hermes profile --help` + 官方文档 | 角色隔离 | `verified (runtime)` |
| Dispatcher | `hermes kanban dispatch --help` + 官方文档 | 自动派发 worker | `verified (runtime)` |
| Curator | `hermes curator --help` + 官方文档 | Skill 生命周期维护 | `verified (hybrid)` |
| Memory | `hermes memory --help` + 官方文档 | 跨会话持久记忆 | `verified (hybrid)` |
| skill_manage（官方工具面） | 官方配置/skill 文档 | 官方 skill 创建能力存在 | `verified (doc-only)` |
| skill_manage（Phase 19 自动创建 skill 工作流语义） | 同上 | 自动创建 + 持续演进 workflow | `local-extension` |
| Session Search | `hermes sessions --help` + toolsets 文档 | 历史回溯 | `verified (runtime)` |
| terminal() | tools/toolsets 文档 | 执行任意 CLI | `verified (hybrid)` |
| clarify() | tools/toolsets 文档 | 向用户请求决策 | `verified (hybrid)` |
| Gateway（命令/服务面） | `hermes gateway --help` + CLI 文档 | 多平台消息能力存在 | `verified (hybrid)` |
| Gateway（当前环境消息投递闭环） | 同上 | 真实消息通知闭环 | `unsupported` |
| Plugin `pre_tool_call` hook | hooks/Event Hooks 文档 | Risk Policy 硬拦截 | `verified (hybrid)` |
| Plugin `post_tool_call` hook | hooks/Event Hooks 文档 | Observability 采集 | `verified (hybrid)` |
| Plugin `on_session_end` hook | hooks/Event Hooks 文档 | Observability 汇总 | `verified (hybrid)` |
| `approvals.mode` 配置 | `config.yaml` + Security 文档 | 命令级审批（官方两层） | `verified (hybrid)` |
| RFC #16102 | GitHub Issue | approval gates 属于 user-space | `verified (doc-only)` |

## 附录 B：self-improving-agent 规则参考

来源：ClawHub `self-improving-agent` skill（community）

**触发条件（6 种）：**
1. 命令/操作意外失败
2. 用户纠正 agent
3. 用户请求不存在的功能
4. 外部 API/工具失败
5. Agent 发现知识过时
6. 发现更好的方法

**分类体系（4 类）：**
- `correction`：纠正错误认知
- `insight`：新发现的洞察
- `knowledge_gap`：识别的知识缺口
- `best_practice`：总结的最佳实践

**升级规则：**
- 广泛适用 → promote 到 SOUL.md（永久规则）
- 工作流改进 → promote 到 Skill
- 工具陷阱 → promote 到 Skill pitfall 条目
- 知识缺口 → 创建 research task

> 注：本设计使用 Hermes 原生的 memory + skill_manage 替代 `.learnings/` 文件存储，保留其触发条件和分类体系。

---

## 附录 C：终端权限模型（Terminal Permission Model）

为 reviewer 等 read-only 角色实现技术层面的"只读"约束：

**Read-Only Terminal Proxy：**
- 拦截所有写命令（`rm`, `write`, `git push`, `DROP TABLE` 等）
- 转为 dry-run 模式返回预期结果，不实际执行
- 读命令正常透传
- 写操作尝试记录到审计日志 `~/.hermes/audit/terminal.log`

**实现方式：**
- 在 Hermes 层拦截 `terminal()` tool call 的 `command` 参数
- 使用命令白名单/黑名单 + 正则匹配
- 对模糊命令（如 `curl` 可能触发 POST）标记为 `ambiguous` 并要求二次确认

**目的**：解决 `terminal(只读)` 只有 prompt 约束、没有技术 enforce 的问题。

## 附录 D：动态 Agent 上下文（Kanban State as Living Context）

每次启动 agent 时，动态从当前 Kanban board 生成项目专属上下文：

**注入内容：**
- 当前 board 的活跃任务列表（running + blocked）
- 最近 3 个已完成任务的 handoff 摘要
- 当前项目的 block 原因统计
- 当前 board 的 backpressure 状态

**格式：**
```markdown
## 当前项目上下文（自动生成，请勿手动编辑）

**活跃任务：**
- T42 (implementer): 实现 JWT 认证模块 — running, 15 min
- T43 (reviewer): 审查 JWT 代码 — blocked, 等待用户确认

**最近完成：**
- T41 (orchestrator): 拆解认证模块为 4 个子任务

**项目状态：** 正常 | 积压比: 1.2
```

**目的**：替代静态 AGENTS.md，让 agent 每次启动都携带项目的实时上下文，减少重复澄清和错误假设。

## 附录 E：脚本自注册机制（Self-Registering Commands）

将 `orch-*` 脚本从 `docs/orchestra/scripts/` 迁移到根目录 `scripts/`，并通过 manifest 自动注册：

**Phase Manifest DSL（`scripts/manifest.yaml`）：**
```yaml
commands:
  - name: orch-init
    script: orch-init.sh
    description: 初始化项目 orchestra 环境
    profiles: [orchestrator]

  - name: orch-dispatch
    script: orch-dispatch.sh
    description: 派发任务到指定 profile
    profiles: [orchestrator, implementer]
```

**自动注册行为：**
- `make init` 时读取 manifest，生成 Makefile target
- `make register` 将命令注入当前 board 的 agent 上下文
- 新增/删除脚本时，修改 manifest 即可，无需手动更新 Makefile

**目的**：解决脚本 buried 在深层目录、根目录 `scripts/` 为空的问题。
