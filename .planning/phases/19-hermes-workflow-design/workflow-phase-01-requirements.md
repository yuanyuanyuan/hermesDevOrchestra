## Phase 1: 需求提交与澄清

> 📎 **相关 ASCII 流程图**：[`ascii-end-to-end.md`](./ascii-end-to-end.md) — Phase 1-2 需求提交→澄清→任务拆解
>
> **能力来源说明：** `kanban_create`/`kanban_show`/`kanban_block`/`kanban_complete` 工具、Profile 隔离、Dispatcher 派发属于 `[Hermes 官方]`。需求澄清方法论（一次一问/动态顺序/推荐标签/收敛机制）、Research + POC 技术研判流程、DoR 验证门、异步澄清（崩溃恢复/分级超时）、多需求优先级排序、持续可行性检查、需求版本控制属于 `[Phase 19 增量]`。

---

### 设计原则

**老板不会写详细需求文档。** Jacky 只会说：

> "用户体验太差了，每次都要重新登录"

**老板也不会给出技术细节。** 技术栈、数据库表结构、现有代码——这些由 PM 自己去读项目文件和代码来获取。如果需要调研外部内容（比如"JWT 和 Session 哪个适合我们"），PM 发起 Research 子任务（assignee: researcher），由 Researcher 产出技术方案提案。

**需求澄清必须输出证据。** 所有澄清结果不能是 AI "拍脑袋"给出的——必须引用具体的代码行、文档段落或外部链接，做到可追溯、可验证。

**默认一次一问，支持快速模式。** 默认模式：每次只问一个最关键的问题，根据老板的回答和已掌握的上下文来决定下一个问题。快速模式：如果前 3 轮回答都是「推荐选项」且无冲突触发，后续轮次可按维度层（价值/功能/验收/范围）合并为 2-3 个问题一批，减少异步轮次。老板可随时请求切换到快速模式。

**可行性检查贯穿始终。** 不是最后才一次性检查——每确认一个关键维度（目标、用户群体、时间、技术方案），就立刻检查可行性。发现冲突立即沟通，不让老板继续回答后续问题。越早发现冲突，浪费的澄清轮次越少。

**发现冲突要主动沟通。** 如果需求跟项目实际情况不一致、技术上无法实现、或者需求本身有逻辑问题，必须跟老板沟通澄清——而不是默默接受然后做不了。沟通时要有证据。

**证据分层要求。** 技术事实（框架版本、依赖、代码逻辑）必须引用代码（文件:行号），且引用后需再次 file_read 验证准确性。关键发现（如「无 auth 模块」）必须用 grep 搜索全代码库交叉验证。工作量估算标注为「LLM 估算，未经验证」。业务/行业判断优先使用外部佐证（搜索结果、行业报告）；对于标准行业实践（如「7 天免登录是 SaaS 常见做法」），PM 可基于领域知识给出建议并标注置信度，不必强制搜索。

**问题顺序遵循维度依赖图，冲突时动态调整。** 11 个维度必须全部覆盖，默认顺序为：目标→用户→时间→登录方式→现有处理→交互→验收→影响→可观测→MVP→技术方案。当可行性检查发现冲突时，可跳过或重排后续维度优先澄清冲突项。如果用户输入已隐含某些维度（如「企业 SSO」隐含了用户群体），可跳过已回答的维度。

**澄清流程是异步的，但有分级超时。** 老板可能中途去开会、出差、睡觉。每轮通过 kanban comments 保存进度，崩溃后可从检查点恢复（v1 依赖自然语言 comments 恢复上下文）。但澄清任务不能无限期阻塞：24h 未回复发送提醒 → 72h 升级通知渠道 → 7 天标记为 stale 并通知将在 48h 后归档 → 归档后回到 backlog 不阻塞 Board。同一时间只允许一个需求处于「等待用户回答」状态，其他排队。

---

### 活跃角色（8 profiles）

| 角色 | 职责 |
|------|------|
| **pm** | 需求分析、任务分解、任务分配 |
| **orchestrator** | 派发/监控/消息路由（状态机驱动，不做分析） |
| **researcher** | 技术方案调研（不写代码） |
| **implementer** | TDD 编码（RED→GREEN）、回归测试、POC 验证 |
| **tech-reviewer** | 代码审查（hard gate + 只读） |
| **qa-tester** | 验收测试 |
| **devops-engineer** | 部署与环境配置 |
| **sre-observer** | 故障分析（仅手动升级触发） |

---

### 需求澄清方法论

| 维度 | 澄清目标 | 参考来源 |
|------|---------|---------|
| **价值层** WHY | 为什么做？给谁做？解决什么问题？ | Impact Mapping, Jobs-to-be-Done |
| **功能层** WHAT | 做什么？用户故事是什么？验收标准是什么？ | User Story Mapping, INVEST 原则 |
| **验收层** VERIFY | 如何验收？影响范围？可观测性？ | Definition of Done, Observability-Driven |
| **范围层** BOUNDARY | MVP 包含什么？不包含什么？优先级？ | MoSCoW, Scope Boundary |

**Definition of Ready 标准**（需求必须满足才能进入任务拆解）：

```
✅ 价值层：WHY 已明确（业务目标、用户群体、成功指标）
✅ 功能层：用户故事已定义，验收标准可测试
✅ 验收层：验收方式已确认，影响范围已识别，可观测性已确认
✅ 范围层：MVP 边界已划定，排除项已列出
✅ 可行性：需求与项目现实一致，无未解决的冲突或阻塞项
✅ 证据链：所有技术判断有代码/文档/链接佐证
✅ 无歧义：任何角色（Implementer/Reviewer/QA）都能独立理解
```

### 选项设计规范

每个澄清选项必须包含：

```
[标签] 选项文本
  理由：用大白话解释为什么选/不选这个
  推荐标记：⭐ 推荐 / ○ 可选 / △ 需谨慎
```

同时每个问题必须包含"其他"选项：

```
[其他] 我有别的想法 → 触发追加澄清轮次
```

当老板选择"其他"并输入自定义内容后，因为输入是模糊的，系统必须发起**追加澄清轮次**来细化这个自定义答案。

---

### Step 1.1: Jacky 产生需求

**【场景上下文】**
早上 9:30，Jacky 在 Review Alpha 项目的 backlog。用户反馈说"每次操作都要重新登录，体验很差"。

**【Jacky 心理活动】**
> "用户抱怨好几次了。我得改善登录体验。
> 但具体怎么做我不知道——JWT？Session？第三方服务？
> 我也不清楚现在的代码是什么结构，让 AI 自己去研究吧。"

---

### Step 1.2: Jacky 向系统提交原始需求

**【Jacky 对白】**

Jacky 打开终端，输入：

```bash
$ hermes kanban boards switch project-alpha
$ hermes kanban create \
    --title "改善登录体验：减少用户重复登录" \
    --body "用户反馈每次重启浏览器都要重新登录，体验很差。需要改善。" \
    --assignee pm \
    --triage
```

注意：Jacky **没有**给出技术栈、数据库表结构、框架版本等技术细节。他只描述了问题。

---

### Step 1.3: Dispatcher 派发 PM

**【系统内部】Dispatcher 决策日志：**

```
[2026-05-10T09:31:02Z] Dispatcher cycle start
[2026-05-10T09:31:02Z] Board: project-alpha
[2026-05-10T09:31:02Z] Triage tasks: [t_alpha_001]
[2026-05-10T09:31:02Z] Promoting t_alpha_001: triage → ready
[2026-05-10T09:31:02Z] Claiming t_alpha_001 (atomic)
[2026-05-10T09:31:02Z] Spawning worker: pm
[2026-05-10T09:31:03Z] Worker PID: 18473
```

---

### Step 1.3.5: 多需求优先级排序 `[Phase 19 增量]`

**【场景】** Jacky 可能一次性提交多个需求，或 Board 上已有多个待处理需求。默认的 FIFO（先到先处理）不一定合理。

**【PM 执行优先级排序】**

```python
# PM 被派发后，先检查 Board 上所有 triage 需求
triage_tasks = kanban_list(board="project-alpha", status="triage")

# 如果有多个需求，先排序再逐个处理
if len(triage_tasks) > 1:
    prioritized = prioritize_requirements(triage_tasks)
```

**【排序维度】**

| 维度 | 权重 | 判断依据 |
|------|------|---------|
| **业务价值** | 高 | 影响用户数 × 影响程度 |
| **时间紧迫性** | 高 | 有明确 deadline 的优先 |
| **依赖关系** | 中 | 被其他需求依赖的优先 |
| **技术风险** | 中 | 不确定性高的优先（需要先验证可行性） |

**【PM 向 Jacky 确认排序】**

