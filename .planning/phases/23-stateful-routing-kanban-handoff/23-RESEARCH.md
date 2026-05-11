# Phase 23 Research: Stateful Routing & Kanban Handoff

**Phase:** 23 — Stateful Routing & Kanban Handoff  
**Date:** 2026-05-11  
**Status:** Complete

## Research Questions

1. Phase 23 应该直接依赖 Hermes 官方 Kanban 的哪些能力，而不是继续沿用旧文件总线语义？
2. 在已锁定“`status + parents` 为主、metadata 轻扩展”为前提下，最小可执行路由合同应该长什么样？
3. 现有 `pm` / `implementer` / `reviewer` 的 `hermes-role-engine/v1` 输出，如何映射到 Kanban-native 的 create / block / complete / resume 流？
4. `researcher` 与 `qa-tester` 尚未在 Phase 22 闭合完整 role-engine contract 的情况下，Phase 23 应该怎样保持范围克制？
5. 当前仓库里哪条脚本链路最适合作为 Phase 23 的落点，避免平行再造一个第二调度器？

## Findings

### 1. Hermes 官方 Kanban 已经提供了 Phase 23 所需的核心 substrate：状态机、依赖链、runs、handoff metadata 和 per-board 隔离

官方 Kanban 文档当前明确给出：

- task status 是 `triage | todo | ready | running | blocked | done | archived`
- `task_links` 负责 parent → child 依赖，dispatcher 会在所有 parents `done` 后自动把 `todo` 提升为 `ready`
- worker 通过 `kanban_show` / `kanban_complete` / `kanban_block` / `kanban_comment` 等 toolset 驱动任务，而不是 shell 调 `hermes kanban`
- `task_runs` 是一任务多尝试的真实承载面，summary 与 metadata 都挂在 run 上
- downstream children 读取 parent 的 summary + metadata 做 handoff
- board 是硬隔离边界，worker 通过 `HERMES_KANBAN_BOARD` 只能看到自己的 board

这意味着 Phase 23 不需要自己再实现：

- 第二套任务状态枚举
- 第二套 parent promotion 逻辑
- 第二套 handoff 存储
- 第二套 per-project routing queue

最小正确做法是：在 Hermes 官方 Kanban 之上补一层**轻量 routing contract**，把本地业务态压缩到少量 metadata，而不是再复制一遍 scheduler。  
[CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban]

### 2. 用户锁定的“轻量扩展”与 Hermes 官方模型是兼容的，但要明确：comments 可以参与上下文，不可作为恢复真相源

官方文档当前写得很直白：

- worker 重启时会读完整 comment thread
- 但真正结构化 handoff 还是 `kanban_complete(summary=..., metadata=...)`
- `summary` 是人类 closeout，`metadata` 是机器可消费 handoff
- attempt history 和 structured handoff 都在 `task_runs`

用户在 Phase 22 和 Phase 23 里锁定的是：

- comment 只做关键转折审计摘要
- metadata 才是恢复和路由真相源
- handoff 采用最小结构化摘要 + 文件引用

这两者并不冲突。正确落法应是：

1. comment 仍然保留，但只在关键转折写一条短摘要  
2. Orchestrator / worker 恢复逻辑绝不依赖 comment parse  
3. canonical 恢复字段落在 `workflow_state`、`routing_reason`、`resume_target`、`handoff_ref` + run summary/metadata

