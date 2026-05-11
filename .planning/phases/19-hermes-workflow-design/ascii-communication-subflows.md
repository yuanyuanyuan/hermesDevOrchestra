## 三、实时通信子流程（§5）

> **架构说明（2026-05-11 更新）：** 本文档中的通信流程已更新为"外部 CLI 引擎"模式。
> - Worker 是 Hermes Profile 进程（轻量编排层），通过 JSON 协议委托给外部 CLI 引擎
> - `--resume <session-id>` 机制被**上下文累积模式**替代（每次传入完整对话历史，CLI 引擎无状态）
> - 详见 [`EXTERNAL-CLI-ENGINE.md`](./EXTERNAL-CLI-ENGINE.md) §7

> **两层通信模型：**
> - **Layer 1 — Hermes Profile ↔ Kanban**：任务状态流转（block/unblock、task 创建/完成）
> - **Layer 2 — Hermes Profile ↔ CLI 引擎**：JSON Request/Response Envelope（工具调用委托、上下文累积）

> 📎 **相关叙事文档**：
> - 实时问答 → [`workflow-phase-04-testing-review.md`](./workflow-phase-04-testing-review.md) — Step 4.10 Jacky 收到 block 通知并决策
> - 人与 Agent 沟通 → [`workflow-appendix-human-reactions.md`](./workflow-appendix-human-reactions.md) — 人的真实反应场景
>
> **能力来源说明：** `kanban_block()`/`kanban_complete()`、`AskUserQuestion`、PreToolUse hook + defer 机制属于 `[Hermes 官方]` 或 Claude Code 原生能力。`kanban_block` reason 前缀（如 `reviewer-needed:`）触发自动创建 Reviewer 子任务属于 `[Phase 19 增量]`。defer 的原始返回会先由 adapter 规整为 `hermes-role-engine/v1` Response Envelope。

---

### 实时问答流程（Kanban Block + Defer）

当 Worker 遇到技术疑问时，有两条路径：

**路径 A：Implementer 主动 block（主流程）**

```
   ┌─────────────────────────────────────────────────────────────────┐
   │                     Kanban Board (SQLite)                        │
   │  ┌─────────────────────────────────────────────────────────┐    │
   │  │  Task T1 (blocked)                                      │    │
   │  │  ───────────────────────────────────────────────────    │    │
   │  │  status: blocked                                        │    │
   │  │  reason: "reviewer-needed: 用 RS256 还是 HS256?"        │    │
   │  │  block_time: 2026-05-10T10:00:00Z                       │    │
   │  └─────────────────────────────────────────────────────────┘    │
   │                              │                                  │
   │  ┌───────────────────────────┼─────────────────────────────┐    │
   │  │                           ▼                             │    │
   │  │  Task T1-rev (ready→running)                            │    │
   │  │  ───────────────────────────────────────────────────    │    │
   │  │  title: "审查: T1 技术决策"                              │    │
   │  │  assignee: reviewer                                     │    │
   │  │  body: "T1 需要决策: 用 RS256 还是 HS256?"               │    │
   │  │  priority: high  ← 自动高优先级                         │    │
   │  └─────────────────────────────────────────────────────────┘    │
   │                              │                                  │
   │                              ▼                                  │
   │  ┌─────────────────────────────────────────────────────────┐    │
   │  │  Task T1-rev (done)                                     │    │
   │  │  ───────────────────────────────────────────────────    │    │
   │  │  summary: "建议用 RS256"                                 │    │
   │  │  metadata:                                              │    │
   │  │  { "decision": "RS256", "reason": "支持 key rotation" } │    │
   │  └─────────────────────────────────────────────────────────┘    │
   │                              │                                  │
   │                              ▼                                  │
   │  ┌─────────────────────────────────────────────────────────┐    │
   │  │  Task T1 (unblocked)                                    │    │
   │  │  ───────────────────────────────────────────────────    │    │
   │  │  status: ready → running                                │    │
   │  │  metadata.decision: "RS256"  ← 决策写入                 │    │
   │  └─────────────────────────────────────────────────────────┘    │
   └─────────────────────────────────────────────────────────────────┘

        时序图:
        Implementer          Dispatcher          Reviewer
             │                   │                  │
             │ ① block()         │                  │
             │ "reviewer-needed" │                  │
             │──────────────────►│                  │
             │                   │ ② 检测前缀        │
             │                   │ 创建 reviewer task│
             │                   │─────────────────►│
             │                   │                  │ ③ 分析并
             │                   │                  │    complete()
             │                   │◄─────────────────│
             │                   │ ④ unblock +     │
             │                   │    写入决策       │
             │◄──────────────────│                  │
             │ ⑤ 读取 handoff    │                  │
             │    继续执行        │                  │
             │                   │                  │
```

