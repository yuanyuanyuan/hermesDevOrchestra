---
date: 2026-05-10
topic: workflow-explained-validation
---

# WORKFLOW-EXPLAINED.md 准确性验证报告

> 本报告将 `WORKFLOW-EXPLAINED.md` 与 **Hermes Agent v0.13.0 官方文档** 对比，
> 同时评估 AI Agent 行为模拟和人的反应模拟的真实性。
> 
> 数据来源：
> - Hermes 官方文档（hermes-agent.nousresearch.com/docs）
> - `DESIGN.md` + `REQUIREMENTS.md`（产品设计意图）
> - Claude Code CLI / Codex CLI / Hermes Agent 的实际运行原理

---

## 一、官方机制验证（与 Hermes 文档对比）

### ✅ 准确的部分

| # | 叙事内容 | 官方文档依据 | 状态 |
|---|---------|------------|------|
| 1 | `hermes kanban boards create <slug>` 创建项目 Board | 官方 CLI 命令完全一致 | ✅ |
| 2 | Board 隔离：独立 SQLite、独立 workspace、独立 dispatcher | 官方文档确认 | ✅ |
| 3 | Dispatcher 每 60 秒循环 | `dispatch_interval_seconds: 60` 默认值 | ✅ |
| 4 | Worker 通过 `kanban_*` toolset（非 CLI）与 board 交互 | 官方明确说明 | ✅ |
| 5 | Worker spawn 时注入 `HERMES_KANBAN_TASK` 和 `HERMES_KANBAN_BOARD` | 官方确认 | ✅ |
| 6 | `kanban_show()` / `kanban_complete()` / `kanban_block()` 工具 | 官方 7 个工具完整对应 | ✅ |
| 7 | `parents` 依赖链：todo → ready 当 parents done | 官方 `kanban_link` 机制 | ✅ |
| 8 | `worktree` workspace：git worktree add 创建隔离目录 | 官方三种 workspace 之一 | ✅ |
| 9 | `hermes -p <profile>` 切换 profile | 官方 `-p` / `--profile` 参数 | ✅ |
| 10 | Gateway 推送通知：`/kanban create` 自动订阅 | 官方 auto-subscribe 机制 | ✅ |
| 11 | `kanban-worker` 和 `kanban-orchestrator` 是 bundled skill | 官方 bundled skills | ✅ |
| 12 | `kanban_heartbeat()` 用于长任务心跳 | 官方 worker skill 指导 | ✅ |
| 13 | Task runs：每次 claim 创建一个 run 记录 | 官方 `task_runs` 表设计 | ✅ |
| 14 | Comment 作为 agent 间协议 | 官方 comment 机制 | ✅ |
| 15 | `scratch` / `dir:<path>` / `worktree` 三种 workspace | 官方完整对应 | ✅ |

### ⚠️ 部分准确 / 需澄清

| # | 叙事内容 | 官方实际行为 | 问题 |
|---|---------|------------|------|
| 16 | 每个 Profile 有独立 `SOUL.md` | **官方只从 `HERMES_HOME` 加载 SOUL.md**，不自动从 profile 目录加载 | 产品设计（R3）假设 profile 级 override，但官方目前不支持 per-profile SOUL.md。需要 `config.yaml` 中 `agent.system_prompt` 或自定义机制实现 |
| 17 | `hermes kanban create` 的 `--status triage` | 官方 CLI 没有 `--status` 参数，创建的任务默认进入 `ready`（无 parents 时）或 `todo`（有 parents 时）。`--triage` flag 存在 | 叙事中 `--status triage` 不存在，应为 `--triage` |
| 18 | `--assignee orchestrator` 创建任务后立即被派发 | 官方：无 parents 的任务创建后默认 `ready`（不是 `triage`），Dispatcher 下一轮 tick 认领 | 基本准确，但 `triage` 列需要显式 `--triage` |
| 19 | `kanban_show()` 返回 `workspace` 字段 | 官方 `kanban_show` 返回 `worker_context` 包含 workspace 信息，但格式是预格式化的文本而非结构化 JSON | 叙事中 JSON 格式过于结构化，实际返回更自由 |
| 20 | `expected_duration_max` 作为 task metadata | 官方文档未提及此字段，但 `max_runtime_seconds` 是官方参数（`--max-runtime`） | 叙事中的字段名与官方不一致 |

