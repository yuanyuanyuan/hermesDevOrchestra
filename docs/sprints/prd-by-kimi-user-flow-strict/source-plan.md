---
title: prd-by-kimi-user-flow-strict
owner: codex
date: 2026-05-26
version: v2
---

# PRD by Kimi User Flow Strict Sprint Source Plan

## Execution Guardrails

- 在功能 sprint 开始前，优先把 `scripts/lib/orch_gateway.py` 的新增逻辑抽到职责明确的 helper modules；`orch_gateway.py` 尽量只保留 HTTP 路由、authority 校验与模块编排。
- 任何 Sprint 若发现需要继续向 `orch_gateway.py` 堆叠跨阶段逻辑，必须先补 Gateway seam extraction，再继续功能实现。
- 所有“自动推进”能力都必须同时附带阻塞条件、authority route 和回放验证路径，不能只写 happy path。

## Requirements

- R1. 新项目首次接入必须在 5 分钟内产出《项目探测报告》草稿，并生成 `.hermes/project-profile.yaml`、初始 `AGENTS.md` 与 `SOUL.md`。
- R2. 0 阶每次任务都必须输出《需求补全包》，包含目标、非目标、约束、环境、上下游、隐性内容、验收线索、依赖图、冲突清单、验收矩阵和执行 prompt envelope。
- R3. 系统必须显式保留 6 类信息：用户原始意图、系统补全内容、模型推断内容、已验证事实、未验证假设、冲突信息，并为关键结论附来源、置信度和验证方式。
- R4. 0 阶必须支持摘要/详细双模式、短意图输入解析、确认节点枚举、以及两轮渐进式错误纠正；用户坚持错误决策时必须记录 Override 或上浮审批。
- R5. 系统必须支持快速、轻量、标准三层通道；快速通道需走“规则初筛 -> 极简辩论 -> 渐进校准”，并满足自动合并与轻量证据要求。
- R6. 一阶方向辩论必须基于结构化工单运行，工单包含项目背景、目标、非目标、约束、验收标准、风险边界、失败策略，并区分硬约束与用户偏好。
- R7. 辩论系统必须支持 16 支 canonical 团队、项目扩展团队、旧别名兼容、以及按任务类型和 `project-profile.yaml` 装配团队与模式。
- R8. 二阶方案辩论必须根据争议程度选择 canonical mode，输出 DAG、任务输入输出、写入范围、并行边界、测试策略，并声明 delegate_task 同源隔离。
- R9. Gateway 必须提供 Kimi-facing Run Projection API，保存 Run、Task、Artifact、Decision、Audit、Event 六类状态投影，记录需求补全来源、置信度、冲突和依赖投影，并把 PRD §2.2 的权限边界矩阵显式落成可查询、可验证的 authority contract。
- R10. 三阶执行必须只能通过 Gateway/Kanban 分派，具备独立 workspace 或等价上下文隔离，并对写入范围、证据引用、测试结果和审查输出做门控。
- R11. 三阶执行期间必须每 30 秒或每完成一个子任务发送结构化心跳；并行任务必须声明 disjoint write set 或显式 merge strategy，且用户可随时查询实时快照。
- R12. 四阶改进必须完整落地 A-E 五类问题分类、最多 3 次回归循环、评审争议 mini-debate、以及超范围修复阻塞与新 Run/子任务生成。
- R13. 五阶全局评估必须覆盖 8 个维度，按场景使用 `jury_panel`、`meta_review`、`cross_team_conflict_detector`，并对 `pass_with_warnings` 做高/中/低风险摘要通知与 authority routing。
- R14. 六阶持续改进必须读取完整审计输入，保留经验来源/置信度/适用边界，对 protected target 强制 Kimi review + Human Approval，并为 PRD 第 11 章成功指标定义并实现采集口径、事件字段、汇总阈值与 0→6 阶严格回归验证。

## 术语定义与量化标准（P0 阻断项，不定义则无法实施与验收）

### 1. protected target 完整清单与审批层级映射

| 类别 | pattern 示例 | approval_level | 说明 |
|------|-------------|----------------|------|
| k8s_production | `k8s/production/.*` | L4 | 生产环境 K8s 配置 |
| db_schema | `db/migrations/.*` | L4 | 数据库 schema 变更 |
| api_contract | `docs/api/.*` `specs/.*` | L3 | 对外 API 契约 |
| auth_policy | `config/auth/.*` `policies/.*` | L4 | 认证/授权策略 |
| iam_secrets | `config/secrets/.*` `.env*` | L4 | IAM 与密钥管理 |
| infrastructure | `terraform/.*` `infrastructure/.*` | L4 | 基础设施即代码 |
| payment_compliance | `src/payment/.*` `compliance/.*` | L4 | 支付与合规相关代码 |
| ci_cd_pipeline | `.github/workflows/.*` `ci/.*` | L3 | CI/CD 流水线配置 |
| legal_terms | `docs/legal/.*` `terms/.*` | L4 | 法律条款与用户协议 |
| core_business_logic | `src/core/.*` `domain/.*` | L3 | 核心业务逻辑 |
| data_privacy | `src/pii/.*` `privacy/.*` | L4 | 数据隐私处理 |

> **关键约束**: `project-profile.yaml` 的 `protected_targets` 必须引用上表中的 `类别` 字段；缺失 `kimi_review_ref` + `human_approval_ref` 时 Gateway 必须拒绝 closeout。

