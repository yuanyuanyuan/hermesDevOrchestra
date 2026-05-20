---
name: my-sprint-plan
description: >
  根据需求/PRD 创建完整 Sprint 产物包：Plan、Spec、Schema（可选）、Checklist。
  内部调用 /ce-plan 生成结构化计划，脚本完成解析/拆分/文件生成，LLM 仅负责 SP 估算和 Spec/Schema 编写。
  触发词：创建 sprint 计划、拆分 sprint、规划 sprint、sprint plan、根据 xxx 创建 sprint。
---

# Sprint Plan Skill

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
| 3 | **LLM** | SP 估算 + Spec + Schema | `spec.md`, `schema.md`(可选), 估算 JSON |
| 4 | `scripts/split-sprints.sh` | 拓扑排序 + 贪心装箱 | `/tmp/sprint-plan-assigned.json` |
| 5 | `scripts/generate-sprint-files.sh` | 生成所有 Markdown | `plan-sprint-*.md`, `checklist-sprint-*.md`, `sprint-overview.md` |

```
CONTENT_PATH → /ce-plan → PLAN_FILE → parse → JSON → LLM(SP+Spec) → split → assigned → generate → 产物
```

## 步骤详情

### Step 1: 调用 /ce-plan

调用 `/ce-plan`（Codex: `$ce-plan`）skill，传入 `${CONTENT_PATH}`。

- `/ce-plan` 自动处理上下文收集、需求分析、U-ID 拆分
- 等待完成后获取 `${PLAN_FILE}` 路径

### Step 2: 解析计划（脚本）

```bash
PARSED=/tmp/sprint-plan-parsed.json
bash scripts/parse-plan.sh "${PLAN_FILE}" > "${PARSED}"
```

输出 JSON 结构：`frontmatter`, `requirements[]`, `implementation_units[]`

每个 unit 包含：`uid`, `name`, `goal`, `requirements`, `dependencies`, `files`, `approach`, `test_scenarios`, `verification`

### Step 3: LLM 智力环节

读取 `${PARSED}`，完成以下三项：

**3A — SP 估算**（参考 `reference/sp-estimation.md`）

为每个 UID 赋故事点值（Fibonacci: 1/2/3/5/8），写入估算结果：

```bash
# 读取解析结果，在 implementation_units 中添加 sp 字段
cat ${PARSED} | jq '
  .implementation_units |= [.[] | . + {sp: <LLM估算值>}]
' > /tmp/sprint-plan-estimated.json
```

**3B — 生成 spec.md**（参考 `reference/output-formats.md` 中 Spec 模板）

从 plan 的 requirements 和 implementation_units 中提取，结构化为功能规格：
- 功能需求（FR-1, FR-2, ...）+ 验收标准
- 非功能需求（性能、安全、兼容性）
- 接口契约（API 端点、数据模型）
- 范围边界（包含 / 不包含）
- 风险与依赖

写入 `${OUTPUT_DIR}/spec.md`

**3C — 决定是否生成 schema.md**（参考 `reference/output-formats.md` 中 Schema 模板）

仅当 Plan 涉及以下变更时生成：
- 新增/修改 API 端点
- 数据库 Schema 变更（新增表/列/索引）
- 数据模型变更

如需要，按模板生成 `${OUTPUT_DIR}/schema.md`

### Step 4: Sprint 拆分（脚本）

```bash
bash scripts/split-sprints.sh /tmp/sprint-plan-estimated.json > /tmp/sprint-plan-assigned.json
```

算法：拓扑排序（依赖序）→ 贪心装箱（容量 7 SP/ Sprint）

### Step 5: 生成文件（脚本）

```bash
bash scripts/generate-sprint-files.sh /tmp/sprint-plan-assigned.json "${OUTPUT_DIR}"
```

## 产物清单

```
${OUTPUT_DIR}/
├── spec.md                    # 功能规格说明（必须）
├── schema.md                  # API/DB Schema 变更（可选）
├── sprint-overview.md         # 总览（含依赖图）
├── plan-sprint-1.md           # Sprint 1 Plan
├── checklist-sprint-1.md      # Sprint 1 验收清单（必须）
├── plan-sprint-2.md           # Sprint 2 Plan（如有）
└── checklist-sprint-2.md      # Sprint 2 验收清单（如有）
```

## 与 /my-sprint-execute 的衔接

生成的文件可直接作为 `/my-sprint-execute`（Codex: `$my-sprint-execute`）的输入：

```
/my-sprint-execute <OUTPUT_DIR>/plan-sprint-{N}.md <OUTPUT_DIR>/checklist-sprint-{N}.md {N}
```