### ❌ 不准确 / 产品设计假设（非官方能力）

| # | 叙事内容 | 官方实际状态 | 问题严重性 |
|---|---------|------------|-----------|
| 21 | **Observability Plugin** 通过 `post_tool_call` / `on_session_end` hooks 采集 | **官方文档未确认这些 hook 存在**。Plugin SDK 存在，但具体 hooks 名称需验证 | 🔴 高 |
| 22 | **Risk Policy Engine** (`policies/risk.yaml`) 自动拦截危险命令 | **官方无此机制**。命令拦截需通过 SOUL.md + toolsets 白名单实现 | 🔴 高 |
| 23 | **SRE-Observer 触发**：人工升级触发，非自动 | Hermes 原生处理 crash/timed_out 自动恢复（任务回滚到 ready）。SRE-Observer 仅在 Jacky/PM 判断需要深度根因分析时手动创建 | ✅ 人工升级 |
| 24 | **环境快照**：spawn 时自动采集 `git status`、`df -h`、`hermes status` | **官方无此机制**。需通过 Plugin 或自定义实现（R22） | 🟡 中 |
| 25 | **背压感知**：ratio > 4 暂停派发 implementer | **官方无此机制**。Dispatcher 目前没有背压逻辑（R5 是真增量） | 🟡 中 |
| 26 | **Reviewer 的 terminal 写操作技术性拦截（R8）** | **官方无此机制**。Reviewer 的只读约束只能通过 toolsets 白名单 + SOUL.md 实现 | 🟡 中 |
| 27 | **Curator 自动审查**：每 7 天清理过时 skills | **官方 Curator 存在，但自动审查周期和策略需验证**。官方 curator 是后台服务，具体行为未在获取的文档中详述 | 🟡 中 |
| 28 | `memory_add` 支持 `namespace`、`cross_project`、`tags` 参数 | **官方 memory 系统行为需验证**。叙事中的参数可能是产品设计的理想化 | 🟡 中 |
| 29 | `create_skill` 支持 `name`, `description`, `content`, `tags` 参数 | **官方 skill 创建机制需验证**。叙事可能是理想化 API | 🟡 中 |
| 30 | `kanban_block` 的 `reason` 被 Dispatcher 解析并自动创建 reviewer 任务 | **官方无此自动响应机制**。需要 orchestrator profile 或外部逻辑实现 | 🟡 中 |
| 31 | **Tmux Session 预热池** | **官方无此机制**。Hermes 的 worker 是 OS 进程，不是 tmux session | 🟡 中 |
| 32 | **实时问答流程**：tmux capture-pane + send-keys | **官方 worker 不依赖 tmux**。worker 通过 tool 调用与 board 交互，tmux 只是可选的终端后端 | 🟡 中 |
| 33 | **Crash 时 git stash 回滚 workspace** | **官方无此机制**。worker 崩溃后任务回退到 ready，但 workspace 清理需自定义实现（R4） | 🟡 中 |
| 34 | `kanban_complete` 的 `metadata` 支持任意 JSON 结构 | **官方支持**，但 schema 校验（R13）是产品增量，官方不做校验 | 🟢 低 |
| 35 | `kanban_create` 支持 `skills` 数组附加额外 skill | **官方支持**。`--skill` flag 和 `skills` tool 参数均存在 | ✅ 准确 |

---

## 二、AI Agent 行为真实性评估

### 核心问题：叙事过于"理想化"

