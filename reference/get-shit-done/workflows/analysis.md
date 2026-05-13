# GSD Workflows 分析

> 分析自 `/tmp/gsd-analysis/get-shit-done/workflows/` 目录下 87 个 .md 文件。
> 生成日期: 2026-05-12

---

## 分类概览

| 分类 | 数量 | 说明 |
|------|------|------|
| 核心阶段生命周期 | 9 | Discuss -> Plan -> Execute -> Verify 完整流程 |
| 阶段管理 | 10 | 增删改查阶段、MVP/UI/AI 特殊阶段 |
| 项目初始化 | 4 | 新项目、新里程碑、代码库映射 |
| 执行模式 | 5 | 自主执行、管理器、快速任务、调度器 |
| 质量与审查 | 8 | 代码审查、跨AI审查、UI审查、安全审查 |
| 验证与审计 | 4 | 里程碑审计、UAT审计、自动修复 |
| 里程碑生命周期 | 4 | 完成里程碑、总结、差距规划 |
| 状态管理 | 6 | 进度检查、恢复、暂停、撤销、线程 |
| 捕获与组织 | 7 | TODO、笔记、种子、探索、导入 |
| 文档 | 3 | 文档更新、学习提取、会话报告 |
| 基础设施 | 9 | 设置、清理、健康检查、更新、帮助 |
| 调试 | 4 | 调试、诊断、取证、节点修复 |
| 研究与探索 | 5 | Spike、Sketch、依赖分析 |
| 工作区管理 | 3 | 新建、删除、列出工作区 |
| PR与发布 | 3 | PR分支、发布、补丁重应用 |
| 用户画像 | 1 | 开发者行为分析 |

---

## 详细分析

---

### 一、核心阶段生命周期 (Core Phase Lifecycle)

---

#### 1. discuss-phase.md

- **目的**: 提取下游代理需要的实现决策。通过自适应面试分析阶段中的灰色地带，让用户选择要讨论的内容，然后深入探讨每个选定领域。
- **触发**: `/gsd-discuss-phase <N>`
- **步骤**:
  1. 加载阶段上下文和先前决策
  2. 识别灰色地带（实现决策点）
  3. 让用户选择要讨论的领域
  4. 深入讨论每个选定领域
  5. 写入 CONTEXT.md
  6. Git 提交
- **调用 Agents**: 无（纯对话流程，但支持 --power 模式委托给 discuss-phase-power）
- **输入**: ROADMAP.md, PROJECT.md, REQUIREMENTS.md, STATE.md, 代码库
- **产出**: `{phase_dir}/{padded}-CONTEXT.md`, 讨论日志
- **质量门控**: 范围保护（防止范围蔓延）、灰色地带识别完整性
- **依赖**: 无（可独立运行）
- **模式**: 支持 --power（批量问题）、--auto（自动回答）、--chain（链式推进）、--text（纯文本）、--batch、--analyze 等多种模式

---

#### 2. discuss-phase-assumptions.md

- **目的**: 使用代码库优先分析和假设表面化来提取实现决策，替代面试式提问。Claude 先分析代码库、形成观点，然后只问用户真正不确定的问题。
- **触发**: `/gsd-discuss-phase <N> --assumptions`（由 discuss-phase 调用）
- **步骤**:
  1. 加载阶段上下文
  2. 生成假设分析器代理
  3. 代理深入分析代码库
  4. 表面化假设并附带证据
  5. 用户纠正错误假设
  6. 写入 CONTEXT.md
- **调用 Agents**: `gsd-assumptions-analyzer`
- **输入**: ROADMAP.md, 代码库, 先前 CONTEXT.md
- **产出**: CONTEXT.md（与标准 discuss-phase 格式相同）
- **质量门控**: 每个假设必须引用证据（文件路径、发现的模式）、必须说明错误后果
- **依赖**: 无

---

#### 3. discuss-phase-power.md

- **目的**: 为 discuss-phase 提供高级用户模式。预先生成所有问题到 JSON 状态文件和 HTML 伴侣 UI，用户按自己的节奏回答，然后一次性处理所有答案生成 CONTEXT.md。
- **触发**: `/gsd-discuss-phase <N> --power`
- **步骤**:
  1. 分析灰色地带（与标准模式相同）
  2. 生成所有问题到 `{padded}-QUESTIONS.json`
  3. 生成 HTML 伴侣 UI
  4. 等待用户回答
  5. 处理所有答案
  6. 生成 CONTEXT.md
- **调用 Agents**: 无
- **输入**: ROADMAP.md, 代码库
- **产出**: QUESTIONS.json, QUESTIONS.html, CONTEXT.md
- **质量门控**: 答案验证、完整性检查
- **依赖**: 无

---

#### 4. plan-phase.md

- **目的**: 为路线图阶段创建可执行的阶段提示（PLAN.md 文件），集成研究和验证。默认流程：研究（如需要）-> 计划 -> 验证 -> 完成。编排 gsd-phase-researcher、gsd-planner 和 gsd-plan-checker 代理，带修订循环（最多 3 次迭代）。
- **触发**: `/gsd-plan-phase <N>`
- **步骤**:
  1. 初始化上下文
  2. 解析和规范化参数
  3. 检查 UI-SPEC.md 和 AI-SPEC.md 前置条件
  4. 执行发现（如需要）
  5. 运行模式映射器（如启用）
  6. 生成研究员代理（如启用）
  7. 生成计划器代理
  8. 运行计划检查器（如启用，最多 3 次迭代）
  9. 运行 Nyquist 验证（如启用）
  10. 提交 PLAN.md
- **调用 Agents**: `gsd-phase-researcher`, `gsd-pattern-mapper`, `gsd-planner`, `gsd-plan-checker`
- **输入**: CONTEXT.md, RESEARCH.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, PROJECT.md, 代码库
- **产出**: `{padded}-{plan}-PLAN.md`, RESEARCH.md（可选）, PATTERNS.md（可选）
- **质量门控**: 计划检查器（最多 3 次修订迭代）、Nyquist 验证、TDD 模式门控、MVP 模式门控
- **依赖**: discuss-phase（CONTEXT.md）
- **特殊模式**: --research, --skip-research, --research-phase, --gaps, --skip-verify, --skip-ui, --prd, --ingest, --reviews, --text, --bounce, --skip-bounce, --chunked, --mvp

---

#### 5. execute-phase.md

- **目的**: 使用基于波次的并行执行来执行阶段中的所有计划。编排器保持精简 -- 将计划执行委托给子代理。
- **触发**: `/gsd-execute-phase <N>`
- **步骤**:
  1. 解析参数
  2. 初始化上下文
  3. 发现阶段中的计划
  4. 分析计划依赖关系
  5. 将计划分组为波次
  6. 按波次生成执行器代理
  7. 处理检查点
  8. 收集结果
  9. 运行验证器（如启用）
  10. 运行代码审查（如启用）
  11. 运行 UI 审查（如启用）
  12. 过渡到下一阶段
- **调用 Agents**: `gsd-executor`, `gsd-verifier`, `gsd-code-reviewer`, `gsd-ui-auditor`
- **输入**: PLAN.md 文件, CONTEXT.md, RESEARCH.md, 代码库
- **产出**: SUMMARY.md 文件, VERIFICATION.md（可选）, REVIEW.md（可选）, UI-REVIEW.md（可选）
- **质量门控**: 验证器、代码审查、UI 审查、工作树隔离、子模块安全检查
- **依赖**: plan-phase（PLAN.md）
- **特殊模式**: --wave N, --gaps-only, --cross-ai, --no-cross-ai

---

#### 6. execute-plan.md

- **目的**: 执行单个阶段提示（PLAN.md）并创建结果摘要（SUMMARY.md）。
- **触发**: 由 execute-phase 内部调用
- **步骤**:
  1. 初始化上下文
  2. 识别计划
  3. 记录开始时间
  4. 解析任务段
  5. 执行任务（内联或委托给 gsd-executor）
  6. 处理检查点
  7. 创建 SUMMARY.md
  8. 更新 STATE.md
- **调用 Agents**: `gsd-executor`（可选）
- **输入**: PLAN.md, CONTEXT.md, 代码库
- **产出**: SUMMARY.md, 代码变更, Git 提交
- **质量门控**: 原子关闭不变量（生产代码提交 -> SUMMARY 提交 -> STATE/ROADMAP 更新）、节点修复
- **依赖**: plan-phase（PLAN.md）

---

#### 7. verify-phase.md

