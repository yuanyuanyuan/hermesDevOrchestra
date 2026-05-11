## Phase 2: 任务拆解（PM）

> **架构说明（2026-05-11 更新）：** 本文档中的 PM 任务拆解采用"外部 CLI 引擎"模式。PM Profile 委托 `claude -p` PM 引擎完成任务拆解，Profile 解析 JSON Response Envelope 中的 `tasks` 数组后调用 `kanban_create()` 创建任务。详见 [`EXTERNAL-CLI-ENGINE.md`](./EXTERNAL-CLI-ENGINE.md) §6.4。

> 📎 **相关 ASCII 流程图**：
> - [`ascii-end-to-end.md`](./ascii-end-to-end.md) — Phase 1-2 需求提交→任务拆解
> - [`ascii-kanban-subflows.md`](./ascii-kanban-subflows.md) — 任务依赖链、Dispatcher 工作循环
> - [`ascii-core-flows.md`](./ascii-core-flows.md) — F1 Phase 0 平台能力确认、F2 多项目并行生命周期

---

### Step 2.1: Dispatcher 派发 PM `[Hermes 官方]`

**【场景上下文】**
60 秒后，Dispatcher 的下一轮循环开始。t_alpha_001 是 project-alpha board 上唯一的 ready 任务。

**【系统内部】Dispatcher 的决策日志：**

```
[2026-05-10T09:31:02Z] Dispatcher cycle start
[2026-05-10T09:31:02Z] Board: project-alpha
[2026-05-10T09:31:02Z] Ready tasks: [t_alpha_001]
[2026-05-10T09:31:02Z] Claiming t_alpha_001 (atomic)
[2026-05-10T09:31:02Z] Spawning worker: pm
[2026-05-10T09:31:02Z] Environment: HERMES_KANBAN_TASK=t_alpha_001
[2026-05-10T09:31:02Z] Environment: HERMES_KANBAN_BOARD=project-alpha
[2026-05-10T09:31:03Z] Worker PID: 18473
```

---

### Step 2.2: PM 被唤醒，读取任务 `[Hermes 官方]`

**【PM 内心OS】**

> "我被 Dispatcher 派发了。任务 ID 是 t_plan_alpha_001，board 是 project-alpha。
> 这是一个任务拆解任务，parent 是 t_alpha_001（需求澄清任务）。
> 让我先看看任务详情，然后读取需求澄清文档。"

**【PM 执行的具体指令】**

```python
# PM 调用 kanban_show() 读取自己的任务
kanban_show(task_id="t_plan_alpha_001")
```

**【系统返回】**

```json
{
  "task_id": "t_plan_alpha_001",
  "title": "任务拆解: 用户认证模块",
  "body": "读取 t_alpha_001 的需求澄清文档，拆解为可执行的子任务图",
  "assignee": "pm",
  "status": "running",
  "board": "project-alpha",
  "parents": ["t_alpha_001"],
  "children": [],
  "created_at": "2026-05-10T09:35:15Z",
  "claimed_at": "2026-05-10T09:36:02Z",
  "workspace": "/data/hermes/workspaces/project-alpha"
}
```

**【PM 读取 parent 的需求澄清文档】**

```python
# 读取需求澄清任务的 handoff（包含标准化需求文档）
kanban_show(task_id="t_alpha_001")
```

**【PM 内心OS】**

> "好的，需求澄清文档 v1 已经被 Jacky 确认了。让我提取关键信息：
>
> **价值层：** 用户 7 天免登录，SaaS 外部客户，1-2 周
> **功能层：** 4 个用户故事（自动续期、注册、登录、登出），12 个验收标准
> **技术层：** JWT (RS256)，Axum 0.7，4 个接口，access 15min / refresh 7day，用第三方库
> **范围层：** 完整认证流程（登录/注册/刷新/登出），排除第三方登录/密码重置/邮箱验证
> **追溯：** 每个用户故事关联到 Q 编号，排除项关联到 CONFLICT_1
>
> 需求文档已通过 DoR 7 项验证，Jacky 已确认。现在拆解任务。
>
> 拆解时需要保持追溯链：
> - 每个子任务的 metadata 中标注覆盖的用户故事和验收标准
> - 这样后续可以验证: 哪些任务覆盖了哪些需求"