### 2. A-E 五类问题分类定义表

| 类别 | 名称 | 判定标准 | 处理动作 | 升级路径 |
|------|------|----------|----------|----------|
| A | 格式/风格问题 | lint/format 可自动修复 | 自动修复 + 复测 | 无 |
| B | 简单逻辑错误 | 单测失败，定位清晰 | 自动修复 + 复测 | 2 次失败后人工介入 |
| C | 边界条件缺失 | 边界测试失败 | 自动修复 + 边界用例补充 | 2 次失败后人工介入 |
| D | 架构/设计缺陷 | 多模块影响，需重构 | 方案 mini-debate → 修复 | 第 3 次失败上浮接受/回滚/重设计 |
| E | 评审争议 | 评审人间意见不一致 | 2 轮 mini-debate → Kimi/用户裁决 | 未收敛则 block + 升级 |

> **关键约束**: 四阶改进必须按上表分类，且 D 类回归上限为 3 次，E 类争议上限为 2 轮 mini-debate。

### 3. 核心安全红线清单

| 红线编号 | 红线描述 | 检测方式 | 阻止机制 |
|----------|----------|----------|----------|
| SR-01 | 禁止覆盖或绕过 authentication/authorization 逻辑 | 关键词 denylist + 语义匹配 | Gateway 拒绝 + 审计记录 |
| SR-02 | 禁止在 prompt_injection 中植入系统级指令覆盖 | 语义匹配 + AST 扫描 | 团队装配阶段拒绝加载 |
| SR-03 | 禁止向未授权 actor 暴露 protected target 写权限 | 权限矩阵校验 | Gateway authority 拒绝 |
| SR-04 | 禁止在生产环境执行未经验证的 schema 变更 | protected target 匹配 + L4 审批 | 缺少审批引用时阻塞 |
| SR-05 | 禁止在 auto_merge 路径中绕过证据门控 | 证据清单完整性校验 | 缺少任一项证据时阻塞 |

> **关键约束**: `prompt_injection` 覆盖上述红线任意一条时，自定义团队 `custom_teams` 加载失败并记录审计事件。

### 4. 置信度阈值量化标准

| 阈值名称 | 数值范围 | 判定规则 | 行为 |
|----------|----------|----------|------|
| 高置信度 | ≥ 0.85 | 模型输出 probability top-1 ≥ 0.85 且与验证事实一致 | 可自动推进 |
| 中置信度 | 0.60 ~ 0.84 | 模型输出 probability top-1 在 [0.60, 0.84] | 需确认节点，用户确认后可推进 |
| 低置信度 | < 0.60 | 模型输出 probability top-1 < 0.60 | 必须阻塞，补充信息或上浮审批 |
| 冲突阈值 | ≥ 1 条冲突记录 | `conflicts` 数组非空 | 必须进入 conflict ledger，不得自动推进 |

> **关键约束**: 低置信度推断（< 0.60）不得作为完成证据推进到下一阶段。

### 5. 模糊词量化标准

| 原表述 | 量化定义 | 验收断言 |
|--------|----------|----------|
| "5 分钟内" | ≤ 300 秒 wall-clock | `time_elapsed <= 300` |
| "完整" | 字段存在性 + 非空 + 格式正确 | 每个字段 `is not None and len > 0 and schema_valid` |
| "及时" | 在指定 SLA 内响应 | `response_time <= sla_threshold` |
| "足够" | 满足最小样本量或覆盖率 | `sample_size >= min_n` 或 `coverage >= min_pct` |
| "优先" | 在同级任务中排序第一 | `priority_rank == 1` |
| "显式保留" | 字段存在于输出结构且可被查询 | `field in output and queryable == true` |
| "不得推进" | Gateway 返回 HTTP 422 / 阻塞状态码 | `status_code == 422 or stage_blocked == true` |

## Implementation Units

