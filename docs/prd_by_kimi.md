<!-- 本文件按用户反馈修订：核心目标是需求/任务自动补全、信息保真、默认自动推进，并以 Get 知识库 qnN4o510、仓库 full debate registry、authority matrix 和当前 Gateway 六阶段实现为依据。 -->

# Hermes Dev Orchestra 产品需求文档

**版本**：v1.2
**日期**：2026-05-26
**项目根目录**：`/data/hermes`
**核心依据**：Get 知识库 `qnN4o510`、`docs/knowledge/qnN4o510-synthesis.md`、`docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`、`config/debate/full/*`、`scripts/lib/orch_gateway.py`

> 说明：本文同时包含目标态需求与 Sprint 分解，当前仓库只实现其中已落地的子集；实现边界以对应 Sprint 计划、ADR 和测试为准。
>
> 当前边界（截至 PR #17 / 2026-06-01）：
> - 已落地并可直接在仓库中验证的内容，以 `scripts/lib/orch_gateway.py`、相关 CLI 脚本、对应 ADR 和测试脚本覆盖的子集为准。
> - 下文中如 Conflict Ledger 持久化/仲裁全流程、完整 rollback API、快速通道自动合并、Low-Risk Override 等描述，除非有对应代码与测试支撑，否则一律视为目标态设计，不代表仓库已经完整实现。
> - 因此，本文任何单个章节都不能单独作为“功能已可用”的证据；是否已落地必须同时回看代码、ADR 和测试。

---

## 1. 产品定位

Hermes Dev Orchestra 是一个 **Kimi-first 的需求补全与 AI 研发编排系统**。

产品存在的根本目的，是在获得一个需求/任务时，自动补齐相关依赖和上下文，降低信息丢失、误解和错误传播，并将任务从接收到实施、测试、验收、沉淀的全过程妥善处理。除非出现危险、偏离、冲突无法解决或关键判断低置信度，系统应尽量不需要人为监督。

```text
用户说目标
  → Kimi 自动补齐上下文、依赖、隐性约束、验收矩阵和执行 prompt
  → Gateway 翻译、校验、投影状态、记录证据与冲突
  → Hermes agents 调度辩论、执行和生命周期
  → Claude/Codex 编码、审查、测试、专项审计
  → Kimi 审计并沉淀经验
```

核心原则：

- 用户只提供目标、约束、线索和必要确认。
- Kimi 负责需求补全、意图转换、任务拆解编排、验收和审计。
- Gateway 负责通信适配、状态权威、证据校验、冲突记录和路由。
- Hermes agents 负责执行框架、多 Agent 生命周期、上下文隔离和任务推进。
- Claude/Codex 负责具体编码、审查、测试和专项审计。

---

## 2. 角色职责与边界

### 2.1 各角色分工匹配度验证

| 角色 | 职责定义 | 知识库设计规范 | 匹配度 |
|------|----------|----------------|--------|
| **用户** | 提供目标、约束、线索，并在例外情况下确认 | 意图驱动范式下，人类不规定“怎么做”，只在危险、偏离、冲突、低置信度时决策 | 完全匹配 |
| **Kimi** | 需求补全 + 编排 + 调度 + 验收 + 审计 | 负责意图转换、依赖补全、验收矩阵、任务拆解、双重验收和经验审计 | 完全匹配 |
| **Gateway** | 翻译适配、状态投影、证据门控、冲突记录 | 负责格式转换、消息路由、依赖/证据投影、风险门控和 Run Projection API | 完全匹配 |
| **Hermes agents** | 下层执行与多 Agent 生命周期管理，可调度 16 支辩论团队 | 负责任务持久化、上下文隔离、依赖发现、工具调用和生命周期推进 | 完全匹配 |
| **Claude/Codex** | 具体审查、编码、测试、专项审计 | 作为底层执行模型，承担具体工程动作和证据产出 | 完全匹配 |

### 2.2 权限边界

| 能力 | Kimi | Gateway | Hermes agents | Claude/Codex | 用户 |
|------|------|---------|---------------|--------------|------|
| 创建 Run | 请求/补全意图 | 校验并执行 | 接收任务 | 无权直接创建 | 提供初始目标 |
| 补全需求 | 负责生成补全包 | 记录补全来源和投影 | 提供执行侧事实 | 可提供审查意见 | 提供线索或纠正 |
| 修改 Kanban 原始状态 | 不允许 | 内部执行 | 通过 Gateway 受控执行 | 不允许 | 不允许 |
| 推进阶段 | 决策输入 | 校验证据并推进 | 输出执行证据 | 输出任务结果 | 仅在高风险/冲突/低置信度时确认 |
| 选择辩论团队 | 请求/审计 | 按策略装配 | 执行辩论 | 作为后端实例参与 | 无需干预 |
| 编码/审查 | 不直接执行常规底层任务 | 分派与校验 | 生命周期管理 | 执行 | 无需干预 |
| L3/L4 高风险审批 | 不可代替人类 | 阻塞并上浮 | 等待授权 | 不允许越权 | 必须审批 |
| 经验沉淀 | 审计并提出建议 | 记录与校验 | 落地配置/规则修改 | 可提供建议 | protected target 需确认 |

Kimi 是补全者和裁决者，不是底层状态写入者。Gateway 是状态和证据门，Hermes agents 是执行框架，Claude/Codex 是被调度的执行模型。

---

## 3. 产品目标

### 3.1 用户目标

用户希望用自然语言交付复杂工程任务，但不想手动管理：

- 需求补全和上下文水合。
- 环境、上下游、代码、测试和发布依赖发现。
- 子任务拆解。
- 多模型选择。
- 评审团队组合。
- 上下文隔离。
- 测试与审查证据。
- 经验沉淀。

### 3.2 系统目标

系统必须做到：

1. 把模糊或不完整目标转换为完整、可执行、可测试、可验收的任务包。
2. 自动补齐环境、上下游、隐性约束、依赖图、验收矩阵和执行 prompt。
3. 在方向和方案阶段先论证，再执行。
4. 通过 16 支辩论团队和 8 种辩论模式降低单模型盲区。
5. 让 Gateway 对所有状态推进做证据校验，并保留冲突、来源和置信度。
6. 支持 Claude/Codex 完成具体编码、审查、测试和特殊审计。
7. 在评审发现问题后当场修复，不把问题留到下一轮。
8. 在最终交付后由 Kimi 审计日志并沉淀流程经验。

### 3.3 非目标

当前产品不追求：

- 让用户直接操作 Hermes Kanban。
- 让 Kimi 绕过 Gateway 改状态。
- 让单个 Claude/Codex 会话承担全流程长上下文。
- 让模拟辩论结果冒充真实强证据。
- 让系统在没有审批时自动修改 protected target。
- 让用户为每个阶段做常规人工监督。
- **无条件服从用户明显错误的决策**（如“明文存密码”、“跳过测试直接上线”）。系统必须客观纠正，提供证据，用户坚持则记录 Override 并上浮审批。

### 3.4 信息保真原则

系统在处理任务时必须区分并保留：

- 用户原始意图。
- 系统补全内容。
- 模型推断内容。
- 已验证事实。
- 未验证假设。
- 冲突信息。

原则如下：

- 任何关键结论都必须附带来源、置信度和验证方式。
- 冲突信息不得静默覆盖，必须进入 Conflict Ledger 或等价证据链。
- 低置信度内容只能作为 warning，不能直接作为完成证据。
- 任务进入执行前必须具备依赖图、验收矩阵和执行 prompt envelope。
- 只有关键缺失、危险变更、无法自动消解的冲突或不可可靠推断的信息才上浮给用户。

