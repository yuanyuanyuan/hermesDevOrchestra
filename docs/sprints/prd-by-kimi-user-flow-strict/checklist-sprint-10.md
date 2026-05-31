# Sprint 10 验收清单

## 验收条件（可独立验证子项）

### AC-1: A-E 五类问题分类完整落地
- **可执行断言**: `scripts/lib/orch_gateway.py` 或 `scripts/lib/gateway_improvement.py` 中存在 A/B/C/D/E 五个独立处理分支；每个分支的判定标准与 `source-plan.md` §2 的 A-E 分类表一致。
- **测试脚本**: `scripts/tests/test-gateway-review-verdict-improvement-budget.sh`
- **负向用例**: review/qa 反馈返回了未定义的类别（如 `F`），系统未拒绝或 fallback 到默认分支 → 必须返回 HTTP 400 并记录 `unknown_classification` 事件。
- **状态**: ⬜

### AC-2: 回归循环最多 3 次，第 3 次失败后上浮决策
- **可执行断言**: 运行 D 类问题测试用例，模拟 3 次 `fixing → retesting → failed`；第 3 次失败后，Gateway 返回的状态为 `regression_budget_exceeded`，并生成包含 `accept_with_risk`/`rollback`/`redesign` 三条路径的决策节点；`decisions.json` 中存在对应记录。
- **测试脚本**: `scripts/tests/test-gateway-review-verdict-improvement-budget.sh`
- **负向用例**: 第 3 次失败后系统仍自动发起第 4 次修复尝试 → `test-gateway-review-verdict-improvement-budget.sh` 必须以非 0 退出码失败。
- **状态**: ⬜

### AC-3: 评审争议触发 2 轮 mini-debate，未收敛则转裁决
- **可执行断言**: 运行 E 类争议测试用例，系统触发 2 轮 mini-debate；每轮输出 `consensus_score`；2 轮后 `consensus_score < 0.60` 时，状态转为 `escalated`，`authority_route` 指向 `kimi` 或 `user`。
- **测试脚本**: `scripts/tests/test-gateway-review-verdict-request-changes.sh`
- **负向用例**: 2 轮 mini-debate 后 consensus_score 低于阈值，系统未阻塞且自动选择一方结论推进 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-4: 超范围修复由 Gateway 阻塞并生成子任务或新 Run
- **可执行断言**: 提交修复的文件路径超出原始 `task.write_scope_ref` 范围时，Gateway 返回 HTTP 422，`status == blocked_scope_violation`；同时 `tasks.json` 中出现新的子任务或 `run.json` 中出现新的 `child_run_ref`。
- **测试脚本**: `scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
- **负向用例**: 修复提交修改了未授权路径（如 `db/migrations/xxx.sql`），Gateway 未返回 422 且未生成子任务 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-5: Gateway 改进逻辑 seam extraction 合规
- **可执行断言**: `orch_gateway.py` 新增行数 ≤ 50（通过 `git diff --stat` 校验）；新增 8 维评估逻辑 100% 落在 helper module 中（通过 `grep` 校验 helper module 中是否存在对应函数定义）。
- **测试脚本**: `scripts/tests/test-full-contract-validation.sh`（内置 seam extraction 断言）
- **负向用例**: `orch_gateway.py` 新增行数 > 50 且 closeout 中未记录技术债务 → 架构红线审核不通过，Sprint 不得签核。
- **状态**: ⬜

## 架构红线合规
- [ ] 新增逻辑优先落入 `scripts/lib/gateway_improvement.py`，`orch_gateway.py` 仅保留路由与编排
- [ ] `orch_gateway.py` 行数增长不超过 50 行（超支需记录技术债务）
- [ ] 所有自动推进路径附带阻塞条件、authority route 和回放验证路径
- [ ] 文件态持久化采用原子写模式（先临时文件后重命名）

## 文档交付物
- [ ] `docs/user-flow-guide_by_kimi.md` 已更新四阶 A-E 分类处理流程图
- [ ] `docs/FULL-COVERAGE-MATRIX.md` 已补充四阶覆盖维度与测试映射

## 任务完成状态
- [ ] U10 — 四阶改进分类、回归上限与争议裁决

## 验证命令

```bash
rtk bash scripts/tests/test-gateway-review-verdict-improvement-budget.sh
rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh
rtk bash scripts/tests/test-gateway-review-verdict-block-human-approval.sh
rtk bash scripts/tests/test-gateway-qa-verdict-block-kimi.sh
rtk bash scripts/tests/test-full-contract-validation.sh
```

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
