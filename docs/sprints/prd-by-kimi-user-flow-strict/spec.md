# Hermes Dev Orchestra 功能规格说明

## 概述

本规格说明对应 `docs/prd_by_kimi.md`、`docs/sandbox-simulation-report.md`、`docs/user-flow-guide_by_kimi.md` 的修复后严格实施版。
本轮在原 strict 版基础上补齐了 4 个关键缺口：权限矩阵显式验收、快速通道渐进校准 gate、成功指标采集管道，以及 0→6 阶严格闭环回归。

## 功能需求

### FR-1: 新项目接入与 Gateway seam 抽取
- **描述**: 首次使用时自动探测技术栈、测试命令、部署目标、风险标志，并优先把 Gateway 的 intake/projection/evidence 逻辑抽到 helper modules，降低后续改单点文件的风险。
- **验收标准**: 接入流程可生成《项目探测报告》、`.hermes/project-profile.yaml`、`AGENTS.md`、`SOUL.md`；新增 Gateway 逻辑优先进入 helper modules。
- **优先级**: P0

### FR-2: 需求补全包与四维依赖图
- **描述**: 每次任务输出《需求补全包》，显式区分 6 类信息，并保证依赖图覆盖环境依赖、上游依赖、下游影响、代码依赖四个维度。
- **验收标准**: 缺任一类信息、缺依赖图四维之一、缺验收矩阵或 prompt envelope 都必须阻塞。
- **优先级**: P0

### FR-3: 0 阶双模式与两轮纠错
- **描述**: 0 阶支持 compact/verbose 双模式、短意图解析、确认节点清单和两轮渐进纠错/Override/审批留痕。
- **验收标准**: 第二轮纠错后仍坚持必须产生 Override 或审批记录；不得静默推进高风险错误决策。
- **优先级**: P0

### FR-4: 三层通道与渐进校准 rollout gate
- **描述**: 实现 quick/light/standard 三层通道，并将 Week 1-2/Week 3/Week 4+ 的渐进校准节奏做成可配置 rollout gate。
- **验收标准**: 在校准证据不足时必须强制走标准通道；用户可一键升级为标准通道；`silent/compact/verbose` 通知行为可验证。
- **优先级**: P0

### FR-5: 一阶方向辩论工单、别名映射与自定义团队防护
- **描述**: 一阶方向辩论必须使用结构化工单，支持 canonical/custom teams、legacy alias mapping，并校验 `prompt_injection` 不覆盖安全红线。
- **验收标准**: 工单字段完整；alias mapping 显式存在；恶意 `prompt_injection` 被阻止。
- **优先级**: P0

### FR-6: 二阶方案辩论与 DAG
- **描述**: 根据争议程度选择 canonical mode，输出 DAG、写入范围、并行边界、测试策略，并声明 delegate_task 同源隔离。
- **验收标准**: 缺 DAG、写入范围、测试策略或同源隔离声明时不通过。
- **优先级**: P0

### FR-7: Gateway Run Projection API 与权限矩阵
- **描述**: Gateway 作为状态权威，提供 Run Projection API，保存六类投影实体，并把 PRD §2.2 的权限边界表落成显式 authority contract。
- **验收标准**: 权限矩阵至少覆盖 create run、补全需求、修改 Kanban 原始状态、推进阶段、选择辩论团队、编码/审查、L3/L4 审批、经验沉淀。
- **优先级**: P0

### FR-8: 三阶分派执行与证据门控
- **描述**: 三阶执行只能通过 Gateway/Kanban 分派，worker 具备独立 workspace/上下文隔离，完成声明必须带 write scope、测试与审查证据。
- **验收标准**: 缺证据、越 write scope、越权推进都必须被 Gateway 拒绝。
- **优先级**: P0

### FR-9: 执行心跳、实时快照与并行写集
- **描述**: 三阶执行期间每 30 秒或每完成一个子任务输出结构化心跳，支持实时快照查询，并强制声明并行写集策略。
- **验收标准**: 用户可查询实时状态；未声明 disjoint write set 或 merge strategy 的任务不得执行。
- **优先级**: P0

### FR-10: 四阶改进分类与争议裁决
- **描述**: 四阶完整实现 A-E 五类问题分类、最多 3 次回归循环、2 轮 mini-debate 与超范围修复阻塞。
- **验收标准**: 第 3 次回归失败必须上浮；争议未收敛必须转 Kimi/用户裁决。
- **优先级**: P0

