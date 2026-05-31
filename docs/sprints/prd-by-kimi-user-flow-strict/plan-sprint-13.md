# Sprint 13 Plan

**总故事点**: 5 SP / 7 SP 容量  
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U13 | 成功指标采集、Schema 一致性与 0→6 阶严格回归 | 5 | U12 | ⬜ |

## 详细说明

### Task 1 (U13): 成功指标采集、Schema 一致性与 0→6 阶严格回归

- **目标**: 为 PRD 第 11 章成功指标补齐事件采集与汇总验证，并把 0→6 阶完整闭环、schema 文档一致性和 staging 严格回归绑定成上线前 gate。

#### 技术方案要点

- **数据流**: Gateway 状态流转时写入 `events.jsonl` → `orch-audit` 按日/周/月聚合 → 输出 `metrics_summary.json` → `orch-verify` 在 staging 环境对比阈值 → 不达标则 closeout 标记失败 → CI gate 拦截合并。
- **状态机**: `metrics_pipeline_initialized` → `events_collected` → `aggregated` → `threshold_verified` → `{pass | fail}` → `gate_decision`。
- **接口契约**: `scripts/bin/orch-audit` 接收 `--run-id` 和 `--output metrics_summary.json`；`scripts/bin/orch-verify` 接收 `--metrics metrics_summary.json` 和 `--thresholds config/performance/slo-policy.json`。

#### 验收标准

- **AC-1**: PRD 第 11 章每项成功指标都必须内联到实现中，对应采集字段、聚合逻辑、阈值和验证脚本。
  - 必须内联 PRD §11.1 的 14 项指标清单（详见下文「PRD §11.1 指标清单内联」）。
  - 每项指标在 `config/performance/slo-policy.json` 中有明确的 `metric_id`、`source_events[]`、`aggregation_rule`、`threshold`、`validation_script_ref`。
  - `scripts/tests/test-success-metrics-pipeline.sh` 必须能独立运行并验证所有指标的事件字段存在性、聚合结果正确性和阈值通过/失败行为。
- **AC-2**: `schema.md` 与 `config/schemas/orchestra.full.schema.json` 必须保持一致，并有自动化校验。
  - 建立三重一致性校验方案：`schema.md`（人类可读文档）↔ `schema.json`（机器校验 schema）↔ `orch_gateway.py` 实现（运行时校验逻辑）。
  - `scripts/tests/test-schema-doc-sync.sh` 自动化校验规则：
    1. `schema.md` 中每个数据模型表格的字段名必须在 `schema.json` 的 `properties` 中存在（名称一致）。
    2. `schema.json` 中每个字段的 `type` 必须与 `schema.md` 中声明的类型一致。
    3. `orch_gateway.py` 中所有硬编码字段名必须能在 `schema.json` 中找到对应定义（通过 AST 扫描或反射）。
    4. 校验失败时脚本返回非 0 退出码，并输出差异报告（缺失字段、类型不一致、实现漂移列表）。
  - 该校验必须绑定到 CI gate，每次 PR 自动运行，失败时阻止合并。
- **AC-3**: 0→6 阶严格闭环回归在 staging/harness 环境下可跑通。
  - 必须定义 staging/harness 环境（详见下文「Staging / Harness 环境定义」），包含 IaC 配置和数据注入脚本。
  - `scripts/tests/test-e2e-strict-six-stage-flow.sh` 必须在 staging 环境下完整回放一条 0→6 阶 Run：intake → direction → solution → implementation → improvement → global evaluation → closeout。
  - 回放必须产出可验证的 artifacts：`run.json`、`tasks.json`、`events.jsonl`、`audit.jsonl`、`metrics_summary.json`。
  - 每项产出必须通过 schema 校验和完整性断言。
- **AC-4**: 上线 Gate 必须绑定 strict six-stage 回归结果。
  - 只有当 `test-e2e-strict-six-stage-flow.sh`、`test-schema-doc-sync.sh`、`test-success-metrics-pipeline.sh` 全部通过时，才允许标记 closeout 为"满足 PRD 成功标准"。
  - 任一测试失败时，closeout 必须标记为 `gate_failed`，并输出失败项清单与修复指引。

#### 负向用例

- **NC-1**: `metrics_summary.json` 中某项指标聚合结果低于阈值，但 `orch-verify` 仍返回 0 → 必须被测试脚本捕获并标记为阈值校验失效。
- **NC-2**: `schema.md` 新增字段但未同步到 `schema.json`，CI gate 未拦截 → 必须被 `test-schema-doc-sync.sh` 捕获并阻止合并。
- **NC-3**: staging 环境缺少数据注入脚本，导致 e2e 回归因无项目数据而跳过 intake 阶段 → 必须被环境就绪检查拦截，回归不得标记为通过。
- **NC-4**: `orch_gateway.py` 实现中使用了硬编码字段名 `legacy_run_status`，但该字段在 `schema.json` 中已移除 → 必须被 AST 扫描捕获并报告为 schema 实现漂移。

#### 架构红线合规项

- [ ] 所有新增脚本必须支持独立运行（不依赖未安装的外部服务），并通过 `set -euo pipefail` 保证错误即停。
- [ ] Staging 环境定义文件必须受版本控制，环境搭建脚本必须幂等（多次运行结果一致）。
- [ ] Schema 三重一致性校验必须零人工介入，纯自动化运行。

#### 文档更新要求

