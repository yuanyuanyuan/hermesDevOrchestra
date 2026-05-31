# Sprint 8 验收清单

## 验收条件（可独立验证子项）

### AC-1: 三阶执行任务只能通过 Gateway/Kanban 分派
- **可执行断言**: 直接调用 Kanban 原始状态修改接口（绕过 Gateway dispatch）返回 `dispatch_token_required`；合法 dispatch 请求返回 200 并包含 `dispatch_token` 与 `computed_write_scope`
- **测试脚本**: `scripts/tests/test-kanban-handoff.sh`
- **负向用例**: Gateway dispatch 后，worker 绕过 Gateway 直接修改 Kanban 状态，Kanban 层未校验 dispatch_token，导致 authority 旁路
- **状态**: ⬜

### AC-2: 每个代理具有独立 workspace 或等价上下文隔离
- **可执行断言**: 分派响应包含 `workspace_path`，该路径在文件系统层面与其他 task 的 workspace 不重叠；`worker_session_record` 包含 `workspace_path` 与 `context_bundle_id`
- **测试脚本**: `scripts/tests/test-project-isolation.sh`
- **负向用例**: 两个 task 的 workspace 目录因路径归一化错误（如尾部斜杠不一致）被判定为不同，但实际指向同一目录，导致隔离失效
- **状态**: ⬜

### AC-3: Gateway 计算的 expected_write_scope 可拦截越权写入
- **可执行断言**: Worker 提交 `reported_write_scope` 包含 `computed_write_scope` 之外的路径 → Gateway 返回 `write_scope_violation`；`file_manifest` 中出现 `computed_write_scope` 之外的路径 → Gateway 返回 `unexpected_file_detected`
- **测试脚本**: `scripts/tests/test-write-scope-violation.sh`
- **负向用例**: Worker 通过符号链接将范围外路径映射到允许路径内，`file_manifest` 未解析 symlink，Gateway 漏检逃逸
- **状态**: ⬜

### AC-4: 无证据的完成声明不得推进阶段
- **可执行断言**: 缺失 `test_evidence` 的 completion_payload → `evidence_missing`；缺失 `review_evidence` 的 completion_payload → `evidence_missing`；测试 exit code 非零 → `test_failure`
- **测试脚本**: `scripts/tests/test-evidence-missing-blocks.sh`
- **负向用例**: Worker 提交空的 `test_evidence` 对象（字段存在但内容为空），Gateway 未校验字段深度，误判为证据齐全
- **状态**: ⬜

### AC-5: 审查阻塞性问题未解决不得推进
- **可执行断言**: `review_evidence.blockers[]` 非空 → `review_blockers_unresolved`；blockers 为空但存在 warnings → 允许通过
- **测试脚本**: `scripts/tests/test-gateway-worker-output-evidence-missing.sh`
- **负向用例**: Reviewer 将阻塞性问题伪装为 warning（降低 severity），Gateway 仅校验 blockers 数组长度而未校验 severity 分布
- **状态**: ⬜

### AC-6: 分派 token 过期或伪造无法推进阶段
- **可执行断言**: 过期 `dispatch_token`（超过 expiry_time）→ `dispatch_token_expired`；伪造 `dispatch_token`（签名不匹配或 UUID 格式错误）→ `dispatch_token_invalid`
- **测试脚本**: `scripts/tests/test-dispatch-token-forgery.sh`
- **负向用例**: Worker 在 token 过期前 1 秒提交 completion，网络延迟导致请求到达时 token 已过期，合法完成被误判为伪造
- **状态**: ⬜

## 架构红线合规
- [ ] 新增 `scripts/lib/write_scope_validator.py` 独立模块，write scope 校验未直接追加到 `orch_gateway.py`
- [ ] 新增 `scripts/lib/evidence_gate.py` 独立模块，evidence gate 未直接追加到 `orch_gateway.py`
- [ ] `orch_gateway.py` 净增长 ≤ 60 行
- [ ] `worker_session_record` 的读写优先通过 `scripts/lib/worker_session.py` 完成，Gateway 未直接操作 `worker-sessions/*.json`
- [ ] `config/decisions/authority-matrix.json` 中 `mutate_kanban_raw_state` 对 Kimi/Claude/Codex 均为 `allowed=false`

## 文档交付物
- [ ] `docs/gateway-integration-architecture.md` 已更新，包含 dispatch 时序图、write scope 校验流程图、evidence gate 判定树
- [ ] `docs/sprints/prd-by-kimi-user-flow-strict/schema.md` 已补充 `dispatch_token`、`worker_session_record`、`write_scope_check`、`evidence_gate_result` 数据模型
- [ ] `docs/user-flow-guide_by_kimi.md` 已补充三阶分派的交互说明与错误码释义
- [ ] `audit.jsonl` 中存在 `write_scope_check` 与 `source_isolation_check` 两类事件记录

## 任务完成状态
- [ ] U8 — 三阶分派执行、工作区隔离与证据门控（所有 AC 断言通过）

## 验证命令汇总

```bash
rtk bash scripts/tests/test-worker-session.sh
rtk bash scripts/tests/test-project-isolation.sh
rtk bash scripts/tests/test-write-scope-violation.sh
rtk bash scripts/tests/test-evidence-missing-blocks.sh
rtk bash scripts/tests/test-gateway-worker-output-write-scope-violation.sh
rtk bash scripts/tests/test-gateway-worker-output-evidence-missing.sh
rtk bash scripts/tests/test-dispatch-token-forgery.sh
rtk bash scripts/tests/test-parallel-write-scope-overlap.sh
rtk bash scripts/tests/test-kanban-handoff.sh
```

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