```python
clarify(
    question={
        "id": "PRIORITIZE",
        "question": "当前有 3 个待处理需求，建议按以下顺序处理：",
        "options": [
            {
                "label": "A) 按建议顺序: ①登录改善 → ②搜索优化 → ③首页改版",
                "reason": "①用户最频繁反馈，②影响所有用户，③不急。①的认证模块可能是②③的前置依赖。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 全部并行处理",
                "reason": "同时澄清 3 个需求，但你的注意力会分散，每轮要回答 3 个问题。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "C) 只做最重要的 1 个",
                "reason": "集中精力，其他排队。适合你很忙的时候。",
                "recommend": "○ 可选",
            },
            {
                "label": "其他",
                "reason": "想调整顺序？请说明。",
            },
        ],
    }
)
```

**【排序后的处理策略】**
- **串行处理**（推荐）：按优先级逐个澄清，一个完成后再处理下一个
- **并行处理**（谨慎）：同时澄清多个需求，但每轮需回答多个问题，容易混乱
- **Jacky 可随时调整排序**：新需求插入时重新排序

---

### Step 1.4: PM 自动发现技术上下文 `[Phase 19 增量]`

**【PM 工具权限】**

> PM 允许 `file_read` + `terminal(只读)`，禁止 `file_write` + `terminal(写操作)`。
> 这是 R11 的放宽版本——PM 需要读代码来理解项目上下文，但不能亲自写代码。
> 详见 REQUIREMENTS.md R11 修订。

**【技术发现：按需触发，与澄清交织】**

技术发现不是一次性的前置步骤——它与澄清过程交织进行：

| 触发时机 | 行为 |
|---------|------|
| **初始发现**（澄清开始前） | 从 CLAUDE.md 出发，建立基础技术画像 |
| **用户选"其他"时** | 如果输入引入了新的技术概念（如 Redis），触发针对性发现 |
| **可行性检查发现盲区时** | 如果检查需要的数据不在初始发现中，触发补充发现 |
| **每轮澄清后** | 如果回答改变了技术方向，更新技术画像 |

**【PM 内心OS】**

> "Jacky 只说了'登录体验差'，没给任何技术细节。
> 我需要自己去读项目代码和文档，搞清楚现有系统是什么样的。
> 先做初始发现，后续根据 Jacky 的回答按需补充。"

**【初始技术发现（澄清开始前）】**

初始发现遵循"从入口出发、按需深入"的原则：

```python
# ===== 第一步：读取项目入口文件 =====
# Claude Code 项目读 CLAUDE.md，其他项目读 AGENTS.md
# 入口文件通常包含：项目结构、约定、常用命令、关键路径
file_read("CLAUDE.md")  # 或 AGENTS.md
# → 发现: 项目是 Rust + Axum + PostgreSQL
# → 发现: 代码在 src/，测试在 tests/
# → 发现: 项目约定、命名规范等

# ===== 第二步：根据入口文件的指引，按需读取 =====
# 入口文件通常会指向关键目录和文件，不需要盲目扫描

# 读取项目依赖（入口文件可能指向 Cargo.toml）
file_read("Cargo.toml")
# → 发现: axum 0.7, sqlx, argon2, serde, 无 JWT 依赖
#   引用: Cargo.toml:15,18,20

# 根据入口文件或 Cargo.toml 的指引，读取源码结构
terminal("tree -L 3 src/")
# → 发现: src/routes/users.rs, src/middleware/, 无 src/auth/

# 按需深入：用户模型（与"登录"需求直接相关）
file_read("src/models/user.rs")
# → 发现: User { id, email, password_hash, created_at }
#   引用: src/models/user.rs:12-18

# 按需深入：现有登录逻辑（需求核心）
file_read("src/routes/users.rs")
# → 发现: POST /users/login 使用 session-based 认证
#   引用: src/routes/users.rs:45-72

# 按需深入：中间件链（影响 auth 中间件插入位置）
file_read("src/middleware/mod.rs")
# → 发现: trace → cors → rate_limit，无 auth 中间件
#   引用: src/middleware/mod.rs:8-15

# 如果入口文件有测试相关指引
file_read("tests/")  # 或根据 CLAUDE.md 的指引
# → 发现: 现有测试框架和运行方式
```

**【PM 生成技术发现报告】**

```markdown
## 技术发现报告 (project-alpha)

### 发现路径
CLAUDE.md → Cargo.toml → src/ → 按需深入具体文件

### 证据来源
| 发现 | 文件路径 | 行号 | 内容摘要 |
|------|---------|------|---------|
| 框架: Axum 0.7.9 | Cargo.toml | L15 | `axum = "0.7"` |
| 数据库: PostgreSQL + sqlx | Cargo.toml | L18 | `sqlx = { version = "0.7", features = ["postgres"] }` |
| 密码哈希: argon2 | Cargo.toml | L20 | `argon2 = "0.5"` |
| 用户模型 | src/models/user.rs | L12-18 | `User { id, email, password_hash, created_at }` |
| 现有登录: session-based | src/routes/users.rs | L45-72 | `POST /users/login` 使用 session |
| 中间件链 | src/middleware/mod.rs | L8-15 | `trace → cors → rate_limit`（无 auth） |
| 无 auth 模块 | src/ 目录 | — | `tree` 输出无 src/auth/ 目录 |
| 无 JWT 依赖 | Cargo.toml | — | 无 jsonwebtoken / ring 等 |

### 关键约束（基于代码证据）
- 现有 users 表只有 4 个字段，新增字段需要 migration
- 现有 /users/login 接口需要兼容或替换
- 中间件链需要在 rate_limit 后插入 auth 中间件
- 无现有 auth 模块，需从零搭建
```

**【证据验证步骤】**

技术发现报告生成后，PM 必须对关键发现进行交叉验证：

```python
# 关键发现验证（必须执行）
# 1. 「无 auth 模块」→ grep 搜索全代码库
terminal("rg -l 'auth|session|login' src/")
# → 如果搜索结果显示其他文件也有 auth 逻辑，标记为「待人工确认」

# 2. 「仅登录接口使用 session」→ 搜索 session 使用点
terminal("rg 'session' src/routes/")
# → 如果其他路由也使用 session，影响范围需要扩大

# 3. 文件引用验证 → 再次 file_read 确认行号内容
file_read("src/routes/users.rs", offset=44, limit=28)
# → 确认 L45-72 确实包含 session-based 认证逻辑
```

---

### Step 1.5: PM 执行需求澄清流程（一次一问，逐步收缩，维度依赖图驱动顺序）

**【核心设计：一次一个问题，维度依赖图驱动顺序，冲突时动态调整】**

需求澄清不是一次性抛出所有问题，而是**一次问一个最关键的问题**，根据老板的回答和已掌握的上下文来决定下一个问题。**11 个维度必须全部覆盖**，默认顺序为：目标→用户→时间→登录方式→现有处理→交互→验收→影响→可观测→MVP→技术方案。当可行性检查发现冲突时，可跳过或重排后续维度优先澄清冲突项。如果用户输入已隐含某些维度，可跳过已回答的维度。支持快速模式：前 3 轮无冲突时可按层合并后续问题。

每一轮：

1. 检查 Definition of Ready — 哪些维度还没满足？
2. 检查可行性约束 — 哪些维度有冲突需要优先澄清？
3. 检查依赖关系 — 有些问题需要先回答其他问题（如 MVP 范围依赖于目标和时间）
4. 选择当前"最关键"的一个问题，给出选项（含推荐标签+大白话理由+"其他"）
5. 老板回答后，更新已知信息，触发按需技术发现和可行性检查
6. 重复，直到所有维度都满足 Definition of Ready

**【动态顺序示例】**

标准路径（参考，非固定脚本）：Q1(目标) → Q2(用户) → Q3(时间) → Q4(登录方式) → ...

但如果技术发现阶段就发现项目没有 Redis，而 Jacky 选了"用 Redis 做 session"：
- PM 立即触发可行性冲突沟通，而不是继续问 Q6-Q11
- 冲突解决后，根据新的上下文决定下一个问题

如果 Jacky 在 Q1 选了"其他"并引入了全新概念（如"企业 SSO"）：
- PM 触发针对性技术发现
- 可能跳过 Q2（用户群体已隐含在"企业"中），直接问 Q4（登录方式）

**需求逐步收缩示意：**

```
初始状态: "改善登录体验" — 什么都可能

Q1 后: 目标收敛为"7天免登录" — 排除了"记住我"和"安全超时"
Q2 后: 用户确认为"外部付费客户" — 安全标准确定
Q3 后: 时间确认为"1-2周" — 方案复杂度有上界
Q4 后: 功能确认为"邮箱+密码" — 排除了第三方登录
Q5 后: 策略确认为"替换session" — 排除了叠加方案
Q6 后: 交互确认为"静默刷新" — 排除了弹窗和跳转
Q7 后: 验收确认为"自动化+手动" — 测试策略确定
Q8 后: 影响范围确认为"仅登录接口" — 回归范围确定
Q9 后: 可观测性确认为"基础日志" — 监控策略确定
Q10后: MVP确认为"完整认证流程" — 功能边界确定
Q11后: 实现方式确认为"第三方库" — 技术方案确定

最终状态: 无歧义，任何角色可执行
```

