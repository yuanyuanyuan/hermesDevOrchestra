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
- Kanban 管理任务生命周期，tmux 管理实时通信
- 自我进化走 Hermes 原生的 memory + skill_manage + curator 机制

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
│  · tmux: 进程管理 + 实时通信                                  │
│  · Curator: Skill 生命周期维护                                │
│  · Memory: 跨会话持久记忆                                    │
└───────┬──────────────┬──────────────┬───────────────────────┘
        │              │              │
   ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
   │ Profile │   │ Profile │   │ Profile │
   │  ...N   │   │  ...2   │   │  ...1   │
   └─────────┘   └─────────┘   └─────────┘
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

| Profile | 职责 | SOUL.md 核心规则 | Toolsets | 典型 Model |
|---------|------|-----------------|----------|------------|
| `orchestrator` | 拆任务、派发、监控、复盘 | "只路由，不执行" | kanban, memory, clarify, delegation | 任意（如 kimi-coding） |
| `implementer` | 编码、测试、重构 | "只执行编码，不做架构决策" | terminal, file, code_execution | 任意（如 codex/claude） |
| `reviewer` | 代码审查、技术决策 | "审查质量，标记危险操作" | terminal(只读), file(只读) | 任意（如 claude） |
| `researcher` | 调研、收集信息 | "广泛搜索，结构化输出" | web, browser, file, terminal | 任意 |
| `analyst` | 综合分析、决策建议 | "基于事实，给出明确结论" | file, memory | 任意 |
| `ops` | 部署、运维、CI/CD | "变更前确认，操作可回滚" | terminal, file | 任意 |

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
You are a full-stack engineer. You execute coding tasks assigned to you.

## Rules
1. Read the task from kanban_show() before starting.
2. Work within $HERMES_KANBAN_WORKSPACE only.
3. Run existing tests before making changes (establish baseline).
4. Write tests for new functionality.
5. Run tests after changes to verify.
6. Do NOT make architecture decisions — block the task and ask.
7. Do NOT touch production databases, credentials, or CI/CD configs.
8. Use kanban_heartbeat() for long-running tasks (>2 min).
9. Use kanban_complete() with structured metadata when done.
10. Use kanban_block() when you need human input.

## Completion Metadata Shape
Always include in kanban_complete metadata:
- changed_files: list of modified file paths
- tests_run: number of tests executed
- tests_passed: number of tests passed
- decisions: list of technical decisions made
- pitfalls: list of gotchas discovered
```

### 3.5 Toolsets 配置

每个 profile 的 `config.yaml` 中通过 `toolsets` 控制可用工具：

```yaml
# orchestrator/config.yaml
toolsets:
  enabled: [kanban, memory, clarify, delegation, todo]
  disabled: [terminal, file, code_execution, web, browser]

# implementer/config.yaml
toolsets:
  enabled: [terminal, file, code_execution, memory, kanban]
  disabled: [delegation, messaging]

# reviewer/config.yaml
toolsets:
  enabled: [terminal, file, memory, kanban]
  disabled: [code_execution, delegation, messaging]
```

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
    summary="shipped JWT auth — login/register/refresh, 14 tests pass",
    metadata={
        "changed_files": ["auth/jwt.py", "auth/tests/test_jwt.py"],
        "tests_run": 14,
        "tests_passed": 14,
        "decisions": ["RS256 over HS256 for key rotation support"],
        "pitfalls": ["token refresh needs sliding window, not fixed TTL"],
        "duration_minutes": 25,
    }
)
```

下游任务通过 `kanban_show()` 读取 parent 的 handoff 数据，获得完整上下文。

---

## 5. 实时通信：tmux

### 5.1 设计决策

**不用文件总线。** Hermes 作为 tmux 的操控者，可以直接通过 `tmux capture-pane` 读取输出、`tmux send-keys` 发送输入，实现 Agent 间的实时通信。

### 5.2 通信场景

| 场景 | 机制 | 说明 |
|------|------|------|
| 任务分派 | Kanban create/claim | Dispatcher 自动 |
| 任务完成 | Kanban complete | summary + metadata |
| 任务阻塞 | Kanban block | 等待用户输入 |
| 依赖等待 | Kanban parents | 自动 promote |
| 实时问答 | tmux capture + send-keys | Hermes 做路由器 |
| 用户决策 | clarify() | Hermes 直接问用户 |

### 5.3 实时问答流程

当 Worker（如 implementer）执行中遇到需要 reviewer 决策的问题：

```
1. Worker 的 tmux 输出显示疑问
2. Hermes capture-pane 读取到
3. Hermes 判断需要 reviewer 决策
4. Hermes 用 claude -p 一次性调用 reviewer 角色：
   terminal(command="claude -p '审查以下技术问题：{问题描述}，
            项目上下文：{上下文}，给出决策和理由。' --max-turns 1")
5. Hermes 将决策结果 send-keys 回 Worker 的 tmux
6. Worker 继续执行
```

**Reviewer 不需要常驻 tmux 会话。** 按需 `-p` 调用即可。

### 5.4 tmux 会话命名规范

```
hermes-{board_slug}-{profile}-{task_id}
```

示例：
```
hermes-project-alpha-implementer-t_a1b2c3
hermes-project-beta-reviewer-t_d4e5f6
```

---

## 6. 决策矩阵（三级）

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

---

## 9. 端到端流程示例

### 场景：用户要求"给项目 Alpha 加用户认证模块"

