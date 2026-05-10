---
title: Phase 19 Requirements 反例压测 (R4 / R5 / R7 / R10)
date: 2026-05-09
context: phase-19-hermes-workflow-design
source: /gsd-explore on REQUIREMENTS.md
status: pending review (no edits applied to REQUIREMENTS.md yet)
---

# Phase 19 Requirements 反例压测

本 note 记录在 `/gsd-explore` 会话中对 REQUIREMENTS.md 进行 4 个反例方向压测后的发现，及对应的 R-ID 修订/新增建议。**本文件不修改 REQUIREMENTS.md 主体**，所有差量补丁见姊妹文件 `requirements-rev2-patch.md`。

---

## 反例 #1：长 inference 假死（触及 R4 / R12）

### 场景

worker 是 implementer profile，正在执行 `terminal(command="npm test && npm run build")`，build 阶段单步耗时 220s。worker 进程仍存活，PID 仍在，只是阻塞在子进程 stdout 等待。

R12 现状：「心跳间隔不得超过 stale 阈值的一半」。但**心跳由谁发**没规定。

### 关键判断

蕾姆问"心跳是进程级旁路 vs 任务级显式"，用户裁决：**(a) 进程活着就算签到** —— 心跳进程化。

### 副作用（用户选 (a) 后浮现）

- R4 文本「PID 不存在 OR 心跳超时」中，第二个条件失去独立语义（心跳 ⇔ PID 存活）
- R12 的 50% 节奏契约被掏空（不再有"任务级 stale"概念）
- 软死锁（PID 活但卡死）完全无回收机制

### 用户裁决：(a-1) 任务级 timeout 为主力 + (a-3) 用户手动 cancel 兜底

### 修订建议

- **R4 改写** — 触发条件 → "PID 不存在 OR 任务执行超出声明时长上限 OR 用户主动 cancel"
- **R12 改写** — 不再用 50% 节奏契约；改为"worker skill 必须在 task metadata 中声明 `expected_duration_max`"
- **R15 新增** — dispatcher 必须支持任务级 timeout，触发 R4 流程

---

## 反例 #2：reviewer 拦截绕过（触及 R8 / R10 / R13）

### 场景

R8 限定"调用 terminal 工具时"做写拦截；R10 通过 SOUL.md disabled `code_execution`。但 reviewer 实际可用工具远不止这两个：

| 绕过路径 | 工具 | 是否被现行 R-ID 覆盖 |
|---------|------|--------------------|
| `file_write` 直接写文件 | `file` toolset | ❌ 无人管 |
| handoff metadata 投毒下游 | `kanban_complete` | ❌ 无人管，且必需保留 |
| webhook 触发外部写 | `web_fetch` POST | ❌ 无人管 |
| 创建恶意 learning 污染未来 worker | `memory_write` / `skill_manage` | ❌ 无人管 |
| `cat payload \| bash` 旁路 | `terminal` 读 + pipe | ⚠️ 取决于 R8 实现 |
| 异常写法（`tee` / `awk -i inplace`） | `terminal` | ⚠️ pattern 黑名单维护爆炸 |

### 根本结构问题

R8 + R10 = **黑名单 + 点状屏蔽**。reviewer 的写路径有 ≥10 扇门，现状只锁了 2 扇。

### 用户裁决：白名单（B）+ terminal 兜底（C 变体），且对 metadata 投毒采用 (i) + (ii)

### 修订建议

- **R10 改写** — toolsets 必须**白名单显式列举**：`file_read` / `kanban_read` / `kanban_block` / `kanban_complete` / `clarify`，其他默认 disabled；新 toolset 须经显式审计
- **R8 收缩** — 退化为"白名单内 terminal abuse 兜底"
- **R13 扩展** — handoff metadata schema 校验扩展到**值的安全性**（拒绝 shebang / heredoc / 命令注入元字符等可执行 payload 模式）
- **R16 新增** — 下游 worker 读取 handoff metadata 必须当 untrusted input（用 `<untrusted-handoff>` 上下文标签隔离）

---

## 反例 #3：learning 去重 / 矛盾 / 删除传染（触及 R7）

### 4 个子场景

1. **同主题 5 倍冗余** — 5 个项目各自记录"Next.js next.config.js 必须加 X"，措辞略异。R7 没规定 curator 跨项目去重
2. **沉默覆盖** — 项目 A 在自己 namespace 写了与全局相反的 learning，"项目优先"的 R7 让 A 用新版、B-E 用旧版，**矛盾不浮现**
3. **删除传染** — 项目 A 删了某 learning，全局同主题条目要不要跟着删？R7 没规定
4. **晋升源责任** — "cross-project" 标记由谁打？worker 自己打 → curator 工作队列爆炸；用户 / orchestrator 打 → 谁有跨项目视角？R7 没规定