---

#### 1.5.1 第 1 问：核心目标（价值层 — 最关键的问题先问）

**【PM 内心OS】**

> "Jacky 说'登录体验差'，但具体要改善到什么程度？
> 这是最核心的问题，决定了后面所有技术选型的方向。
> 先问这一个。"

```python
clarify(
    question={
        "id": "Q1",
        "question": "你说的'改善登录体验'，具体想达到什么效果？",
        "options": [
            {
                "label": "A) 7 天内不用重新登录",
                "reason": "大多数 SaaS 产品用这个标准。用户关掉浏览器第二天打开还是登录状态，体验最好。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 永远不用重新登录（记住我）",
                "reason": "体验最好但安全风险高。如果用户电脑被别人用了，账号就一直登录着。",
                "recommend": "○ 可选",
            },
            {
                "label": "C) 减少登录频率但保留安全超时",
                "reason": "折中方案。比如 2 小时超时，但刷新页面不重新登录。适合安全要求高的场景。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "其他",
                "reason": "以上都不符合你的想法？请描述你期望的效果。",
            },
        ],
        "context": "不同目标对应不同的技术方案和安全等级。代码发现: 现有系统是 session-based（src/routes/users.rs:45），任何方案都需要改动。"
    }
)
```

**【Jacky 回复】**
> "选 A — 7 天不用重新登录就行。"

**【PM 更新上下文】**
```
已知信息更新:
+ 目标: 7 天免登录（长会话）
+ 排除: "记住我"（无限期）、"安全超时"（短会话）
下一步: 确认用户群体（影响安全标准）
```

---

#### 1.5.2 第 2 问：用户群体（价值层 — 基于 Q1 的目标推导）

**【PM 内心OS】**

> "Q1 确认了 7 天免登录。接下来要知道给谁用——
> 外部客户和内部团队的安全要求完全不同。"

```python
clarify(
    question={
        "id": "Q2",
        "question": "这个产品是给谁用的？（影响安全标准）",
        "options": [
            {
                "label": "A) 外部付费客户",
                "reason": "安全标准高，token 策略要保守。客户数据泄露是大事。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 内部团队成员",
                "reason": "安全要求相对低，可以更激进地优化体验。",
                "recommend": "○ 可选",
            },
            {
                "label": "C) 两者都有",
                "reason": "需要区分角色做不同策略，复杂度翻倍。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "其他",
                "reason": "有特殊的用户群体？请描述。",
            },
        ],
        "context": "结合 Q1（7天免登录）：如果是外部客户，7 天是行业标准；如果是内部，可以更长。"
    }
)
```

**【Jacky 回复】**
> "选 A — 外部付费客户。"

**【PM 更新上下文】**
```
已知信息更新:
+ 用户群体: 外部付费客户
+ 安全标准: 高（客户数据敏感）
+ 推导: 7天免登录 + 外部客户 → JWT 是合适方案（无状态、可扩展）
下一步: 确认时间压力（影响方案复杂度）

# === 可行性检查: Q1+Q2 后 ===
# "7天免登录"技术上需要 JWT（access+refresh），这是标准做法。
# 外部客户 + 7天 是行业标准（Google 14天，GitHub 14天）。
# 当前无 JWT 依赖（E7），需要新增 — 可行，不是阻塞项。
# → 通过，继续澄清
```

---

#### 1.5.2.5: 何时需要暂停澄清，发起 Research 任务 `[Phase 19 增量]`

在澄清过程中，如果遇到以下情况，**暂停澄清流程**，先发起 research 任务：

| 触发条件 | 示例 | Research 类型 |
|---------|------|--------------|
| 涉及外部系统的技术选型 | "JWT vs Session 哪个更适合我们？" | 技术调研 |
| 需要评估第三方服务 | "要用 Stripe 还是自建支付？" | 服务对比 |
| 涉及行业合规标准 | "GDPR 对用户数据有什么要求？" | 合规调研 |
| 老板提到竞品功能 | "像 Notion 那样的协作编辑" | 竞品分析 |
| 项目依赖的外部 API | "集成 Google OAuth 需要什么条件？" | API 调研 |

**Research + POC 流程：**

PM 判断技术不确定性高时，创建 Research 子任务（assignee: researcher）。Researcher 产出技术方案提案（不写代码）。如果方案需要验证，PM 创建 POC 子任务（assignee: implementer），Implementer 在隔离 worktree 中完成 POC。

```
PM 判断不确定性高
    → 创建 Research 子任务 (assignee: researcher)
    → Researcher 产出技术方案提案
    → PM 评估方案，判断是否需要 POC
        → 需要: 创建 POC 子任务 (assignee: implementer)
              → Implementer 在隔离 worktree 中验证
        → 不需要: 直接进入任务拆解
```

**Research 结果处理：**
- 研究结果作为**新证据**加入证据索引（如 E9: "JWT vs Session 对比分析"）
- 如果研究结论与老板偏好**冲突**，作为可行性问题与老板沟通（附研究证据）
- Research 任务完成后，**从暂停点继续**澄清流程

---

#### 1.5.3 第 3 问：时间压力（价值层 — 收束方案复杂度上界）

```python
clarify(
    question={
        "id": "Q3",
        "question": "这个需求有没有时间压力？",
        "options": [
            {
                "label": "A) 本周内必须上线",
                "reason": "只做最小改动——在现有登录上加 token 刷新，不做大重构。",
                "recommend": "○ 可选",
            },
            {
                "label": "B) 1-2 周内完成",
                "reason": "可以做完整的认证模块替换，质量有保障。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "C) 不急，做好就行",
                "reason": "可以加上密码重置、邮箱验证等完整功能。",
                "recommend": "○ 可选",
            },
            {
                "label": "其他",
                "reason": "有具体的截止日期？请说明。",
            },
        ],
        "context": "结合 Q1+Q2（7天免登录+外部客户）：需要 JWT + 安全审计，1-2 周是比较合理的周期。"
    }
)
```

**【Jacky 回复】**
> "选 B — 1-2 周内搞定。"

**【PM 更新上下文】**
```
已知信息更新:
+ 时间: 1-2 周
+ 方案复杂度上界: 可以做完整认证模块替换，不需要最小改动
+ 价值层已完整: WHY 收束完毕
下一步: 进入功能层 — 登录方式
```

---

#### 1.5.4 第 4 问：登录方式（功能层 — 基于代码发现）

```python
clarify(
    question={
        "id": "Q4",
        "question": "登录方式需要支持哪些？（代码发现: 现有系统只支持邮箱+密码，见 src/routes/users.rs:45）",
        "options": [
            {
                "label": "A) 只做邮箱+密码",
                "reason": "现有系统已经有邮箱+密码登录，在此基础上加 token 刷新就行。改动最小。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 邮箱+密码 + 第三方登录（Google/GitHub）",
                "reason": "需要接入 OAuth，工作量约 3 倍。建议作为第二期。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "C) 邮箱+密码 + SSO（企业单点登录）",
                "reason": "需要 SAML/OIDC 集成，复杂度很高。除非客户明确要求。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "其他",
                "reason": "有其他登录方式需求？请描述。",
            },
        ],
        "context": "代码证据: src/routes/users.rs:45-72 现有 POST /users/login 只支持邮箱+密码。Q3 确认了 1-2 周，只做邮箱+密码时间最充裕。"
    }
)
```

**【Jacky 回复】**
> "选 A — 只做邮箱+密码。"

---

#### 1.5.5 第 5 问：现有登录处理方式（功能层 — 基于 Q4 和代码发现）

```python
clarify(
    question={
        "id": "Q5",
        "question": "现有的 session-based 登录怎么处理？（现有实现在 src/routes/users.rs:45-72）",
        "options": [
            {
                "label": "A) 直接替换为 JWT",
                "reason": "代码更干净，没有技术债。但现有用户的 session 会全部失效，需要重新登录一次。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 在现有基础上叠加 token 刷新",
                "reason": "改动小，现有用户无感知。但 session + JWT 两套机制共存，代码会变复杂。",
                "recommend": "○ 可选",
            },
            {
                "label": "其他",
                "reason": "有其他想法？请描述。",
            },
        ],
        "context": "代码证据: src/routes/users.rs:45-72 使用 session-based 认证。Q2 确认了外部客户但用户量小，替换影响可控。"
    }
)
```

