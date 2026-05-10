## 三、实时通信子流程（§5）

> 📎 **相关叙事文档**：
> - 实时问答 → [`workflow-phase-04-testing-review.md`](./workflow-phase-04-testing-review.md) — Step 4.10 Jacky 收到 block 通知并决策
> - 人与 Agent 沟通 → [`workflow-appendix-human-reactions.md`](./workflow-appendix-human-reactions.md) — 人的真实反应场景
>
> **能力来源说明：** `kanban_block()`/`kanban_complete()`、`AskUserQuestion`、PreToolUse hook + defer 机制属于 `[Hermes 官方]` 或 Claude Code 原生能力。`kanban_block` reason 前缀（如 `reviewer-needed:`）触发自动创建 Reviewer 子任务属于 `[Phase 19 增量]`。

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

**路径 B：Claude Code AskUserQuestion → defer（兜底）**

当 Claude Code 运行时自行调用 `AskUserQuestion`（Implementer 未遵守 block 指令）：

```
        时序图:
        Worker (claude -p)     PreToolUse Hook      Dispatcher
             │                   │                  │
             │ ① 调用            │                  │
             │ AskUserQuestion   │                  │
             │──────────────────►│                  │
             │                   │ ② 返回 defer     │
             │◄──────────────────│                  │
             │                   │                  │
             │ 进程退出           │                  │
             │ stop_reason:      │                  │
             │ "tool_deferred"   │                  │
             │──────────────────────────────────────►│
             │                   │                  │
             │                   │                  │ ③ 读取
             │                   │                  │ deferred_tool_use
             │                   │                  │ 路由给 Reviewer
             │                   │                  │
             │                   │                  │ ④ --resume 恢复
             │◄──────────────────────────────────────│
             │                   │                  │
             │ ⑤ hook 再次触发   │                  │
             │ 返回 allow +      │                  │
             │    answers        │                  │
             │──────────────────►│                  │
             │                   │                  │
             │ 继续执行           │                  │
```

deferred_tool_use 结构示例：
```json
{
  "stop_reason": "tool_deferred",
  "session_id": "abc123",
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
  }
}
```

**大白话：** 工人 A 写代码时自己犹豫了，系统自动"暂停"A，把问题转给专家 B，拿到答案后"恢复"A 继续干。全程不用 tmux，用 Claude Code 原生机制。

---

