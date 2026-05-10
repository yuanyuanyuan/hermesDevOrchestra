---
date: 2026-05-09
topic: hermes-workflow-design
---

# Hermes 多项目 AI 开发工作流 — Requirements

> 版本: 2.0.0
> 日期: 2026-05-10
> 状态: Draft (Grill-Me 确认版)

## Summary

基于 Hermes Agent v0.13.0 原生能力（Kanban、Profile、Dispatcher、Curator、Plugin Hooks），构建一套单人多项目 AI 开发编排系统。通过 Phase 0 平台能力确认钉死官方能力边界，定义 PM、Orchestrator（中枢路由）、Researcher、Implementer、Reviewer、QA-Tester、DevOps-Engineer、SRE-Observer 共 8 个角色的行为契约与流转规则。

---

## Problem Frame

Hermes Agent v0.13.0 原生提供了：

- 持久化任务板（Kanban + SQLite，含 atomic claim、parents 依赖、心跳、stale claim 回收、failure-limit 熔断）
- Profile 隔离（独立 toolsets / SOUL.md / model 配置）
- Curator + memory + skill_manage 自我进化三件套
- 多平台 Gateway（嵌入 dispatcher）
- 23 个内置 toolsets 覆盖 terminal / file / clarify / delegation / messaging 全部需求
- Plugin Hook 系统（`pre_tool_call` / `post_tool_call` / `on_session_end` 等，支持阻塞和观测）

需要在此基础上构建增量能力：Research + POC 技术研判流程、PM/Orchestrator 角色分离、状态机驱动路由、三层纵深风险拦截、per-board 完全隔离的多项目并行管理。

---

## Architecture Context

本系统的最外层是 **Hermes Agent v0.13.0 运行时**（对应 Actor A1）。所有其他角色均运行于该运行时内部：

- **PM**（A2）是持续存在的需求分析角色，负责需求澄清、技术研判、任务拆解
- **Orchestrator**（A3）是中枢路由器，负责按状态机路由表派发任务、监控进度、所有角色间通信经由其中转
- **Researcher**（A4）是按需唤醒的技术调研角色，产出技术方案文档
- **Implementer**（A5）在隔离 worktree 中执行编码、测试、POC
- **Reviewer**（A6）审查代码，受硬门禁 + 只读约束
- **QA-Tester**（A7）功能验收
- **DevOps-Engineer**（A8）CI/CD、部署
- **SRE-Observer**（A9）故障根因分析，人工升级触发
- **Risk Policy Engine** 注入 Hermes `pre_tool_call` hook，三层纵深拦截
- **User**（A10）在 Hermes 外部，通过 Gateway / CLI 与系统交互

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Hermes Agent v0.13.0 运行时（A1）                      │
│                         宿主平台 · 本工作不修改其实现                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              Hermes 官方内置能力（平台服务层）                     │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐ │   │
│  │  │ Kanban  │ │Dispatcher│ │ Gateway │ │ Curator │ │ Toolsets │ │   │
│  │  │ 任务板   │ │ 调度器   │ │ 消息推送 │ │ 知识管家 │ │ 23套工具 │ │   │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬─────┘ │   │
│  │       └────────────┴────────────┴────────────┴───────────┘      │   │
│  │                              ▲                                  │   │
│  └──────────────────────────────┼──────────────────────────────────┘   │
│                                 │                                      │
│  ┌──────────────────────────────┼──────────────────────────────────┐   │
│  │            Profiles（用户配置的角色实例）← 由 Hermes 加载           │   │
│  │                              │                                   │   │
│  │    ┌─────────────┐   ┌───────┴───────┐   ┌─────────────────┐   │   │
│  │    │     PM      │   │ Orchestrator  │   │   Researcher    │   │   │
│  │    │   (A2)      │   │    (A3)       │   │     (A4)        │   │   │
│  │    │  需求分析    │   │  中枢路由      │   │   技术调研       │   │   │
│  │    │  任务拆解    │   │  进度监控      │   │   方案文档       │   │   │
│  │    └─────────────┘   └───────────────┘   └─────────────────┘   │   │
│  │                              │                                   │   │
│  │    ┌─────────────┐   ┌───────┴───────┐   ┌─────────────────┐   │   │
│  │    │ Implementer │   │   Reviewer    │   │   QA-Tester     │   │   │
│  │    │   (A5)      │   │    (A6)       │   │     (A7)        │   │   │
│  │    │  编码执行    │   │  只读审查      │   │   功能验收       │   │   │
│  │    │  POC 验证    │   │  硬门禁        │   │                 │   │   │
│  │    └─────────────┘   └───────────────┘   └─────────────────┘   │   │
│  │                              │                                   │   │
│  │    ┌─────────────┐   ┌───────┴───────┐                         │   │
│  │    │   DevOps    │   │ SRE-Observer  │                         │   │
│  │    │   (A8)      │   │    (A9)       │                         │   │
│  │    │  发布部署    │   │  根因分析      │                         │   │
│  │    └─────────────┘   └───────────────┘                         │   │
│  │                              │                                   │   │
│  │                 ┌────────────┴────────────┐                   │   │
│  │                 │   Risk Policy Engine    │    注入所有 Worker  │   │
│  │                 │   SOUL.md + Plugin + CLI│    三层纵深拦截     │   │
│  │                 └─────────────────────────┘                   │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                 ▲                                      │
└─────────────────────────────────┼──────────────────────────────────────┘
                                  │
                     ┌────────────┴────────────┐
                     │       User (Jacky)       │
                     │        (A10) 人类        │
                     │    通过 Gateway/CLI 交互   │
                     └─────────────────────────┘