WORKFLOW-EXPLAINED.md 中的 AI Agent 表现得像一个**完美的资深工程师**——每一步都正确、每个决策都合理、每个问题都能自我修正。这与真实的 LLM（Claude/Codex/Hermes）行为有显著差距。

#### 2.1 Implementer 的理想化问题

**叙事中的 Implementer：**
> "等等，我注意到一个问题——ring 的 RSA_PSS 和 RSA_PKCS1v15 是不同的...
> 这是一个关键的安全 bug！
> 根据 R9，这是实现正确性而非架构决策，我应该自己修正..."

**真实的 LLM 可能的行为：**

```
【可能性 A：遗漏】
Implementer 根本没有意识到 RS256 = PKCS#1 v1.5 这个问题。
它直接使用 `RSA_PSS_SHA256`，测试通过后提交。
Tech-Reviewer 在审查时发现："RS256 应该用 PKCS#1 v1.5，不是 PSS" → 返回 high severity finding

【可能性 B：错误修正】
Implementer "觉得" PSS 更安全，故意使用 PSS。
在 kanban_complete 的 decisions 中写："使用 RSA_PSS_SHA256（更安全）"
Tech-Reviewer："RS256 的标准定义是 PKCS#1 v1.5，PSS 不兼容标准 JWT 库" → 返回 high severity finding

【可能性 C：修正但引入新 bug】
Implementer 意识到应该用 PKCS#1 v1.5，但写成了 `RSA_PKCS1_1024_8192_SHA256`。
密钥长度不匹配导致签名失败。
测试报错，Implementer 困惑，可能需要 2-3 次 retry 才能解决。
```

**影响：** 叙事只展示了"可能性 A 的反面"（完美自修正），没有展示 LLM 的真实失败模式。这会让读者（Jacky）高估系统的可靠性。

#### 2.2 Tech-Reviewer 的理想化问题

**叙事中的 Tech-Reviewer：**
> 逐行分析所有代码，发现 8 个问题（3 medium + 5 low），包括：
> - 时序攻击风险
> - 用户枚举风险
> - 测试路径硬编码
> - 格式问题

**真实的 LLM 可能的行为：**

```
【可能性 A：遗漏严重问题】
Tech-Reviewer 没有发现 "RS256 用错算法"（如果 Implementer 没自修正）。
因为它可能不熟悉 ring crate 的 API 差异。

【可能性 B：误报】
Tech-Reviewer 报告 "使用了不安全的 random 生成器"，
但实际上 `ring::rand::SystemRandom` 是密码学安全的。
这是 LLM 的"幻觉"——基于训练数据中 "不要自己实现 random" 的泛化。

【可能性 C：过度审查】
Tech-Reviewer 对每行代码都提建议，产生 30+ 个 "low" 级别问题，
淹没了真正重要的 medium/high 问题。
Jacky 看到审查报告时信息过载，无法快速判断优先级。

【可能性 D：没有上下文】
Tech-Reviewer 只审查了 jwt.rs，没有看 routes.rs（虽然 T2 还没完成）。
但它在审查报告中"预言"了 T2 的问题（如 constant_time_eq），
实际上这些预言可能不准确或过度。
```

**影响：** 叙事展示了"完美审查员"，但真实系统中审查质量取决于：
- SOUL.md 中审查 checklists 的完整性
- Reviewer profile 的 model 能力
- 训练数据中相关安全知识的覆盖度

#### 2.3 PM 的理想化问题

**叙事中的 PM：**
> 完美拆解为 6 个任务，依赖关系合理，预估时间准确

**真实的 LLM 可能的行为：**

