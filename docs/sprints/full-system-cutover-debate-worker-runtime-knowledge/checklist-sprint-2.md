# Sprint 2 验收清单

## 验收条件

- [x] **U3**: Default runtime worker selection no longer depends on legacy worker registries or caller-side staged overrides.; Capability negotiation still records checked backends, fallback reasoning, and blocked decisions on the default path.
- [x] **U5**: Runtime knowledge and ingestion tests pass on the default runtime path without staged override.; Freshness, provenance, redaction, and human-approval boundaries remain enforced after activation.
- [x] 全部测试通过（exit 0）
- [x] 代码符合项目规范

## 任务完成状态

- [x] U3 — Cut over worker registry and capability negotiation to the default runtime
- [x] U5 — Activate gbrain-backed runtime knowledge on the default runtime path

## 验证命令

```bash
rtk bash scripts/tests/test-worker-registry.sh
rtk bash scripts/tests/test-gateway-worker-registry.sh
rtk bash scripts/tests/test-runtime-knowledge.sh
rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh
rtk bash scripts/tests/test-gateway-mvp-real-acceptance-boundary.sh
rtk bash scripts/tests/test-gateway-integration-points.sh
```

## 签核

- [x] 开发完成
- [x] 测试通过
- [ ] Code Review 完成
- [ ] 合并到 main

- [2026-05-21] Verified by Codex — all tests passed