### FR-11: 五阶八维评估与 warnings 通知级别
- **描述**: 五阶评估覆盖 8 维，按场景使用 `jury_panel` / `meta_review` / `cross_team_conflict_detector`，并支持 `none/summary/full` warnings 通知级别。
- **验收标准**: 残余风险必须高/中/低排序；通知级别行为可验证；`fail/block` 必须正确 authority routing。
- **优先级**: P0

### FR-12: 六阶审计沉淀与 protected target 审批
- **描述**: 六阶读取完整审计输入，保留来源/置信度/适用边界，并通过 self-evolution queue 管理建议落地；protected target 需 Kimi review + Human Approval。
- **验收标准**: protected target 不可 auto-apply；建议需区分已落地/待审/拒绝状态。
- **优先级**: P0

### FR-13: 成功指标采集、Schema 一致性与 0→6 阶严格回归
- **描述**: 为 PRD 第 11 章成功指标补齐事件采集、聚合逻辑、阈值验证，并把 schema 文档一致性与 0→6 阶严格闭环回归绑定为上线 gate。
- **验收标准**: 每项成功指标都有采集字段、聚合逻辑、阈值与验证脚本；schema.md 与 schema.json 自动校验一致；strict six-stage flow 可回放。
- **优先级**: P0

## 非功能需求

- **性能**: quick channel 极简确认需受时间阈值约束；执行心跳不得低于每 30 秒一次。
- **安全**: Kimi 不得绕过 Gateway 改 Kanban 原始状态；custom team `prompt_injection` 不得覆盖安全红线；protected target 强制审批。
- **Actor 认证**: 每个权限判断必须携带主体身份凭证（`actor_id` + `actor_type` + `session_token`）。Gateway 在放行任何 `mutate_kanban_raw_state`、`advance_stage`、`approve_l3_l4` 操作前，必须校验 actor 在 authority_matrix 中的存在性与 `allowed=true` 状态；未通过认证的主体一律路由到 `block_reason: unauthenticated_actor`。
- **兼容性**: 支持 legacy alias，但 canonical team/mode id 以 `config/debate/full/*` 为准。
- **可审计性**: 每个关键结论、权限判断、阶段推进、success metric 聚合都必须有回放路径。

## 接口契约