```
【可能性 A：拆解过细】
PM 把 JWT 模块拆成 15 个子任务，每个只有 10 行代码的工作量。
导致 Dispatcher 频繁 spawn/destroy worker，开销超过实际工作。

【可能性 B：拆解过粗】
PM 只拆成 2 个任务："实现 JWT" + "写测试"。
Implementer 执行 T1 时 overwhelmed（任务太大，容易 timeout）。

【可能性 C：依赖关系错误】
PM 设置 T4（审查）依赖 T2（接口）而不是 T1（核心逻辑）。
导致审查员在等待 Implementer 写接口时无事可做，延迟了 1 小时。

【可能性 D：预估时间偏差】
PM 预估 T1 60 分钟，实际 Implementer 用了 120 分钟（RS256 问题反复调试）。
Dispatcher 在 60 分钟时 timeout kill worker，导致任务回滚， Implementer retry。
```

#### 2.4 LLM 不会"主动长记性"

**叙事中的自我进化：**
> Implementer 主动调用 `memory_add` 和 `create_skill`

**真实的 LLM 行为：**

```
除非 SOUL.md 或 skill 中明确要求"任务完成后记录经验教训"，
LLM 通常不会主动调用 memory/skill 工具。

更可能的行为：
- Implementer 完成 T5 后直接 kanban_complete，完全忘记记录经验
- 或者只在 summary 中写一句"注意 JWT 过期时间不要硬编码"，
  但没有调用 memory_add → 经验没有持久化
- 下次新项目遇到同样问题时，Implementer 从零开始踩坑

只有在 SOUL.md 中写入规则如：
  "每完成一个任务，必须调用 memory_add 记录至少一条经验教训"
  "如果发现可复用的工作流，调用 create_skill"
LLM 才会大概率执行。
即使如此，也可能遗漏（取决于 prompt 的显式程度和 model 的遵循能力）。
```

#### 2.5 "内心OS"的本质

**重要澄清：**

> LLM 没有"意识"、"担忧"、"意识到"等心理活动。
> 叙事中的 "【AI 内心OS】" 实际上是**对 LLM 生成过程的拟人化描述**。
>
> 真实过程：
> 1. LLM 接收 system prompt + context + tool results
> 2. LLM 生成下一个 token（基于概率分布）
> 3. 如果生成的 token 序列构成 `kanban_block()` 调用，工具被触发
> 4. 工具结果返回后，LLM 继续生成
>
> LLM 不会"担心"部署失败，它只是基于训练数据中的模式，
> 在特定上下文（如看到 exit code 1 + "DATABASE_URL" 错误）时，
> 生成 `kanban_block(...)` 的 token 序列。

**叙事手法的建议：**
- 保留 "【AI 决策过程】" 作为解释 LLM 行为的工具
- 但应明确标注为"模拟的决策逻辑"，而非真实心理活动
- 增加"【LLM 实际可能的行为】"章节，展示失败模式

---

## 三、人的反应真实性评估

### 3.1 Jacky 的反应过于理性

**叙事中的 Jacky：**
> 每个决策都基于技术分析（RS256 vs HS256、token 旋转策略、覆盖率）
> 对 block 通知立即响应
> 对审查报告逐条审阅

**真实的"一人公司 CEO"可能的行为：**

```
【场景：收到 token 旋转策略 block 通知】

叙事版 Jacky：
  立即阅读三个选项的技术细节，分析安全性 vs 复杂度，
  1 分钟内回复选择 B。

真实版 Jacky（可能性 A：忙碌中）：
  手机震动，看了一眼 Telegram：
  "什么旋转策略？我在开会... 先选 A（最简单的）吧，
   反正 JWT 只是内部用的，安全性要求不高。"
  → 选择了最不安全的方案，埋下技术债务

真实版 Jacky（可能性 B：技术焦虑）：
  "选项 A 不安全？选项 B 需要 Redis？
   我连 staging 都没配好，怎么可能有 Redis...
   选项 C 是什么？滑动过期？
   算了，我不确定，让 Implementer 自己决定吧。"
  → 回复 "你决定"，但 Implementer 的 SOUL.md 要求遇到架构决策必须 block
  → 循环 block，任务卡死

真实版 Jacky（可能性 C：忽略）：
  手机静音，2 小时后才看到通知。
  此时 T2 已经 timeout（如果 timeout 设置不合理）。
  → Dispatcher 回收任务，重新 spawn，Implementer 重复之前的工作
  → 浪费 token 和时间

真实版 Jacky（可能性 D：过度干预）：
  "什么？Implementer 连这个都要问我？
   那我要 AI 团队干什么？
   让我直接看看代码..."
  → Jacky 打开代码，发现 Implementer 已经写了 200 行
  → Jacky 开始手动改代码，绕过整个 Kanban 流程
  → 系统状态混乱（人类直接修改 vs AI 任务流不同步）
```

