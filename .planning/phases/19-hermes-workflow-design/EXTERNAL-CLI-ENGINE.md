---
date: 2026-05-11
topic: hermes-workflow-design
---

# 外部 CLI 引擎架构设计

> 版本: 1.0.0
> 日期: 2026-05-11
> 状态: Draft (Grill-Me 确认版)
> 本文档为 Phase 19 设计的架构补充，定义 "Hermes 调度 + 外部 CLI 引擎" 统一模式。

---

## 1. 设计动机

Hermes Agent 的调度能力（Kanban、Dispatcher、Gateway、Plugin Hooks）非常强大，但在代码分析、需求推理、技术发现等"思考"任务上，Claude Code 和 Codex CLI 等专用 CLI 工具拥有更成熟的工程化能力：

- Claude Code：完整的文件操作工具链（Read/Glob/Grep/Bash）、subagents、worktrees、MCP tools、hooks 系统
- Codex CLI：强大的代码生成能力、TDD 工作流、--full-auto 自动执行

**核心思路：让 Hermes 做调度专家，让 CLI 工具做工程专家。**

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────────────────────┐
│  Hermes Agent（纯调度层）                                            │
│  · Kanban 任务板 + Dispatcher 派发                                   │
│  · Gateway 消息推送                                                  │
│  · Plugin Hooks（Risk Policy + Observability）                       │
│  · Memory + Curator（自我进化）                                      │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Profile 层（每个 Profile = 轻量 LLM + 协议编排）              │  │
│  │                                                               │  │
│  │  ┌─────────┐ ┌─────────────┐ ┌──────────┐ ┌──────────────┐  │  │
│  │  │   PM    │ │ Researcher  │ │Implementer│ │   Reviewer   │  │  │
│  │  │ 路由+编排│ │ 路由+编排   │ │ 路由+编排 │ │ 路由+编排    │  │  │
│  │  └────┬────┘ └──────┬──────┘ └─────┬────┘ └──────┬───────┘  │  │
│  │       │             │              │             │           │  │
│  │       ▼             ▼              ▼             ▼           │  │
│  │  ┌─────────┐ ┌─────────────┐ ┌──────────┐ ┌──────────────┐  │  │
│  │  │claude -p│ │  claude -p  │ │codex exec│ │  claude -p   │  │  │
│  │  │PM 引擎  │ │Research 引擎│ │Impl 引擎 │ │ Review 引擎  │  │  │
│  │  └─────────┘ └─────────────┘ └──────────┘ └──────────────┘  │  │
│  │                                                               │  │
│  │  ┌──────────────┐ ┌─────────────┐ ┌──────────────────────┐  │  │
│  │  │  QA-Tester   │ │   DevOps    │ │    SRE-Observer      │  │  │
│  │  │ 路由+编排     │ │ 路由+编排   │ │ 路由+编排            │  │  │
│  │  └──────┬───────┘ └──────┬──────┘ └──────────┬───────────┘  │  │
│  │         ▼                ▼                    ▼              │  │
│  │  ┌──────────────┐ ┌─────────────┐ ┌──────────────────────┐  │  │
│  │  │  claude -p   │ │ codex exec  │ │     claude -p        │  │  │
│  │  │  QA 引擎     │ │ DevOps 引擎 │ │    SRE 引擎          │  │  │
│  │  └──────────────┘ └─────────────┘ └──────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 角色 → CLI 引擎映射

