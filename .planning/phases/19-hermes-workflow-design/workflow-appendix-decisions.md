## 附录 B：关键设计决策的叙事化讨论

> 📎 **相关 ASCII 流程图**：
> - [`ascii-decision-matrix.md`](./ascii-decision-matrix.md) — L3 升级流程、声明式风险策略引擎
> - [`ascii-observability.md`](./ascii-observability.md) — SRE-Observer 自动触发与分析

---

### 决策 1：为什么 SRE-Observer 是独立 Profile 而不是内置逻辑？ `[Phase 19 增量]`

**【Jacky 的心理提问】**

> "为什么根因分析要作为一个独立的 AI 角色（SRE-Observer），
> 而不是让 Dispatcher 自己跑一段分析代码？"

**【系统回答】**

> "有三个原因：
> 
> **原因 1：架构一致性**
> 系统中的所有'工作'都走 Kanban 任务流。如果根因分析是内置逻辑，
> 它就成为了系统核心的一部分，违反了'不修改 Hermes 核心'的约束（R19）。
> 作为独立 Profile，它和其他 Worker 一样，通过 hooks 读取数据，通过 Kanban 输出报告。
> 
> **原因 2：可替换性**
> 现在的 SRE-Observer 可以用通用 LLM（GPT-4/Claude）。
> 未来如果出现专门的'根因分析模型'（比如经过大量日志训练的专用模型），
> 只需要换掉 SRE-Observer 的 profile model 配置，不需要改系统代码。
> 
> **原因 3：资源隔离**
> SRE 分析可能需要读取大量 trace 数据，消耗大量 token。
> 作为独立任务，可以通过 priority 机制或独立派发池，避免和业务任务争夺资源。
> 
> **技术实现说明：**
> SRE-Observer 的**自动触发**不是由 Plugin hook 直接创建 Kanban 任务的（hooks 不能调用工具）。
> 实际路径是：Plugin 的 `post_tool_call` / `on_session_end` hooks 将故障事件写入外部队列；
> 由 cron job 或独立监控进程定期扫描该队列和 board 状态，检测到触发条件后创建 sre-observer 任务。
> 这种'观察 → 记录 → 异步触发'的设计保持了 Plugin 的纯观察性，不侵入 Hermes 核心调度逻辑。
> 
> 类比：就像公司里的'事故调查小组'——它不是每个部门日常工作的一部分，
> 而是出事后临时组建的专家团队，调查完出报告就解散。"

**【Jacky 的认可】**

> "说得通。让根因分析也走任务流，保持架构一致性。
> 而且未来可以换更专业的模型来做分析，不需要改系统代码。"

---

### 决策 2：为什么 Reviewer 的写操作要技术性拦截（R8）？ `[Phase 19 增量]`

**【Jacky 的心理提问】**

> "Reviewer 的角色是'只读审查'，但为什么要做技术层面的拦截？
> 不是已经在 SOUL.md 里写了'你只许读不许写'吗？"

**【系统回答】**

> "SOUL.md 是 prompt 层的约束，相当于'口头嘱咐'。
> 但 LLM 可能会'忘记'或'误解'这个约束。
> 
> 比如 Reviewer 在审查时想跑 lint：
> ```bash
> terminal(command='cargo clippy --fix')  # --fix 会自动修改代码！
> ```
> 或者 Reviewer 想测试某个修复建议：
> ```bash
> terminal(command='echo "fix" >> src/auth/jwt.rs')
> ```
> 
> 这些场景下，Reviewer 可能不是故意破坏规则，而是'不小心'执行了写操作。
> R8 的技术性拦截相当于'物理锁'——即使 Reviewer 忘了规则，系统也会拦住它。
> 
> 这是纵深防御：
> - 第一层：SOUL.md prompt 约束（心理防线）
> - 第二层：toolsets 白名单（工具防线）
> - 第三层：R8 terminal 写操作拦截（物理防线）
> 
> 三层都失效的概率极低。"

**【Jacky 的认可】**

> "对，只依赖 prompt 约束太脆弱了。三层防御是必要的——
> Reviewer 如果'手滑'执行了 cargo clippy --fix，系统必须拦住它。
> 审计日志也要记录，万一真出事了能追溯。"

---

### 决策 3：为什么 Implementer 遇到不确定时必须 block（R9）？ `[Hermes 官方]` + `[Phase 19 增量]`

**【场景对比】**

**场景 A（没有 R9，Implementer 自行决定）：**

```
Implementer: "RS256 还是 HS256？让我想想...
            HS256 更简单，用一个密钥就行。
            用户说'便于未来微服务拆分'... 但 HS256 也可以拆分啊，
            只要所有服务共享同一个密钥就行。
            好吧，我用 HS256。"

# 结果：用户要求的是 RS256（非对称，更安全）
# Implementer 用了 HS256（对称，所有服务共享密钥）
# 后期微服务拆分时必须改代码
```

**场景 B（有 R9，Implementer block）：**

```
Implementer: "RS256 还是 HS256？用户说'便于未来微服务拆分'。
            这是一个架构决策，我不应该自己决定。
            kanban_block(reason='architecture-decision: RS256 vs HS256')"

Jacky: "用 RS256。理由：微服务之间不需要共享密钥，
        每个服务只需要公钥验证，私钥由认证中心保管。"

Implementer: "收到，用 RS256。"
```

**【Jacky 的认可】**

> "这个规则很重要。AI 工人不应该替我做技术选型决策——
> 它的知识截止于训练数据，不知道我未来的架构规划。
> 只有我自己知道为什么要选 RS256（为了微服务拆分）。
> 
> 但我也希望 block 不会频繁触发——如果每个小决策都要问我，
> 我就变成'项目经理'了，失去了自动化的意义。
> 
> 关键是如何定义'架构决策'的边界：
> - 算法选择（RS256 vs HS256）→ 必须 block
> - 变量命名（access_token vs jwt）→ 自己定
> - 错误消息措辞 → 自己定
> - 是否加缓存 → 必须 block
> 
> 这个边界需要在 SOUL.md 中明确。"

---
