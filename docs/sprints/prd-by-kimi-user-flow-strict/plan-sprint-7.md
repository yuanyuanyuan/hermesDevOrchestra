# Sprint 7 Plan

**总故事点**: 5 SP / 7 SP 容量
**任务数**: 1 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U7 | Gateway Run Projection API 与六类状态投影 | 5 | U6 | ⬜ |

## 详细说明

### Task 1 (U7): Gateway Run Projection API 与六类状态投影

- **目标**: 以 Gateway 为状态权威补齐 Run Projection API 和六类实体投影，确保 Kimi 只能通过投影与决策推进流程，而不能直接改 Kanban 原始状态。

#### 技术方案要点

1. **Actor 认证机制**
   - **身份模型**：所有写入操作必须携带 `actor_token`，Gateway 校验 token 后解析出 `actor_id` 与 `actor_type`。
   - **Actor 类型枚举**：`kimi`（外部 AI 顾问）、`gateway`（系统内部）、`hermes_agents`（自动化代理群）、`claude_codex`（编码代理）、`user`（人类用户）。
   - **Token 格式**：`actor_token = base64(actor_type + ":" + actor_id + ":" + hmac_sha256(secret, actor_type + actor_id + timestamp))`
   - **校验流程**：
     1. Gateway 接收请求头 `X-Actor-Token`
     2. 解析 token，验证 HMAC 签名（secret 来自 `config/decisions/actor-secrets.json`，文件权限 600）
     3. 检查 token 未过期（有效期 300 秒，允许 30 秒时钟漂移）
     4. 从 `authority_matrix` 查询该 actor 的 capability 列表
     5. 对比请求操作与 allowed capabilities，不匹配则返回 `403 actor_capability_denied`
   - **L3/L4 审批者识别**：L3 审批者 token 包含 `approval_level: L3` claim；L4 包含 `approval_level: L4` + `protected_target_pattern` 白名单。
   - **Token 撤销**：支持通过 `POST /orchestra/actors/{actor_id}/revoke` 使 token 失效，Gateway 维护内存级 revoked-token 缓存（TTL 600 秒，持久化到 `audit.jsonl`）。

2. **Projection API 端点详细定义**
   - **端点 1 — 读取投影**：`GET /orchestra/runs/{run_id}/projection`
     - 请求参数：`?entity_types=run,tasks,artifacts,decisions,audits,events`（可选，默认全部）
     - 请求头：`X-Actor-Token: <token>`
     - 响应 200：JSON 对象，包含 `run`、`tasks[]`、`artifacts[]`、`decisions[]`、`audits[]`、`events[]`
     - 响应 403：`{ "error": "actor_capability_denied", "actor": "...", "required_capability": "..." }`
     - 响应 404：`{ "error": "run_not_found", "run_id": "..." }`
   - **端点 2 — 刷新投影**：`POST /orchestra/runs/{run_id}/projection`
     - 请求体：`{ "refresh_entities": ["tasks", "artifacts"], "reason": "stage_advance" }`
     - 触发 Gateway 从 Kanban/WorkerSession 重新聚合数据并更新投影
     - 响应 200：返回更新后的投影全文
     - 响应 409：若 `reason` 不是已知枚举值（`stage_advance`, `heartbeat_sync`, `audit_rebuild`, `manual_refresh`），返回 `invalid_refresh_reason`
   - **端点 3 — 权限矩阵视图**：投影响应中必须内嵌 `authority_matrix_view`，展示当前 actor 对每个 capability 的 `allowed`/`blocked`/`requires_approval` 状态。
   - **端点 4 — intake 来源投影**：投影中的 `run.intake_projection` 必须包含 `original_intent_source`、`confidence_score`、`conflict_summary`、`dependency_projection`。

3. **六类状态投影持久化**
   - `run`: run 级元数据（id, stage, created_at, actor_tokens[], current_blockers[]）
   - `tasks[]`: 每个 task 的 stage、assignee、write_scope、evidence_refs[]、test_results[]
   - `artifacts[]`: artifact id、type、path、checksum、produced_by_task、verified_by_gate
   - `decisions[]`: decision id、type、actor、timestamp、rationale、approval_level（若需审批）
   - `audits[]`: audit event id、event_type、actor、timestamp、before_state、after_state
   - `events[]`: event id、event_type、payload、timestamp、run_id
   - 持久化介质：沿用现有文件态（`run.json`、`tasks.json`、`events.jsonl`、`audit.jsonl`），本轮不新增数据库表；但 Projection API 返回的 JSON 必须显式标注 `projection_schema_version: "1.0.0"`。

