# Hermes Orchestra 实现差距分析报告（修订版）

**日期**: 2026-05-21
**分析范围**: `HERMES-ORCHESTRA-FULL-PRD.md`, `HERMES-ORCHESTRA-FULL-SCHEMAS.md`, `HERMES-ORCHESTRA-FULL-SPEC.md`
**状态**: Full Target Readiness 与 Active Runtime 差距复核

---

## 执行摘要

Hermes Orchestra 的 **Full Target 产物层** 已经比较完整：完整 Schema、staged/disabled 配置、验证工具、配套 ADR，以及一批围绕 full contract 的 Python 模块和 shell 测试都已存在，且代表性验证可通过。

但这不应被表述为 **“full runtime 已大体实现”**。当前仓库的真实状态更接近：

- **Full Target Readiness**: 高
  - Full Schema、Full Debate Package、Full Worker Registry、Cutover/Fixture/SLO/Self-Evolution 等目标产物已落盘，可被验证工具消费。
- **Active Runtime Adoption**: 低到中
  - 当前活动运行时仍以 MVP/current runtime 为主。
  - 多个 full-path 子系统仍处于 `staged_target` 或 `enabled: false`，尚未成为默认运行路径。
  - `goal-gateway-cutover` 范围内已新增 mixed-family runtime activation substrate，但它只激活了 Gateway authority / closeout 相关模块默认路径，还不是全量 full runtime。
- **测试结论**: 应理解为“合约有效、staged 组件在测试场景可工作”，而不是“full runtime 已完成切换”。

本次复核后，更准确的结论是：

1. **可以说 full-target 合约层基本就位。**
2. **不能说 full runtime 已达到 75%-80% 并接近完成。**
3. **真正的主要差距是 cutover、默认启用、以及 Gateway 对 full artifact family 的真实运行时消费。**

---

## 本次复核的直接证据

已复核并实际运行的代表性验证：

- `scripts/bin/orch-full-contract-validate`: PASS
- `scripts/tests/test-gateway-run-create.sh`: PASS
- `scripts/tests/test-worker-registry.sh`: PASS
- `scripts/tests/test-release-pipeline.sh`: PASS
- `scripts/tests/test-debate-assembly.sh`: PASS
- `scripts/tests/test-runtime-activation.sh`: PASS
- `scripts/tests/test-e2e-ai-debate-flow.sh`: PASS
- `scripts/tests/test-e2e-ai-worker-flow.sh`: PASS
- `scripts/tests/test-runtime-knowledge.sh`: PASS

这些结果证明：

- Full Schema 与 staged/disabled 配置之间的 **静态合约一致性** 是成立的。
- debate / worker 的代表性 Gateway 流程现在可以在默认 runtime 分流下运行，不再依赖调用方显式传入 `allow_staged=True`。
- Runtime knowledge 的合约、ingestion/query 代码与 state-store 测试现在可在默认 repo 配置下运行；gbrain 不再作为本轮 active runtime 接入目标。

这些结果**没有**证明：

- 当前默认 Gateway runtime 已切换到 full schema artifact family。
- `config/release/*`、`config/decisions/remote-channel.json` 已成为 active runtime authority。

---

## 1. 核心判断

### 我同意的部分

- Full 规格相关配置文件基本齐备。
- `config/schemas/orchestra.full.schema.json` 与 `orch-full-contract-validate` 已具备较强的目标合约约束能力。
- debate、worker、release、runtime knowledge、self-evolution 等模块，至少都已有清晰的 target shape，而不是停留在纯文档层。

### 我不同意的部分

- 将 staged/disabled target package 表述为“已实现”或“完整实现”。
- 用单一完成度百分比混合描述 target readiness 和 active runtime。
- 把“测试通过”直接外推成“当前默认运行时已具备 full capability”。

---

## 2. 当前状态应如何准确表述

建议把现状拆成两层：

### A. Full Target Readiness

这层可以给出积极判断：

- Full machine schema 已存在。
- Full contract validator 已存在并可运行。
- Full debate / worker / release / knowledge / remote decision / self-evolution 的目标配置与对应代码模块已存在。
- 相关 ADR、authority matrix、coverage matrix、cutover policy、fixture policy、SLO policy 已补齐。

### B. Active Runtime Status

这层必须更保守：