### 3.5 Conflict Ledger 数据结构

冲突信息不得静默覆盖，必须进入 Conflict Ledger。Ledger 每条记录必须包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `conflict_id` | string | 全局唯一标识 |
| `run_id` | string | 所属 Run |
| `stage` | string | 发现冲突的阶段（intake / direction_debate / …） |
| `type` | string | 冲突类型：`intent_vs_inference` / `fact_vs_assumption` / `cross_team_conflict` / `dependency_conflict` / `user_override` |
| `sources` | array | 冲突各方的来源引用（含原始文本、文件路径、模型推断标识） |
| `severity` | string | `high` / `medium` / `low` |
| `resolution` | string | 当前处理状态：`open` / `auto_resolved` / `escalated` / `overridden` / `accepted_risk` |
| `resolver` | string | 解决者：`kimi` / `gateway` / `user` / `debate_jury` |
| `resolution_evidence` | string | 解决依据的引用（如工单号、辩论结论 ID） |
| `created_at` | ISO timestamp | 创建时间 |
| `resolved_at` | ISO timestamp | 解决时间（未解决时为 null） |

**消费规则**：
- Gateway 在阶段推进前必须查询当前 Run 的 `open` 状态冲突；存在 `severity=high` 且未解决时，禁止推进。
- 六阶审计必须读取全部冲突记录，评估 resolution 是否合理。

---

## 3.6 Run 状态机与回滚策略

### 状态机定义

Run 除六阶段外，还必须显式管理以下生命周期状态：

```text
created → intake_complete → direction_debate → solution_debate → implementation
→ improvement → global_evaluation → continuous_improvement → closed
```

**异常状态**：`paused`（人工暂停）、`blocked`（等待审批/信息）、`cancelled`（人工取消）、`rollback_requested`（回滚中）。

**阶段流转条件**：

| 当前状态 | 允许转入 | 条件 |
|----------|----------|------|
| created | intake_complete | 需求补全包生成且通过完整性校验（6 类信息、依赖图四维、验收矩阵、prompt envelope 齐全） |
| intake_complete | direction_debate | 无 high severity 冲突，或冲突已 auto_resolved / overridden |
| direction_debate | solution_debate | 《最佳选择报告》verdict ≠ block，且无待确认的高风险/低置信度项 |
| solution_debate | implementation | 《具体实现报告》DAG、写入范围、测试策略齐全，无不可消解冲突 |
| implementation | improvement | 所有子任务完成声明均附带测试+审查证据，write scope 无越界 |
| improvement | global_evaluation | 改进闭环完成（A 类修复复测通过；B/C 类已 blocked 并记录；D 类未超 3 次回归；E 类已裁决） |
| global_evaluation | continuous_improvement | verdict = pass 或 pass_with_warnings（且残余风险未超阈值） |
| continuous_improvement | closed | closeout artifact 已生成，protected target 变更已审批 |
| 任意状态 | paused | 用户显式发起暂停指令 |
| 任意状态 | blocked | Gateway 检测到证据缺失、越权、高风险未审批 |
| paused/blocked | 上一正常状态 | 用户解除暂停 / 审批完成 / 信息补齐 |
| 任意状态（implementation 及之后） | rollback_requested | 用户或系统在 implementation 及之后发现严重缺陷，发起回滚 |

### 回滚策略

**回滚触发条件**：
1. 用户在五阶前明确发起回滚。
2. 五阶 verdict = fail 且用户选择回滚而非重设计。
3. 四阶 D 类回归第 3 次失败后用户选择回滚。
4. 三阶执行中检测到破坏性变更（如删除生产数据、改错核心配置）被 Harness Engine 阻断，系统自动建议回滚。

**回滚范围与执行者**：

| 回滚时机 | 回滚范围 | 执行者 | 说明 |
|----------|----------|--------|------|
| intake_complete 之前 | 仅丢弃补全包 | Gateway | 无代码变更，重新 intake |
| direction/solution debate | 丢弃辩论报告，回到 intake_complete | Gateway | 保留补全包，重新辩论 |
| implementation 中 | 回滚已提交的代码变更（git revert / reset） | Codex（受 Gateway 监督） | 只回滚当前 Run 的 commit，不碰其他 Run |
| improvement 中 | 回滚到 implementation 完成时的基线 | Codex + Gateway | 丢弃所有改进 commit |
| global_evaluation 后 | 回滚到 implementation 基线或接受残余风险 | 用户决策 | 五阶 fail 时默认选项为回滚 |

**回滚不可触碰项**：
- 其他 Run 的代码或状态。
- 已合并到主干且被后续 Run 依赖的变更（此时必须走 hotfix / 新 Run，而非回滚）。
- protected target（CI/CD、权限配置、密钥）。

---

## 4. 需求补全与六阶闭环需求

### 4.0 总览

| 阶段 | 名称 | 产品目标 | 主要输出 |
|------|------|----------|----------|
| 0阶 | 需求补全 | 自动补齐上下文、依赖和验收矩阵 | 《需求补全包》 |
| 一阶 | 方向辩论 | 对齐业务可行性与方向风险 | 《最佳选择报告》 |
| 二阶 | 方案辩论 | 锁定技术实现路径和 DAG | 《具体实现报告》 |
| 三阶 | 具体执行 | 完成编码、测试、审查 | 《任务反馈文档》 |
| 四阶 | 改进实现 | 根据反馈当场修复问题 | 《改进报告》 |
| 五阶 | 全局评估 | 多维度验收并排序风险 | 《整体改进报告》 |
| 六阶 | 持续改进 | 审计日志并沉淀经验 | 《工作流优化建议》 |

当前 Gateway 代码对应的 stage id：

```text
direction_debate
solution_debate
implementation
improvement
global_evaluation
continuous_improvement
```

0阶是六阶段前的 intake/context hydration 层。它可以在实现上接入 run intake、artifact projection 和 decision projection，但在产品需求中必须显式存在。

### 4.1 0阶：需求补全与上下文水合 + 项目接入

**用户故事**：作为用户，我只给出一个不完整的目标，系统应先自动补齐上下文、依赖和验收信息，再进入后续执行。如果是新项目首次使用，系统应先自动探测项目信息并完成接入配置。

**功能需求**：

- **新项目接入**（首次使用）：
  - Kimi 自动探测文件树、依赖文件（`package.json` / `pyproject.toml` / `go.mod` 等）、CI/CD 配置、测试目录结构。
  - 生成《项目探测报告》草稿，展示推测的技术栈、测试命令、部署目标、风险标志（如支付流、PII）。
  - **确认交互设计**：系统以**结构化问卷**形式展示探测结果，每项附带【正确 / 修正】按钮。探测项分为两类：
    - **高置信度项**（语言、框架）：默认勾选“正确”，用户可一键确认全部。
    - **中低置信度项**（数据库、部署目标、风险标志）：需要用户显式确认或填写修正值。
    - 若用户选择“修正”，系统弹出单字段输入框（如数据库从 `PostgreSQL` 改为 `MySQL`），修正后实时更新 profile 预览。
  - 确认流程控制在 **8-12 个问题**、**3-5 分钟**内完成；超过 12 个问题未确认完时，Gateway 自动将剩余项标记为 `unverified_assumption`，不阻塞接入，但写入 project-profile 的 `pending_verification` 列表。
  - 生成 `.hermes/project-profile.yaml`、初始 `AGENTS.md` 和 `SOUL.md`。