- **目的**: 通过目标反向分析验证阶段目标达成情况。检查代码库是否交付了阶段承诺的内容，而不仅仅是任务已完成。
- **触发**: 由 execute-phase 内部调用
- **步骤**:
  1. 加载上下文
  2. 建立必须存在的条件
  3. 检查代码库中的实际状态
  4. 验证每个必须条件
  5. 生成验证报告
  6. 标记差距
- **调用 Agents**: `gsd-verifier`
- **输入**: PLAN.md, SUMMARY.md, 代码库, REQUIREMENTS.md
- **产出**: VERIFICATION.md
- **质量门控**: 目标反向验证（任务完成 != 目标达成）
- **依赖**: execute-phase（SUMMARY.md）

---

#### 8. verify-work.md

- **目的**: 通过对话式测试验证构建的功能。创建 UAT.md 跟踪测试进度，支持跨会话持久化，并将差距输入 /gsd-plan-phase --gaps。
- **触发**: `/gsd-verify-work <N>`
- **步骤**:
  1. 初始化上下文
  2. 检查活动 UAT 会话
  3. 从 VERIFICATION.md 加载测试场景
  4. 逐个展示预期行为
  5. 用户确认或描述差异
  6. 记录问题和严重程度
  7. 生成差距计划（如有差距）
- **调用 Agents**: `gsd-planner`, `gsd-plan-checker`（用于差距规划）
- **输入**: VERIFICATION.md, PLAN.md, SUMMARY.md, 代码库
- **产出**: UAT.md, 差距计划（可选）
- **质量门控**: "展示预期，询问现实是否匹配" 哲学
- **依赖**: verify-phase（VERIFICATION.md）
- **特殊模式**: --gaps, --text, --ws

---

#### 9. transition.md

- **目的**: 标记当前阶段完成并推进到下一阶段。这是进度跟踪和 PROJECT.md 演变发生的自然时刻。（内部工作流，非用户命令）
- **触发**: 由 execute-phase 在自动推进时内部调用
- **步骤**:
  1. 加载项目状态
  2. 验证完成
  3. 更新 STATE.md
  4. 更新 ROADMAP.md
  5. 演变 PROJECT.md
  6. 运行毕业扫描
  7. 路由到下一阶段
- **调用 Agents**: 无
- **输入**: STATE.md, PROJECT.md, ROADMAP.md, SUMMARY.md
- **产出**: 更新的 STATE.md, ROADMAP.md, PROJECT.md
- **质量门控**: 完成验证、PROJECT.md 演变审查
- **依赖**: execute-phase（所有 SUMMARY.md）

---

### 二、阶段管理 (Phase Management)

---

#### 10. add-phase.md

- **目的**: 在当前里程碑末尾添加新的整数阶段。自动计算下一阶段编号，创建阶段目录，并更新路线图结构。
- **触发**: `/gsd-add-phase <description>`
- **步骤**:
  1. 解析参数
  2. 加载阶段操作上下文
  3. 委托 `gsd-sdk query phase.add`
  4. 更新 STATE.md
  5. 完成报告
- **调用 Agents**: 无
- **输入**: ROADMAP.md, STATE.md
- **产出**: 新阶段目录, 更新的 ROADMAP.md, STATE.md
- **质量门控**: 无
- **依赖**: 无

---

#### 11. insert-phase.md

- **目的**: 在里程碑中现有整数阶段之间插入小数阶段用于紧急工作。使用小数编号（72.1, 72.2 等）保留计划阶段的逻辑顺序。
- **触发**: `/gsd-insert-phase <after> <description>`
- **步骤**:
  1. 解析参数
  2. 加载阶段操作上下文
  3. 委托 `gsd-sdk query phase.insert`
  4. 更新 STATE.md
  5. 完成报告
- **调用 Agents**: 无
- **输入**: ROADMAP.md, STATE.md
- **产出**: 新阶段目录（带 INSERTED 标记）, 更新的 ROADMAP.md, STATE.md
- **质量门控**: 目标阶段存在性验证
- **依赖**: 无

---

#### 12. edit-phase.md

- **目的**: 就地编辑 ROADMAP.md 中现有阶段的任何字段。始终保留阶段编号和位置。对进行中和已完成的阶段有保护，除非传递 --force。
- **触发**: `/gsd-edit-phase <phase-number> [--force]`
- **步骤**:
  1. 解析参数
  2. 加载阶段操作上下文
  3. 加载阶段数据
  4. 展示当前值
  5. 收集编辑
  6. 验证 depends_on 引用
  7. 显示差异并确认
  8. 写入更新
- **调用 Agents**: 无
- **输入**: ROADMAP.md
- **产出**: 更新的 ROADMAP.md
- **质量门控**: depends_on 引用验证、差异确认
- **依赖**: 无

---

#### 13. remove-phase.md

- **目的**: 从项目路线图中删除未开始的未来阶段，删除其目录，重新编号所有后续阶段以保持干净的线性序列。
- **触发**: `/gsd-remove-phase <phase-number>`
- **步骤**:
  1. 解析参数
  2. 加载阶段操作上下文
  3. 验证是未来阶段
  4. 确认删除
  5. 委托 `gsd-sdk query phase.remove`
  6. 提交
- **调用 Agents**: 无
- **输入**: ROADMAP.md, STATE.md, 阶段目录
- **产出**: 更新的 ROADMAP.md, STATE.md, 删除的阶段目录, 重新编号的目录和文件
- **质量门控**: 未来阶段验证（不能删除当前或已完成的阶段）
- **依赖**: 无

---

#### 14. spec-phase.md

- **目的**: 通过带有定量模糊评分的苏格拉底式面试循环澄清阶段交付什么。产生带有可证伪需求的 SPEC.md，discuss-phase 将其视为锁定的决策。
- **触发**: `/gsd-spec-phase <N>`
- **步骤**:
  1. 解析参数
  2. 运行面试循环（研究者、简化者、边界守护者、失败分析师、种子关闭者视角）
  3. 评分模糊度（目标清晰度、边界清晰度、约束清晰度、验收标准）
  4. 达到门控阈值（模糊度 <= 0.20）
  5. 写入 SPEC.md
- **调用 Agents**: 无
- **输入**: ROADMAP.md, 代码库, REQUIREMENTS.md
- **产出**: `{padded}-SPEC.md`
- **质量门控**: 模糊度评分门控（所有维度 >= 最小值，总模糊度 <= 0.20）
- **依赖**: 无

---

#### 15. mvp-phase.md

- **目的**: 指导用户完成 MVP 模式的阶段规划。提示"作为/我希望/以便"用户故事，对故事运行 SPIDR 拆分检查，将结果写入 ROADMAP.md，并委托给 /gsd-plan-phase。
- **触发**: `/gsd-mvp-phase <N>`
- **步骤**:
  1. 解析和验证阶段参数
  2. 验证阶段存在并检查状态
  3. 收集用户故事（作为/我希望/以便）
  4. 运行 SPIDR 拆分检查
  5. 写入 ROADMAP.md（标记为 MVP 模式）
  6. 委托给 `/gsd-plan-phase`
- **调用 Agents**: 无（委托给 plan-phase）
- **输入**: ROADMAP.md, 阶段目标
- **产出**: 更新的 ROADMAP.md（mode: mvp）, 委托给 plan-phase
- **质量门控**: SPIDR 拆分检查、用户故事完整性
- **依赖**: 无

---

#### 16. ui-phase.md

- **目的**: 为前端阶段生成 UI 设计合约（UI-SPEC.md）。编排 gsd-ui-researcher 和 gsd-ui-checker 带修订循环。在 discuss-phase 和 plan-phase 之间插入。
- **触发**: `/gsd-ui-phase <N>`
- **步骤**:
  1. 初始化上下文
  2. 检查前置条件（CONTEXT.md 存在）
  3. 检查现有 UI-SPEC.md
  4. 生成 UI 研究员代理
  5. 运行 UI 检查器（最多 3 次修订）
  6. 验证 UI-SPEC 完整性
  7. 提交
- **调用 Agents**: `gsd-ui-researcher`, `gsd-ui-checker`
- **输入**: CONTEXT.md, RESEARCH.md, 代码库, sketch-findings（可选）
- **产出**: `{padded}-UI-SPEC.md`
- **质量门控**: UI 检查器修订循环（最多 3 次）、完整性验证
- **依赖**: discuss-phase（CONTEXT.md）

---

#### 17. ai-integration-phase.md

