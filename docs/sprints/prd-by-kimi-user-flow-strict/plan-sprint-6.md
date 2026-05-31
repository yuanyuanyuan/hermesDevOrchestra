# Sprint 6 Plan

**总故事点**: 5 SP / 7 SP 容量
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U6 | 二阶方案辩论模式策略与 DAG 生成 | 5 | U5 | ⬜ |

## 详细说明

### Task 1 (U6): 二阶方案辩论模式策略与 DAG 生成

- **目标**: 把二阶方案辩论做成真正的路线选择器，明确模式选择逻辑、DAG 产物、同源隔离约束和进入三阶的自动门控。

#### 技术方案要点

1. **争议程度量化指标**
   - 引入 `dispute_score` 三因子公式：`dispute_score = w1 * conflict_density + w2 * assumption_divergence + w3 * team_position_variance`
   - `conflict_density`: 冲突声明数 / 总声明数（阈值：>0.3 视为高冲突）
   - `assumption_divergence`: 未验证假设的 Jaccard 距离（阈值：>0.4 视为高分歧）
   - `team_position_variance`: 各 team 对方案评分标准差（阈值：>1.5σ 视为高方差）
   - **canonical mode 选择矩阵**：
     - `dispute_score < 0.3` → `consensus_fast`（单轮确认，跳过 mini-debate）
     - `0.3 ≤ dispute_score < 0.6` → `standard_debate`（标准二阶辩论，含 mini-debate）
     - `dispute_score ≥ 0.6` → `deep_fork`（深度分支，保留所有候选方案并行推演）
   - 量化指标必须在《具体实现报告》的 `debate_metrics` 字段中持久化，供审计回放。

2. **DAG 验证方案**
   - **无环性验证（Acyclicity）**：基于 DFS 的回边检测算法，遍历 DAG 邻接表；发现任一 back-edge 立即拒绝该 DAG 并触发 `dag_cycle_detected` 事件。
   - **连通性验证（Connectivity）**：从 root 节点出发执行 BFS/DFS 可达性分析，确保所有 task 节点均可从 root 到达；存在不可达节点时标记为 `orphan_task` 并阻断进入三阶。
   - **拓扑序一致性**：验证 DAG 拓扑排序结果与 `task.dependencies` 声明一致；不一致时拒绝并返回 `topological_sort_mismatch` 错误码。
   - 验证逻辑封装为 `scripts/lib/dag_validator.py` 独立模块，供 debate 与 Gateway 两端复用。

3. **同源隔离检测机制**
   - **同源判定规则**：对 `delegate_task` 的 `source_fingerprint` 计算 SHA-256(agent_id + workspace_path + context_hash)，两个 task 的 fingerprint 完全相同视为同源。
   - **碰撞检测**：在 DAG 生成阶段，遍历所有 task 的 `delegate_to` 与 `source_fingerprint` 组合；发现同源 task 被分配到同一 worker/agent 时触发 `source_collision` 告警并强制重分配。
   - **隔离审计**：每次 `delegate_task` 调用必须在 `audit.jsonl` 中写入 `source_isolation_check` 记录，包含 `expected_fingerprint`、`actual_fingerprint`、`collision_result`。
   - 无法提供独立身份时（如 legacy 模式），默认降级为 `sequential_execution`（禁止并行），并在报告中标注 `source_isolation_degraded`。

4. **数据流与状态机**
   - 输入：`debate_backend_adapter.py` 输出的 `candidate_solutions` + `team_scores`
   - 处理：`debate_member_invocation.py` 计算 `dispute_score` → 选择 canonical mode → 生成 DAG → `dag_validator.py` 验证 → 输出《具体实现报告》
   - 输出：`implementation_report`（含 DAG、task I/O、write_scope、parallel_boundaries、test_strategy、dependency_conflict_resolution）
   - 状态机：`debating` → `dag_validated` → `source_isolation_verified` → `ready_for_stage3`
   - 自动门控：DAG 验证通过 + 同源隔离无碰撞 + 依赖矩阵完整性检查通过 → 自动推进到三阶；任一失败则停留在二阶并生成 `stage2_blocker` 事件。

#### 验收标准

- **AC-1**: 争议程度量化指标可计算且可回放
  - 给定同一组 candidate_solutions，重复计算 `dispute_score` 结果偏差 < 0.01
  - `debate_metrics` 字段持久化到 `events.jsonl`，可通过 `grep '"dispute_score"' events.jsonl` 检索
- **AC-2**: DAG 无环性验证可拦截含环图
  - 构造含环测试 DAG（A→B→C→A），`dag_validator.py` 返回 `cycle_detected=false` 并上报事件
  - 无环 DAG 正常通过验证
