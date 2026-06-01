# Sprint 4 Plan

**总故事点**: 6 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U4a | 三层通道路由与 Rollout Gate | 3 | U3b | ⬜ |
| 2 | U4b | auto_merge 安全控制与证据检测引擎 | 3 | U4a | ⬜ |

## 详细说明

### Task 1 (U4a): 三层通道路由与 Rollout Gate

- **目标**: 把通道分级从"只有 quick-channel 概念"升级为可执行的三层路由策略（Quick / Light / Standard），补齐 Light 通道定义，并建立渐进校准的 Rollout Gate 与全局 kill switch。
- **技术方案要点**:
  - **数据流**: 意图输入 → 通道分级器（Quick/Light/Standard）→ Rollout Gate（按项目生命周期周数判定）→ 证据初筛 → 路由到对应通道处理器
  - **状态机**: Intake → ClassifyChannel → RolloutCheck → EvidenceScreen → Route
  - **接口契约**: `ChannelRouter.classify(intent, project_age_weeks, profile) -> ChannelType`；`RolloutGate.allow(channel: ChannelType, project_age_weeks: int, calibration_evidence: EvidenceBundle) -> GateResult`；Quick 通道：Week 1-2 仅允许 lint/语法/i18n/硬编码扫描类任务；Week 3 允许扩展至单文件重构；Week 4+ 允许多文件但 ≤ 3 个；Light 通道：允许中等复杂度任务（多文件重构、配置更新），需极简辩论（1 轮）；Standard 通道：全功能，需完整辩论（3 轮）
- **验收标准**:
  - **AC-1**: Quick、Light、Standard 三层通道完整定义且可配置，不能只存在 quick-channel；配置项位于 `config/performance/slo-policy.json` → `channels`
  - **AC-2**: Rollout Gate 控制：Week 定义以项目首次接入日期（`project-profile.yaml` 中 `first_intake_date`）为基准，按自然周计算；Week 1-2 / Week 3 / Week 4+ 的渐进校准节奏必须可验证
  - **AC-3**: 校准证据不足时强制走 Standard 通道：若 `calibration_evidence.confidence < 0.7` 或 `calibration_evidence.coverage < 0.5`，Rollout Gate 返回 `forced_standard: true`
  - **AC-4**: Quick channel 全局 kill switch：在 `config/performance/slo-policy.json` 中设置 `channels.quick.enabled: false` 时，所有原本路由到 Quick 的意图必须降级到 Light 或 Standard，且日志记录降级原因
- **负向用例**:
  - 生产环境 Quick 通道误判导致风险：运维人员设置 `channels.quick.enabled: false` 后，系统仍继续路由到 Quick 通道 → 阻塞
  - Week 2 项目请求多文件重构：Rollout Gate 必须拒绝并强制走 Standard，若允许走 Quick 则阻塞
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - 通道分级器与 Rollout Gate 作为独立 helper modules
- **文档更新要求**:
  - 更新 `docs/CONFIGURATION.md` 新增三层通道配置与 Rollout Gate 参数
  - 更新 `docs/user-flow-guide_by_kimi.md` 1 阶通道分级流程，明确 Light 通道职责
  - 更新 `docs/sandbox-simulation-report.md` 模拟 Quick→Light→Standard 渐进场景
- **涉及文件**: Create: `scripts/lib/channel_router.py`, Create: `scripts/lib/rollout_gate.py`, Modify: `scripts/lib/orch_gateway.py`, Modify: `config/performance/slo-policy.json`, Modify: `docs/CONFIGURATION.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Modify: `docs/sandbox-simulation-report.md`, Create: `scripts/tests/test-quick-channel-rollout-gate.sh`, Create: `scripts/tests/test-channel-kill-switch.sh`, Modify: `scripts/tests/test-risk-check.sh`, Modify: `scripts/tests/test-gateway-closeout-rejects-unexecuted-tests.sh`, Modify: `scripts/tests/test-gateway-global-evaluation-warnings.sh`, Modify: `scripts/tests/test-docs.sh`

### Task 2 (U4b): auto_merge 安全控制与证据检测引擎

- **目标**: 补齐 `auto_merge=true` 时的安全控制（分支保护、审计、回滚路径），建立敏感词/PII 检测引擎，并验证三种通知级别行为。
- **技术方案要点**:
  - **数据流**: Quick/Light 通道任务完成 → 证据检测引擎（lint/语法/i18n/硬编码/敏感词/PII）→ 安全评分 → `auto_merge` 决策器 → 合并或拦截
  - **状态机**: Complete → EvidenceScan → SecurityScore → MergeDecision → Merge/Block
  - **接口契约**: `EvidenceScanner.scan(diff: str, files: list) -> ScanResult`（包含 `lint_pass`、`syntax_pass`、`i18n_pass`、`hardcode_flags`、`sensitive_keywords`、`pii_detected`）；`SecurityGate.evaluate(scan: ScanResult) -> GateVerdict`；`AutoMerge.merge(target_branch: str, pr_number: int, audit_context: dict) -> MergeReceipt`；目标分支必须为 `main` 以外的受保护分支（如 `staging`），禁止直推 `main`
- **验收标准**:
  - **AC-1**: `auto_merge=true` 时，目标分支不能是 `main`；必须是 `staging` 或配置的白名单分支；且 PR 必须通过分支保护规则（至少 1 review、CI pass）
  - **AC-2**: 敏感词检测引擎覆盖至少 3 类：安全红线关键词（如 `password=`、`secret=`、`api_key`）、PII 模式（正则：邮箱、手机号、身份证号）、合规关键词（如 `TODO: remove before prod`）
  - **AC-3**: PII 检测命中时，`auto_merge` 自动降级为 `false`，记录 `block_reason: pii_detected` 到审计日志，并通知责任人
  - **AC-4**: `silent/compact/verbose` 三种通知级别行为可验证：silent 仅写日志不发通知；compact 发送摘要（≤ 5 行）；verbose 发送完整报告
- **负向用例**:
  - 包含 `password=123456` 的 diff 被 `auto_merge=true` 合并到 `main`：阻塞
  - `silent` 模式下仍发送 Slack 通知：阻塞
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - 证据检测引擎与安全门控作为独立 helper modules
- **文档更新要求**:
  - 更新 `docs/CONFIGURATION.md` 新增 `auto_merge` 分支保护规则与敏感词列表配置
  - 更新 `docs/user-flow-guide_by_kimi.md` 新增 Quick/Light 通道 auto_merge 安全流程
- **涉及文件**: Create: `scripts/lib/evidence_scanner.py`, Create: `scripts/lib/security_gate.py`, Create: `scripts/lib/auto_merge_controller.py`, Modify: `scripts/lib/orch_gateway.py`, Modify: `config/performance/slo-policy.json`, Modify: `docs/CONFIGURATION.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Create: `scripts/tests/test-auto-merge-security.sh`, Create: `scripts/tests/test-sensitive-keyword-pii.sh`, Create: `scripts/tests/test-notification-levels.sh`, Modify: `scripts/tests/test-risk-check.sh`, Modify: `scripts/tests/test-gateway-closeout-rejects-unexecuted-tests.sh`, Modify: `scripts/tests/test-gateway-global-evaluation-warnings.sh`, Modify: `scripts/tests/test-docs.sh`
