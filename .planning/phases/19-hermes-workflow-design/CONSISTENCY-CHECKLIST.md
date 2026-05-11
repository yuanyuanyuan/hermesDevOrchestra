---
date: 2026-05-11
topic: hermes-workflow-design
status: working-checklist
---

# Phase 19 文档一致性清单

## 目标

本清单用于维护 `.planning/phases/19-hermes-workflow-design/` 目录下 25 个顶层文件的一致性。

当前统一架构基线：

- **Hermes 做宿主 / 编排层**
- **外部 CLI 引擎做可替换推理/执行层**
- **Hermes Profile 持有业务状态**
- **CLI 引擎按 `hermes-role-engine/v1` 无状态调用**
- **恢复依赖 Kanban metadata 的结构化状态，不依赖 `--resume`**

---

## 文件分层

### A. 规范源文件

这些文件是“定义真相”的源头。后续改架构时，必须优先修改它们。

1. [REQUIREMENTS.md](/data/hermes/.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md)
2. [DESIGN.md](/data/hermes/.planning/phases/19-hermes-workflow-design/DESIGN.md)
3. [EXTERNAL-CLI-ENGINE.md](/data/hermes/.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md)

### B. 索引文件

这些文件主要负责导航，不应自行发明新机制。

1. [WORKFLOW-EXPLAINED.md](/data/hermes/.planning/phases/19-hermes-workflow-design/WORKFLOW-EXPLAINED.md)
2. [WORKFLOW-ASCII-DIAGRAMS.md](/data/hermes/.planning/phases/19-hermes-workflow-design/WORKFLOW-ASCII-DIAGRAMS.md)

### C. 主流程叙事文件

这些文件应严格消费规范源，不应与规范源冲突。

1. [workflow-phase-01-requirements.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-phase-01-requirements.md)
2. [workflow-phase-02-orchestrator.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-phase-02-orchestrator.md)
3. [workflow-phase-03-implementation.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-phase-03-implementation.md)
4. [workflow-phase-04-testing-review.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-phase-04-testing-review.md)
5. [workflow-phase-05-fix-evolution.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-phase-05-fix-evolution.md)
6. [workflow-phase-06-completion.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-phase-06-completion.md)

### D. ASCII 子系统图

这些文件是“图形化投影”，应反映规范源，不应引入新协议。

1. [ascii-core-flows.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-core-flows.md)
2. [ascii-communication-subflows.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-communication-subflows.md)
3. [ascii-decision-matrix.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-decision-matrix.md)
4. [ascii-kanban-subflows.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-kanban-subflows.md)
5. [ascii-multi-project.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-multi-project.md)
6. [ascii-observability.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-observability.md)
7. [ascii-overview.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-overview.md)
8. [ascii-self-evolution.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-self-evolution.md)
9. [ascii-end-to-end.md](/data/hermes/.planning/phases/19-hermes-workflow-design/ascii-end-to-end.md)

### E. 叙事附录

这些文件用于解释、说服、举例，允许更口语化，但不允许修改规范边界。

1. [workflow-appendix-decisions.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-appendix-decisions.md)
2. [workflow-appendix-failure-modes.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-appendix-failure-modes.md)
3. [workflow-appendix-human-reactions.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-appendix-human-reactions.md)
4. [workflow-appendix-roles.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-appendix-roles.md)
5. [workflow-appendix-timeline.md](/data/hermes/.planning/phases/19-hermes-workflow-design/workflow-appendix-timeline.md)

---

## 修改顺序

后续涉及架构变更时，按这个顺序改：

1. 先改 `REQUIREMENTS.md`
2. 再改 `DESIGN.md`
3. 如果涉及外部 CLI 协议，再改 `EXTERNAL-CLI-ENGINE.md`
4. 再同步 `WORKFLOW-EXPLAINED.md` 和 `WORKFLOW-ASCII-DIAGRAMS.md`
5. 再同步 6 个 `workflow-phase-*`
6. 再同步相关 `ascii-*`
7. 最后同步 `appendix` 类解释文件

禁止反过来从叙事文件发明新机制，再倒逼规范源跟上。

---

## 必查约束

每次修改后，至少检查下面 10 条：

1. **唯一宿主模型**
   Hermes 是宿主/编排层，不能又被写成“真正做 PM/实现/审查的是 Hermes 内部另一套 agent”。

2. **唯一状态模型**
   业务状态真相源在 Kanban metadata / handoff / task state。
   不能再把 comments、tmux session、CLI session 当恢复真相源。

3. **唯一会话模型**
   外部 CLI 引擎是无状态调用。
   可以提到旧 `--resume` 被替代，但不能把它写回主路径。

4. **唯一协议模型**
   Profile ↔ CLI 引擎统一走 `hermes-role-engine/v1`。
   defer 场景也必须先标准化到这个 envelope，再进 Hermes 流程。

5. **唯一 authority**
   `clarify`、`kanban_block`、`kanban_complete`、memory 写入、skill 创建结论，归 Hermes Profile。
   外部 CLI 引擎不直接拥有 authority。

6. **PM 澄清恢复规则**
   多轮澄清历史必须以 `pm_clarification_history` 这类结构化字段为主。
   comments 只做人类审计摘要。

7. **Reviewer 只读边界**
   Reviewer 的 Hermes toolset 和 CLI `--allowedTools` 都必须只读。
   不能在示例里悄悄把 `terminal` 或写能力重新开回来。

8. **文件总线 / tmux 状态**
   允许作为历史迁移背景出现。
   不允许作为当前 phase 的兼容回退主路径。

9. **索引文件不发明机制**
   `WORKFLOW-EXPLAINED.md`、`WORKFLOW-ASCII-DIAGRAMS.md` 只能摘要，不应新增规范细节。

10. **ASCII 图和正文同源**
   图里如果出现新的字段名、状态名、恢复步骤，正文里必须已有对应定义。

---

## 快速扫描词

每次大改后，建议全文扫这些词，确认它们不是以“当前主路径”存在：

```text
--resume
session_id
tool_deferred
stop_reason
tmux
文件总线
读取 task comments
comments 保存进度
同一个 `claude -p` 实例
兼容回退
```

说明：

- 出现这些词不一定错
- 但如果不是在“旧机制已替代”或“历史迁移说明”上下文里，大概率就有漂移

---

## 最小 Review 流程

每次文档改完，至少做下面 4 步：

1. `rg` 扫关键词残留
2. 回看 `REQUIREMENTS.md` 的新增/修改 requirement 是否被 `DESIGN.md` 落实
3. 回看 `workflow-phase-01` 和 `ascii-communication-subflows` 是否仍与协议一致
4. 回看 `ascii-overview.md` / `workflow-appendix-timeline.md` 是否还在传播旧心智

---

## 当前建议

如果后面继续演进这套架构，优先遵守这条原则：

**宁可增加 adapter 层的显式协议，也不要让 Hermes 与具体 CLI/SDK 的隐式返回格式深度耦合。**

这样后面要换 `claude -p`、Claude SDK、Codex CLI，甚至别的 engine，文档和实现都不会散掉。