**【Jacky 回复】**
> "选 A — 直接替换掉 session。"

---

#### 1.5.6 第 6 问：token 过期交互（功能层 — 基于 Q1+Q5 推导）

```python
clarify(
    question={
        "id": "Q6",
        "question": "token 过期后用户应该怎么感知？（Q1 确认了 7 天免登录，Q5 确认了替换 session）",
        "options": [
            {
                "label": "A) 静默刷新，用户完全无感知",
                "reason": "体验最好。access token 过期时自动用 refresh token 换新的，用户什么都不用做。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 弹窗提示'会话即将过期，是否续期'",
                "reason": "用户有知情权，但会打断操作流程。适合安全要求高的金融类应用。",
                "recommend": "○ 可选",
            },
            {
                "label": "C) 直接跳转登录页",
                "reason": "最简单但体验最差。用户正在填表单突然跳到登录页，之前填的内容可能丢失。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "其他",
                "reason": "有其他交互设计想法？请描述。",
            },
        ],
        "context": "Q1 目标是'7天不用重新登录'，静默刷新最符合这个目标。技术上需要 access token + refresh token 双 token 机制。"
    }
)
```

**【Jacky 回复】**
> "选 A — 静默刷新。"

**【PM 更新上下文】**
```
已知信息更新:
+ 功能层核心已确定: 邮箱+密码 + 替换session + 静默刷新
+ 推导: 需要 JWT(access+refresh) + auth 中间件
下一步: 进入验收层 — 如何验证
```

---

#### 1.5.7 第 7 问：验收方式（验收层）

```python
clarify(
    question={
        "id": "Q7",
        "question": "如何验证'7 天免登录'这个核心需求已实现？",
        "options": [
            {
                "label": "A) 自动化测试覆盖",
                "reason": "写测试用例模拟：登录→等 token 过期→自动刷新→继续操作。可重复验证，不会遗漏。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 手动测试",
                "reason": "人工登录后等 15 分钟（access token 过期），再操作看是否自动刷新。简单但不可重复。",
                "recommend": "○ 可选",
            },
            {
                "label": "C) 两者都要",
                "reason": "自动化测试保证质量，手动测试做最终验收。最稳妥但工作量最大。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "其他",
                "reason": "有其他验收方式？请描述。",
            },
        ],
        "context": "代码发现: 项目现有测试在 tests/ 目录，使用 cargo test 运行。Q3 确认了 1-2 周，两者都要的时间是够的。"
    }
)
```

**【Jacky 回复】**
> "选 C — 自动化+手动都要。"

---

#### 1.5.8 第 8 问：影响范围（验收层 — 基于代码分析）

```python
clarify(
    question={
        "id": "Q8",
        "question": "这个改动会影响哪些现有功能？（基于代码分析）",
        "options": [
            {
                "label": "A) 只影响登录/登出相关接口",
                "reason": "代码证据: src/routes/users.rs 中的 /login 和相关接口。其他接口不受影响。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 可能影响所有需要认证的接口",
                "reason": "如果替换 session 为 JWT，所有依赖 session 的中间件都需要改。需要全面回归测试。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "其他",
                "reason": "有其他担心的影响范围？请描述。",
            },
        ],
        "context": "代码证据: src/middleware/mod.rs:8-15 现有中间件链 trace→cors→rate_limit 无 auth 环节。⚠️ 交叉验证: 当 Q5='替换session' 时，必须用 grep 搜索全代码库的 session 使用点（不仅是中间件链），确认是否有其他路由依赖 session。如果发现其他路由使用 session，应推荐选项 B。"
    }
)
```

**【Jacky 回复】**
> "选 A — 只影响登录接口。"

---

#### 1.5.9 第 9 问：可观测性（验收层）

```python
clarify(
    question={
        "id": "Q9",
        "question": "需要可观测性支持吗？（即：能否看到认证系统的运行状态）",
        "options": [
            {
                "label": "A) 基础日志即可",
                "reason": "记录登录成功/失败、token 刷新、异常等关键事件。够用且不增加复杂度。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 需要结构化指标",
                "reason": "需要知道：每天多少人登录、刷新成功率、平均 token 寿命等。适合数据驱动决策。",
                "recommend": "○ 可选",
            },
            {
                "label": "C) 暂不需要",
                "reason": "先跑起来再说，后面需要再加。",
                "recommend": "○ 可选",
            },
            {
                "label": "其他",
                "reason": "有特殊的监控需求？请描述。",
            },
        ],
        "context": "系统已有 Observability Plugin 框架（post_tool_call hook），可复用。Q2 确认了外部客户，基础日志是必须的。"
    }
)
```

**【Jacky 回复】**
> "选 A — 基础日志就行。"

**【PM 更新上下文】**
```
已知信息更新:
+ 验收层已完整: 自动化+手动、仅登录接口、基础日志
下一步: 进入范围层 — MVP 功能边界
```

---

#### 1.5.10 第 10 问：MVP 功能范围（范围层）

```python
clarify(
    question={
        "id": "Q10",
        "question": "MVP 阶段要做哪些功能？",
        "options": [
            {
                "label": "A) 只做登录+自动刷新（最小 MVP）",
                "reason": "最快上线。只改现有 /login 接口，加 token 刷新机制。2-3 天搞定。",
                "recommend": "○ 可选",
            },
            {
                "label": "B) 登录+注册+刷新+登出（完整认证流程）",
                "reason": "覆盖用户生命周期。注册是新用户入口，登出是安全必须。1-2 周。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "C) 完整认证 + 密码重置 + 邮箱验证",
                "reason": "最完整但工作量大。密码重置需要邮件服务，邮箱验证也需要邮件。3-4 周。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "其他",
                "reason": "有其他功能需要包含？请描述。",
            },
        ],
        "context": "代码证据: 现有 src/routes/users.rs 只有 login，无 register/logout/refresh。Q3 确认了 1-2 周，B 选项刚好匹配。"
    }
)
```

**【Jacky 回复】**
> "选 B — 做完整认证流程。"

---

#### 1.5.11 第 11 问：实现方式（范围层 — 技术方案确认）

```python
clarify(
    question={
        "id": "Q11",
        "question": "JWT 实现方式？（代码发现: 现有 Cargo.toml 无 JWT 相关依赖）",
        "options": [
            {
                "label": "A) 用成熟的第三方库（如 jsonwebtoken）",
                "reason": "经过社区验证，安全可靠。工作量小，专注业务逻辑。代码证据: Cargo.toml 中无 crypto 相关依赖，需要新增。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 自己用 ring 底层库实现",
                "reason": "对 crypto 有完全控制，但工作量约 3 倍，且容易出安全 bug。适合学习但不适合生产。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "C) 你来决定",
                "reason": "让 AI 根据项目情况选择最合适的方案。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "其他",
                "reason": "有其他技术偏好？请描述。",
            },
        ],
        "context": "代码证据: Cargo.toml 无 ring/jsonwebtoken 等依赖，需要新增。Q3 确认了 1-2 周，用第三方库时间最充裕。"
    }
)
```

**【Jacky 回复】**
> "选 A — 用第三方库。"

**【PM 更新上下文】**
```
所有维度已满足 Definition of Ready:
✅ 价值层: 7天免登录, 外部客户, 1-2周
✅ 功能层: 邮箱+密码, 替换session, 静默刷新, 完整认证流程
✅ 验收层: 自动化+手动, 仅登录接口, 基础日志
✅ 范围层: 登录+注册+刷新+登出, 第三方库
✅ 可行性: 无冲突（下面检查）
✅ 证据链: 8项代码证据
✅ 无歧义: 所有选项已明确选择
```

---

### Step 1.5.12: "其他"选项的追加澄清示例

假设 Jacky 在 Q1 选择了"其他"并输入：

> "我希望用户可以选择记住登录状态，但安全要求高的操作（比如修改密码、删除账号）还是需要重新验证"

这是一个模糊的需求，PM 发起**追加澄清**（继续一次一问）：

**【追加第 1 问】**

```python
clarify(
    question={
        "id": "Q1_followup_1",
        "question": "你提到'安全要求高的操作需要重新验证'，具体指哪些操作？",
        "options": [
            {
                "label": "A) 修改密码、删除账号、修改绑定邮箱",
                "reason": "这些操作一旦执行不可逆，需要确认是本人操作。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 所有写操作（创建/修改/删除）都需要",
                "reason": "最安全但体验差。用户每次保存都要重新输入密码。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "C) 涉及资金的操作（充值/提现/付款）",
                "reason": "金融场景的标准做法。如果 Alpha 不涉及资金，不需要。",
                "recommend": "○ 可选",
            },
            {
                "label": "其他",
                "reason": "有其他操作需要重新验证？请描述。",
            },
        ],
        "context": "这影响 auth 中间件的设计——需要区分'普通认证'和'敏感操作认证'。"
    }
)
```