```
═══════════════════════════════════════════════════════════════
 Phase 1: 需求提交
═══════════════════════════════════════════════════════════════

用户 → Hermes: "给项目 Alpha 加用户认证模块，用 JWT"

Hermes (orchestrator profile):
  kanban_create(title="规划: 用户认证模块", assignee="orchestrator")

═══════════════════════════════════════════════════════════════
 Phase 2: 任务拆解（Orchestrator）
═══════════════════════════════════════════════════════════════

Orchestrator 被 dispatcher 派发，执行：

  kanban_show() → 读取任务详情

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
 Phase 3: 执行（Implementer）
═══════════════════════════════════════════════════════════════

Dispatcher 发现 T1 ready, spawn implementer worker:

  hermes -p implementer --skills kanban-worker

Implementer:
  kanban_show() → 读取 T1 详情
  cd $HERMES_KANBAN_WORKSPACE

  # 运行现有测试建立基线
  terminal(command="npm test")

  # 调用底层 CLI 执行编码（具体用什么 CLI 由 profile 的 model 决定）
  # 如果 model 是 codex:
  terminal(command="codex exec --full-auto '实现 JWT 认证...'",
           workdir="...", background=true, pty=true)
  # 如果 model 是 claude:
  terminal(command="claude -p '实现 JWT 认证...' --max-turns 10",
           workdir="...", timeout=180)

  # 长任务心跳
  kanban_heartbeat(note="已实现登录接口，正在实现注册...")

  # 遇到疑问（如不确定用 RS256 还是 HS256）
  # tmux 输出显示疑问，Hermes 读取后用 claude -p 问 reviewer
  # reviewer 回答后 Hermes send-keys 回 implementer 的 tmux

  # 完成
  kanban_complete(
      summary="JWT 认证已实现，登录/注册/刷新三个接口",
      metadata={
          "changed_files": ["src/auth/jwt.rs", "src/auth/routes.rs"],
          "tests_run": 12, "tests_passed": 12,
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

  # 修复问题
  terminal(command="codex exec --full-auto '修复 token 过期时间硬编码问题...'")

  kanban_complete(
      summary="已修复，token 过期时间改为环境变量配置",
      metadata={
          "changed_files": ["src/auth/jwt.rs", "config/default.toml"],
          "tests_run": 12, "tests_passed": 12
      }
  )

  # 自我进化：记录经验
  memory add "JWT token 过期时间应可配置，不要硬编码"
  skill_manage create "jwt-auth-checklist" → 新 skill

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

## 10. 与现有 dev-orchestra skill 的迁移路径

| 组件 | 当前设计 | 新设计 | 迁移动作 |
|------|---------|--------|---------|
| 任务管理 | 文件总线 + todo 工具 | Kanban boards | 删除文件总线逻辑 |
| 任务依赖 | inotifywait 轮询 | Kanban parents | 替换为依赖链 |
| 进程管理 | tmux 手动 spawn | Kanban dispatcher | 删除手动 spawn |
| Agent 间通信 | 文件总线 JSON envelope | tmux capture + send-keys | 删除文件总线 |
| 角色定义 | 绑定 CLI (claude-supervisor/codex-executor) | 抽象 Profile | 重写 SOUL.md |
| 决策流转 | 三级决策矩阵 | 保留（不冲突） | 无需修改 |
| 多项目 | process(action="list") | Kanban 多 board | 替换为 board |
| 持久化 | 无 | SQLite + memory | 新增 |
| 自我进化 | 无 | curator + memory + skill_manage | 新增 |

---

## 11. 前置条件

| 依赖 | 最低版本 | 检查命令 |
|------|---------|---------|
| Hermes Agent | >= 0.11.0 | `hermes --version` |
| Claude Code CLI | >= 2.1.110 | `claude --version` |
| Codex CLI | >= 0.122.0 | `codex --version` |
| tmux | >= 3.0 | `tmux -V` |
| Node.js | >= 18 | `node --version` |

---

## 12. 配置文件结构

```
~/.hermes/
├── config.yaml              # 主配置（model, toolsets, curator 等）
├── .env                     # API keys
├── SOUL.md                  # 默认 profile 的角色定义
├── memories/
│   ├── MEMORY.md            # 持久记忆（2200 字符）
│   └── USER.md              # 用户画像（1375 字符）
├── profiles/
│   ├── orchestrator/
│   │   ├── config.yaml      # model + toolsets
│   │   ├── SOUL.md          # 角色定义
│   │   └── .env             # 可选的 profile 级 keys
│   ├── implementer/
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   └── .env
│   └── reviewer/
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

| 能力 | 官方来源 | 本文使用方式 |
|------|---------|-------------|
| Kanban 系统 | `hermes kanban --help` + 官方文档 | 任务生命周期管理 |
| Profile 系统 | `hermes profile --help` | 角色隔离 |
| Dispatcher | Kanban 内置，嵌入 Gateway | 自动派发 worker |
| Curator | `hermes curator --help` + 官方文档 | Skill 生命周期维护 |
| Memory | `hermes memory --help` + 官方文档 | 跨会话持久记忆 |
| skill_manage | Agent 内置工具 | 自动创建 skill |
| Session Search | `hermes sessions --help` | 历史回溯 |
| terminal() | 内置工具 | 执行任意 CLI |
| clarify() | 内置工具 | 向用户请求决策 |
| Gateway | `hermes gateway --help` | 多平台消息通知 |

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
