# Sprint 9 Plan

**总故事点**: 5 SP / 7 SP 容量
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U9 | 三阶心跳、实时快照与并行写集策略 | 5 | U8 | ⬜ |

## 详细说明

### Task 1 (U9): 三阶心跳、实时快照与并行写集策略

- **目标**: 消除三阶长时静默和并行写冲突，要求执行期间输出结构化心跳、支持快照查询，并为并行任务声明 disjoint write set 或显式合并策略。

#### 技术方案要点

1. **心跳协议 Schema**
   - **消息格式**（JSON，UTF-8）：
     ```json
     {
       "protocol_version": "1.0.0",
       "message_type": "worker_heartbeat",
       "run_id": "<ulid>",
       "task_id": "<task_id>",
       "session_id": "<uuid>",
       "timestamp": "<ISO-8601>",
       "stage": "running|paused|blocked|completed|error",
       "progress": {
         "completed_count": 3,
         "total_count": 7,
         "in_progress_tasks": ["subtask-4", "subtask-5"],
         "blocked_tasks": ["subtask-6"]
       },
       "eta_seconds": 420,
       "block_reason": "waiting_for_upstream_artifact|resource_exhausted|manual_approval|error_retry",
       "resource_usage": {
         "cpu_percent": 45.2,
         "memory_mb": 512
       }
     }
     ```
   - **发送频率**：
     - 正常执行期间：每 30 秒 ± 5 秒抖动发送一次
     - 每完成一个子任务：立即发送一次（作为里程碑心跳）
     - 进入 `blocked` 或 `error` 状态：立即发送一次，并在阻塞解除前每 60 秒重发
   - **传输方式**：优先通过 `POST /orchestra/runs/{run_id}/heartbeat` 提交；若网络不可用，worker 本地缓冲最近 10 条心跳，恢复后批量上报。
   - **心跳 ID 去重**：每条心跳含单调递增 `heartbeat_seq`（uint64，每 session 从 1 开始），Gateway 拒绝已处理序列号的重复心跳。

2. **Sweeper 调度与超时检测**
   - **调度策略**：
     - 使用独立进程/线程 `worker_session_sweeper`，与 Gateway 主进程解耦
     - 调度周期：每 60 秒执行一次扫描（通过 `sched` 模块或 cron 式循环）
     - 扫描范围：所有状态为 `running` 或 `blocked` 的 `worker_session_record`
   - **超时判定规则**：
     - 硬超时（Hard Timeout）：自 `last_heartbeat_at` 起超过 120 秒未收到心跳 → 标记 session 为 `zombie`，触发 `worker_zombie_detected` 事件， Gateway 发起强制清理
     - 软超时（Soft Timeout）：自 `dispatched_at` 起超过 task 预估时间 200% 且未进入 `completed` → 标记为 `likely_stalled`，触发告警但暂不强制终止（允许人工介入）
     - 阻塞超时（Block Timeout）：`stage=blocked` 且 `block_reason=manual_approval` 超过 3600 秒 → 自动上浮为 `escalation` 事件，通知 User 与 Kimi
   - **清理动作**：
     - 对 `zombie` session：强制终止 worker 进程（若可访问）、归档 workspace 到 `worker-sessions/archive/`、更新 session 状态为 `force_cleaned`
     - 对 `likely_stalled`：发送 `heartbeat_probe` 到 worker，若 30 秒内无响应则升级为 `zombie`
   - **持久化**：sweeper 每次扫描结果写入 `events.jsonl`，包含 `sweep_run_id`、`scanned_sessions_count`、`zombie_count`、`stalled_count`。

3. **Write Set 格式**
   - **定义**：`write_set` 是一个声明式路径集合，描述 task 计划修改的文件范围。
   - **结构**：
     ```json
     {
       "write_set_id": "<uuid>",
       "task_id": "<task_id>",
       "run_id": "<ulid>",
       "declared_paths": [
         {"path": "src/module/a.py", "intent": "modify", "optional": false},
         {"path": "tests/test_a.py", "intent": "create", "optional": true}
       ],
       "path_normalization": "project_root_relative",
       "computed_at": "<ISO-8601>"
     }
     ```
   - **路径归一化规则**：
     1. 以项目根目录为基准，去除 `./` 前缀
     2. 使用正斜杠 `/` 作为分隔符（统一 Windows/Unix）
     3. 禁止包含 `..` 段（目录逃逸）
     4. 禁止绝对路径（以 `/` 或盘符开头）
     5. 对 glob 模式（如 `src/**/*.py`），在 dispatch 前展开为具体路径集合后再做交集检测
   - **disjoint 判定算法**：
     - 给定两个 task 的 `declared_paths[]`，分别提取 `path` 字段构成集合 A、B
     - 计算交集 `A ∩ B`
     - 若交集为空 → `disjoint=true`
     - 若交集非空 → `disjoint=false`，必须提供 `merge_strategy` 或改为串行执行

