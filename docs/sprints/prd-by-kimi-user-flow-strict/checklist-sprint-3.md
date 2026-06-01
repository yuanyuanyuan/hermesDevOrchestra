# Sprint 3 验收清单

## 验收条件（可独立验证子项）

### AC-1: 配置加载优先级——yaml 优先
- **可执行断言**: 在测试目录同时创建 `.hermes/project-profile.yaml`（`default_mode: summary`）与 `.hermes/project.json`（`mode: detailed`），运行 `python scripts/lib/project_config_loader.py --project-dir .` 输出 `default_mode: summary` 且 `config_source: project-profile.yaml`
- **测试脚本**: `scripts/tests/test-config-loader-resolution.sh`
- **负向用例**: 加载结果回退到 `project.json` 的 `mode: detailed` 或未记录 `config_source`，则阻塞
- **状态**: ✅

### AC-2: 默认模式可配置且生效
- **可执行断言**: `orch-mvp-wizard --project-dir .` 在 `default_mode: summary` 下输出 ≤ 10 行核心信息；在 `default_mode: detailed` 下输出完整 6 类信息
- **测试脚本**: `scripts/tests/test-config-loader-resolution.sh`
- **负向用例**: 模式切换后输出内容无差异，则阻塞
- **状态**: ✅

### AC-3: 配置冲突日志记录
- **可执行断言**: `logs/config-resolution.jsonl` 存在条目包含 `conflict_field: default_mode`、`yaml_value: summary`、`json_value: detailed`、`resolution: yaml_wins`
- **测试脚本**: `scripts/tests/test-config-loader-resolution.sh`
- **负向用例**: 冲突存在但日志中无对应记录，则阻塞
- **状态**: ✅

### AC-4: 确认节点清单覆盖 6 大场景
- **可执行断言**: `python scripts/lib/correction_gate.py --list-nodes` 输出包含 `low_confidence`、`conflict`、`l3_l4_target`、`protected_target`、`goal_divergence`、`unreliable_inference` 6 个节点 ID
- **测试脚本**: `scripts/tests/test-correction-gate-cli.sh`
- **负向用例**: 任一节点 ID 缺失，则阻塞
- **状态**: ✅

### AC-5: CLI 两轮交互模式可落地
- **可执行断言**: `echo -e "N\nExplain\nY" | orch-mvp-wizard --interactive --mock` 完成 2 轮交互：第 1 轮显示概要选项，第 2 轮展开细分追问，最终输出包含 `override: false` 与 `rounds_completed: 2`
- **测试脚本**: `scripts/tests/test-correction-gate-cli.sh`
- **负向用例**: 交互模式仅执行 1 轮或崩溃，则阻塞
- **状态**: ✅

### AC-6: 非交互模式降级与警告
- **可执行断言**: `orch-mvp-wizard --batch` 输出包含 `"warn": "non-interactive: two-round correction degraded to single-round confirmation"`，且结果中包含 `mode: non-interactive`
- **测试脚本**: `scripts/tests/test-correction-gate-cli.sh`
- **负向用例**: `--batch` 模式未打印降级警告或假装执行了两轮纠错，则阻塞
- **状态**: ✅

### AC-7: Override 记录持久化
- **可执行断言**: 两轮纠错后用户坚持原意图，`.hermes/override-log.jsonl` 存在条目包含 `original_intent`、`user_override`、`approval_status`；写入通过 `atomic_writer.py` 完成（检查 `.tmp` 文件存在后 rename）
- **测试脚本**: `scripts/tests/test-correction-gate-cli.sh`
- **负向用例**: Override 记录缺失或使用非原子写导致文件损坏，则阻塞
- **状态**: ✅

## 架构红线合规
- [x] Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
- [x] `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
- [x] Override 日志写入使用 `atomic_writer.py`（S2b 产物）
- [x] 配置加载器作为独立 helper module

## 文档交付物
- [x] `docs/CONFIGURATION.md` 更新：`interaction.default_mode` 与 `--interactive` / `--batch` 标志
- [x] `docs/user-flow-guide_by_kimi.md` 更新：摘要/详细模式 + CLI 交互与非交互差异
- [x] `docs/sandbox-simulation-report.md` 更新：两轮纠错 CLI 行为模拟

## 任务完成状态
- [x] U3a — 摘要/详细模式与 project-profile 配置统一
- [x] U3b — 两轮纠错门控与 CLI 适配

## 签核
- [x] 开发完成
- [x] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [x] 架构红线合规确认
- [ ] 合并到 main

[2026-06-01] Verified by Codex — all tests passed
