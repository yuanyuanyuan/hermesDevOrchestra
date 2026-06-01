# Sprint 12 Plan

**总故事点**: 5 SP / 7 SP 容量  
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U12 | 六阶审计沉淀与 protected target 审批 | 5 | U11 | ⬜ |

## 详细说明

### Task 1 (U12): 六阶审计沉淀与 protected target 审批

- **目标**: 把六阶做成真正的"可审计可进化"收尾阶段，补齐审计输入范围、建议落地队列和 protected target 审批边界。

#### 技术方案要点

- **数据流**: Gateway 触发 closeout → 审计聚合器读取六类输入 → 完整性校验 → 生成审计报告与改进建议 → 建议入 self-evolution queue → protected target 变更走审批流 → closeout 完成或阻塞。
- **状态机**: `closeout_initiated` → `audit_inputs_collected` → `integrity_verified` → `proposals_generated` → `{approved | rejected | queued}` → `closeout_completed` / `blocked`。
- **接口契约**: `POST /orchestra/runs/{run_id}/closeout` 提交 closeout；`POST /orchestra/decisions/approve` 处理 protected target 审批；`GET /orchestra/modules/self-evolution/enqueue` 查询 queue 状态。

#### 验收标准

- **AC-1**: 六阶审计读取完整输入，并为经验保留来源、置信度、适用边界。
  - 审计输入必须覆盖六类：完整日志（`events.jsonl` + `audit.jsonl`）、补全包（`intake_package`）、工具调用记录（`worker-sessions/*.json` 中的 invocation log）、错误栈（所有 `error` 类型 event）、审查记录（四阶 review/qa 输出）、closeout artifacts（summary、proposals、metrics）。
  - 每条经验建议必须包含 `source_event_refs[]`、`confidence_score`（0.00~1.00）、`applicable_scope`（文件 pattern 或 task type 限制）。
- **AC-2**: protected target 必须走 Kimi review + Human Approval，不能自动落地。
  - 引用 `source-plan.md` §1 中定义的 protected target 清单与 approval_level 映射（L3/L4）。
  - 任何涉及 protected target 的变更，closeout payload 必须包含 `kimi_review_ref` 和 `human_approval_ref`。
  - 缺失任一审批引用时，Gateway 必须拒绝 closeout，返回 HTTP 422，并在 `audit.jsonl` 中记录 `protected_target_missing_approval` 事件。
  - L4 级别（k8s production、db schema、auth policy、iam secrets、infrastructure、payment compliance、legal terms、data privacy）必须同时满足 Kimi review + Human Approval；L3 级别（api contract、ci cd pipeline、core business logic）至少满足 Human Approval。
- **AC-3**: 审计建议必须区分"已落地 / 待审 / 拒绝"，并可通过 queue 回溯。
  - 建议状态 enum：`applied`（已写入 AGENTS.md/SOUL.md/配置）、`pending_review`（在 queue 中待审批）、`rejected`（明确拒绝并记录理由）。
  - `self-evolution-review-queue.json` 必须持久化，支持按 `run_id`、`proposal_id`、`status` 查询。
  - 从 queue 到 AGENTS.md/SOUL.md 的写入必须通过 Gateway authority 校验，不得由 agent 直写。
- **AC-4**: Self-evolution queue 必须持久化，重启不丢。
  - Queue 从纯内存改为文件态持久化：以 NDJSON 或 SQLite 形式写入 `.hermes/evolution-queue/` 目录。
  - 写入必须采用原子写模式（先写临时文件，成功后重命名替换）。
  - 启动时必须加载已有 queue，恢复 `pending_review` 状态项。
  - 必须实现幂等 enqueue：同一 `proposal_id` 重复提交时，只更新 timestamp，不重复创建条目。