### 3.2 对通知推送的反应

**叙事中：**
> Gateway 推送 → Jacky 立即查看并决策

**现实中：**
- Telegram/Discord 消息可能被淹没在群聊中
- 手机通知可能被系统归类为"低优先级"而静默
- Jacky 可能在深度工作中，设置了"勿扰模式"
- 连续多个项目的通知可能导致"通知疲劳"，Jacky 开始忽略所有 AI 团队的消息

**产品设计需考虑的机制：**
- 重要 block 是否需要重复通知（ escalating 通知策略）
- 是否支持"批量决策"（一次处理多个 block）
- 是否支持"代理决策"（让 PM 在 L2 层面做更多决策，减少 L3）

### 3.3 对"预计 4.3 小时"的反应

**叙事中：**
> Jacky 看到预计时间后，"今天下午应该能看到结果"

**现实中：**
- "4.3 小时"可能只是编码时间，不包括 Jacky 的决策延迟
- 如果 Jacky 每 30 分钟才看一次手机，总时间可能翻倍
- Jacky 可能对"4.3 小时"感到焦虑："这么久？我自己写可能 2 小时就搞定了"
- 或者 Jacky 可能完全不信："AI 说 4.3 小时，实际可能要 2 天"

### 3.4 对技术债务的反应

**叙事中：**
> Jacky 主动发现覆盖率不足、jti_blacklist 清理缺失等问题

**现实中：**
- Jacky 可能根本不会看 pitfalls
- 或者看了但不理解（"什么是 jti_blacklist？"）
- 或者觉得"以后再说"，导致债务积累

---

## 四、最严重的不准确项（需立即修正）

### 🔴 第 1 类：产品能力 vs 官方能力混淆

**问题：** 叙事中大量描述的功能（Risk Policy、背压、环境快照）被呈现为"系统正在运行"的机制，但实际上这些是产品的**增量设计**（R3-R24），不是 Hermes 官方已有的能力。SRE-Observer 已改为人工升级触发，Hermes 原生处理 crash/timed_out 恢复。

**影响：** Jacky 审核时会产生误解——"这些功能好像已经都有了，那我还需要开发什么？"

**修正建议：**
- 在叙事中明确标注 `[官方能力]` vs `[增量设计，待实现]`
- 或在文档开头增加免责声明

### 🔴 第 2 类：LLM 不会犯错

**问题：** 叙事中所有 AI 角色的输出都是正确的、高质量的、没有幻觉的。

**影响：** Jacky 会高估系统可靠性，对真实部署时的失败感到意外。

**修正建议：**
- 增加"失败模式"章节，展示每个角色可能犯的错误
- 在关键决策点展示"如果 AI 做错了，系统如何兜底"

### 🔴 第 3 类：人的反应过于理性

**问题：** Jacky 被描绘成一个 24/7 在线、技术全面、冷静理性的完美用户。

**影响：** 产品设计没有考虑真实用户的摩擦（延迟响应、技术盲区、情绪、注意力分散）。

**修正建议：**
- 增加"用户摩擦"章节
- 设计"escalating 通知"、"批量决策"、"代理决策"等机制

