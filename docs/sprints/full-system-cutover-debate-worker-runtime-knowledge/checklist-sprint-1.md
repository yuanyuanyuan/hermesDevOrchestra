# Sprint 1 验收清单

## 验收条件

- [x] **U1**: Default runtime activation reports `full_debate_package`, `worker_execution`, and `runtime_domain_knowledge` as active families.; Gateway module defaulting no longer requires explicit `allow_staged=True` for the three target families.
- [ ] **U2**: Debate runtime tests pass with default runtime behavior and without explicit `allow_staged=True` for normal success cases.; Debate report and audit artifacts preserve member/opinion/backend/degradation evidence on the default path.
- [ ] 全部测试通过（exit 0）
- [ ] 代码符合项目规范

## 任务完成状态

- [x] U1 — Extend runtime-family activation to the three target families
- [ ] U2 — Cut over the Debate Engine default runtime path

## 验证命令

```bash
rtk bash scripts/tests/test-runtime-activation.sh
rtk bash scripts/tests/test-gateway-integration-points.sh
rtk bash scripts/tests/test-debate-assembly.sh
rtk bash scripts/tests/test-debate-member-invocation.sh
rtk bash scripts/tests/test-debate-engine-ai.sh
rtk bash scripts/tests/test-e2e-ai-debate-flow.sh
```

## 签核

- [ ] 开发完成
- [ ] 测试通过
- [ ] Code Review 完成
- [ ] 合并到 main