### 根本结构问题

R7 把 learning 当**静态分类**（放对位置）处理，但 learning 是**动态知识**：会过时、会被推翻、有版本、有冲突、有传染。R7 现状只覆盖"放哪儿"。

### 用户裁决：拆为 R7 / R7b / R7c / R7d / R7e

### 修订建议

- **R7 保留** — 命名空间核心规则不变
- **R7b 新增** — 同主题合并：curator 必须支持基于语义相似度的同主题识别，跨项目检测时主动合并/标注差异
- **R7c 新增** — 矛盾浮现：项目命名空间 vs 全局命名空间在主题相似但内容矛盾时，agent 查询返回必须显式 `<conflict_warning>` 元数据
- **R7d 新增** — 删除传染：learning 删除必须声明传染范围（仅本项目 / 触发其他项目复审 / 不允许直接全局回退）
- **R7e 新增** — 晋升源责任：cross-project 标记仅允许 orchestrator 或用户显式标注；curator 拒绝 worker 主动晋升请求

---

## 反例 #4：R5 死锁背压（触及 R5）

### 场景

R5 看「ready 队列深度比率」决定 pause。但比率分不清"动得慢" vs "完全不动"。

| 状态 | ratio 表现 | R5 现状响应 | 应有响应 |
|------|----------|------------|---------|
| **健康背压** — reviewer 在工作但慢 | 短期高 → 自然回落 | pause implementer | ✅ pause（正确） |
| **死锁背压** — reviewer 0 throughput（LLM 限流 / model 配错 / profile bug） | 单调上升 → ∞ | pause implementer 永远不释放 | ❌ 应升级告警 |

### 子问题：抖动敏感性

R5 没说比率窗口是滑动平均还是瞬时。瞬时实现会导致 spawn 状态频繁切换。

### 修订建议

- **R5 保留** — backpressure pause 语义不变
- **R17 新增** — 活性检测：当下游消费 profile 持续 X 分钟（默认 30）throughput=0 且 ready 队列非空，必须升级到用户/orchestrator（创建 block + Gateway 推送）
- **R18 新增** — 抖动平滑：R5 的比率计算必须采用滑动窗口平均（具体值留 ce-plan）

---

## 14 项修订/新增汇总

| # | 反例 | R-ID | 改动类型 |
|---|------|------|----------|
| 1 | #1 | R4 | 改写（触发条件） |
| 2 | #1 | R12 | 改写（心跳契约重新定义） |
| 3 | #1 | **R15 新增** | 任务级 timeout |
| 4 | #2 | R10 | 改写（白名单 toolsets） |
| 5 | #2 | R8 | 收缩（兜底语义） |
| 6 | #2 | R13 | 扩展（值校验） |
| 7 | #2 | **R16 新增** | handoff untrusted input |
| 8 | #3 | R7 | 保留 |
| 9 | #3 | **R7b 新增** | 同主题合并 |
| 10 | #3 | **R7c 新增** | 矛盾浮现 |
| 11 | #3 | **R7d 新增** | 删除传染 |
| 12 | #3 | **R7e 新增** | 晋升源责任 |
| 13 | #4 | **R17 新增** | 活性检测 |
| 14 | #4 | **R18 新增** | 抖动平滑 |

**未触及 R-ID**：R1 / R2 / R3 / R6 / R9 / R11 / R14（未在本轮压测覆盖范围内）

---

## 后续动作建议

1. **审阅本 note 与姊妹 patch 文件**（`requirements-rev2-patch.md`），决定哪些建议接受 / 修改 / 拒绝
2. **接受的修订** apply 到 REQUIREMENTS.md，建议保留原文件，新文件命名为 `REQUIREMENTS-REV2.md`（沿用项目已有的 `REQUIREMENTS-REV1.md` 命名习惯）
3. **下一轮压测候选**（本轮未覆盖）：
   - R3 项目级 profile override 的合并语义边界
   - R6 risk policy YAML 与 hermes 内置 hooks 的关系
   - R11 orchestrator 禁用 toolsets 后的"间接编码"路径（如通过 kanban_create_task description 投毒）
   - R14 worker skill 必须 kanban_block 触发条件清单的完备性
4. **进入 ce-plan 之前**，至少 R8 / R10 / R13 这一组（涉及安全语义）建议先合并到主 REQUIREMENTS.md，避免 ce-plan 阶段以错误前提拆任务