| 角色 | CLI 引擎 | 理由 | Hermes Profile 职责 |
|------|----------|------|-------------------|
| **PM** | `claude -p` | 需求分析、技术发现、澄清对话 | 组装上下文、管理对话历史、解析输出、创建 Kanban 任务 |
| **Researcher** | `claude -p` | 技术调研、web search、方案对比 | 传入调研主题、解析技术方案文档 |
| **Implementer** | `codex exec`（默认）/ `claude -p`（可切换） | 编码、TDD、worktree 管理；Codex 编码能力更强，但可配置切换 | 传入任务 + 验收标准、解析 handoff metadata |
| **Reviewer** | `claude -p` | 代码审查、安全分析（只读） | 传入变更文件列表、解析 findings |
| **QA-Tester** | `claude -p` | 功能验收、测试执行 | 传入需求文档 + 测试计划、解析测试结果 |
| **DevOps** | `codex exec`（默认）/ `claude -p`（可切换） | 部署脚本、CI/CD | 传入部署配置、解析部署报告 |
| **SRE-Observer** | `claude -p` | 根因分析、日志阅读 | 传入故障上下文、解析根因报告 |
| **Orchestrator** | 无（规则驱动） | 状态机路由，不需要 LLM 推理 | 纯规则引擎，按路由表派发 |

---

## 4. Profile 配置

每个 Profile 的 `config.yaml` 新增 `engine` 字段：

```yaml
# pm/config.yaml
model: kimi-coding          # 轻量模型，只做路由和编排
engine:
  cli: claude               # 外部 CLI 引擎
  mode: -p                  # 执行模式
  flags: "--output-format json"
  fallback: null            # 降级引擎（可选）
toolsets:
  enabled: [terminal, kanban, clarify, memory, file_read]
  disabled: [code_execution, delegation]
```

```yaml
# implementer/config.yaml
model: kimi-coding
engine:
  cli: codex                # 默认用 codex
  mode: exec
  flags: "--full-auto --json"
  fallback: claude          # codex 不可用时降级到 claude -p
toolsets:
  enabled: [terminal, file, code_execution, memory, kanban]
  disabled: [delegation, messaging]
```

```yaml
# reviewer/config.yaml
model: kimi-coding
engine:
  cli: claude
  mode: -p
  flags: "--output-format json --allowedTools 'Read,Glob,Grep'"
  fallback: null
toolsets:
  enabled: [file_read, kanban_read, kanban_block, kanban_complete, clarify]
  disabled: [terminal, code_execution, delegation, messaging]
```

---

## 5. 统一协议设计

### 5.1 Request Envelope（Hermes Profile → CLI 引擎）

```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm | researcher | implementer | reviewer | qa-tester | devops | sre-observer",
  "task_type": "clarification | technical_discovery | feasibility_check | requirement_doc | implementation | review | testing | deployment | root_cause_analysis",
  "correlation_id": "{role}-call-{project}-{task_id}-{turn}",
  "turn": 1,
  "project_workspace": "/data/projects/{project}",
  "task_id": "t_xxx",
  "task_body": "...",
  "conversation_history": [],
  "handoff_from_parent": {},
  "instructions": {
    "role": "...",
    "goal": "...",
    "constraints": ["..."],
    "output_format": "structured_json"
  }
}
```

### 5.2 Response Envelope（CLI 引擎 → Hermes Profile）

每个角色的 Response schema 不同，但统一包含 `status` 和 `next_action` 字段。`correlation_id` 只用于日志追踪，不承担 session resume 语义。

```json
{
  "protocol": "hermes-role-engine/v1",
  "correlation_id": "...",
  "status": "...",
  "turn": 1,
  "role_specific_payload": {},
  "next_action": "continue | wait_for_user | create_tasks | create_research_task | block | complete | defer_to_human",
  "deferred_tool_use": null,
  "conversation_context": []
}
```

### 5.3 各角色的 status 枚举

| 角色 | 可能的 status 值 |
|------|-----------------|
| **PM** | `question`, `needs_research`, `requirement_ready`, `feasibility_issue` |
| **Researcher** | `research_complete`, `needs_poc`, `recommendation` |
| **Implementer** | `task_complete`, `needs_decision`, `blocked`, `test_failed` |
| **Reviewer** | `approved`, `findings`, `rejected` |
| **QA-Tester** | `pass`, `fail`, `blocked` |
| **DevOps** | `deploy_complete`, `deploy_failed`, `needs_approval` |
| **SRE-Observer** | `root_cause_report` |

