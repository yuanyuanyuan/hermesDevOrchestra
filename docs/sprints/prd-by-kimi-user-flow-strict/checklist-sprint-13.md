# Sprint 13 验收清单

## 验收条件（可独立验证子项）

### AC-1: PRD §11.1 14 项成功指标内联实现
- **可执行断言**: `config/performance/slo-policy.json` 中包含 14 项指标，每项含 `metric_id`、`source_events[]`、`aggregation_rule`、`threshold`、`validation_script_ref`；`scripts/tests/test-success-metrics-pipeline.sh` 运行后返回 0，且输出的 `metrics_summary.json` 中 14 项指标均存在 `observed_value` 和 `status`（`pass`/`warn`/`fail`）。
- **测试脚本**: `scripts/tests/test-success-metrics-pipeline.sh`
- **负向用例**: `slo-policy.json` 中缺少任一指标（如 `quick_channel.merged`），或 `test-success-metrics-pipeline.sh` 运行时缺少对应事件字段 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-2: `schema.md` 与 `config/schemas/orchestra.full.schema.json` 自动化校验一致
- **可执行断言**: `scripts/tests/test-schema-doc-sync.sh` 运行后返回 0；当故意在 `schema.md` 中新增字段但未同步到 `schema.json` 时，脚本返回非 0 并输出差异报告（含缺失字段名）；当在 `orch_gateway.py` 中使用 `schema.json` 中不存在的硬编码字段时，脚本返回非 0 并输出"实现漂移"列表。
- **测试脚本**: `scripts/tests/test-schema-doc-sync.sh`
- **负向用例**: `schema.md` 与 `schema.json` 存在字段名不一致（如 `schema.md` 写 `run_projection`，`schema.json` 写 `runProjections`），但 `test-schema-doc-sync.sh` 仍返回 0 → 必须以非 0 退出码失败。
- **状态**: ⬜

### AC-3: 0→6 阶严格闭环回归在 staging/harness 下可跑通
- **可执行断言**: 
  1. 执行 `scripts/lib/staging Harness.sh` 成功创建隔离环境（退出码 0）。
  2. 执行 `scripts/lib/staging inject-data.sh` 成功注入 mock 数据。
  3. 执行 `scripts/tests/test-e2e-strict-six-stage-flow.sh` 返回 0。
  4. 回归结束后，`.hermes/staging/` 下存在 `run.json`、`tasks.json`、`events.jsonl`、`audit.jsonl`、`metrics_summary.json`，且均通过 schema 校验。
- **测试脚本**: `scripts/tests/test-e2e-strict-six-stage-flow.sh`
- **负向用例**: staging 环境缺少数据注入脚本，导致 intake 阶段因无项目数据而跳过 → 环境就绪检查必须以非 0 退出码失败，回归不得标记为通过。
- **状态**: ⬜

### AC-4: Schema 三重一致性校验绑定 CI gate
- **可执行断言**: 在 CI 流水线中运行 `test-schema-doc-sync.sh`；当 `schema.md`/`schema.json`/Gateway 实现三者不一致时，CI gate 返回失败状态，阻止 PR 合并。
- **测试脚本**: `scripts/tests/test-schema-doc-sync.sh`（CI 集成验证）
- **负向用例**: `orch_gateway.py` 实现中使用已移除的字段 `legacy_run_status`，但 CI gate 未拦截 → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-5: 上线 Gate 绑定 strict six-stage 回归结果
- **可执行断言**: 仅当 `test-e2e-strict-six-stage-flow.sh`、`test-schema-doc-sync.sh`、`test-success-metrics-pipeline.sh` 全部返回 0 时，`release_gate_report.release_approved` 才为 `true`；任一失败时，`release_approved` 为 `false` 且 `block_reasons[]` 非空。
- **测试脚本**: `scripts/tests/test-mvp-acceptance.sh`（扩展 gate 验证）
- **负向用例**: `test-success-metrics-pipeline.sh` 失败但 `release_approved` 仍为 `true` → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

### AC-6: Staging 环境定义完整且幂等
- **可执行断言**: 
  1. `scripts/lib/staging Harness.sh`、`scripts/lib/staging inject-data.sh`、`scripts/lib/staging teardown.sh` 均存在且可执行。
  2. 连续运行两次 `Harness.sh` + `teardown.sh` + `Harness.sh`，环境状态一致（通过文件哈希或目录列表比对）。
  3. `inject-data.sh` 生成的 `project-profile.yaml` 包含 `protected_targets`、`quick_channel`、`evaluation` 配置，且至少注入 1 个含 protected target 的 mock 任务和 1 个含冲突标记的 mock intake。
- **测试脚本**: `scripts/tests/test-e2e-strict-six-stage-flow.sh`（内置环境验证）
- **负向用例**: 两次运行 `Harness.sh` 后环境状态不一致（如残留旧数据） → 测试脚本必须以非 0 退出码失败。
- **状态**: ⬜

## 架构红线合规
- [ ] 所有新增脚本使用 `set -euo pipefail`，错误即停
- [ ] Staging 环境定义文件受版本控制，搭建脚本幂等
- [ ] Schema 三重一致性校验零人工介入，纯自动化运行
- [ ] 文件态持久化采用原子写模式

## 文档交付物
- [ ] `docs/user-flow-guide_by_kimi.md` 已更新成功指标采集管道使用说明、staging 环境搭建指南、schema 同步校验流程
- [ ] `docs/FULL-COVERAGE-MATRIX.md` 已补充 S13 上线 Gate 覆盖的测试项与指标映射
- [ ] `docs/sandbox-simulation-report.md` 已补充 staging 回归在沙箱中的验证方法与数据注入示例

## 任务完成状态
- [ ] U13 — 成功指标采集、Schema 一致性与 0→6 阶严格回归

## 验证命令

```bash
rtk bash scripts/tests/test-success-metrics-pipeline.sh
rtk bash scripts/tests/test-schema-doc-sync.sh
rtk bash scripts/tests/test-e2e-strict-six-stage-flow.sh
rtk bash scripts/tests/test-performance-slo.sh
rtk bash scripts/tests/test-mvp-acceptance.sh
rtk bash scripts/tests/test-mvp-wizard-demo-run.sh
rtk bash scripts/tests/test-mvp-wizard-real-worker-demo.sh
rtk bash scripts/tests/test-gateway-mvp-acceptance-artifacts.sh
rtk bash scripts/tests/test-gateway-events-rebuild.sh
```

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