### U1. 新项目接入与项目探测报告
**Goal:** 为首次使用场景建立可确认的项目接入流程，确保系统能在进入六阶闭环前自动识别项目技术栈、测试命令、部署目标与风险标志，并生成项目画像初稿。
**Requirements:** R1
**Dependencies:** None
**Files:**
- Create: `scripts/lib/gateway_intake.py`
- Create: `scripts/lib/gateway_projection.py`
- Create: `scripts/lib/gateway_evidence.py`
- Modify: `scripts/bin/orch-init`
- Modify: `scripts/bin/orch-profile-sync`
- Modify: `scripts/bin/orch-mvp-wizard`
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `docs/CONFIGURATION.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Modify: `scripts/tests/test-init-start-status.sh`
- Modify: `scripts/tests/test-mvp-wizard.sh`
- Modify: `scripts/tests/test-profile-packaging.sh`
**Approach:**
- 在接入相关功能开始前抽出 Gateway intake/projection/evidence helper seams，降低后续 0 阶到五阶对单文件的反复改动。
- **Seam Extraction 成功标准**: 抽出的 helper module 必须具备独立单元测试能力；`orch_gateway.py` 行数增长不超过 50 行；新增逻辑 100% 落在 helper 中。
- **Seam Extraction Fallback**: 若 helper 抽取导致接口不兼容或测试覆盖率下降 >5%，允许保留原有 Gateway 内实现，但必须在 Sprint 1 closeout 中记录技术债务并制定后续 Sprint 的再抽取计划。
- 统一首次接入的探测输入源，覆盖文件树、依赖文件、CI/CD、测试目录与风险标志。
- 为《项目探测报告》定义最小字段集合与确认步骤，避免只有 project-profile 草稿而没有可读报告。
- 将项目画像输出与初始化脚本、profile 同步逻辑串起来，保证接入结果可重复生成。
**Test scenarios:**
- 首次接入空白项目时仍能输出完整探测报告草稿。
- 已存在项目画像时不会重复触发首次接入流程。
- 探测结果缺少测试命令或风险标志时，流程必须阻塞并提示修正。
**Verification:**
- 首次接入在 5 分钟内输出《项目探测报告》草稿，至少包含技术栈、测试命令、部署目标、风险标志。
- 开发者确认后生成 `.hermes/project-profile.yaml`、初始 `AGENTS.md`、`SOUL.md`，并可被后续流程读取。
- 接入配置在重复执行时结果稳定，不出现首次接入与常规任务路径混淆。
- Gateway 新增的 intake / projection / evidence 逻辑优先落在 helper modules，`orch_gateway.py` 保持路由与编排边界。

### U2. 需求补全包与信息保真六分类
**Goal:** 把 0 阶补全从“主观总结”提升为带证据的结构化产物，显式保留 6 类信息，并确保依赖图、冲突清单、验收矩阵和 prompt envelope 可直接驱动后续阶段。
**Requirements:** R2, R3
**Dependencies:** U1
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `config/schemas/orchestra.full.schema.json`
- Modify: `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`
- Modify: `docs/prd_by_kimi.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Modify: `scripts/tests/test-gateway-run-short-intent-blocks.sh`
- Modify: `scripts/tests/test-gateway-decision-approve-intake.sh`
- Modify: `scripts/tests/test-full-contract-validation.sh`
**Approach:**
- 为《需求补全包》定义固定结构，覆盖目标、非目标、约束、环境、上下游、隐性内容和验收线索。
- 给每条关键判断补充来源、置信度、验证方式与冲突去向，防止静默覆盖原始意图。
- 把依赖图、验收矩阵、执行 prompt envelope 作为必须产物写进 Gateway 投影与 contract schema。
**Test scenarios:**
- 短输入任务能够自动扩充为完整补全包。
- 低置信度推断不能被当作完成证据推进。
- 冲突信息出现时必须进入 conflict ledger 或等价记录。
**Verification:**
- 《需求补全包》显式保留 6 类信息，并为关键结论附来源、置信度、验证方式。
- 补全包必须包含依赖图、冲突清单、验收矩阵、执行 prompt envelope，缺任一项即阻塞。
- 依赖图必须同时覆盖环境依赖、上游依赖、下游影响、代码依赖四个维度，不能只有单层文件依赖。
- Gateway 状态投影能追溯原始输入与补全结果之间的映射关系。
- 文件态持久化（`run.json` / `tasks.json` / `events.jsonl`）必须采用原子写模式：先写入临时文件，成功后重命名替换；写入失败时必须保留上一次有效版本并可自动恢复。

### U3. 摘要详细模式、短意图解析与两轮纠错
**Goal:** 让 0 阶用户交互从“全量信息轰炸”变成可配置的确认体验，同时把短意图解析、确认节点与两轮渐进纠错/Override 机制做成明确门控。
**Requirements:** R4
**Dependencies:** U2
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/bin/orch-mvp-wizard`
- Modify: `docs/sandbox-simulation-report.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Modify: `docs/CONFIGURATION.md`
- Modify: `scripts/tests/test-gateway-decision-approve-intake.sh`
- Modify: `scripts/tests/test-risk-decisions.sh`
- Modify: `scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
**Approach:**
- 在 `project-profile.yaml` 中引入 compact/verbose intake 模式和通知偏好。
- 为短意图输入补全确认节点清单，覆盖低置信度、冲突、L3/L4、protected target、目标偏离等场景。
- 将用户纠错流程拆成第一轮极简提示、第二轮完整证据、最终 Override/审批留痕三段。
**Test scenarios:**
- 用户只输入“目标 + 线索 + 不要碰 Z”时仍能进入结构化补全。
- 第一轮纠错被拒绝后，第二轮能展开完整证据链。
- 非高风险坚持错误决策时产生 Override 记录，高风险则强制审批。
**Verification:**
- 0 阶同时支持摘要模式与详细模式，默认模式可由 `project-profile.yaml` 配置。
- 确认节点清单覆盖低置信度、冲突、L3/L4、protected target、目标偏离、无法可靠推断等场景。
- 错误纠正遵循 2 轮渐进展开；第 2 轮后仍坚持则记录 Override 或上浮审批并留痕。

### U4. 三层通道分级与快速通道证据门控
**Goal:** 把通道分级从“只有 quick-channel 概念”升级为可执行的三层路由策略，尤其要补齐快速通道的规则初筛、极简辩论、渐进校准和自动合并证据。
**Requirements:** R5
**Dependencies:** U3
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `config/performance/slo-policy.json`
- Modify: `docs/CONFIGURATION.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Modify: `docs/sandbox-simulation-report.md`
- Create: `scripts/tests/test-quick-channel-rollout-gate.sh`
- Modify: `scripts/tests/test-risk-check.sh`
- Modify: `scripts/tests/test-gateway-closeout-rejects-unexecuted-tests.sh`
- Modify: `scripts/tests/test-gateway-global-evaluation-warnings.sh`
- Modify: `scripts/tests/test-docs.sh`
**Approach:**
- 定义 quick/light/standard 三层通道的进入条件、跳过阶段和审查深度。
- 为快速通道落地“三层判定流程”：规则引擎初筛、1 轮极简辩论确认、Week 1-4 渐进校准。
- 将 Week 1-2 强制标准通道、Week 3 仅收敛规则、Week 4+ 条件启用 quick 的 rollout gate 写成可配置开关。
  - **"Week" 定义**: 自项目首次接入完成（U1 验收通过）起算的自然周；Week 1 为接入完成后第 1-7 天，以此类推。