---

## 6. PM 引擎详细设计

### 6.1 PM 引擎的生命周期

```
claude -p PM 引擎的完整生命周期：
  Phase 1: 技术发现 + 需求澄清（多轮）
  Phase 2: 生成需求文档
  Phase 3: 任务拆解（基于需求文档）
```

三阶段属于同一个 PM 引擎逻辑流程，但实现上是多次无状态调用；连续性完全由 Hermes Profile 维护的上下文累积保证。

### 6.2 PM 引擎的 Request 示例（第 1 轮）

```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm",
  "task_type": "clarification",
  "correlation_id": "pm-call-alpha-t42-1",
  "turn": 1,
  "project_workspace": "/data/projects/alpha",
  "task_id": "t_42",
  "task_body": "用户反馈每次重启浏览器都要重新登录",
  "conversation_history": [],
  "handoff_from_parent": null,
  "instructions": {
    "role": "PM",
    "goal": "澄清需求，直到无歧义",
    "constraints": [
      "一次只问一个问题",
      "每个问题必须有推荐标签 + 大白话理由",
      "所有判断必须有代码证据（文件:行号）",
      "不要做架构决策",
      "技术发现由你自己完成（读 AGENTS.md、代码结构）"
    ],
    "output_format": "structured_json"
  }
}
```

### 6.3 PM 引擎的 Response 示例（澄清问题）

```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm",
  "status": "question",
  "correlation_id": "pm-call-alpha-t42-1",
  "turn": 1,
  "analysis": {
    "technical_findings": [
      "当前使用 session-based 认证（src/routes/users.rs:45-72）",
      "无 auth 中间件（src/middleware/mod.rs:8-15）",
      "无 JWT 依赖（Cargo.toml 无 jsonwebtoken）"
    ],
    "feasibility": "可行，但需要引入 JWT 库",
    "risks": ["RS256 vs HS256 选型待定"]
  },
  "question": {
    "id": "q_1",
    "text": "核心目标是什么？",
    "options": [
      {"label": "7天免登录", "reason": "用户体验最佳，行业标准", "recommended": true},
      {"label": "30天免登录", "reason": "安全性更高", "recommended": false},
      {"label": "自定义", "reason": "特殊安全要求", "recommended": false}
    ],
    "other_allowed": true
  },
  "next_action": "wait_for_user"
}
```

### 6.4 PM 引擎的 Response 示例（需求就绪 + 任务拆解）

```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm",
  "status": "requirement_ready",
  "correlation_id": "pm-call-alpha-t42-11",
  "turn": 11,
  "requirement_doc": {
    "title": "JWT 认证模块需求文档",
    "summary": "将 session-based 认证替换为 JWT token 认证，支持 7 天免登录",
    "acceptance_criteria": [
      "有效凭证返回 200 + JWT token",
      "无效凭证返回 401",
      "过期 token 返回 Expired 错误",
      "支持 token 静默刷新"
    ],
    "tech_stack_decisions": [
      {"decision": "RS256", "reason": "支持密钥轮换"}
    ],
    "scope": {
      "in": ["登录接口", "注册接口", "token 刷新"],
      "out": ["第三方登录", "密码重置"]
    },
    "evidence_chain": [
      {"file": "src/routes/users.rs:45", "finding": "当前 session-based 实现"}
    ]
  },
  "tasks": [
    {
      "id": "T1",
      "title": "实现 JWT 认证模块",
      "assignee": "implementer",
      "workspace": "worktree",
      "body": "实现登录/注册/刷新接口，使用 RS256",
      "acceptance_criteria": ["有效凭证返回 200 + token", "无效凭证返回 401"],
      "parents": [],
      "needs_research": false,
      "expected_duration_max": "60min"
    },
    {
      "id": "T2",
      "title": "编写认证模块测试",
      "assignee": "implementer",
      "workspace": "worktree",
      "body": "单元测试 + 集成测试",
      "parents": ["T1"],
      "needs_research": false,
      "expected_duration_max": "30min"
    },
    {
      "id": "T3",
      "title": "审查认证模块代码",
      "assignee": "reviewer",
      "workspace": "inherit",
      "body": "安全性、代码规范、错误处理",
      "parents": ["T1"],
      "needs_research": false,
      "expected_duration_max": "15min"
    }
  ],
  "research_needed": null,
  "next_action": "create_kanban_tasks"
}
```

