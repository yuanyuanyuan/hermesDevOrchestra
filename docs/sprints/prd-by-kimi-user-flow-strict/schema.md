# Hermes Dev Orchestra Schema 变更说明

## API 变更

### Kimi-facing Run Projection API

| 方法 | 路径 | 描述 |
|------|------|------|
| GET/POST | `/orchestra/runs/{run_id}/projection` | 返回或刷新 Run、Task、Artifact、Decision、Audit、Event 六类投影与权限矩阵视图 |
| POST | `/orchestra/runs` | 创建带 intake 上下文的运行实例 |
| POST | `/orchestra/decisions/approve` | 解决 intake/global evaluation/protected target 等审批节点 |

**响应要求**:
- 必须包含 `run`, `tasks`, `artifacts`, `decisions`, `audits`, `events` 六类对象。
- 必须包含 intake 的来源、置信度、冲突、依赖投影。
- 必须包含 authority matrix 或等价的 capability route 视图。
- Kimi 不得通过该接口直接改写 Kanban 原始状态。

### 模块端点扩展

| 模块族 | 关键操作 | 说明 |
|--------|----------|------|
| `debate-assembly` | `select-for-stage` | 按 task type / risk / profile / alias mapping 选择 team + mode |
| `debate-member-invocation` | `execute` | 生成并执行方案辩论与 mini-debate |
| `worker-session` | `create-session`, `transition` | 记录 workspace、write scope、context bundle、cleanup |
| `self-evolution` | `enqueue`, `transition`, `generate-stage6-sweep` | 六阶建议入队、审批、收敛 |

## 数据模型

### `project-profile.yaml`

```yaml
profile:
  tech_stack:
    language: python
    framework: fastapi
    test_runner: pytest
  deploy:
    target: kubernetes
  risk_flags:
    has_payment_flow: true
    has_pii_data: true
  protected_targets:
    - category: k8s_production
      pattern: "k8s/production/.*"
      level: L4
    - category: iam_secrets
      pattern: "secrets/.*|\\.env.*|vault/.*"
      level: L4
    - category: infrastructure
      pattern: "terraform/.*|infra/.*|\\.github/workflows/.*"
      level: L4
    - category: payment_compliance
      pattern: "payment/.*|pci/.*|checkout/.*"
      level: L4
intake:
  default_mode: compact
quick_channel:
  rollout_phase: observe_only   # observe_only / calibrating / enabled
  auto_merge: true
  notification: compact         # silent / compact / verbose
evaluation:
  warning_notification: summary # none / summary / full
debate:
  inactive_teams: []
  custom_teams: []
  alias_mapping_ref: "config/debate/full/alias-mapping.json"
```

### `authority_matrix`

| 字段 | 类型 | 约束 |
|------|------|------|
| `actor` | string | `kimi` / `gateway` / `hermes_agents` / `claude_codex` / `user` |
| `capability` | string | 必填 |
| `allowed` | boolean | 必填 |
| `route` | string | 必填，说明通过谁推进 |
| `block_reason` | string | 拒绝时必填 |

必须覆盖至少 8 类能力：
- `create_run`
- `hydrate_requirements`
- `mutate_kanban_raw_state`
- `advance_stage`
- `select_debate_teams`
- `code_or_review`
- `approve_l3_l4`
- `apply_self_evolution`

### `actor_token`

| 字段 | 类型 | 约束 |
|------|------|------|
| `actor_type` | string | `kimi` / `gateway` / `hermes_agents` / `claude_codex` / `user` |
| `actor_id` | string | `^[a-z0-9_-]{3,64}$` |
| `timestamp` | integer | Unix 秒级时间戳，有效期 300 秒，允许 30 秒时钟漂移 |
| `signature` | string | `hmac_sha256(secret, actor_type + actor_id + timestamp)` |
| `approval_level` | string/null | 可选，`L3` / `L4` |
| `protected_target_pattern` | string/null | L4 protected target 白名单，可选 |

Gateway 从 `X-Actor-Token` 读取 base64 编码 token，校验 HMAC、过期时间和 revoked-token 缓存。

### `authority_matrix_view`

| 字段 | 类型 | 约束 |
|------|------|------|
| `<capability>` | string | `allowed` / `blocked` / `requires_approval` |

该视图按当前 actor 投影 `config/decisions/authority-matrix.json` 的 8 类能力结果。未定义 capability 必须 fail closed，返回 `capability_not_defined`。

### `projection_response`

| 字段 | 类型 | 约束 |
|------|------|------|
| `projection_schema_version` | string | 固定为 `1.0.0` |
| `run` | object | Run 级元数据，含 `intake_projection` |
| `tasks` | array | Task 投影，含 `assigned_actor`、`write_scope`、`evidence_refs` / artifact refs |
| `artifacts` | array | Artifact id、类型、state path、checksum |
| `decisions` | array | Decision id、type、actor、timestamp、rationale、approval_level |
| `audits` | array | 来自 `audit.jsonl` 的 run-scoped 审计事件 |
| `events` | array | 来自 `events.jsonl` 的 workflow event |
| `authority_matrix_view` | object | 当前 actor 对 8 类能力的投影视图 |