- **AC-3**: DAG 连通性验证可发现孤立节点
  - 构造含不可达节点的 DAG，验证器返回 `connectivity_passed=false` 并列出 orphan task ID
  - 全连通 DAG 正常通过验证
- **AC-4**: 同源隔离检测可发现碰撞并强制重分配
  - 构造两个 task 具有相同 `source_fingerprint` 且指向同一 agent，系统触发 `source_collision` 并拒绝并行分派
  - 无碰撞场景正常通过，audit.jsonl 中可检索到 `source_isolation_check` 记录
- **AC-5**: 模式选择矩阵按 dispute_score 正确路由
  - `dispute_score=0.15` → `consensus_fast`
  - `dispute_score=0.45` → `standard_debate`
  - `dispute_score=0.75` → `deep_fork`
- **AC-6**: 自动门控在三阶就绪条件满足时自动推进
  - 所有前置检查通过时，Gateway 生成 `stage_transition: 2→3` 事件
  - 任一检查失败时，停留在二阶并生成 `stage2_blocker` 事件

#### 负向用例

- **NE-1**: AI 生成的 DAG 存在隐式环（通过间接依赖回环），验证器未检测到，导致三阶执行死锁。
  - 缓解：`dag_validator.py` 同时执行 DFS back-edge 检测与拓扑序双重校验，降低漏检概率。
- **NE-2**: 两个 worker 使用相同的临时 workspace 路径（如 `/tmp/hermes_worker`），`source_fingerprint` 计算相同但实为不同执行环境，导致误报 collision。
  - 缓解：`source_fingerprint` 除 workspace_path 外，强制混入 `agent_id` 与 `context_hash`（含时间戳与 run_id），降低哈希碰撞概率。

#### 架构红线合规项

- **Seam Extraction 检查**：新增 DAG 验证逻辑必须优先放入 `scripts/lib/dag_validator.py`，禁止直接追加到 `orch_gateway.py` 主文件；若必须修改 Gateway，行数增长不得超过 50 行，且仅限调用 seam 的 facade 入口。
- **Gateway 行数增长限制**：`orch_gateway.py` 净增长 ≤ 50 行；超出部分必须通过 helper module 外置。
- **模块单向依赖**：`dag_validator.py` 不得依赖 `debate_member_invocation.py`（上层可调用下层，反向禁止）。

#### 文档更新要求

- [ ] 更新 `docs/adr/0002-full-debate-package-mode-registry.md`，补充 `dispute_score` 计算逻辑与 canonical mode 选择矩阵
- [ ] 更新 `docs/gateway-integration-architecture.md`，补充 DAG 验证与同源隔离的调用时序图
- [ ] 更新 `docs/sprints/prd-by-kimi-user-flow-strict/schema.md`，补充 `debate_metrics`、`dag_validation_result`、`source_isolation_check` 三个数据模型
- [ ] 在 `scripts/tests/` 目录新增 `test-dag-validator-cycle.sh`、`test-dag-validator-connectivity.sh`、`test-source-isolation-collision.sh`

#### 跨 Sprint 接口契约

- **输入（来自 Sprint 5）**：`candidate_solutions` 数组，每个元素包含 `team_id`、`solution_text`、`team_score`、`assumptions[]`、`conflicts[]`
- **输出（供 Sprint 7 消费）**：`implementation_report` JSON，必须包含：
  - `dag`: `{ nodes[], edges[], topological_order[] }`（已验证无环且连通）
  - `tasks[]`: 每个 task 含 `task_id`、`inputs[]`、`outputs[]`、`write_scope[]`、`parallel_boundary_id`、`test_strategy`、`source_fingerprint`
  - `dependency_conflict_resolution`: 冲突处理决策记录
  - `debate_metrics`: `{ dispute_score, canonical_mode_selected, selection_timestamp }`
- **输出（供 Sprint 8 消费）**：`write_scope[]` 数组，路径格式必须为归一化相对路径（以 `./` 或项目根目录为基准，禁止绝对路径）

#### 涉及文件

Modify: `scripts/lib/debate_member_invocation.py`, `scripts/lib/debate_backend_adapter.py`, `scripts/lib/debate_report.py`, `config/debate/full/modes.json`, `docs/adr/0002-full-debate-package-mode-registry.md`, `docs/gateway-integration-architecture.md`, `scripts/tests/test-debate-member-invocation.sh`, `scripts/tests/test-e2e-ai-debate-flow.sh`, `scripts/tests/test-gateway-ai-integration.sh`
Create: `scripts/lib/dag_validator.py`, `scripts/tests/test-dag-validator-cycle.sh`, `scripts/tests/test-dag-validator-connectivity.sh`, `scripts/tests/test-source-isolation-collision.sh`