- 当前活动运行时仍是 MVP/current runtime 主导。
- Full Gateway runtime implementation 不能简单归类为“已实现”，更接近“部分实现 + 待 cutover 集成”。
- 多个 full-path 组件默认并不启用，或仅以 staged target 身份存在。

### C. 规格对齐总表

下表按 `HERMES-ORCHESTRA-FULL-PRD.md`、`HERMES-ORCHESTRA-FULL-SPEC.md`、`HERMES-ORCHESTRA-FULL-SCHEMAS.md` 的一级能力分组汇总，并与 `docs/FULL-COVERAGE-MATRIX.md` 对齐。

状态解释：

- `已完成`：目标产物/代码/验证路径已经到位，且当前结论与权威矩阵一致。
- `部分完成`：只完成了 target layer，或 runtime 只实现了局部链路。
- `未完成`：默认 active runtime 尚未接入，或矩阵明确标为 `pending` / `not implemented` / `not active runtime`。

| 能力域 | PRD / SPEC / SCHEMAS 对应 | `FULL-COVERAGE-MATRIX` 对齐项 | Full Target 状态 | Active Runtime 状态 | 当前结论 |
|---|---|---|---|---|---|
| Run 与 Gateway Authority | PRD: User Stories 1-14；SPEC: 4.1-4.5；SCHEMAS: 3.1 | Gateway runtime contract、Gateway full runtime implementation、Idempotency record contract | 部分完成 | 部分完成 | 本地 Python Gateway、Run API、幂等与部分投影链路已存在；Sprint 12 新增了 `gateway_authority` mixed-family activation substrate，但 run-level full artifact cutover 仍未完成。 |
| Six-Stage Evidence 与 Closeout | PRD: User Stories 15-19、63-66、75；SPEC: 4、6、10；SCHEMAS: 3.2 | Self evolution review queue policy，外加 current runtime 的 closeout / evaluation 链路 | 部分完成 | 部分完成 | full schema 已覆盖 `structured_prd`、`development_plan`、`test_plan`、`global_evaluation_report`、`iteration_closeout_report`、`system_improvement_proposals`；Sprint 12 让 `closeout_and_self_evolution` 模块默认激活，但 closeout route 仍未全量消费 full artifacts。 |
| Full Debate Package | PRD: User Stories 20-37；SPEC: 5；SCHEMAS: 3.3 | Full debate team registry、mode registry、coverage policy、assembly policy、backend policy | 已完成 | 部分完成 | canonical teams/modes、assembly/coverage/backend policy、report/audit 代码与测试已就位；代表性 Gateway debate flow 已默认走 mixed-family full package，但 artifact-family authority 仍未完成 run-level cutover。 |
| Worker Execution | PRD: User Stories 38-52；SPEC: 7；SCHEMAS: 3.4 | Full worker backend registry、role registry、capability negotiation report、worker session lifecycle、worker parallel integration | 部分完成 | 部分完成 | registry、default-path negotiation、session record persistence/sweeper、parallel plan/conflict artifact 覆盖已存在；但更深的 serial merge orchestration 与 full worker artifact authority 仍未完成 run-level cutover。 |
| Runtime Domain Knowledge Base | PRD: User Stories 53-62；SPEC: 11.1；SCHEMAS: 3.5 | Runtime Domain Knowledge Base config、runtime knowledge entry contract、ingestion audit、retrieval audit | 部分完成 | 未完成 | config 已显式 deferred，默认 runtime 不接入 gbrain；state-store 仅保留为测试/降级行为，不是 active runtime authority。 |
| Kimi-Audited Self Evolution | PRD: User Stories 63-66；SPEC: 6；SCHEMAS: 3.2 中 `system_improvement_proposals` + queue policy | Self evolution review queue policy | 部分完成 | 部分完成 | queue policy 与 proposal 生成逻辑已存在；Sprint 12 让 self-evolution module endpoint 脱离 `allow_staged=True`，但 Stage 6 默认触发与 closeout 自动接线仍不完整。 |
| Release Pipeline | PRD: User Stories 67-70；SPEC: 9；SCHEMAS: 3.6 | Release pipeline config、release command registry、release evidence | 部分完成 | 未完成 | pipeline/registry/executor 与 `deployment_report` 校验已存在，但 formal path 默认 disabled，不是当前发布 authority。 |
| Remote Decision Channel | PRD: User Stories 71-74；SPEC: 8.1；SCHEMAS: 3.6 | Remote decision config、remote decision evidence | 部分完成 | 未完成 | request/response contract 与 disabled config 已定义，但 adapter 与默认运行时接线未实现。 |
| Degradation Policy | PRD: Implementation Decisions + Testing Decisions；SPEC: 3.3、4.6；SCHEMAS: 3.7 | Degradation policy | 已完成 | 部分完成 | policy、schema、代码与测试已就位；Sprint 12 让 Gateway 可按 mixed-family activation 默认调用该 policy，但 run-level enforcement 仍未全量接入。 |
| Cutover Policy | PRD: Implementation Decisions；SPEC: 4.4-4.5；SCHEMAS: 3.8 | Full contract readiness gate policy | 已完成 | 未完成 | artifact-family cutover 规则、禁用全局切换、保留历史 artifact 的策略已定义，但真正 cutover 尚未发生。 |
| Performance SLO Policy | PRD: Implementation Decisions；SPEC: 4.6；SCHEMAS: 3.9 | Performance SLO policy | 已完成 | 部分完成 | component budget 与 degradation action 策略已定义并可验证；Sprint 12 让 Gateway 默认可调用该 policy，但它还不是所有 run command 的统一 enforcement path。 |
| Fixture Policy | PRD: Testing Decisions；SPEC: 4.7；SCHEMAS: 3.10 | Full fixture policy | 已完成 | 部分完成 | contract fixtures / runtime fake adapters 的边界与限制已定义并可验证；Sprint 12 让 Gateway 默认可调用该 policy，但它仍主要约束 test/readiness 边界。 |