```

---

## Actors

- A1. **Hermes Agent runtime** — 提供 Kanban dispatcher、Gateway、Curator 等官方能力，本工作不修改其实现
- A2. **PM profile** — 持续存在；需求澄清、技术研判（判断是否需要 Research）、任务拆解、分配 assignee
- A3. **Orchestrator profile** — 中枢路由器；按状态机路由表派发任务、监控进度、所有角色间通信经由其中转、审计追踪
- A4. **Researcher profile** — 按需唤醒；技术方案调研、产出技术方案文档，不写代码
- A5. **Implementer profile** — 按需唤醒；在隔离 worktree 中执行编码、测试、POC
- A6. **Reviewer profile** — 按需唤醒；审查代码、标记风险，受硬门禁 + 只读约束
- A7. **QA-Tester profile** — 按需唤醒；功能验收、集成测试
- A8. **DevOps-Engineer profile** — 按需唤醒；CI/CD、部署、版本管理
- A9. **SRE-Observer profile** — 人工升级触发；故障根因分析，输出结构化报告
- A10. **User (Jacky)** — L3 决策仲裁者；通过 Gateway 或 CLI 响应 block
- A11. **Curator** — Hermes 原生后台服务；skill 生命周期维护
- A12. **Risk Policy Engine** — 三层纵深风险拦截（SOUL.md 软约束 + Plugin `pre_tool_call` 硬拦截 + CLI 原生安全）

---

## Key Flows

- F0. **Phase 0 平台能力确认**
  - **Trigger:** 开始设计 Profile 前，一次性执行
  - **Actors:** A1
  - **Steps:** 对 Hermes v0.13.0 的关键能力（Kanban、Profile、Dispatcher、Plugin Hooks）执行最小端到端用例；记录命令、退出码、输出片段；产出一份 capability-verification 表
  - **Outcome:** 确认哪些能力可直接使用、哪些需要增量扩展
  - **Covered by:** R1, R2

- F1. **需求提交与澄清**
  - **Trigger:** 用户通过 Gateway/CLI 提交需求
  - **Actors:** A2 (PM), A10 (User)
  - **Steps:** PM 被唤醒；读取 AGENTS.md 路由获取项目上下文；一次一问逐步收缩澄清；可行性检查 + 冲突沟通；生成标准化需求文档
  - **Outcome:** 需求文档写入 Kanban task，所有判断有代码证据
  - **Covered by:** R3

- F2. **技术研判（Research + POC）**
  - **Trigger:** PM 判断任务涉及"项目中从未用过的技术栈"或需求含"调研/选型/方案"关键词
  - **Actors:** A2 (PM), A4 (Researcher), A5 (Implementer)
  - **Steps:**
    1. PM 创建 Research 子任务（T1.1），assignee: researcher，依赖原任务
    2. Researcher 被唤醒；读取需求文档 + AGENTS.md 路由 + MEMORY.md 经验；必要时 web research；产出技术方案文档；写入 task comment
    3. Researcher 在 comment 中标注"需要 POC"或"无需 POC，推荐方案 X"
    4. 如果需要 POC → PM 创建 POC 子任务（T1.2），assignee: implementer，依赖 T1.1
    5. Implementer 在独立 POC worktree（`.worktrees/poc-<task-slug>`）中验证技术可行性
    6. POC 成功 → 写入结果文档，Orchestrator 路由到正式实现
    7. POC 失败 → 写入失败文档（做了什么、为什么失败），`kanban_block()`，Orchestrator 决定：换方案重新 research / 升级用户 / 放弃任务
  - **Outcome:** 技术方案确定，POC 通过或已知风险已文档化
  - **Covered by:** R-new(Research), R-new(POC)

- F3. **任务拆解与派发**
  - **Trigger:** PM 完成需求分析（F1）和技术研判（F2，如适用）
  - **Actors:** A2 (PM), A3 (Orchestrator)
  - **Steps:** PM 拆解为子任务 + 设置 dependencies + assignee；写入 Kanban（状态: ready）；Orchestrator 接管，按状态机路由表派发给对应角色
  - **Outcome:** 任务图写入 Kanban，所有依赖关系就绪
  - **Covered by:** R4, R5

- F4. **多项目并行任务生命周期（含背压）**
  - **Trigger:** Orchestrator 创建 ready 任务，dispatcher 准备 spawn worker
  - **Actors:** A1, A3 (Orchestrator), A5 (Implementer), A6 (Reviewer)
  - **Steps:** dispatcher 计算 implementer/reviewer 队列深度比；超过阈值时按策略降速或暂停 implementer；正常时按 assignee 在隔离 workspace spawn worker；worker 通过心跳维持 liveness；崩溃时 Hermes 官方自动回收到 ready
  - **Outcome:** 不会出现 implementer 持续压垮 reviewer 的积压；崩溃 worker 自动恢复
  - **Covered by:** R4, R5

- F5. **L3 风险升级与用户决策**
  - **Trigger:** Worker 即将执行的命令匹配 risk policy 中的 L3 规则
  - **Actors:** A1, A5/A6 (Worker), A10 (User), A12 (Risk Policy)
  - **Steps:** Risk policy engine（Plugin `pre_tool_call` hook）拦截命令；调用 `kanban_block` 并附带规则 ID 与命令上下文；Gateway 按订阅推送给用户；用户通过 CLI / Gateway 响应；dispatcher unblock 并恢复 worker
  - **Outcome:** L3 操作在用户明确批准前不会执行；审计日志记录决策轨迹
  - **Covered by:** R6

- F6. **故障处理与 SRE 分析**
  - **Trigger:** 人工判断需要深度分析时（Hermes 官方自动处理 crash/timed_out 回收）
  - **Actors:** A9 (SRE-Observer), A10 (User)
  - **Steps:** 用户或 Orchestrator 手动创建 SRE 分析任务；SRE-Observer 读取 task_runs + events + logs；生成结构化根因报告
  - **Outcome:** 根因报告包含 root_cause_category / confidence / recommended_action
  - **Covered by:** R19, R20, R21

- F7. **完成通知与用户审核**
  - **Trigger:** 所有子任务 done
  - **Actors:** A3 (Orchestrator), A10 (User)
  - **Steps:** Orchestrator 汇总完成情况；Gateway 推送通知用户；用户审核决策（合并/发布/归档）
  - **Outcome:** 用户确认完成，代码合并到 main

---

## Requirements

**Phase 0 — 能力对齐验证**

- R1. 在引用 DESIGN.md 中任何"标记为官方覆盖"的能力之前，必须有一份 capability-verification 表用代码级证据（命令调用、退出码、关键输出片段）证明该能力在当前安装的 Hermes Agent 版本上能跑通最小端到端用例。
- R2. 验证表中标记为"未通过"的项目，必须重新归类为真增量需求（合并到 R3-R8 的相应类别），并在 doc 中显式追加 R-ID。

**真增量工程需求**

- R3. 必须支持项目级 profile override：在不污染全局 `~/.hermes/profiles/` 的前提下，允许每个项目对 toolsets / model / SOUL.md 做局部覆盖；运行时按"全局 base + 项目 override"合并。
- R4. Worker 任务需要回收时（PID 不存在 OR 任务执行超出声明的 expected_duration_max OR 用户/orchestrator 主动 cancel），系统必须将该 worker 占用的 git worktree 恢复到任务开始前的干净状态，再由 dispatcher 将任务回退到 ready 重新派发。
- R5. Dispatcher 必须感知"按 profile 分类的 ready 任务队列深度"，当某 profile 的 ready 队列相对其下游消费 profile 超过阈值时，自动降低或暂停对该 profile 的 spawn 频率。
- R6. 必须支持声明式风险策略文件（YAML 形态），按 pattern 匹配将命令归入 L1/L2/L3，注入 worker 上下文供 sentinel 逻辑统一消费；L3 项目永远不允许超时自动通过。
- R7. Learnings/memory 默认必须写入"项目专属"命名空间；只有显式标记 cross-project 且通过 curator 审核的条目才进入"全局"命名空间；agent 查找时项目命名空间优先于全局。
- R7b. Curator 必须支持基于语义相似度的"同主题 learning"识别：当多个项目命名空间的 learning 在主题与建议上相似度超过阈值（具体值留 ce-plan）时，curator 必须主动触发合并流程或生成跨项目复审 task；不允许"5 个项目独立记录同一条经验"长期沉默存在。
- R7c. 当 agent 查询 learning 时，若项目命名空间条目与全局命名空间条目在主题相似但内容矛盾，查询结果必须显式包含 `<conflict_warning>` 元数据（含两端条目摘要）；agent 不允许沉默选用项目版本而忽略全局矛盾。
- R7d. Learning 删除必须显式声明传染范围之一：(a) 仅本项目（默认）(b) 本项目 + 触发其他项目对同主题条目的复审（curator 派发 review task）(c) 全局回退（必须经 curator 二次审核与用户/orchestrator 确认）。不允许"沉默删除"——即不允许仅删除项目条目而绕过对应全局条目的状态评估。
- R7e. "cross-project" 标记仅允许由 orchestrator profile 或用户显式标注；worker（implementer / reviewer）调用 `memory_promote(cross_project=True)` 等 API 必须被 curator 拒绝。Curator 拒绝时记录原因到审计日志。
- R8. 在 R10 白名单基础上，若 reviewer profile 的白名单中包含 terminal 工具（如审查时需运行 lint / typecheck），terminal 工具的所有写操作（rm / write / git push / DROP TABLE 等）必须被技术性拦截而非仅靠 SOUL.md prompt 约束；拦截行为可配置为 dry-run 返回或直接拒绝；所有拦截事件必须写入审计日志。R8 作为白名单内 terminal abuse 的兜底，不是 reviewer 写防护的主防线（主防线见 R10）。

**SOUL.md 与 Worker Skill 行为契约**

- R9. Implementer profile 的 SOUL.md 必须包含强制规则："遇到架构决策、技术选型、不在任务范围内的判断时，必须调用 `kanban_block` 而非自行决定"。
- R10. Reviewer profile 的 toolsets 配置必须采用白名单显式列举形式，仅 enable 必需的只读 + kanban 写工具集（默认白名单：`file_read` / `kanban_read` / `kanban_block` / `kanban_complete` / `clarify`），其他 toolsets 默认 disabled。Hermes Agent 升级引入新 toolset 时，必须经过显式审计才能加入 reviewer 白名单。Reviewer 的 SOUL.md 须声明"只读"立场作为 prompt 层强化，与 toolsets 白名单（主防线）+ R8 terminal 兜底（次防线）形成纵深防御。
- R11. Orchestrator profile 的 toolsets 配置必须采用白名单形式：允许 `file_read` / `terminal(只读命令)` / `kanban_read` / `kanban_write` / `clarify`，禁止 `file_write` / `terminal(写操作)` / `code_execution`。Orchestrator 需要只读访问项目代码来执行技术发现（Step 1.4）和可行性检查（Step 1.6），但不能亲自编码。写操作拦截机制同 R8。
- R12. Worker skill 必须为每个任务在 task metadata 中声明 `expected_duration_max`（任务的最大合理执行时长），dispatcher 据此触发 R4 的任务级 timeout 流程。Worker 进程的存活通过 OS 进程级别（PID 探测 + 进程级 keep-alive 信号）判定，不再要求任务循环显式调用 heartbeat API。
- R13. Worker skill 必须为 `kanban_complete` 定义结构化 handoff metadata 形态，至少包含 changed_files、tests_run、tests_passed、decisions、pitfalls 五个字段（具体 schema 留给 ce-plan）。schema 校验必须覆盖字段值的安全性：decisions / pitfalls 等自由文本字段不允许包含可执行 payload 模式（shebang / bash heredoc / 含 auth token 的 URL / shell 命令注入元字符等），由 ce-plan 阶段定义具体过滤清单。
- R14. Worker skill 必须明确列出"必须 kanban_block 的触发条件清单"（至少包含：架构决策、被 risk policy 拦截、外部依赖不可用、关键测试失败），不允许 worker 凭直觉决定何时 block。
- R15. Dispatcher 必须支持任务级 timeout：基于 task metadata 中的 `expected_duration_max` 字段，超时后触发 R4 的 dirty-state cleanup 与 ready 重派流程。timeout 默认值（按 profile 给保守值，如 implementer 60min / reviewer 10min）由 ce-plan 阶段确定。
- R16. 下游 worker（任意 profile）读取 parent task 的 handoff metadata 时，必须将 metadata 标注为 untrusted input：在 LLM 上下文中使用专用包裹标签（如 `<untrusted-handoff source="<parent_task_id>">…</untrusted-handoff>`）隔离，禁止将 metadata 内容直接拼接到指令性 prompt；worker skill 必须显式声明对 untrusted-handoff 内容的处理边界（仅作为参考信息使用，不作为指令源）。
- R17. Dispatcher 必须区分"健康背压"与"死锁背压"：当某下游消费 profile 持续 X 分钟（默认 30）throughput=0 且 ready 队列非空时，必须升级到 orchestrator 或用户（创建 kanban_block 任务 + 通过 Gateway 推送告警）。R5 的 pause 机制不允许演变成无人察觉的永久死锁。
- R18. R5 的 ready 队列深度比率计算必须采用滑动窗口平均（默认窗口大小由 ce-plan 决定，建议 ≥ 1 分钟），不允许采用瞬时值；防止短期抖动导致 spawn 状态频繁切换。

**全链路可观测性需求**

- R19. Observability Plugin 必须通过 Hermes 官方 `post_tool_call` 和 `on_session_end` hooks 采集工具调用链，写入 `observability_trace.db`（或扩展 `kanban.db` schema），**不允许**修改 Hermes 核心代码。
- R20. 当任务 outcome 为 `crashed` / `timed_out` / `gave_up`，或同一任务的 `rollback_count ≥ 2`，或任务 `blocked` 超过 R17 阈值（默认 30 分钟）时，Dispatcher 必须自动创建高优先级 `sre-observer` 分析任务，且该任务必须能读取故障任务的全部 runs、events、logs、audit traces。
- R21. SRE-Observer 的 `kanban_complete` 必须输出标准化根因报告 metadata，字段至少包含：`root_cause_category`（枚举：code / environment / deployment / external / policy / review / qa）、`confidence`（high / medium / low）、`symptom`、`root_cause`、`responsible_profile`、`upstream_fault`、`recommended_action`、`trace_anchor`。
- R22. 所有 Worker spawn 时，Dispatcher 必须采集环境快照（至少包含 `git status` 输出、`df -h` 前 5 行、`hermes status` 输出）并关联到当前 `task_run` 的 metadata，供 SRE-Observer 做环境层根因定位。
- R23. QA-Tester 调用 `kanban_block` 且 reason 包含 `regression`、`critical_bug` 或 `security_flaw` 时，必须自动触发 R20 的 SRE 分析流程；根因报告必须能区分"代码缺陷"（responsible_profile = implementer）与"上游交付物缺陷"（responsible_profile = 上游角色，upstream_fault 指向上游 task）。
- R24. DevOps-Engineer 的 deployment 相关 task（workspace 含 `deploy` 关键词或 task body 含部署指令）若 outcome ≠ `completed`，必须自动触发 R20 的 SRE 分析；根因报告必须包含 CI/CD 日志摘要（最后 50 行）和环境差异（当前 git commit vs 上次成功发布的 commit diff）。

---

## Acceptance Examples

- AE1. **Covers R1.** Given DESIGN §4.3 声明"parents 依赖由官方支持"，when capability verification 表中存在条目记录 `hermes kanban link <parent> <child>` 命令的退出码与 `hermes kanban show` 输出中的 parent 字段截图/文本，then 该项可标记为 verified 并从需求集排除。
- AE2. **Covers R2.** Given Phase 0 验证 §3.6 project-level override 时发现 Hermes 仅支持 `HERMES_HOME` 全替换而无层级合并，when 验证标记为"未通过"，then 必须保留 R3 不变（已基于该假设设立）；若未来发现新机制，则更新 R3 描述。
- AE3. **Covers R5.** Given implementer 队列有 9 个 ready 任务、reviewer 队列有 2 个 ready 任务（比率 4.5），when dispatcher 进入下一轮 spawn 决策，then implementer 当轮 spawn 数为 0，且日志记录"backpressure paused: ratio=4.5"。
- AE4. **Covers R6.** Given risk policy 配置 `pattern: "git push --force"` 为 L3，when worker 即将通过 terminal 执行该命令，then 命令不会被实际执行、任务进入 blocked 状态、Gateway 推送决策请求给用户、审计日志记录命令文本与拦截时间。
- AE5. **Covers R8, R10.** Given reviewer profile 在审查代码时调用 `terminal(command="rm test.txt")`，when read-only proxy 拦截该命令，then 命令不会被实际执行、tool call 返回结构化错误（含拒绝原因）、审计日志写入一行 `reviewer-attempted-write: rm test.txt`。
- AE6. **Covers R9.** Given implementer 在执行任务时遇到"应该用 RS256 还是 HS256"的技术选型问题，when 该决策不在 task body 已明确、也不在 risk policy 已规则化的范围内，then implementer 必须调用 `kanban_block(reason="architecture-decision: RS256 vs HS256")` 而非自行选择。
- AE7. **Covers R12, R15.** Given implementer 任务在 task metadata 中声明 `expected_duration_max=30min`，worker 进程在 35min 时仍存活但未完成，when dispatcher 检测到任务级 timeout，then dispatcher 触发 SIGTERM kill worker、执行 R4 的 worktree 清理、将任务回退到 ready；审计日志记录 timeout 触发原因与原 PID。
- AE8. **Covers R10, R8.** Given reviewer profile toolsets 配置为白名单 `file_read / kanban_read / kanban_block / kanban_complete / clarify / terminal`，when reviewer 调用 `file_write(...)`，then 工具调用直接因 toolset 未 enable 而失败（白名单层拦截，不进入 R8）；when reviewer 调用 `terminal(command="rm test.txt")`，then R8 兜底拦截生效，命令不执行、审计日志写入。
- AE9. **Covers R13, R16.** Given reviewer 在 `kanban_complete` 的 decisions 字段塞入 `"#!/bin/bash\nrm -rf /"`，when handoff metadata 提交，then schema 校验拒绝（R13 的值校验），返回结构化错误；若校验放行（边角 pattern 漏过），下游 implementer 读取时必须将该字段包裹在 `<untrusted-handoff>` 标签内（R16），不允许执行其内容。
- AE10. **Covers R17.** Given reviewer profile 的 LLM provider 持续返回 429（限流），reviewer worker 反复 spawn 后立刻退出，throughput 持续 0；当持续时间超过 30min 且 ready 队列仍 ≥ 1 时，then dispatcher 创建 kanban_block 任务标注"reviewer profile 死锁告警"、Gateway 推送给用户；R5 的 pause 状态不允许在无升级的情况下保持超过此阈值。
- AE11. **Covers R7c.** Given 全局 namespace 有 learning "Webpack 配置必须 X"、项目 A 的 namespace 有矛盾的 learning "Webpack 配置必须 NOT X"，when 项目 A 的 implementer 查询 "Webpack 配置" 相关 learnings，then 返回结果必须包含两端条目并附 `<conflict_warning>` 元数据；agent 不允许仅返回项目版本而隐藏全局矛盾。
- AE12. **Covers R7e.** Given implementer worker 调用 `memory_promote(cross_project=True)`，when curator 收到该请求，then 直接拒绝并记录审计日志；仅 orchestrator profile 或用户显式标注的 cross-project 标记可被 curator 接受。

- AE13. **Covers R19.** Given Implementer worker 执行了 `terminal(command="pytest")` 并返回 exit_code=1，when `post_tool_call` hook 触发，then `observability_trace.db` 中新增一条记录：tool_name="terminal", result_status="error", 且包含 task_id 与 timestamp。
- AE14. **Covers R20.** Given T5 的 outcome 为 `crashed`，when Dispatcher 进入下一轮 tick，then 自动创建 task assignee="sre-observer"，title 包含"根因分析"，且该任务的 parents 包含 T5。
- AE15. **Covers R21.** Given SRE-Observer 完成分析后调用 `kanban_complete`，when metadata 中 `root_cause_category="environment"` 且 `confidence="high"`，then 报告被 Dashboard 的 SRE 报告列表正确渲染。
- AE16. **Covers R22.** Given Dispatcher spawn DevOps-Engineer worker 时，when 环境快照采集完成，then `task_runs` 的 metadata 中包含 `env_snapshot.git_status` 与 `env_snapshot.disk_free` 字段。
- AE17. **Covers R23.** Given QA-Tester 调用 `kanban_block(reason="critical_bug: login returns 500")`，when blocker 关键词匹配，then Dispatcher 在下一 tick 自动创建 sre-observer 分析任务，且根因报告中 `responsible_profile` 字段最终指向具体角色。
- AE18. **Covers R24.** Given DevOps-Engineer 执行 `deploy.sh` 返回非 0 退出码导致 outcome `crashed`，when sre-observer 分析完成，then 根因报告的 `trace_anchor` 字段包含 deploy 相关 tool call 的标识，且 `recommended_action` 不为空。

---

## Success Criteria

- Phase 0 平台能力确认表完整覆盖 Hermes v0.13.0 关键能力（Kanban、Profile、Dispatcher、Plugin Hooks）
- 8 个 Profile 的行为契约（SOUL.md + toolsets）定义清晰，可直接进入实施
- Research + POC 流程与现有 Phase 1-7 流程无缝衔接
- 状态机路由表覆盖所有正常和异常流转路径
- 单人多项目场景在 4-6 个并行 board 下能稳定运行

---

## Scope Boundaries

**本工作包含：**
- 8 个 Profile（PM / Orchestrator / Researcher / Implementer / Reviewer / QA-Tester / DevOps-Engineer / SRE-Observer）的行为契约定义
- Research + POC 技术研判流程设计
- 状态机驱动的路由架构
- 三层纵深风险拦截（SOUL.md + Plugin hook + CLI 安全）
- per-board 完全隔离的多项目并行管理
- Hermes 原生能力的确认与利用

**本工作不包含：**
- 实现细节（schema、文件路径、API 形态、SQL 语句）— 留给实施阶段
- 新增 Gateway messaging adapter — Telegram/Discord/Slack/WhatsApp 已官方支持
- 团队协作 / AI factory 高吞吐场景 — 维持 single developer 边界
- 预留 Profile（pm-researcher / product-designer / growth-marketer）的启用
- DESIGN §4.6 SIGSTOP/SIGCONT 任务休眠 — 过度设计，保留 block/unblock 官方机制即可
- DESIGN §5.6 Tmux Warm Pool — 过早优化
- DESIGN §8.6 0-100 数字质量分 — 与官方 curator 设计哲学冲突
- DESIGN §8.7 Skill Sandbox + 三阶段晋升 — 与官方 prune→archive→restore 模型冲突
- DESIGN 附录 D 动态 Living Context — 官方 `hermes kanban context` 已覆盖
- DESIGN 附录 E 脚本自注册机制 — 项目脚手架问题，与 Hermes 能力无关

---

## Key Decisions

- **PM 与 Orchestrator 角色分离**：PM 负责需求分析、任务拆解（需要 LLM 推理）；Orchestrator 负责中枢路由、进度监控（规则驱动）。职责清晰，避免单角色负担过重导致幻觉。
- **Research + POC 作为独立流程阶段**：技术不确定性高时，先 Research 产出方案文档，再 POC 验证可行性，最后正式实现。Researcher 不写代码，POC 由 Implementer 执行。
- **Orchestrator 作为中枢路由器**：所有角色间通信经由 Orchestrator 中转，支持审计追踪和流程监控。按状态机路由表执行，不依赖 LLM 推理。
- **Reviewer 硬门禁 + 严格只读**：审查必须通过才能进入下一步；Reviewer 不能自己修复代码，只能报告问题。
- **三层纵深风险拦截**：SOUL.md 软约束（LLM 级）+ Plugin `pre_tool_call` 硬拦截（Plugin 级）+ Claude/Codex CLI 原生安全模式（CLI 级）。
- **SRE-Observer 人工升级触发**：Hermes 官方已内置 crash/timed_out 自动回收，SRE-Observer 仅在人工判断需要深度分析时介入。
- **per-board 完全隔离**：每个项目的 PM、Orchestrator、Worker 都是独立实例，项目间零耦合。
- **可观测性以 Hermes 官方为主**：v1 先用 dashboard + CLI 做日常观测，Plugin 按需增强。

---

## Dependencies / Assumptions

- Hermes Agent v0.13.0 已在目标环境安装并通过 `hermes status` 自检（已实测验证）
- v1.0 SPEC.md 的 actor 权责定义（§AUTH-01/02）保持不变，本 requirements 在其之上扩展但不替换
- v1.2 milestone 已完成，文件总线 runtime 仍可作为兼容回退（在 Phase 0 验证未完成前）
- 假设 Hermes Agent 后续小版本（0.13.x）不会破坏本 doc 引用的能力（Kanban / Profile / Curator / Memory 等）；若发生破坏性变更，需重新触发 Phase 0 验证
- 假设 worker 是 OS 进程而非常驻 LLM 会话（已通过 Hermes Kanban v1 spec §3.3 "no in-process subagent swarms" 确认）

---

## Outstanding Questions

### Resolve Before Planning

（无 — 本讨论已完成范围与契约的对齐，无阻塞实施的产品决策待解）

### Deferred to Planning

- [Affects R3][Technical] 项目级 profile override 的合并语义具体怎么定义？toolsets 是取并集、覆盖、还是有显式 enabled/disabled 双字段语义？SOUL.md 是 frontmatter `extends:` 拼接还是分段标记替换？— 留给 ce-plan 探索
- [Affects R4][Technical] git worktree dirty-state 清理用 `git stash` / `git reset --hard` / 文件系统快照（cp -a 或 zfs snapshot）哪种？取决于性能与可靠性权衡 — ce-plan 阶段调研
- [Affects R5][Technical] 背压阈值（DESIGN 写的 2.0 / 4.0）是否需要可配置？ratio 计算的窗口是瞬时还是滑动平均？— ce-plan 决定
- [Affects R6][Technical] Risk policy YAML 的 schema 细节、pattern 是 glob / regex / 子串匹配、与 Hermes hooks 的关系（替代还是协作）— ce-plan 设计
- [Affects R7][Needs research] 跨项目 learning 晋升的具体审核机制：是 curator 自动判定还是用户审核？审核 UI 在哪里？— 需要先调研 curator 是否已有插件接口
- [Affects R8][Technical] Read-only terminal proxy 的实现位置：在 Hermes tool registry 层 wrap 还是在 SOUL.md 通过 hooks 拦截？前者改动更深、后者可能不可靠 — ce-plan 决策
- [Affects R10][Technical] reviewer 白名单的精确工具集清单：当前默认白名单 `file_read` / `kanban_read` / `kanban_block` / `kanban_complete` / `clarify` 是否完备？是否需要 `terminal`（用于 lint/typecheck）？需要 `web_fetch`（用于 fetch PR 上下文）吗？— 需先查 hermes-docs-index 确认所有 toolsets 后定案
- [Affects R13][Technical] handoff metadata 值过滤清单的精确 pattern：需要拦截哪些 payload 模式（shebang / heredoc / shell 元字符 / URL with auth）？过滤策略是 reject 还是 sanitize？— 留给 ce-plan
- [Affects R7b][Needs research] curator 语义相似度阈值的合理范围：embedding 模型选择？阈值默认值？— 需调研 hermes curator 是否已有相似度比较机制
- [Affects R7d][Technical] 删除传染的工程实现：curator 派发的 review task 模板？复审 SLA？— 留给 ce-plan
- [Affects R15][Technical] 各 profile 的 expected_duration_max 默认值：implementer / reviewer / orchestrator 各自合理上限？是否区分任务类型（简单修复 vs 大型重构）？— 留给 ce-plan
- [Affects R17][Technical] 活性检测的 X 分钟阈值与告警 channel：默认 30min？告警通过 Gateway 哪个 adapter 推送？是否区分死锁严重等级？— 留给 ce-plan
- [Affects R18][Technical] R5 滑动窗口默认值：1 分钟？5 分钟？窗口大小如何与 R17 的 X 分钟阈值协调？— 留给 ce-plan
