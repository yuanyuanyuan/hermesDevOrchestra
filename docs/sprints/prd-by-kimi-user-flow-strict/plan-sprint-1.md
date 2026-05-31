# Sprint 1 Plan

**总故事点**: 6 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U1a | Gateway Seam Extraction & Intake Helper Modules | 3 | - | ⬜ |
| 2 | U1b | Project Discovery Pipeline & Profile Generation | 3 | U1a | ⬜ |

## 详细说明

### Task 1 (U1a): Gateway Seam Extraction & Intake Helper Modules

- **目标**: 将 `orch_gateway.py` 中 6109 行的 intake / projection / evidence 逻辑按 seam extraction 原则外置到独立 helper modules，确保 Gateway 保持路由与编排边界，并建立可验证的成功标准与 fallback 策略。
- **技术方案要点**:
  - **数据流**: 外部请求 → `orch_gateway.py` (路由层) → `gateway_intake.py` (输入校验+标准化) → `gateway_projection.py` (状态投影+映射追踪) → `gateway_evidence.py` (证据收集+置信度标记) → 返回结构化输出
  - **状态机**: Intake → Validate → Project → Evidence → Route；任一阶段失败进入 `FALLBACK_HEURISTIC` 模式（直接透传原始输入到标准通道）
  - **接口契约**: `gateway_intake.normalize(request: dict) -> NormalizedIntent`；`gateway_projection.project(intent: NormalizedIntent, context: GatewayContext) -> ProjectedState`；`gateway_evidence.gather(projected: ProjectedState) -> EvidenceBundle`
- **验收标准**:
  - **AC-1**: `orch_gateway.py` 新增逻辑行数 ≤ 50 行（仅保留路由编排代码），新增 intake/projection/evidence 逻辑 100% 落在 `scripts/lib/gateway_*.py` helper modules
  - **AC-2**: 当任一 helper module 加载失败或抛出异常时，Gateway 在 500ms 内降级到 `FALLBACK_HEURISTIC` 模式，记录降级事件到 `logs/gateway-fallback.jsonl`
  - **AC-3**: `gateway_intake.py` 输出 `NormalizedIntent` schema 与 `spec.md` §3.2 定义完全一致，通过 JSON Schema 校验
  - **AC-4**: 重复执行同一项目接入请求，输出结果稳定（MD5 一致性 ±1% 容差用于时间戳字段）
- **负向用例**:
  - `gateway_intake.py` 文件被删除或权限改为 000 时，Gateway 不应崩溃，必须在 500ms 内进入 fallback 模式并返回 HTTP 503 + 降级标记
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - `orch_gateway.py` 行数增长限制：相对基线 6109 行，净增长 ≤ 50 行
  - helper module 之间单向依赖（intake → projection → evidence），禁止循环引用
- **文档更新要求**:
  - 更新 `docs/CONFIGURATION.md` 新增 Gateway helper modules 注册方式
  - 更新 `docs/user-flow-guide_by_kimi.md` 0 阶 Gateway 数据流章节
  - 新增 `docs/adr/0010-gateway-seam-extraction.md` 记录 seam 拆分决策与 fallback 策略
- **涉及文件**: Create: `scripts/lib/gateway_intake.py`, Create: `scripts/lib/gateway_projection.py`, Create: `scripts/lib/gateway_evidence.py`, Modify: `scripts/lib/orch_gateway.py`, Create: `logs/gateway-fallback.jsonl` (gitkeep), Modify: `docs/CONFIGURATION.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Create: `docs/adr/0010-gateway-seam-extraction.md`

### Task 2 (U1b): Project Discovery Pipeline & Profile Generation

- **目标**: 建立可确认的项目接入流程，确保系统能在进入六阶闭环前自动识别项目技术栈、测试命令、部署目标与风险标志，并在 5 分钟内输出《项目探测报告》草稿。处理 `project-profile.yaml` 与现有 `project.json` 的冲突。
- **技术方案要点**:
  - **数据流**: `orch-init` → 探测脚本（技术栈检测器 / 测试命令发现器 / 部署目标扫描器 / 风险标志启发式）→ 归并到统一 profile model → 输出 `.hermes/project-profile.yaml` + `AGENTS.md` 初稿 + `SOUL.md` 初稿
  - **状态机**: Detect → Merge (解决 project.json vs project-profile.yaml 冲突) → Confirm → Generate → Sync
  - **接口契约**: `ProjectProfile` 统一 schema 同时兼容 yaml 输出和现有 json 读取；冲突解决策略：若 `project.json` 存在，以 `project-profile.yaml` 为真源，但保留 `project.json` 作为只读回退，并在首次生成时写入 `profile-version: 2` 标记
- **验收标准**:
  - **AC-1**: 标准项目（含 package.json / pyproject.toml / Makefile 中至少一个）从执行 `orch-init` 到输出《项目探测报告》草稿 ≤ 300 秒（5 分钟 SLA）
  - **AC-2**: 《项目探测报告》草稿至少包含：技术栈（语言+框架+版本）、测试命令（推断或显式配置）、部署目标（静态/容器/FaaS）、风险标志（protected target 命中清单）
  - **AC-3**: 当 5 分钟 SLA 超时（如大型 monorepo）时，触发**降级策略**：输出部分探测报告（至少包含技术栈）+ 标记 `status: partial` + 记录超时原因，不阻塞后续流程
  - **AC-4**: 开发者确认后生成 `.hermes/project-profile.yaml`、初始 `AGENTS.md`、`SOUL.md`，且均可被后续流程读取；`project.json` 与 `project-profile.yaml` 并存时，以 `project-profile.yaml` 为真源
  - **AC-5**: 接入配置在重复执行时结果稳定（同一仓库两次运行，技术栈/测试命令/部署目标字段完全一致）
- **负向用例**:
  - 空目录（无任何构建文件）运行 `orch-init`：不应无限挂起，应在 30 秒内输出 `status: unknown` 并进入人工确认流程
  - 同时存在 `.hermes/project.json` 和 `.hermes/project-profile.yaml` 且字段冲突时：系统必须明确以 yaml 为真源，禁止静默合并导致字段丢失
- **架构红线合规项**:
  - Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
  - 探测报告生成器不直接写 `orch_gateway.py`，通过 `orch-init` 调用 helper modules
- **文档更新要求**:
  - 更新 `docs/CONFIGURATION.md` 新增 project-profile.yaml 格式说明与 project.json 迁移指南
  - 更新 `docs/user-flow-guide_by_kimi.md` 0 阶首次接入流程，明确 5 分钟 SLA 与降级路径
- **涉及文件**: Modify: `scripts/bin/orch-init`, Modify: `scripts/bin/orch-profile-sync`, Modify: `scripts/bin/orch-mvp-wizard`, Modify: `docs/CONFIGURATION.md`, Modify: `docs/user-flow-guide_by_kimi.md`, Create: `scripts/tests/test-init-start-status.sh`, Modify: `scripts/tests/test-mvp-wizard.sh`, Modify: `scripts/tests/test-profile-packaging.sh`, Create: `scripts/tests/test-gateway-seam-extraction.sh`, Create: `scripts/tests/test-project-profile-conflict-resolution.sh`