---

## 3. 各子系统复核结论

## 3.1 Gateway / Six-Stage Run

### 结论

**部分实现，且当前仍应视为 MVP/current runtime 为主。**

### 依据

- `scripts/lib/orch_gateway.py` 确实已经实现了本地 Python HTTP Gateway。
- 代码中存在 `FULL_MODULE_ENDPOINTS`、`ACTIVE_RUN_STATUSES`、Kanban 完成/阻塞逻辑，以及 `/v1/*` 路由处理。
- 代表性测试 `test-gateway-run-create.sh` 可通过。

### 仍然不能过度表述的点

- 这并不等于“Gateway 已完整消费 full target configs 并完成全量 cutover”。
- `docs/FULL-COVERAGE-MATRIX.md` 更准确地将当前状态表述为：
  - Gateway runtime contract: `partially implemented`
  - Gateway full runtime implementation: `pending`（已补 mixed-family activation substrate，但未完成 run-level cutover）
  - 当前 active runtime: `MVP/current runtime active`

### 真实差距

- Gateway 对 full artifact family 的默认消费路径仍未完成切换。
- closeout gates、capability negotiation、release execution、runtime knowledge、remote decision 等 full-path 能力尚未统一接入 active runtime。

---

## 3.2 Full Debate Package

### 结论

**目标产物完整，且代表性 debate 模块路径已进入默认 Gateway 运行流，但尚未完成 run-level authority cutover。**

### 已就位内容

- `config/debate/full/teams.json`
- `config/debate/full/modes.json`
- `config/debate/full/coverage-policy.json`
- `config/debate/full/assembly-policy.json`
- `config/debate/full/backend-policy.json`
- `scripts/lib/debate_engine.py`
- `scripts/lib/debate_assembly.py`
- `scripts/lib/debate_backend_adapter.py`
- `scripts/lib/debate_member_invocation.py`
- `scripts/lib/debate_report.py`

### 需要纠正的表述

- 这些 full debate 配置的 `package_status` 仍是 `staged_target`，不能把磁盘状态误写成 “config 已 active”。
- 当前更准确的说法是：**配置和组件代码完整，代表性 Gateway debate flow 已默认消费 mixed-family full package，但 artifact-family authority 仍未整体切换。**

---

## 3.3 Worker 执行隔离

### 结论

**Full Worker target 已成型，且 default runtime 已接入 negotiation / session lifecycle 的代表性链路，但并行集成仍未完成。**

### 已就位内容

- `config/workers/full/backends.json`
- `config/workers/full/roles.json`
- `scripts/lib/worker_registry.py`
- `scripts/lib/capability_negotiation.py`
- `scripts/lib/worker_session.py`
- `scripts/lib/worker_session_sweeper.py`

