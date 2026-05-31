# Sprint 5 Plan

**总故事点**: 6 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U5a | 辩论工单契约与团队策略引擎 | 3 | U4b | ⬜ |
| 2 | U5b | 安全红线、别名映射与 Schema 扩展 | 3 | U5a | ⬜ |

## 详细说明

### Task 1 (U5a): 辩论工单契约与团队策略引擎

- **目标**: 为方向辩论建立严格的工单契约和团队装配策略，让一阶能真正做"是否值得做"的前置拦截，而不是泛化成一份模糊报告。
- **技术方案要点**:
  - **数据流**: 意图输入 → 工单生成器 → 团队选择器（canonical 16 + 扩展团队 + 旧别名映射）→ 辩论装配器 → 执行辩论 → 输出方向结论
  - **状态机**: Intake → TicketGenerate → TeamSelect → Assemble → Debate → DirectionVerdict
  - **接口契约**: `DebateTicket` 必须包含：`project_background`、`goal`、`non_goal`、`constraints`、`acceptance_criteria`、`risk_boundary`、`failure_strategy`；`TeamSelector.select(task_type, project_profile) -> TeamList`；`TeamList` 中 `maxItems` 限制为动态计算：canonical 团队无上限，但单张工单总团队数 ≤ `project_profile.max_teams`（默认 16，可配置扩展）
- **验收标准**:
  - **AC-1**: 一阶工单至少包含 7 个字段：`project_background`、`goal`、`non_goal`、`constraints`、`acceptance_criteria`、`risk_boundary`、`failure_strategy`；缺任一项则阻塞校验失败
  - **AC-2**: 团队选择策略支持 16 支 canonical 团队、扩展团队、旧别名兼容，并按 `task_type + project-profile` 配置运行；团队选择结果写入 `logs/team-selection.jsonl`
  - **AC-3**: 旧别名兼容以显式映射表实现：`config/debate/full/alias-mapping.json` 必须存在，且映射关系可被 `TeamSelector` 读取；自定义团队的 `prompt_injection` 字段存在时，必须经过安全红线扫描（见 Task U5b）
  - **AC-4**: 系统显式区分硬约束与用户偏好：`DebateTicket.constraints` 中 `hard` 类约束不可被辩论结论覆盖，`soft` 类约束可被覆盖但需记录 `override_reason`
  - **AC-5**: 方向结论高置信度（≥ 0.8）、低风险（无 blocking 风险）、无冲突时自动进入二阶；任一条件不满足则停留一阶并生成人工审核工单
- **负向用例**:
  - 工单缺失 `failure_strategy`：系统仍继续辩论并输出结论 → 阻塞
  - 自定义团队注入包含 `rm -rf /` 的 prompt：未经安全红线扫描即进入辩论 → 阻塞
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - 辩论装配器与团队选择器作为独立 helper modules
- **文档更新要求**:
  - 更新 `docs/adr/0001-full-debate-package-team-registry.md` 记录团队选择策略与别名映射设计
  - 更新 `docs/adr/0009-dynamic-debate-assembly-policy.md` 记录动态装配策略与硬/软约束区分
  - 更新 `docs/user-flow-guide_by_kimi.md` 1 阶方向辩论流程