HTTP 响应头必须包含 `X-Projection-Schema-Version: 1.0.0`。

### `intake_package`

| 字段 | 类型 | 约束 |
|------|------|------|
| `original_intent` | object | 必填 |
| `system_completion` | object | 必填 |
| `verified_facts` | array | 必填 |
| `unverified_assumptions` | array | 必填 |
| `conflicts` | array | 必填 |
| `dependency_graph` | object | 必填，必须覆盖环境/上游/下游/代码四维 |
| `acceptance_matrix` | array | 必填 |
| `prompt_envelope` | object | 必填 |

### `global_evaluation_report`

| 字段 | 类型 | 约束 |
|------|------|------|
| `dimensions` | array | 必填，至少 8 维，见下表 |
| `verdict` | string | `pass` / `pass_with_warnings` / `fail` / `block` |
| `residual_risks` | array | 必填，按高/中/低排序 |
| `notification_level` | string | `none` / `summary` / `full` |
| `authority_route` | object | 必填 |

#### 8 维评分标准与通过阈值

| 维度 | 评分范围 | pass 阈值 | pass_with_warnings 阈值 | 说明 |
|------|----------|-----------|------------------------|------|
| `completeness` | 0–100 | ≥ 90 | ≥ 75 | 需求补全包是否覆盖 6 类信息 |
| `correctness` | 0–100 | ≥ 95 | ≥ 80 | 代码/决策正确性 |
| `security` | 0–100 | ≥ 95 | ≥ 85 | 权限矩阵、protected target、注入防护 |
| `performance` | 0–100 | ≥ 85 | ≥ 70 | 响应时间与资源消耗 |
| `test_coverage` | 0–100 | ≥ 90 | ≥ 75 | 单元/集成/e2e 覆盖率 |
| `auditability` | 0–100 | ≥ 90 | ≥ 80 | 每条关键结论是否可回放 |
| `maintainability` | 0–100 | ≥ 85 | ≥ 70 | 代码/文档可维护性 |
| `stakeholder_alignment` | 0–100 | ≥ 90 | ≥ 75 | 与 PRD/用户意图的一致性 |

- `pass`：所有维度 ≥ pass 阈值，且无任何高残余风险。
- `pass_with_warnings`：所有维度 ≥ pass_with_warnings 阈值，高残余风险 ≤ 1 个；此时必须触发 `notification_level=summary` 或 `full`。
- `fail`：任一维度 < pass_with_warnings 阈值。
- `block`：存在未解决的 `protected_target` 冲突、安全红线突破或 authority 路由失败。

#### `notification_level` 行为差异

| 级别 | 触发条件 | 行为 |
|------|----------|------|
| `none` | `verdict=pass` 且无 warnings | 不发送任何通知，仅写入 audit log |
| `summary` | `verdict=pass_with_warnings` | 向 Kimi 推送摘要（维度得分 + 残余风险清单），不包含完整证据链 |
| `full` | `verdict=fail` 或 `block` | 向 Kimi 及用户推送完整报告（含 evidence、authority route、建议操作），必须人工确认 |

### `worker_session_record`（心跳协议）

| 字段 | 类型 | 约束 |
|------|------|------|
| `heartbeat_at` | ISO-8601 timestamp | 必填，UTC 时间 |
| `heartbeat_seq` | integer | 必填，从 0 递增，用于检测丢包与乱序 |
| `status` | string | `running` / `paused` / `completed` / `failed` / `conflict` |
| `progress_pct` | integer | 0–100，必填 |

心跳发送频率：每 30 秒或每完成一个子任务时必须发送一次。Gateway 在 `heartbeat_seq` 不连续或 `status=conflict` 时必须触发告警并暂停任务。

### `write_set`

| 字段 | 类型 | 约束 |
|------|------|------|
| `files` | array of string | 必填，本任务计划修改的相对路径列表 |
| `checksums` | object | 必填，键为文件路径，值为 sha256 校验和（执行前快照） |
| `scope` | string | `disjoint` / `overlapping` / `unknown` |
| `disjoint_verified` | boolean | 必填，Gateway 必须在任务启动前验证该 worker 的 `files` 与其他运行中 worker 无交集 |

> 未声明 `write_set` 或 `disjoint_verified=false` 的任务不得执行。

### `merge_strategy`

| 字段 | 类型 | 约束 |
|------|------|------|
| `strategy` | string | 枚举：`sequential` / `branch_merge` / `overwrite_with_backup` / `abort_on_conflict` |
| `fallback` | string | 当首选策略失败时的回退策略，必须与 `strategy` 同枚举集且不能等于自身 |
| `disjoint_write_set_verified` | boolean | 必填，仅当 `true` 时才允许 `branch_merge` |