**【Jacky 回复】**
> "选 A — 修改密码、删除账号、修改绑定邮箱。"

**【追加第 2 问】**（基于上一问的回答继续深入）

```python
clarify(
    question={
        "id": "Q1_followup_2",
        "question": "'重新验证'具体是什么方式？",
        "options": [
            {
                "label": "A) 重新输入密码",
                "reason": "最传统的方式，安全可靠。代码证据: 现有系统用 argon2（Cargo.toml:20），可以直接验证密码。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 输入一次性验证码（邮件/短信）",
                "reason": "不需要记住密码，但需要邮件/短信服务。增加外部依赖。",
                "recommend": "○ 可选",
            },
            {
                "label": "C) 确认弹窗（'确定要执行此操作吗？'）",
                "reason": "最简单但安全级别最低。适合内部系统，不适合面向客户（Q2 确认了外部客户）。",
                "recommend": "△ 需谨慎",
            },
            {
                "label": "其他",
                "reason": "有其他验证方式？请描述。",
            },
        ],
        "context": "Q2 确认了外部付费客户，安全标准高。重新输入密码是最稳妥的选择。"
    }
)
```

**【Jacky 回复】**
> "选 A — 重新输入密码。"

追加澄清完成后，这些内容会被合并到最终需求文档中。

---

#### 1.5.13: "其他"选项的收敛机制 `[Phase 19 增量]`

**【问题】** 如果老板对同一个问题反复选择"其他"，可能是选项设计不足，也可能是用户表达模糊。

**【收敛规则 — 2-strike】**

| 次数 | 系统行为 |
|------|---------|
| 第 1 次 | 正常追加澄清（如 Step 1.5.12 所述） |
| 第 2 次 | 标记该维度为 `[待后续细化]`，用默认值继续，不阻塞整体流程 |

**【第 2 次"其他"的处理】**

```python
# 老板第 2 次选择"其他"并输入新内容
# → 先诊断：是选项设计不足还是用户确实模糊？

# 如果用户输入清晰但不在选项中 → 接受用户输入，标记为「用户自定义」
# 如果用户输入仍然模糊 → 用默认值收敛

pm_action = {
    "dimension": "Q1_核心目标",
    "status": "converged_with_default",  # 或 "user_custom"
    "default_value": "7天免登录（最简方案）",
    "unresolved_details": [
        "敏感操作验证方式 — 标记为待细化",
    ],
    "action": "用默认值继续后续澄清，待细化项在需求文档中单独列出，后续迭代处理",
}
```

**【收敛后的处理】**
- 被收敛的维度在需求文档中标注为 `[待细化]`
- PM 在 DoR 验证时，`[待细化]` 项不算未通过，但会提醒 Jacky
- 后续迭代时，这些项会被优先处理

---

#### 1.5.14: 崩溃恢复与异步澄清 `[Phase 19 增量]`

**【崩溃恢复：通过 kanban comments 保存进度】**

澄清过程中，PM 每轮回答后将当前进度写入 task comments（自然语言格式，v1 不使用结构化 JSON checkpoint）：

```python
# 每轮澄清后保存进度（自然语言）
kanban_comment(
    task_id="t_alpha_001",
    body="""澄清进度更新：
- 已完成：Q1(目标=7天免登录) Q2(用户=外部客户) Q3(时间=1-2周) Q4(登录=邮箱密码)
- 待澄清：token过期交互、验收方式、影响范围、可观测性、MVP范围、技术方案
- 技术发现：Axum 0.7 + PostgreSQL + session-based 认证，无 JWT 依赖
- 冲突：无
- 下一步：Q5 — 现有 session 处理方式"""
)
```

**【崩溃后恢复流程】**

```
PM 崩溃/超时
    ↓
Dispatcher 回滚任务到 ready，重新 spawn 新 PM
    ↓
新 PM 读取 task comments，找到最近的进度更新
    ↓
恢复上下文：已回答 Q1-Q4，待澄清 6 个维度
    ↓
发送通知："PM 已重启，将从 Q5 继续"
    ↓
从待澄清维度中选择下一个最关键的问题，继续澄清
```

**【异步澄清规则与分级超时】**

| 场景 | 处理方式 |
|------|---------|
| **Jacky 不回复** | 24h 发提醒通知 → 72h 升级通知渠道 → 7 天标记 stale → 48h 后归档回 backlog |
| **Research 任务阻塞** | 澄清暂停，task 状态变为 `waiting`。Research 超时 72h，超时后跳过该证据继续澄清 |
| **Jacky 说"明天继续"** | task 状态变为 `paused`。PM 保存进度到 comments 后安全退出。Jacky 随时可以恢复。 |
| **多天澄清** | 每轮通过 comments 保存进度。PM 可以被安全回收和重建，不会丢失上下文。 |
| **Jacky 明确放弃** | task 状态变为 `cancelled`。已有的澄清进度保留在 comments 中，供后续参考。 |
| **多需求排队** | 同一时间只允许一个需求处于「等待回答」状态，其他排队。支持跳过被阻塞需求处理下一个。 |

---

### Step 1.6: 可行性检查与冲突沟通 `[Phase 19 增量]`

**【核心设计：持续可行性检查】**

可行性检查不是最后才做的一次性动作——它贯穿整个澄清过程。每确认一个关键维度，就立刻检查可行性。发现冲突**立即沟通**，不让老板继续回答后续无效问题。

```
Q1 确认目标 → 立刻检查: 目标在技术上可实现吗？
Q2 确认用户 → 立刻检查: 用户群体+目标的安全标准合理吗？
Q3 确认时间 → 立刻检查: 时间+已知范围能匹配吗？
Q5 确认策略 → 立刻检查: 现有代码支持这个策略吗？
Q10 确认范围 → 立刻检查: 范围+时间没有冲突吗？
...每个关键节点都检查
```

**【Q1 后的可行性检查】**

```python
# Q1 确认: 7天免登录
feasibility_check = {
    "check": "7天免登录技术上可实现吗？",
    "evidence": "JWT 是标准方案。access+refresh 双 token 机制支持长期会话。",
    "verdict": "✅ 可行 — 标准技术方案，无阻塞项",
}
# → 通过，继续 Q2
```

**【Q2 后的可行性检查】**

```python
# Q2 确认: 外部付费客户
feasibility_check = {
    "check": "外部客户 + 7天 安全可接受吗？",
    "evidence": "行业标准: Google 14天，GitHub 14天。7天在安全可接受范围内。",
    "verdict": "✅ 可行 — 安全标准合理",
}
# → 通过，继续 Q3
```

**【Q3 后的可行性检查 — 时间与范围匹配】**

```python
# Q3 确认: 1-2 周
feasibility_check = {
    "check": "1-2 周能完成什么级别的功能？",
    "evidence": "代码发现: 现有无 auth 模块（E6），需从零搭建。估算: 4接口+中间件+测试 = 8-10 工作日。",
    "verdict": "✅ 可行 — 1-2 周（5-10 工作日）足够完成核心认证",
    "constraint": "如果后续选择含密码重置/邮箱验证的完整方案，时间会超出",
}
# → 通过，但记录约束: 后续 Q10 选范围时需要对照此约束
```

**【Q10 后的可行性检查 — 范围与时间交叉验证】**

```python
# 如果 Q3 选了"A — 本周内"，Q10 选了"C — 完整认证+密码重置+邮箱验证"
feasibility_check = {
    "check": "范围与时间是否冲突？",
    "evidence": {
        "time": "本周内（5个工作日）",
        "scope": "核心认证(5天) + 密码重置(3天) + 邮箱验证(3天) = 11天",
    },
    "verdict": "❌ 冲突 — 范围超出时间约束",
}
# → 立即沟通，不等最后
```

**【冲突沟通示例 1：时间 vs 范围】**

```python
clarify(
    question={
        "id": "CONFLICT_1",
        "question": "⚠️ 发现冲突：你要求本周上线（Q3），但功能范围超出时间约束。",
        "conflict_detail": {
            "问题": "时间不够",
            "证据": "密码重置需要邮件服务集成（约3天），邮箱验证需要邮件模板+确认流程（约3天），加上核心认证（约5天），总计约 11 个工作日，超过本周（5个工作日）。",
            "建议": [
                {
                    "label": "A) 缩小范围：先做登录+刷新+注册+登出，密码重置和邮箱验证下期",
                    "reason": "本周可以完成核心认证，密码重置和邮箱验证不影响核心价值。",
                    "recommend": "⭐ 推荐",
                },
                {
                    "label": "B) 延长时间：接受 2-3 周完成全部功能",
                    "reason": "功能完整但时间延长。",
                    "recommend": "○ 可选",
                },
                {
                    "label": "C) 砍掉密码重置，保留邮箱验证",
                    "reason": "邮箱验证是安全必须，密码重置可以后做。",
                    "recommend": "○ 可选",
                },
                {
                    "label": "其他",
                    "reason": "有其他想法？请描述。",
                },
            ],
        },
    }
)
```

