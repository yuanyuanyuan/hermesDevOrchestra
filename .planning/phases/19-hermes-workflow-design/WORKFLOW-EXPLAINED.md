---
date: 2026-05-10
topic: hermes-workflow-design
---

# 业务流程深度叙事版（含对白、心理活动、具体指令）

> 本文档为 `DESIGN.md` + `REQUIREMENTS.md` 中定义的全部业务流程提供**沉浸式叙事版本**。
> 每个步骤包含：**用户心理活动**、**用户与系统的对白**、**AI Agent 的内心独白**、**执行的具体命令/指令**。
> 目的：让用户（CEO/Jacky）能够以"身临其境"的方式审核每个细节是否符合真实工作场景。
>
> 由于完整叙事篇幅较长（约 4,500 行），本文档按 **Phase / 附录** 拆分为多个子文件。以下提供目录索引，你可按需跳转阅读。

---

## 关于本文档的能力来源标注

本文档描述的系统能力分为三类，用方括号标注在相关段落旁：

- **`[Hermes 官方]`** — Hermes Agent v0.13.0 原生支持的能力。可直接使用，无需增量开发。
- **`[Phase 19 增量]`** — 本工作（Phase 19）计划通过 Plugin/Skill/SOUL.md 等扩展点新增的能力。需要工程实现，详见 `REQUIREMENTS.md` R3-R24。
- **`[设计假设]`** — 文档为叙事流畅性假设的行为或性能特征，尚未有代码级验证。可能随实现调整。

> **官方背书：** Hermes RFC #16102 明确将 "approval gates" 列为 v1 不实现的功能，鼓励通过 plugins 或 profile conventions 在 user-space 构建。本设计的 L1/L2/L3 风险分级、Risk Policy Engine 属于此范畴。

> **注意**：叙事中 AI Agent 的行为在多数场景下展示为"理想执行"。真实的 LLM 会出现遗漏、误判和过度自信。详见 **附录 D：AI 失败模式** 和 **附录 E：人的真实反应**。

---

## 场景设定

**人物：**
- **Jacky**（你）：一人公司 CEO，懂技术但时间有限，同时管理 5-6 个项目
- **PM**（AI 项目经理）：负责需求分析、技术研判、任务拆解与派发
- **Orchestrator**（AI 中枢路由器）：负责任务派发、进度监控、消息路由（不做分析/拆解）
- **Researcher**（AI 技术调研员）：按需唤醒，负责技术方案调研，不写代码
- **Implementer**（AI 开发工程师）：负责 TDD 编码（RED→GREEN 循环）、回归测试、POC 验证
- **Tech-Reviewer**（AI 技术审查员）：负责审查代码安全性、规范性（硬门禁 + 只读）
- **QA-Tester**（AI 测试员）：负责跑测试用例、功能验收
- **DevOps-Engineer**（AI 发布工程师）：负责三层部署（dev/test→staging→production）、验证门控、UAT 配合、自动回滚、git tag
- **SRE-Observer**（AI 可观测性工程师）：负责故障根因分析（仅人工升级触发）

**项目：** Project Alpha —— 一个 SaaS 产品的后端服务，技术栈：Rust + Axum + PostgreSQL

**当前上下文：**
- Alpha 项目已有一个基础的 Kanban Board
- 已有用户管理模块（登录/注册）
- **新需求**：用户反馈"每次重启浏览器都要重新登录，体验很差"——Jacky 只给了这一句话

---

## 目录索引

### 主流程（按 Phase 顺序）

