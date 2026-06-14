# Sprint 14 Supplement 验收清单

## 验收条件

- [x] `config/knowledge/runtime-kb.json` 默认不再接入 gbrain，runtime knowledge 进入 deferred 状态。
- [x] `scripts/bin/orch-full-contract-validate` 通过 deferred 口径验证 runtime knowledge，而不是 gbrain 口径。
- [x] runtime knowledge 相关测试不再依赖本机 gbrain CLI。
- [x] `docs/FULL-COVERAGE-MATRIX.md` 与 `IMPLEMENTATION-GAP-ANALYSIS.md` 同步更新为 deferred / not runtime 口径。
- [x] `docs/full-system-cutover-debate-worker-runtime-knowledge-report.md` 同步更新。

## 验证命令

```bash
rtk bash scripts/tests/test-runtime-activation.sh
rtk bash scripts/tests/test-gateway-config-registries.sh
rtk bash scripts/tests/test-runtime-knowledge.sh
rtk bash scripts/tests/test-full-contract-validation.sh
rtk bash scripts/tests/test-gateway-integration-points.sh
```

[2026-05-25] Verified by Codex — all tests passed
