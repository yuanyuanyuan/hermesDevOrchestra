---
name: my-sprint-plan
description: >
  根据传入的需求/PRD/Plan 内容，创建 Sprint 计划和验收 Checklist。
  内部调用 /ce-plan（Codex: $ce-plan）生成结构化实现计划，再按中级开发工程师产能（7 SP/Sprint）进行故事点估算和 Sprint 拆分。
  单 Sprint = 1 周（5 工作日），超容量自动拆分多 Sprint，输出可直接交给 /my-sprint-execute 执行的产物。
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

```
CONTENT_PATH → /ce-plan → 结构化 Plan → SP 估算 → Sprint 拆分 → 输出文件
```

### 步骤 1：调用 /ce-plan 生成结构化计划

调用 `/ce-plan`（Codex: `$ce-plan`）skill，传入 `${CONTENT_PATH}` 作为需求来源。

- `/ce-plan` 会自动处理：上下文收集、需求分析、实现单元（U-ID）拆分、计划文件生成
- 等待 `/ce-plan` 完成后，获取生成的 Plan 文件路径（`${PLAN_FILE}`）

### 步骤 2：解析实现单元

从 `${PLAN_FILE}` 中提取所有实现单元（Implementation Units），每个单元包含：
- U-ID（如 U-1, U-2）
- 任务描述
- 涉及文件
- 验收标准

### 步骤 3：故事点估算

对每个实现单元估算故事点。

**中级开发工程师单 Sprint 产能（1 周 = 5 工作日）：**

| 指标 | 值 |
|------|------|
| 有效编码时间/天 | 6 小时（扣除会议、Code Review、上下文切换） |
| 单 Sprint 有效工时 | 30 小时 |
| **Sprint 容量** | **7 SP** |

**估算尺（Fibonacci 变体）：**

| SP | 预估工时 | 典型任务 |
|----|----------|----------|
| 1 | ~4h | 配置修改、简单 bug 修复、文档更新 |
| 2 | ~8h（1 天） | 单个接口、简单组件、单元测试补充 |
| 3 | ~12h | 模块级功能、中等复杂度集成 |
| 5 | ~20h | 跨模块功能、复杂业务逻辑 |
| 8 | ~32h | 架构级变更、多模块联动 |
| 13 | ~52h | **必须拆分**，不允许作为单个任务 |

**估算原则：**
- 包含开发 + 单元测试 + Code Review 修改时间
- 不确定的任务取高估值
- 含外部依赖的任务 +1 SP 缓冲
- 超过 8 SP 的单元必须拆分后再分配

### 步骤 4：Sprint 拆分

```
SPRINT_CAPACITY = 7
remaining = SPRINT_CAPACITY
sprint_num = 1

对按优先级排序的实现单元列表：
  unit = 当前单元

  如果 unit.sp > SPRINT_CAPACITY:
    将 unit 拆分为 2+ 个子单元（每个 ≤ SPRINT_CAPACITY）
    重新插入队列

  如果 remaining >= unit.sp:
    加入当前 sprint
    remaining -= unit.sp
  否则:
    关闭当前 sprint
    sprint_num += 1
    创建新 sprint（remaining = SPRINT_CAPACITY）
    加入新 sprint
    remaining -= unit.sp

  // 依赖检查：被依赖单元必须在同 Sprint 或更早 Sprint
  // 如果依赖在更晚 Sprint → 调整顺序或合并
```

**约束：**
- 单 Sprint 总 SP ≤ 7
- 依赖关系必须满足拓扑序
- 每个 Sprint 必须有可独立交付的增量价值

### 步骤 5：输出生成

#### 5A — 每个 Sprint 的 Plan 文件

路径：`${OUTPUT_DIR}/plan-sprint-{N}.md`

```markdown
# Sprint {N} Plan

**周期**: 第 {N} 周
**总故事点**: {X} SP / 7 SP 容量
**目标**: {一句话 Sprint 目标}

## 任务清单

| # | U-ID | 任务 | 类型 | SP | 依赖 | 状态 |
|---|------|------|------|----|------|------|
| 1 | U-1 | {任务描述} | feature | 3 | - | ⬜ |
| 2 | U-2 | {任务描述} | test | 2 | U-1 | ⬜ |

## 详细说明

### Task 1 (U-1): {任务名}
- **描述**: {详细描述}
- **验收标准**: {可验证的条件}
- **涉及文件**: {文件列表}
```

#### 5B — 每个 Sprint 的 Checklist 文件

路径：`${OUTPUT_DIR}/checklist-sprint-{N}.md`

```markdown
# Sprint {N} 验收清单

## 验收条件

- [ ] {U-1 验收条件}
- [ ] {U-2 验收条件}
- [ ] 全部测试通过（exit 0）
- [ ] 代码符合项目规范

## 验证命令

```bash
{根据项目结构生成的具体验证命令}
```

## 签核

- [ ] 开发完成
- [ ] 测试通过
- [ ] Code Review 完成
- [ ] 合并到 main
```

#### 5C — 总览文件

路径：`${OUTPUT_DIR}/sprint-overview.md`

汇总所有 Sprint 的目标、任务分配、依赖关系图（Mermaid）和时间线。

## 产物清单

执行完成后输出：

```
${OUTPUT_DIR}/
├── sprint-overview.md          # 总览
├── plan-sprint-1.md            # Sprint 1 Plan
├── checklist-sprint-1.md       # Sprint 1 Checklist
├── plan-sprint-2.md            # Sprint 2 Plan（如有）
├── checklist-sprint-2.md       # Sprint 2 Checklist（如有）
└── ...
```

## 与 /my-sprint-execute 的衔接

生成的 `plan-sprint-{N}.md` 和 `checklist-sprint-{N}.md` 可直接作为 `/my-sprint-execute`（Codex: `$my-sprint-execute`）的输入：

```
/my-sprint-execute <OUTPUT_DIR>/plan-sprint-{N}.md <OUTPUT_DIR>/checklist-sprint-{N}.md {N}
```