- **目的**: 为涉及构建 AI 系统的阶段生成 AI 设计合约（AI-SPEC.md）。编排 gsd-framework-selector -> gsd-ai-researcher -> gsd-domain-researcher -> gsd-eval-planner 带验证门控。
- **触发**: `/gsd-ai-integration-phase <N>`
- **步骤**:
  1. 初始化上下文
  2. 解析和验证阶段
  3. 检查前置条件
  4. 检查现有 AI-SPEC.md
  5. 生成框架选择器
  6. 初始化 AI-SPEC.md
  7. 生成 AI 研究员（顺序执行，防止竞争）
  8. 生成领域研究员（等待步骤 7 完成）
  9. 生成评估规划器
  10. 验证 AI-SPEC 完整性
  11. 提交
- **调用 Agents**: `gsd-framework-selector`, `gsd-ai-researcher`, `gsd-domain-researcher`, `gsd-eval-planner`
- **输入**: CONTEXT.md, REQUIREMENTS.md, ai-frameworks.md, ai-evals.md
- **产出**: `{padded}-AI-SPEC.md`
- **质量门控**: 完整性验证（7 个部分必须非空）、顺序执行防止竞争
- **依赖**: discuss-phase（CONTEXT.md）

---

#### 18. ultraplan-phase.md

- **目的**: 将 GSD 的计划阶段卸载到 Claude Code 的 ultraplan 云基础设施。（BETA 功能）
- **触发**: `/gsd-ultraplan-phase <N>`
- **步骤**:
  1. 显示 BETA 警告
  2. 运行时门控（仅 Claude Code）
  3. 初始化上下文
  4. 调用 ultraplan 云 API
  5. 接收并验证结果
  6. 写入 PLAN.md
- **调用 Agents**: 无（使用 Claude Code 云基础设施）
- **输入**: 阶段上下文
- **产出**: PLAN.md
- **质量门控**: 运行时门控、结果验证
- **依赖**: 无

---

#### 19. discovery-phase.md

- **目的**: 在适当的深度级别执行发现。产生 DISCOVERY.md（用于级别 2-3），为 PLAN.md 创建提供信息。由 plan-phase.md 的 mandatory_discovery 步骤调用。
- **触发**: 由 plan-phase 内部调用
- **步骤**:
  1. 确定深度级别（1: 快速验证, 2: 标准, 3: 深入）
  2. 级别 1: Context7 快速验证
  3. 级别 2: 标准发现（15-30 分钟）
  4. 级别 3: 深入发现（1+ 小时）
- **调用 Agents**: 无
- **输入**: 阶段目标, 代码库
- **产出**: DISCOVERY.md（级别 2-3）
- **质量门控**: 源层次结构（Context7 优先于 WebSearch）
- **依赖**: plan-phase

---

### 三、项目初始化 (Project Initialization)

---

#### 20. new-project.md

- **目的**: 通过统一流程初始化新项目：深度提问、研究（可选）、需求、路线图。一个命令从想法到准备规划。
- **触发**: `/gsd-new-project`
- **步骤**:
  1. 设置（检查代理安装、项目状态）
  2. 配置（YOLO/交互模式、粒度、Git、代理）
  3. 深度提问（理解要构建什么）
  4. 可选领域研究（生成 4 个并行研究代理）
  5. 需求定义（v1/v2/范围外）
  6. 需求审批
  7. 路线图创建（阶段分解和成功标准）
  8. 路线图审批
  9. 提交所有制品
- **调用 Agents**: `gsd-project-researcher`, `gsd-research-synthesizer`, `gsd-roadmapper`
- **输入**: 用户想法/文档
- **产出**: PROJECT.md, config.json, research/, REQUIREMENTS.md, ROADMAP.md, STATE.md
- **质量门控**: 代理安装检查、需求审批、路线图审批
- **依赖**: 无
- **特殊模式**: --auto（自动模式，需要想法文档）

---

#### 21. new-milestone.md

- **目的**: 为现有项目启动新的里程碑周期。加载项目上下文，收集里程碑目标，更新 PROJECT.md 和 STATE.md，可选运行并行研究，定义带有 REQ-ID 的范围需求，生成路线图器创建分阶段执行计划。
- **触发**: `/gsd-new-milestone`
- **步骤**:
  1. 加载上下文
  2. 收集里程碑目标（从 MILESTONE-CONTEXT.md 或对话）
  3. 扫描已种植的种子
  4. 可选领域研究
  5. 需求定义
  6. 需求审批
  7. 路线图创建
  8. 路线图审批
  9. 提交
- **调用 Agents**: `gsd-project-researcher`, `gsd-research-synthesizer`, `gsd-roadmapper`
- **输入**: PROJECT.md, MILESTONES.md, STATE.md, MILESTONE-CONTEXT.md（可选）
- **产出**: 更新的 PROJECT.md, STATE.md, 新 REQUIREMENTS.md, 新 ROADMAP.md
- **质量门控**: 需求审批、路线图审批
- **依赖**: 已有项目（PROJECT.md）
- **特殊模式**: --reset-phase-numbers

---

#### 22. map-codebase.md

- **目的**: 编排并行代码库映射器代理分析代码库并在 .planning/codebase/ 中产生结构化文档。每个代理有新鲜上下文，探索特定焦点区域，并直接写入文档。
- **触发**: `/gsd-map-codebase [--fast] [--focus <area>] [--query <term>]`
- **步骤**:
  1. 解析路径标志
  2. 检查现有文档
  3. 创建输出目录
  4. 生成 4 个并行映射器代理
  5. 收集结果
  6. 写入摘要
- **调用 Agents**: `gsd-codebase-mapper`（4 个并行实例）
- **输入**: 代码库
- **产出**: .planning/codebase/ 下 7 个文档（STACK.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, INTEGRATIONS.md, CONCERNS.md）
- **质量门控**: 文档质量优先于长度、始终包含文件路径
- **依赖**: 无
- **特殊模式**: --fast, --focus, --query, --paths

---

#### 23. scan.md

- **目的**: 轻量级代码库评估。生成单个 gsd-codebase-mapper 代理用于一个焦点区域，产生有针对性的文档。
- **触发**: `/gsd-scan [--focus <area>]`
- **步骤**:
  1. 解析参数并解析焦点
  2. 检查现有文档
  3. 创建输出目录
  4. 生成单个映射器代理
  5. 报告
- **调用 Agents**: `gsd-codebase-mapper`（单个实例）
- **输入**: 代码库
- **产出**: .planning/codebase/ 下 2-4 个文档（取决于焦点）
- **质量门控**: 焦点验证
- **依赖**: 无

---

### 四、执行模式 (Execution Modes)

---

#### 24. autonomous.md

- **目的**: 自主驱动里程碑阶段 -- 所有剩余阶段、通过 --from N/--to N 指定范围、或通过 --only N 指定单个阶段。对每个未完成阶段：discuss -> plan -> execute。仅在明确的用户决策时暂停。
- **触发**: `/gsd-autonomous [--from N] [--to N] [--only N] [--interactive]`
- **步骤**:
  1. 初始化
  2. 发现阶段
  3. 过滤阶段（基于 --from/--to/--only）
  4. 循环每个未完成阶段：discuss -> plan -> execute
  5. 重新读取 ROADMAP.md（捕获动态插入的阶段）
  6. 处理暂停和恢复
- **调用 Agents**: 通过 Skill() 调用 discuss-phase, plan-phase, execute-phase
- **输入**: ROADMAP.md, STATE.md
- **产出**: 所有阶段制品（CONTEXT.md, PLAN.md, SUMMARY.md 等）
- **质量门控**: 用户决策门控、灰色区域接受、阻塞器处理
- **依赖**: new-milestone 或已有 ROADMAP.md
- **特殊模式**: --interactive（discuss 内联，plan+execute 后台）

---

#### 25. manager.md

- **目的**: 从单个终端管理里程碑的交互式命令中心。显示所有阶段的仪表板（带视觉状态），将 discuss 内联分派，plan/execute 作为后台代理分派，每次操作后循环回仪表板。
- **触发**: `/gsd-manager`
- **步骤**:
  1. 初始化
  2. 显示仪表板
  3. 等待用户选择阶段
  4. 根据阶段状态路由（discuss/plan/execute）
  5. 后台代理完成后刷新仪表板
  6. 循环
- **调用 Agents**: 通过 Skill() 调用 discuss-phase, plan-phase, execute-phase
- **输入**: ROADMAP.md, STATE.md
- **产出**: 所有阶段制品
- **质量门控**: 仪表板状态刷新、后台代理监控
- **依赖**: new-milestone 或已有 ROADMAP.md

