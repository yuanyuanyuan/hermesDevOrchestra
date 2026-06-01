# Sprint 2 Plan

**总故事点**: 6 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U2a | 六分类 Schema & 结构化补全包 | 3 | U1b | ⬜ |
| 2 | U2b | 阻塞校验引擎 & 文件态原子持久化 | 3 | U2a | ⬜ |

## 详细说明

### Task 1 (U2a): 六分类 Schema & 结构化补全包

- **目标**: 把 0 阶补全从"主观总结"提升为带证据的结构化产物，显式保留 6 类信息（意图摘要、依赖图、冲突清单、验收矩阵、执行 prompt envelope、风险标志），并确保产物可直接驱动后续阶段。
- **技术方案要点**:
  - **数据流**: 原始输入 → `gateway_intake.normalize()` → `gateway_projection.project()` → 六分类归并器 → 输出 `requirement-completion-bundle.json`
  - **状态机**: Intake → Classify → EvidenceAttach → ValidateStructure → Output
  - **接口契约**: `RequirementCompletionBundle` schema 必须包含 6 个顶层字段：`intent_summary`、`dependency_graph`、`conflict_list`、`acceptance_matrix`、`prompt_envelope`、`risk_flags`；每个字段内关键结论必须附 `source`、`confidence`、`verification_method`
- **验收标准**:
  - **AC-1**: 《需求补全包》显式保留 6 类信息，且每个关键结论附 `source`（来源文件/行号）、`confidence`（0.0-1.0）、`verification_method`（人工/自动/推断）
  - **AC-2**: 依赖图同时覆盖环境依赖、上游依赖、下游影响、代码依赖四个维度，不能只有单层文件依赖；以 JSON 邻接表或 Mermaid 格式输出
  - **AC-3**: 冲突清单必须显式标注冲突类型（语义冲突/版本冲突/资源冲突/权限冲突）、严重级别（blocking/warning/info）、建议解决策略
  - **AC-4**: 验收矩阵必须包含至少一条可独立验证的验收条件（AC-N 格式），每条关联到对应的测试脚本路径或验证命令
  - **AC-5**: 执行 prompt envelope 必须包含 `system_prompt`、`user_prompt`、`context_window_budget`、`output_schema_ref` 四个字段
- **负向用例**:
  - 输入为模糊意图（"帮我改点东西"）时，系统不应生成看似完整但信息为空（null/空字符串）的补全包；必须输出 `confidence < 0.3` 并进入人工确认节点
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - 六分类归并器不直接耦合 `orch_gateway.py` 路由逻辑，通过 `gateway_projection.py` 扩展输出
- **文档更新要求**:
  - 更新 `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` 新增六分类信息保留要求
  - 更新 `docs/prd_by_kimi.md` 补全包结构定义章节
  - 更新 `docs/user-flow-guide_by_kimi.md` 0 阶补全流程
- **涉及文件**: Modify: `scripts/lib/orch_gateway.py`, Modify: `scripts/lib/gateway_projection.py`, Modify: `config/schemas/orchestra.full.schema.json`, Modify: `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`, Modify: `docs/prd_by_kimi.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Create: `scripts/tests/test-completion-bundle-schema.sh`, Modify: `scripts/tests/test-gateway-run-short-intent-blocks.sh`, Modify: `scripts/tests/test-gateway-decision-approve-intake.sh`, Modify: `scripts/tests/test-full-contract-validation.sh`

### Task 2 (U2b): 阻塞校验引擎 & 文件态原子持久化

- **目标**: 实现"缺任一项即阻塞"的工程强制力，并补全文件态持久化的原子写与损坏恢复机制。
- **技术方案要点**:
  - **数据流**: 补全包生成 → 阻塞校验引擎（检查 6 类信息完整性）→ 校验通过则原子写入 `run.json` / `tasks.json` / `events.jsonl`；校验失败则返回阻塞原因清单并拒绝推进
  - **状态机**: Draft → Validate(6 fields) → Block/Pass → AtomicWrite → Confirm
  - **接口契约**: `BlockerValidator.validate(bundle: RequirementCompletionBundle) -> ValidationResult`；`AtomicWriter.write(path, data) -> WriteReceipt`（基于 write-to-temp + fsync + rename 模式）
- **验收标准**:
  - **AC-1**: 阻塞校验引擎对补全包执行 6 字段强制检查，缺任一项（null/空数组/空对象/空字符串）即返回 `status: blocked`，附带缺失字段清单，下游流程不得继续
  - **AC-2**: 文件写入采用原子写：先写 `.tmp.XXX.{timestamp}.json`，执行 `fsync`，再 `rename` 到目标文件；目标文件损坏时可通过 `.tmp` 文件恢复
  - **AC-3**: 并发写冲突检测：写入前读取文件 mtime，若 mtime 变化则拒绝写入并返回 `status: conflict`，由调用方重试
  - **AC-4**: Gateway 状态投影能追溯原始输入与补全结果之间的映射关系：每个补全包字段必须包含 `source_input_hash` 与 `projection_timestamp`
- **负向用例**:
  - 磁盘空间不足时原子写失败：系统不得留下半写文件；`.tmp` 文件必须在 24h 后自动清理
  - 并发两个进程同时写 `run.json`：后写进程必须检测到 mtime 变化并返回 conflict，禁止覆盖导致数据丢失
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - 阻塞校验引擎与原子写入器作为独立 helper modules，可被其他 Sprint 复用
- **文档更新要求**:
  - 更新 `docs/CONFIGURATION.md` 新增原子写配置与恢复流程
  - 更新 `docs/user-flow-guide_by_kimi.md` 说明阻塞校验行为与人工干预路径
- **涉及文件**: Create: `scripts/lib/blocker_validator.py`, Create: `scripts/lib/atomic_writer.py`, Modify: `scripts/lib/orch_gateway.py`, Modify: `scripts/lib/gateway_projection.py`, Modify: `docs/CONFIGURATION.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Create: `scripts/tests/test-blocker-validator.sh`, Create: `scripts/tests/test-atomic-writer.sh`, Modify: `scripts/tests/test-gateway-run-short-intent-blocks.sh`, Modify: `scripts/tests/test-gateway-decision-approve-intake.sh`, Modify: `scripts/tests/test-full-contract-validation.sh`