**【冲突沟通示例 2：需求与代码现实不一致 — 在 Q4 时就发现】**

```python
# 假设 Jacky 在 Q4 选了"OAuth2.0 SSO 企业登录"
# 代码发现: 无 OAuth 依赖，users 表无 SSO 字段

feasibility_check = {
    "check": "OAuth2.0 SSO 在当前项目可行吗？",
    "evidence": [
        "Cargo.toml 无 OAuth 依赖",
        "users 表只有 email+password_hash（src/models/user.rs:12-18），无 SSO 字段",
        "需要引入 OAuth 库 + 扩展 users 表 + 集成第三方 IdP",
    ],
    "verdict": "❌ 不可行 — 工作量约 3-4 周，超出 Q3 确认的 1-2 周",
}
# → 立即在 Q4 沟通，而不是等 Q11 才说

clarify(
    question={
        "id": "CONFLICT_2",
        "question": "⚠️ 发现问题：OAuth2.0 SSO 在当前项目不可行。",
        "conflict_detail": {
            "问题": "项目现状与需求不匹配",
            "证据": [
                "users 表只有 email+password_hash（src/models/user.rs:12-18），无 SSO 字段",
                "Cargo.toml 无 OAuth 依赖",
                "需要引入 OAuth 库 + 扩展 users 表 + 集成第三方 IdP，约 3-4 周",
            ],
            "建议": [
                {
                    "label": "A) 先做邮箱+密码登录，SSO 作为第二期",
                    "reason": "核心认证 1-2 周可完成，SSO 不影响现有用户。",
                    "recommend": "⭐ 推荐",
                },
                {
                    "label": "B) 延长到 3-4 周，包含 SSO",
                    "reason": "功能完整但时间延长。",
                    "recommend": "○ 可选",
                },
                {
                    "label": "其他",
                    "reason": "有其他想法？请描述。",
                },
            ],
        },
    }
)
```

**【最终完整性检查】**

所有问题问完后，做一次完整性检查（非重复，而是确认没有遗漏）：

```python
final_feasibility = {
    "checks": [
        {"item": "JWT 替换 session", "verdict": "✅", "evidence": "session 逻辑集中在 src/routes/users.rs:45-72"},
        {"item": "7天免登录安全", "verdict": "✅", "evidence": "行业标准（Google 14天，GitHub 14天）"},
        {"item": "1-2 周完成", "verdict": "✅", "evidence": "4接口+中间件+测试，估算 8-10 工作日"},
        {"item": "第三方库兼容", "verdict": "✅", "evidence": "jsonwebtoken 支持 Rust 1.56+，与 Axum 0.7 兼容"},
        {"item": "无未解决冲突", "verdict": "✅", "evidence": "CONFLICT_1 已通过缩小范围解决"},
    ],
    "overall": "✅ 全部通过，可进入需求文档生成",
}
```

**【阻塞场景：需求无法继续澄清】**

可行性检查可能发现**阻塞项**——不是冲突（可以调整范围），而是需求本身无法在当前条件下推进。

| 阻塞类型 | 示例 | 触发时机 |
|---------|------|---------|
| **基础设施缺失** | "需要密码重置"但项目没有邮件服务 | Q10 选范围时 |
| **外部依赖未就绪** | "集成 Google OAuth"但没有 Google Cloud 项目 | Q4 选登录方式时 |
| **前置需求未完成** | "加协作编辑"但实时通信模块还没做 | 技术发现时 |
| **合规要求未满足** | "存储用户健康数据"但没有 HIPAA 合规 | Q2 确认用户群体时 |

**【PM 处理阻塞】**

```python
# 示例: Jacky 要密码重置，但项目没有邮件服务
blocking_issue = {
    "type": "infrastructure_missing",
    "requirement": "密码重置功能",
    "blocker": "项目没有邮件服务",
    "evidence": [
        "Cargo.toml 无 lettre/sendgrid/mailgun 等邮件依赖",
        "src/ 无 email/mailer 模块",
        "环境变量无 SMTP/SENDGRID_API_KEY",
    ],
    "verdict": "🚫 阻塞 — 需要先搭建邮件服务",
}

clarify(
    question={
        "id": "BLOCK_1",
        "question": "⚠️ 需求阻塞：密码重置需要邮件服务，但项目目前没有。",
        "blocker_detail": {
            "阻塞项": "密码重置功能",
            "原因": "项目没有邮件服务（无邮件依赖、无 SMTP 配置）",
            "证据": [
                "Cargo.toml 无邮件相关依赖",
                "环境变量无 SMTP/SENDGRID_API_KEY",
            ],
            "建议": [
                {
                    "label": "A) 从 MVP 中移除密码重置",
                    "reason": "核心认证不受影响，密码重置可以下期做。最快上线。",
                    "recommend": "⭐ 推荐",
                },
                {
                    "label": "B) 先搭建邮件服务，再做密码重置",
                    "reason": "需要额外 2-3 天搭建邮件服务。需求暂停，等邮件服务就绪后继续。",
                    "recommend": "○ 可选",
                },
                {
                    "label": "C) 用第三方密码重置服务（如 Auth0）",
                    "reason": "不需要自己搭邮件，但引入外部依赖和成本。",
                    "recommend": "○ 可选",
                },
                {
                    "label": "其他",
                    "reason": "有其他方案？请描述。",
                },
            ],
        },
    }
)
```

**【阻塞状态处理】**

```python
# Jacky 选 B: 先搭建邮件服务
block_resolution = {
    "action": "pause_requirement",
    "blocked_dimension": "MVP范围（密码重置）",
    "prerequisite": "搭建邮件服务（letter + SMTP 配置）",
    "next_step": "创建前置任务: '搭建邮件服务基础设施'",
    "resume_condition": "邮件服务就绪后，自动恢复密码重置的澄清",
}

# Jacky 选 A: 移除阻塞项
block_resolution = {
    "action": "remove_blocked_feature",
    "removed": "密码重置",
    "impact": "MVP 范围缩小，不影响核心认证功能",
    "note": "密码重置记录为后续迭代需求",
}
```

---

**【PM 内心OS】**

> "所有问题都问完了，冲突也都解决了。
> 现在生成最终的需求文档，每一条都要有证据。"

**【PM 生成的需求文档】**

