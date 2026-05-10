---
date: 2026-05-10
topic: hermes-workflow-design
---

# 业务流程 ASCII 流程图全集

> 本文档为 `DESIGN.md` + `REQUIREMENTS.md` 中定义的全部业务流程提供 ASCII 流程图。
> 每个图包含：参与者、流程步骤、判断分支、数据流向。
>
> 由于完整内容篇幅较长（约 2,200+ 行），本文档按 **章节主题** 拆分为多个子文件。以下提供目录索引，你可按需跳转阅读。

---

## 目录索引

### 核心流程与端到端示例

| 章节 | 文件 | 行数 | 包含的 ASCII 图 |
|------|------|------|----------------|
| 一、核心业务流程（F1–F4） | [`ascii-core-flows.md`](./ascii-core-flows.md) | ~367 | F0 Phase 0 平台能力确认、F2 多项目并行任务生命周期（含背压）、F3 L3 风险升级与用户决策、F4 自动故障检测与根因分析 |
| 八、端到端完整示例 | [`ascii-end-to-end.md`](./ascii-end-to-end.md) | ~399 | Phase 1-2 需求提交→澄清→拆解、Phase 3 执行、Phase 4 测试+审查、Phase 5 修复+进化、Phase 5.5 故障场景→SRE-Observer、Phase 6 完成通知 |

### 子系统流程

| 章节 | 文件 | 行数 | 包含的 ASCII 图 |
|------|------|------|----------------|
| 二、Kanban 任务管理 | [`ascii-kanban-subflows.md`](./ascii-kanban-subflows.md) | ~349 | 任务状态机流转、任务依赖链（parents）、Dispatcher 工作循环、Handoff 机制、Worker 崩溃状态回滚、背压感知任务准入 |
| 三、实时通信 | [`ascii-communication-subflows.md`](./ascii-communication-subflows.md) | ~195 | 实时问答流程（tmux 方式）、Agent 间通信可靠性方案（推荐 A）、Tmux Session 预热池 |
| 四、决策矩阵 | [`ascii-decision-matrix.md`](./ascii-decision-matrix.md) | ~146 | L3 升级流程（完整路径）、声明式风险策略引擎 |
| 五、多项目并行管理 | [`ascii-multi-project.md`](./ascii-multi-project.md) | ~77 | 跨项目经验共享 |
| 六、自我进化 | [`ascii-self-evolution.md`](./ascii-self-evolution.md) | ~227 | 三层架构（知识资产管理）、实时层进化、定期层进化（Curator 自动审查）、分层经验归档 |
| 七、全链路可观测性 | [`ascii-observability.md`](./ascii-observability.md) | ~258 | Observability Plugin 零侵入采集、SRE-Observer 人工升级触发与分析、故障定位 8 层模型 |

### 总览与速查

| 章节 | 文件 | 行数 | 内容 |
|------|------|------|------|
| 九、流程全景图 + 十、角色职责速查表 + 附录 | [`ascii-overview.md`](./ascii-overview.md) | ~225 | 完整系统架构全景 ASCII 图、8 角色职责矩阵（pm, orchestrator, researcher, implementer, tech-reviewer, qa-tester, devops-engineer, sre-observer）、30+ 流程编号索引 |

---

## 如何阅读本文档

**如果你需要验证某个具体需求**：
- R1-R2（Phase 0 平台能力确认）→ **核心业务流程** F0
- R3（Profile Override）→ **Kanban 子流程** Dispatcher 工作循环
- R4（Worktree 回收）→ **Kanban 子流程** Worker 崩溃状态回滚
- R5（Backpressure）→ **核心业务流程** F2、**Kanban 子流程** 背压感知任务准入
- R6-R7（Risk Policy / Memory 命名空间）→ **决策矩阵** L3 升级流程、声明式风险策略引擎
- R8（Reviewer 只读终端）→ **端到端示例** Phase 4
- R9-R18（SOUL.md / Skill 契约）→ **自我进化** 三层架构、实时/定期层进化
- R19-R24（Observability / SRE-Observer）→ **可观测性** 全部、**核心业务流程** F4

**如果你需要向他人展示系统全貌**：
- 先看 **ascii-overview.md** 的「流程全景图」和「角色职责速查表」
- 再按需深入具体章节的 ASCII 图

**如果你正在实现某个子系统**：
- 实现 Dispatcher → **Kanban 子流程** 全部
- 实现 Risk Policy Engine → **决策矩阵** 全部 + **核心业务流程** F3
- 实现 Observability Plugin → **可观测性** 全部 + **核心业务流程** F4
- 实现 Skill 进化机制 → **自我进化** 全部

---

*本文档为索引文件。完整 ASCII 流程图内容分布在上述 9 个子文件中。*