| Phase | 标题 | 文件 | 行数 | 核心内容 |
|-------|------|------|------|----------|
| 1 | 需求提交与澄清（PM） | [`workflow-phase-01-requirements.md`](./workflow-phase-01-requirements.md) | ~1050 | Jacky 提交模糊需求、多需求优先级排序、按需技术发现（与澄清交织）、动态顺序一次一问逐步收缩澄清（含推荐标签/大白话理由/其他选项/追加轮次/收敛上限）、持续可行性检查+冲突沟通+阻塞升级、崩溃恢复（comments 保存进度）+异步澄清、DoR 验证门、Jacky 显式确认+收敛修改限制+需求版本控制+质量反馈、Reviewer/QA 交叉校正、生成含证据链的标准化需求文档 |
| 1.5 | Research + POC（Researcher） | *(内嵌于 Phase 1-2 之间)* | ~100 | PM 发起技术调研任务、Researcher 产出技术方案文档（含 POC 验证）、PM 拿到方案后进入任务拆解 |
| 2 | 任务拆解（PM） + 派发（Orchestrator） | [`workflow-phase-02-orchestrator.md`](./workflow-phase-02-orchestrator.md) | ~360 | PM 读取需求文档+技术方案、拆分为 6 个子任务、Orchestrator 按状态机路由派发、Jacky 确认任务图 |
| 3 | 执行（Implementer） | [`workflow-phase-03-implementation.md`](./workflow-phase-03-implementation.md) | ~740 | Implementer 被唤醒、建立上下文、编写 JWT 核心逻辑和测试、发送心跳 |
| 4 | 测试 + 审查（并行） | [`workflow-phase-04-testing-review.md`](./workflow-phase-04-testing-review.md) | ~975 | Tech-Reviewer 并行审查代码安全性；Implementer 同时执行 T2（HTTP 接口）；发现 L3 拦截事件 |
| 5 | 修复 + 自我进化 | [`workflow-phase-05-fix-evolution.md`](./workflow-phase-05-fix-evolution.md) | ~1000 | T3 测试用例编写、T5 修复审查问题、记录经验教训 Skill、部署失败触发 SRE-Observer 调查 |
| 5.6 | 部署发布（三层环境） | *(内嵌于 ascii-end-to-end.md)* | ~200 | DevOps-Engineer 三层部署（dev/test→staging→production）、验证门控（测试+E2E+性能）、UAT 用户验收、自动回滚+阻塞、git tag |
| 6 | 完成通知 + 用户审核决策 | [`workflow-phase-06-completion.md`](./workflow-phase-06-completion.md) | ~310 | Project Alpha 全部任务完成、Jacky 审核决策、合并到 main、最终反思 |

### 附录

| 附录 | 标题 | 文件 | 行数 | 核心内容 |
|------|------|------|------|----------|
| A | 其他核心流程的叙事化版本 | [`workflow-appendix-roles.md`](./workflow-appendix-roles.md) | ~300 | 多项目管理、紧急 Bug 修复、新成员 onboarding 的叙事场景 |
| B | 关键设计决策的叙事化讨论 | [`workflow-appendix-decisions.md`](./workflow-appendix-decisions.md) | ~135 | SRE-Observer 为何独立、Reviewer 只读终端、SOUL.md vs AGENTS.md 分工 |
| C | 全流程时间线 `[设计假设]` | [`workflow-appendix-timeline.md`](./workflow-appendix-timeline.md) | ~32 | 从需求提交到部署完成的完整时间线（含并行事件标注） |
| D | AI 失败模式 | [`workflow-appendix-failure-modes.md`](./workflow-appendix-failure-modes.md) | ~270 | 6 个 AI 角色各 1-2 种典型失败行为、后果、兜底机制 |
| E | 人的真实反应 | [`workflow-appendix-human-reactions.md`](./workflow-appendix-human-reactions.md) | ~240 | 延迟响应、信息过载、情绪疲劳、技术盲区、通知疲劳 5 个真实场景 |

---

## 如何阅读本文档

**如果你刚接触这个工作流**：
1. 先读 **Phase 1 → Phase 2 → Phase 3**，理解需求如何变成可执行的任务
2. 重点看 **Phase 4 的 L3 拦截事件**（Step 4.10），这是 Risk Policy Engine 的核心价值展示
3. 扫读 **附录 D** 和 **附录 E**，校准对 AI 和人类行为的预期

**如果你要验证某个具体需求**：
- 需求 R1-R2（Phase 0 平台能力确认）→ Phase 2 + Phase 3
- 需求 R3-R8（真增量工程）→ Phase 4（L3 拦截 = R6/R8）、Phase 5（背压 = R5、worktree 回收 = R4）
- 需求 R9-R18（SOUL.md / Skill 行为契约）→ Phase 3、Phase 5 Step 5.4
- 需求 R19-R24（可观测性）→ Phase 5.5（SRE-Observer）、Phase 4 Step 4.5

**如果你要审计技术准确性**：
- 每个子文件中的 `[Hermes 官方]` 标注段落已通过 `archive/VALIDATION-REPORT.md` 与 Hermes v0.13.0 官方文档交叉核对
- `[Phase 19 增量]` 标注段落的可行性详见 `archive/FEASIBILITY-REPORT.md`
- `[设计假设]` 标注段落为叙事需要，非技术承诺

---

*本文档为索引文件。完整叙事内容分布在上述 11 个子文件中。*