4. **PRD §2.2 权限矩阵落地**
   - 权限矩阵显式覆盖 8 类能力（详见 `docs/sprints/prd-by-kimi-user-flow-strict/schema.md` 的 `authority_matrix` 定义）：
     1. `create_run` — Kimi/Gateway/User 允许；Claude/Codex 禁止
     2. `hydrate_requirements` — Kimi 允许；Claude/Codex 需 Gateway 代理
     3. `mutate_kanban_raw_state` — 仅 Gateway 允许；Kimi/Claude/Codex/User 全部禁止
     4. `advance_stage` — Gateway 允许；Claude/Codex 在提交 evidence 后经 Gateway 校验允许；Kimi 仅允许通过 projection 发起请求
     5. `select_debate_teams` — Kimi 允许；Claude/Codex 禁止
     6. `code_or_review` — Claude/Codex 允许（在其 assigned task 范围内）；Kimi 禁止
     7. `approve_l3_l4` — User 允许（L3/L4 审批者 token）；Kimi 允许（review 建议但无最终权）；Gateway 禁止
     8. `apply_self_evolution` — User 允许（最终确认）；Kimi 允许（review）；Gateway 禁止直接应用
   - 矩阵以 JSON 文件形式落地到 `config/decisions/authority-matrix.json`，Gateway 启动时加载到内存，热更新通过 `SIGHUP` 信号触发重载。
   - **悬空条款处理**：PRD §2.2 原文中"所有状态推进都必须经过 Gateway authority 校验"必须有对应的 enforcement 代码路径——任何直接写入 Kanban 原始状态的请求（绕过 Gateway）必须在 `orch_gateway.py` 的 intake handler 中被拒绝，返回 `mutate_kanban_raw_state_blocked`。

#### 验收标准

- **AC-1**: Gateway 暴露 Kimi-facing Run Projection API，响应包含六类投影
  - `GET /orchestra/runs/{run_id}/projection` 返回 200，且 JSON 包含 `run`、`tasks`、`artifacts`、`decisions`、`audits`、`events` 六个顶级键
  - 响应头包含 `X-Projection-Schema-Version: 1.0.0`
- **AC-2**: 需求补全的来源、置信度、冲突和依赖投影可通过状态接口查询
  - `run.intake_projection.confidence_score` 为数值类型且范围 [0.0, 1.0]
  - `run.intake_projection.conflict_summary` 为数组，每个冲突包含 `type`、`severity`、`involved_entities`
  - `run.intake_projection.dependency_projection` 包含四维依赖图摘要
- **AC-3**: PRD §2.2 权限矩阵显式覆盖 8 类权限
  - `config/decisions/authority-matrix.json` 存在且包含 8 条 capability 定义
  - Gateway 启动日志包含 `authority_matrix_loaded: 8 capabilities`
  - 对未覆盖的第 9 类 capability 请求，Gateway 默认返回 `capability_not_defined` 并拒绝
- **AC-4**: Kimi 不能直接修改 Kanban 原始状态
  - 携带 `actor_type=kimi` 的请求尝试 `mutate_kanban_raw_state`，Gateway 返回 403 且 `error_code=mutate_kanban_raw_state_blocked`
  - 携带 `actor_type=gateway` 的内部调用允许通过
- **AC-5**: Claude/Codex 不能越权推进阶段
  - `actor_type=claude_codex` 尝试 `advance_stage` 但缺少对应 task 的 assignment token，返回 403
  - 在已分配 task 范围内提交 evidence 后，经 Gateway 校验通过可推进
- **AC-6**: Actor 认证机制可拦截伪造/过期 token
  - 伪造 HMAC 签名的 token → 401 `invalid_actor_token`
  - 过期 token（timestamp > 300s + 漂移窗口）→ 401 `actor_token_expired`
  - 已撤销 token → 403 `actor_token_revoked`
- **AC-7**: Projection API 支持刷新并返回更新后数据
  - `POST /orchestra/runs/{run_id}/projection` 携带合法 `refresh_entities`，响应 200 且数据与当前状态一致
  - 携带非法 `reason` 值，响应 409 `invalid_refresh_reason`

