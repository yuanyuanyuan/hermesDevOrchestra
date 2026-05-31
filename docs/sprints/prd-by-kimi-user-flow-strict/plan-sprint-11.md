# Sprint 11 Plan

**总故事点**: 5 SP / 7 SP 容量  
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U11 | 五阶八维评估、残余风险通知与 authority routing | 5 | U10 | ⬜ |

## 详细说明

### Task 1 (U11): 五阶八维评估、残余风险通知与 authority routing

- **目标**: 将五阶从"汇总测试结果"升级为跨维度 verdict 体系，补齐 8 维评估、mode 选择、`pass_with_warnings` 风险摘要和最终 authority routing。

#### 技术方案要点

- **数据流**: Gateway 收集 0→4 阶 artifacts + events → 评估引擎按 8 维评分 → 生成 verdict + residual_risks → 按 notification_level 分发通知 → authority routing 决定推进/阻塞/审批。
- **状态机**: `evaluating` → `dimensions_scored` → `verdict_generated` → `notification_delivered` → `{advance_to_closeout | blocked | approval_required}`。
- **接口契约**: `POST /orchestra/runs/{run_id}/global-evaluation` 提交评估结果；响应包含 `verdict`、`dimensions[]`、`residual_risks[]`、`notification_level`、`authority_route`。

#### 验收标准

- **AC-1**: 五阶覆盖 8 个维度，每维输出 0-10 分评分。
  - 8 维定义：业务目标、补全正确性、安全合规、质量、性能、可维护性、文档、可观测性。
  - 每维评分必须附带评分依据（引用具体 artifact、event 或 test result）。
  - 评分结果写入 `global_evaluation_report.dimensions[]`，字段为 `{name, score, rationale, evidence_refs[]}`。
- **AC-2**: `pass_with_warnings` 触发条件精确可配。
  - 默认触发条件：存在至少 1 维评分 < 5 分，但没有任何维度评分 < 3 分。
  - 该条件必须在 `config/debate/full/coverage-policy.json` 中可配置化（`warning_trigger_min_score` 和 `warning_trigger_any_below`）。
  - 触发时，`verdict` 固定为 `pass_with_warnings`，且 `residual_risks[]` 必须按高/中/低排序输出。
- **AC-3**: `jury_panel`、`meta_review`、`cross_team_conflict_detector` 按场景触发，而非固定使用。
  - **jury_panel**: 当任意维度评分分歧 ≥ 3 分（不同 evaluator 之间）或 E 类争议未收敛时触发。
  - **meta_review**: 当跨团队影响面 ≥ 2 个团队或存在 protected target 变更时触发。
  - **cross_team_conflict_detector**: 当评审记录中出现不同团队对同一文件给出相反结论时触发。
  - 触发逻辑必须写入 `scripts/lib/orch_gateway.py` 的评估路由分支，并在 `events.jsonl` 中记录触发原因。
- **AC-4**: `notification_level` 三种行为差异必须可验证。
  - `none`: 不向用户发送任何通知；残余风险仅写入审计日志；适合 CI 无人值守场景。
  - `summary`: 向用户发送摘要，包含 verdict + 残余风险高/中/低计数 + 最高风险项名称；不含详细评分。
  - `full`: 向用户发送完整评估报告，含 8 维评分、每项 rationale、全部 residual_risks、authority_route 说明。
  - 配置读取自 `project-profile.yaml` 的 `evaluation.warning_notification`（或 Run 级别覆盖）。
- **AC-5**: `fail` / `block` / `acceptance_required` 必须正确 authority routing。
  - `fail`（任一维度 < 3 分）: 路由回四阶重设计，或生成 rollback 决策。
  - `block`（存在未解决的冲突、证据缺失或 protected target 未审批）: 阻塞并生成 `approval_required` 决策，路由到 Human。
  - `acceptance_required`（高风险残余 + L4 变更）: 路由到 L4 审批者（Human + Kimi review）。

#### 负向用例

- **NC-1**: 8 维中某维评分为 4 分，但 verdict 仍为 `pass` → 必须被自动修正为 `pass_with_warnings`。
- **NC-2**: `notification_level = summary` 时，系统发送了 8 维完整评分明细 → 必须被测试脚本拦截并标记为配置泄漏。
- **NC-3**: `fail` 场景下 Gateway 未阻塞，自动推进到 closeout → 必须触发安全红线事件 `SR-05`（绕过证据门控）。
- **NC-4**: `cross_team_conflict_detector` 未检测到评审记录中的相反结论，直接生成 verdict → 必须在评估报告中标记 `detector_skipped` 并记录原因。

#### 架构红线合规项

- [ ] 新增 8 维评估逻辑优先落入 `scripts/lib/gateway_evaluation.py`，`orch_gateway.py` 仅保留路由与编排。
- [ ] `orch_gateway.py` 行数增长不超过 50 行；若超支需在 closeout 中记录技术债务。
- [ ] 评估引擎必须支持独立单元测试（mock 各阶段 artifacts），不依赖真实上游 Run。

#### 文档更新要求

- [ ] 更新 `docs/user-flow-guide_by_kimi.md`：补充五阶 8 维评分流程、mode 触发场景矩阵、notification_level 行为对照表。
- [ ] 更新 `config/debate/full/coverage-policy.json`：写入 `pass_with_warnings` 默认触发条件配置。
- [ ] 更新 `docs/FULL-COVERAGE-MATRIX.md`：补充五阶覆盖维度与测试映射。

#### 跨 Sprint 接口契约

- **输入**（来自 U10）: `improvement_report`（含 `classification`、`cycles_count`、`verdict`、`residual_risks[]`）。
- **输出**（流向 U12）: `global_evaluation_report`（含 `dimensions[]`、`verdict`、`residual_risks[]`、`notification_level`、`authority_route`、`mode_refs[]`）。
- **格式约束**: `dimensions[].score` 为整数 `0~10`；`verdict` 为 enum `[pass, pass_with_warnings, fail, block]`；`notification_level` 为 enum `[none, summary, full]`；`authority_route` 必须包含 `next_stage`、`required_approvers[]`、`block_reason`（若阻塞）。