- **需求补全**（每次任务）：
  - Kimi 把原始意图拆成目标、非目标、约束、环境、上下游、隐性内容和验收线索。
  - 系统自动生成依赖图、冲突清单、验收矩阵和执行 prompt envelope。
  - Gateway 记录原始输入与补全结果之间的映射，保留来源和置信度。
  - 只有在关键缺失无法可靠推断、存在高风险变更或冲突无法自动消解时，才向用户提问。
  - **输出模式**：支持摘要模式（默认，只展示关键推断摘要 + 确认按钮 + 高风险警示）和详细模式（完整补全包）。用户可在 `project-profile.yaml` 中配置默认模式。
- **用户错误纠正**（每次任务）：
  - 若用户请求包含客观错误（如“明文存密码”、“跳过测试上线”），系统在补全阶段先触发纠正机制。
  - 纠正遵循“客观陈述 + 证据引用 + 替代方案”原则，最多 2 轮。
  - **渐进展开**：第一轮只给极简风险提示 + 替代方案，详细证据默认折叠；第二轮才展示完整证据链（同类历史、规范原文）。
  - 第 2 轮仍坚持则记录为“用户 Override”或上浮 L3/L4 审批。
  - **Override 记录格式**：每次 Override 必须生成不可变记录，字段如下：

| 字段 | 说明 |
|------|------|
| `override_id` | 全局唯一标识 |
| `run_id` | 所属 Run |
| `user_intent_original` | 用户原始请求文本 |
| `correction_rounds` | 纠正轮次详情（每轮的风险提示、替代方案、用户回应） |
| `override_category` | `security_violation` / `process_violation` / `best_practice_deviation` |
| `risk_level` | `L2`（非高风险，记录后继续）/ `L3`（需审批人确认）/ `L4`（需高级审批人+审计） |
| `approver_ref` | 审批人标识（L3/L4 必填） |
| `evidence_refs` | 关联的证据引用（规范原文、历史事故 ID） |
| `status` | `recorded` / `approved` / `rejected` |
| `created_at` | ISO timestamp |

**审批人查询接口**：Gateway 必须暴露按 `risk_level` 和 `status=recorded` 筛选的 Override 待审批列表，审批人可通过 `/orchestra/decisions/approve` 批量处理。

**验收标准**：

- 新项目首次使用时，5 分钟内完成接入配置。
- 生成《需求补全包》。
- 生成可执行的依赖图和验收矩阵。
- 用户错误被识别并纠正，Override 留痕。

### 4.2 一阶：方向辩论

**用户故事**：作为用户，我只输入目标和验收标准，系统应先判断方向是否值得做，而不是直接写代码。

**功能需求**：

- Kimi 必须基于《需求补全包》生成结构化工单。
- **工单数据格式（JSON Schema）**：
  ```json
  {
    "work_order_id": "wo_xxx",
    "run_id": "run_xxx",
    "project_background": { "summary": "string", "relevant_history": ["string"] },
    "goal": { "primary": "string", "measurable_outcome": "string" },
    "non_goals": ["string"],
    "constraints": {
      "hard": [{ "item": "string", "source": "user_original|system_inferred", "confidence": "high|medium|low" }],
      "preference": [{ "item": "string", "source": "user_original", "evaluated_in_debate": true }]
    },
    "acceptance_criteria": [{ "criterion": "string", "test_method": "string", "evidence_type": "string" }],
    "risk_boundary": { "max_acceptable_risk": "L2|L3|L4", "rollback_plan": "string", "failure_strategy": "string" },
    "derived_from_intake_package": "intake_xxx"
  }
  ```
- 工单应包含项目背景、目标、非目标、约束、验收标准、风险边界、失败策略。
- Hermes 必须按任务类型和 `project-profile.yaml` 中的 `debate` 配置选择辩论团队（核心 16 支 + 项目自定义扩展团队）。
- 常规方向决策应优先使用 `dynamic_assembly` + `adversarial_debate`，需要结论时使用 `jury_panel`。
- 若方向结论高置信度、低风险、无冲突，则自动进入二阶；仅在低置信度、冲突或高风险时上浮给用户。
- 若用户在需求中指点实现（如“用 Alembic 做 migration，文件放 `migrations/`”），系统应区分“硬约束”和“用户偏好/实现细节”，前者写入工单，后者在二阶由辩论团队重新评估。

**验收标准**：

- 生成《最佳选择报告》。
- 报告明确方向可行性、核心风险、是否继续。
- 高风险、低置信度或冲突未消解时才请求用户确认。
- 用户错误决策已被纠正或记录 Override。

### 4.3 二阶：方案辩论

**用户故事**：作为用户，我希望系统在动手前先比较技术路线，避免错误实现路径造成返工。

**功能需求**：

- Kimi 基于方向报告发起方案辩论。
- Hermes 根据争议程度选择：
  - `adversarial_debate`：路线争议大。
  - `parallel_debate`：多个维度独立评审。
  - `risk_priority_matrix`：风险排序。
  - `cross_team_conflict_detector`：团队意见冲突检测。
- Kimi 将方案拆成 DAG，并交给 Gateway/Hermes 管理。
- **DAG 数据格式（JSON Schema）**：
  ```json
  {
    "dag_id": "dag_xxx",
    "run_id": "run_xxx",
    "nodes": [
      {
        "task_id": "t1",
        "name": "string",
        "worker_type": "codex|claude",
        "input_refs": ["artifact_id_or_file_path"],
        "output_refs": ["artifact_id_or_file_path"],
        "write_scope": ["glob_pattern_or_file_path"],
        "test_strategy": "string",
        "acceptance_criteria_refs": ["ac_id"],
        "estimated_duration_seconds": 120,
        "merge_strategy": "fast_forward|merge_commit|squash_then_merge|sequential_rebase|manual"
      }
    ],
    "edges": [
      { "from": "t1", "to": "t2", "dependency_type": "data|control|test" }
    ],
    "parallel_groups": [["t2", "t3"]],
    "rollback_checkpoint": "commit_sha_or_tag"
  }
  ```
- **调度规则**：Gateway 在解析 DAG 时必须检测循环依赖；存在环时阻塞并返回 `invalid_dag_cycle` 错误，要求 Kimi 重生成。
- `delegate_task` 上下文必须声明：当 Kimi 是上层裁决者时，下层独立审查不得使用同源 Kimi 模型替代独立 Claude/Codex 审计。
- **同源隔离检测机制**：Gateway 在创建 worker session 时，必须校验 session 的 `model_source` 字段。若当前 Run 的上层裁决者为 `kimi`，则任何标记为 `review`、`audit`、`cross_check` 的 worker session 的 `model_source` 不得为 `kimi`（必须为 `claude` 或 `codex` 独立实例）。违规时 Gateway 拒绝创建 session，返回 `source_isolation_violation`，并自动重新分派给合规的 worker。
- 若方案结论明确且依赖矩阵完整，则自动进入三阶；仅在不可消解冲突或高风险时上浮用户。

**验收标准**：

- 生成《具体实现报告》。
- 报告包含技术路线、任务拆分、依赖关系、并行边界、测试策略。
- 每个执行任务有明确验收标准和证据要求。

### 4.4 三阶：具体执行

**用户故事**：作为用户，我希望系统自动完成实现，但所有修改都能追踪、隔离和审查。

**功能需求**：

- Kimi 通过 Gateway/Kanban 分派任务，不直接写项目状态。
- Hermes agents 管理子代理生命周期，可使用多级代理委托。
- 每个代理应有独立 workspace 或等价上下文隔离。
- Gateway 必须校验写入范围、证据引用、测试结果和审查输出。
- Claude/Codex 按角色执行编码、测试、审查、专项审计。
- **执行期间必须向用户推送进度摘要（执行心跳）**：每 30 秒或每完成一个子任务推送一次，包括当前阶段、已完成/进行中任务、预计剩余时间、阻塞状态。用户可随时查询实时快照而不中断执行。