```markdown
# 需求文档: 用户认证模块 (t_alpha_001)

## 0. 证据索引

| 编号 | 证据来源 | 路径 | 行号 | 内容摘要 |
|------|---------|------|------|---------|
| E1 | 框架版本 | Cargo.toml | L15 | `axum = "0.7"` |
| E2 | 数据库 | Cargo.toml | L18 | `sqlx = { features = ["postgres"] }` |
| E3 | 用户模型 | src/models/user.rs | L12-18 | `User { id, email, password_hash, created_at }` |
| E4 | 现有登录 | src/routes/users.rs | L45-72 | session-based POST /users/login |
| E5 | 中间件链 | src/middleware/mod.rs | L8-15 | trace→cors→rate_limit（无 auth） |
| E6 | 无 auth 模块 | src/ | — | tree 输出无 src/auth/ |
| E7 | 无 JWT 依赖 | Cargo.toml | — | 无 jsonwebtoken/ring |
| E8 | 密码哈希 | Cargo.toml | L20 | `argon2 = "0.5"` |

---

## 1. 价值层 (WHY)

### 业务背景
用户反馈每次重启浏览器都要重新登录，体验很差。
> 证据: Jacky 原始需求描述

### 目标用户
Alpha SaaS 产品的外部付费客户。
> 证据: Jacky 确认 Q2:A

### 业务目标
- 用户 7 天内无需重新登录（长会话支持）
> 证据: Jacky 确认 Q1:A

### 成功指标
- 用户平均登录频率从"每次会话"降至"每周 1 次"
- 无新增安全事件

### 时间要求
1-2 周内完成
> 证据: Jacky 确认 Q3:B

---

## 2. 功能层 (WHAT)

### 用户故事

**US-1: 自动续期**
作为 SaaS 用户，我希望登录后 7 天内无需重新登录，以便操作不被中断。
> 证据: Q1:A

**验收标准:**
- Given 用户已登录，When 7 天内再次访问，Then 自动使用有效 token
- Given access token 过期，When 用户发起请求，Then 静默刷新
- Given refresh token 过期，When 用户发起请求，Then 跳转登录页
> 证据: Q6:A 静默刷新

**US-2: 用户注册**
验收: 有效邮箱注册成功 + 重复邮箱提示已注册
> 证据: Q10:B

**US-3: 用户登录**
验收: 正确凭据返回 token 对 + 错误密码返回 401 + 不泄露用户存在性
> 证据: E4 现有登录逻辑

**US-4: 用户登出**
验收: token 加入黑名单 + 返回 204
> 证据: Q10:B

---

## 3. 验收层 (VERIFY)

### 验收方式
- 自动化测试 + 手动测试
> 证据: Q7:C

### 影响范围
- 直接影响: src/routes/users.rs（E4）
- 新增模块: src/auth/
- 中间件变更: src/middleware/mod.rs（E5）
- 不影响: 其他业务接口
> 证据: Q8:A

### 可观测性
- 登录成功/失败日志
- token 刷新日志
- 异常事件日志
> 证据: Q9:A

---

## 4. 范围层 (BOUNDARY)

### MVP 包含
- [x] 登录 (/login) — 替换 session
- [x] 注册 (/register)
- [x] 静默刷新 (/refresh)
- [x] 登出 (/logout)
- [x] auth 中间件
- [x] 自动化测试 + 手动验收
> 证据: Q10:B, Q5:A, Q6:A

### MVP 不包含
- [ ] 第三方登录
- [ ] 密码重置
- [ ] 邮箱验证
- [ ] 敏感操作二次验证
> 证据: Q4:A（只做邮箱+密码），CONFLICT_1 解决结果

### 优先级
1. 登录 + 静默刷新（核心价值）
2. 注册（用户增长）
3. 登出（安全）

---

## 5. 技术背景（系统自动发现，非老板提供）

> 以下所有技术信息均由 PM 自动读取项目代码获得。
> 发现路径: CLAUDE.md → Cargo.toml → src/ → 按需深入

| 组件 | 状态 | 证据 |
|------|------|------|
| 框架 | Axum 0.7.9 | E1: Cargo.toml:15 |
| 数据库 | PostgreSQL + sqlx 0.7 | E2: Cargo.toml:18 |
| 用户模型 | User { id, email, password_hash, created_at } | E3: src/models/user.rs:12-18 |
| 登录方式 | session-based | E4: src/routes/users.rs:45-72 |
| 中间件 | trace→cors→rate_limit | E5: src/middleware/mod.rs:8-15 |
| auth 模块 | 不存在 | E6 |
| JWT 依赖 | 不存在 | E7 |
| 密码哈希 | argon2 0.5 | E8: Cargo.toml:20 |

### 约束
- 不修改现有 users 表结构（可新增字段）
- 不破坏现有 /users 相关接口
- 新增 auth 中间件插入 rate_limit 之后

---

## 6. 可行性确认

| 检查项 | 结果 | 证据 |
|--------|------|------|
| JWT 替换 session 可行？ | ✅ | session 逻辑集中在 src/routes/users.rs:45-72 |
| 7天免登录安全可接受？ | ✅ | 行业标准（Google 14天，GitHub 14天） |
| 1-2周内能完成？ | ✅ | 4接口+中间件+测试，估算 8-10 工作日 |
| 第三方库兼容 Axum 0.7？ | ✅ | jsonwebtoken 支持 Rust 1.56+ |
| 冲突已解决 | ✅ | CONFLICT_1: 范围调整为不含密码重置/邮箱验证 |
```

---

### Step 1.7.5: Definition of Ready 验证门 `[Phase 19 增量]`

**【DoR 验证：机器可验证项 + LLM 自检】**

需求文档生成后，先执行机器可验证项，再执行 LLM 自检。机器验证不通过直接打回，不依赖 LLM 判断。

**【机器可验证项（脚本执行）】**

```python
# 1. 证据链完整性：每个 E-ID 是否有对应的文件路径+行号
for evidence in requirement_doc.evidence_index:
    assert evidence.file_path exists, f"E{evidence.id} 文件不存在"
    assert evidence.line_range is not None, f"E{evidence.id} 缺少行号"

# 2. 维度覆盖：11 个维度是否都有对应的 Q-ID 回答
required_dimensions = ["目标", "用户", "时间", "登录方式", "现有处理", "交互", "验收", "影响", "可观测", "MVP", "技术方案"]
for dim in required_dimensions:
    assert dim in requirement_doc.answered_dimensions, f"维度 '{dim}' 未覆盖"

# 3. 用户故事格式：是否符合 Given-When-Then
for us in requirement_doc.user_stories:
    assert "Given" in us.acceptance_criteria and "When" in us.acceptance_criteria, f"{us.id} 验收标准格式不符"
```

**【LLM 自检项（结构化输出）】**

需求文档生成后，PM 必须逐项检查 Definition of Ready 的 7 项标准。自检必须结构化输出，不通过的项自动触发补问。

```python
dor_verification = {
    "value_layer": {
        "status": "✅",
        "checklist": [
            "业务目标明确? ✅ — 7天免登录（Q1:A）",
            "用户群体明确? ✅ — 外部付费客户（Q2:A）",
            "成功指标明确? ✅ — 登录频率降低、无安全事件",
            "时间要求明确? ✅ — 1-2周（Q3:B）",
        ],
    },
    "functional_layer": {
        "status": "✅",
        "checklist": [
            "用户故事已定义? ✅ — US-1~US-4",
            "验收标准可测试? ✅ — Given-When-Then 格式，12 条",
        ],
    },
    "verify_layer": {
        "status": "✅",
        "checklist": [
            "验收方式已确认? ✅ — 自动化+手动（Q7:C）",
            "影响范围已识别? ✅ — 仅登录接口（Q8:A）",
            "可观测性已确认? ✅ — 基础日志（Q9:A）",
        ],
    },
    "scope_layer": {
        "status": "✅",
        "checklist": [
            "MVP 边界已划定? ✅ — 登录+注册+刷新+登出（Q10:B）",
            "排除项已列出? ✅ — 第三方登录/密码重置/邮箱验证",
        ],
    },
    "feasibility": {
        "status": "✅",
        "checklist": [
            "无未解决冲突? ✅ — CONFLICT_1 已解决",
            "代码现实一致? ✅ — 所有技术判断有代码证据",
        ],
    },
    "evidence_chain": {
        "status": "✅",
        "checklist": [
            "技术判断有代码/文档佐证? ✅ — 8 项证据（E1-E8）",
        ],
    },
    "unambiguous": {
        "status": "✅",
        "checklist": [
            "任何角色都能独立理解? ✅ — 所有选项已明确选择，无模糊表述",
        ],
    },
    "overall": "✅ 全部通过",
}
```

**【DoR 未通过的处理】**

如果有任何一项未通过：

```python
# 示例: 功能层未通过 — 验收标准不可测试
dor_verification = {
    "functional_layer": {
        "status": "❌",
        "issue": "US-1 的验收标准'用户体验改善'不可测试",
        "action": "触发补问 → 回到 Step 1.5 补充具体验收标准",
    },
}
# PM 自动发起补问:
clarify(
    question={
        "id": "DOR_FIX_1",
        "question": "US-1 的验收标准需要更具体。'用户体验改善'怎么量化？",
        "options": [
            {
                "label": "A) 登录频率从每次会话降至每周 1 次",
                "reason": "可量化、可测试。通过登录日志统计。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 用户满意度调查评分 ≥ 4/5",
                "reason": "需要用户调研，周期长。",
                "recommend": "○ 可选",
            },
            {
                "label": "其他",
                "reason": "有其他量化方式？",
            },
        ],
    }
)
```

---

### Step 1.8: Jacky 确认需求文档 `[Phase 19 增量]`

**【核心设计：显式确认关卡】**

需求文档生成并通过 DoR 验证后，**必须**经过 Jacky 显式确认才能进入任务拆解。不允许隐式接受。

**【系统推送（Gateway → 多渠道回退）】**

Gateway 消息投递采用多渠道回退策略：主渠道（Telegram）失败时自动尝试备用渠道（Discord → CLI → 邮件）。在 kanban task 中记录消息投递状态，支持手动重发。72h 未确认则升级通知渠道并标记为 stale。

```
📋 Project Alpha — 需求澄清完成

原始需求: 改善登录体验：减少用户重复登录

经过 13 轮问答（一次一问，逐步收缩），已转化为标准化需求：

🎯 核心目标: 用户 7 天内无需重新登录
👥 目标用户: SaaS 外部付费客户
⏰ 时间要求: 1-2 周

📦 MVP 功能:
  ✅ 登录 (/login) — 替换现有 session
  ✅ 注册 (/register)
  ✅ 静默刷新 (/refresh)
  ✅ 登出 (/logout)
  ✅ auth 中间件

🚫 排除项:
  ❌ 第三方登录
  ❌ 密码重置
  ❌ 邮箱验证

🔍 验收: 自动化测试 + 手动验收
📊 可观测性: 基础日志
🔗 证据链: 8 项代码证据
⚠️ 冲突已解决: 1 项（范围 vs 时间）
✅ DoR 验证: 全部通过

[查看详情] [修改需求] [确认并开始拆解]
```

