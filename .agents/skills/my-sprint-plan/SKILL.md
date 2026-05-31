---
name: my-sprint-plan
description: >
  根据需求/PRD 创建完整 Sprint 产物包：Plan、Spec、Schema（可选）、Checklist。
  内部调用 /ce-plan 生成结构化计划，脚本完成解析/拆分/文件生成，LLM 负责 SP 估算（含架构债务/安全/schema同步/负向测试等因子）、Spec/Schema 编写、验收标准量化、跨 Sprint 契约定义。
  触发词：创建 sprint 计划、拆分 sprint、规划 sprint、sprint plan、根据 xxx 创建 sprint。
---

# Sprint Plan Skill（增强版 v2）

> v2 核心改进：
> 1. **SP 估算**增加架构债务/安全/schema 三重同步/负向测试/文档同步/跨 Sprint 契约等因子，避免 5 SP 均一化低估
> 2. **Plan 文档**保留 Approach/Test Scenarios/接口契约/负向测试，不再压缩为 19 行清单
> 3. **Checklist**采用四级结构（架构红线+功能验收+测试覆盖+文档同步），逐条独立可勾选
> 4. **验收标准**强制量化，内置模糊词检测
> 5. **跨 Sprint 接口契约**显式定义，避免组装断裂

## 调用签名

```
my-sprint-plan <CONTENT_PATH> [--output <OUTPUT_DIR>]
```

- `CONTENT_PATH`: 需求内容文件路径（PRD、需求文档、feature spec 等）
- `--output`: 输出目录（默认 `${REPO_DIR}/docs/sprints/`）

## 核心流程

| 步骤 | 执行者 | 动作 | 产物 |
|------|--------|------|------|
| 1 | /ce-plan | 生成结构化 Plan | `PLAN_FILE` |
| 2 | `scripts/parse-plan.sh` | 解析 Plan → JSON | `/tmp/sprint-plan-parsed.json` |
| 3 | **LLM** | SP 估算（含 v2 因子）+ Spec + Schema | 估算 JSON + `spec.md` + `schema.md` |
| 4 | **LLM** | 验收标准量化 + 模糊词检测 + 跨 Sprint 契约 | 增强后的 estimated JSON |
| 5 | **LLM** | 负向测试设计 + 风险降级策略 | 增强后的 estimated JSON |
| 6 | `scripts/split-sprints.sh` | 拓扑排序 + 贪心装箱 | `/tmp/sprint-plan-assigned.json` |
| 7 | `scripts/generate-sprint-files.sh` | 生成所有 Markdown（v2 增强模板） | `plan-sprint-*.md`, `checklist-sprint-*.md`, `sprint-overview.md` |

```
CONTENT_PATH → /ce-plan → PLAN_FILE → parse → JSON
                                          ↓
                                    LLM: SP估算(3A) + Spec(3B) + Schema(3C)
                                          ↓
                                    LLM: 量化验收(3D) + 跨Sprint契约(3E) + 负向测试(3F)
                                          ↓
                                    split → assigned → generate → 产物
```

## 前置检查

执行步骤前验证以下条件。任一条件失败，按对应路径处理：

| 检查项 | 触发条件 | 一线修复 | 仍失败兜底 |
|--------|---------|---------|-----------|
| 输入文件存在性 | `${CONTENT_PATH}` 不存在或不可读 | 询问用户补充路径或基于对话内容直接生成 PRD | 终止执行，告知用户必须提供有效需求来源 |
| 输出目录冲突 | `${OUTPUT_DIR}` 已存在同名 sprint 文件 | 🔴 CHECKPOINT：询问用户「覆盖 / 增量更新 / 换目录」三选一，**必须得到明确答复后再继续** | 默认切至 `${OUTPUT_DIR}-v2` 并告知 |
| 工具链就绪 | `jq` / `bash` 不可用 | 提示安装缺失工具；或 fallback 到纯 LLM 生成 JSON | 终止执行，输出手动步骤清单 |

## 步骤详情

### Step 1: 调用 /ce-plan

调用 `/ce-plan`（Codex: `$ce-plan`）skill，传入 `${CONTENT_PATH}`。

- `/ce-plan` 自动处理上下文收集、需求分析、U-ID 拆分
- 等待完成后获取 `${PLAN_FILE}` 路径

> **如果 /ce-plan 调用失败**（超时、报错、返回空）：
> 1. 检查 `${CONTENT_PATH}` 是否在前置检查中已验证
> 2. 重试 1 次
> 3. 仍失败 → 跳过 /ce-plan，由 LLM 直接阅读 `${CONTENT_PATH}` 并手动拆分 implementation units，标记 `plan_source: manual`

### Step 2: 解析计划（脚本）

```bash
PARSED=/tmp/sprint-plan-parsed.json
bash scripts/parse-plan.sh "${PLAN_FILE}" > "${PARSED}"
```

