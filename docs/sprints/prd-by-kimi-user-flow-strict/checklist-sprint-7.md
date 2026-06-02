# Sprint 7 验收清单

## 验收条件（可独立验证子项）

### AC-1: Gateway 暴露 Kimi-facing Run Projection API，响应包含六类投影
- **可执行断言**: `GET /orchestra/runs/{run_id}/projection` 返回 200，JSON 包含 `run`、`tasks`、`artifacts`、`decisions`、`audits`、`events` 六个顶级键；响应头包含 `X-Projection-Schema-Version: 1.0.0`
- **测试脚本**: `scripts/tests/test-projection-api.sh`
- **负向用例**: API 响应缺少 `audits` 或 `events` 键，但 HTTP 状态仍为 200，客户端未感知数据缺失
- **状态**: ✅

### AC-2: 需求补全的来源、置信度、冲突和依赖投影可通过状态接口查询
- **可执行断言**: `run.intake_projection.confidence_score` 为数值类型且范围 [0.0, 1.0]；`run.intake_projection.conflict_summary` 为数组且每个元素包含 `type`、`severity`、`involved_entities`；`run.intake_projection.dependency_projection` 包含四维依赖图摘要
- **测试脚本**: `scripts/tests/test-projection-api.sh`（intake 投影子用例）
- **负向用例**: confidence_score 为字符串 `"high"` 而非数值，导致下游指标聚合失败
- **状态**: ✅

### AC-3: PRD §2.2 权限矩阵显式覆盖 8 类权限
- **可执行断言**: `config/decisions/authority-matrix.json` 存在且包含 8 条 capability 定义；Gateway 启动日志包含 `authority_matrix_loaded: 8 capabilities`；对未覆盖的第 9 类 capability 请求返回 `capability_not_defined`
- **测试脚本**: `scripts/tests/test-authority-matrix-8-caps.sh`
- **负向用例**: 权限矩阵文件存在但缺少 `approve_l3_l4`，Gateway 启动未失败，导致 L3/L4 审批无权限校验
- **状态**: ✅

### AC-4: Kimi 不能直接修改 Kanban 原始状态
- **可执行断言**: 携带 `actor_type=kimi` 的请求尝试 `mutate_kanban_raw_state`，Gateway 返回 403 且 `error_code=mutate_kanban_raw_state_blocked`
- **测试脚本**: `scripts/tests/test-gateway-authority-matrix.sh`
- **负向用例**: Kimi 通过伪造 `actor_type=gateway` 的 token 绕过校验，直接修改 Kanban 状态
- **状态**: ✅

### AC-5: Claude/Codex 不能越权推进阶段
- **可执行断言**: `actor_type=claude_codex` 尝试 `advance_stage` 但缺少对应 task 的 assignment token，返回 403；在已分配 task 范围内提交 evidence 后，经 Gateway 校验通过可推进
- **测试脚本**: `scripts/tests/test-gateway-capabilities-authority-layers.sh`
- **负向用例**: Claude/Codex 复用旧的 dispatch_token 为其他 task 推进阶段，Gateway 未校验 token 的 task_id 绑定
- **状态**: ✅

### AC-6: Actor 认证机制可拦截伪造/过期 token
- **可执行断言**: 伪造 HMAC 签名 → 401 `invalid_actor_token`；过期 token（timestamp > 300s + 30s 漂移）→ 401 `actor_token_expired`；已撤销 token → 403 `actor_token_revoked`
- **测试脚本**: `scripts/tests/test-actor-auth-forgery.sh`
- **负向用例**: 时钟漂移超过 30 秒窗口，合法 token 被误判为过期，导致正常操作被阻断
- **状态**: ✅

### AC-7: Projection API 支持刷新并返回更新后数据
- **可执行断言**: `POST /orchestra/runs/{run_id}/projection` 携带合法 `refresh_entities`，响应 200 且数据与当前状态一致；携带非法 `reason` 值，响应 409 `invalid_refresh_reason`
- **测试脚本**: `scripts/tests/test-projection-api.sh`（刷新子用例）
- **负向用例**: 刷新过程中 Kanban 原始状态被并发修改，Projection 返回旧数据，客户端基于 stale 投影做出错误决策
- **状态**: ✅

## 架构红线合规
- [x] 新增 `scripts/lib/actor_auth.py` 独立模块，Actor 认证逻辑未直接追加到 `orch_gateway.py`
- [x] 新增 `scripts/lib/run_projection.py` 独立模块，Projection 聚合逻辑未直接追加到 `orch_gateway.py`
- [x] `orch_gateway.py` 净增长 ≤ 60 行
- [x] `actor-secrets.json` 与 `authority-matrix.json` 为分文件存储，`grep -i secret config/decisions/authority-matrix.json` 返回空
- [x] `actor-secrets.json` 文件权限为 600（`stat -c %a config/decisions/actor-secrets.json` 输出 600）

## 文档交付物
- [x] `docs/gateway-integration-architecture.md` 已更新，包含 Projection API 端点定义、Actor 认证时序图、权限矩阵 8 类能力映射表
- [x] `docs/FULL-COVERAGE-MATRIX.md` 已标记 PRD §2.2 的 8 类权限为「已落地」
- [x] `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` 已补充 L3/L4 审批者 token 结构与 capability route 说明
- [x] `docs/sprints/prd-by-kimi-user-flow-strict/schema.md` 已补充 `actor_token`、`projection_response`、`authority_matrix_view` 数据模型
- [x] `config/decisions/authority-matrix.json` 已落地并可被 Gateway 加载

## 任务完成状态
- [x] U7 — Gateway Run Projection API 与六类状态投影（所有 AC 断言通过）

## 验证命令汇总

```bash
rtk bash scripts/tests/test-projection-api.sh
rtk bash scripts/tests/test-actor-auth-forgery.sh
rtk bash scripts/tests/test-authority-matrix-8-caps.sh
rtk bash scripts/tests/test-gateway-authority-matrix.sh
rtk bash scripts/tests/test-gateway-integration-points.sh
rtk bash scripts/tests/test-gateway-capabilities-authority-layers.sh
rtk bash scripts/tests/test-kanban-routing.sh
rtk bash scripts/tests/test-gateway-config-registries.sh
```

## 签核
- [x] 开发完成
- [x] 测试通过（所有 AC 断言通过）
- [x] Code Review 完成
- [x] 架构红线合规确认
- [ ] 合并到 main

[2026-06-02] Verified by Codex — all tests passed