**【Jacky 选择"确认并开始拆解"】**

```python
# Jacky 确认 → 需求文档状态变为 confirmed
clarify(
    question={
        "id": "CONFIRM",
        "question": "需求文档已确认。以下是最终摘要，请确认：",
        "summary": {
            "核心目标": "7天免登录",
            "用户群体": "外部付费客户",
            "时间": "1-2周",
            "MVP功能": "登录+注册+刷新+登出",
            "排除项": "第三方登录、密码重置、邮箱验证",
            "验收": "自动化+手动",
            "证据": "8项代码证据",
        },
        "options": [
            {"label": "✅ 确认，开始拆解任务", "reason": "需求文档无误，进入任务拆解阶段。"},
            {"label": "✏️ 修改需求", "reason": "需要调整某些内容。"},
            {"label": "其他", "reason": "有其他想法？"},
        ],
    }
)
```

**【Jacky 选择"修改需求"】**

```python
clarify(
    question={
        "id": "MODIFY",
        "question": "需要修改哪部分内容？",
        "options": [
            {"label": "A) 核心目标/用户群体", "reason": "回到 Q1/Q2 重新澄清"},
            {"label": "B) 功能范围（MVP 包含什么）", "reason": "回到 Q10 重新选择"},
            {"label": "C) 技术方案", "reason": "回到 Q11 重新选择"},
            {"label": "其他", "reason": "请描述需要修改的内容。"},
        ],
    }
)
```

**修改流程：**
1. Jacky 指定修改范围 → PM 回到对应的澄清轮次
2. 重新执行该轮次的澄清 + 可行性检查
3. 更新需求文档，重新验证 DoR
4. 再次推送确认通知
5. **需求文档版本号递增**（v1 → v2 → v3...）

**【全局修改预算】**

需求确认后最多允许 **3 次修改**。超限后 PM 强制输出当前版本并标注「修改预算已用尽，如需继续修改请手动干预」。如果连续 2 次修改涉及不同维度，提示 Jacky 是否需要重新从头澄清（说明需求尚未稳定）。

**【收敛-修改限制】**

如果 Jacky 要修改的维度**之前被强制收敛过**：

```python
# 场景：Q1 被收敛为"7天免登录"，现在 Jacky 要改 Q1
clarify(
    question={
        "id": "MODIFY_CONVERGED",
        "question": "Q1（核心目标）之前被收敛为默认值（7天免登录）。你现在有明确的想法吗？",
        "options": [
            {
                "label": "A) 用当前默认值（7天免登录），不改了",
                "reason": "已经收敛过一次，继续推进更重要。",
                "recommend": "⭐ 推荐",
            },
            {
                "label": "B) 我现在有明确想法了",
                "reason": "请描述你想要的具体效果。",
            },
        ],
    }
)
```

**限制规则：**
- 同一维度最多经历 **1 次收敛 + 1 次修改**
- 第二次修改时，如果还是模糊 → 锁定为当前值 + 标记 `[已锁定，需后续迭代]`
- 锁定后不允许再修改，只能在后续迭代中重新评估

**【需求版本控制】**

每次确认生成一个版本：

```python
requirement_version = {
    "version": "v1",
    "confirmed_at": "2026-05-10T09:46:00Z",
    "confirmed_by": "jacky",
    "changes": "初始版本",
    "dor_status": "all_passed",
}
```

修改后：
```python
requirement_version = {
    "version": "v2",
    "confirmed_at": "2026-05-10T10:15:00Z",
    "confirmed_by": "jacky",
    "changes": "Q10: MVP 范围调整 — 增加密码重置",
    "dor_status": "all_passed",
    "parent_version": "v1",
}
```

---

### Step 1.8.3: 澄清质量反馈 `[Phase 19 增量]`

**【目的】** 收集 Jacky 对澄清过程的反馈，用于持续优化澄清问题的质量。

**【系统推送反馈问卷】**

Jacky 确认需求文档后，系统自动发送一份简短问卷：

```
📊 需求澄清质量反馈

经过 13 轮问答完成了需求澄清，请花 30 秒评价一下：

1️⃣ 澄清过程清晰吗？
   ⭐⭐⭐⭐⭐ 非常清晰
   ⭐⭐⭐⭐ 比较清晰
   ⭐⭐⭐ 一般
   ⭐⭐ 有些混乱
   ⭐ 很难理解

2️⃣ 有没有遗漏重要内容？
   ✅ 没有遗漏
   ⚠️ 有，但不重要
   ❌ 有，很重要（请补充）

3️⃣ 哪个问题最有价值？（可多选）
   □ Q1 核心目标
   □ Q2 用户群体
   □ Q3 时间压力
   □ Q4-Q6 功能细节
   □ Q7-Q9 验收相关
   □ Q10-Q11 范围和技术

4️⃣ 其他建议？（可选）
   [自由输入]
```

**【反馈收集与分析】**

```python
feedback_record = {
    "requirement_id": "t_alpha_001",
    "version": "v1",
    "questions_count": 13,
    "clarity_rating": 5,         # 1-5
    "missing_important": False,   # 是否遗漏重要内容
    "most_valuable_questions": ["Q1", "Q10"],
    "suggestions": "",
    "duration_minutes": 16,       # 澄清总耗时
    "conflicts_found": 1,         # 发现的冲突数
}
```

**【反馈驱动优化】**

反馈数据用于优化澄清流程：

| 指标 | 优化动作 |
|------|---------|
| 某问题经常被跳过/选默认 | 考虑简化该问题或调整选项 |
| 某问题经常触发"其他" | 考虑增加选项或调整问题措辞 |
| 整体评分 < 3 | 检查问题顺序、措辞、选项设计 |
| 经常有"遗漏重要内容" | 分析遗漏类型，补充对应问题 |
| 澄清耗时过长 | 考虑减少问题数量或合并相似问题 |

---

### Step 1.8.5: 需求追溯规范 `[Phase 19 增量]`

**【双向追溯链】**

需求文档中的每个元素必须可追溯：

```
需求文档                    代码/证据
─────────────              ──────────
US-1 (自动续期)     ←→     Q1:A + Q6:A
  验收标准 1.1      ←→     src/routes/users.rs (token 刷新逻辑)
  验收标准 1.2      ←→     Q6:A (静默刷新)

E1 (框架版本)       ←→     Cargo.toml:15
E4 (现有登录)       ←→     src/routes/users.rs:45-72

排除项: 密码重置    ←→     CONFLICT_1 解决结果
排除项: 第三方登录   ←→     Q4:A 选择理由
```

**【追溯规范】**
- 每个用户故事 → 关联到对应的澄清问题编号（Q1, Q2, ...）
- 每个技术约束 → 关联到代码证据（文件:行号）
- 每个排除项 → 关联到排除原因（冲突解决/主动排除）
- 每个可行性检查 → 关联到检查结论和证据

---

### Step 1.9: PM 完成需求澄清任务

```python
kanban_complete(
    task_id="t_alpha_001",
    summary="需求澄清完成。13轮问答（一次一问，逐步收缩）。可行性检查贯穿全程，1个冲突已解决（Q10 后发现范围vs时间）。DoR 7项全部通过。Jacky 确认 v1。",
    metadata={
        "requirement_version": "v1",
        "confirmed_by": "jacky",
        "confirmed_at": "2026-05-10T09:46:00Z",
        "clarification_approach": "one_question_at_a_time",
        "questions_asked": 13,
        "conflicts_found": 1,
        "conflicts_resolved": 1,
        "evidence_items": 8,
        "feasibility_checks": 5,
        "feasibility_passed": 5,
        "dor_verification": "all_passed",
        "traceability": {
            "user_stories": ["US-1→Q1:A,Q6:A", "US-2→Q10:B", "US-3→E4", "US-4→Q10:B"],
            "exclusions": ["第三方登录→Q4:A", "密码重置→CONFLICT_1", "邮箱验证→CONFLICT_1"],
        },
    }
)
```

---

### Step 1.10: 系统自动创建规划任务（含追溯）

```python
t_plan = kanban_create(
    title="任务拆解: 用户认证模块 (v1)",
    assignee="pm",
    body="""读取 t_alpha_001 的需求澄清文档 v1，拆解为可执行的子任务图。

追溯要求:
- 每个子任务必须关联到需求文档的用户故事（US-1~US-4）
- 每个子任务的验收标准必须覆盖对应的 Given-When-Then
- 任务 metadata 中包含 requirement_version 和 covered_user_stories""",
    parents=[t_alpha_001],
)
```

---