**大白话：** A 遇到问题了填一张"求助工单"（kanban_block），系统自动派 B 来处理，处理完把结论写回工单，A 看到后继续干活。消息不会丢，有记录可查。

---

**路径 B：CLI 引擎 AskUserQuestion → defer → 上下文累积（兜底）**

当 CLI 引擎运行时自行调用 `AskUserQuestion`（Implementer 未遵守 block 指令）：

> **关键变化（2026-05-11）：** 原 `--resume <session-id>` 机制已替换为**上下文累积模式**。
> CLI 引擎无状态，每次调用都通过 Request Envelope 传入完整对话历史。
> Profile 从上一次 Response Envelope 中提取对话上下文，追加新消息后重新发起调用。

```
        时序图:
        Profile (编排层)     CLI 引擎 (无状态)      Dispatcher
             │                   │                  │
             │ ① 发送 Request    │                  │
             │ Envelope          │                  │
             │ (含完整对话历史)   │                  │
             │──────────────────►│                  │
             │                   │                  │
             │ ② 返回 Response   │                  │
             │ Envelope          │                  │
             │ status: deferred  │                  │
             │ next_action:      │                  │
             │ defer_to_human    │                  │
             │◄──────────────────│                  │
             │                   │                  │
             │ ③ 读取            │                  │
             │ deferred_tool_use │                  │
             │ + 提取对话上下文   │                  │
             │ 写入 Kanban       │                  │
             │──────────────────────────────────────►│
             │                   │                  │
             │                   │                  │ ④ 路由给 Reviewer
             │                   │                  │    获取回答
             │                   │                  │
             │ ⑤ 读取回答        │                  │
             │◄──────────────────────────────────────│
             │                   │                  │
             │ ⑥ 构造新 Request  │                  │
             │ Envelope          │                  │
             │ = 旧对话历史      │                  │
             │ + 用户回答        │                  │
             │──────────────────►│                  │
             │                   │                  │
             │ ⑦ CLI 引擎        │                  │
             │ 以 allow +        │                  │
             │ answers 继续      │                  │
             │◄──────────────────│                  │
             │                   │                  │
             │ 继续执行           │                  │
```

> **上下文累积示意：**
> ```
> 调用 1: Request{ history: [user_msg_1, assistant_msg_1, ...] }
>         Response{ status: "deferred", next_action: "defer_to_human", conversation_context: [...] }
>
> 调用 2: Request{ history: [user_msg_1, assistant_msg_1, ..., deferred_answer] }
>         Response{ status: "task_complete", next_action: "continue", result: "..." }
> ```
> Profile 负责维护和累积对话历史；CLI 引擎每次都是全新调用，不保留任何状态。

defer 场景的标准化 Response Envelope 示例：
```json
{
  "protocol": "hermes-role-engine/v1",
  "status": "deferred",
  "next_action": "defer_to_human",
  "deferred_tool_use": {
    "id": "toolu_01abc",
    "name": "AskUserQuestion",
    "input": {
      "questions": [{
        "question": "用 RS256 还是 HS256?",
        "header": "JWT算法",
        "options": [{"label": "RS256"}, {"label": "HS256"}],
        "multiSelect": false
      }]
    }
  },
  "conversation_context": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

> **注意：** 原始 CLI/SDK 返回如果是 `stop_reason: "tool_deferred"`，必须先由 adapter 映射成上面的标准化 Response Envelope。
> `conversation_context` 是下一次调用的唯一恢复输入；不再依赖 `session_id` 进行会话恢复。

**大白话：** 工人 A（CLI 引擎）写代码时犹豫了，返回一个"暂停+问题"响应。Profile 层把问题转给专家 B，拿到答案后，把"之前的全部对话 + 答案"打包成新请求，重新调用 CLI 引擎。CLI 引擎每次都从头开始，但因为收到了完整历史，所以能无缝继续。全程不用 tmux，不用 --resume。

---
