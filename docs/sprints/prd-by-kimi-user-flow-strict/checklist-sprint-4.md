# Sprint 4 验收清单

## 验收条件（可独立验证子项）

### AC-1: 三层通道完整定义
- **可执行断言**: `cat config/performance/slo-policy.json | jq '.channels'` 输出包含 `quick`、`light`、`standard` 三个键，且每个键包含 `enabled`（bool）、`max_files`（int）、`required_evidence`（array）
- **测试脚本**: `scripts/tests/test-quick-channel-rollout-gate.sh`
- **负向用例**: 仅存在 `quick` 通道或 `light` 通道缺失 `required_evidence`，则阻塞
- **状态**: ⬜

### AC-2: Rollout Gate 按周数强制路由
- **可执行断言**: 模拟 `project_age_weeks=1` + `intent.files_count=5`（超过 Quick 限制），`channel_router.classify()` 返回 `channel: standard` 且 `reason: "week_1_2_quick_file_limit_exceeded"`
- **测试脚本**: `scripts/tests/test-quick-channel-rollout-gate.sh`
- **负向用例**: Week 1 项目被路由到 Quick 通道且文件数 > 1，则阻塞
- **状态**: ⬜

### AC-3: 校准证据不足时强制 Standard
- **可执行断言**: `calibration_evidence.confidence=0.5` + `calibration_evidence.coverage=0.3` 时，`rollout_gate.allow()` 返回 `forced_standard: true` 与 `reason: "insufficient_calibration_evidence"`
- **测试脚本**: `scripts/tests/test-quick-channel-rollout-gate.sh`
- **负向用例**: 证据不足仍允许走 Quick 通道，则阻塞
- **状态**: ⬜

### AC-4: Quick Channel 全局 Kill Switch
- **可执行断言**: 设置 `config/performance/slo-policy.json` 中 `channels.quick.enabled=false` 后，原本路由到 Quick 的意图返回 `channel: light` 或 `channel: standard`，且 `logs/channel-routing.jsonl` 包含 `downgrade_reason: "kill_switch_enabled"`
- **测试脚本**: `scripts/tests/test-channel-kill-switch.sh`
- **负向用例**: Kill Switch 启用后系统仍路由到 Quick 通道，则阻塞
- **状态**: ⬜

### AC-5: auto_merge 禁止直推 main
- **可执行断言**: `auto_merge_controller.merge(target_branch="main", ...)` 抛出 `MergeRejectedError` 且消息包含 `"target branch main is protected"`
- **测试脚本**: `scripts/tests/test-auto-merge-security.sh`
- **负向用例**: `auto_merge=true` 时成功合并到 `main` 且未触发分支保护，则阻塞
- **状态**: ⬜

### AC-6: 敏感词/PII 检测引擎命中
- **可执行断言**: 输入 diff 包含 `password=secret123`，`evidence_scanner.scan()` 返回 `sensitive_keywords: ["password="]` 与 `pii_detected: true`；`security_gate.evaluate()` 返回 `verdict: block` 与 `block_reason: "pii_detected"`
- **测试脚本**: `scripts/tests/test-sensitive-keyword-pii.sh`
- **负向用例**: 包含 `password=` 的 diff 被标记为 `security_pass: true`，则阻塞
- **状态**: ⬜

### AC-7: PII 命中时 auto_merge 降级
- **可执行断言**: `auto_merge=true` 配置下，PII 检测命中后，合并请求被拒绝，审计日志包含 `action: auto_merge_blocked`、`reason: pii_detected`、`original_target_branch`
- **测试脚本**: `scripts/tests/test-auto-merge-security.sh`
- **负向用例**: PII 命中后仍执行合并，则阻塞
- **状态**: ⬜

### AC-8: 三种通知级别行为可验证
- **可执行断言**: `notification.send(level="silent")` 后 Slack webhook 调用次数 = 0；`level="compact"` 后消息字符数 ≤ 200；`level="verbose"` 后消息包含完整 `ScanResult` JSON
- **测试脚本**: `scripts/tests/test-notification-levels.sh`
- **负向用例**: `silent` 模式下仍发送通知，或 `compact` 消息 > 200 字符，则阻塞
- **状态**: ⬜

## 架构红线合规
- [ ] Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
- [ ] `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
- [ ] 通道分级器、Rollout Gate、证据检测引擎、安全门控均为独立 helper modules
- [ ] auto_merge 目标分支必须通过配置白名单校验，禁止硬编码

## 文档交付物
- [ ] `docs/CONFIGURATION.md` 更新：三层通道配置、Rollout Gate 参数、auto_merge 分支保护
- [ ] `docs/user-flow-guide_by_kimi.md` 更新：1 阶通道分级 + Light 通道职责 + auto_merge 安全流程
- [ ] `docs/sandbox-simulation-report.md` 更新：Quick→Light→Standard 渐进场景模拟

## 任务完成状态
- [ ] U4a — 三层通道路由与 Rollout Gate
- [ ] U4b — auto_merge 安全控制与证据检测引擎

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