---

### Step 2.3: PM 拆解任务

> **外部引擎注解：** 以下任务拆解逻辑由 `claude -p` PM 引擎实际执行。PM Profile 将需求文档发送给 PM 引擎，引擎返回 JSON Response Envelope（含 `tasks` 数组），Profile 解析后逐条调用 `kanban_create()` 创建任务。下方伪代码展示的是 Profile 解析引擎响应后执行的操作序列。

**【PM 执行的具体指令】**

```python
# T1: 实现 JWT 核心逻辑（生成、验证、刷新）
t1 = kanban_create(
    title="T1: 实现 JWT 核心逻辑（生成/验证/刷新 token）",
    assignee="implementer",
    body="""在 src/auth/jwt.rs 中实现：
    
1. TokenClaims 结构体：sub(user_id), exp, iat, jti
2. generate_token(user_id, token_type) -> String
   - token_type: access (15min) | refresh (7days)
3. verify_token(token_string) -> Result<TokenClaims, JwtError>
   - 验证签名、过期时间、格式
4. refresh_access_token(refresh_token) -> Result<String, JwtError>
   - 验证 refresh token 有效性
   - 生成新的 access token
   
技术要求：
- 使用 RS256（RSA + SHA-256）
- 私钥从环境变量 JWT_PRIVATE_KEY 读取
- 公钥从环境变量 JWT_PUBLIC_KEY 读取
- 错误类型：Expired, InvalidSignature, InvalidFormat

依赖：无（可立即开始）
预期时长：60 分钟
""",
    workspace="worktree",
    expected_duration_max="60min",
    metadata={
        "estimated_complexity": "medium",
        "skills_needed": ["rust", "crypto", "jwt"],
        "requirement_version": "v1",
        "covered_user_stories": ["US-1 (自动续期): access+refresh 双 token 机制"],
        "covered_acceptance": ["US-1.1: 7天内自动使用有效 token", "US-1.2: access token 过期时静默刷新"],
    }
)

# T2: 实现 HTTP 接口（基于 T1）
t2 = kanban_create(
    title="T2: 实现 /login /register /refresh /logout 四个 HTTP 接口",
    assignee="implementer",
    body="""在 src/auth/routes.rs 中实现 Axum handlers：

1. POST /login
   - Body: { email, password }
   - 验证密码（使用已有 argon2 hash）
   - 生成 access + refresh token
   - 返回: { access_token, refresh_token, token_type: "Bearer" }
   
2. POST /register
   - Body: { email, password }
   - 检查 email 唯一性
   - argon2 哈希密码
   - 插入 users 表
   - 生成 token 对
   
3. POST /refresh
   - Body: { refresh_token }
   - 验证 refresh token
   - 生成新的 access token
   - 返回: { access_token, token_type: "Bearer" }
   
4. POST /logout
   - Header: Authorization: Bearer <token>
   - 将 token jti 加入黑名单（Redis 或内存）
   - 返回 204

中间件集成：
- 在现有 trace → cors → rate_limit 链之后添加 auth 中间件
- auth 中间件从 Authorization header 提取并验证 access token

依赖：T1（JWT 核心逻辑必须先完成）
预期时长：90 分钟
""",
    workspace="worktree",
    parents=[t1],
    expected_duration_max="90min",
    metadata={
        "estimated_complexity": "medium-high",
        "skills_needed": ["rust", "axum", "postgresql"],
        "requirement_version": "v1",
        "covered_user_stories": ["US-2 (注册)", "US-3 (登录)", "US-4 (登出)", "US-1.2 (静默刷新)"],
        "covered_acceptance": ["US-2.1: 有效邮箱注册成功", "US-3.1: 正确凭据返回 token 对", "US-3.2: 错误密码返回 401", "US-4.1: token 加入黑名单"],
    }
)

# T3: 写测试（基于 T2）
t3 = kanban_create(
    title="T3: 写单元测试和集成测试（覆盖率 ≥ 80%）",
    assignee="implementer",
    body="""测试范围：

单元测试（src/auth/jwt.rs）：
- test_generate_access_token：验证 token 格式和 claims
- test_generate_refresh_token：验证 7 天过期
- test_verify_valid_token：验证正确 token 通过
- test_verify_expired_token：验证过期 token 返回 Expired 错误
- test_verify_invalid_signature：验证伪造签名失败
- test_refresh_access_token：验证 refresh 流程

集成测试（tests/auth_integration.rs）：
- test_login_success：正确凭据返回 token 对
- test_login_wrong_password：错误密码返回 401
- test_register_success：新用户注册成功
- test_register_duplicate_email：重复邮箱返回 409
- test_refresh_success：有效 refresh token 返回新 access token
- test_refresh_invalid_token：无效 refresh token 返回 401
- test_logout_success：登出后 token 失效
- test_protected_route_without_token：未授权访问返回 401
- test_protected_route_with_token：有效 token 访问通过

要求：cargo tarpaulin 报告覆盖率 ≥ 80%
依赖：T2（接口必须先实现）
预期时长：60 分钟
""",
    workspace="worktree",
    parents=[t2],
    expected_duration_max="60min",
    metadata={
        "estimated_complexity": "medium",
        "skills_needed": ["rust", "testing"],
        "requirement_version": "v1",
        "covered_user_stories": ["US-1~US-4 全部验收标准的自动化测试"],
        "covered_acceptance": ["Q7:C 自动化测试覆盖", "Q8:A 仅登录接口回归"],
    }
)

# T4: 代码审查（基于 T1，可与 T2 并行）
t4 = kanban_create(
    title="T4: 技术审查 JWT 实现（安全+规范）",
    assignee="tech-reviewer",
    body="""审查范围：
1. src/auth/jwt.rs：加密实现是否正确
2. src/auth/routes.rs：接口实现是否安全
3. 密码处理：是否使用恒定时间比较（timing-safe）
4. Token 黑名单：内存实现是否可扩展
5. 错误信息：是否暴露过多信息给攻击者
6. 密钥管理：私钥是否安全存储

审查 checklist：
- [ ] RS256 实现使用标准库（ring 或 rustls）
- [ ] 没有硬编码密钥
- [ ] 密码比较使用 constant_time_eq
- [ ] 错误响应不泄露用户存在性
- [ ] Token claims 包含 jti（用于撤销）
- [ ] Rate limit 对 auth 端点单独配置

依赖：T1（JWT 核心逻辑）
预期时长：30 分钟
""",
    workspace="worktree",
    parents=[t1],
    expected_duration_max="30min",
    metadata={
        "estimated_complexity": "medium",
        "review_focus": ["security", "correctness"],
        "requirement_version": "v1",
        "covered_user_stories": ["安全审查: US-1~US-4 实现的安全性"],
        "covered_acceptance": ["US-3.3: 不泄露用户存在性"],
    }
)

# T5: 修复审查问题（基于 T4）
t5 = kanban_create(
    title="T5: 修复审查发现的问题",
    assignee="implementer",
    body="""根据 T4 的审查 findings 修复代码。

注意：
- 修复后重新跑测试，确保不引入回归
- 如果 reviewer 提出架构级问题，需要 block 并升级给 Jacky

依赖：T4（审查必须先完成）
预期时长：30 分钟
""",
    workspace="worktree",
    parents=[t4],
    expected_duration_max="30min",
    metadata={
        "estimated_complexity": "low-medium",
        "depends_on_review": True,
        "requirement_version": "v1",
        "covered_user_stories": ["修复审查发现的问题，确保 US-1~US-4 安全性"],
    }
)

# T6: 最终验收（基于 T3 + T5）
t6 = kanban_create(
    title="T6: 最终验收测试和部署准备",
    assignee="devops-engineer",
    body="""1. 在 staging 环境跑完整测试套件
2. 验证环境变量配置（JWT_PRIVATE_KEY, JWT_PUBLIC_KEY）
3. 更新部署文档（如需要）
4. 准备生产环境发布

依赖：T3（测试通过）+ T5（修复完成）
预期时长：20 分钟
""",
    workspace="worktree",
    parents=[t3, t5],
    expected_duration_max="20min",
    metadata={
        "estimated_complexity": "low",
        "deployment_target": "staging",
        "requirement_version": "v1",
        "covered_user_stories": ["US-1~US-4 整体验收"],
        "covered_acceptance": ["Q7:C 手动验收", "Q9:A 基础日志验证"],
    }
)
```

