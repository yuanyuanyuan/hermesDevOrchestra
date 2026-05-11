# Phase 23: Stateful Routing & Kanban Handoff - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-11
**Phase:** 23-stateful-routing-kanban-handoff
**Areas discussed:** 路由状态模型, 任务图生成方式, block-resume 交接方式, handoff 上下文形状, 评论与审计密度, blocked reason 结构约束, Research 派生触发条件, Review / QA 插入策略, 路由规则落点, workflow_state 最小字段集, QA 强制条件清单, Research 触发清单具体项

---

## 路由状态模型

| Option | Description | Selected |
|--------|-------------|----------|
| 轻量扩展 | 以 Hermes 原生 `status + parents` 为主，只新增少量 `workflow_state` metadata | ✓ |
| 纯原生 | 完全只用 `status + parents`，不加额外 workflow metadata | |
| 显式状态机 | 引入完整 `workflow_state` 枚举，路由主要看 metadata | |

**User's choice:** 轻量扩展
**Notes:** 用户接受以 Hermes 原生状态为主，只做最小量 routing metadata 补充。

---

## 任务图生成方式

| Option | Description | Selected |
|--------|-------------|----------|
| 骨架先行，增量展开 | PM 先创建主干任务图，只放当前确定节点；后续按结果补 children 和 `parents` | ✓ |
| 一次性完整拆解 | PM 在需求就绪后一次性创建完整任务树 | |
| 最小单任务推进 | 先只创建一个 research 或 implement 任务，后续完全靠运行时继续派生 | |

**User's choice:** 骨架先行，增量展开
**Notes:** 用户接受先搭骨架，再按 research / review / QA 结果扩图。

---

## block-resume 交接方式

| Option | Description | Selected |
|--------|-------------|----------|
| 原任务恢复为主 | `kanban_block` 解开后优先恢复原任务继续；只有角色真的变化时才新建下游任务 | ✓ |
| 一律派生新任务 | 每次 block 后都由 Orchestrator 新建后续任务接管，原任务不再恢复 | |
| 混合但偏派生 | 默认新建后续任务，只有少数短暂停顿才恢复原任务 | |

**User's choice:** 原任务恢复为主
**Notes:** 用户接受“解阻塞优先恢复原任务，换角色才派生”的模式。

---

## handoff 上下文形状

| Option | Description | Selected |
|--------|-------------|----------|
| 最小结构化摘要 + 文件引用 | 只传结构化摘要、关键决策、状态字段、产物路径；大内容放文件，不内联 metadata | ✓ |
| 富结构化 payload | 在 metadata 里直接放更完整的分析、检查结果、长文本摘要 | |
| 摘要最小化 | 只放极少字段，几乎所有内容都靠外部文件自行回读 | |

**User's choice:** 最小结构化摘要 + 文件引用
**Notes:** 用户倾向让 metadata 保持可恢复所需最小集，不膨胀成正文仓库。

---

## 评论与审计密度

| Option | Description | Selected |
|--------|-------------|----------|
| 关键转折记录 | 只在创建任务图、进入 blocked、解除 blocked、角色切换、完成交付时写 `kanban_comment` | ✓ |
| 全量过程记录 | 每次路由判断、状态变化、恢复、重试都写 comment | |
| 极简审计 | 只在最终完成或失败时写 comment，平时主要靠 metadata | |

**User's choice:** 关键转折记录
**Notes:** 用户接受 comment 只记录主链路转折，不做噪音日志。

---

## blocked reason 结构约束

| Option | Description | Selected |
|--------|-------------|----------|
| 轻结构化前缀 | 保留可读文本，但要求固定前缀，如 `needs-user:`、`needs-review:`、`research-required:` | ✓ |
| 完全结构化 | 不靠 reason 文本，主要靠独立 metadata 字段表达 block 类型和恢复条件 | |
| 自由文本 | reason 只写人话，Orchestrator 用宽松关键词解析 | |

**User's choice:** 轻结构化前缀
**Notes:** 用户接受 parseable 前缀 + 人类可读尾部的折中方案。

---

## Research 派生触发条件

| Option | Description | Selected |
|--------|-------------|----------|
| 显式触发清单 | 命中固定条件才必须先派生 `researcher` | ✓ |
| PM 自由判断 | 由 PM 根据上下文自主决定是否派生 research | |
| 保守优先 research | 只要有一点不确定性就先派生 research | |

**User's choice:** 显式触发清单
**Notes:** 用户不希望让 PM 临场自由发挥 research 触发标准。

---

## Review / QA 插入策略

| Option | Description | Selected |
|--------|-------------|----------|
| Review 强制，QA 选择性强制 | 代码实现任务默认都过 reviewer；只有高验收风险任务强制进 QA | ✓ |
| Review/QA 全强制 | 只要进入实现链路，全部都必须经过 reviewer 和 qa | |
| 按任务声明决定 | 由 PM 在建图时逐个标记是否需要 review / qa | |

**User's choice:** Review 强制，QA 选择性强制
**Notes:** 用户接受 review 作为默认门，QA 按风险和用户感知面插入。

---

## 路由规则落点

| Option | Description | Selected |
|--------|-------------|----------|
| 代码为主，文档镜像 | 路由表以脚本/配置中的可执行规则为准，文档只做人类可读镜像说明 | ✓ |
| 文档为主，代码实现 | 先把路由表写在设计/规格文档里，代码按文档手动保持一致 | |
| 独立配置为主 | 把路由规则抽成单独 YAML/JSON，代码和文档都从它派生 | |

**User's choice:** 代码为主，文档镜像
**Notes:** 用户接受可执行规则优先，文档只做镜像，不反客为主。

---

## workflow_state 最小字段集

| Option | Description | Selected |
|--------|-------------|----------|
| 四字段最小集 | `workflow_state`、`routing_reason`、`resume_target`、`handoff_ref` | ✓ |
| 富字段集 | 再加 `attempt_count`、`last_transition_at`、`origin_task_id`、`expected_next_roles` 等 | |
| 超轻量 | 只保留 `workflow_state`，其他主要靠原生状态和 comment 补足 | |

**User's choice:** 四字段最小集
**Notes:** 用户接受足够支撑 Phase 23 的最小字段集，不把 metadata 做成第二套任务系统。

---

## QA 强制条件清单

| Option | Description | Selected |
|--------|-------------|----------|
| 三类强制条件 | 用户可见行为变更、跨模块/跨边界集成、验收风险高或回归面大 | ✓ |
| 两类强制条件 | 只看用户可见行为变更、跨模块集成 | |
| PM 标记制 | 不固定清单，由 PM 建图时决定是否插入 QA | |

**User's choice:** 三类强制条件
**Notes:** 用户接受把“高验收风险/高回归面”也纳入强制 QA 条件。

---

## Research 触发清单具体项

| Option | Description | Selected |
|--------|-------------|----------|
| 三类触发 | 新技术栈/能力面、影响后续任务图的方案分叉、显式调研/可行性判断要求 | ✓ |
| 两类触发 | 只看新技术栈、显式调研关键词 | |
| 扩大型触发 | 把任何实现不确定性都纳入 | |

**User's choice:** 三类触发
**Notes:** 用户接受 research 只在明确触发条件下插入，不把普通实现不确定性都升级成 research。

---

## the agent's Discretion

- `workflow_state` 的最终枚举值集合
- `routing_reason` 的规范前缀词表
- `resume_target` 的允许值范围

## Deferred Ideas

None — discussion stayed within phase scope.
