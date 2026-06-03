# Sprint 9 验收清单

## 验收条件（可独立验证子项）

### AC-1: 执行期间每 30 秒或每完成一个子任务发送结构化心跳
- **可执行断言**: 心跳消息符合 JSON schema，`protocol_version` 为 `"1.0.0"`，`stage`、`completed_count`、`in_progress_tasks`、`eta_seconds`、`block_reason` 字段均存在且类型正确；连续 120 秒未收到心跳时 sweeper 标记为 `zombie`
- **测试脚本**: `scripts/tests/test-heartbeat-schema.sh`
- **负向用例**: Worker 进程崩溃后心跳停止，但 sweeper 因扫描周期配置错误（如 600 秒）导致 10 分钟后才发现 zombie
- **状态**: ✅

### AC-2: 用户可随时查询实时快照而不中断执行
- **可执行断言**: `GET /orchestra/runs/{run_id}/snapshot` 返回 200，包含当前所有 `running`/`blocked` task 的最新心跳摘要；查询不触发 worker 侧任何状态变更（只读操作）；快照数据与最近一次心跳的延迟 ≤ 35 秒
- **测试脚本**: `scripts/tests/test-snapshot-readonly.sh`
- **负向用例**: 快照查询被错误地实现为 `POST` 并带有副作用（如触发 worker 侧状态刷新），导致并发查询影响执行性能
- **状态**: ✅

### AC-3: Sweeper 每 60 秒扫描并检测超时 session
- **可执行断言**: `events.jsonl` 中可检索到 `sweep_run` 事件，包含 `scanned_sessions_count`；对 `zombie` session 生成 `worker_zombie_detected` 事件并执行强制清理；对 `likely_stalled` session 生成 `worker_likely_stalled` 告警
- **测试脚本**: `scripts/tests/test-sweeper-zombie-detection.sh`
- **负向用例**: Sweeper 进程崩溃后未重启，所有 session 超时检测永久失效，worker 僵尸状态不被发现
- **状态**: ✅

### AC-4: 并行任务必须声明 disjoint write set 或显式 merge strategy
- **可执行断言**: 两个 task 的 `declared_paths` 无交集且无 `merge_strategy` → 允许 dispatch；有交集且无 `merge_strategy` → `parallel_write_conflict`，拒绝 dispatch；有交集且 `merge_strategy=ordered_merge` → 允许 dispatch，并在 session 中记录策略
- **测试脚本**: `scripts/tests/test-write-set-disjoint.sh`
- **负向用例**: 两个 task 使用语义不同但路径相同的文件（如 `src/config.py` 与 `./src/config.py`），因归一化不足导致 disjoint 检测误报为不冲突，执行后数据损坏
- **状态**: ✅

### AC-5: Merge strategy 必须是枚举值之一
- **可执行断言**: `ordered_merge`、`last_writer_wins`、`manual_conflict_resolution`、`abort_on_conflict` 均合法；提交 `three_way_merge` 等非法值 → `invalid_merge_strategy`
- **测试脚本**: `scripts/tests/test-merge-strategy-enum.sh`
- **负向用例**: `merge_strategy` 字段为空字符串，Gateway 未拒绝而采用未定义行为，导致后续合并逻辑异常
- **状态**: ✅

### AC-6: 心跳序列号去重可抵御重复提交
- **可执行断言**: 同一 `heartbeat_seq` 被重复提交两次，Gateway 仅处理第一次，第二次返回 `heartbeat_duplicate_ignored`；乱序到达的心跳（seq N+2 先于 seq N+1）被缓冲等待，直到 seq N+1 到达后按序处理
- **测试脚本**: `scripts/tests/test-heartbeat-schema.sh`（去重子用例）
- **负向用例**: 网络分区恢复后 worker 批量重放心跳，Gateway 的 seq 缓冲区溢出导致部分心跳丢失，进度回退
- **状态**: ✅

## 架构红线合规
- [x] 新增 `scripts/lib/heartbeat_handler.py` 独立模块，心跳处理未直接追加到 `orch_gateway.py`
- [x] `scripts/lib/worker_session_sweeper.py` 增强后，sweeper 逻辑未直接追加到 `orch_gateway.py`
- [x] `orch_gateway.py` 净增长 ≤ 50 行
- [x] Sweeper 与 Gateway 主进程分离运行（验证 `ps` 或进程列表中存在独立 sweeper 进程/线程）
- [x] `write_scope_validator.py` 被 S8 与 S9 复用，无代码重复

## 文档交付物
- [x] `docs/sandbox-simulation-report.md` 已更新，包含心跳协议 schema 与 sweeper 调度说明
- [x] `docs/user-flow-guide_by_kimi.md` 已更新，包含实时快照查询的交互说明与错误码释义
- [x] `docs/sprints/prd-by-kimi-user-flow-strict/schema.md` 已补充 `heartbeat_message`、`sweep_result`、`write_set`、`merge_strategy_enum` 数据模型
- [x] `docs/gateway-integration-architecture.md` 已更新，包含心跳→快照→sweeper 的数据流图
- [x] `events.jsonl` 中存在 `heartbeat`、`sweep_result`、`parallel_write_conflict` 三类事件记录

## 任务完成状态
- [x] U9 — 三阶心跳、实时快照与并行写集策略（所有 AC 断言通过）

## 验证命令汇总

```bash
rtk bash scripts/tests/test-heartbeat-schema.sh
rtk bash scripts/tests/test-sweeper-zombie-detection.sh
rtk bash scripts/tests/test-write-set-disjoint.sh
rtk bash scripts/tests/test-merge-strategy-enum.sh
rtk bash scripts/tests/test-snapshot-readonly.sh
rtk bash scripts/tests/test-gateway-events-sse.sh
rtk bash scripts/tests/test-gateway-events-pagination.sh
rtk bash scripts/tests/test-gateway-events-rebuild.sh
rtk bash scripts/tests/test-e2e-ai-worker-flow.sh
rtk bash scripts/tests/test-backpressure-basic.sh
```

## 签核
- [x] 开发完成
- [x] 测试通过（所有 AC 断言通过）
- [x] Code Review 完成
- [x] 架构红线合规确认
- [ ] 合并到 main

[2026-06-02] Verified by Codex — all tests passed