- **涉及文件**: Modify: `scripts/lib/debate_assembly.py`, Modify: `scripts/lib/debate_report.py`, Create: `scripts/lib/team_selector.py`, Create: `scripts/lib/debate_ticket_generator.py`, Modify: `config/debate/full/teams.json`, Create: `config/debate/full/alias-mapping.json`, Modify: `config/debate/full/assembly-policy.json`, Modify: `docs/adr/0001-full-debate-package-team-registry.md`, Modify: `docs/adr/0009-dynamic-debate-assembly-policy.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Create: `scripts/tests/test-debate-ticket-schema.sh`, Create: `scripts/tests/test-team-selector.sh`, Modify: `scripts/tests/test-debate-assembly.sh`, Modify: `scripts/tests/test-gateway-config-registries.sh`

### Task 2 (U5b): 安全红线、别名映射与 Schema 扩展

- **目标**: 定义核心安全红线清单+检测算法，确保 `alias-mapping.json` 可落地，并解决 schema `maxItems=16` 与扩展团队冲突。
- **技术方案要点**:
  - **数据流**: 团队配置加载 → 别名解析 → 安全红线扫描（关键词 denylist + 语义匹配）→ 扩展团队校验 → 工单装配
  - **状态机**: Load → AliasResolve → SecurityScan → Validate → Assemble
  - **接口契约**: `SecurityScanner.scan(prompt_injection: str) -> SecurityReport`；检测算法：① 关键词 denylist（精确匹配 `rm -rf`、`DROP TABLE`、`eval(` 等 20+ 条）；② 语义匹配（使用简单正则+熵检测识别潜在的命令注入模式）；`alias-mapping.json` schema：`{ "alias": string, "canonical_team": string, "deprecated_since": ISO8601|null, "migration_note": string|null }`
- **验收标准**:
  - **AC-1**: 核心安全红线清单至少包含 3 大类：文件系统破坏（`rm -rf`、`mkfs.`）、数据破坏（`DROP TABLE`、`DELETE FROM`）、代码执行（`eval(`、`exec(`、`subprocess.call`）；检测算法为关键词 denylist + 语义正则匹配，命中任一即返回 `status: blocked`
  - **AC-2**: `config/debate/full/alias-mapping.json` 存在且通过 JSON Schema 校验；至少包含 3 条旧别名到 canonical 团队的映射；自定义团队 `prompt_injection` 字段值必须通过 `SecurityScanner.scan()`，未通过则团队被标记 `security_blocked: true` 且不可参与辩论
  - **AC-3**: Schema `maxItems` 冲突解决：`orchestra.full.schema.json` 中 `team_list.maxItems` 改为可配置上限（从 `project-profile.yaml` 读取 `max_teams`，默认 16，最小 1，最大 64）；若配置 > 64 则拒绝加载并返回 `config_error`
  - **AC-4**: 安全红线扫描结果记录到 `logs/security-scan.jsonl`，包含 `team_id`、`prompt_hash`、`scan_result`、`blocked_keywords`、`timestamp`
- **负向用例**:
  - `alias-mapping.json` 不存在：`TeamSelector` 加载失败并返回 `config_error`，而非静默忽略别名 → 阻塞
  - `project-profile.yaml` 设置 `max_teams: 100`：系统必须拒绝并返回 `config_error: max_teams exceeds hard limit 64`，不能静默截断为 16 → 阻塞
  - 安全红线扫描漏报 `eval(request.body)`：系统允许该团队参与辩论 → 阻塞
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
  - 安全扫描器作为独立 helper module，可被 S4b 的 `evidence_scanner.py` 复用
- **文档更新要求**:
  - 更新 `docs/adr/0001-full-debate-package-team-registry.md` 记录安全红线清单与别名映射 schema
  - 更新 `docs/adr/0009-dynamic-debate-assembly-policy.md` 记录 maxItems 动态配置决策
  - 更新 `docs/CONFIGURATION.md` 新增 `max_teams` 配置说明与安全红线关键词列表
- **涉及文件**: Create: `scripts/lib/security_scanner.py`, Modify: `scripts/lib/team_selector.py`, Create: `config/debate/full/alias-mapping.json`, Modify: `config/schemas/orchestra.full.schema.json`, Modify: `config/debate/full/assembly-policy.json`, Modify: `docs/adr/0001-full-debate-package-team-registry.md`, Modify: `docs/adr/0009-dynamic-debate-assembly-policy.md`, Modify: `docs/CONFIGURATION.md`, Create: `scripts/tests/test-debate-alias-mapping.sh`, Create: `scripts/tests/test-debate-custom-team-guards.sh`, Create: `scripts/tests/test-security-scanner.sh`, Modify: `scripts/tests/test-debate-assembly.sh`, Modify: `scripts/tests/test-gateway-config-registries.sh`