---

## 五、修正后的叙事原则

### AI 行为叙事原则

1. **显式规则依赖**：AI 的每个"正确行为"必须追溯到明确的 SOUL.md 规则或 skill 指导，而非"AI 自己想到了"
2. **展示失败模式**：每个角色至少展示 1-2 种可能的失败方式
3. **Retry 是常态**：任务可能 timeout、crash、产生错误输出，需要 retry 机制
4. **工具调用可能失败**：`kanban_create` 可能返回错误，`terminal` 可能返回非 0 exit code

### 人的反应叙事原则

1. **延迟响应**：人对 block 的响应可能有 5 分钟到几小时的延迟
2. **技术盲区**：人对某些技术术语不理解，需要简化解释
3. **情绪存在**：人对频繁 block 会感到烦躁，对崩溃会感到焦虑
4. **注意力有限**：人不会看所有通知，不会读所有 details

### 系统能力标注原则

1. **官方能力**：标注 `[Hermes 官方]`
2. **产品增量**：标注 `[Phase 19 增量，待实现]`
3. **设计假设**：标注 `[设计假设，需验证]`

---

## 六、具体修正清单

| 位置 | 当前内容 | 修正建议 |
|------|---------|---------|
| Phase 1 | Jacky 提交详细需求文档 | ✅ 已修正：Jacky 只提模糊需求，PM 从 CLAUDE.md 出发按需读代码发现技术上下文 |
| Phase 1 | 需求澄清选项无推荐标签 | ✅ 已修正：每个选项含⭐推荐标签 + 大白话理由 + "其他"选项 |
| Phase 1 | 需求澄清无验收层 | ✅ 已修正：新增 VERIFY 维度（如何验收/影响范围/可观测性） |
| Phase 1 | 澄清结果无证据 | ✅ 已修正：所有技术判断引用代码（文件:行号）或外部链接 |
| Phase 1 | 一次抛出所有问题 | ✅ 已修正：改为一次一问，逐步收缩，每轮基于上一轮回答优化下一个问题 |
| Phase 1 | 只有确认没有冲突检查 | ✅ 已修正：新增可行性检查，发现冲突时主动沟通（附证据和建议选项） |
| Phase 1→2 | 需求直接进入任务拆解 | ✅ 已修正：新增需求澄清阶段 → Research + POC 技术研判 → PM 任务拆解 |
| Phase 2.3 | PM 完美拆解 6 个任务 | 增加"如果拆解过细/过粗会怎样"的失败模式 |
| Phase 3.7 | Implementer 自修正 RS256 bug | 增加"如果 Implementer 没发现，Reviewer 如何兜底"的对比场景 |
| Phase 4.3 | Tech-Reviewer 发现 8 个问题 | 增加"Reviewer 可能遗漏或误报"的失败模式 |
| Phase 4.10 | Jacky 1 分钟内回复 block | 改为"Jacky 可能在开会，30 分钟后才看到"的真实场景 |
| Phase 5.4 | Implementer 主动 memory_add + create_skill | 明确说明"这需要 SOUL.md 中的显式规则引导" |
| Phase 5.5.2 | DevOps block（外部依赖缺失） | 改为真正的 crashed 场景（如 deploy.sh 执行错误命令）；Phase 5.6 三层部署流程中任一层失败触发 |
| Phase 5.5.3 | SRE-Observer 触发 | 改为人工升级触发；Hermes 原生处理 crash/timed_out 恢复 |
| 全局 | 所有 Plugin hooks | 标注 `[设计假设，需验证官方 Plugin SDK 支持]` |
| 全局 | Risk Policy Engine | 标注 `[Phase 19 增量]` |
| 全局 | 背压机制 | 标注 `[Phase 19 增量]` |
| 附录 B | 决策讨论 | 增加"这些决策的前提是什么官方能力已存在"的澄清；SRE-Observer 改为人工升级触发 |