> **如果 parse-plan.sh 失败**（非 0 退出、输出非 JSON）：
> 1. 检查脚本是否存在且可执行
> 2. 尝试直接读取 `${PLAN_FILE}` 为文本，用 LLM 提取结构化信息
> 3. 仍失败 → 终止，提示用户检查脚本或手动提供 JSON

输出 JSON 结构：`frontmatter`, `requirements[]`, `implementation_units[]`

每个 unit 包含：`uid`, `name`, `goal`, `requirements`, `dependencies`, `files`, `approach`, `test_scenarios`, `verification`

### Step 3: LLM 智力环节 — 估算与规格

读取 `${PARSED}`，完成以下三项：

**3A — SP 估算（参考 `reference/sp-estimation.md` v2）**

为每个 UID 赋故事点值（Fibonacci: 1/2/3/5/8），**必须应用估算因子加成体系**：

```bash
# 读取解析结果，在 implementation_units 中添加 sp 字段
# 估算时必须逐项检查：
# - F1 架构债务系数（是否向单一大文件堆叠？）
# - F2 安全/权限系数
# - F3 Schema 三重同步系数
# - F4 测试覆盖系数（每个 Test Scenario +0.5 SP，负向测试 +1 SP）
# - F5 文档/配置同步系数
# - F6 跨 Sprint 接口契约系数
# - F7 未知/模糊系数（关键技术方案未定义 +2 SP）
cat ${PARSED} | jq '
  .implementation_units |= [.[] | . + {sp: <LLM估算值>}]
' > /tmp/sprint-plan-estimated.json
```

> 🛑 STOP · **红线**：如果所有 Sprint 容量利用率相同（如全部是 71%），说明估算未反映实际复杂度差异，必须重新估算。

**3B — 生成 spec.md**（参考 `reference/output-formats.md` v2 中 Spec 模板）

从 plan 的 requirements 和 implementation_units 中提取，结构化为功能规格：
- 功能需求（FR-1, FR-2, ...）+ **可量化**验收标准
- 非功能需求（性能、安全、兼容性）
- 接口契约（API 端点、数据模型、**错误码**、**向后兼容策略**）
- 范围边界（包含 / 不包含）
- 风险与依赖（**含监控指标**）
- **成功指标**（对应 PRD 第 11 章，指标 ID/事件源/聚合规则/阈值/验证方式）

写入 `${OUTPUT_DIR}/spec.md`

**3C — 决定是否生成 schema.md**（参考 `reference/output-formats.md` v2 中 Schema 模板）

仅当 Plan 涉及以下变更时生成：
- 新增/修改 API 端点
- 数据库 Schema 变更（新增表/列/索引）
- 数据模型变更
- **Artifact / 配置文件格式变更**

如需要，按模板生成 `${OUTPUT_DIR}/schema.md`，**必须包含持久化说明和 Schema 一致性校验章节**。

### Step 4: LLM 智力环节 — 验收量化与契约定义

**3D — 验收标准量化与模糊词检测**

遍历每个 unit 的 `verification` 数组，执行以下检查：

1. **模糊词检测**：扫描以下词汇
   ```
   完整、及时、足够、合理、适当、有效、正确、正常、尽快、
   充分、必要、主要、关键、重要、良好、优化、完善、确保、
   保证、尽量、力争、原则上、一般情况下、视情况而定
   ```
2. **标记处理**：
   - 包含模糊词且无数值阈值/判定算法 → 标记 `⚠️ 需量化`
   - 已包含具体数值/阈值/算法 → 保留
3. **改写建议**：为每个标记项提供可量化改写版本

将处理后的 verification 写回 JSON，并在每个 unit 中增加 `verification_quantified: boolean` 字段。

**3E — 跨 Sprint 接口契约定义**

1. 遍历所有 unit 的 `dependencies`，构建 "producer → consumer" 映射
2. 为每个跨 Sprint 依赖定义契约：
   - 数据格式（JSON / YAML / 文件列表）
   - Schema 版本
   - 关键字段清单
   - 缺失时的降级行为
3. 将契约定义写入每个 producer unit 的 `output_contract` 字段

**3F — 负向测试设计与风险降级策略**

为每个 unit 生成：
- `negative_tests[]`：至少 2 条负向测试用例（阻塞条件、异常输入、降级场景）
- `risk_fallback[]`：至少 1 条风险 + 缓解措施 + 降级方案

将增强后的 JSON 写入 `/tmp/sprint-plan-enhanced.json`

### Step 5: Sprint 拆分（脚本）

```bash
bash scripts/split-sprints.sh /tmp/sprint-plan-enhanced.json > /tmp/sprint-plan-assigned.json
```