- 将 auto_merge、notification、i18n key 检查、硬编码扫描、lint/基本语法验证写入证据门控。
- **auto_merge 安全控制**: `auto_merge=true` 时，目标分支必须为 `main` 之外的保护分支（如 `staging` / `quick-merge`），且必须满足：分支保护规则启用（需至少 1 条审查 + CI 通过）、存在回滚路径（`git revert` 或等价命令可达）、合并操作写入审计日志。
**Test scenarios:**
- 纯文案任务命中快速通道时无需完整六阶。
- 文案任务若触发敏感词或 PII 风险，必须降级到轻量或标准通道。
- 关闭 auto_merge 时，快速通道完成后必须停在显式确认点。
- 用户在 quick 路由前手动升级到 standard 时，必须绕过 quick gate 并记录原因。
**Verification:**
- 快速、轻量、标准三层通道完整定义且可配置，不能只存在 quick-channel。
- 快速通道严格执行“规则初筛 -> 极简辩论 -> 渐进校准”，且支持用户一键升级到标准通道。
- Week 1-2 / Week 3 / Week 4+ 的渐进校准节奏必须由 rollout gate 控制，在校准证据不足时强制走标准通道。
- 纯文案 quick task 通过 lint/基本语法/i18n key/硬编码扫描证据后，`auto_merge=true` 时默认自动合并；`silent/compact/verbose` 三种通知级别行为可验证。