### API 端点
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/orchestra/runs` | 创建 intake / run |
| POST | `/orchestra/decisions/approve` | 处理 intake/global evaluation/protected target 审批 |
| POST | `/orchestra/runs/{run_id}/global-evaluation` | 提交五阶评估 |
| POST | `/orchestra/runs/{run_id}/closeout` | 提交六阶 closeout 与建议 |
| GET/POST | `/orchestra/runs/{run_id}/projection` | 读取或刷新 Run Projection |
| POST | `/orchestra/modules/*` | Gateway 内部模块调用入口 |

### 数据模型
| 实体 | 核心字段 | 说明 |
|------|----------|------|
| `project_profile` | `intake`, `quick_channel`, `evaluation`, `debate`, `protected_targets` | 项目画像与策略 |
| `intake_package` | `original_intent`, `system_completion`, `verified_facts`, `unverified_assumptions`, `conflicts`, `dependency_graph`, `acceptance_matrix`, `prompt_envelope` | 0 阶补全包 |
| `authority_matrix` | `actor`, `capability`, `allowed`, `route`, `block_reason` | PRD §2.2 权限边界表 |
| `run_projection` | `run`, `tasks`, `artifacts`, `decisions`, `audits`, `events` | Kimi-facing 投影视图 |
| `success_metrics_summary` | `metric_id`, `source_events`, `aggregation_rule`, `threshold`, `status` | PRD §11 成功指标汇总 |
| `merge_strategy` | `strategy`, `fallback`, `disjoint_write_set_verified` | 并行写集合并策略，见下方枚举 |
| `worker_heartbeat` | `heartbeat_at`, `heartbeat_seq`, `status`, `progress_pct` | 执行期间结构化心跳 |
| `write_set` | `files`, `checksums`, `scope`, `disjoint_verified` | 任务声明的写入范围与校验 |

#### Merge Strategy 枚举
`merge_strategy` 必须显式声明以下四种策略之一，且未声明或验证失败时 Gateway 必须拒绝执行：

| 枚举值 | 适用场景 | 回退行为 |
|--------|----------|----------|
| `sequential` | 单 worker、无并行写冲突风险 | 无需回退，直接顺序提交 |
| `branch_merge` | 多 worker、写集已验证为 disjoint | 若合并冲突，回退到 `abort_on_conflict` |
| `overwrite_with_backup` | 允许覆盖但必须保留备份 | 备份写入失败时回退到 `abort_on_conflict` |
| `abort_on_conflict` | 任何冲突必须人工介入 | 直接中断任务，路由到 Kimi/用户裁决 |

### 跨 Sprint 接口契约
U10（六阶审计沉淀）→ U11（成功指标采集）→ U12（0→6 阶严格回归）之间必须满足以下输出/输入格式约束：

| 上游 Sprint | 输出产物 | 下游 Sprint | 输入要求 |
|-------------|----------|-------------|----------|
| U10 | `audit.jsonl`（含 `source`、`confidence`、`applicability_boundary`、`kimi_review_ref`、`human_approval_ref`） | U11 | 必须读取 U10 的 `audit.jsonl` 作为 success metrics 的事件来源之一；缺少 `human_approval_ref` 的 protected target 变更不得纳入指标计算 |
| U10 | `self_evolution_queue`（状态：`applied` / `pending` / `rejected`） | U11 | 仅统计 `status=applied` 的建议作为"改进落地率"分子 |
| U11 | `success_metrics_summary.json`（含 `metric_id`、`observed_value`、`threshold`、`status`） | U12 | 必须作为回归 gate 的准入数据；任何 `status=fail` 的指标必须阻塞进入严格回归阶段 |
| U11 | `schema_consistency_report`（`schema.md` vs `schema.json` 差异列表） | U12 | 差异列表非空时必须阻塞回归执行，必须先修复 schema 不一致 |

## 范围边界

### 包含
- 0 阶补全与项目接入。
- 一阶/二阶辩论策略、别名映射、自定义团队防护、DAG、同源隔离。
- 三阶 Gateway 分派、worker 隔离、心跳、并行写集、authority contract。
- 四阶改进闭环、五阶八维评估、六阶审计沉淀。
- 成功指标采集与 strict six-stage 回归。

### 不包含
- 业务领域功能本身。
- 将 Gateway 改造成新的远程持久化服务。
- 引入新的数据库表迁移。
- 在未审批情况下自动修改 protected target。

### Protected Target 完整分类
`protected_targets` 共 11 个类别，任何匹配以下 pattern 的文件或配置变更都必须经过 Kimi review + Human Approval（L4），且不可 auto-merge：

| 类别 | Pattern 示例 | 审批级别 | 是否允许 auto-merge |
|------|-------------|----------|-------------------|
| `k8s_production` | `k8s/production/.*` | L4 | 否 |
| `database_schema` | `db/migrations/.*` | L4 | 否 |
| `auth_identity` | `auth/.*`、`iam/.*` | L4 | 否 |
| `api_contract` | `api/.*`、`openapi/.*` | L4 | 否 |
| `financial_ledger` | `ledger/.*`、`billing/.*` | L4 | 否 |
| `legal_compliance` | `compliance/.*`、`legal/.*` | L4 | 否 |
| `core_business_logic` | `domain/.*`、`core/.*` | L4 | 否 |
| `iam_secrets` | `secrets/.*`、`\.env.*`、vault 路径 | L4 | 否 |
| `infrastructure` | `terraform/.*`、`infra/.*`、CI/CD pipeline | L4 | 否 |
| `payment_compliance` | `payment/.*`、`pci/.*`、`checkout/.*` | L4 | 否 |
| `gateway_seam` | `gateway/.*`、`orchestra/.*` | L4 | 否 |

> 注：`auto_merge=true` 仅对非 protected target 的变更生效；任何 protected target 的 PR 必须开启分支保护（require review + status checks）并写入审计日志。

## 风险与依赖

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Gateway 单文件继续膨胀 | 实施冲突与回归风险高 | 提前抽 helper seams，新增逻辑优先外置 |
| quick channel 过早启用 | 高风险任务误走快通道 | rollout gate 强制标准通道期 + 校准证据 |
| success metrics 只有定义没有数据 | 无法证明满足 PRD §11 | 新增 metrics pipeline 与 staging 验证 |
| schema 文档与实现漂移 | 文档错误引导开发 | 增加 schema doc sync 校验 |
| 只有单点测试没有闭环回归 | 组装后链路断裂 | 新增 strict six-stage e2e gate |
| staging/harness 环境缺失 | 无法在隔离环境中验证 protected target 变更、success metrics 采集及严格回归 | Sprint 启动前必须完成 `.test-venv/` 与临时 namespace 搭建；关键变更必须先经 harness 验证再进入主分支 |