> **如果 split-sprints.sh 失败**：
> 1. 检查输入 JSON 是否包含 `implementation_units` 和 `sp` 字段
> 2. 手动按依赖拓扑排序 + 贪心装箱（容量 7 SP）分配至 Sprint
> 3. 输出 `/tmp/sprint-plan-assigned.json`

算法：拓扑排序（依赖序）→ 贪心装箱（容量 7 SP/ Sprint）

### Step 6: 生成文件（脚本 — v2 增强模板）

```bash
bash scripts/generate-sprint-files.sh /tmp/sprint-plan-assigned.json "${OUTPUT_DIR}"
```

> **如果 generate-sprint-files.sh 失败**：
> 1. 检查输入 JSON 格式
> 2. Fallback 到 LLM 直接按模板生成各 Markdown 文件
> 3. 标记 `generation_mode: manual_fallback`

增强点：
- **sprint-overview.md**：增加跨 Sprint 接口契约表 + 已知限制与债务表 + 容量利用率均一化警告
- **plan-sprint-{N}.md**：
  - 保留 Approach 全部细节（不丢失）
  - 验收标准逐条独立（不分号拼接）
  - 自动模糊词检测标记
  - 测试矩阵（Test Scenario → 测试脚本映射）
  - 负向测试 / 边界条件
  - 风险与降级策略
  - 接口契约变更表
- **checklist-sprint-{N}.md**：
  - **一级：架构红线合规**（helper module 优先、schema 同步、自动化校验）
  - **二级：功能验收**（逐条独立 checkbox，含验证方式和通过标准）
  - **三级：测试覆盖**（正向 Test Scenarios + 负向测试 + 回归范围）
  - **四级：文档/Schema/配置同步**（文件变更确认、一致性校验）
  - **签核**：增加"文档一致性""架构红线""接口契约"确认项

## 产物清单

```
${OUTPUT_DIR}/
├── spec.md                    # 功能规格说明（必须，含可量化验收标准）
├── schema.md                  # API/DB/Artifact Schema 变更（可选，含持久化说明+一致性校验）
├── sprint-overview.md         # 总览（含依赖图、跨 Sprint 契约、均一化警告）
├── plan-sprint-1.md           # Sprint 1 Plan（含 Approach/测试矩阵/负向测试/风险降级）
├── checklist-sprint-1.md      # Sprint 1 验收清单（四级结构，逐条独立）
├── plan-sprint-2.md           # Sprint 2 Plan
├── checklist-sprint-2.md      # Sprint 2 验收清单
└── ...
```

## 🔴 CHECKPOINT · LLM 评审后处理

生成产物后，**必须**使用 `/my-pr-review` 或独立评审 agent 对产物进行**找茬式评审**，重点检查：

1. **估算复核**：是否存在 5 SP 均一化？是否遗漏架构债务/安全/schema 同步因子？
2. **模糊词扫描**：验收标准中是否还有"完整""及时"等不可量化词汇？
3. **Checklist 完整性**：Test Scenarios 是否全部映射到 checklist？负向测试是否 ≥2 条？
4. **跨 Sprint 契约**：每个 producer→consumer 依赖是否都有契约定义？
5. **架构红线**：每个 Sprint 是否都涉及向单一大文件堆叠？如是，是否已拆分 seam extraction？

## 反例与黑名单

以下做法会降低 sprint 产物质量，**明确禁止**：

| # | 反模式 | 为什么禁止 | 正确做法 |
|---|--------|-----------|---------|
| 1 | 所有 UID 给相同 SP（如全 5） | 掩盖复杂度差异，容量规划失真 | 应用 v2 因子体系，差异化估算 |
| 2 | 验收标准含模糊词且无改写 | "完整""及时"等词无法验证 | 模糊词检测 → 量化改写 → 标记 ⚠️ |
| 3 | 跳过前置检查直接执行 | 文件不存在/目录冲突时流程崩溃 | 必须先跑前置检查，失败按 fallback 处理 |
| 4 | 压缩 Plan 为简单 todo 列表 | 丢失 Approach、Test Scenarios、接口契约 | 保留全部细节，按模板生成 |
| 5 | 跨 Sprint 依赖无契约定义 | 组装阶段断裂，接口不兼容 | 每个 producer→consumer 必须定义契约 |
| 6 | 负向测试 < 2 条 / unit | 遗漏边界条件和降级场景 | 每个 unit 至少 2 条负向测试 |
| 7 | 在无用户确认的情况下覆盖已有 sprint 文件 | 丢失历史产物，增量场景失控 | 必须经 🔴 CHECKPOINT 确认后再覆盖 |

## 与 /my-sprint-execute 的衔接

生成的文件可直接作为 `/my-sprint-execute`（Codex: `$my-sprint-execute`）的输入：

```
/my-sprint-execute <OUTPUT_DIR>/plan-sprint-{N}.md <OUTPUT_DIR>/checklist-sprint-{N}.md {N}
```
