# Sprint 8 Plan

**总故事点**: 5 SP / 7 SP 容量
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U8 | 三阶分派执行、工作区隔离与证据门控 | 5 | U7 | ⬜ |

## 详细说明

### Task 1 (U8): 三阶分派执行、工作区隔离与证据门控

- **目标**: 把三阶执行收紧为受控分派流程，明确 Gateway/Kanban authority、worker 生命周期、独立 workspace、写入范围、测试与审查证据门控。

#### 技术方案要点

1. **Write scope 校验方案（解决自证漏洞）**
   - **核心问题**：worker 自报的 `actual_write_scope` 不可信（可自证漏洞），必须由 Gateway 基于上游可信输入独立计算 `expected_write_scope`，两者对比通过后才允许推进。
   - **expected_write_scope 计算规则**：
     1. Gateway 读取 Sprint 6 输出的 `implementation_report.tasks[]`
     2. 按 `task_id` 提取 `write_scope[]` 字段（归一化相对路径数组）
     3. 若 task 属于 `parallel_boundary_id` 组，汇总该组所有 task 的 write_scope，执行交集检测；存在非空交集时，在分派前返回 `parallel_write_scope_overlap` 并阻断
     4. 将 `expected_write_scope` 写入 `worker_session_record` 的 `computed_write_scope` 字段（该字段由 Gateway 计算，worker 不可覆写）
   - **actual_write_scope 校验流程**：
     1. Worker 完成任务后提交 `completion_payload`，内含 `reported_write_scope[]` 与 `file_manifest[]`（每个文件含 path + sha256）
     2. Gateway 对比 `reported_write_scope` 与 `computed_write_scope`：
        - 若 `reported_write_scope` 包含 `computed_write_scope` 之外的路径 → `write_scope_violation`，拒绝推进
        - 若 `file_manifest` 中的路径不在 `computed_write_scope` 内 → `unexpected_file_detected`，拒绝推进
        - 若 `reported_write_scope` 是 `computed_write_scope` 的真子集 → 允许（保守写入合法）
     3. 校验结果写入 `audit.jsonl` 的 `write_scope_check` 事件
   - **路径归一化**：所有路径在执行对比前必须经过 `os.path.normpath` + 去除 `./` 前缀 + 强制相对路径（禁止以 `/` 开头）；绝对路径直接视为 violation。

2. **分派流程技术强制力**
   - **Kanban authority token**：每次分派生成唯一的 `dispatch_token`（UUIDv4），绑定到 `run_id + task_id + assigned_actor + expiry_time`。
   - **分派门控（Dispatch Gate）**：
     1. Gateway 接收 `POST /orchestra/runs/{run_id}/tasks/{task_id}/dispatch`
     2. 校验请求 actor 具有 `advance_stage` capability 且为当前 task 的合法 assignee
     3. 检查 task 状态为 `ready_for_dispatch`（已通过二阶 DAG 验证与同源隔离检测）
     4. 生成 `dispatch_token`，创建 `worker_session_record`，写入 `computed_write_scope`
     5. 返回 dispatch 响应，含 `session_id`、`workspace_path`、`dispatch_token`、`computed_write_scope`
   - **直接推进拦截**：Claude/Codex 任何不携带有效 `dispatch_token` 的阶段推进请求，一律返回 `dispatch_token_required`。
   - **上下文隔离**：每个 worker session 分配独立 workspace 目录（`worker-sessions/{run_id}/{task_id}/{session_id}/`），通过文件系统权限（chmod 700）隔离；不支持文件系统隔离的环境（如共享容器）使用 `context_bundle_id` + 沙箱命名空间作为等价隔离证明。

3. **证据门控（Evidence Gate）**
   - **必填证据类型**：
     - `test_evidence`: 测试脚本执行结果（exit code + stdout 摘要 + 覆盖率，若适用）
     - `review_evidence`: 代码审查输出（reviewer_id + 审查结论 + 阻塞性问题列表）
     - `commit_evidence`: 变更提交记录（commit hash + diff stat + 关联 issue）
   - **门控规则**：
     - 任一必填证据缺失 → `evidence_missing`，拒绝阶段推进
     - `test_evidence.exit_code != 0` → `test_failure`，拒绝阶段推进
     - `review_evidence.blockers[]` 非空 → `review_blockers_unresolved`，拒绝阶段推进
   - **证据引用完整性**：`completion_payload.evidence_refs[]` 中的每个引用必须在 `artifacts[]` 或外部存储中存在对应实体；无法解析的引用触发 `evidence_ref_unresolvable`。

4. **Worker 生命周期状态机**
   - `created` → `dispatched`（收到 dispatch 请求）→ `running`（worker 心跳首次上报）→ `evidence_submitted`（提交 completion_payload）→ `gateway_verifying`（Gateway 执行 write scope + evidence 校验）→ `completed`（校验通过）或 `rejected`（校验失败）→ `cleaned_up`（sweeper 清理 workspace）
   - 任一状态停留超时（如 `running` 超过 task 预估时间 200%）触发 `worker_timeout` 告警。

#### 验收标准

- **AC-1**: 三阶执行任务只能通过 Gateway/Kanban 分派
  - 直接调用 Kanban 原始状态修改接口（绕过 Gateway dispatch）返回 `dispatch_token_required`
  - 合法 dispatch 请求返回 200 并包含 `dispatch_token` 与 `computed_write_scope`
- **AC-2**: 每个代理具有独立 workspace 或等价上下文隔离
  - 分派响应包含 `workspace_path`，该路径在文件系统层面与其他 task 的 workspace 不重叠
  - `worker_session_record` 包含 `workspace_path` 与 `context_bundle_id`
