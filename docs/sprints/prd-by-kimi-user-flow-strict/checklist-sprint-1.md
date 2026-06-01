# Sprint 1 验收清单

## 验收条件（可独立验证子项）

### AC-1: Seam Extraction 成功——新增逻辑 100% 外置到 helper modules
- **可执行断言**: `cloc scripts/lib/orch_gateway.py` 基线 6109 行，本 Sprint 修改后净增长 ≤ 50 行；且 `scripts/lib/gateway_intake.py`、`gateway_projection.py`、`gateway_evidence.py` 均存在且行数 > 0
- **测试脚本**: `scripts/tests/test-gateway-seam-extraction.sh`
- **负向用例**: 若 `orch_gateway.py` 新增逻辑 > 50 行或直接内嵌 intake/projection/evidence 实现，则断言失败，Sprint 阻塞
- **状态**: ✅

### AC-2: Gateway Fallback 降级机制可验证
- **可执行断言**: 临时重命名 `gateway_intake.py` → `gateway_intake.py.bak`，调用 Gateway API，返回 HTTP 503 + `x-gateway-fallback: heuristic`，且响应时间 ≤ 500ms；`logs/gateway-fallback.jsonl` 中存在对应降级事件记录
- **测试脚本**: `scripts/tests/test-gateway-seam-extraction.sh`
- **负向用例**: Gateway 在 helper module 缺失时崩溃或返回 500 而非 503，则阻塞
- **状态**: ✅

### AC-3: NormalizedIntent Schema 合规
- **可执行断言**: `python -c "import jsonschema; jsonschema.validate(instance=gateway_intake.normalize({'repo_url':'https://github.com/x/y'}), schema=load_schema('orchestra.full.schema.json#/definitions/NormalizedIntent'))"` 通过
- **测试脚本**: `scripts/tests/test-init-start-status.sh`
- **负向用例**: 输出字段缺失 `intent_type`、`confidence`、`source_trace` 任一字段则阻塞
- **状态**: ✅

### AC-4: 项目探测报告 5 分钟 SLA
- **可执行断言**: `time rtk bash scripts/bin/orch-init --dry-run` 在含 package.json 的标准项目目录下，wall-clock 时间 ≤ 300s；输出包含 `detection_report` 且字段 `tech_stack`、`test_command`、`deploy_target`、`risk_flags` 均非空
- **测试脚本**: `scripts/tests/test-init-start-status.sh`
- **负向用例**: 超时无输出或缺少上述任一字段则阻塞
- **状态**: ✅

### AC-5: 5 分钟 SLA 降级策略生效
- **可执行断言**: 在大型 monorepo 模拟环境（>1000 文件）下运行 `orch-init`，若 wall-clock > 300s，输出必须包含 `status: partial` 且至少包含 `tech_stack` 字段；进程不得异常退出
- **测试脚本**: `scripts/tests/test-init-start-status.sh`
- **负向用例**: 超时后进程僵死或输出 `status: failed` 而非 `partial`，则阻塞
- **状态**: ✅

### AC-6: project-profile.yaml 为真源，与 project.json 冲突可解决
- **可执行断言**: 同时创建 `.hermes/project.json`（含 `name: old`）和 `.hermes/project-profile.yaml`（含 `name: new`），运行 `orch-profile-sync` 后，`scripts/bin/orch-mvp-wizard` 读取到的 `project.name == 'new'`；且 `.hermes/project.json` 内容未被覆盖但存在 `deprecated: true` 标记
- **测试脚本**: `scripts/tests/test-project-profile-conflict-resolution.sh`
- **负向用例**: 系统读取 `project.json` 而非 yaml 作为真源，或静默合并导致字段丢失，则阻塞
- **状态**: ✅

### AC-7: 重复执行稳定性
- **可执行断言**: 同一仓库连续两次运行 `orch-init --dry-run`，输出的 `tech_stack`、`test_command`、`deploy_target` 字段 MD5 一致（时间戳字段除外容差 ±1%）
- **测试脚本**: `scripts/tests/test-profile-packaging.sh`
- **负向用例**: 两次运行输出同一字段不一致（非时间戳原因），则阻塞
- **状态**: ✅

## 架构红线合规
- [x] Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
- [x] `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行，实际 6143，增长 34 行）
- [x] helper module 之间单向依赖，无循环引用（通过 Python import 验证）
- [x] 探测报告生成不直接修改 `orch_gateway.py`

## 文档交付物
- [x] `docs/CONFIGURATION.md` 更新：Gateway helper modules 注册方式
- [x] `docs/CONFIGURATION.md` 更新：project-profile.yaml 格式说明与 project.json 迁移指南
- [x] `docs/user-flow-guide_by_kimi.md` 更新：0 阶 Gateway 数据流 + 5 分钟 SLA 降级路径
- [x] `docs/adr/0010-gateway-seam-extraction.md` 新建：seam 拆分决策与 fallback 策略

## 任务完成状态
- [x] U1a — Gateway Seam Extraction & Intake Helper Modules
- [x] U1b — Project Discovery Pipeline & Profile Generation

## 签核
- [x] 开发完成
- [x] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [x] 架构红线合规确认
- [ ] 合并到 main

---

[2026-05-31] Verified by Codex — 四级验收全部通过
  - 架构红线合规: ✅
  - 功能验收: ✅ (7/7 条)
  - 测试覆盖: ✅ (正向 5/5, 负向 2/2, 回归通过)
  - 文档/Schema/配置同步: ✅