**验收标准**：

- 生成《任务反馈文档》。
- 文档记录修改文件、测试结果、审查结论、待改进问题。
- 没有证据的完成声明不得推进阶段。

### 4.5 四阶：改进实现

**用户故事**：作为用户，我不希望评审意见只停留在报告里，系统应立即修复能修的问题。

**功能需求**：

- Kimi 从任务反馈中提取问题，并对照验收矩阵判断缺口，对问题分类：
  - **A. 纯代码级问题**（lint、typo、边界条件、空指针）：Codex 自动修复 → 复测 → 闭环。
  - **B. 需要额外信息才能修复**：上浮问用户 / 查工单 / 查历史；信息不足则 Gateway 标记 blocked。
  - **C. 修复超出当前 Run 范围**（如需改基础设施、其他服务、新增依赖）：Gateway 阻塞，生成子任务 / 新 Run，走审批。
  - **D. 修复后引入新问题（回归）**：进入二次四阶，最多允许 3 次循环；第 3 次仍失败则上浮用户决策（接受 / 回滚 / 重设计）。
  - **E. 评审意见存在争议**（Claude 说有问题，Codex 不认同）：触发 mini-debate，2 轮未达成一致则 Kimi 裁决或上浮用户。

**A-E 分类自动判定规则**：

| 类别 | 判定条件（满足任一即可） | 自动判定信号 |
|------|------------------------|-------------|
| A | 问题可被 lint / formatter / 单测定位；修复只影响单文件且不改接口契约；Codex 置信度 ≥ 高 | lint 失败行、类型错误、单测断言失败行 |
| B | 问题涉及业务逻辑但验收矩阵未覆盖该分支；或需要用户确认设计意图 | 验收矩阵无对应条目、涉及外部 API 行为不确定 |
| C | 修复需新增依赖（package.json/go.mod 变更）、改其他服务接口、改基础设施配置 | 依赖文件变更、跨服务调用、infra-as-code 文件 |
| D | 复测时发现新问题，且新问题与本次修复直接相关 | 回归测试失败、新 lint 错误出现在修改文件 |
| E | 两个独立 worker（Claude vs Codex，或不同 Codex 实例）对同一问题给出相反 verdict，且各自有证据 | verdict 不一致率、证据引用互相矛盾 |

**Mini-debate 触发与执行规范**：
- **触发条件**：仅 E 类争议触发；A/B/C/D 类不得使用 mini-debate 替代明确处理路径。
- **参与者**：争议双方原 worker 实例 + 1 支独立 `meta_review` 团队（由 Gateway 按 `dynamic_assembly` 选出，不得与争议方同源）。
- **执行流程**：
  1. 第 1 轮：双方各提交 1 条结构化论据（问题定位 + 证据引用 + 建议修复）。
  2. 第 2 轮：双方针对对方论据进行反驳，`meta_review` 团队给出独立评估。
  3. 若 2 轮后 verdict 仍不一致（如 2:1 或 1:1:1），由 Kimi 裁决；Kimi 置信度 < 高时上浮用户。
- **时间约束**：mini-debate 每轮不超过 60 秒，总时长不超过 3 分钟；超时由 Gateway 强制标记为 `timeout_escalated`，转 Kimi 裁决。
- Hermes 调度 Claude/Codex 修复可自动处理的问题。
- 修改后必须重新测试和复审。
- 如果问题超出原范围，Gateway 必须阻塞并要求 Kimi 或用户决策。

**验收标准**：

- 生成《改进报告》。
- 报告包含问题分类、修复路径、复测证据、残余风险、blocked 项及原因。
- 回归循环不超过 3 次。
- 阻塞项必须明确上浮原因。

### 4.6 五阶：全局评估

**用户故事**：作为用户，我希望系统在交付前做全局评估，而不只是局部测试通过。

**功能需求**：

- Kimi 最大程度调度辩论团队并行评估。
- 至少覆盖业务目标、补全正确性、安全合规、质量、性能、可维护性、文档、可观测性。
- 推荐模式为 `jury_panel`、`meta_review`、`cross_team_conflict_detector`。
- 若 verdict 为 fail/block，或 pass_with_warnings 但残余风险超出阈值，Gateway 必须阻塞等待决策；其他情况默认自动通过并通知用户。
- **`pass_with_warnings` 主动摘要通知**：verdict 为 `pass_with_warnings` 时，系统自动通过，但必须在通知中显式摘要残余风险（按高/中/低排序），确保用户知情权。用户可配置通知级别（`none` / `summary` / `full`）。

**8 维评估评分细则**：

每个维度评分采用三档制：`pass` / `warn` / `fail`，并附带置信度（高/中/低）。

| 维度 | 通过标准（pass） | 警告标准（warn） | 失败标准（fail） | 权重 |
|------|-----------------|-----------------|-----------------|------|
| 业务目标 | 原始需求 100% 映射到实现，验收矩阵全部覆盖 | 验收矩阵覆盖 ≥ 80%，缺失项为非核心功能 | 核心功能未实现或验收矩阵覆盖 < 80% | 一票否决 |
| 补全正确性 | 系统补全的依赖、约束、验收标准与代码事实一致，无误导 | 补全存在轻微偏差（如路径推断错误但已修正） | 补全严重误导执行（如遗漏支付流安全要求） | 一票否决 |
| 安全合规 | 无高危漏洞；静态扫描、依赖扫描通过；无 secrets 泄露 | 存在中危漏洞或合规缺口，但有缓解措施 | 存在高危漏洞、secrets 泄露或未满足的合规硬要求 | 一票否决 |
| 质量 | 单测覆盖率 ≥ 项目阈值；lint 无错误；无已知 bug | 覆盖率略低于阈值（-5% 以内）或存在低优先级 lint warn | 覆盖率显著低于阈值（-10% 以上）或存在阻塞级 bug | 1.0 |
| 性能 | 满足 project-profile 中的 SLO（响应时间、吞吐量） | 接近 SLO 边界（偏差 ≤ 10%） | 超出 SLO 边界（偏差 > 10%）或未做性能验证 | 1.0 |
| 可维护性 | 代码复杂度、重复率符合项目规范；无技术债引入 | 复杂度略超阈值或引入可控技术债 | 严重过度设计或重复率超标，显著增加维护成本 | 0.8 |
| 文档 | API 文档、变更日志、README 已更新，与代码一致 | 文档存在遗漏但核心信息已覆盖 | 关键文档缺失或与代码严重不一致 | 0.8 |
| 可观测性 | 日志、指标、追踪已按规范添加；告警规则已更新 | 观测项存在遗漏但核心路径已覆盖 | 无日志、无指标或告警规则缺失导致盲区 | 0.8 |

**综合 verdict 生成规则**：
1. 任一**一票否决维度**为 `fail` → 整体 `fail`。
2. 无 `fail`，但存在 ≥ 2 个非一票否决维度为 `warn` → `pass_with_warnings`。
3. 无 `fail`，且 `warn` 维度 < 2 → `pass`。
4. 若存在未消解冲突或审批未完成 → `block`。

**Pass_with_warnings 风险阈值定义**：

残余风险按以下量化标准判断是否"超出阈值"：

| 风险等级 | 定义 | 阈值 |
|----------|------|------|
| 高 | 可能导致生产事故、数据丢失、安全事件、合规处罚 | **零容忍**：存在即阻塞（除非用户显式 Override 并审批） |
| 中 | 可能导致功能缺陷、性能退化、维护困难，但无即时灾难性后果 | 允许 ≤ 1 个中风险项；> 1 个则视为超阈值，阻塞等待决策 |
| 低 | 边缘场景问题、文档笔误、日志格式不统一 | 允许 ≤ 3 个低风险项；> 3 个则升级为 `pass_with_warnings` 并通知 |