---

#### 26. quick.md

- **目的**: 使用 GSD 保证（原子提交、STATE.md 跟踪）执行小型临时任务。快速模式生成 gsd-planner（快速模式）+ gsd-executor，在 .planning/quick/ 中跟踪任务。
- **触发**: `/gsd-quick <description> [--full] [--validate] [--discuss] [--research]`
- **步骤**:
  1. 解析参数
  2. 收集任务描述
  3. 可选讨论阶段（--discuss）
  4. 可选研究阶段（--research）
  5. 生成计划器代理（快速模式）
  6. 生成执行器代理
  7. 可选验证（--validate）
  8. 可选代码审查
  9. 更新 STATE.md
- **调用 Agents**: `gsd-phase-researcher`, `gsd-planner`, `gsd-plan-checker`, `gsd-executor`, `gsd-verifier`, `gsd-code-reviewer`
- **输入**: 任务描述
- **产出**: .planning/quick/ 下的计划和摘要, 代码变更, SUMMARY.md
- **质量门控**: 计划检查（--validate 模式）、验证（--validate 模式）、代码审查
- **依赖**: 无
- **特殊模式**: --full（完整质量管道）、--validate（仅计划检查+验证）、--discuss、--research

---

#### 27. fast.md

- **目的**: 内联执行琐碎任务，无子代理开销。无 PLAN.md，无 Task 生成，无研究，无计划检查。只是：理解 -> 做 -> 提交 -> 记录。
- **触发**: `/gsd-fast <task>`
- **步骤**:
  1. 解析任务
  2. 范围检查（<= 3 文件编辑, <= 1 分钟工作）
  3. 内联执行
  4. 原子提交
  5. 记录到 STATE.md
- **调用 Agents**: 无（纯内联）
- **输入**: 任务描述
- **产出**: 代码变更, Git 提交
- **质量门控**: 范围检查（超过 3 文件编辑则重定向到 /gsd-quick）
- **依赖**: 无

---

#### 28. do.md

- **目的**: 分析用户的自由文本并路由到最合适的 GSD 命令。这是调度器 -- 它自己从不做工作。
- **触发**: `/gsd-do <description>`
- **步骤**:
  1. 验证输入
  2. 检查项目是否存在
  3. 匹配意图到命令（基于路由表）
  4. 显示路由决策
  5. 调用选定的命令
- **调用 Agents**: 无（路由到其他命令）
- **输入**: 用户文本描述
- **产出**: 路由到适当的 GSD 命令
- **质量门控**: 意图匹配、歧义处理（询问用户）
- **依赖**: 无

---

### 五、质量与审查 (Quality & Review)

---

#### 29. code-review.md

- **目的**: 审查阶段中更改的源文件的错误、安全问题和代码质量问题。计算文件范围，检查配置门控，生成 gsd-code-reviewer 代理，提交 REVIEW.md。
- **触发**: `/gsd-code-review <N> [--depth=quick|standard|deep] [--files=file1,file2]`
- **步骤**:
  1. 初始化
  2. 检查配置门控
  3. 计算文件范围
  4. 生成代码审查器代理
  5. 提交 REVIEW.md
- **调用 Agents**: `gsd-code-reviewer`
- **输入**: 阶段目录中的源文件, SUMMARY.md, CONTEXT.md
- **产出**: `{padded}-REVIEW.md`
- **质量门控**: 配置门控（workflow.code_review）、深度控制
- **依赖**: execute-phase（SUMMARY.md）
- **特殊模式**: --depth, --files

---

#### 30. code-review-fix.md

- **目的**: 自动修复 REVIEW.md 中的问题。验证阶段，检查配置门控，验证 REVIEW.md 存在且有可修复问题，生成 gsd-code-fixer 代理，处理 --auto 迭代循环（上限 3 次）。
- **触发**: `/gsd-code-review-fix <N> [--all] [--auto]`
- **步骤**:
  1. 初始化
  2. 检查配置门控
  3. 验证 REVIEW.md 存在
  4. 生成代码修复器代理
  5. 可选 --auto 迭代（最多 3 次：修复 -> 重新审查 -> 修复）
  6. 提交 REVIEW-FIX.md
- **调用 Agents**: `gsd-code-fixer`, `gsd-code-reviewer`
- **输入**: REVIEW.md, 源文件
- **产出**: `{padded}-REVIEW-FIX.md`, 代码修复
- **质量门控**: 配置门控、自动迭代上限（3 次）
- **依赖**: code-review（REVIEW.md）
- **特殊模式**: --all, --auto

---

#### 31. review.md

- **目的**: 跨 AI 同行审查 -- 调用外部 AI CLI 独立审查阶段计划。每个 CLI 获得相同的提示并产生结构化反馈。结果合并到 REVIEWS.md 供计划器通过 --reviews 标志合并。
- **触发**: `/gsd-review <N> [--codex] [--gemini] [--claude] [--all]`
- **步骤**:
  1. 检测可用 CLI
  2. 解析标志
  3. 为每个选定的 CLI 生成审查提示
  4. 并行运行外部 AI 审查
  5. 收集结果
  6. 合并到 REVIEWS.md
- **调用 Agents**: 无（调用外部 CLI: gemini, claude, codex, opencode, qwen, cursor, ollama, lm-studio, llama-cpp）
- **输入**: PLAN.md, PROJECT.md, REQUIREMENTS.md, CONTEXT.md
- **产出**: `{padded}-REVIEWS.md`
- **质量门控**: 对抗性审查（不同 AI 模型捕获不同盲点）
- **依赖**: plan-phase（PLAN.md）
- **特殊模式**: --codex, --gemini, --claude, --coderabbit, --opencode, --qwen, --cursor, --ollama, --lm-studio, --llama-cpp, --all

---

#### 32. plan-review-convergence.md

- **目的**: 跨 AI 计划收敛循环 -- 自动化手动链：gsd-plan-phase N -> gsd-review N --codex -> gsd-plan-phase N --reviews -> gsd-review N --codex -> ...
- **触发**: `/gsd-plan-review-convergence <N> [--codex] [--max-cycles N]`
- **步骤**:
  1. 解析参数
  2. 检查配置门控（默认禁用）
  3. 循环（最多 max_cycles 次）：plan-phase -> review -> 检查 HIGH 计数
  4. 停滞检测
  5. 升级处理
- **调用 Agents**: 通过 Skill() 调用 plan-phase, review
- **输入**: 阶段上下文
- **产出**: 收敛的 PLAN.md, REVIEWS.md
- **质量门控**: 配置门控（默认禁用）、HIGH 问题计数、停滞检测
- **依赖**: plan-phase, review

---

#### 33. ui-review.md

- **目的**: 已实现前端代码的回顾性 6 支柱视觉审计。独立命令，适用于任何项目。产生评分的 UI-REVIEW.md。
- **触发**: `/gsd-ui-review <N>`
- **步骤**:
  1. 初始化
  2. 检测输入状态
  3. 生成 UI 审计器代理
  4. 代理执行 6 支柱审计
  5. 生成 UI-REVIEW.md
- **调用 Agents**: `gsd-ui-auditor`
- **输入**: SUMMARY.md, UI-SPEC.md（可选）, 源代码
- **产出**: `{padded}-UI-REVIEW.md`
- **质量门控**: 6 支柱评分
- **依赖**: execute-phase（SUMMARY.md）

---

#### 34. eval-review.md

- **目的**: 已实现 AI 阶段评估覆盖范围的回顾性审计。产生评分的 EVAL-REVIEW.md。
- **触发**: `/gsd-eval-review <N>`
- **步骤**:
  1. 初始化
  2. 检测输入状态（AI-SPEC.md + SUMMARY.md / 仅 SUMMARY.md）
  3. 检查现有 EVAL-REVIEW.md
  4. 生成评估审计器代理
  5. 生成 EVAL-REVIEW.md
- **调用 Agents**: `gsd-eval-auditor`
- **输入**: SUMMARY.md, AI-SPEC.md（可选）
- **产出**: `{padded}-EVAL-REVIEW.md`
- **质量门控**: 评估覆盖评分
- **依赖**: execute-phase（SUMMARY.md）

---

#### 35. validate-phase.md

- **目的**: 审计已完成阶段的 Nyquist 验证差距。生成缺失测试。更新 VALIDATION.md。
- **触发**: `/gsd-validate-phase <N>`
- **步骤**:
  1. 初始化
  2. 检测输入状态
  3. 发现阶段制品
  4. 生成 Nyquist 审计器代理
  5. 更新 VALIDATION.md