### Round 4 修正（持续可行性检查 + DoR 门控 + 确认流程 + 追溯链）

| 位置 | 当前内容 | 修正建议 |
|------|---------|---------|
| Phase 1 设计原则 | 可行性检查在最后一次性做 | ✅ 已修正：可行性检查贯穿澄清全程，每确认一个关键维度就立刻检查 |
| Phase 1 Step 1.5 | 无研究任务触发机制 | ✅ 已修正：新增"何时暂停澄清发起 Research 任务"规则表 |
| Phase 1 Step 1.6 | 最后才做可行性检查 | ✅ 已修正：改为持续可行性检查，含 Q1/Q2/Q3 后的检查点 + 两个冲突沟通示例 |
| Phase 1 Step 1.7 | 需求文档生成后直接完成 | ✅ 已修正：新增 DoR 验证门（7项逐项检查，不通过自动补问） |
| Phase 1 Step 1.8 | 隐式接受，无确认关卡 | ✅ 已修正：Jacky 必须显式确认，支持"修改需求"回到对应澄清轮次 |
| Phase 1 Step 1.8 | 无需求版本控制 | ✅ 已修正：每次确认生成版本号（v1→v2→v3），记录变更摘要 |
| Phase 1 | 无需求追溯规范 | ✅ 已修正：新增 Step 1.8.5 追溯规范（US→Q编号→代码证据） |
| Phase 2 T1-T6 | metadata 无需求追溯 | ✅ 已修正：每个任务 metadata 含 requirement_version + covered_user_stories + covered_acceptance |
| Phase 2 Step 2.2 | PM 读取需求文档 | ✅ 已修正：反映读取已确认的 v1 文档+技术方案，含追溯链 |
| ascii-end-to-end | 可行性检查在最后 | ✅ 已修正：改为持续检查 + DoR 验证门 + 显式确认/修改流程 |
| workflow-appendix-timeline | 无 DoR 验证和确认步骤 | ✅ 已修正：新增 DoR 验证和 Jacky 确认 v1 步骤 |
| WORKFLOW-EXPLAINED | Phase 1 描述无 DoR/确认/版本 | ✅ 已修正：更新目录描述 |

### Round 5 修正（多需求排序 + 阻塞升级 + 收敛上限 + 质量反馈）

| 位置 | 当前内容 | 修正建议 |
|------|---------|---------|
| Phase 1 Step 1.3 | 无多需求处理机制 | ✅ 已修正：新增 Step 1.3.5 多需求优先级排序（价值/紧迫性/依赖/风险四维度） |
| Phase 1 Step 1.6 | 只有冲突（可调整范围），无阻塞（无法继续） | ✅ 已修正：新增 4 种阻塞类型 + 阻塞沟通示例 + 3 种处理策略 |
| Phase 1 Step 1.5.12 | "其他"选项无收敛上限 | ✅ 已修正：新增 Step 1.5.13 收敛机制（第 2 次合成摘要、第 3 次强制收敛） |
| Phase 1 Step 1.8 | 确认后无质量反馈 | ✅ 已修正：新增 Step 1.8.3 反馈问卷 + 反馈驱动优化机制 |

### Round 6 修正（Grill-with-docs 共识）

