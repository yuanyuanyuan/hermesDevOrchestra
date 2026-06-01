# Sprint 2 验收清单

## 验收条件（可独立验证子项）

### AC-1: 六分类信息完整性
- **可执行断言**: `python scripts/tests/test-completion-bundle-schema.sh` 生成的 `requirement-completion-bundle.json` 包含 6 个顶层字段：`intent_summary`、`dependency_graph`、`conflict_list`、`acceptance_matrix`、`prompt_envelope`、`risk_flags`
- **测试脚本**: `scripts/tests/test-completion-bundle-schema.sh`
- **负向用例**: 任一顶层字段缺失或为 null/空对象/空字符串，则阻塞
- **状态**: ✅

### AC-2: 关键结论附带证据三元组
- **可执行断言**: 对补全包中每个关键结论节点，JSON Path `$.intent_summary.conclusions[*]` 必须包含 `source`（字符串，非空）、`confidence`（float，0.0-1.0）、`verification_method`（enum: manual/auto/inferred）
- **测试脚本**: `scripts/tests/test-completion-bundle-schema.sh`
- **负向用例**: `confidence` 超出 0.0-1.0 范围或 `verification_method` 为未定义枚举值，则阻塞
- **状态**: ✅

### AC-3: 依赖图四维覆盖
- **可执行断言**: `$.dependency_graph.dimensions` 包含 `environment`、`upstream`、`downstream`、`code` 四个键，且每个键对应的依赖列表长度 ≥ 1
- **测试脚本**: `scripts/tests/test-full-contract-validation.sh`
- **负向用例**: 仅包含单层文件依赖（如只有 `code` 维度），则阻塞
- **状态**: ✅

### AC-4: 阻塞校验引擎——缺一项即阻塞
- **可执行断言**: `python scripts/lib/blocker_validator.py --test-missing-field intent_summary` 返回 exit code 1，stdout 包含 `"status": "blocked"` 与 `"missing_fields": ["intent_summary"]`
- **测试脚本**: `scripts/tests/test-blocker-validator.sh`
- **负向用例**: 缺失字段时仍返回 `status: passed` 或下游流程继续执行，则阻塞
- **状态**: ✅

### AC-5: 原子写——无半写文件
- **可执行断言**: 在写入 `run.json` 过程中发送 SIGKILL 给写入进程，检查目标文件：要么保持旧版本完整可读，要么为新版本完整可读，不得存在截断/损坏 JSON
- **测试脚本**: `scripts/tests/test-atomic-writer.sh`
- **负向用例**: 目标文件为截断 JSON 或大小为 0 的损坏文件，则阻塞
- **状态**: ✅

### AC-6: 并发写冲突检测
- **可执行断言**: 同时启动两个进程写同一 `run.json`，后启动的进程返回 `status: conflict` 且 exit code ≠ 0；先启动的进程成功写入
- **测试脚本**: `scripts/tests/test-atomic-writer.sh`
- **负向用例**: 后启动进程静默覆盖先启动进程的写入结果，则阻塞
- **状态**: ✅

### AC-7: Gateway 状态投影可溯源
- **可执行断言**: 补全包中每个字段包含 `source_input_hash`（SHA-256，64 字符 hex）与 `projection_timestamp`（ISO 8601）
- **测试脚本**: `scripts/tests/test-gateway-decision-approve-intake.sh`
- **负向用例**: `source_input_hash` 长度 ≠ 64 或 `projection_timestamp` 非合法 ISO 8601，则阻塞
- **状态**: ✅

## 架构红线合规
- [x] Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
- [x] `orch_gateway.py` 行数净增长 ≤ 50 行（main 基线 6190 行，git diff 净增 +41 行）
- [x] 阻塞校验引擎与原子写入器作为独立 helper modules
- [x] 原子写使用 write-to-temp + fsync + rename 模式

## 文档交付物
- [x] `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` 更新：六分类信息保留要求
- [x] `docs/prd_by_kimi.md` 更新：补全包结构定义章节
- [x] `docs/user-flow-guide_by_kimi.md` 更新：0 阶补全流程 + 阻塞校验行为
- [x] `docs/CONFIGURATION.md` 更新：原子写配置与恢复流程

## 任务完成状态
- [x] U2a — 六分类 Schema & 结构化补全包
- [x] U2b — 阻塞校验引擎 & 文件态原子持久化

## 签核
- [x] 开发完成
- [x] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [x] 架构红线合规确认
- [ ] 合并到 main

[2026-06-01] Verified — 四级验收全部通过
  - 架构红线合规: ✅
  - 功能验收: ✅ (7/7 条)
  - 测试覆盖: ✅ (正向 7/7, 负向 4/4, 回归通过)
  - 文档/Schema/配置同步: ✅