### 6.5 PM 引擎的 Response 示例（需要 Research）

```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm",
  "status": "needs_research",
  "correlation_id": "pm-call-alpha-t42-5",
  "turn": 5,
  "research": {
    "topic": "JWT 签名方案选型（RS256 vs HS256）",
    "scope": "Rust 生态 JWT 库对比",
    "questions": [
      "jsonwebtoken vs jwt-simple 哪个更成熟？",
      "RS256 的性能开销是否可接受？",
      "密钥轮换的最佳实践是什么？"
    ],
    "needs_poc": true,
    "poc_scope": "验证 RS256 签名性能和密钥轮换流程"
  },
  "tasks": [],
  "next_action": "create_research_task"
}
```

---

## 7. 多轮对话管理

### 7.1 方案选择：上下文累积（无状态）

每次调用 `claude -p` 时传入完整对话历史，CLI 引擎完全无状态。

**优点：** 不依赖 session 持久化机制，最可靠
**缺点：** token 随轮次线性增长（需求澄清通常不超过 15 轮，总量可控）

### 7.2 对话历史存储

对话历史存储在 Kanban task metadata 的 `pm_clarification_history` 字段；`kanban_comment()` 仅用于人类可读审计，不作为恢复真相源：

```json
{
  "pm_clarification_history": [
    {
      "turn": 1,
      "question": "核心目标是什么？",
      "options": ["7天免登录", "30天免登录", "自定义"],
      "user_answer": "7天免登录",
      "timestamp": "2026-05-11T10:30:00Z"
    },
    {
      "turn": 2,
      "question": "用户群体？",
      "options": ["外部客户", "内部员工", "全部"],
      "user_answer": "外部客户",
      "timestamp": "2026-05-11T10:35:00Z"
    }
  ]
}
```

### 7.3 两阶段任务拆解

- **无技术不确定性** → PM 引擎直接拆解任务（`status: "requirement_ready"` 包含 `tasks`）
- **有技术不确定性** → PM 引擎先输出 `status: "needs_research"`，Hermes PM 创建 Research 任务，Research 完成后再调用一次 PM 引擎做正式拆解

---

## 8. 错误处理

| 场景 | 症状 | 处理方式 |
|------|------|---------|
| CLI 引擎超时 | 进程挂起 > 300 秒 | kill → retry 1 次 → kanban_block(reason='engine-timeout') |
| CLI 引擎崩溃 | exit code ≠ 0 | retry 1 次 → kanban_block(reason='engine-crash') |
| 输出格式错误 | JSON 解析失败 | log raw output → kanban_block(reason='engine-parse-error') |
| API 限流 | 429 错误 | backoff 60s → retry → kanban_block(reason='engine-rate-limit') |
| 澄清超限 | 超过 15 轮仍在提问 | 强制生成 requirement_ready，用已有信息拼接需求文档 |

核心原则：**所有无法自动恢复的错误都升级为 kanban_block，由用户决定下一步。**

---

## 9. 三层纵深风险拦截

```
┌─────────────────────────────────────────────────────┐
│  第 1 层：CLI 引擎工具白名单                          │
│  claude -p --allowedTools 'Read,Glob,Grep'           │
│  → 从源头限制引擎能做什么                              │
├─────────────────────────────────────────────────────┤
│  第 2 层：Hermes Plugin `pre_tool_call` hook          │
│  → 拦截 terminal() 中的高风险命令                      │
│  → pattern: "git push --force" → L3 block            │
├─────────────────────────────────────────────────────┤
│  第 3 层：SOUL.md 软约束                              │
│  → "不要执行 rm -rf"（LLM 级别，可被绕过）            │
└─────────────────────────────────────────────────────┘
```