- **调用 Agents**: `gsd-nyquist-auditor`
- **输入**: PLAN.md, SUMMARY.md, REQUIREMENTS.md
- **产出**: `{padded}-VALIDATION.md`
- **质量门控**: Nyquist 验证配置门控
- **依赖**: execute-phase（SUMMARY.md）

---

#### 36. secure-phase.md

- **目的**: 验证已完成阶段的威胁缓解。确认 PLAN.md 威胁寄存器处置已解决。更新 SECURITY.md。
- **触发**: `/gsd-secure-phase <N>`
- **步骤**:
  1. 初始化
  2. 检测输入状态
  3. 发现阶段制品
  4. 生成安全审计器代理
  5. 更新 SECURITY.md
- **调用 Agents**: `gsd-security-auditor`
- **输入**: PLAN.md, SUMMARY.md, 威胁模型
- **产出**: `{padded}-SECURITY.md`
- **质量门控**: 安全执行配置门控
- **依赖**: execute-phase（SUMMARY.md）

---

### 六、验证与审计 (Verification & Audit)

---

#### 37. audit-milestone.md

- **目的**: 通过聚合阶段验证、检查跨阶段集成和评估需求覆盖范围来验证里程碑是否达到完成定义。
- **触发**: `/gsd-audit-milestone <version>`
- **步骤**:
  1. 初始化里程碑上下文
  2. 确定里程碑范围
  3. 读取所有阶段验证
  4. 生成集成检查器代理
  5. 收集结果
  6. 检查需求覆盖（3 源交叉引用）
  7. Nyquist 合规发现
  8. 聚合到 MILESTONE-AUDIT.md
  9. 展示结果
- **调用 Agents**: `gsd-integration-checker`
- **输入**: 所有阶段的 VERIFICATION.md, SUMMARY.md, REQUIREMENTS.md
- **产出**: `v{version}-MILESTONE-AUDIT.md`
- **质量门控**: FAIL 门控（任何未满足需求强制 gaps_found 状态）、孤立需求检测、3 源交叉引用
- **依赖**: 所有阶段的 verify-phase

---

#### 38. audit-uat.md

- **目的**: 跨阶段审计所有 UAT 和验证文件。查找每个未完成项目（待处理、跳过、阻塞、需要人工），可选对照代码库验证以检测过时文档。
- **触发**: `/gsd-audit-uat`
- **步骤**:
  1. 运行 CLI 审计
  2. 分类（可立即测试 / 需要前置条件 / 过时）
  3. 展示审计报告
  4. 生成人工 UAT 测试计划
- **调用 Agents**: 无
- **输入**: 所有阶段的 UAT.md, VERIFICATION.md
- **产出**: 审计报告, 人工 UAT 测试计划
- **质量门控**: 过时检测（对照代码库验证）
- **依赖**: 无

---

#### 39. audit-fix.md

- **目的**: 自主审计到修复管道。运行审计，解析发现，分类为可自动修复 vs 仅手动，为可修复问题生成执行器代理，每次修复后运行测试，并原子提交。
- **触发**: `/gsd-audit-fix [--max N] [--severity high|medium|all] [--dry-run]`
- **步骤**:
  1. 解析参数
  2. 运行审计（默认: audit-uat）
  3. 分类发现
  4. 展示分类表
  5. 对每个可自动修复的发现：生成代理 -> 运行测试 -> 提交或回滚
  6. 报告
- **调用 Agents**: `gsd-executor`
- **输入**: UAT.md, VERIFICATION.md
- **产出**: 代码修复, Git 提交（带发现 ID）, 审计修复报告
- **质量门控**: 测试通过门控、失败时停止管道、原子提交带可追溯性
- **依赖**: audit-uat

---

#### 40. add-tests.md

- **目的**: 为已完成阶段生成单元和 E2E 测试。将每个更改的文件分类为 TDD/E2E/Skip，展示测试计划供用户批准，然后生成测试。
- **触发**: `/gsd-add-tests <N> [additional instructions]`
- **步骤**:
  1. 解析参数
  2. 加载阶段制品
  3. 分析实现并分类文件
  4. 展示分类供确认
  5. 发现测试结构
  6. 生成测试计划
  7. 执行 TDD 测试生成
  8. 执行 E2E 测试生成
  9. 摘要和提交
- **调用 Agents**: 无（内联执行）
- **输入**: SUMMARY.md, CONTEXT.md, VERIFICATION.md, 源代码
- **产出**: 测试文件, 覆盖报告, Git 提交
- **质量门控**: 分类确认、测试执行验证、RED-GREEN 约定
- **依赖**: execute-phase（SUMMARY.md）

---

### 七、里程碑生命周期 (Milestone Lifecycle)

---

#### 41. complete-milestone.md

- **目的**: 标记已发布的版本为完成。在 MILESTONES.md 中创建历史记录，执行 PROJECT.md 演变审查，重组 ROADMAP.md，并在 git 中标记发布。
- **触发**: `/gsd-complete-milestone <version>`
- **步骤**:
  1. 预关闭制品审计
  2. 验证就绪状态
  3. 需求完成检查
  4. 归档里程碑制品
  5. 更新 ROADMAP.md
  6. 归档 REQUIREMENTS.md
  7. 执行 PROJECT.md 演变审查
  8. 创建 Git 标签
  9. 可选创建下一里程碑
- **调用 Agents**: 无
- **输入**: ROADMAP.md, REQUIREMENTS.md, PROJECT.md, 所有阶段制品
- **产出**: .planning/milestones/v{X.Y}-ROADMAP.md, .planning/milestones/v{X.Y}-REQUIREMENTS.md, Git 标签
- **质量门控**: 需求完成检查、预关闭制品审计、PROJECT.md 演变审查
- **依赖**: audit-milestone

---

#### 42. milestone-summary.md

- **目的**: 从已完成的里程碑制品生成全面、人性化的项目摘要。为团队入职设计。
- **触发**: `/gsd-milestone-summary [version]`
- **步骤**:
  1. 解析版本
  2. 定位制品
  3. 发现阶段制品
  4. 读取所有制品
  5. 生成摘要
- **调用 Agents**: 无
- **输入**: ROADMAP.md, REQUIREMENTS.md, PROJECT.md, MILESTONE-AUDIT.md, 所有阶段制品
- **产出**: 项目摘要文档
- **质量门控**: 无
- **依赖**: complete-milestone

---

#### 43. plan-milestone-gaps.md

- **目的**: 创建关闭 audit-milestone 识别的差距所需的所有阶段。
- **触发**: `/gsd-plan-milestone-gaps`
- **步骤**:
  1. 加载审计结果
  2. 优先级排序差距
  3. 将差距分组为阶段
  4. 在 ROADMAP.md 中创建阶段条目
  5. 提供计划选项
- **调用 Agents**: 无
- **输入**: MILESTONE-AUDIT.md, REQUIREMENTS.md
- **产出**: 新阶段条目
- **质量门控**: 优先级分组、依赖顺序
- **依赖**: audit-milestone

---

#### 44. graduation.md

- **目的**: LEARNINGS.md 跨阶段毕业助手。聚类重复项目，通过 HITL 表面化晋升候选。（内部工作流）
- **触发**: 由 transition.md 的 graduation_scan 步骤内部调用
- **步骤**:
  1. 守卫检查
  2. 收集 LEARNINGS.md 文件
  3. 按词汇相似性聚类
  4. 表面化晋升候选
  5. 开发者批准
- **调用 Agents**: 无
- **输入**: 最近 N 个阶段的 LEARNINGS.md
- **产出**: 晋升的项目
- **质量门控**: 开发者批准门控
- **依赖**: extract-learnings

---

### 八、状态管理 (State Management)

---

#### 45. progress.md

- **目的**: 检查项目进度，总结最近工作和即将到来的内容，然后智能路由到下一个操作。
- **触发**: `/gsd-progress`
- **步骤**:
  1. 加载上下文
  2. 分析路线图
  3. 生成进度报告
  4. 路由到下一操作
- **调用 Agents**: 无
- **输入**: STATE.md, ROADMAP.md, PROJECT.md
- **产出**: 进度报告, 路由到下一 GSD 命令
- **质量门控**: 无
- **依赖**: 无

---

#### 46. next.md

- **目的**: 检测当前项目状态并自动推进到下一个逻辑 GSD 工作流步骤。
- **触发**: `/gsd-next [--force]`
- **步骤**:
  1. 检测状态
  2. 运行安全门控
  3. 确定下一操作
  4. 路由