- **AC-5**: 六阶审计输入完整性必须在校验清单中逐项验证。
  - closeout 前 Gateway 必须运行完整性校验器，逐项检查六类输入的存在性与非空。
  - 任一输入缺失时，closeout 不得标记为完成，状态转为 `audit_incomplete`，并输出缺失项清单。
  - 校验结果写入 `closeout_audit_checklist.json`，作为 closeout artifact 的一部分。

#### 负向用例

- **NC-1**: 审计聚合器未读取 `events.jsonl`，仅使用内存缓存生成报告 → 完整性校验必须失败，closeout 被阻塞。
- **NC-2**: protected target 变更（如修改 `terraform/main.tf`）未包含 `human_approval_ref`，Gateway 仍允许 closeout → 必须触发安全红线 `SR-04` 并拒绝 closeout。
- **NC-3**: 进程重启后，self-evolution queue 中所有 `pending_review` 提案丢失 → 启动恢复机制必须能从 `.hermes/evolution-queue/` 重新加载。
- **NC-4**: 同一审计建议被 agent 直接写入 `AGENTS.md` 而未经 Gateway 审批 → 必须被下次 audit 扫描发现并标记为 `unauthorized_apply`，回滚写入并记录事件。

#### 架构红线合规项

- [ ] 新增审计聚合逻辑优先落入 `scripts/lib/gateway_closeout.py`，`orch_gateway.py` 仅保留路由与编排。
- [ ] `orch_gateway.py` 行数增长不超过 50 行；若超支需在 closeout 中记录技术债务。
- [ ] Queue 持久化目录 `.hermes/evolution-queue/` 必须受版本控制或备份策略保护，不得放在 `/tmp` 等易失路径。

#### 文档更新要求

- [ ] 更新 `docs/user-flow-guide_by_kimi.md`：补充六阶审计输入清单、protected target 审批流程图、queue 持久化说明。
- [ ] 更新 `docs/FULL-COVERAGE-MATRIX.md`：补充六阶覆盖维度与测试映射。
- [ ] 更新 `docs/sandbox-simulation-report.md`：补充 closeout 完整性校验在沙箱中的验证方法。

#### 跨 Sprint 接口契约

- **输入**（来自 U11）: `global_evaluation_report`（含 `verdict`、`dimensions[]`、`residual_risks[]`、`authority_route`）。
- **输出**（流向 U13）: `closeout_report`（含 `audit_checklist_passed`、`proposals[]`、`protected_target_approvals[]`、`metrics_summary_ref`）。
- **格式约束**: `closeout_report.proposals[].status` 为 enum `[applied, pending_review, rejected]`；`protected_target_approvals[]` 每项必须含 `target_pattern`、`approval_level`、`kimi_review_ref`（L4 必填）、`human_approval_ref`（L3/L4 必填）；`audit_checklist_passed` 为布尔值，false 时 closeout 不得完成。

---

#### 六阶审计输入完整性校验清单

| 序号 | 输入类别 | 校验项 | 存在性断言 | 非空断言 |
|------|----------|--------|-----------|----------|
| 1 | 完整日志 | `events.jsonl` 存在且可读 | `file_exists` | `file_size > 0` |
| 2 | 完整日志 | `audit.jsonl` 存在且可读 | `file_exists` | `file_size > 0` |
| 3 | 补全包 | `intake_package` 存在于 Run Projection | `field_exists` | `len(keys) >= 8` |
| 4 | 工具调用记录 | `worker-sessions/*.json` 中 `invocations[]` 存在 | `field_exists` | `len(invocations) > 0` |
| 5 | 错误栈 | `events.jsonl` 中 `event_type == error` 的记录存在 | `query_has_results` | `count >= 1`（允许 0，但需显式标注"无错误"） |
| 6 | 审查记录 | 四阶 `review_feedback[]` 或 `qa_verdict` 存在 | `field_exists` | `len(feedback) > 0`（允许 0，但需显式标注"无 review"） |
| 7 | closeout artifacts | `closeout_summary`、`proposals`、`metrics_summary` 存在 | `field_exists` | `proposals` 允许空，但需显式标注 |