### 关键事实

- full worker registry 配置仍是 `package_status: "staged_target"`。
- 直接实例化 `WorkerRegistry(repo)` 仍会因 package 未 active 而阻塞，但 Gateway default path 现在会通过 runtime activation 为 worker family 提供默认 staged override。
- 相关代表性 Gateway 测试已不再要求调用方显式传 `allow_staged=True`。
- Gateway 现在会把 worker session create/transition 结果持久化到 `state://runs/<run_id>/worker-sessions/<session_id>.json`。
- Gateway 现在会在 worker output 路径写出 `parallel_group_plan`、`conflict_scan`，并在机械冲突时写出 `merge_conflict_report` 后阻塞该次输出。

### 真实差距

- 当前并行能力只覆盖机械层的 plan / scan / conflict artifact 产出，还没有完成更深的 serial merge orchestration、语义兼容校验和 full worker artifact authority cutover。
- 当前更准确的说法是：worker negotiation、session lifecycle、parallel mechanical evidence 已有默认 runtime 证据，但完整并行编排与 run-level full artifact cutover 仍未完成。

---

## 3.4 Runtime Domain Knowledge Base

### 结论

**默认 repo 路径现已禁用 runtime knowledge active 接入；它仅保留为 deferred target，不是 full runtime authority cutover。**

### 已就位内容

- `config/knowledge/runtime-kb.json`
- `scripts/lib/knowledge_ingestion.py`
- `scripts/lib/runtime_knowledge.py`

### 关键事实

- `config/knowledge/runtime-kb.json` 当前默认 `enabled: false`。
- `backend` 当前是 `deferred`，并要求显式 adapter 选择后再启用。
- 默认 repo 路径下的 ingestion / query 只会返回 `module_disabled`，不再进入 active runtime。
- `enabled: false` 的显式禁用负例保留，确保 deferred 配置不会被误当成 active capability。
- state-store 仅作为测试和后续 adapter 候选，不是默认 runtime authority。

### 真实差距

- runtime knowledge 当前是 deferred，不会直接决定 closeout、release、remote decision 等最终 authority 行为。
- retrieval audit、promotion path、gateway consumption 还未成为 active runtime 路径。

---

## 3.5 Release Pipeline

### 结论

**配置和执行器已存在，但这是 disabled formal path，不是当前默认发布运行时。**

### 已就位内容

- `config/release/pipeline.json`
- `config/release/commands.json`
- `scripts/lib/release_pipeline.py`
- `scripts/lib/release_executor.py`

### 关键事实

- `pipeline.json` 默认 `enabled: false`
- `commands.json` 默认 `enabled: false`
- registry 仍为 `package_status: "staged_target"`
- 默认 `ReleasePipeline(repo)` / `ReleaseExecutor(repo)` 会返回 `module_disabled`
- 测试通过依赖在临时 repo 中显式把配置改为 enabled/active

### 真实差距

- 不能把它写成“发布流水线已实现，只待验证”。
- 更准确的说法是：**发布流水线 target contract 与执行器逻辑已写好，但默认运行时尚未接管真实发布路径。**

---

## 3.6 Self Evolution

### 结论

**队列模型和生成逻辑已实现，但仍属于 staged policy，不是当前 active runtime 既成事实。**

### 已就位内容

- `config/evolution/self-evolution-review-queue.json`
- `scripts/lib/self_evolution.py`

### 真实差距

- Stage 6 sweep 何时、如何在真实 Gateway closeout 流程中触发，仍需作为运行时集成问题处理。
- “proposal queue 已定义”不等于“所有完成的 run 都在默认流程里进入该队列”。

---

## 3.7 Remote Decision Channel

### 结论

**配置存在，但当前就是 disabled optional path。**

### 关键事实

- `config/decisions/remote-channel.json` 默认 `enabled: false`
- `channel_type: "none"`
- `adapter_id: "disabled"`

### 真实差距

- 当前不能把它描述成“配置完成，仅待验证”。
- 更准确的说法是：**协议约束已定义，适配器与默认运行时接入尚未实现。**

---

## 3.8 Schema / Validation / Cutover Policy

### 结论

**这是当前仓库最扎实、最接近“完成”的部分。**

### 已确认