**通知级别默认策略**：
- 默认级别：`summary`（仅展示高/中风险摘要，最多 3 条）。
- `none`：仅通知 verdict，不展示残余风险（仅允许在内部 staging 环境使用，生产环境禁止）。
- `full`：展示全部 8 维评估详情、残余风险清单、改进建议。用户可在 `project-profile.yaml` 中配置：
  ```yaml
  evaluation:
    warning_notification: summary   # none / summary / full
    default_for_production: summary # 生产环境强制最低 summary，禁止 none
  ```

**验收标准**：

- 生成《整体改进报告》或 `global_evaluation_report`。
- 报告明确通过/警告/失败/阻塞。
- 最终验收前必须有完整证据链和验收矩阵覆盖结果。

### 4.7 六阶：持续改进

**用户故事**：作为用户，我希望系统把本轮经验沉淀为下一轮更好的工作流，而不是每次从零开始。

**功能需求**：

- Kimi 作为独立审计员读取完整审计输入。完整标准定义如下：

| 输入类别 | 必须包含的文件/记录 | 完整性校验规则 |
|----------|---------------------|---------------|
| 原始需求与补全 | `intake_package.json`、原始用户输入文本 | 6 类信息齐全，依赖图四维覆盖 |
| 执行日志 | `events.jsonl` 中本 Run 的全部事件 | 事件时间戳连续，无 > 60 秒的空洞（除非人工暂停） |
| 工具调用 | 所有 worker session 的 `tool_calls.json` | 每个 tool_call 必须有 `request` + `response` + `status` |
| 错误栈 | `errors.jsonl` 中本 Run 的全部错误记录 | 含错误类型、堆栈、影响范围、是否已修复 |
| 审查记录 | 所有 `review_verdict.json`、`qa_verdict.json` | 每个 verdict 含 reviewer、结论、证据引用 |
| Gateway 状态 | `run.json`、`tasks.json`、`decisions.json`、`audit.jsonl` | 状态流转与事件日志一致，无未授权的阶段跳跃 |
| Closeout artifacts | `global_evaluation_report.json`、`improvement_report.json` | 与验收矩阵逐项映射，无遗漏 |

- 若任一类别缺失或完整性校验失败，Gateway 拒绝进入 `continuous_improvement` 阶段，返回 `audit_input_incomplete`，要求补齐。
- Kimi 生成《工作流优化建议》。
- Hermes agents 可把建议落地到 AGENTS.md、SOUL.md、配置或流程文档。
- protected target 变更必须要求人工审批。
- 对成功与失败经验都要保留来源、置信度和适用边界，避免把偶然成功误写成通用规则。

**Protected Target 完整判定清单**：

以下变更无论大小，均视为 protected target，强制走 Kimi review + Human Approval：

| 类别 | 具体范围 | 审批级别 |
|------|----------|----------|
| 根规则 | `AGENTS.md` 根级规则、`SOUL.md` 核心决策偏好、`.hermes/project-profile.yaml` 的 `protected_targets` 自身 | L4 |
| CI/CD | `.github/workflows/`、Jenkinsfile、GitLab CI、ArgoCD 配置、发布流水线脚本 | L4 |
| 权限与密钥 | IAM 策略、RBAC 配置、API key / secret 的增删改、数据库访问凭证 | L4 |
| 基础设施 | `k8s/production/`、`terraform/`、网络策略、DNS 配置、负载均衡规则 | L4 |
| 风险策略 | `config/debate/full/*` 核心注册表、`config/performance/slo-policy.json`、degradation/evolution 策略 | L3 |
| Worker/Gateway 配置 | `orch_gateway.py` 路由规则、worker session 超时策略、authority matrix 本身 | L3 |
| 支付与合规 | 支付网关配置、PCI-DSS 相关文件、GDPR/CCPA 数据处理规则 | L4 |

**Self-evolution Queue 工作机制**：

六阶产出的《工作流优化建议》不直接修改配置，而是进入 `self-evolution queue`，按以下状态流转：

```text
proposed → kimi_reviewed → human_approved → applied → verified
         → rejected
         → auto_applied (仅限非 protected target 且置信度=高、无冲突)
```

| 状态 | 进入条件 | 处理者 |
|------|----------|--------|
| `proposed` | 六阶审计自动生成建议 | Kimi |
| `kimi_reviewed` | Kimi 审查建议的合理性、来源可靠性、适用边界 | Kimi |
| `human_approved` | 涉及 protected target 或 Kimi 置信度 ≤ 中时必须人工审批 | 项目 Owner / 安全负责人 |
| `applied` | Hermes agents 将建议写入目标文件（AGENTS.md / SOUL.md / 配置） | Codex（受 Gateway 监督） |
| `verified` | 下一 Run 执行后，Gateway 验证该建议是否改善了目标指标 | Gateway |
| `rejected` | Kimi 或人工判定建议不合理、适用边界不清、或风险 > 收益 | Kimi / Human |
| `auto_applied` | 非 protected target、置信度=高、与现有规则无冲突、同类建议已有 3 次以上成功验证 | Gateway 自动执行 |

**队列管理规则**：
- queue 持久化为 `config/evolution/self-evolution-review-queue.json`。
- 同一类建议（如"增加前端 i18n 检查"）被 reject 后，30 天内不得再次 auto_apply，必须人工审批。
- 六阶审计必须输出 queue 状态摘要：已落地 N 条、待审 M 条、拒绝 P 条。

**验收标准**：

- 生成 closeout 与 improvement proposal artifacts。
- 明确哪些建议已落地，哪些进入待审队列。
- 最终成果交付给用户或自动归档通知用户。

---

## 5. 关键产物需求

### 5.1 需求补全包

必须包含：

- 原始用户意图。
- 系统补全内容。
- 已验证事实。
- 未验证假设。
- 冲突清单。
- 风险边界。
- 依赖图。
- 验收矩阵。
- 执行 prompt envelope。

### 5.2 依赖图

必须覆盖：

- 环境依赖：工具链、版本、密钥、服务、权限。
- 上游依赖：API、数据源、配置、外部服务、前置任务。
- 下游影响：调用方、UI、测试、部署、文档、监控。
- 代码依赖：模块、接口、schema、迁移、构建链路。

### 5.3 验收矩阵

每条需求必须映射到：

- 验收标准。
- 测试类型。
- 证据 artifact。
- 责任 worker。
- 当前 verdict。
- 残余风险。

### 5.4 执行 Prompt Envelope

必须包含：

- 目标和非目标。
- 背景与上下文。
- 依赖图摘要。
- 写入范围。
- 禁止操作。
- 验收矩阵。
- 测试策略。
- 失败策略。

---

## 6. 辩论系统需求

### 6.1 16 支 canonical 团队

full-system 团队注册表以 `qnN4o510` 为权威，当前仓库目标配置位于 `config/debate/full/teams.json`。

canonical team id：

```text
security
compliance
data_engineering
devops_sre
frontend
ai_feature
scalability_arch
chaos_engineering
platform
privacy_ethics
oss_compliance
observability
business
documentation
api_design
i18n_l10n
```

旧版或 MVP 配置中的 `product`、`architecture`、`ux`、`testing`、`release` 等只能作为兼容别名或评审维度，不是 full-system canonical id。

### 6.2 扩展团队规范

项目可在核心 16 支基础上自定义扩展团队：

```json
{
  "custom_teams": [
    {
      "id": "payment_compliance",
      "extends": "compliance",
      "focus": ["PCI-DSS", "3DS", "chargeback"],
      "prompt_injection": "你专注于支付合规。审查时必须检查……"
    }
  ]
}
```

