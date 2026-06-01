# Sprint 11 验收清单

## 验收条件（可独立验证子项）

### AC-1: 五阶覆盖 8 个维度，每维输出 0-10 分评分
- **可执行断言**: 调用 `POST /orchestra/runs/{run_id}/global-evaluation`，响应中 `dimensions[]` 长度 = 8，且名称为 `[业务目标, 补全正确性, 安全合规, 质量, 性能, 可维护性, 文档, 可观测性]`；每项含 `score`（整数 0~10）、`rationale`（非空字符串）、`evidence_refs[]`（非空数组）。
- **测试脚本**: `scripts/tests/test-gateway-global-evaluation-pass.sh`
- **负向用例**: 响应中 dimensions 数量 ≠ 8，或某维 `score` 为负数/大于 10，或 `rationale` 为空 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-2: `pass_with_warnings` 触发条件精确可配
- **可执行断言**: 配置存在 1 维评分 = 4 分、其余维 ≥ 5 分时，`verdict` 必须为 `pass_with_warnings`；配置存在 1 维评分 = 2 分时，`verdict` 必须为 `fail`（非 `pass_with_warnings`）。`config/debate/full/coverage-policy.json` 中必须存在 `warning_trigger_min_score` 和 `warning_trigger_any_below` 配置项。
- **测试脚本**: `scripts/tests/test-gateway-global-evaluation-warnings.sh`
- **负向用例**: 存在 1 维 4 分但 verdict 仍为 `pass` → 测试脚本必须以非 0 退出码失败；存在 1 维 2 分但 verdict 为 `pass_with_warnings` → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-3: `jury_panel`、`meta_review`、`cross_team_conflict_detector` 按场景触发
- **可执行断言**: 
  - 模拟不同 evaluator 对同一维度评分差 ≥ 3 分 → `events.jsonl` 中出现 `jury_panel_triggered` 事件。
  - 模拟跨 2 个团队的 protected target 变更 → `events.jsonl` 中出现 `meta_review_triggered` 事件。
  - 模拟评审记录中同一文件获相反结论 → `events.jsonl` 中出现 `cross_team_conflict_triggered` 事件。
- **测试脚本**: `scripts/tests/test-gateway-global-evaluation-fail-blocks.sh`
- **负向用例**: 上述场景未触发对应 mode，评估报告未标记 `detector_skipped` 及原因 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-4: `notification_level` 三种行为差异可验证
- **可执行断言**: 
  - `notification_level = none`：回归后用户侧无任何通知事件，`audit.jsonl` 中仅记录 `notification_suppressed`。
  - `notification_level = summary`：用户收到摘要，含 verdict + 高/中/低风险计数 + 最高风险项；正文不含 8 维详细评分。
  - `notification_level = full`：用户收到完整报告，含 8 维评分、每项 rationale、全部 residual_risks、authority_route。
- **测试脚本**: `scripts/tests/test-gateway-global-evaluation-notification-levels.sh`
- **负向用例**: `notification_level = summary` 时，通知正文包含某维度的具体评分数字 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-5: `fail` / `block` / `acceptance_required` 正确 authority routing
- **可执行断言**: 
  - `fail`（任一维度 < 3 分）：`authority_route.next_stage` 为 `improvement` 或 `rollback`，非 `closeout`。
  - `block`（证据缺失）：`authority_route.required_approvers[]` 包含 `human`，状态为 `approval_required`。
  - `acceptance_required`（L4 变更）：`authority_route.required_approvers[]` 同时包含 `kimi` 和 `human`。
- **测试脚本**: `scripts/tests/test-gateway-global-evaluation-block-human-approval.sh`
- **负向用例**: `fail` 场景下 `next_stage` 仍为 `closeout` → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-6: Gateway 评估逻辑 seam extraction 合规
- **可执行断言**: `orch_gateway.py` 新增行数 ≤ 50；8 维评估逻辑 100% 落在 helper module 中。
- **测试脚本**: `scripts/tests/test-full-contract-validation.sh`
- **负向用例**: `orch_gateway.py` 新增行数 > 50 且未记录技术债务 → 架构红线审核不通过。
- **状态**: ⬜

## 架构红线合规
- [ ] 新增逻辑优先落入 `scripts/lib/gateway_evaluation.py`，`orch_gateway.py` 仅保留路由与编排
- [ ] `orch_gateway.py` 行数增长不超过 50 行（超支需记录技术债务）
- [ ] 评估引擎支持独立单元测试（mock artifacts），不依赖真实上游 Run
- [ ] 文件态持久化采用原子写模式

## 文档交付物
- [ ] `docs/user-flow-guide_by_kimi.md` 已更新五阶 8 维评分流程、mode 触发场景矩阵、notification_level 行为对照表
- [ ] `config/debate/full/coverage-policy.json` 已写入 `pass_with_warnings` 默认触发条件配置
- [ ] `docs/FULL-COVERAGE-MATRIX.md` 已补充五阶覆盖维度与测试映射

## 任务完成状态
- [ ] U11 — 五阶八维评估、残余风险通知与 authority routing

## 验证命令

```bash
rtk bash scripts/tests/test-gateway-global-evaluation-pass.sh
rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh
rtk bash scripts/tests/test-gateway-global-evaluation-fail-blocks.sh
rtk bash scripts/tests/test-gateway-global-evaluation-block-human-approval.sh
rtk bash scripts/tests/test-gateway-global-evaluation-final-acceptance.sh
rtk bash scripts/tests/test-gateway-global-evaluation-notification-levels.sh
rtk bash scripts/tests/test-full-contract-validation.sh
```

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