- **调用 Agents**: 无
- **输入**: STATE.md, ROADMAP.md
- **产出**: 路由到适当的 GSD 命令
- **质量门控**: 安全门控（未解决的检查点、阻塞器等）
- **依赖**: 无

---

#### 47. resume-project.md

- **目的**: 即时恢复完整项目上下文。
- **触发**: `/gsd-resume-work` 或 "继续"、"下一步"、"我们在哪里"、"恢复"
- **步骤**:
  1. 初始化
  2. 加载状态
  3. 显示项目概览
  4. 路由到下一操作
- **调用 Agents**: 无
- **输入**: STATE.md, PROJECT.md, ROADMAP.md
- **产出**: 项目上下文恢复, 路由建议
- **质量门控**: 无
- **依赖**: 无

---

#### 48. pause-work.md

- **目的**: 创建结构化的交接文件以在会话之间保留完整的工作状态。
- **触发**: `/gsd-pause-work`
- **步骤**:
  1. 检测上下文（阶段/spike/sketch/审议/研究工作）
  2. 收集完整状态
  3. 检查虚假完成
  4. 写入 HANDOFF.json
  5. 写入 .continue-here.md
  6. 提交
- **调用 Agents**: 无
- **输入**: 所有当前工作制品
- **产出**: .planning/HANDOFF.json, .planning/.continue-here.md
- **质量门控**: 虚假完成检查、阻塞约束记录
- **依赖**: 无

---

#### 49. undo.md

- **目的**: 安全的 Git 回滚工作流。使用 git revert --no-commit（从不使用 git reset）以保留历史。
- **触发**: `/gsd-undo --last N | --phase NN | --plan NN-MM`
- **步骤**:
  1. 解析参数
  2. 收集候选提交
  3. 依赖检查
  4. 确认门控
  5. 执行 git revert --no-commit
  6. 提交
- **调用 Agents**: 无
- **输入**: Git 历史, 阶段清单
- **产出**: Git revert 提交
- **质量门控**: 依赖检查、确认门控
- **依赖**: 无

---

#### 50. thread.md

- **目的**: 创建、列出、关闭或恢复持久上下文线程。
- **触发**: `/gsd-thread [list|close <slug>|status <slug>|<description>]`
- **步骤**:
  1. 解析参数确定模式
  2. LIST/CLOSE/STATUS/RESUME/CREATE 模式处理