**规则**：
1. 必须声明 `extends`，继承核心团队基线。
2. `id` 不可与核心团队冲突。
3. `prompt_injection` 不得覆盖核心安全红线。
4. 多项目复用可提升到组织级。

**核心安全红线（不可被 prompt_injection 覆盖）**：

以下规则为系统级安全底线，任何 custom team 的 `prompt_injection` 若试图覆盖、弱化或绕过这些规则，必须在注册时被 Gateway 拒绝：

| 红线编号 | 规则内容 | 校验方式 |
|----------|----------|----------|
| SR-1 | 不得允许明文存储密码、密钥、token、信用卡号、CVV | 关键词匹配 + 语义检测 |
| SR-2 | 不得允许跳过安全扫描（SAST/DAST/依赖扫描）直接上线 | 模式匹配：如 "跳过测试"、"绕过扫描" |
| SR-3 | 不得允许在生产环境直接修改数据或执行未经审核的 DDL | 环境关键词 + 操作类型匹配 |
| SR-4 | 不得允许降低日志级别以隐藏错误 or 删除审计日志 | 日志配置变更的语义检测 |
| SR-5 | 不得允许放宽身份认证或授权策略（如关闭 MFA、扩大 RBAC 范围） | 认证/授权配置模式匹配 |
| SR-6 | 不得允许引入已知 CVE 的高危依赖或禁用依赖扫描 | 依赖文件变更 + CVE 数据库比对 |
| SR-7 | 不得允许绕过 Gateway 直接修改 Kanban 状态或 worker 输出 | 系统架构级硬编码校验 |

**Legacy Alias 映射规范**：

旧版或 MVP 中的非 canonical team id 必须通过显式映射表 `config/debate/full/alias-mapping.json` 兼容，映射表示例：

```json
{
  "aliases": {
    "product": { "maps_to": "business", "reason": "product 评审维度已并入 business", "deprecated": true },
    "architecture": { "maps_to": "scalability_arch", "reason": "架构评审由 scalability_arch 覆盖", "deprecated": true },
    "ux": { "maps_to": "frontend", "reason": "UX 评审由 frontend 覆盖", "deprecated": true },
    "testing": { "maps_to": null, "reason": "testing 不是独立评审团队，而是各团队内的验收维度", "deprecated": true },
    "release": { "maps_to": "devops_sre", "reason": "发布流程由 devops_sre 覆盖", "deprecated": true },
    "red_team": { "maps_to": "security", "reason": "red_team 是 security 的别名", "deprecated": false },
    "risk_review": { "maps_to": "risk_priority_matrix", "reason": "risk_review 是模式而非团队", "deprecated": true },
    "consensus": { "maps_to": "jury_panel", "reason": "consensus 是 jury_panel 的别名", "deprecated": false }
  }
}
```

- `deprecated: true` 的别名在运行时必须打印迁移警告，下一 major version 中移除。
- `maps_to: null` 表示该别名无对应 canonical id，使用时报错并提示正确团队。
- 映射表变更必须经过 L3 审批（属于 debate registry 配置变更）。

### 6.3 8 种 canonical 模式

full-system 模式注册表以 `qnN4o510` 为权威，当前仓库目标配置位于 `config/debate/full/modes.json`。

canonical mode id：

```text
sequential_review
parallel_debate
adversarial_debate
jury_panel
dynamic_assembly
meta_review
risk_priority_matrix
cross_team_conflict_detector
```

用户原描述中的 `riskprioritymatrix` 应落为 canonical id `risk_priority_matrix`。

### 6.4 组合策略

| 场景 | 推荐模式 |
|------|----------|
| 不确定该找哪些团队 | `dynamic_assembly` |
| 技术路线争议大 | `adversarial_debate` |
| 多维度独立快速评估 | `parallel_debate` |
| 需要链式交接评审 | `sequential_review` |
| 需要明确投票结论 | `jury_panel` |
| 怀疑首轮评审有遗漏 | `meta_review` |
| 需要定量排序风险 | `risk_priority_matrix` |
| 团队结论互相冲突 | `cross_team_conflict_detector` |

---

## 7. 通道分级需求

### 7.1 三层通道

| 通道 | 跳过阶段 | 审查深度 | 适用场景 |
|------|---------|---------|---------|
| **快速通道** | 一阶、二阶 | light | 纯文案、单文件 typo、配置值调参 |
| **轻量通道** | 一阶、二阶 | standard | 简单逻辑修改、无风险 UI 调整、文档更新 |
| **标准通道** | 无 | deep | 其他所有任务 |

### 7.2 快速通道判定流程

**第一层：规则引擎初筛**

- 基于 diff 行数、文件路径、内容模式匹配进行初筛。
- 例如：纯文案修改（`diff.lines <= 5`，路径匹配 `*.tsx/*.html`，内容匹配 `text|label|placeholder`，排除 `onClick|fetch|eval`）。

**第二层：简单辩论确认**

- 规则引擎初筛后**不直接执行**，启动一轮极简辩论（1-2 支相关团队，1 轮，30 秒内）。
- 如有异议（如 security 发现文案涉及 PII），降级为轻量通道或标准通道。

**第三层：渐进式校准**

- Week 1-2：所有任务标注 proposed_route，但全部走标准通道，收集误判数据。
- Week 3：Kimi 分析误判案例，调优规则。
- Week 4+：启用快速通道，保留“用户一键升级为标准通道”选项。

### 7.3 快速通道自动合并

- 快速通道任务通过证据校验后，**默认自动合并并通知用户**，无需等待用户点确认。
- 用户可在 `project-profile.yaml` 中关闭自动合并：
  ```yaml
  quick_channel:
    auto_merge: true  # 默认 true
    notification: compact  # silent / compact / verbose
  ```
- 若自动合并失败（如分支冲突、CI 失败），降级为人工确认。

### 7.4 快速通道证据要求

- 快速通道仍须通过 Gateway 的轻量证据校验（如 lint、基本语法检查）。
- 纯文案修改可豁免功能测试，但须通过 i18n key 检查和硬编码字符串扫描。

### 7.5 快速通道规则引擎完整规则集

规则引擎初筛必须按以下优先级评估，任一条件命中即进入对应通道；未命中任何规则时降级为轻量或标准通道：

| 规则 ID | 通道 | 条件（AND 关系） | 审查深度 |
|---------|------|------------------|----------|
| Q1 | 快速 | `diff.lines <= 5` + 文件路径匹配 `*.{tsx,jsx,vue,html,md,txt,yaml,yml,json}` + 内容匹配 `text|label|placeholder|title|alt|aria-label|description` + 排除 `onClick|onSubmit|fetch|eval|import|require|function|class` | light：1-2 支团队，1 轮 |
| Q2 | 快速 | `diff.lines <= 3` + 文件路径匹配 `*.{css,scss,less}` + 纯样式值变更（color、font-size、margin 等）+ 无 `!important` 覆盖关键变量 | light |
| Q3 | 快速 | `diff.lines <= 1` + 文件路径匹配 `*.config.{js,ts,json}` + 仅数值调参（timeout、retry、pool_size 等）+ 值在已知安全范围内 | light |
| Q4 | 轻量 | `diff.lines <= 20` + 文件路径匹配 `*.{ts,tsx,js,jsx,py,go}` + 无新增依赖 + 无数据库 schema 变更 + 无 API 接口签名变更 | standard：3-4 支团队，1 轮 |
| Q5 | 轻量 | 文档更新（`*.md`、`docs/`、`README`）+ 无配置值变更 + 无架构图变更 | standard |
| Q6 | 标准 | 未命中 Q1-Q5 的所有任务 | deep：完整六阶 |