这样既不违背 Hermes worker 默认会读 comments 的行为，也不会把 comment 升格成业务真相源。  
[CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban]
[VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
[VERIFIED: .planning/phases/23-stateful-routing-kanban-handoff/23-CONTEXT.md]

### 3. Phase 23 最合适的 routing contract 不是“完整 workflow template”，而是一个 metadata-first 的薄层

Hermes 官方 docs 已经为 v2 预留了 `workflow_template_id` / `current_step_key` 字段，但 v1 kernel 还不基于它们路由。  
[CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban]

用户当前锁定的目标也不是做模板引擎，而是：

- `status + parents` 为主
- 四字段最小 metadata 集：
  - `workflow_state`
  - `routing_reason`
  - `resume_target`
  - `handoff_ref`
- 轻结构化 block reason 前缀
- 代码为主、文档镜像

因此 Phase 23 的本地 contract 应保持在这个层级：

- `workflow_state`：只表达当前 routing checkpoint，而非复制完整任务状态机
- `routing_reason`：记录这次路由/阻塞/派生为何发生
- `resume_target`：说明解阻塞后由谁/哪类任务继续
- `handoff_ref`：指向本次交接的 canonical 产物或摘要

不建议本 phase 提前设计：

- 通用 workflow template DSL
- 独立 YAML routing compiler
- schema-heavy orchestration database
- 泛化的 multi-lane same-project scheduler

这些都比当前 milestone 大。Phase 23 应该只做 MVP 主链路能执行的薄层路由。  
[VERIFIED: .planning/phases/23-stateful-routing-kanban-handoff/23-CONTEXT.md]
[VERIFIED: .planning/ROADMAP.md]

### 4. 现有 `pm` / `implementer` / `reviewer` role-engine contract 已足够支撑第一版 Kanban 路由解释器

Phase 22 已经固定：

- `pm.question -> wait_for_user`
- `pm.needs_research -> create_research_task`
- `pm.requirement_ready -> create_tasks`
- `implementer.task_complete -> complete`
- `implementer.blocked|test_failed -> block`
- `reviewer.approved -> complete`
- `reviewer.findings -> block`

这说明本 phase 最应该做的是“解释器”，不是再发明协议：

| Role | Existing output | Phase 23 action |
|------|------------------|-----------------|
| PM | `wait_for_user` | block 当前 PM 任务，保留 structured history，等用户 unblock 后恢复原任务 |
| PM | `create_research_task` | 创建 `researcher` child task，并把原任务保持在可恢复链上 |
| PM | `create_tasks` | 生成 skeleton task graph，按 parents 串出 implement/review/qa 主链路 |
| Implementer | `block` | block 当前任务，等待用户/上游解阻塞后恢复原任务 |
| Implementer | `complete` | 创建 `reviewer` child task，并写入最小 handoff |
| Reviewer | `approved` | 若命中 QA 强制条件则派生 QA；否则推进完成 |
| Reviewer | `findings` | 派生新的 implementer follow-up task，保持 review findings 作为 handoff |

也就是说，Phase 23 不需要扩 Phase 22 的 shared `next_action` enum；只需要把它落成 routing rules。  
[VERIFIED: docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md]
[VERIFIED: docs/orchestra/hermes/role-engine-protocol/v1/roles/pm.md]
[VERIFIED: docs/orchestra/hermes/role-engine-protocol/v1/roles/implementer.md]
[VERIFIED: docs/orchestra/hermes/role-engine-protocol/v1/roles/reviewer.md]

### 5. `researcher` 和 `qa-tester` 在本 phase 应作为“路由层能力”接入，不应把 scope 扩成完整 role-engine protocol 扩张

Phase 22 明确只闭合了 `pm` / `implementer` / `reviewer` 三个角色的可执行协议面。  
[VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]

但 Phase 23 的 roadmap 目标确实要求：

- PM 能派生 `researcher`
- 审核通过后能条件性进入 `qa-tester`

最稳妥的范围控制是：

1. 在 routing 层承认 `researcher` 和 `qa-tester` 两类 task node
2. 为它们定义 task graph insertion rule、handoff contract 和 unblock/complete expectation
3. 不在本 phase 把它们扩成新的完整 `role-engine-protocol/v1/roles/*.md` 闭环，除非执行时发现没有最小 contract 无法落地

换句话说，本 phase 只需要解决“怎么把任务交给 researcher/qa，以及交完后怎么回来”，不是把全部角色协议一次性收完。

### 6. 当前仓库里最合适的执行落点是“保留 `orch-bus-loop` 入口，内部切换到 Kanban-native routing”，而不是新增第二个并行调度器

代码面现状：

- `orch-start` 仍负责启动长期运行的编排 watcher
- `orch-bus-loop` 当前承载了任务派发、问题转发、决策恢复、审计落点等旧逻辑
- `orch-status` / `README.md` / `WORKFLOW.md` 仍围绕这条入口解释系统

如果本 phase 新增一个全新的 `orch-kanban-loop` 并同时保留 `orch-bus-loop`，会引入两套入口：

- 文档和运维面同时存在“旧 loop / 新 loop”
- Phase 23 结束后仍需要一次重命名或切换
- 测试矩阵也会翻倍

更好的最小变更策略是：

1. 保留 `docs/orchestra/scripts/bin/orch-bus-loop` 这个入口名
2. 在内部把它改造成 Kanban-native router / compatibility bridge
3. 如有必要，再把纯 routing 辅助逻辑下沉到 `docs/orchestra/scripts/lib/` 中的独立 helper
4. 让 `orch-start` / `orch-status` / `README.md` 跟着这条唯一入口演进

这样可以避免本 phase 再造第二调度器，同时保持对现有启动脚本和测试入口的兼容。  
[VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop]
[VERIFIED: docs/orchestra/scripts/bin/orch-start]
[VERIFIED: docs/orchestra/README.md]

### 7. QA 和 Research 的条件应先写成纯函数式规则，再让 orchestration 脚本消费，避免把判断散在多处

用户已经把两类条件钉死：

- Research 三类触发
- QA 三类强制条件

这非常适合在本 phase 做成一组本地 helper 规则：

- `orch_task_needs_research(...)`
- `orch_task_needs_qa(...)`
- `orch_parse_block_reason_prefix(...)`
- `orch_build_resume_target(...)`

无论这些 helper 最终放在 bash、Python 还是混合脚本里，原则都应是：

- 路由规则在一处集中定义
- `orch-bus-loop` / `orch-status` / tests 共用同一套判定
- 文档只镜像它们，不手抄第二份

这比把判断散在 PM task builder、review follow-up、status 输出和 README 文案里稳得多。

### 8. 最低验证面不是“全角色 E2E 全跑通”，而是“主链路上的 graph creation / block-resume / review handoff / conditional QA insertion 都可脚本化验证”

Phase 23 当前最合理的验证分层：

1. **Static contract checks**
   - docs 中出现四字段最小集
   - block prefix 词表固定
   - route action 与 `next_action` 映射固定

2. **Routing smoke tests**
   - PM `needs_research` -> 创建 researcher child
   - PM `requirement_ready` -> 创建 skeleton graph
   - implementer `blocked` -> 原任务 block 后 resume
   - implementer `complete` -> reviewer child + handoff
   - reviewer `approved` + QA 条件命中 -> QA child
   - reviewer `findings` -> implementer follow-up child

3. **Aggregate compatibility**
   - 现有 role-engine protocol tests 不回归
   - 现有 project isolation 假设不回归

这比在本 phase 强行追求 researcher / qa / orchestrator / pm 全 CLI E2E 更符合“最小可执行路由层”的目标。

## Recommended Implementation

1. 在现有 orchestration runtime 上定义一份 **Kanban-native routing contract**，把 Phase 23 锁定的 metadata 字段、block prefix 和 role transitions 固定下来。
2. 在 `docs/orchestra/scripts/lib/` 增加或扩展一组 routing helpers，集中处理：
   - `next_action` -> Kanban action 映射
   - research / QA 条件判断
   - `routing_reason` / `resume_target` / `handoff_ref` 规范化
3. 保留 `orch-bus-loop` 作为唯一公开入口，但把内部逻辑从文件总线轮询改造成 Kanban-driven routing / compatibility bridge。
4. 更新 `orch-start` / `orch-status` / `README.md` / `WORKFLOW.md`，把 canonical 运行路径切到 Kanban routing，而不是继续把文件总线描述成主路径。
5. 新增至少两类测试：
   - `test-kanban-routing.sh`
   - `test-kanban-handoff.sh`
6. 保持 scope 克制：本 phase 不做 risk hook、不做 timeout cleanup、不做 observability persistence、不扩 full seven-role role-engine protocol。

## Validation Architecture

### Static Contract Checks

执行阶段至少应 grep/断言：

- `workflow_state`
- `routing_reason`
- `resume_target`
- `handoff_ref`
- `needs-user:`
- `needs-review:`
- `research-required:`

同时检查文档和代码里对 QA / Research 条件的表述一致。

### Routing Smoke Checks

执行阶段推荐新增脚本验证以下案例：

```text
PM question -> block current PM task, wait for user, resume same task
PM needs_research -> create researcher child with parent link
PM requirement_ready -> create skeleton graph with explicit parents
Implementer blocked -> preserve original task identity across unblock
Implementer complete -> create reviewer child and handoff
Reviewer approved + qa-needed -> create qa-tester child
Reviewer findings -> create implementer follow-up child with review handoff
```

### Aggregate Gate

Phase 23 结束前仍应至少跑：

```bash
rtk docs/orchestra/scripts/tests/test-role-engine-protocol.sh
rtk docs/orchestra/scripts/tests/test-project-isolation.sh
rtk make test
```

并且在 verification 中明确区分：

- 新增 Kanban routing 测试失败：属于本 phase 回归
- 已知 `upstream-status` mismatch：沿用 inherited external blocker

## Risks

| Risk | Mitigation |
|------|------------|
| 把 `workflow_state` 做成第二套完整状态机。 | 严格限制 metadata 为四字段最小集，只表达 routing checkpoint。 |
| 继续依赖 comment parse 做恢复。 | 所有恢复逻辑只读 run summary/metadata + normalized fields。 |
| 为了接入 QA/Research，把 Phase 23 扩成 full role-engine protocol 扩张。 | `researcher` / `qa-tester` 只作为 routing-level task nodes 接入。 |
| 新增 `orch-kanban-loop` 造成双入口长期并存。 | 保留 `orch-bus-loop` 入口名，内部迁移为 Kanban router。 |
| reviewer findings 回流 implementer 时打破“原任务恢复优先”原则。 | 将“原任务恢复优先”限定为同角色解阻塞；跨角色回流一律显式 child/follow-up。 |
| QA / Research 条件判断散落多处，后续难维护。 | 提前集中为共享 helper，文档只镜像代码。 |

## Research Complete

Phase 23 的最佳执行路径已经明确：

- 站在 Hermes 官方 Kanban 的 `status + parents + task_runs + board isolation` substrate 上实现
- 只补一层薄的 routing metadata contract
- 复用 Phase 22 的 `next_action` 协议解释器，不扩 protocol 面
- 保留 `orch-bus-loop` 公开入口，内部切到 Kanban-native routing
- 用 graph creation / block-resume / reviewer handoff / conditional QA insertion 作为最小验证闭环
