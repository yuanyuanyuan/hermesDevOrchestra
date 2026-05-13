# Get Shit Done (GSD) 完整使用指南

> 基于官方源代码和文档的详细使用指南
> 版本: v1.50.0-canary.0
> 更新日期: 2026-05-12

---

## 目录

- [快速入门](#快速入门)
- [核心工作流](#核心工作流)
- [命令参考](#命令参考)
- [Agent 参考](#agent-参考)
- [Workflow 参考](#workflow-参考)
- [配置参考](#配置参考)
- [最佳实践](#最佳实践)

---

## 快速入门

### 安装

```bash
npx get-shit-done-cc@latest
```

安装程序会提示选择运行时（Claude Code、OpenCode、Gemini CLI 等）和安装位置（全局或本地）。

### 首次使用

```bash
# 启动 Claude Code（跳过权限确认模式）
claude --dangerously-skip-permissions

# 初始化新项目
/gsd-new-project

# 或者，如果已有代码库
/gsd-map-codebase
/gsd-new-project
```

### 六步核心循环

```bash
# 1. 初始化
/gsd-new-project

# 2. 讨论
/gsd-discuss-phase 1

# 3. 计划
/gsd-plan-phase 1

# 4. 执行
/gsd-execute-phase 1

# 5. 验证
/gsd-verify-work 1

# 6. 发布
/gsd-ship 1
/gsd-complete-milestone
/gsd-new-milestone
```

---

## 核心工作流

### 1. 项目初始化流程

```
/gsd-new-project
    │
    ├── 提问阶段（Questioning）
    │   └── 深入了解项目目标、约束、技术偏好
    │
    ├── 研究阶段（Research）— 4 个并行 agent
    │   ├── gsd-project-researcher (技术栈)
    │   ├── gsd-project-researcher (功能)
    │   ├── gsd-project-researcher (架构)
    │   └── gsd-project-researcher (陷阱)
    │
    ├── 综合阶段（Synthesis）
    │   └── gsd-research-synthesizer -> SUMMARY.md
    │
    ├── 需求提取
    │   └── REQUIREMENTS.md
    │
    ├── 路线图创建
    │   └── gsd-roadmapper -> ROADMAP.md
    │
    └── 用户批准
        └── STATE.md 初始化
```

**触发**: `/gsd-new-project [--auto @file.md]`

**产出**:
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/config.json`
- `.planning/research/`

### 2. 阶段讨论流程

```
/gsd-discuss-phase 1
    │
    ├── 加载上下文
    │   └── ROADMAP.md, PROJECT.md, REQUIREMENTS.md
    │
    ├── 识别灰色地带
    │   └── 扫描阶段描述中的实现决策点
    │
    ├── 用户选择讨论领域
    │   └── 交互式选择或 --all 全选
    │
    ├── 深入讨论
    │   └── 自适应提问，记录决策
    │
    └── 写入 CONTEXT.md
```

**触发**: `/gsd-discuss-phase [N] [--all|--auto|--batch|--analyze|--power|--assumptions]`

**标志**:
- `--all`: 跳过选择步骤，讨论所有灰色地带
- `--auto`: 自动选择推荐默认值
- `--batch`: 分组批量回答
- `--analyze`: 添加权衡分析
- `--power`: 文件批量回答模式
- `--assumptions`: 表面化 Claude 的实现假设

**产出**: `{phase}-CONTEXT.md`

### 3. 阶段计划流程

```
/gsd-plan-phase 1
    │
    ├── 初始化上下文
    │
    ├── 研究阶段（如启用）
    │   └── gsd-phase-researcher -> RESEARCH.md
    │       └── Package Legitimacy Gate (slopcheck)
    │
    ├── 模式映射（如启用）
    │   └── gsd-pattern-mapper -> PATTERNS.md
    │
    ├── 计划创建
    │   └── gsd-planner -> PLAN.md
    │
    ├── 计划验证（如启用，最多 3 次迭代）
    │   └── gsd-plan-checker
    │       └── 7 个验证维度
    │
    └── 提交 PLAN.md
```

**触发**: `/gsd-plan-phase [N] [--auto|--research|--skip-research|--gaps|--skip-verify|--prd <file>|--ingest <path>]`

**标志**:
- `--auto`: 跳过交互确认
- `--research`: 强制重新研究
- `--skip-research`: 跳过领域研究
- `--research-phase <N>`: 仅研究模式
- `--gaps`: 差距关闭模式（读取 VERIFICATION.md）
- `--skip-verify`: 跳过计划检查器
- `--prd <file>`: 使用 PRD 文件代替 discuss-phase
- `--ingest <path>`: 使用 ADR 文件作为上下文
- `--reviews`: 使用跨 AI 评审反馈重新计划
- `--tdd`: 启用 TDD 模式
- `--mvp`: 启用 MVP 模式

**产出**:
- `{phase}-{N}-PLAN.md`
- `{phase}-RESEARCH.md`（可选）
- `{phase}-VALIDATION.md`（可选）

### 4. 阶段执行流程

```
/gsd-execute-phase 1
    │
    ├── 解析参数和初始化
    │
    ├── 发现阶段中的计划
    │   └── 扫描 phases/ 目录
    │
    ├── 分析依赖关系
    │   └── 建立计划依赖图
    │
    ├── 波次分组
    │   └── 无依赖的计划并行执行
    │
    ├── 波次执行（按顺序）
    │   ├── Wave 1: 并行执行器
    │   │   ├── gsd-executor (Plan 01)
    │   │   ├── gsd-executor (Plan 02)
    │   │   └── ...
    │   ├── Wave 2: 等待 Wave 1 完成
    │   └── ...
    │
    ├── 验证（如启用）
    │   └── gsd-verifier -> VERIFICATION.md
    │
    ├── 代码审查（如启用）
    │   └── gsd-code-reviewer -> REVIEW.md
    │
    └── 状态更新
```

**触发**: `/gsd-execute-phase <N> [--wave N|--gaps-only|--cross-ai]`

**标志**:
- `--wave N`: 仅执行第 N 波
- `--gaps-only`: 仅执行差距修复
- `--cross-ai`: 委托给外部 AI CLI

**产出**:
- `{phase}-{N}-SUMMARY.md`（每个计划）
- `{phase}-VERIFICATION.md`（如启用）
- Git 提交（原子提交/任务）

### 5. 验证流程

```
/gsd-verify-work 1
    │
    ├── 初始化上下文
    │
    ├── 检查活动 UAT 会话
    │   └── 恢复或创建新会话
    │
    ├── 从 VERIFICATION.md 加载测试场景
    │
    ├── 逐个展示预期行为
    │   └── 用户确认或描述差异
    │
    ├── 记录问题和严重程度
    │
    └── 生成差距计划（如有差距）
        └── 可通过 /gsd-plan-phase --gaps 修复
```

**触发**: `/gsd-verify-work [N]`

**产出**: `{phase}-UAT.md`

---

## 命令参考

### 核心工作流命令

#### /gsd-discuss-phase

在规划前通过自适应提问收集阶段上下文。

**触发**: `/gsd-discuss-phase [N] [flags]`

**前置**: ROADMAP.md 存在

**产出**: CONTEXT.md

**标志**:
| 标志 | 说明 |
|------|------|
| `--all` | 跳过选择，讨论所有灰色地带 |
| `--auto` | 自动选择推荐默认值 |
| `--batch` | 分组批量回答 |
| `--analyze` | 添加权衡分析 |
| `--power` | 文件批量回答 |
| `--assumptions` | 表面化 Claude 假设 |

**示例**:
```bash
/gsd-discuss-phase 1              # 交互式讨论
/gsd-discuss-phase 1 --all        # 讨论所有灰色地带
/gsd-discuss-phase 3 --auto       # 自动模式
/gsd-discuss-phase 2 --analyze    # 带权衡分析
```

#### /gsd-plan-phase

创建详细的阶段计划并进行验证循环。

**触发**: `/gsd-plan-phase [N] [flags]`

**前置**: CONTEXT.md 存在

**产出**: PLAN.md, RESEARCH.md（可选）

**标志**:
| 标志 | 说明 |
|------|------|
| `--auto` | 跳过交互确认 |
| `--research` | 强制重新研究 |
| `--skip-research` | 跳过领域研究 |
| `--research-phase <N>` | 仅研究模式 |
| `--view` | 打印现有 RESEARCH.md |
| `--gaps` | 差距关闭模式 |
| `--skip-verify` | 跳过计划检查器 |
| `--prd <file>` | 使用 PRD 文件 |
| `--ingest <path>` | 使用 ADR 文件 |
| `--reviews` | 使用跨 AI 评审反馈 |
| `--tdd` | 启用 TDD 模式 |
| `--mvp` | 启用 MVP 模式 |

**示例**:
```bash
/gsd-plan-phase 1                              # 标准计划
/gsd-plan-phase 3 --skip-research              # 跳过研究
/gsd-plan-phase --auto                         # 非交互式
/gsd-plan-phase 2 --validate                   # 计划前验证状态
/gsd-plan-phase --research-phase 4             # 仅研究
/gsd-plan-phase 2 --ingest docs/adr/0010.md   # ADR 快速路径
```

#### /gsd-execute-phase

使用基于波的并行化执行阶段中的所有计划。

**触发**: `/gsd-execute-phase <N> [flags]`

**前置**: PLAN.md 存在

**产出**: SUMMARY.md, Git 提交

**标志**:
| 标志 | 说明 |
|------|------|
| `--wave N` | 仅执行第 N 波 |
| `--gaps-only` | 仅执行差距修复 |
| `--cross-ai` | 委托给外部 AI CLI |
| `--no-cross-ai` | 强制本地执行 |
| `--validate` | 执行前验证状态 |

**示例**:
```bash
/gsd-execute-phase 1                # 执行阶段 1
/gsd-execute-phase 1 --wave 2       # 仅执行 Wave 2
/gsd-execute-phase 2 --cross-ai     # 委托给外部 AI
```

#### /gsd-verify-work

通过对话式 UAT 验证构建的功能。

**触发**: `/gsd-verify-work [N]`

**前置**: 阶段已执行

**产出**: UAT.md

**示例**:
```bash
/gsd-verify-work 1                  # UAT 阶段 1
```

#### /gsd-progress

检查进度、推进工作流或分发自由形式意图。

**触发**: `/gsd-progress [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--next` | 自动推进到下一步 |
| `--do "task"` | 分发自由形式意图 |
| `--forensic` | 附加完整性审计 |

**示例**:
```bash
/gsd-progress                       # 查看状态和下一步
/gsd-progress --next                # 自动推进
/gsd-progress --do "fix auth bug"   # 分发意图
```

#### /gsd-autonomous

自主运行所有剩余阶段。

**触发**: `/gsd-autonomous [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--from N` | 从阶段 N 开始 |
| `--to N` | 到阶段 N 停止 |
| `--only N` | 仅执行阶段 N |
| `--interactive` | 精简上下文带用户输入 |

**示例**:
```bash
/gsd-autonomous                     # 运行所有剩余阶段
/gsd-autonomous --from 3            # 从阶段 3 开始
/gsd-autonomous --from 3 --to 5     # 运行阶段 3-5
```

---

### 项目管理命令

#### /gsd-new-project

初始化新项目，深度上下文收集。

**触发**: `/gsd-new-project [--auto @file.md]`

**前置**: 无

**产出**: PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, config.json

**示例**:
```bash
/gsd-new-project                    # 交互式
/gsd-new-project --auto @prd.md     # 从 PRD 自动提取
```

#### /gsd-new-milestone

开始新的里程碑周期。

**触发**: `/gsd-new-milestone [name] [--reset-phase-numbers]`

**前置**: 项目已初始化

**产出**: 更新的 PROJECT.md, 新 REQUIREMENTS.md, 新 ROADMAP.md

**示例**:
```bash
/gsd-new-milestone                  # 交互式
/gsd-new-milestone "v2.0 Mobile"    # 命名里程碑
```

#### /gsd-complete-milestone

归档已完成的里程碑并标记发布。

**触发**: `/gsd-complete-milestone`

**前置**: 里程碑审计完成（推荐）

**产出**: MILESTONES.md 条目, Git 标签

**示例**:
```bash
/gsd-complete-milestone
```

#### /gsd-milestone-summary

从里程碑工件生成综合项目摘要。

**触发**: `/gsd-milestone-summary [version]`

**前置**: 至少一个已完成或进行中的里程碑

**产出**: `.planning/reports/MILESTONE_SUMMARY-v{version}.md`

**示例**:
```bash
/gsd-milestone-summary                # 当前里程碑
/gsd-milestone-summary v1.0           # 特定里程碑
```

#### /gsd-phase

ROADMAP.md 中阶段的 CRUD。

**触发**: `/gsd-phase [flags] <description>`

**标志**:
| 标志 | 说明 |
|------|------|
| (无) | 追加新阶段 |
| `--insert <N>` | 在阶段 N 后插入小数阶段 |
| `--remove <N>` | 移除阶段并重新编号 |
| `--edit <N>` | 编辑现有阶段 |
| `--force` | 允许编辑进行中/已完成阶段 |

**示例**:
```bash
/gsd-phase "Add auth system"              # 追加
/gsd-phase --insert 3 "Fix race condition" # 插入 3.1
/gsd-phase --remove 7                      # 移除
/gsd-phase --edit 5                        # 编辑
```

#### /gsd-manager

交互式命令中心，从一个终端管理多个阶段。

**触发**: `/gsd-manager [--analyze-deps]`

**前置**: 项目已初始化

**行为**:
- 所有阶段的仪表板
- 推荐最优下一步
- 讨论内联运行，计划/执行作为后台 agent

**示例**:
```bash
/gsd-manager                        # 打开命令中心
/gsd-manager --analyze-deps         # 分析依赖关系
```

#### /gsd-workstreams

管理并行工作流。

**子命令**:
| 子命令 | 说明 |
|--------|------|
| `list` | 列出所有工作流 |
| `create <name>` | 创建新工作流 |
| `status <name>` | 工作流详情 |
| `switch <name>` | 设置活动工作流 |
| `progress` | 跨工作流进度概览 |
| `complete <name>` | 归档完成的工作流 |
| `resume <name>` | 恢复工作流 |

**示例**:
```bash
/gsd-workstreams                    # 列出
/gsd-workstreams create backend-api # 创建
/gsd-workstreams switch backend-api # 切换
/gsd-workstreams progress           # 进度
```

---

### 规划与设计命令

#### /gsd-spec-phase

用歧义评分澄清阶段交付物，生成 SPEC.md。

**触发**: `/gsd-spec-phase <N> [--auto] [--text]`

**产出**: SPEC.md

**示例**:
```bash
/gsd-spec-phase 2                   # 阶段 2 的规范
```

#### /gsd-mvp-phase

将阶段规划为垂直 MVP 切片。

**触发**: `/gsd-mvp-phase <N>`

**产出**: 用户故事, PLAN.md

**示例**:
```bash
/gsd-mvp-phase 1                    # MVP 切片规划
```

#### /gsd-ui-phase

为前端阶段生成 UI 设计合约。

**触发**: `/gsd-ui-phase [N]`

**产出**: UI-SPEC.md

**示例**:
```bash
/gsd-ui-phase 2                     # UI 设计合约
```

#### /gsd-ai-integration-phase

为 AI 系统阶段生成 AI-SPEC.md 设计合约。

**触发**: `/gsd-ai-integration-phase [N]`

**产出**: AI-SPEC.md

**并行 Agent**:
- gsd-framework-selector
- gsd-ai-researcher
- gsd-domain-researcher
- gsd-eval-planner

**示例**:
```bash
/gsd-ai-integration-phase           # 当前阶段
/gsd-ai-integration-phase 3         # 特定阶段
```

#### /gsd-plan-review-convergence

跨 AI 计划收敛循环。

**触发**: `/gsd-plan-review-convergence <N> [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--codex` | Codex 评审 |
| `--gemini` | Gemini 评审 |
| `--claude` | Claude 评审 |
| `--opencode` | OpenCode 评审 |
| `--all` | 所有可用评审 |
| `--max-cycles N` | 最大循环数 |

**示例**:
```bash
/gsd-plan-review-convergence 3                    # 默认评审
/gsd-plan-review-convergence 3 --codex            # 仅 Codex
/gsd-plan-review-convergence 3 --all --max-cycles 5
```

#### /gsd-sketch

用一次性 HTML 模型草图 UI/设计想法。

**触发**: `/gsd-sketch [idea] [--quick] [--text] [--wrap-up]`

**产出**: HTML 模型, 设计文档

**示例**:
```bash
/gsd-sketch                         # 交互式
/gsd-sketch "dashboard layout"      # 特定想法
/gsd-sketch --quick "sidebar nav"   # 快速模式
```

#### /gsd-spike

通过体验式探索验证想法。

**触发**: `/gsd-spike [idea] [--quick] [--text] [--wrap-up]`

**产出**: 验证结果, 学习文档

**示例**:
```bash
/gsd-spike                          # 交互式
/gsd-spike "can we stream LLM tokens"
/gsd-spike --wrap-up                # 打包发现为 skill
```

---

### 代码质量命令

#### /gsd-code-review

审查阶段中更改的源文件。

**触发**: `/gsd-code-review <N> [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--depth=quick\|standard\|deep` | 审查深度 |
| `--files file1,file2` | 显式文件列表 |
| `--fix` | 自动修复发现 |
| `--fix --all` | 修复包括 Info 级别 |
| `--fix --auto` | 修复并重新审查循环 |

**Agent**:
- gsd-code-reviewer（审查）
- gsd-code-fixer（修复）

**示例**:
```bash
/gsd-code-review 3                          # 标准审查
/gsd-code-review 2 --depth=deep             # 深度审查
/gsd-code-review 3 --fix                    # 审查并修复
/gsd-code-review 3 --fix --auto             # 修复循环
```

#### /gsd-review

跨 AI 同行评审。

**触发**: `/gsd-review --phase <N> [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--gemini` | Gemini 评审 |
| `--claude` | Claude 评审 |
| `--codex` | Codex 评审 |
| `--opencode` | OpenCode 评审 |
| `--all` | 所有可用 |

**示例**:
```bash
/gsd-review --phase 3 --all
/gsd-review --phase 2 --gemini
```

#### /gsd-secure-phase

回顾性验证威胁缓解措施。

**触发**: `/gsd-secure-phase [N]`

**Agent**: gsd-security-auditor

**示例**:
```bash
/gsd-secure-phase                   # 最后完成的阶段
/gsd-secure-phase 5                 # 特定阶段
```

#### /gsd-eval-review

审计 AI 阶段的评估覆盖范围。

**触发**: `/gsd-eval-review [N]`

**Agent**: gsd-eval-auditor

**示例**:
```bash
/gsd-eval-review                    # 当前阶段
/gsd-eval-review 3                  # 特定阶段
```

#### /gsd-ui-review

6 支柱视觉审计。

**触发**: `/gsd-ui-review [N]`

**Agent**: gsd-ui-auditor

**示例**:
```bash
/gsd-ui-review                      # 当前阶段
/gsd-ui-review 3                    # 特定阶段
```

---

### 审计与修复命令

#### /gsd-audit-uat

跨阶段 UAT 审计。

**触发**: `/gsd-audit-uat`

**示例**:
```bash
/gsd-audit-uat
```

#### /gsd-audit-milestone

里程碑完成审计。

**触发**: `/gsd-audit-milestone [version]`

**示例**:
```bash
/gsd-audit-milestone
```

#### /gsd-audit-fix

自动审计到修复管道。

**触发**: `/gsd-audit-fix [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--source <audit>` | 审计来源 |
| `--severity high\|medium\|all` | 最低严重程度 |
| `--max N` | 最大修复数 |
| `--dry-run` | 仅分类不修复 |

**示例**:
```bash
/gsd-audit-fix                              # 默认
/gsd-audit-fix --severity high             # 仅高严重
/gsd-audit-fix --dry-run                   # 预览
```

#### /gsd-validate-phase

Nyquist 验证缺口审计。

**触发**: `/gsd-validate-phase [N]`

**Agent**: gsd-nyquist-auditor

**示例**:
```bash
/gsd-validate-phase 2               # 审计阶段 2
```

---

### 上下文管理命令

#### /gsd-capture

捕获想法、任务、笔记和种子。

**触发**: `/gsd-capture [flags] [text]`

**标志**:
| 标志 | 说明 |
|------|------|
| (无) | 捕获为结构化 todo |
| `--note [text]` | 零摩擦笔记 |
| `--backlog <desc>` | 添加到待办列表 |
| `--seed [idea]` | 捕获前瞻性想法 |
| `--list` | 列出待办事项 |

**示例**:
```bash
/gsd-capture "Add dark mode"               # todo
/gsd-capture --note "Caching idea"         # 笔记
/gsd-capture --note list                   # 列出笔记
/gsd-capture --backlog "GraphQL API"       # 待办
/gsd-capture --seed "Real-time collab"     # 种子
```

#### /gsd-thread

管理持久化上下文线程。

**触发**: `/gsd-thread [list|close|status|name|description]`

**示例**:
```bash
/gsd-thread                         # 列出所有
/gsd-thread list --open             # 仅进行中
/gsd-thread close fix-deploy-key    # 关闭
/gsd-thread "Investigate timeout"   # 创建新线程
```

#### /gsd-pause-work

暂停工作时创建上下文交接。

**触发**: `/gsd-pause-work [--report]`

**示例**:
```bash
/gsd-pause-work                     # 创建交接
/gsd-pause-work --report            # 带会话报告
```

#### /gsd-resume-work

从上一个会话恢复工作。

**触发**: `/gsd-resume-work`

**示例**:
```bash
/gsd-resume-work
```

#### /gsd-explore

苏格拉底式构思和想法路由。

**触发**: `/gsd-explore [topic]`

**示例**:
```bash
/gsd-explore                        # 开放式构思
/gsd-explore auth strategy          # 特定主题
```

---

### 代码库分析命令

#### /gsd-map-codebase

使用并行映射代理分析代码库。

**触发**: `/gsd-map-codebase [area] [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--fast` | 快速单 agent 扫描 |
| `--focus tech\|arch\|quality\|concerns` | 聚焦区域 |
| `--query <term>` | 搜索现有 intel |

**Agent**: gsd-codebase-mapper（4 个并行）

**示例**:
```bash
/gsd-map-codebase                   # 完整分析（4 agent）
/gsd-map-codebase --fast            # 快速概览
/gsd-map-codebase --query auth      # 搜索 intel
```

#### /gsd-graphify

构建和查询项目知识图谱。

**触发**: `/gsd-graphify [build|query|status|diff]`

**示例**:
```bash
/gsd-graphify build                 # 构建图谱
/gsd-graphify query auth            # 查询
/gsd-graphify status                # 状态
```

#### /gsd-ingest-docs

从现有文档引导 .planning/ 设置。

**触发**: `/gsd-ingest-docs [path] [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--mode new\|merge` | 覆盖自动检测 |
| `--manifest <file>` | YAML 清单 |
| `--resolve auto` | 冲突解决模式 |

**Agent**:
- gsd-doc-classifier（并行分类）
- gsd-doc-synthesizer（综合）

**示例**:
```bash
/gsd-ingest-docs                    # 扫描仓库根
/gsd-ingest-docs docs/              # 仅 docs/
```

#### /gsd-extract-learnings

从完成的阶段提取决策和教训。

**触发**: `/gsd-extract-learnings <N> [--all]`

**示例**:
```bash
/gsd-extract-learnings 3            # 从阶段 3
/gsd-extract-learnings --all        # 从所有阶段
```

---

### 工具命令

#### /gsd-fast

内联执行简单任务 — 无子代理，无规划开销。

**触发**: `/gsd-fast [task]`

**适用**: 错字修复、配置更改、小重构、忘记的提交

**示例**:
```bash
/gsd-fast "fix typo in README"
/gsd-fast "add .env to gitignore"
```

#### /gsd-quick

使用 GSD 保证执行快速任务。

**触发**: `/gsd-quick [flags] [task]`

**标志**:
| 标志 | 说明 |
|------|------|
| `--full` | 完整质量管道 |
| `--validate` | 仅计划检查 + 验证 |
| `--discuss` | 轻量预计划讨论 |
| `--research` | 专注研究 |

**子命令**:
| 子命令 | 说明 |
|--------|------|
| `list` | 列出所有快速任务 |
| `status <slug>` | 任务状态 |
| `resume <slug>` | 恢复任务 |

**示例**:
```bash
/gsd-quick                          # 基本任务
/gsd-quick --full                   # 完整管道
/gsd-quick list                     # 列出任务
```

#### /gsd-config

配置 GSD 设置。

**触发**: `/gsd-config [flags]`

**标志**:
| 标志 | 说明 |
|------|------|
| (无) | 常用开关 |
| `--advanced` | 高级设置 |
| `--integrations` | 集成设置 |
| `--profile <name>` | 快速配置切换 |

**配置文件**: `.planning/config.json`

**示例**:
```bash
/gsd-config                         # 常用设置
/gsd-config --advanced              # 高级设置
/gsd-config --profile quality       # 切换到质量配置
```

#### /gsd-stats

显示项目统计。

**触发**: `/gsd-stats`

**示例**:
```bash
/gsd-stats
```

#### /gsd-health

诊断规划目录健康状况。

**触发**: `/gsd-health [--repair] [--context]`

**示例**:
```bash
/gsd-health                         # 检查健康
/gsd-health --repair                # 检查并修复
/gsd-health --context               # 上下文利用率
```

#### /gsd-update

更新 GSD 到最新版本。

**触发**: `/gsd-update [--sync] [--reapply]`

**示例**:
```bash
/gsd-update                         # 检查更新
/gsd-update --sync                  # 更新并同步 skills
/gsd-update --reapply               # 更新并重新应用补丁
```

#### /gsd-import

导入外部计划。

**触发**: `/gsd-import --from <file> | --from-gsd2`

**示例**:
```bash
/gsd-import --from /tmp/team-plan.md
/gsd-import --from-gsd2             # 从 GSD-2 迁移
```

---

### Git 与部署命令

#### /gsd-pr-branch

创建干净的 PR 分支。

**触发**: `/gsd-pr-branch [target]`

**示例**:
```bash
/gsd-pr-branch                      # 对 main
/gsd-pr-branch develop              # 对 develop
```

#### /gsd-ship

创建 PR、运行评审、准备合并。

**触发**: `/gsd-ship [N] [--draft]`

**前置**: 阶段已验证，gh CLI 已安装

**示例**:
```bash
/gsd-ship 4                         # 发布阶段 4
/gsd-ship 4 --draft                 # 草稿 PR
```

#### /gsd-undo

安全的 git 回滚。

**触发**: `/gsd-undo --last N | --phase NN | --plan NN-MM`

**示例**:
```bash
/gsd-undo --last 5                  # 选择最近 5 个
/gsd-undo --phase 03                # 回滚阶段 3
/gsd-undo --plan 03-02              # 回滚计划 03-02
```

---

### 调试与诊断命令

#### /gsd-debug

系统性调试，跨上下文重置保持状态。

**触发**: `/gsd-debug [list|status|continue|--diagnose] [issue]`

**Agent**:
- gsd-debug-session-manager
- gsd-debugger

**示例**:
```bash
/gsd-debug "Login button not responding"
/gsd-debug --diagnose "Intermittent 500 errors"
/gsd-debug list
/gsd-debug continue form-submit-500
```

#### /gsd-forensics

失败 GSD 工作流的后期调查。

**触发**: `/gsd-forensics [problem]`

**示例**:
```bash
/gsd-forensics                              # 交互式
/gsd-forensics "Phase 3 stalled"           # 带描述
```

#### /gsd-inbox

分类和审查 GitHub issues 和 PRs。

**触发**: `/gsd-inbox [flags]`

**示例**:
```bash
/gsd-inbox
/gsd-inbox --issues --label bug
```

---

## Agent 参考

### 研究类 Agents

#### gsd-project-researcher

在路线图创建前研究领域生态系统。

**职责**: 生成 STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md

**调用者**: `/gsd-new-project`, `/gsd-new-milestone`

**并行**: 4 个实例并行运行

#### gsd-phase-researcher

在规划前研究如何实现一个阶段。

**职责**: 生成 RESEARCH.md

**调用者**: `/gsd-plan-phase`

**特性**:
- 每个声明标注来源 [VERIFIED]/[CITED]/[ASSUMED]
- Package Legitimacy Gate (slopcheck)
- Validation Architecture 和 Security Domain

#### gsd-ui-researcher

生成 UI-SPEC.md 设计合约。

**职责**: 检测设计系统状态，只问未回答的问题

**调用者**: `/gsd-ui-phase`

#### gsd-advisor-researcher

研究单个灰色地带决策。

**职责**: 返回结构化比较表和理由

**调用者**: `discuss-phase --assumptions`

#### gsd-framework-selector

通过交互式决策矩阵选择 AI/LLM 框架。

**职责**: 最多 6 个问题的访谈，返回排名前 3 推荐

**调用者**: `/gsd-ai-integration-phase`

#### gsd-pattern-mapper

分析代码库现有模式。

**职责**: 生成 PATTERNS.md，将新文件映射到最接近的类比

**调用者**: `/gsd-plan-phase`

#### gsd-user-profiler

分析跨 8 个行为维度的会话消息。

**职责**: 生成开发者画像

**调用者**: `/gsd-profile-user`

---

### 规划类 Agents

#### gsd-planner

创建可执行的阶段计划。

**职责**: 任务分解、依赖分析、目标反向验证

**调用者**: `/gsd-plan-phase`, `--gaps`, `--reviews`

**特性**:
- 锁定决策不可协商
- 禁止简化语言
- 支持 TDD 计划类型

#### gsd-roadmapper

创建项目路线图。

**职责**: 阶段分解、需求映射、成功标准推导

**调用者**: `/gsd-new-project`

**特性**: 为 solo developer + Claude 设计

#### gsd-eval-planner

为 AI 阶段设计结构化评估策略。

**职责**: 写 AI-SPEC.md Sections 5-7

**调用者**: `/gsd-ai-integration-phase`

---

### 执行类 Agents

#### gsd-executor

以原子提交执行 GSD 计划。

**职责**: 代码实现、偏差处理、检查点管理

**调用者**: `/gsd-execute-phase`

**特性**:
- 4 条偏差规则
- 分析瘫痪保护
- 工作树安全
- 破坏性 git 命令禁止

#### gsd-code-fixer

智能应用代码审查修复。

**职责**: 每个修复原子提交

**调用者**: `/gsd-code-review --fix`

**特性**:
- 隔离 git worktree
- 3 层验证
- 安全回滚

---

### 验证类 Agents

#### gsd-verifier

通过目标反向分析验证阶段目标。

**职责**: 生成 VERIFICATION.md

**调用者**: `/gsd-verify-work`

**原则**: 任务完成 != 目标达成

#### gsd-plan-checker

在执行前验证计划。

**职责**: 7 个验证维度，修订循环（最多 3 次）

**调用者**: `/gsd-plan-phase`

#### gsd-code-reviewer

审查源文件的 bug、安全问题。

**职责**: 生成 REVIEW.md

**调用者**: `/gsd-code-review`

**深度**: quick, standard, deep

#### gsd-integration-checker

验证跨阶段集成和 E2E 流程。

**职责**: Requirements Integration Map

**调用者**: 里程碑审计器

#### gsd-nyquist-auditor

通过生成测试填补验证空白。

**职责**: 生成 VALIDATION.md

**调用者**: `/gsd-validate-phase`

#### gsd-security-auditor

验证威胁缓解措施。

**职责**: 生成 SECURITY.md

**调用者**: `/gsd-secure-phase`

#### gsd-eval-auditor

审计 AI 阶段的评估覆盖。

**职责**: 生成 EVAL-REVIEW.md

**调用者**: `/gsd-eval-review`

#### gsd-ui-auditor

6 支柱视觉审计。

**职责**: 生成 UI-REVIEW.md

**调用者**: `/gsd-ui-review`

#### gsd-ui-checker

验证 UI-SPEC.md 设计合约。

**职责**: 6 个验证维度

**调用者**: `/gsd-ui-phase`

---

### 文档类 Agents

#### gsd-doc-writer

写和更新项目文档。

**职责**: 10 种文档类型，4 种模式

**调用者**: `/gsd-docs-update`

#### gsd-doc-classifier

将规划文档分类。

**职责**: ADR/PRD/SPEC/DOC/UNKNOWN

**调用者**: `/gsd-ingest-docs`

#### gsd-doc-synthesizer

将分类文档综合为单一上下文。

**职责**: 冲突检测、优先级规则

**调用者**: `/gsd-ingest-docs`

---

### 综合类 Agents

#### gsd-research-synthesizer

将 4 个并行 researcher 的输出综合。

**职责**: 生成 SUMMARY.md

**调用者**: `/gsd-new-project`

#### gsd-intel-updater

分析代码库并写入结构化 intel 文件。

**职责**: 5 个 intel 文件

**调用者**: `/gsd-map-codebase --query`

---

### 调试类 Agents

#### gsd-debugger

使用科学方法调查 bug。

**职责**: 可证伪性要求、结构化推理检查点

**调用者**: `/gsd-debug`

**技术**: 二分搜索、橡皮鸭、delta 调试、最小复制、git bisect

#### gsd-debug-session-manager

管理多周期调试检查点。

**职责**: 生成 gsd-debugger agent，处理 5 种返回类型

**调用者**: `/gsd-debug`

---

## Workflow 参考

### 核心生命周期 Workflows

| Workflow | 文件 | 说明 |
|----------|------|------|
| discuss-phase | workflows/discuss-phase.md | 阶段讨论编排 |
| plan-phase | workflows/plan-phase.md | 阶段计划编排 |
| execute-phase | workflows/execute-phase.md | 阶段执行编排 |
| verify-work | workflows/verify-work.md | UAT 验证编排 |

### 项目初始化 Workflows

| Workflow | 文件 | 说明 |
|----------|------|------|
| new-project | workflows/new-project.md | 新项目初始化 |
| new-milestone | workflows/new-milestone.md | 新里程碑 |
| map-codebase | workflows/map-codebase.md | 代码库分析 |
| ingest-docs | workflows/ingest-docs.md | 文档导入 |

### 阶段管理 Workflows

| Workflow | 文件 | 说明 |
|----------|------|------|
| add-phase | workflows/add-phase.md | 添加阶段 |
| insert-phase | workflows/insert-phase.md | 插入阶段 |
| edit-phase | workflows/edit-phase.md | 编辑阶段 |
| mvp-phase | workflows/mvp-phase.md | MVP 阶段 |
| ui-phase | workflows/ui-phase.md | UI 阶段 |
| ai-integration-phase | workflows/ai-integration-phase.md | AI 阶段 |

### 质量与审查 Workflows

| Workflow | 文件 | 说明 |
|----------|------|------|
| code-review | workflows/code-review.md | 代码审查 |
| code-review-fix | workflows/code-review-fix.md | 审查修复 |
| review | workflows/review.md | 跨 AI 评审 |
| secure-phase | workflows/secure-phase.md | 安全审查 |
| eval-review | workflows/eval-review.md | 评估审计 |
| ui-review | workflows/ui-review.md | UI 审计 |

### 状态管理 Workflows

| Workflow | 文件 | 说明 |
|----------|------|------|
| progress | workflows/progress.md | 进度检查 |
| next | workflows/next.md | 自动推进 |
| pause-work | workflows/pause-work.md | 暂停工作 |
| resume-project | workflows/resume-project.md | 恢复工作 |
| undo | workflows/undo.md | 安全回滚 |

### 捕获与组织 Workflows

| Workflow | 文件 | 说明 |
|----------|------|------|
| add-todo | workflows/add-todo.md | 添加 TODO |
| note | workflows/note.md | 笔记 |
| add-backlog | workflows/add-backlog.md | 待办列表 |
| explore | workflows/explore.md | 构思 |
| thread | workflows/thread.md | 上下文线程 |

### 调试 Workflows

| Workflow | 文件 | 说明 |
|----------|------|------|
| debug | workflows/debug.md | 调试编排 |
| diagnose-issues | workflows/diagnose-issues.md | 问题诊断 |
| forensics | workflows/forensics.md | 后期调查 |
| node-repair | workflows/node-repair.md | 节点修复 |

---

## 配置参考

### 配置文件位置

`.planning/config.json`

### 核心配置项

```json
{
  "mode": "interactive",
  "model_profile": "balanced",
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "code_review": true,
    "parallelization": {
      "enabled": true
    }
  },
  "git": {
    "base_branch": "main",
    "phase_branch_template": "gsd/{phase-slug}"
  }
}
```

### 模式

| 模式 | 说明 |
|------|------|
| `interactive` | 确认每一步 |
| `yolo` | 自动批准 |

### 模型配置

| Profile | 说明 |
|---------|------|
| `quality` | 使用最高质量模型 |
| `balanced` | 平衡质量和成本 |
| `budget` | 优先成本 |
| `inherit` | 继承运行时默认 |

### 工作流开关

| 键 | 默认 | 说明 |
|----|------|------|
| `workflow.research` | true | 启用领域研究 |
| `workflow.plan_check` | true | 启用计划检查器 |
| `workflow.verifier` | true | 启用验证器 |
| `workflow.code_review` | true | 启用代码审查 |
| `workflow.parallelization.enabled` | true | 启用并行执行 |

---

## 最佳实践

### 1. 新项目最佳实践

```bash
# 1. 如有现有代码，先映射
/gsd-map-codebase

# 2. 初始化项目
/gsd-new-project

# 3. 审查研究结果
# 检查 .planning/research/ 目录

# 4. 审查路线图
# 检查 .planning/ROADMAP.md

# 5. 开始第一个阶段
/gsd-discuss-phase 1
```

### 2. 阶段执行最佳实践

```bash
# 1. 充分讨论（不要跳过）
/gsd-discuss-phase 1 --all

# 2. 计划并验证
/gsd-plan-phase 1

# 3. 审查计划
# 检查 .planning/phases/01-*/01-*-PLAN.md

# 4. 执行
/gsd-execute-phase 1

# 5. 验证（重要！）
/gsd-verify-work 1

# 6. 代码审查
/gsd-code-review 1

# 7. 发布
/gsd-ship 1
```

### 3. 质量保证最佳实践

- 不要跳过 `/gsd-verify-work`
- 使用 `/gsd-code-review --fix` 自动修复问题
- 使用 `/gsd-review --all` 获取多 AI 评审
- 定期运行 `/gsd-health` 检查规划目录健康

### 4. 上下文管理最佳实践

- 使用 `/gsd-pause-work` 暂停长会话
- 使用 `/gsd-resume-work` 恢复工作
- 使用 `/gsd-thread` 管理跨会话题
- 使用 `/gsd-capture --note` 记录想法

### 5. 调试最佳实践

```bash
# 启动调试会话
/gsd-debug "Bug description"

# 如果需要诊断
/gsd-debug --diagnose "Intermittent error"

# 继续之前的会话
/gsd-debug continue session-slug

# 后期调查
/gsd-forensics "What went wrong"
```

---

*文档生成: 2026-05-12*
*基于 GSD v1.50.0-canary.0 源码*