### 9.1 各角色工具白名单

| 角色 | CLI | 工具白名单 | 说明 |
|------|-----|-----------|------|
| **PM** | claude | `Read,Glob,Grep,Bash` | 需要读代码和执行基本命令 |
| **Researcher** | claude | `Read,Glob,Grep,Bash,WebFetch,WebSearch` | 需要 web 调研 |
| **Implementer** | codex | `--full-auto`（全工具） | 编码需要完整工具链 |
| **Reviewer** | claude | `Read,Glob,Grep`（严格只读） | 只读审查 |
| **QA-Tester** | claude | `Read,Glob,Grep,Bash` | 需要执行测试 |
| **DevOps** | codex | `--full-auto` | 部署需要完整工具链 |
| **SRE-Observer** | claude | `Read,Glob,Grep,Bash` | 需要读日志和执行诊断命令 |

### 9.2 Orchestrator 特殊处理

Orchestrator 不使用外部 CLI 引擎，它是纯规则驱动的状态机路由。Hermes 的轻量 LLM 只用于理解自然语言指令，所有路由决策基于预定义的路由表。

---

## 10. 与 Phase 19 原设计的关系

本文档是 Phase 19 DESIGN.md 的架构补充，不是替代。以下 Phase 19 机制保持不变：

| Phase 19 机制 | 与外部 CLI 引擎的关系 |
|--------------|---------------------|
| **Kanban 任务管理** | CLI 引擎的输出通过 Hermes Profile 写入 Kanban |
| **Dispatcher 派发** | Dispatcher 派发 Hermes Profile 进程，Profile 内部调用 CLI 引擎 |
| **Risk Policy Engine** | 第 2 层拦截，在 Hermes 层拦截 terminal() 调用 |
| **Backpressure（R5）** | Dispatcher 控制 spawn 频率，与 CLI 引擎无关 |
| **SRE-Observer** | 读取 CLI 引擎的执行日志做根因分析 |
| **Self-evolution** | CLI 引擎的经验通过 Hermes Profile 写入 Memory |
| **Observability Plugin** | 采集 terminal() 调用链，包含 CLI 引擎的执行 |
| **Session Resume** | 不使用（采用上下文累积模式） |

---

## 11. 设计决策记录

| # | 决策项 | 结论 | 理由 |
|---|--------|------|------|
| D1 | 架构模式 | Hermes 轻量 LLM 做路由编排 + 外部 CLI 做实际思考 | 关注点分离，各取所长 |
| D2 | 协议格式 | JSON Request/Response Envelope over stdin/stdout | 机器可解析，结构化输出 |
| D3 | 上下文管理 | 完整累积（CLI 引擎无状态） | 最可靠，不依赖 session 机制 |
| D4 | 对话存储 | Kanban task metadata | 与 Handoff 机制一致，下游可读 |
| D5 | 技术发现 | CLI 引擎自己做 | 简化 Hermes PM 职责 |
| D6 | 任务拆解 | 同一个 PM 引擎完成 | PM 引擎已有完整上下文 |
| D7 | Research 分支 | 有技术不确定性 → 先 Research → 再拆解 | 避免盲目拆解 |
| D8 | 错误处理 | 重试 → 降级 → kanban_block | 所有不可恢复错误升级用户 |
| D9 | 统一模式 | 所有角色都用外部 CLI 引擎 | 架构一致性 |
| D10 | CLI 选择 | 可配置，Implementer/DevOps 默认 codex，其他默认 claude | Codex 编码能力更强，但可切换 |
| D11 | 风险拦截 | CLI 白名单 + Hermes Plugin hook + SOUL.md 三层 | 纵深防御 |
| D12 | Orchestrator | 不使用外部 CLI 引擎，纯规则驱动 | 路由不需要 LLM 推理 |