- [ ] 更新 `docs/user-flow-guide_by_kimi.md`：补充成功指标采集管道使用说明、staging 环境搭建指南、schema 同步校验流程。
- [ ] 更新 `docs/FULL-COVERAGE-MATRIX.md`：补充 S13 上线 Gate 覆盖的测试项与指标映射。
- [ ] 更新 `docs/sandbox-simulation-report.md`：补充 staging 回归在沙箱中的验证方法与数据注入示例。

#### 跨 Sprint 接口契约

- **输入**（来自 U12）: `closeout_report`（含 `audit_checklist_passed`、`proposals[]`、`metrics_summary_ref`）。
- **输出**（作为项目最终交付）: `release_gate_report`（含 `strict_six_stage_passed`、`schema_sync_passed`、`metrics_pipeline_passed`、`release_approved`）。
- **格式约束**: `release_gate_report` 中所有布尔项为 true 时，`release_approved` 才能为 true；任一 false 时，`release_approved` 必须为 false，且 `block_reasons[]` 必须非空。

---

#### PRD §11.1 指标清单内联

| 指标 | 对应事件类型 | 采集字段 | 聚合规则 | 阈值 |
|------|-------------|----------|----------|------|
| 用户只输入目标即可启动 | `run.created` | `has_intent_only: bool`, `hydration_time_ms` | 月度占比：intent_only / total_runs ≥ 85% | ≥ 85% |
| 自动补齐环境/上下游/隐性约束 | `intake.completed` | `has_env_deps`, `has_upstream`, `has_downstream`, `has_implicit`, `has_acceptance_matrix` | 月度占比：四项全 true / total_intake ≥ 90% | ≥ 90% |
| 信息损失/冲突覆盖减少 | `conflict.resolved` | `resolution`, `severity`, `auto_resolved_rate` | 月度 auto_resolved / total_conflicts ≥ 70% | ≥ 70% |
| 一阶/二阶拦截错误方向 | `direction_debate.blocked` + `solution_debate.blocked` | `reason: direction_error / route_error` | 月度拦截数 ≥ 1 | ≥ 1 |
| 三阶输出有完整证据 | `implementation.completed` | `has_test_evidence`, `has_review_evidence`, `write_scope_verified` | 月度三项全 true / total_impl ≥ 95% | ≥ 95% |
| 四阶评审意见转修复 | `improvement.closed` | `a_fixed`, `b_escalated`, `c_blocked`, `d_regression_loops`, `e_debated` | 月度 A 类闭环率 ≥ 90%；D 类 3 次内闭环率 ≥ 80% | A≥90%, D≥80% |
| 五阶暴露跨维度问题 | `global_evaluation.pass_with_warnings` | `warn_dimensions_count`, `residual_risks_high`, `residual_risks_medium` | 月度 pass_with_warnings 率 10%-30% | 10%-30% |
| 六阶经验沉淀 | `closeout.completed` | `proposals_generated`, `proposals_applied`, `proposals_rejected` | 月度 proposals_applied ≥ 1 | ≥ 1 |
| Gateway 阻断无证据推进 | `gateway.blocked` | `reason: missing_evidence / scope_violation / unauthorized_advance` | 月度阻断事件数 ≥ 1 | ≥ 1 |
| 无人监督完成率 | `run.closed` | `human_intervention_count` | 月度 human_intervention_count = 0 的 Run 占比 ≥ 70% | ≥ 70% |
| 三阶可感知进度 | `heartbeat.delivered` | `latency_ms`, `delivery_rate` | 心跳延迟 ≤ 5 秒，送达率 ≥ 99% | ≤ 5s, ≥ 99% |
| 快速通道自动合并率 | `quick_channel.merged` | `auto_merged`, `downgrade_count` | 月度 auto_merged / total_quick ≥ 90% | ≥ 90% |
| 残余风险通知到达率 | `global_evaluation.notified` | `notification_level`, `delivery_confirmed` | `delivery_confirmed = true` 占比 = 100% | = 100% |

> **关键约束**: 所有事件由 Gateway 在状态流转时写入 `events.jsonl`，格式为 NDJSON，每条含 `event_type`、`timestamp`、`run_id`、`payload`。`orch-audit` 负责聚合，`orch-verify` 负责阈值比对，任一指标不达标则 closeout 不得标记为"满足 PRD 成功标准"。

---

#### Staging / Harness 环境定义

| 组件 | 定义 | 实现方式 |
|------|------|----------|
| 环境初始化 | 一键创建隔离 staging 目录 | `scripts/lib/staging Harness.sh`（IaC 脚本） |
| 项目数据注入 | 为 e2e 回归准备 mock project-profile、AGENTS.md、SOUL.md | `scripts/lib/staging inject-data.sh` |
| Gateway 隔离 | staging 实例使用独立 `.hermes/staging/` 状态目录 | `HERMES_STATE_DIR=.hermes/staging` 环境变量 |
| 事件回放验证 | 回归结束后验证 artifacts 完整性与 schema 合规 | `scripts/tests/test-e2e-strict-six-stage-flow.sh` 内置断言 |
| 清理策略 | 每次回归前清空 staging 状态，保证幂等 | `scripts/lib/staging teardown.sh` |

**数据注入脚本要求**:
- `inject-data.sh` 必须生成有效的 `project-profile.yaml`，包含 `protected_targets`、`quick_channel`、`evaluation` 配置。
- 必须注入至少 1 个含 protected target 的 mock 任务，以验证 L3/L4 审批路径。
- 必须注入至少 1 个含冲突标记的 mock intake，以验证 conflict resolution 路径。