- **AC-3**: Gateway 计算的 expected_write_scope 可拦截越权写入
  - Worker 提交 `reported_write_scope` 包含 `computed_write_scope` 之外的路径 → Gateway 返回 `write_scope_violation`
  - `file_manifest` 中出现 `computed_write_scope` 之外的路径 → Gateway 返回 `unexpected_file_detected`
- **AC-4**: 无证据的完成声明不得推进阶段
  - 缺失 `test_evidence` 的 completion_payload → `evidence_missing`
  - 缺失 `review_evidence` 的 completion_payload → `evidence_missing`
  - 测试 exit code 非零 → `test_failure`
- **AC-5**: 审查阻塞性问题未解决不得推进
  - `review_evidence.blockers[]` 非空 → `review_blockers_unresolved`
  - blockers 为空但存在 warnings → 允许通过（warnings 不阻塞）
- **AC-6**: 分派 token 过期或伪造无法推进阶段
  - 过期 `dispatch_token`（超过 expiry_time）→ `dispatch_token_expired`
  - 伪造 `dispatch_token`（签名不匹配或 UUID 格式错误）→ `dispatch_token_invalid`

#### 负向用例

- **NE-1**: Worker 通过符号链接（symlink）将 `computed_write_scope` 之外的真实路径映射到允许路径内，绕过 write scope 校验。
  - 缓解：Gateway 在 `file_manifest` 校验阶段，对每条路径执行 `os.path.realpath` 解析符号链接后再做范围比对；发现 symlink 指向范围外路径时返回 `symlink_escape_detected`。
- **NE-2**: Worker 在提交 completion_payload 后、Gateway 校验前，恶意修改已提交的文件内容，导致 `file_manifest.sha256` 与实际文件不一致。
  - 缓解：Gateway 在 evidence verification 阶段重新计算文件 sha256，与 `file_manifest` 中的声明对比；不一致时返回 `file_integrity_mismatch`。
- **NE-3**: 两个并行 worker 的 `computed_write_scope` 存在隐藏交集（如一个写 `src/utils.py`，另一个通过 glob 写 `src/*`），导致写冲突。
  - 缓解：Gateway 在 dispatch 前对并行边界组执行 write scope 交集预检；使用归一化后的路径集合做交集运算；发现交集非空时返回 `parallel_write_scope_overlap` 并禁止并行分派。

#### 架构红线合规项

- **Seam Extraction 检查**：Write scope 校验逻辑封装到 `scripts/lib/write_scope_validator.py`；Evidence gate 封装到 `scripts/lib/evidence_gate.py`；Worker session 管理封装到 `scripts/lib/worker_session.py`；Gateway 仅保留 dispatch facade，净增长 ≤ 60 行。
- **Gateway 行数增长限制**：`orch_gateway.py` 净增长 ≤ 60 行。
- **状态外置原则**：`worker_session_record` 的读写优先通过 `worker_session.py` 完成，禁止 Gateway 直接操作 `worker-sessions/*.json` 文件。

#### 文档更新要求

- [ ] 更新 `docs/gateway-integration-architecture.md`，补充 dispatch 时序图、write scope 校验流程图、evidence gate 判定树
- [ ] 更新 `docs/sprints/prd-by-kimi-user-flow-strict/schema.md`，补充 `dispatch_token`、`worker_session_record`、`write_scope_check`、`evidence_gate_result` 数据模型
- [ ] 更新 `docs/user-flow-guide_by_kimi.md`，补充三阶分派的交互说明与错误码释义
- [ ] 新增 `scripts/tests/test-write-scope-violation.sh`、`scripts/tests/test-evidence-missing-blocks.sh`、`scripts/tests/test-dispatch-token-forgery.sh`、`scripts/tests/test-parallel-write-scope-overlap.sh`

#### 跨 Sprint 接口契约

- **输入（来自 Sprint 7）**：`run_projection` 中 `tasks[].task_id`、`tasks[].assigned_actor`、`tasks[].write_scope`
  - Gateway dispatch 时必须以该投影中的 `assigned_actor` 与 `write_scope` 为基准
- **输出（供 Sprint 9 消费）**：`worker_session_record`
  - 必须包含：`session_id`、`run_id`、`task_id`、`assigned_actor`、`workspace_path`、`computed_write_scope[]`、`dispatch_token`、`created_at`、`status`
  - Sprint 9 的心跳协议与 sweeper 将读取该记录以检测超时与僵尸 session
- **接口格式约束**：
  - `dispatch_token` 为 UUIDv4 字符串（36 字符）
  - `write_scope[]` 元素为归一化相对路径，禁止绝对路径，禁止包含 `..` 段
  - `file_manifest[]` 每个条目必须包含 `path`（归一化相对路径）与 `sha256`（64 字符 hex）

#### 涉及文件

Modify: `scripts/lib/orch_gateway.py`, `scripts/lib/worker_session.py`, `scripts/lib/worker_session_sweeper.py`, `docs/gateway-integration-architecture.md`, `scripts/tests/test-worker-session.sh`, `scripts/tests/test-project-isolation.sh`, `scripts/tests/test-gateway-worker-output-write-scope-violation.sh`, `scripts/tests/test-gateway-worker-output-evidence-missing.sh`, `scripts/tests/test-kanban-handoff.sh`
Create: `scripts/lib/write_scope_validator.py`, `scripts/lib/evidence_gate.py`, `scripts/tests/test-write-scope-violation.sh`, `scripts/tests/test-evidence-missing-blocks.sh`, `scripts/tests/test-dispatch-token-forgery.sh`, `scripts/tests/test-parallel-write-scope-overlap.sh`