**【PM 内心OS】**

> "任务图创建完毕。让我检查一下依赖关系：
> - T1（JWT 核心）无依赖，可立即开始
> - T2（HTTP 接口）依赖 T1
> - T3（测试）依赖 T2
> - T4（审查）依赖 T1，可与 T2 并行
> - T5（修复）依赖 T4
> - T6（部署）依赖 T3 和 T5
>
> 这个依赖图是合理的。最大并行度是 2（T2 和 T4 同时跑）。
> 现在完成自己的任务，把任务图提交。"

**【PM 执行完成指令】**

```python
kanban_complete(
    task_id="t_alpha_001",
    summary="已拆解为 6 个子任务：T1(核心逻辑)→T2(接口)→T3(测试)，T4(审查)与T2并行→T5(修复)→T6(部署)",
    metadata={
        "task_graph": {
            "t1": {"deps": [], "assignee": "implementer"},
            "t2": {"deps": ["t1"], "assignee": "implementer"},
            "t3": {"deps": ["t2"], "assignee": "implementer"},
            "t4": {"deps": ["t1"], "assignee": "tech-reviewer"},
            "t5": {"deps": ["t4"], "assignee": "implementer"},
            "t6": {"deps": ["t3", "t5"], "assignee": "devops-engineer"}
        },
        "estimated_total_duration": "260min (~4.3 hours)",
        "parallel_paths": ["t1→t2→t3", "t1→t4→t5"]
    }
)
```