4. **Merge Strategy 枚举**
   - **支持策略**：
     1. `ordered_merge` — 按 task 拓扑序依次应用，后执行的覆盖先执行的；适用于无逻辑依赖的独立文件修改
     2. `last_writer_wins` — 同一文件的多个修改取最后完成 task 的版本；适用于配置/元数据类文件
     3. `manual_conflict_resolution` — 发现写集重叠时暂停执行，通知 User/Kimi 手动裁决；适用于高风险核心文件
     4. `abort_on_conflict` — 发现写集重叠时直接中止并行执行，全部降级为串行；适用于保守策略
   - **选择规则**：
     - 默认策略：若 Sprint 6 的 DAG 未显式声明，则使用 `abort_on_conflict`（最安全）
     - 显式声明：在 `implementation_report.tasks[].merge_strategy` 中指定，Gateway dispatch 时校验其合法性
     - 非法策略：Worker 提交未在枚举中的策略字符串 → Gateway 返回 `invalid_merge_strategy`
   - **策略执行**：
     - Gateway 在 dispatch 前对并行边界组内所有 task 的 `write_set` 执行 disjoint 检测
     - 若 `disjoint=false` 且无合法 `merge_strategy` → 返回 `parallel_write_conflict` 并阻断 dispatch
     - 若 `disjoint=false` 但 `merge_strategy=ordered_merge|last_writer_wins` → 在 `worker_session_record` 中标记 `conflict_accepted=true` 并记录策略
     - 若 `merge_strategy=manual_conflict_resolution` → 生成 `conflict_resolution_pending` 事件并等待外部决策

#### 验收标准

- **AC-1**: 执行期间每 30 秒或每完成一个子任务发送结构化心跳
  - 心跳消息符合上述 JSON schema，`protocol_version` 为 `"1.0.0"`
  - `stage`、`completed_count`、`in_progress_tasks`、`eta_seconds`、`block_reason` 字段均存在且类型正确
  - 连续 120 秒未收到心跳时 sweeper 标记为 `zombie`
- **AC-2**: 用户可随时查询实时快照而不中断执行
  - `GET /orchestra/runs/{run_id}/snapshot` 返回 200，包含当前所有 `running`/`blocked` task 的最新心跳摘要
  - 查询不触发 worker 侧任何状态变更（只读操作）
  - 快照数据与最近一次心跳的延迟 ≤ 35 秒
- **AC-3**: Sweeper 每 60 秒扫描并检测超时 session
  - `events.jsonl` 中可检索到 `sweep_run` 事件，包含 `scanned_sessions_count`
  - 对 `zombie` session 生成 `worker_zombie_detected` 事件并执行强制清理
  - 对 `likely_stalled` session 生成 `worker_likely_stalled` 告警
- **AC-4**: 并行任务必须声明 disjoint write set 或显式 merge strategy
  - 两个 task 的 `declared_paths` 无交集且无 `merge_strategy` → 允许 dispatch
  - 两个 task 的 `declared_paths` 有交集且无 `merge_strategy` → `parallel_write_conflict`，拒绝 dispatch
  - 有交集且 `merge_strategy=ordered_merge` → 允许 dispatch，并在 session 中记录策略
- **AC-5**: Merge strategy 必须是枚举值之一
  - `ordered_merge`、`last_writer_wins`、`manual_conflict_resolution`、`abort_on_conflict` 均合法
  - 提交 `three_way_merge` 等非法值 → `invalid_merge_strategy`
- **AC-6**: 心跳序列号去重可抵御重复提交
  - 同一 `heartbeat_seq` 被重复提交两次，Gateway 仅处理第一次，第二次返回 `heartbeat_duplicate_ignored`
  - 乱序到达的心跳（seq N+2 先于 seq N+1）被缓冲等待，直到 seq N+1 到达后按序处理

#### 负向用例

- **NE-1**: Worker 进程崩溃后心跳停止，但 sweeper 未及时检测，用户长时间看到 "进行中" 的虚假状态。
  - 缓解：硬超时阈值 120 秒（2 个心跳周期 + 裕量）；sweeper 每 60 秒扫描，最坏情况 180 秒内必发现 zombie。