**安全逃逸规则**：无论命中哪条规则，若 diff 内容匹配以下模式，强制升级为标准通道：
- 含 `password`、`secret`、`token`、`key`、`credential`、`private_key`
- 含 `drop table`、`delete from`、`truncate`、`alter table`（未在 migration 目录中）
- 含 `eval(`、`Function(`、`setTimeout(.*string)`、`innerHTML`
- 新增外部网络请求（`fetch`、`axios`、`http.request`）

### 7.6 Rollout Gate 配置

`project-profile.yaml` 中的 `quick_channel.rollout_phase` 控制快速通道启用节奏：

| 阶段 | 行为 | 切换条件 |
|------|------|----------|
| `observe_only` | 所有任务标注 proposed_route，但全部走标准通道；系统静默记录"若走快速通道是否正确" | 默认值；新项目或重大配置变更后强制回到此阶段 |
| `calibrating` | 允许快速通道执行，但要求人工二次确认（不自动合并）；收集确认/拒绝数据 | 累积 ≥ 50 条快速通道判定且误判率 < 5% 时自动转入 |
| `enabled` | 完全启用快速通道，允许自动合并（若配置 `auto_merge: true`） | 累积 ≥ 100 条且误判率 < 2% 时可手动切至此阶段 |

**误判定义**：标注为 quick 的任务在实际执行中发现需要标准通道才能发现的问题（如 security 风险、API 兼容性断裂）。

**强制回退机制**：若某周误判率突增 > 10%，Gateway 自动将 `rollout_phase` 回退到 `observe_only`，并通知项目 Owner。

### 7.7 自动合并失败降级流程

快速通道任务尝试自动合并时，以下任一情况视为合并失败，必须降级为人工确认：

1. **Git 合并冲突**：目标分支在任务执行期间已有新提交，导致 fast-forward 失败。
2. **CI 失败**：合并后触发的基础流水线（lint + unit test）失败。
3. **分支保护规则冲突**：目标分支要求至少 1 条人工 review，但快速通道未产生人工 review。

**降级 UX**：
- Gateway 立即停止自动合并，保留任务分支。
- 向用户发送阻塞通知：
  ```text
  ⚠️ 快速通道任务 [run_id] 自动合并失败。
  原因：CI 失败（test_payment.py::test_refund 断言失败）。
  分支：quickfix/copy-1855
  操作选项：
  [1] 查看失败日志并手动修复后合并
  [2] 升级到标准通道，重新执行完整测试与审查
  [3] 放弃本次变更，关闭 Run
  ```
- 用户选择前，Run 状态保持 `blocked`，不自动关闭。

### 7.8 并行任务 Merge Strategy

当三阶拆分为并行子任务时，必须在 DAG 中显式声明 `merge_strategy`：

| 策略 | 适用场景 | 执行方式 |
|------|----------|----------|
| `fast_forward` | 各子任务修改完全 disjoint 的文件集 | 按完成顺序依次 rebase 到基线，保持线性历史 |
| `merge_commit` | 子任务有 disjoint write set 但需保留并行历史 | 全部完成后统一 merge，生成合并提交 |
| `squash_then_merge` | 子任务产生大量中间 commit | 每个子任务先 squash 为单 commit，再 merge |
| `sequential_rebase` | 子任务间有逻辑依赖（如 A 改接口，B 改调用方） | 严格按 DAG 拓扑顺序 rebase，后序任务基于前序任务的结果 |
| `manual` | write set 可能重叠，或涉及重命名/大范围重构 | Gateway 阻塞，等待 Kimi 或用户决策合并顺序 |

**默认策略**：未声明时 Gateway 强制使用 `manual`，拒绝自动执行。

**Write Set 冲突检测算法**：
- 并行任务进入执行前，Gateway 收集所有节点的 `write_scope` 列表。
- 对每一对并行节点 `(ti, tj)`，检查其 write_scope 是否存在交集：
  - 若交集为空 → 允许并行执行。
  - 若交集非空但 `merge_strategy ≠ manual` → Gateway 阻塞，返回 `write_set_overlap`，要求显式声明 `manual` 或缩小 write_scope。
  - 若交集非空且 `merge_strategy = manual` → 允许进入执行，但 Gateway 标记为 `requires_manual_merge`，在三阶完成后通知 Kimi/用户决策合并顺序。
- write_scope 支持 glob 表达式（如 `src/pages/*.tsx`）；冲突检测采用字符串前缀匹配 + glob 展开后的路径交集计算。

---

## 8. Gateway 与证据门控需求

Gateway 必须承担以下职责：

- 暴露 Kimi-facing Run Projection API。
- 将 Kimi 请求翻译为 Hermes 执行动作。
- 保存 Run、Task、Artifact、Decision、Audit、Event 的状态投影。
- 记录需求补全来源、置信度、冲突和依赖投影。
- 阻止 Kimi 直接改 Kanban 原始状态。
- 校验 worker output、review verdict、global evaluation、closeout artifact。
- 在证据缺失、风险越界、权限不足、状态分歧时阻塞。

Gateway 不应承担：

- 自己做业务决策。
- 替代 Claude/Codex 生成代码。
- 替代用户批准 L3/L4 或 protected target。
- 将模拟/模板输出当作真实强证据。

---

## 9. Worker 执行需求

### 8.1 执行模型

| Worker | 主要职责 |
|--------|----------|
| Codex | 代码实现、修复、测试执行、结构化结果返回 |
| Claude | 代码审查、风险审计、专项评估、复审 |
| 额外 Claude/Codex 实例 | 特殊审计、交叉评审、隔离执行 |

### 8.2 生命周期

Hermes agents 必须管理：

- 会话创建。
- 工作区分配。
- 写入范围。
- 超时与清理。
- 输出收集。
- 失败重试或阻塞上浮。

### 8.3 执行约束

- 所有执行必须遵循 Harness Engine、AGENTS.md、SOUL.md。
- 并行任务必须有 disjoint write set 或明确合并策略。
- 子代理不能绕过 Gateway 报告“已完成”。
- 缺少测试证据或审查证据时不得推进阶段。

---

## 10. 用户交互需求

### 9.1 输入形态

用户输入应支持短意图：

```text
我要做 X，相关线索是 A、B、C，约束是不要碰 Z。
```

**新项目首次使用时的接入对话**：

系统先自动探测项目信息并展示草稿报告，开发者确认或修正后完成接入。

**日常任务时的处理**：

Kimi 先补成结构化工单和验收矩阵，再在必要时提问。只有以下信息无法可靠推断时才问用户：

- 验收标准缺失且无法从上下文推断。
- 硬约束冲突。
- 风险策略不明确。
- 关键依赖不可确认。
- 高风险操作需要确认。

### 9.2 用户错误纠正交互

当系统检测到用户请求存在客观错误时：

1. **第一轮纠正（极简）**：一句话风险概述 + 一个替代方案。详细证据默认折叠，用户可主动展开查看。
2. **第二轮纠正（完整）**（如用户坚持）：展示同类历史事故、安全规范原文和完整证据链。
3. **最终处理**（如用户仍然坚持）：
   - 若涉及 L3/L4：Gateway 阻塞，要求审批人确认。
   - 若非高风险：记录为“用户 Override”，附证据，继续执行，六阶复盘。

系统纠正时禁止人格评价，只陈述事实和证据。首轮纠正避免信息过载导致用户产生"被教育"的对抗感。

### 9.3 自动推进与确认节点

用户需要确认：