**【系统提示】**

```
[hermes] Task t_alpha_001 completed by pm
[hermes] Task graph created: 6 sub-tasks
[hermes] Next ready tasks: [t1_alpha_001]  ← T1 无依赖，已 ready
[hermes] Dispatcher will spawn implementer for T1 in next cycle
```

---

### Step 2.4: Jacky 收到通知，查看任务图

**【场景上下文】**
Jacky 正在处理 Project Beta 的代码，手机震动了。

**【系统推送（Gateway → Telegram）】**

```
📬 Project Alpha — 任务已拆解

原始需求: 给 Alpha 加上 JWT 认证模块

已拆解为 6 个子任务：
├─ T1: 实现 JWT 核心逻辑（生成/验证/刷新 token）
│  ├─ T2: 实现 /login /register /refresh /logout 接口
│  │  └─ T3: 写单元测试和集成测试（覆盖率 ≥ 80%）
│  └─ T4: 技术审查 JWT 实现（安全+规范）
│     └─ T5: 修复审查发现的问题
└─ T6: 最终验收测试和部署准备

预计总时长: ~4.3 小时
关键路径: T1→T2→T3→T6 (3.8 小时)

[查看详情] [暂停] [追加需求]
```

**【Jacky 心理活动】**

> "拆解得挺细的。6 个任务，依赖关系清晰。
> T4（审查）依赖 T1，和 T2（HTTP 接口）并行——这个设计很聪明。
> 审查员在 Implementer 写接口的同时审查 JWT 核心逻辑，不浪费时间。
>
> 不过有个隐患：T4 只审查了 T1 的 JWT 核心逻辑，没有覆盖 T2 的 HTTP 接口。
> /login 的错误响应会不会泄露用户信息？/refresh 的 token 验证有没有时序攻击？
> 这些问题要等 T2 完成后才能审查。
> 先运行看看，如果审查结果不满意我再追加一个 T4b 审查接口。
> 预计 4.3 小时，今天下午应该能看到结果。"

Jacky 没有干预，让系统继续运行。

---

### 架构注记：PM 任务拆解数据流

| 层级 | 组件 | 职责 |
|------|------|------|
| 编排层 | PM Profile | 接收 Dispatcher 派发，读取需求文档，调用 `claude -p` PM 引擎，解析响应后调用 `kanban_create()` 创建任务 |
| 引擎层 | `claude -p` PM 引擎 | 接收需求上下文，执行任务拆解推理，返回 JSON Response Envelope（`tasks` 数组含 title、body、deps、metadata） |
| 持久层 | `kanban_create()` | 将任务写入 Kanban 存储，建立依赖关系，触发 Dispatcher 调度 |