### U5. 一阶方向辩论工单与团队策略引擎
**Goal:** 为方向辩论建立严格的工单契约和团队装配策略，让一阶能真正做“是否值得做”的前置拦截，而不是泛化成一份模糊报告。
**Requirements:** R6, R7
**Dependencies:** U4
**Files:**
- Modify: `scripts/lib/debate_assembly.py`
- Modify: `scripts/lib/debate_report.py`
- Modify: `config/debate/full/teams.json`
- Create: `config/debate/full/alias-mapping.json`
- Modify: `config/debate/full/assembly-policy.json`
- Modify: `docs/adr/0001-full-debate-package-team-registry.md`
- Modify: `docs/adr/0009-dynamic-debate-assembly-policy.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Create: `scripts/tests/test-debate-alias-mapping.sh`
- Create: `scripts/tests/test-debate-custom-team-guards.sh`
- Modify: `scripts/tests/test-debate-assembly.sh`
- Modify: `scripts/tests/test-gateway-config-registries.sh`
**Approach:**
- 定义方向辩论结构化工单字段，并区分硬约束与用户偏好/实现细节。
- 按任务类型和 `project-profile.yaml` 的 debate 配置选择 canonical/custom teams，并补齐旧别名兼容映射表。
- 为 custom team 的 `prompt_injection` 加安全红线校验，阻止覆盖核心安全约束。
  - **检测算法**: 对 `prompt_injection` 文本执行关键词 denylist 匹配（覆盖 SR-01~SR-05 关键词表）+ 语义匹配（embedding 相似度与已知安全绕过模式库比对，阈值 ≥ 0.75）；命中任意一条即拒绝加载。
- 让常规方向决策优先走 `dynamic_assembly + adversarial_debate`，需要 verdict 时补 `jury_panel`。
**Test scenarios:**
- 支付、合规、前端等不同任务类型触发不同团队组合。
- 自定义扩展团队必须声明 `extends` 且不能覆盖核心安全红线。
- 高置信度/低风险/无冲突的方向结论自动推进到二阶。
**Verification:**
- 一阶工单至少包含项目背景、目标、非目标、约束、验收标准、风险边界、失败策略。
- 团队选择策略支持 16 支 canonical 团队、扩展团队、旧别名兼容，并按 task type + project-profile 配置运行。
- 旧别名兼容必须以显式映射表实现，自定义团队的 `prompt_injection` 不能覆盖核心安全红线。
- 系统显式区分硬约束与用户偏好；方向结论高置信度、低风险、无冲突时自动进入二阶。

### U6. 二阶方案辩论模式策略与 DAG 生成
**Goal:** 把二阶方案辩论做成真正的路线选择器，明确模式选择逻辑、DAG 产物、同源隔离约束和进入三阶的自动门控。
**Requirements:** R8
**Dependencies:** U5
**Files:**
- Modify: `scripts/lib/debate_member_invocation.py`
- Modify: `scripts/lib/debate_backend_adapter.py`
- Modify: `scripts/lib/debate_report.py`
- Modify: `config/debate/full/modes.json`
- Modify: `docs/adr/0002-full-debate-package-mode-registry.md`
- Modify: `docs/gateway-integration-architecture.md`
- Modify: `scripts/tests/test-debate-member-invocation.sh`
- Modify: `scripts/tests/test-e2e-ai-debate-flow.sh`
- Modify: `scripts/tests/test-gateway-ai-integration.sh`
**Approach:**
1. **争议程度量化指标与 mode 选择矩阵**：

   | 争议得分 | 计算方式 | 选择 mode | 触发条件 |
   |---------|---------|----------|---------|
   | ≥ 0.80 | 不一致率 ≥ 80% | adversarial_debate | 高风险任务 + 观点分裂 |
   | 0.50 ~ 0.79 | 不一致率 50%~79% | parallel_debate | 多维度独立评审 |
   | 0.30 ~ 0.49 | 不一致率 30%~49% | risk_priority | 存在已知风险项 |
   | < 0.30 | 不一致率 < 30% | conflict_detector | 低争议，快速收敛 |

   争议得分计算: `dispute_score = 1 - (max_verdict_agreement / total_reviews)`

2. **DAG 正确性验证**: 拓扑排序检测环 + 连通性检测。DAG 中必须不存在环，且所有任务节点必须可从起始节点到达。任一检查失败时 Gateway 拒绝进入三阶并返回错误详情。
3. **同源隔离检测机制**: `delegate_task` 携带 `auditor_identity` 字段（值为 `kimi` / `claude` / `codex` / `human`），Gateway 在校验时检查该字段不得与上层裁决者的 identity 相同；若检测到同源审计，立即拒绝分派并记录安全事件。
**Test scenarios:**
- 路线争议大时自动选择 adversarial_debate。
- 多维度独立评审时自动选择 parallel_debate。
- 方案结论明确且依赖矩阵完整时无需额外人工确认即可进入三阶。
**Verification:**
- 二阶根据争议程度选择正确 canonical mode，而不是固定单一模式。
- 《具体实现报告》必须输出 DAG、任务输入输出、写入范围、并行边界、测试策略、依赖与冲突处理。
- `delegate_task` 明确同源隔离；方案结论明确且依赖矩阵完整时自动进入三阶。

### U7. Gateway Run Projection API 与六类状态投影
**Goal:** 以 Gateway 为状态权威补齐 Run Projection API 和六类实体投影，确保 Kimi 只能通过投影与决策推进流程，而不能直接改 Kanban 原始状态。
**Requirements:** R9
**Dependencies:** U6
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `docs/gateway-integration-architecture.md`
- Modify: `docs/FULL-COVERAGE-MATRIX.md`
- Modify: `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`
- Create: `scripts/tests/test-gateway-authority-matrix.sh`
- Modify: `scripts/tests/test-gateway-integration-points.sh`
- Modify: `scripts/tests/test-gateway-capabilities-authority-layers.sh`
- Modify: `scripts/tests/test-kanban-routing.sh`
- Modify: `scripts/tests/test-gateway-config-registries.sh`
**Approach:**
- 明确 Kimi-facing Run Projection API 的资源、操作、authority 和 response shape。
- 把 Run、Task、Artifact、Decision、Audit、Event 六类状态投影以及需求补全来源/置信度/冲突/依赖投影固化。
- 把 PRD §2.2 的权限边界矩阵落成显式 authority contract，并为“阻止 Kimi 直接改 Kanban 原始状态”加门控与测试。
**Test scenarios:**
- Run Projection API 返回完整六类实体视图。
- Kimi 试图绕过 Gateway 直写 Kanban 状态时被阻止。
- intake / debate / implementation / evaluation / closeout 的投影对象能够串成完整证据链。
**Verification:**
- Gateway 暴露 Kimi-facing Run Projection API，并持久化 Run、Task、Artifact、Decision、Audit、Event 六类投影。
- 需求补全的来源、置信度、冲突和依赖投影可通过状态接口查询。
- PRD §2.2 权限矩阵必须显式覆盖 create run、补全需求、修改 Kanban 原始状态、推进阶段、选择辩论团队、编码/审查、L3/L4 审批、经验沉淀八类权限。
- Kimi 不能直接修改 Kanban 原始状态，Claude/Codex 不能越权推进阶段，所有状态推进都必须经过 Gateway authority 校验。
- **Actor 认证机制**: Kimi/Claude/Codex/Human 的身份通过 API key + 签名 token 认证；L3/L4 审批者通过审批流中的 `approver_identity` 字段识别。签名 token 使用 HMAC-SHA256，密钥由 Gateway 统一签发并设置过期时间。
- **权限授予与撤销**: 通过 `authority_matrix` 的 `allowed` + `route` 字段管理。授予时设置 `allowed=true` 并绑定 `route`（如 `gateway:kanban:write`）；撤销时设置 `allowed=false` 并记录 `block_reason`（如 `scope_violation`、`manual_revoke`、`expired`）。变更记录追加写入 `audit/authority-changelog.jsonl`。
- **"Kimi 不能直写 Kanban" 的正确 enforce 方式**: Kanban 层增加 access control model，所有写入必须经过 Gateway authority 校验。写入前校验 actor 的 capability：
  1. 检查 actor 的 `authority_matrix` 中 `route=gateway:kanban:write` 且 `allowed=true`；
  2. 检查操作是否在 actor 的 `write_scope` 内；
  3. 对 protected target 额外检查 `approval_ref`（`kimi_review_ref` + `human_approval_ref`）；
  4. 任一项不满足时 OS/FS 层拒绝写入，Gateway 返回 403 并记录安全审计事件。

### U8. 三阶分派执行、工作区隔离与证据门控
**Goal:** 把三阶执行收紧为受控分派流程，明确 Gateway/Kanban authority、worker 生命周期、独立 workspace、写入范围、测试与审查证据门控。
**Requirements:** R10
**Dependencies:** U7
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/lib/worker_session.py`
- Modify: `scripts/lib/worker_session_sweeper.py`
- Modify: `docs/gateway-integration-architecture.md`
- Modify: `scripts/tests/test-worker-session.sh`
- Modify: `scripts/tests/test-project-isolation.sh`
- Modify: `scripts/tests/test-gateway-worker-output-write-scope-violation.sh`
- Modify: `scripts/tests/test-gateway-worker-output-evidence-missing.sh`
- Modify: `scripts/tests/test-kanban-handoff.sh`
**Approach:**
- 将所有执行任务分派都收敛到 Gateway/Kanban 路由，禁止其他入口直接写任务状态。
- 要求每个 worker session 具备独立 workspace 或等价隔离、独立 write scope 和上下文 bundle。
- 将写入范围、证据引用、测试结果、审查输出校验变成阶段推进前置门。
**Test scenarios:**
- worker 输出缺少测试证据时不能推进阶段。
- write scope 超范围时 Gateway 立即拒绝。
- session 超时、缺失或隔离失败时 sweeper 能正确回收。
**Verification:**
- 三阶执行任务只能通过 Gateway/Kanban 分派，Claude/Codex 无法绕过 authority 直接推进。
- 每个代理都有独立 workspace 或等价上下文隔离，并带有 write scope 与 context bundle 记录。
- Gateway 必须校验写入范围、证据引用、测试结果、审查输出；无证据的完成声明不得推进阶段。
- **Write scope 自证漏洞修复**: worker 自报的 write scope 不可信。Gateway 必须在分派前根据 task 类型和文件树计算 `expected_write_scope`（基于 task 的 `file_patterns` + `dependency_graph` 推导）；执行完成后对比实际修改文件与 `expected_write_scope`。若实际修改超出预期范围，立即标记为 `scope_violation`，拒绝阶段推进并触发安全审计。
- **分派流程技术强制力**: Gateway 通过 `worker_session` 的 context bundle 限制文件系统访问。context bundle 中必须包含 `allowed_paths`（基于 `expected_write_scope` 的绝对路径列表），worker 启动时由 OS 层（如 Linux namespaces / chroot / bind mount 白名单）强制执行。越 scope 写入时 OS 层拒绝（返回 `EPERM`/`EACCES`），worker 无法通过任何应用层手段绕过。