- 方向报告中的低置信度或冲突项。
- 方案报告中的高风险或不可逆变更。
- L3/L4 或 protected target。
- 无法自动消解的冲突。
- protected target 的经验沉淀或配置修改。

用户不需要确认：

- 每个子任务分配。
- 每个辩论团队组合。
- 每次状态投影。
- 低风险实现细节。
- 快速通道任务的自动合并。
- 默认可自动验收通过的最终交付。

### 9.4 通知与交互载体规范

**执行心跳传输协议**：
- 心跳通过 **SSE（Server-Sent Events）** 通道推送，事件类型为 `orchestra.heartbeat`。
- 消息格式（JSON）：
  ```json
  {
    "event": "orchestra.heartbeat",
    "run_id": "run_xxx",
    "stage": "implementation",
    "completed_tasks": 2,
    "total_tasks": 5,
    "in_progress": ["test_payment.py"],
    "queued": ["review_payment.py"],
    "blocked": null,
    "eta_seconds": 45,
    "timestamp": "2026-05-26T12:00:00Z"
  }
  ```
- SSE 连接断开后，客户端可在 5 秒内重连并收到最近 3 条历史心跳（Gateway 缓存）。

**实时快照查询**：
- 用户输入 `"状态？"` 或 `"status"` 时，Gateway 返回当前 Run 的完整投影（不含正在执行中的中间文件内容，只含元数据）。
- 查询接口：`GET /orchestra/runs/{run_id}/projection?snapshot=true`，响应包含 `run`、`tasks`、`artifacts`、`decisions`、`audits`、`events` 六类对象，与常规投影一致。
- 快照查询不中断 worker 执行，Gateway 采用只读副本或日志回放实现。

---

## 11. 成功指标

产品成功应以以下指标衡量：

- 用户只输入目标和少量线索即可启动工作流。
- 系统能自动补齐环境、上下游、隐性约束和验收矩阵。
- 信息损失、冲突覆盖和错误传播显著减少。
- 一阶/二阶能在编码前拦截明显错误方向或路线。
- 三阶输出有完整代码、测试、审查证据。
- 四阶能把评审意见转化为实际修复。
- 五阶能暴露跨模块、跨角色、跨风险维度的问题。
- 六阶能沉淀可复用经验，而不是污染记忆。
- Gateway 能阻断无证据推进、越权推进和状态分歧。
- Claude/Codex 的执行结果可审计、可复现、可回溯。
- 无人监督完成率高，只有危险、偏离、冲突或低置信度时才上浮人工。
- 三阶执行期间用户可感知进度，不因长时静默产生焦虑。
- 快速通道自动合并率高于 90%，用户无需为单文案修改点确认。
- `pass_with_warnings` 的残余风险通知到达率 100%，用户知情权不被自动推进牺牲。

### 11.1 成功指标采集管道

PRD §11 的定性指标必须落地为可采集、可聚合、可验证的定量事件管道。

**事件采集字段规范**：

| 指标 | 对应事件类型 | 采集字段 | 聚合规则 | 阈值 |
|------|-------------|----------|----------|------|
| 用户只输入目标即可启动 | `run.created` | `has_intent_only: bool`, `hydration_time_ms` | 月度占比：intent_only / total_runs ≥ 85% | ≥ 85% |
| 自动补齐环境/上下游/隐性约束 | `intake.completed` | `has_env_deps`, `has_upstream`, `has_downstream`, `has_implicit`, `has_acceptance_matrix` | 月度占比：四项全 true / total_intake ≥ 90% | ≥ 90% |
| 信息损失/冲突覆盖减少 | `conflict.resolved` | `resolution`, `severity`, `auto_resolved_rate` | 月度 auto_resolved / total_conflicts ≥ 70% | ≥ 70% |
| 一阶/二阶拦截错误方向 | `direction_debate.blocked` + `solution_debate.blocked` | `reason: direction_error / route_error` | 月度拦截数 ≥ 1（非零即达标，证明机制生效） | ≥ 1 |
| 三阶输出有完整证据 | `implementation.completed` | `has_test_evidence`, `has_review_evidence`, `write_scope_verified` | 月度三项全 true / total_impl ≥ 95% | ≥ 95% |
| 四阶评审意见转修复 | `improvement.closed` | `a_fixed`, `b_escalated`, `c_blocked`, `d_regression_loops`, `e_debated` | 月度 A 类闭环率 ≥ 90%；D 类 3 次内闭环率 ≥ 80% | A≥90%, D≥80% |
| 五阶暴露跨维度问题 | `global_evaluation.pass_with_warnings` | `warn_dimensions_count`, `residual_risks_high`, `residual_risks_medium` | 月度 pass_with_warnings 率 10%-30%（过低说明评审不足，过高说明质量差） | 10%-30% |
| 六阶经验沉淀 | `closeout.completed` | `proposals_generated`, `proposals_applied`, `proposals_rejected` | 月度 proposals_applied ≥ 1（证明 queue 在运转） | ≥ 1 |
| Gateway 阻断无证据推进 | `gateway.blocked` | `reason: missing_evidence / scope_violation / unauthorized_advance` | 月度阻断事件数 ≥ 1（机制生效证明） | ≥ 1 |
| 无人监督完成率 | `run.closed` | `human_intervention_count` | 月度 human_intervention_count = 0 的 Run 占比 ≥ 70% | ≥ 70% |
| 三阶可感知进度 | `heartbeat.delivered` | `latency_ms`, `delivery_rate` | 心跳延迟 ≤ 5 秒，送达率 ≥ 99% | ≤ 5s, ≥ 99% |
| 快速通道自动合并率 | `quick_channel.merged` | `auto_merged`, `downgrade_count` | 月度 auto_merged / total_quick ≥ 90% | ≥ 90% |
| 残余风险通知到达率 | `global_evaluation.notified` | `notification_level`, `delivery_confirmed` | `delivery_confirmed = true` 占比 = 100% | = 100% |

**采集与验证机制**：
1. 所有事件由 Gateway 在状态流转时写入 `events.jsonl`，格式为 NDJSON，每条含 `event_type`、`timestamp`、`run_id`、`payload`。
2. `scripts/bin/orch-audit` 负责按日/周/月聚合事件，输出 `metrics_summary.json`。
3. `scripts/bin/orch-verify` 在 staging 环境执行时，对比 `metrics_summary.json` 与上述阈值，任一指标不达标则 closeout 不得标记为"满足 PRD 成功标准"。
4. Schema 一致性：`config/schemas/orchestra.full.schema.json` 必须包含所有事件字段定义；`scripts/tests/test-schema-doc-sync.sh` 自动校验 schema.md、schema.json 与事件字段的一致性。

---

## 12. 当前实现对齐说明

当前仓库已经具备与本 PRD 对齐的关键基础：

- `scripts/lib/orch_gateway.py` 定义六阶段 Run。
- `config/debate/full/teams.json` 定义 `qnN4o510` 对齐的 16 支团队。
- `config/debate/full/modes.json` 定义 `qnN4o510` 对齐的 8 种模式。
- `config/debate/full/coverage-policy.json` 定义不同阶段的最低覆盖要求。
- `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` 定义 Kimi、Human、Gateway、Worker 的权限边界。

仍需在文档和实现推进中保持的边界：

- `qnN4o510` 是设计知识源，不是运行时状态权威。
- Gateway State、Audit、Kanban、Artifacts 才是运行时证据链。
- MVP legacy registry 是兼容层，full-system 文档和目标实现以 canonical registry 为准。
- Kimi 是外部上层 Orchestrator，不嵌入 Hermes execution core。
- 0阶需求补全是产品必要层，可以作为 Gateway six-stage run 的 intake/context hydration 前置能力实现。
