# Sprint 3 验收清单

## 验收条件

- [x] **U4**: Worker session lifecycle and output gating tests pass through default runtime behavior.; Parallel integration and cleanup behavior are covered by real-path Gateway tests instead of staged-only fixtures.
- [x] **U6**: Gap analysis and full coverage matrix align with runtime activation, config status, and passing real-path tests.; A completion report exists with debate, worker, runtime-knowledge evidence and residual-risk sections.
- [x] 全部测试通过（exit 0）
- [x] 代码符合项目规范

## 任务完成状态

- [x] U4 — Integrate worker session lifecycle and parallel execution on the default runtime path
- [x] U6 — Re-baseline validation, matrices, and completion reporting

## 验证命令

```bash
rtk bash scripts/tests/test-worker-session.sh
rtk bash scripts/tests/test-worker-lifecycle-timeout.sh
rtk bash scripts/tests/test-e2e-ai-worker-flow.sh
rtk bash scripts/tests/test-gateway-worker-output-complete-task.sh
rtk bash scripts/tests/test-gateway-worker-output-write-scope-violation.sh
rtk bash scripts/tests/test-gateway-capabilities-authority-layers.sh
rtk bash scripts/tests/test-gateway-config-registries.sh
rtk bash scripts/tests/test-runtime-activation.sh
```

## 签核

- [x] 开发完成
- [x] 测试通过
- [ ] Code Review 完成
- [ ] 合并到 main

- [2026-05-21] Verified by Codex — all tests passed