### U9. 三阶心跳、实时快照与并行写集策略
**Goal:** 消除三阶长时静默和并行写冲突，要求执行期间输出结构化心跳、支持快照查询，并为并行任务声明 disjoint write set 或显式合并策略。
**Requirements:** R11
**Dependencies:** U8
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `docs/sandbox-simulation-report.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Modify: `scripts/tests/test-gateway-events-sse.sh`
- Modify: `scripts/tests/test-gateway-events-pagination.sh`
- Modify: `scripts/tests/test-gateway-events-rebuild.sh`
- Modify: `scripts/tests/test-e2e-ai-worker-flow.sh`
- Modify: `scripts/tests/test-backpressure-basic.sh`
**Approach:**
1. **心跳协议 schema**: `worker_session_record` 必须包含以下字段：
   - `heartbeat_at`: ISO8601 时间戳（UTC），精确到毫秒；
   - `heartbeat_seq`: 递增整数，从 1 开始，每次心跳 +1，用于检测丢包或乱序；
   - `status`: 枚举值 `idle` / `running` / `blocked`，分别表示空闲、执行中、阻塞等待；
   - `progress_pct`: 整数 0-100，表示当前任务整体进度百分比。

   心跳缺失或 `heartbeat_seq` 出现回退/跳跃时，Gateway 标记该 session 为 `suspect` 并立即触发探测。
2. **心跳超时检测与 sweeper 调度**: sweeper 每 60 秒扫描一次所有 `running` 状态的 worker session。
   - 心跳缺失超过 90 秒（3 个心跳周期）标记为 `stale`，Gateway 暂停向该 session 分派新子任务，并尝试通过侧信道探测（如查询 worker 的 HTTP health endpoint）；
   - 心跳缺失超过 180 秒强制回收 session：终止 worker 进程、释放 workspace、将未完成任务重新入队，并记录 `session_forcibly_recovered` 审计事件。
3. **write set 格式与验证算法**: write set 为 JSON 对象：
   ```json
   { "paths": ["rel/path/1", "rel/path/2"], "normalized": true }
   ```
   - 路径必须经 `realpath` 归一化（消除 `.` / `..` / 符号链接），且为相对于项目根目录的相对路径；
   - 验证冲突时，两个 write set 取路径交集，交集非空即判定为冲突；
   - 冲突检测必须在任务分派前完成，冲突时根据 `merge_strategy` 决定处理方式。
4. **merge strategy 枚举**: `merge_strategy` 必须是以下之一：
   - `sequential`：串行执行，后任务等待前任务完成，无需 write set 不相交；
   - `branch_merge`：分支合并，各任务在独立分支执行，完成后通过 PR/MR 合并，需定义合并顺序与冲突解决策略；
   - `overwrite_with_backup`：覆盖但备份，后任务的写入覆盖前任务结果，但 Gateway 必须先创建备份快照（`backup_ref`），覆盖操作写入审计日志；
   - `abort_on_conflict`：冲突时中止，分派前检测到 write set 交集非空时立即中止并行配置，降级为 `sequential` 或返回错误等待人工决策。
**Test scenarios:**
- 长任务执行超过 30 秒时仍能持续输出进度摘要。
- 用户在执行中发起状态查询，不会中断 worker。
- 并行任务未声明 disjoint write set 或 merge strategy 时直接阻塞。
**Verification:**
- 执行期间每 30 秒或每完成一个子任务发送结构化心跳，包含阶段、完成数、进行中任务、预计剩余时间、阻塞状态。
- 用户可随时查询实时快照而不中断执行。
- 并行任务必须声明 disjoint write set 或显式 merge strategy，否则不得进入执行。

### U10. 四阶改进分类、回归上限与争议裁决
**Goal:** 把四阶从“收到 review 再修”细化为带问题分类、回归预算、争议裁决和范围控制的明确闭环。
**Requirements:** R12
**Dependencies:** U9
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Modify: `scripts/tests/test-gateway-review-verdict-improvement-budget.sh`
- Modify: `scripts/tests/test-gateway-review-verdict-request-changes.sh`
- Modify: `scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
- Modify: `scripts/tests/test-gateway-qa-verdict-block-kimi.sh`
**Approach:**
- 把 review/qa 反馈映射成 A-E 五类问题，并为每类定义处理动作。
- 用 improvement cycle 记录回归预算，达到第 3 次失败时强制上浮。
- 对评审争议引入 2 轮 mini-debate，对超范围修复引入 blocked + new run/subtask 路径。
**Test scenarios:**
- A 类问题能够自动修复并复测闭环。
- D 类回归在第 3 次失败后不再自动重试。
- E 类争议 2 轮后仍未达成一致时转 Kimi/用户决策。
**Verification:**
- 四阶完整落地 A-E 五类问题分类，每类都有明确处理路径。
- 回归循环最多 3 次，第 3 次失败必须上浮“接受 / 回滚 / 重设计”决策。
- 评审争议触发 2 轮 mini-debate；超范围修复由 Gateway 阻塞并生成子任务或新 Run。

