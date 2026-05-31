# Sprint 10 Plan

**总故事点**: 5 SP / 7 SP 容量  
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U10 | 四阶改进分类、回归上限与争议裁决 | 5 | U9 | ⬜ |

## 详细说明

### Task 1 (U10): 四阶改进分类、回归上限与争议裁决

- **目标**: 把四阶从"收到 review 再修"细化为带问题分类、回归预算、争议裁决和范围控制的明确闭环。

#### 技术方案要点

- **数据流**: Gateway 接收 review/qa 反馈 → 分类器映射到 A-E 类别 → 按类别路由处理动作 → 记录 improvement cycle → 更新 Run Projection。
- **状态机**: `review_received` → `classified` → `fixing` → `retesting` → `{resolved | regression_budget_exceeded | escalated}` → `closed`。
- **接口契约**: Gateway 暴露 `POST /orchestra/runs/{run_id}/improvement` 接收反馈分类与修复结果；`GET /orchestra/runs/{run_id}/improvement/cycles` 查询回归预算消耗。

#### 验收标准

- **AC-1**: 四阶完整落地 A-E 五类问题分类，每类都有明确处理路径。
  - 分类器必须引用 `source-plan.md` §2 中已定义的 A-E 五类问题分类表（详见下文「A-E 分类引用」）。
  - 每类问题在 `orch_gateway.py` 中有独立处理分支，且处理动作与上表一致。
- **AC-2**: 回归循环最多 3 次，第 3 次失败后必须上浮决策。
  - improvement cycle 计数器在每次 `fixing → retesting → failed` 时递增。
  - 第 3 次失败后，Gateway 必须生成决策节点，提供三条路径：接受（accept_with_risk）、回滚（rollback）、重设计（redesign）。
  - 决策节点必须记录到 `decisions.json`，并触发 authority routing 到 Kimi 或 Human。
- **AC-3**: 评审争议触发 2 轮 mini-debate，未收敛则转裁决。
  - E 类争议自动启动 2 轮 mini-debate，每轮输出 consensus_score。
  - 2 轮后 consensus_score < 0.60 时，Gateway 阻塞并生成 `escalation` 决策，路由到 Kimi/用户裁决。
- **AC-4**: 超范围修复由 Gateway 阻塞并生成子任务或新 Run。
  - Gateway 比对修复提交的文件路径与原始 task write_scope_ref。
  - 检测到路径越界时，返回 HTTP 422，状态转为 `blocked_scope_violation`。
  - 同时自动创建子任务（同 Run 内）或新 Run（跨功能边界时），并将原 task 标记为 `pending_child_resolution`。

#### 负向用例

- **NC-1**: D 类问题在第 3 次失败后仍自动重试，未上浮决策节点 → 必须被 Gateway 拒绝并记录安全事件。
- **NC-2**: 修复提交修改了 `db/migrations/xxx.sql` 但原始 task 不含该路径，Gateway 未阻塞 → 必须触发 scope violation block。
- **NC-3**: E 类争议 2 轮 mini-debate 后 consensus_score 仍低于阈值，系统自动选择一方结论推进 → 必须阻塞等待裁决。

#### 架构红线合规项

- [ ] 新增逻辑优先落入 helper modules（如 `scripts/lib/gateway_improvement.py`），`orch_gateway.py` 仅保留路由与编排。
- [ ] `orch_gateway.py` 行数增长不超过 50 行；若超支需在 closeout 中记录技术债务。
- [ ] 所有自动推进路径必须附带阻塞条件、authority route 和回放验证路径。

#### 文档更新要求

- [ ] 更新 `docs/user-flow-guide_by_kimi.md`：补充四阶 A-E 分类处理流程图。
- [ ] 更新 `docs/FULL-COVERAGE-MATRIX.md`：补充四阶覆盖维度与测试映射。

#### 跨 Sprint 接口契约

- **输入**（来自 U9）: `task.write_scope_ref`（文件路径列表）、`task.review_feedback[]`（含 reviewer、comment、severity）。
- **输出**（流向 U11）: `improvement_report`（含 `classification`、A-E 类别、`cycles_count`、`verdict`、`residual_risks[]`、`child_task_refs[]`）。
- **格式约束**: `improvement_report.classification` 必须为 enum `[A, B, C, D, E]`；`cycles_count` 为整数且 `0 ≤ cycles_count ≤ 3`；`verdict` 为 enum `[resolved, accepted_with_risk, rollback, redesign, escalated, blocked]`。

---

#### A-E 分类引用（source-plan.md §2）

| 类别 | 名称 | 判定标准 | 处理动作 | 升级路径 |
|------|------|----------|----------|----------|
| A | 格式/风格问题 | lint/format 可自动修复 | 自动修复 + 复测 | 无 |
| B | 简单逻辑错误 | 单测失败，定位清晰 | 自动修复 + 复测 | 2 次失败后人工介入 |
| C | 边界条件缺失 | 边界测试失败 | 自动修复 + 边界用例补充 | 2 次失败后人工介入 |
| D | 架构/设计缺陷 | 多模块影响，需重构 | 方案 mini-debate → 修复 | 第 3 次失败上浮接受/回滚/重设计 |
| E | 评审争议 | 评审人间意见不一致 | 2 轮 mini-debate → Kimi/用户裁决 | 未收敛则 block + 升级 |

> **关键约束**: 四阶改进必须按上表分类，且 D 类回归上限为 3 次，E 类争议上限为 2 轮 mini-debate。