#### 负向用例

- **NE-1**: Gateway 重启后 authority-matrix.json 加载失败，系统以空矩阵运行，导致所有请求被默认允许。
  - 缓解：启动时若加载失败，Gateway 立即退出（fail-fast），不进入服务状态；日志输出 `FATAL: authority_matrix_load_failed`。
- **NE-2**: actor_token 泄露后被重放攻击利用。
  - 缓解：token 含 timestamp 且有效期仅 300 秒；Gateway 维护 revoked-token 缓存；对高频重放 IP 启用指数退避。
- **NE-3**: Projection API 返回的 `tasks[]` 与 Kanban 原始状态不一致，Kimi 基于错误投影做出决策。
  - 缓解：每次 `POST /projection` 刷新时，Gateway 强制对比 `tasks.json` 与 Kanban 原始状态的 checksum；不一致时返回 `projection_stale` 并触发后台重聚合。

#### 架构红线合规项

- **Seam Extraction 检查**：Actor 认证逻辑优先封装到 `scripts/lib/actor_auth.py`；Projection 聚合逻辑封装到 `scripts/lib/run_projection.py`；Gateway 仅保留 facade 路由与入口校验，净增长 ≤ 60 行。
- **Gateway 行数增长限制**：`orch_gateway.py` 净增长 ≤ 60 行；超出部分必须外置到 helper module。
- **配置分离**：`actor-secrets.json` 与 `authority-matrix.json` 必须分文件存储，禁止把 secret 混入权限矩阵。

#### 文档更新要求

- [ ] 更新 `docs/gateway-integration-architecture.md`，补充 Projection API 端点定义、Actor 认证时序图、权限矩阵 8 类能力映射表
- [ ] 更新 `docs/FULL-COVERAGE-MATRIX.md`，标记 PRD §2.2 的 8 类权限为「已落地」
- [ ] 更新 `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`，补充 L3/L4 审批者 token 结构与 capability route 说明
- [ ] 更新 `docs/sprints/prd-by-kimi-user-flow-strict/schema.md`，补充 `actor_token`、`projection_response`、`authority_matrix_view` 三个数据模型
- [ ] 新增 `scripts/tests/test-projection-api.sh`、`scripts/tests/test-actor-auth-forgery.sh`、`scripts/tests/test-authority-matrix-8-caps.sh`

#### 跨 Sprint 接口契约

- **输入（来自 Sprint 6）**：`implementation_report.dag`、`implementation_report.tasks[]`（含 `write_scope[]`、`source_fingerprint`）
  - Gateway 在创建 Run Projection 时，将 S6 输出的 DAG 节点映射为 `tasks[]` 投影初始状态
- **输出（供 Sprint 8 消费）**：`run_projection` JSON 中 `tasks[].write_scope` 与 `tasks[].assigned_actor`
  - Sprint 8 的 dispatch 逻辑必须读取该投影中的 task 分配与写入范围，作为分派校验依据
- **输出（供 Sprint 9 消费）**：`run_projection.events[]` 作为心跳事件与实时快照的聚合源
- **接口格式约束**：
  - `run_id` 必须为 ULID 格式（26 字符， Crockford's Base32）
  - `actor_id` 必须为 `^[a-z0-9_-]{3,64}$`
  - `capability` 必须为 8 类权限的枚举值之一，拒绝自由字符串

#### 涉及文件

Modify: `scripts/lib/orch_gateway.py`, `docs/gateway-integration-architecture.md`, `docs/FULL-COVERAGE-MATRIX.md`, `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`, `scripts/tests/test-gateway-authority-matrix.sh`, `scripts/tests/test-gateway-integration-points.sh`, `scripts/tests/test-gateway-capabilities-authority-layers.sh`, `scripts/tests/test-kanban-routing.sh`, `scripts/tests/test-gateway-config-registries.sh`
Create: `scripts/lib/actor_auth.py`, `scripts/lib/run_projection.py`, `config/decisions/authority-matrix.json`, `config/decisions/actor-secrets.json.example`, `scripts/tests/test-projection-api.sh`, `scripts/tests/test-actor-auth-forgery.sh`, `scripts/tests/test-authority-matrix-8-caps.sh`