### `success_metrics_summary`

| 字段 | 类型 | 约束 |
|------|------|------|
| `metric_id` | string | 必填，对应 PRD §11 指标 |
| `source_events` | array | 必填 |
| `aggregation_rule` | string | 必填 |
| `threshold` | string/number | 必填 |
| `observed_value` | string/number | 必填 |
| `status` | string | `pass` / `warn` / `fail` |

### `debate_metrics`

| 字段 | 类型 | 约束 |
|------|------|------|
| `conflict_density` | number | `0..1`，冲突声明数 / 总声明数 |
| `assumption_divergence` | number | `0..1`，候选方案假设集合平均 Jaccard 距离 |
| `team_position_variance` | number | `0..1`，team score 标准差归一化值 |
| `weights` | object | 必含 `conflict_density`、`assumption_divergence`、`team_position_variance`，权重和必须为 `1.0` |
| `dispute_score` | number | `0..1`，可由同一 `candidate_solutions` 重放，偏差 `< 0.01` |
| `canonical_mode_selected` | string | `consensus_fast` / `standard_debate` / `deep_fork` |
| `selection_timestamp` | ISO-8601 timestamp | 必填，记录模式选择时间 |

路由矩阵：

- `dispute_score < 0.3` → `consensus_fast`
- `0.3 <= dispute_score < 0.6` → `standard_debate`
- `dispute_score >= 0.6` → `deep_fork`

### `dag_validation_result`

| 字段 | 类型 | 约束 |
|------|------|------|
| `acyclicity_passed` | boolean | 无回边时为 `true` |
| `cycle_detected` | boolean | 检测到 DFS back-edge 时为 `true`，并写入 `dag_cycle_detected` 事件 |
| `back_edges` | array | 每项含 `from`、`to` |
| `connectivity_passed` | boolean | root 可达所有 task 时为 `true` |
| `orphan_task_ids` | array of string | 不可达 task id 列表 |
| `topological_order` | array of string | DAG 拓扑序 |
| `topological_sort_consistent` | boolean | 拓扑序与 `task.dependencies` 一致时为 `true` |
| `passed` | boolean | 三项验证全部通过时为 `true` |
| `errors` | array of string | `cycle_detected` / `orphan_task` / `topological_sort_mismatch` 等 |

### `source_isolation_check`

| 字段 | 类型 | 约束 |
|------|------|------|
| `task_id` | string | 被检查的 delegate task |
| `delegate_to` | string | 目标 worker / agent |
| `expected_fingerprint` | sha256 string | `SHA-256(agent_id + workspace_path + context_hash)` |
| `actual_fingerprint` | sha256 string | 实际计算或输入的 fingerprint |
| `collision_result` | boolean | 同一 `delegate_to` 下 fingerprint 重复时为 `true` |

同源隔离整体结果写入 `implementation_report.source_isolation_result`。无法提供独立身份时必须降级为 `sequential_execution`，并阻断自动进入三阶。

## 持久化说明

本轮仍不新增数据库表。

原因不是“忽略持久化”，而是当前仓库已经以 Gateway 本地状态文件和日志作为权威持久化介质，包括：
- `run.json`
- `tasks.json`
- `events.jsonl`
- `audit.jsonl`
- `worker-sessions/*.json`
- 各阶段 artifact JSON

本轮要求补强的是：
- 文件态投影的 authority contract
- 事件/指标采集字段
- 回放与恢复验证路径
- 文件态持久化的原子写语义

而不是新增一套数据库 schema。

#### 原子写实现
所有 JSON/YAML/JSONL 状态文件的写入必须遵循"临时文件 + 重命名"模式：

1. 写入到同目录下的临时文件（命名：`{target}.tmp.{pid}.{nonce}`）。
2. 使用 `fsync`（或等效操作）确保数据落盘。
3. 通过原子重命名（`rename`/`mv`）覆盖目标文件。
4. 读取方始终只读取目标文件名，因此不会读到半写状态。
5. 写入失败时保留上一次完整版本，并在 `events.jsonl` 中记录 `write_failure` 事件。

该机制适用于 `run.json`、`tasks.json`、`events.jsonl`、`audit.jsonl`、`worker-sessions/*.json` 以及各阶段 artifact JSON。

## 向后兼容性

- [x] 保留 legacy alias，但必须通过 `alias-mapping.json` 显式映射。
- [x] 保留 MVP/legacy Gateway 路径，但 strict flow 以前述 authority/matrix/metrics gate 为准。
- [x] 不引入数据库 schema 破坏性变更。
- [x] protected target 在缺少 `kimi_review_ref` / `human_approval_ref` 时必须拒绝。