| 位置 | 设计决策 | 修正内容 |
|------|---------|---------|
| 设计原则 | 证据必须来自外部或实证 | ✅ 新增原则：不做推理，无外部证据则本地 POC |
| 设计原则 | 问题顺序动态 | ✅ 新增原则：11 维度固定覆盖，顺序由 PM 动态决定 |
| 设计原则 | 异步澄清 | ✅ 新增原则：PM 不被超时回收，支持暂停/恢复 |
| Step 1.4 | 技术发现一次性前置 | ✅ 改为按需触发，与澄清交织进行 |
| Step 1.4 | PM 工具权限未定义 | ✅ 新增权限说明：file_read + terminal(只读)，禁止写操作 |
| Step 1.5 | 问题顺序固定 Q1-Q11 | ✅ 改为动态顺序，问题池固定但顺序由 PM 决定 |
| Step 1.5.14 | 无崩溃恢复机制 | ✅ 新增：每轮通过 kanban comments 保存进度，崩溃后从检查点恢复 |
| Step 1.5.14 | 无异步处理规则 | ✅ 新增：不回复/Research 阻塞/暂停/多天/放弃 5 种场景的处理规则 |
| Step 1.8 | 修改需求无收敛限制 | ✅ 新增：同一维度最多 1 次收敛 + 1 次修改，第二次仍模糊则锁定 |
| REQUIREMENTS.md R11 | PM 禁用 file/terminal | ✅ 放宽为 file_read + terminal(只读) 允许，file_write + terminal(写) 禁止 |
| ascii-end-to-end | 技术发现一次性 | ✅ 改为按需触发 + 动态顺序 + 异步澄清 + 崩溃恢复 |
| WORKFLOW-EXPLAINED | Phase 1 描述 | ✅ 更新：按需发现/动态顺序/崩溃恢复/异步/交叉校正 |

### Round 7 修正（DoubleCheck 报告交叉验证）

基于 `WORKFLOW-HERMES-DOUBLE-CHECK.md` 的独立调查结果：

| # | DoubleCheck 发现 | 对设计文档的影响 | 修正内容 |
|---|-----------------|----------------|---------|
| 1 | Worker/Dispatcher/Gateway 官方已实现 | 无影响，设计文档已正确标注 | ✅ 无需修正 |
| 2 | L1/L2/L3 官方不存在，为项目独创 | DESIGN.md §6 需标注为项目设计概念 | ✅ 已修正：添加 `[项目设计概念，非官方机制]` 标注 |
| 3 | Risk Policy YAML 官方不存在 | DESIGN.md §6.2 需标注为项目增量 | ✅ 已修正：添加 `[项目增量，非官方机制]` 标注 |
| 4 | Sentinel 官方不存在 | 已在 VALIDATION-REPORT 标注 | ✅ 无需额外修正 |
| 5 | Reviewer Hard Gate 软约定有硬门无 | R10 已要求白名单+R8兜底 | ✅ 设计已覆盖 |
| 6 | **RFC #16102 明确支持 user-space approval gates** | DESIGN.md / REQUIREMENTS.md 需引用 | ✅ 已修正：§1、§6、§6.2、R6、Architecture Context 均添加 RFC 引用 |
| 7 | Plugin `pre_tool_call` hook 确认存在 | Risk Policy 实现路径已验证 | ✅ 已修正：DESIGN.md §6.2 添加 Plugin 实现路径推荐 |
| 8 | Plugin `post_tool_call` / `on_session_end` 确认存在 | Observability Plugin 实现已验证 | ✅ 已修正：DESIGN.md §9.2 + R19 添加验证状态 |
| 9 | 官方安全模型只有两层（命令级拦截） | 需区分官方能力与项目增量 | ✅ 已修正：DESIGN.md §6 说明区别 |
| 10 | 官方 `approvals.mode` 有 manual/smart/off 三模式 | DESIGN.md 附录 A 需补充 | ✅ 已修正：附录 A 添加条目 |

**DoubleCheck 报告核心结论：** 本项目设计文档与 Hermes 官方能力的边界划分基本正确。L1/L2/L3、Risk Policy、Sentinel 均为项目增量设计，有 RFC #16102 的官方背书支持通过 Plugin/Skill 层实现。Plugin Hook 名称（`pre_tool_call`、`post_tool_call`、`on_session_end`）已全部通过官方文档验证。

*本验证报告基于 Hermes Agent v0.13.0 官方文档（2026-05-09 索引）+ DoubleCheck 报告交叉验证（2026-05-10）*
