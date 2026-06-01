# Sprint 12 验收清单

## 验收条件（可独立验证子项）

### AC-1: 六阶审计读取完整六类输入
- **可执行断言**: 运行 closeout 流程后，`closeout_audit_checklist.json` 中六类输入（完整日志、补全包、工具调用记录、错误栈、审查记录、closeout artifacts）的 `exists` 和 `non_empty` 字段均为 `true`；每条经验建议含 `source_event_refs[]`、`confidence_score`（0.00~1.00）、`applicable_scope`。
- **测试脚本**: `scripts/tests/test-gateway-closeout-completes-run.sh`
- **负向用例**: 审计聚合器未读取 `events.jsonl`（如直接删除该文件后运行 closeout），`closeout_audit_checklist.json` 中对应项为 `false`，但 Gateway 仍允许 closeout 标记完成 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-2: protected target 强制 Kimi review + Human Approval
- **可执行断言**: 提交包含 `terraform/main.tf`（L4）或 `docs/api/spec.yaml`（L3）变更的 closeout；L4 场景下缺失 `kimi_review_ref` 或 `human_approval_ref` 时 Gateway 返回 HTTP 422；L3 场景下缺失 `human_approval_ref` 时同样返回 HTTP 422；`audit.jsonl` 中出现 `protected_target_missing_approval` 事件。
- **测试脚本**: `scripts/tests/test-gateway-closeout-forbidden-proposal.sh`
- **负向用例**: protected target 变更未含审批引用，Gateway 仍允许 closeout → 测试脚本必须以非 0 退出码失败，并标记安全红线 `SR-04` 触发。
- **状态**: ⬜

### AC-3: 审计建议区分"已落地 / 待审 / 拒绝"并可回溯
- **可执行断言**: `self-evolution-review-queue.json`（或 `.hermes/evolution-queue/` 下的持久化文件）中存在至少 3 条记录，状态分别为 `applied`、`pending_review`、`rejected`；每条记录可通过 `run_id` 和 `proposal_id` 查询；从 queue 到 `AGENTS.md`/`SOUL.md` 的写入必须经过 Gateway authority 校验。
- **测试脚本**: `scripts/tests/test-self-evolution.sh`
- **负向用例**: agent 直写 `AGENTS.md` 未经 Gateway 审批，下次 audit 未标记 `unauthorized_apply` 或未回滚 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-4: Self-evolution queue 持久化，重启不丢
- **可执行断言**: 
  1. 运行 enqueue 操作，生成 `pending_review` 提案。
  2. 验证 `.hermes/evolution-queue/` 下存在对应持久化文件。
  3. 模拟进程重启（如 kill Gateway 进程后重新启动）。
  4. 重启后查询 queue，`pending_review` 提案仍存在且状态不变。
  5. 同一 `proposal_id` 重复 enqueue，queue 中仅有一条记录，timestamp 被更新。
- **测试脚本**: `scripts/tests/test-self-evolution.sh`（含持久化子测试）
- **负向用例**: 进程重启后 `pending_review` 提案丢失 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-5: 六阶审计输入完整性校验清单逐项通过
- **可执行断言**: 运行 closeout 前，Gateway 执行完整性校验；`closeout_audit_checklist.json` 中 7 项校验（见 plan-sprint-12.md 校验清单）全部标记 `passed`；任一缺失时 closeout 状态为 `audit_incomplete`，并输出缺失项清单。
- **测试脚本**: `scripts/tests/test-full-contract-validation.sh`
- **负向用例**: 删除 `worker-sessions/*.json` 后运行 closeout，完整性校验未检测缺失且 closeout 标记完成 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-6: Gateway closeout 逻辑 seam extraction 合规
- **可执行断言**: `orch_gateway.py` 新增行数 ≤ 50；审计聚合逻辑 100% 落在 helper module 中。
- **测试脚本**: `scripts/tests/test-full-contract-validation.sh`
- **负向用例**: `orch_gateway.py` 新增行数 > 50 且未记录技术债务 → 架构红线审核不通过。
- **状态**: ⬜

## 架构红线合规
- [ ] 新增逻辑优先落入 `scripts/lib/gateway_closeout.py`，`orch_gateway.py` 仅保留路由与编排
- [ ] `orch_gateway.py` 行数增长不超过 50 行（超支需记录技术债务）
- [ ] Queue 持久化目录 `.hermes/evolution-queue/` 不在 `/tmp` 等易失路径
- [ ] Queue 写入采用原子写模式（先临时文件后重命名）
- [ ] protected target 审批引用缺失时 Gateway 必须拒绝 closeout

## 文档交付物
- [ ] `docs/user-flow-guide_by_kimi.md` 已更新六阶审计输入清单、protected target 审批流程图、queue 持久化说明
- [ ] `docs/FULL-COVERAGE-MATRIX.md` 已补充六阶覆盖维度与测试映射
- [ ] `docs/sandbox-simulation-report.md` 已补充 closeout 完整性校验在沙箱中的验证方法

## 任务完成状态
- [ ] U12 — 六阶审计沉淀与 protected target 审批

## 验证命令

```bash
rtk bash scripts/tests/test-self-evolution.sh
rtk bash scripts/tests/test-gateway-closeout-forbidden-proposal.sh
rtk bash scripts/tests/test-gateway-closeout-completes-run.sh
rtk bash scripts/tests/test-gateway-closeout-summary-alone-rejected.sh
rtk bash scripts/tests/test-full-contract-validation.sh
```

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
