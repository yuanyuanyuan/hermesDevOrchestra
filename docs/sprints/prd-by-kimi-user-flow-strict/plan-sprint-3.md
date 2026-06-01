# Sprint 3 Plan

**总故事点**: 6 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U3a | 摘要/详细模式与 project-profile 配置统一 | 3 | U2b | ⬜ |
| 2 | U3b | 两轮纠错门控与 CLI 适配 | 3 | U3a | ⬜ |

## 详细说明

### Task 1 (U3a): 摘要/详细模式与 project-profile 配置统一

- **目标**: 让 0 阶用户交互从"全量信息轰炸"变成可配置的确认体验，解决 `project-profile.yaml` 与现有 `project.json` 的配置冲突，并统一读取入口。
- **技术方案要点**:
  - **数据流**: `orch-mvp-wizard` → 配置加载器（优先 `project-profile.yaml`，回退 `project.json`）→ 模式选择器（`default_mode: summary|detailed`）→ 输出对应级别的确认节点清单
  - **状态机**: LoadConfig → ResolveConflict(yaml优先) → SelectMode → GenerateConfirmationNodes → Present
  - **接口契约**: `ProjectConfigLoader.load(project_dir) -> UnifiedProfile`；`UnifiedProfile` 必须包含 `interaction.default_mode`（enum: summary/detailed）、`interaction.confirmation_threshold`（float 0.0-1.0）
- **验收标准**:
  - **AC-1**: 0 阶同时支持摘要模式与详细模式，默认模式可由 `project-profile.yaml` 中 `interaction.default_mode` 配置；若 yaml 缺失则回退到 `project.json` 的 `mode` 字段；两者皆无时默认 `detailed`
  - **AC-2**: 摘要模式输出 ≤ 10 行核心信息（技术栈、目标、风险等级）；详细模式输出完整补全包全部 6 类信息
  - **AC-3**: 配置加载器必须记录实际使用的配置文件路径与版本标记到 `logs/config-resolution.jsonl`，供调试追溯
  - **AC-4**: `project-profile.yaml` 中新增字段与现有 `project.json` 字段命名冲突时（如 `name`），以 yaml 值为准，但必须在 `logs/config-resolution.jsonl` 中记录冲突与解决策略
- **负向用例**:
  - 同时存在 `project-profile.yaml` 与 `project.json` 且 `default_mode` 值冲突：系统禁止随机选择，必须以 yaml 为准并记录；若静默回退到 json 则阻塞
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - 配置加载器作为独立 helper module，可被 U1b 的 profile sync 复用
- **文档更新要求**:
  - 更新 `docs/CONFIGURATION.md` 新增 `interaction.default_mode` 与配置加载优先级
  - 更新 `docs/user-flow-guide_by_kimi.md` 摘要/详细模式切换说明
- **涉及文件**: Create: `scripts/lib/project_config_loader.py`, Modify: `scripts/bin/orch-mvp-wizard`, Modify: `scripts/lib/orch_gateway.py`, Modify: `docs/CONFIGURATION.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Create: `scripts/tests/test-config-loader-resolution.sh`, Modify: `scripts/tests/test-gateway-decision-approve-intake.sh`, Modify: `scripts/tests/test-risk-decisions.sh`

### Task 2 (U3b): 两轮纠错门控与 CLI 适配

- **目标**: 把短意图解析、确认节点与两轮渐进纠错/Override 机制做成明确门控，解决"两轮纠错在 CLI 层无法落地"的问题。
- **技术方案要点**:
  - **数据流**: 意图解析 → 确认节点清单生成 → 第一轮纠错（提示折叠/展开，CLI 使用分页/交互式选择）→ 第二轮纠错（细分追问，CLI 使用连续问答）→ Override 记录
  - **状态机**: Parse → Confirm(Round1) → Revise(Round2) → Override/Approve → Log
  - **接口契约**: `CorrectionGate.correct(intent: ParsedIntent, round: int, channel: ChannelType) -> CorrectionResult`；`ChannelType` 支持 `cli_interactive`（使用 `inquirer`/`questionary` 风格）、`web`（保留折叠/展开）、`api`（JSON 往返）；CLI 层使用 `--interactive` 标志启用两轮纠错，非交互模式降级为单轮确认
- **验收标准**:
  - **AC-1**: 确认节点清单覆盖以下场景：低置信度（< 0.5）、冲突（任意级别）、L3/L4 目标、protected target、目标偏离（意图与项目画像不匹配）、无法可靠推断
  - **AC-2**: 错误纠正遵循 2 轮渐进展开：第 1 轮给出概要选项（Y/N/Explain）；若用户选 Explain，第 2 轮展开为 3-5 个细分追问；CLI 交互模式下使用连续问答实现，非交互模式降级为单轮确认 + 日志标记 `mode: non-interactive`
  - **AC-3**: 第 2 轮后用户仍坚持原意图，则记录 Override：写入 `.hermes/override-log.jsonl`，包含 `timestamp`、`original_intent`、`user_override`、`approval_status`（若涉及 L3/L4 则标记 `pending_approval`）
  - **AC-4**: 两轮纠错在 CLI 层可落地：`orch-mvp-wizard --interactive` 支持完整两轮；`orch-mvp-wizard --batch` 跳过交互，但必须在输出中打印"非交互模式：两轮纠错已降级为单轮确认"警告
- **负向用例**:
  - 用户输入涉及 protected target 且未授权：两轮纠错后仍坚持执行，系统必须拒绝继续（不能仅记录 Override），返回 `status: blocked` 并提示"需要 L3/L4 审批"
  - CLI 非交互模式下系统假装执行了两轮纠错但未记录降级标记：阻塞
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - Override 日志写入必须通过 `atomic_writer.py`（S2b 产物），禁止直接覆盖
- **文档更新要求**:
  - 更新 `docs/sandbox-simulation-report.md` 新增两轮纠错 CLI 行为模拟
  - 更新 `docs/user-flow-guide_by_kimi.md` 明确 CLI 交互与非交互模式的行为差异
  - 更新 `docs/CONFIGURATION.md` 新增 `--interactive` / `--batch` 标志说明
- **涉及文件**: Create: `scripts/lib/correction_gate.py`, Modify: `scripts/bin/orch-mvp-wizard`, Modify: `scripts/lib/orch_gateway.py`, Modify: `scripts/lib/gateway_projection.py`, Modify: `docs/sandbox-simulation-report.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Modify: `docs/CONFIGURATION.md`, Create: `scripts/tests/test-correction-gate-cli.sh`, Modify: `scripts/tests/test-gateway-decision-approve-intake.sh`, Modify: `scripts/tests/test-risk-decisions.sh`, Modify: `scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