- `config/schemas/orchestra.full.schema.json` 已存在并可验证 staged/disabled target artifacts
- `scripts/bin/orch-full-contract-validate` 已能验证 full config contracts、canonical IDs、release command refs、disabled formal path 约束
- `config/cutover/full-readiness-gates.json` 已定义 artifact-family staged cutover 规则

### 注意点

- 这套能力的强项是“定义目标、收紧合约、约束 cutover”。
- 它并不自动意味着 runtime 已切到这些 full contracts。

---

## 4. 关于测试覆盖的修正结论

原文对测试的总体方向判断基本正确，但表述需要收紧。

### 可以确认的事实

- `scripts/tests/` 当前有 **111** 个 `*.sh` 测试文件。
- shell test 是本仓库当前的主测试形态。
- 代表性 full-path 测试确实可通过。

### 需要纠正的地方

- “所有关键测试通过”应限定为：**已抽样运行的关键代表性测试通过**。
- “完整覆盖”表述过强。当前更适合写成：**覆盖面广，但仍以 contract/staged behavior 为主，不能替代 full runtime end-to-end cutover 验证。**
- 部分测试脚本更适合通过 `bash scripts/tests/...` 执行，而不是假定都可直接 `./...` 运行。

### 更准确的测试解读

当前测试主要证明三类事情：

1. 配置与 full schema 的一致性
2. staged/disabled formal path 的保护行为正确
3. 在测试场景显式激活后，模块级逻辑可工作

当前测试尚未充分证明：

1. 默认 Gateway runtime 已全量接管 full artifact family
2. full release / knowledge / remote decision / worker isolation 已形成统一生产运行链路
3. 所有跨模块 closeout gate 都在真实默认流程中生效

---

## 5. 对完成度百分比的修正建议

不建议继续用单一百分比描述整个项目状态，因为它会把两类完全不同的东西混在一起：

- target design / config / validation readiness
- active runtime integration / cutover completion

如果必须量化，更可信的说法应是：

- **配置 / Schema / ADR / Validator readiness**: 高
- **模块级 full-path 代码准备度**: 中
- **active runtime cutover 完成度**: 低到中

不建议再使用“整体 85%，运行时 80%”这一类说法。

---

## 6. 修订后的关键发现

### 优势

1. Full target 规格已经被落实为可验证产物，而不只是文档设想。
2. 完整 Schema、validator、cutover gates、fixture policy、SLO policy、self-evolution queue 都已落盘。
3. debate / worker / release / runtime knowledge 等关键子系统都已有明确的代码入口。
4. staged/disabled formal path 的约束设计比较清晰，不容易误切到未准备好的 full runtime。

### 风险

1. 很多能力“存在于 target package”，但尚未成为 active runtime authority。
2. 文档若混淆 staged target 与 active runtime，会误导排期、验收和优先级判断。
3. 测试通过容易被误读为“系统已完成 cutover”。
4. runtime knowledge、release、remote decision 这几条线都还依赖后续真实接线。

---

## 7. 建议下一步

### 立即行动

1. 统一文档口径，明确区分 `target readiness` 与 `active runtime status`
2. 以 `docs/FULL-COVERAGE-MATRIX.md` 为准绳，逐项修正文档中的“已实现”措辞
3. 明确列出哪些 full-path 模块已被 Gateway 默认消费，哪些仍仅限 staged/disabled

### 短期

1. 为 Gateway 增加针对 full artifact family 的默认接线路径验证
2. 将 worker negotiation、runtime knowledge、release executor、self-evolution trigger 分别做 active runtime 集成检查
3. 增补真正跨模块的 end-to-end closeout / release / recovery 测试

### 中期

1. 按 artifact family 执行 staged cutover，而不是全局一键切换
2. 每切一类能力，都同步更新 `FULL-COVERAGE-MATRIX` 和实现差距文档
3. 把“测试通过”拆成 contract pass、module pass、runtime cutover pass 三种不同信号

---

## 结论

Hermes Orchestra 当前最准确的状态不是“full runtime 已大体实现”，而是：

- **Full-target 合约层已经比较成熟**
- **默认 active runtime 仍以 MVP/current runtime 为主**
- **真正的实现差距在于 runtime adoption、gateway integration 和 artifact-family cutover**

因此，本项目现阶段更适合被描述为：

**“Full target 已具备较高准备度，但 full runtime 仍处于分阶段接入与切换前后之间。”**