### U11. 五阶八维评估、残余风险通知与 authority routing
**Goal:** 将五阶从“汇总测试结果”升级为跨维度 verdict 体系，补齐 8 维评估、mode 选择、`pass_with_warnings` 风险摘要和最终 authority routing。
**Requirements:** R13
**Dependencies:** U10
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/bin/orch-mvp-wizard`
- Modify: `config/debate/full/coverage-policy.json`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Create: `scripts/tests/test-gateway-global-evaluation-notification-levels.sh`
- Modify: `scripts/tests/test-gateway-global-evaluation-pass.sh`
- Modify: `scripts/tests/test-gateway-global-evaluation-warnings.sh`
- Modify: `scripts/tests/test-gateway-global-evaluation-fail-blocks.sh`
- Modify: `scripts/tests/test-gateway-global-evaluation-block-human-approval.sh`
- Modify: `scripts/tests/test-gateway-global-evaluation-final-acceptance.sh`
**Approach:**
- 固定 8 维评估维度与报告结构，并把维度覆盖结果映射回验收矩阵。
- 为 `jury_panel`、`meta_review`、`cross_team_conflict_detector` 定义触发场景。
- 将 `pass_with_warnings` 的残余风险排序、通知级别与 authority routing 写入 Gateway 决策逻辑。
**Test scenarios:**
- pass 场景自动进入六阶。
- pass_with_warnings 但中高风险未超阈值时自动通过并通知。
- fail / block / acceptance_required 必须阻塞等待决策。
**Verification:**
- 五阶至少覆盖业务目标、补全正确性、安全合规、质量、性能、可维护性、文档、可观测性 8 个维度。
- `jury_panel`、`meta_review`、`cross_team_conflict_detector` 按场景使用，而不是固定或缺失。
- `pass_with_warnings` 按高/中/低排序摘要残余风险；`none/summary/full` 通知级别与 block/fail authority routing 明确可配且行为可验证。

### U12. 六阶审计沉淀与 protected target 审批
**Goal:** 把六阶做成真正的“可审计可进化”收尾阶段，补齐审计输入范围、建议落地队列和 protected target 审批边界。
**Requirements:** R14
**Dependencies:** U11
**Files:**
- Modify: `scripts/lib/self_evolution.py`
- Modify: `config/evolution/self-evolution-review-queue.json`
- Modify: `docs/FULL-COVERAGE-MATRIX.md`
- Modify: `docs/sandbox-simulation-report.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Modify: `scripts/tests/test-self-evolution.sh`
- Modify: `scripts/tests/test-gateway-closeout-forbidden-proposal.sh`
- Modify: `scripts/tests/test-gateway-closeout-completes-run.sh`
- Modify: `scripts/tests/test-gateway-closeout-summary-alone-rejected.sh`
- Modify: `scripts/tests/test-full-contract-validation.sh`
**Approach:**
1. **Self-evolution queue 持久化**: queue 必须写入磁盘（`config/evolution/self-evolution-review-queue.jsonl`）。每次 enqueue/dequeue/transition 都追加写入 JSONL，格式为：
   ```jsonl
   {"timestamp":"...","action":"enqueue","item_id":"...","state":"pending","payload":{...}}
   ```
   重启时从文件恢复：按行读取，去除最后一个未完整行（若有），按 `item_id` 去重后恢复内存队列。文件必须配置定期备份（每 24h 滚动备份）。