- **调用 Agents**: 无
- **输入**: .planning/threads/*.md
- **产出**: 线程文件
- **质量门控**: slug 消毒、文件名安全
- **依赖**: 无

---

### 九、捕获与组织 (Capture & Organization)

---

#### 51. add-todo.md

- **目的**: 在 GSD 会话中出现的想法、任务或问题捕获为结构化待办事项。
- **触发**: `/gsd-add-todo [description]` 或 `/gsd-capture --todo`
- **步骤**: 加载上下文 -> 提取内容 -> 推断区域 -> 检查重复 -> 创建文件 -> 更新状态 -> Git 提交
- **调用 Agents**: 无
- **输入**: 会话上下文
- **产出**: `.planning/todos/pending/{date}-{slug}.md`
- **质量门控**: 重复检查
- **依赖**: 无

---

#### 52. check-todos.md

- **目的**: 列出所有待处理的待办事项，允许选择，加载上下文，并路由到适当的操作。
- **触发**: `/gsd-capture --list [area]`
- **步骤**: 加载上下文 -> 解析过滤器 -> 列出待办事项 -> 处理选择 -> 加载上下文 -> 检查路线图匹配 -> 提供操作选项
- **调用 Agents**: 无
- **输入**: .planning/todos/pending/*.md
- **产出**: 待办事项列表, 操作路由
- **质量门控**: 无
- **依赖**: 无

---

#### 53. note.md

- **目的**: 零摩擦想法捕获。一次 Write 调用，一行确认。
- **触发**: `/gsd-note <text> | list | promote <N> [--global]`
- **步骤**: 确定存储格式 -> 解析子命令 -> APPEND/LIST/PROMOTE
- **调用 Agents**: 无
- **输入**: 笔记文本
- **产出**: `.planning/notes/{YYYY-MM-DD}-{slug}.md` 或 `~/.claude/notes/`
- **质量门控**: 无
- **依赖**: 无

---

#### 54. plant-seed.md

- **目的**: 将前瞻性想法捕获为带有触发条件的结构化种子文件。种子在 new-milestone 期间自动匹配。
- **触发**: `/gsd-plant-seed <idea> [--enrich SEED-NNN]`
- **步骤**: 解析想法 -> 创建目录 -> 生成 ID -> 写入种子 -> 收集面包屑 -> 提交
- **调用 Agents**: 无
- **输入**: 想法文本
- **产出**: `.planning/seeds/SEED-{NNN}-{slug}.md`
- **质量门控**: 一次性捕获
- **依赖**: 无

---

#### 55. explore.md

- **目的**: 苏格拉底式创意工作流。通过探索性问题引导开发者探索想法，然后将结晶输出路由到 GSD 制品。
- **触发**: `/gsd-explore [topic]`
- **步骤**: 开始对话 -> 苏格拉底式对话（2-5 轮）-> 中途研究 -> 结晶输出 -> 写入选定输出 -> 关闭
- **调用 Agents**: `gsd-phase-researcher`（可选）
- **输入**: 主题描述
- **产出**: 笔记、待办事项、种子、研究问题、需求、新阶段（最多 4 个）
- **质量门控**: 用户明确选择要创建的输出
- **依赖**: 无

---

#### 56. import.md

- **目的**: 外部计划摄入，带冲突检测。
- **触发**: `/gsd-import --from <path>`
- **步骤**: 解析参数 -> 验证路径 -> 检测模式 -> 读取外部计划 -> 冲突检测 -> 写入 PLAN.md -> 验证
- **调用 Agents**: `gsd-plan-checker`
- **输入**: 外部计划文件
- **产出**: PLAN.md
- **质量门控**: 路径安全验证、冲突检测、计划检查器验证
- **依赖**: 无

---

#### 57. ingest-docs.md

- **目的**: 扫描仓库中的混合规划文档（ADR、PRD、SPEC、DOC），综合为统一上下文。
- **触发**: `/gsd-ingest-docs [path] [--mode new|merge]`
- **步骤**: 解析参数 -> 初始化 -> 扫描文档 -> 分类 -> 综合 -> 写入 .planning/
- **调用 Agents**: 无
- **输入**: 仓库中的文档文件
- **产出**: .planning/ 制品
- **质量门控**: 路径安全验证
- **依赖**: 无

---

### 十、文档 (Documentation)

---

#### 58. docs-update.md

- **目的**: 生成、更新和验证所有项目文档。编排并行文档写入器和验证器代理。
- **触发**: `/gsd-docs-update`
- **步骤**: 加载上下文 -> 分类项目 -> 构建队列 -> 检查现有 -> 分派写入器 -> 分派验证器 -> 修复循环 -> 提交
- **调用 Agents**: `gsd-doc-writer`, `gsd-doc-verifier`
- **输入**: 代码库, 现有文档
- **产出**: README.md, ARCHITECTURE.md, GETTING-STARTED.md 等（最多 9 个文档）
- **质量门控**: 文档验证器、修复循环上限（3 次）
- **依赖**: 无

---

#### 59. extract-learnings.md

- **目的**: 从已完成的阶段制品中提取决策、经验教训、模式和意外。
- **触发**: `/gsd-extract-learnings <N>`
- **步骤**: 初始化 -> 收集制品 -> 提取学习（4 类）-> 写入 LEARNINGS.md
- **调用 Agents**: 无
- **输入**: PLAN.md, SUMMARY.md, VERIFICATION.md, UAT.md, STATE.md
- **产出**: `{padded}-LEARNINGS.md`
- **质量门控**: 来源归因
- **依赖**: execute-phase（SUMMARY.md）

---

#### 60. session-report.md

- **目的**: 生成会话后摘要文档。
- **触发**: `/gsd-session-report`
- **步骤**: 收集会话数据 -> 估计使用量 -> 生成报告 -> 显示结果
- **调用 Agents**: 无
- **输入**: STATE.md, Git 日志, 计划/摘要文件
- **产出**: `.planning/reports/SESSION_REPORT.md`
- **质量门控**: 无
- **依赖**: 无

---

### 十一、基础设施 (Infrastructure)

---

#### 61. settings.md

- **目的**: 交互式配置 GSD 工作流代理和模型配置文件选择。
- **触发**: `/gsd-settings`
- **步骤**: 确保并加载配置 -> 读取当前值 -> 展示设置 -> 交互式更新 -> 可选保存全局默认值
- **调用 Agents**: 无
- **输入**: .planning/config.json
- **产出**: 更新的 config.json, 可选 ~/.gsd/defaults.json
- **质量门控**: 无
- **依赖**: 无

---

#### 62. settings-advanced.md

- **目的**: 交互式配置 GSD 高级用户旋钮（计划弹跳、节点修复、子代理超时、跨 AI 执行等）。
- **触发**: `/gsd-settings-advanced`
- **步骤**: 确保并加载配置 -> 读取当前值 -> 分 7 个部分展示 -> 交互式更新
- **调用 Agents**: 无
- **输入**: .planning/config.json
- **产出**: 更新的 config.json
- **质量门控**: 数值输入验证
- **依赖**: 无

---

#### 63. settings-integrations.md

- **目的**: 交互式配置第三方集成（搜索 API 密钥、代码审查 CLI 路由、代理技能注入）。
- **触发**: `/gsd-settings-integrations`
- **步骤**: 确保并加载配置 -> 读取当前值 -> 展示集成设置 -> 交互式更新
- **调用 Agents**: 无
- **输入**: .planning/config.json
- **产出**: 更新的 config.json
- **质量门控**: API 密钥掩码、slug 验证
- **依赖**: 无

---

#### 64. cleanup.md

- **目的**: 将已完成里程碑的阶段目录归档到 .planning/milestones/v{X.Y}-phases/。
- **触发**: `/gsd-cleanup`
- **步骤**: 识别里程碑 -> 确定成员 -> 干运行 -> 确认 -> 归档 -> 提交
- **调用 Agents**: 无
- **输入**: MILESTONES.md, 阶段目录
- **产出**: .planning/milestones/v{X.Y}-phases/
- **质量门控**: 干运行确认
- **依赖**: complete-milestone

---

#### 65. health.md

- **目的**: 验证 .planning/ 目录完整性并报告可操作的问题。可选修复。
- **触发**: `/gsd-health [--repair] [--backfill] [--context]`
- **步骤**: 解析参数 -> 上下文检查 / 完整性验证 -> 修复 / 回填
- **调用 Agents**: 无
- **输入**: .planning/ 目录
- **产出**: 健康报告, 可选修复
- **质量门控**: 无
- **依赖**: 无

---

#### 66. update.md

- **目的**: 通过 npm 检查 GSD 更新，显示变更日志，获取确认，并执行更新。
- **触发**: `/gsd-update [--reapply]`
- **步骤**: 获取版本 -> 检查更新 -> 显示变更日志 -> 确认 -> 执行更新 -> 清除缓存
- **调用 Agents**: 无
- **输入**: npm 注册表
- **产出**: 更新的 GSD 安装
- **质量门控**: 用户确认
- **依赖**: 无

---

#### 67. sync-skills.md

- **目的**: 跨运行时同步托管的 gsd-* 技能目录。
- **触发**: `/gsd-sync-skills --from <runtime> --to <runtime|all> [--dry-run] [--apply]`
- **步骤**: 解析参数 -> 验证运行时 -> 计算差异 -> 干运行 -> 应用
- **调用 Agents**: 无
- **输入**: 源运行时技能目录
- **产出**: 同步的技能目录
- **质量门控**: 干运行（默认）
- **依赖**: 无

---

#### 68. help.md

- **目的**: 显示完整的 GSD 命令参考。
- **触发**: `/gsd-help`
- **步骤**: 显示命令参考
- **调用 Agents**: 无
- **输入**: 无
- **产出**: 命令参考文本
- **质量门控**: 无
- **依赖**: 无

---

#### 69. stats.md

- **目的**: 显示全面的项目统计信息。
- **触发**: `/gsd-stats`
- **步骤**: 收集统计信息 -> 展示 -> MVP 摘要
- **调用 Agents**: 无
- **输入**: STATE.md, ROADMAP.md, Git 历史
- **产出**: 统计信息展示
- **质量门控**: 无
- **依赖**: 无

---

### 十二、调试 (Debugging)

---

#### 70. debug.md

- **目的**: 使用科学方法进行系统性调试，带子代理隔离。
- **触发**: `/gsd-debug <description> | continue <slug> | list | status <slug>`
- **步骤**: 初始化 -> LIST/STATUS/CONTINUE/默认模式处理
- **调用 Agents**: `gsd-debug-session-manager`, `gsd-debugger`
- **输入**: 问题描述, 代码库
- **产出**: .planning/debug/{slug}.md, 代码修复
- **质量门控**: 科学方法（假设 -> 测试 -> 验证）
- **依赖**: 无

---

#### 71. diagnose-issues.md

- **目的**: 编排并行调试代理调查 UAT 差距并找到根本原因。
- **触发**: 由 verify-work 在 UAT 发现差距后调用
- **步骤**: 解析差距 -> 报告计划 -> 为每个差距生成调试代理 -> 收集结果 -> 更新 UAT.md
- **调用 Agents**: `gsd-debugger`（每个差距一个）
- **输入**: UAT.md 差距
- **产出**: 更新的 UAT.md（带诊断）
- **质量门控**: 先诊断后规划
- **依赖**: verify-work（UAT.md 差距）

---

#### 72. forensics.md

- **目的**: 失败或卡住的 GSD 工作流的事后调查。（只读调查）
- **触发**: `/gsd-forensics [description]`
- **步骤**: 获取问题描述 -> 收集证据（Git/规划状态/阶段制品/会话报告）-> 分析异常 -> 生成报告
- **调用 Agents**: 无
- **输入**: Git 历史, .planning/ 制品
- **产出**: 诊断报告
- **质量门控**: 只读（不修改项目文件）
- **依赖**: 无

---

#### 73. node-repair.md

- **目的**: 失败任务验证的自主修复操作符。由 execute-plan 内部调用。
- **触发**: 由 execute-plan 内部调用
- **步骤**: 诊断 -> 选择策略（RETRY/DECOMPOSE/PRUNE/ESCALATE）-> 执行修复 -> 验证 -> 升级
- **调用 Agents**: 无（内联）
- **输入**: 失败任务、错误、计划上下文
- **产出**: 修复结果
- **质量门控**: 修复预算（默认 2 次）、升级门控
- **依赖**: execute-plan

---

### 十三、研究与探索 (Research & Exploration)

---

#### 74. spike.md

- **目的**: 通过体验式探索来验证想法可行性。
- **触发**: `/gsd-spike <idea> | frontier [--quick]`
- **步骤**: 设置目录 -> 定义范围 -> 运行实验 -> 记录结果 -> 更新 MANIFEST.md
- **调用 Agents**: 无
- **输入**: 想法描述
- **产出**: .planning/spikes/SPIKE-{NNN}/, README.md, 代码实验
- **质量门控**: 验证/失败裁决
- **依赖**: 无

---

#### 75. spike-wrap-up.md

- **目的**: 将 spike 实验发现打包为持久的项目技能。
- **触发**: `/gsd-spike --wrap-up`
- **步骤**: 收集清单 -> 自动包含 -> 提取发现 -> 写入技能 -> 写入摘要
- **调用 Agents**: 无
- **输入**: .planning/spikes/
- **产出**: .claude/skills/spike-findings-{project}/, WRAP-UP-SUMMARY.md
- **质量门控**: 无
- **依赖**: spike

---

#### 76. sketch.md

- **目的**: 通过一次性 HTML 模型探索设计方向。
- **触发**: `/gsd-sketch <idea> | frontier [--quick]`
- **步骤**: 设置目录 -> 定义设计问题 -> 生成 2-3 个 HTML 变体 -> 比较选择 -> 记录获胜者
- **调用 Agents**: 无
- **输入**: 设计想法
- **产出**: .planning/sketches/SKETCH-{NNN}/, index.html, README.md
- **质量门控**: 变体比较、获胜者选择
- **依赖**: 无

---

#### 77. sketch-wrap-up.md

- **目的**: 策展 sketch 设计发现并打包为持久技能。
- **触发**: `/gsd-sketch --wrap-up`
- **步骤**: 收集清单 -> 逐个策展 -> 提取决策 -> 写入技能 -> 写入摘要
- **调用 Agents**: 无
- **输入**: .planning/sketches/
- **产出**: .claude/skills/sketch-findings-{project}/, WRAP-UP-SUMMARY.md
- **质量门控**: 逐个策展确认
- **依赖**: sketch

---

#### 78. analyze-dependencies.md

- **目的**: 分析 ROADMAP.md 阶段的依赖关系，检测文件重叠和语义依赖。
- **触发**: `/gsd-analyze-dependencies`
- **步骤**: 加载 ROADMAP -> 推断文件修改 -> 检测依赖 -> 构建依赖表 -> 总结 -> 确认并应用
- **调用 Agents**: 无
- **输入**: ROADMAP.md
- **产出**: 更新的 ROADMAP.md（Depends on 字段）
- **质量门控**: 用户确认
- **依赖**: 无

---

### 十四、工作区管理 (Workspace Management)

---

#### 79. new-workspace.md

- **目的**: 创建带有 Git 仓库副本和独立 .planning/ 的隔离工作区目录。
- **触发**: `/gsd-new-workspace --name <name> [--repos <repo1,repo2>] [--strategy worktree|clone]`
- **步骤**: 设置 -> 解析参数 -> 选择仓库 -> 选择策略 -> 创建工作区 -> 初始化 .planning/
- **调用 Agents**: 无
- **输入**: 仓库路径
- **产出**: ~/gsd-workspaces/{name}/, 工作树/克隆, .planning/
- **质量门控**: 仓库存在性验证
- **依赖**: 无

---

#### 80. remove-workspace.md

- **目的**: 删除 GSD 工作区，清理 Git 工作树。
- **触发**: `/gsd-remove-workspace <name>`
- **步骤**: 设置 -> 安全检查 -> 确认 -> 清理工作树 -> 删除目录
- **调用 Agents**: 无
- **输入**: 工作区名称
- **产出**: 删除的工作区
- **质量门控**: 脏仓库检查、确认
- **依赖**: 无

---

#### 81. list-workspaces.md

- **目的**: 列出所有 GSD 工作区及其状态。
- **触发**: `/gsd-list-workspaces`
- **步骤**: 设置 -> 显示工作区表
- **调用 Agents**: 无
- **输入**: ~/gsd-workspaces/
- **产出**: 工作区列表
- **质量门控**: 无
- **依赖**: 无

---

### 十五、PR 与发布 (PR & Shipping)

---

#### 82. pr-branch.md

- **目的**: 通过过滤 .planning/ 提交创建干净的 PR 分支。
- **触发**: `/gsd-pr-branch [target-branch]`
- **步骤**: 检测状态 -> 分析提交 -> 分类 -> 重建干净历史 -> 创建 PR 分支
- **调用 Agents**: 无
- **输入**: Git 历史, 当前分支
- **产出**: 干净的 PR 分支
- **质量门控**: 依赖检查
- **依赖**: 无

---

#### 83. ship.md

- **目的**: 从完成的阶段/里程碑工作创建拉取请求。
- **触发**: `/gsd-ship <N>`
- **步骤**: 初始化 -> 预飞检查 -> 生成 PR 主体 -> 可选代码审查 -> 创建 PR
- **调用 Agents**: 无
- **输入**: 阶段制品, Git 历史
- **产出**: GitHub PR
- **质量门控**: 预飞检查（验证通过、干净工作树、正确分支）
- **依赖**: verify-phase（VERIFICATION.md）

---

#### 84. reapply-patches.md

- **目的**: GSD 更新后将用户本地修改合并回新版本。使用三方比较。
- **触发**: `/gsd-update --reapply`
- **步骤**: 检测补丁 -> 三方比较 -> 分类差异 -> 应用自定义 -> 处理冲突
- **调用 Agents**: 无
- **输入**: gsd-local-patches/, 新安装的文件
- **产出**: 合并的文件
- **质量门控**: 三方比较、冲突检测
- **依赖**: update

---

### 十六、用户画像 (User Profiling)

---

#### 85. profile-user.md

- **目的**: 编排完整的开发者画像流程。
- **触发**: `/gsd-profile-user [--questionnaire] [--refresh]`
- **步骤**: 初始化 -> 检查现有 -> 会话分析/问卷 -> 生成画像 -> 显示结果 -> 创建制品
- **调用 Agents**: `gsd-user-profiler`
- **输入**: 会话历史, 用户问卷
- **产出**: ~/.claude/get-shit-done/USER-PROFILE.md
- **质量门控**: 用户同意
- **依赖**: 无

---

### 十七、其他 (Miscellaneous)

---

#### 86. list-phase-assumptions.md

- **目的**: 在规划前表面化 Claude 对阶段的假设，使用户能够早期纠正误解。纯对话，无文件输出。
- **触发**: `/gsd-list-phase-assumptions <N>`
- **步骤**: 验证阶段 -> 分析（5 个领域）-> 展示假设 -> 收集反馈 -> 提供下一步
- **调用 Agents**: 无
- **输入**: ROADMAP.md, 项目上下文
- **产出**: 假设列表（纯对话）
- **质量门控**: 置信度标记
- **依赖**: 无

---

## 依赖关系图

```
new-project / new-milestone
    |
    v
discuss-phase (CONTEXT.md)
    |
    +---> spec-phase (SPEC.md) [可选]
    +---> ui-phase (UI-SPEC.md) [可选, 前端]
    +---> ai-integration-phase (AI-SPEC.md) [可选, AI]
    |
    v
plan-phase (PLAN.md)
    |
    +---> review (REVIEWS.md) [可选]
    +---> plan-review-convergence [可选]
    |
    v
execute-phase (SUMMARY.md)
    |
    +---> code-review (REVIEW.md) [可选]
    +---> code-review-fix [可选]
    +---> ui-review (UI-REVIEW.md) [可选]
    +---> eval-review (EVAL-REVIEW.md) [可选]
    +---> validate-phase (VALIDATION.md) [可选]
    +---> secure-phase (SECURITY.md) [可选]
    +---> add-tests [可选]
    |
    v
verify-phase (VERIFICATION.md)
    |
    v
verify-work (UAT.md)
    |
    +---> diagnose-issues [如有差距]
    +---> audit-fix [可选]
    |
    v
transition -> 下一阶段
    |
    v
audit-milestone (MILESTONE-AUDIT.md)
    |
    +---> plan-milestone-gaps [如有差距]
    |
    v
complete-milestone
    |
    v
new-milestone (下一里程碑)
```

---

## 代理依赖矩阵

| 代理 | 被哪些工作流使用 |
|------|-----------------|
| gsd-project-researcher | new-project, new-milestone |
| gsd-research-synthesizer | new-project, new-milestone |
| gsd-roadmapper | new-project, new-milestone |
| gsd-phase-researcher | plan-phase, quick, explore |
| gsd-pattern-mapper | plan-phase |
| gsd-planner | plan-phase, quick, verify-work |
| gsd-plan-checker | plan-phase, quick, import, verify-work |
| gsd-executor | execute-phase, execute-plan, audit-fix, quick |
| gsd-verifier | execute-phase, quick |
| gsd-code-reviewer | execute-phase, code-review, quick |
| gsd-code-fixer | code-review-fix |
| gsd-integration-checker | audit-milestone |
| gsd-nyquist-auditor | validate-phase |
| gsd-security-auditor | secure-phase |
| gsd-ui-researcher | ui-phase |
| gsd-ui-checker | ui-phase |
| gsd-ui-auditor | execute-phase, ui-review |
| gsd-framework-selector | ai-integration-phase |
| gsd-ai-researcher | ai-integration-phase |
| gsd-domain-researcher | ai-integration-phase |
| gsd-eval-planner | ai-integration-phase |
| gsd-eval-auditor | eval-review |
| gsd-debugger | debug, diagnose-issues |
| gsd-debug-session-manager | debug |
| gsd-codebase-mapper | map-codebase, scan |
| gsd-doc-writer | docs-update |
| gsd-doc-verifier | docs-update |
| gsd-user-profiler | profile-user |
| gsd-assumptions-analyzer | discuss-phase-assumptions |

---

## 统计摘要

| 指标 | 值 |
|------|-----|
| 工作流总数 | 87 |
| 独立用户命令 | ~65 |
| 内部工作流 | ~5 (transition, graduation, node-repair, execute-plan, discovery-phase) |
| 使用的代理类型 | 28 |
| 最大代理并行度 | 4 (map-codebase 的 4 个并行映射器) |
| 最复杂工作流 | execute-phase (82.9K), plan-phase (76.8K), quick (47.8K) |
| 最简单工作流 | list-workspaces (1.2K), stats (2.2K), fast (2.6K) |