- **NE-2**: Worker 恶意伪造心跳（如持续发送 `stage=running` 但无实际进展）以逃避超时检测。
  - 缓解：心跳中 `progress.completed_count` 必须单调不减；Gateway 校验若发现回退则标记 `heartbeat_progress_regression` 并触发审计。
- **NE-3**: 并行 task 的 write set 使用语义上不同但路径相同的文件（如 `src/config.py` 与 `./src/config.py`），因归一化不足导致 disjoint 检测误报为不冲突。
  - 缓解：严格的 path normalization 规则（统一分隔符、去除 `./`、禁止 `..`），并在检测前对 glob 模式展开为具体路径。
- **NE-4**: `merge_strategy=last_writer_wins` 被用于逻辑上不能覆盖的核心业务文件，导致数据丢失。
  - 缓解：Gateway 对 `protected_targets` 列表中的路径模式，强制拒绝 `last_writer_wins` 策略，必须使用 `manual_conflict_resolution` 或 `abort_on_conflict`。

#### 架构红线合规项

- **Seam Extraction 检查**：心跳处理逻辑封装到 `scripts/lib/heartbeat_handler.py`；sweeper 逻辑封装到 `scripts/lib/worker_session_sweeper.py`（已存在，本轮增强）；write set 验证封装到 `scripts/lib/write_scope_validator.py`（与 S8 复用）；Gateway 仅保留 API facade，净增长 ≤ 50 行。
- **Gateway 行数增长限制**：`orch_gateway.py` 净增长 ≤ 50 行。
- **进程隔离**：sweeper 必须与 Gateway 主进程分离运行（独立进程或独立线程），sweeper 崩溃不得影响 Gateway 服务。

#### 文档更新要求

- [ ] 更新 `docs/sandbox-simulation-report.md`，补充心跳协议 schema 与 sweeper 调度说明
- [ ] 更新 `docs/user-flow-guide_by_kimi.md`，补充实时快照查询的交互说明与错误码释义
- [ ] 更新 `docs/sprints/prd-by-kimi-user-flow-strict/schema.md`，补充 `heartbeat_message`、`sweep_result`、`write_set`、`merge_strategy_enum` 数据模型
- [ ] 更新 `docs/gateway-integration-architecture.md`，补充心跳→快照→sweeper 的数据流图
- [ ] 新增 `scripts/tests/test-heartbeat-schema.sh`、`scripts/tests/test-sweeper-zombie-detection.sh`、`scripts/tests/test-write-set-disjoint.sh`、`scripts/tests/test-merge-strategy-enum.sh`、`scripts/tests/test-snapshot-readonly.sh`

#### 跨 Sprint 接口契约

- **输入（来自 Sprint 8）**：`worker_session_record`（含 `session_id`、`status`、`computed_write_scope[]`、`workspace_path`、`dispatch_token`）
  - 心跳消息中的 `session_id` 必须与 Sprint 8 创建的 session 记录匹配
  - sweeper 扫描范围限定为 Sprint 8 创建的 `status=running|blocked` 的 session
- **输出（供 Sprint 10+ 消费）**：`events.jsonl` 中的 `heartbeat`、`sweep_result`、`parallel_write_conflict` 事件
  - Sprint 10 的四阶改进闭环将读取这些事件作为 A-E 分类的输入数据
  - Sprint 12 的六阶审计将读取心跳历史以验证执行期间无异常静默
- **接口格式约束**：
  - `heartbeat_seq` 为 uint64，每 session 单调递增，从 1 开始
  - `timestamp` 必须为 ISO-8601 格式（含时区偏移或 Z），精度到毫秒
  - `write_set.declared_paths[].intent` 枚举值为 `create`、`modify`、`delete`
  - `eta_seconds` 为整数或 -1（表示无法估计）

#### 涉及文件

Modify: `scripts/lib/orch_gateway.py`, `docs/sandbox-simulation-report.md`, `docs/user-flow-guide_by_kimi.md`, `scripts/tests/test-gateway-events-sse.sh`, `scripts/tests/test-gateway-events-pagination.sh`, `scripts/tests/test-gateway-events-rebuild.sh`, `scripts/tests/test-e2e-ai-worker-flow.sh`, `scripts/tests/test-backpressure-basic.sh`
Create: `scripts/lib/heartbeat_handler.py`, `scripts/tests/test-heartbeat-schema.sh`, `scripts/tests/test-sweeper-zombie-detection.sh`, `scripts/tests/test-write-set-disjoint.sh`, `scripts/tests/test-merge-strategy-enum.sh`, `scripts/tests/test-snapshot-readonly.sh`