2. **六阶审计输入完整性校验**: closeout 必须校验 7 类审计输入的存在性：
   - 日志文件（`run.jsonl` / `events.jsonl`）；
   - 补全包 JSON（`requirements-completion-package.json`）；
   - 工具调用记录（`tool-calls.jsonl`）；
   - 错误栈（`error-stack.jsonl`）；
   - 审查记录（`review-records.json`）；
   - closeout artifacts（`closeout-report.json` + `success-metrics-summary.json`）；
   - success metrics summary（必须包含 0→6 阶每阶的采集字段、聚合值与阈值对比）。
   缺少任意一类时，closeout 不得完成，Gateway 返回 422 并列明缺失清单。
3. **protected target 强制审批**: 对 protected target 强制走 Kimi review + Human Approval，不允许 auto-apply。
**Test scenarios:**
- protected target proposal 无审批引用时被拒绝。
- closeout 缺少 improvement proposals 或完整证据时不能完成。
- 审计建议必须保留来源、置信度、适用边界，避免把偶然成功写成通用规则。
**Verification:**
- 六阶审计读取完整日志、补全包、工具调用、错误栈、审查记录，并为经验保留来源、置信度、适用边界。
- protected target 必须走 Kimi review + Human Approval，不能自动落地。
- 审计建议必须区分“已落地 / 待审 / 拒绝”，并可通过 closeout / self-evolution queue 回溯。

### U13. 成功指标采集、Schema 一致性与 0→6 阶严格回归
**Goal:** 为 PRD 第 11 章成功指标补齐事件采集与汇总验证，并把 0→6 阶完整闭环、schema 文档一致性和 staging 严格回归绑定成上线前 gate。
**Requirements:** R14
**Dependencies:** U12
**Files:**
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/bin/orch-audit`
- Modify: `scripts/bin/orch-verify`
- Modify: `config/performance/slo-policy.json`
- Modify: `config/schemas/orchestra.full.schema.json`
- Modify: `docs/FULL-COVERAGE-MATRIX.md`
- Modify: `docs/sandbox-simulation-report.md`
- Modify: `docs/user-flow-guide_by_kimi.md`
- Create: `scripts/tests/test-success-metrics-pipeline.sh`
- Create: `scripts/tests/test-schema-doc-sync.sh`
- Create: `scripts/tests/test-e2e-strict-six-stage-flow.sh`
- Modify: `scripts/tests/test-performance-slo.sh`
- Modify: `scripts/tests/test-mvp-acceptance.sh`
- Modify: `scripts/tests/test-mvp-wizard-demo-run.sh`
- Modify: `scripts/tests/test-mvp-wizard-real-worker-demo.sh`
- Modify: `scripts/tests/test-gateway-mvp-acceptance-artifacts.sh`
- Modify: `scripts/tests/test-gateway-events-rebuild.sh`
**Approach:**
- 为 PRD 第 11 章成功指标定义 event/log 字段、聚合口径、阈值和 staging 校验方法，而不止停留在文档定义。
- 把 schema.md 与 `config/schemas/orchestra.full.schema.json` 的一致性校验变成 CI gate。
- 把 0→6 阶完整闭环回放绑定为上线前严格回归，包括 intake、direction、solution、implementation、improvement、global evaluation、closeout。
**Test scenarios:**
- staging/harness 回放一条完整 six-stage run，输出完整 artifacts、events、audit、metrics 汇总。
- schema 文档字段变更但未同步 schema.json 时，CI 必须失败。
- success metrics pipeline 缺少事件字段、阈值或汇总逻辑时，closeout 不得宣称满足 PRD 成功标准。
**Verification:**
- PRD 第 11 章每项成功指标都必须对应已实现的采集字段、聚合逻辑、阈值和验证脚本，而不是只定义口径。
- schema.md 与 `config/schemas/orchestra.full.schema.json` 必须保持一致，并有自动化校验。
- 0→6 阶严格闭环回归在 staging/harness 下可跑通，并产出可回放的 artifacts、events、audit 和 metrics summary。

- **staging/harness 环境定义**: 需要定义 staging 环境配置（`config/testing/staging-env.yaml`）、mock 策略、数据准备脚本、清理策略：
  - **staging-env.yaml** 必须包含：环境名称、基地址、数据库连接串（不得使用生产环境 DB）、外部服务 mock 列表、清理策略；
  - **mock 策略**：对 LLM API 使用 vcr.py / betamax 录制回放，对数据库使用 SQLite in-memory / testcontainers，对文件系统使用 tmpfs + 每次测试后强制清理；
  - **数据准备脚本**：`scripts/tests/setup-staging.sh` 负责初始化 staging 数据（seed data、mock user 、mock project-profile），`scripts/tests/teardown-staging.sh` 负责清理；
  - **清理策略**：每次测试结束后必须执行 teardown，确保不留下残余数据、不泄露敏感信息。
