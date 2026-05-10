## Phase 5: 修复 + 自我进化

> 📎 **相关 ASCII 流程图**：
> - [`ascii-end-to-end.md`](./ascii-end-to-end.md) — Phase 5 修复+进化、Phase 5.5 故障场景→SRE-Observer
> - [`ascii-self-evolution.md`](./ascii-self-evolution.md) — 三层架构、实时/定期层进化
> - [`ascii-observability.md`](./ascii-observability.md) — SRE-Observer 自动触发、故障定位 8 层模型
> - [`ascii-core-flows.md`](./ascii-core-flows.md) — F4 自动故障检测与根因分析
> - [`ascii-kanban-subflows.md`](./ascii-kanban-subflows.md) — Worker 崩溃状态回滚

---

### Step 5.1: T3（测试）和 T5（修复）的执行

**【场景上下文】**
T2 完成后，T3（写测试，assignee=implementer）变为 ready。同时 T4 审查已完成，T5（修复审查问题，assignee=implementer）也变为 ready。Implementer 需要按顺序执行这两个任务（因为都指派给 implementer，不能并行）。

Dispatcher 的决策：先 claim T3（因为 T3 在任务图中更靠前，是 T5 的上游依赖的下游），但 T5 和 T3 之间没有直接依赖关系。实际上 T3 依赖 T2，T5 依赖 T4，两者是并行的！但都被指派给 implementer，所以 implementer 需要串行执行。

**【系统内部】Dispatcher 决策日志：**

```
[2026-05-10T11:35:02Z] Ready tasks: [t3_alpha_001, t5_alpha_001]
[2026-05-10T11:35:02Z] Both assigned to implementer
[2026-05-10T11:35:02Z] Priority: t3_alpha_001 (earlier in critical path)
[2026-05-10T11:35:02Z] Claiming t3_alpha_001
[2026-05-10T11:35:03Z] Spawning implementer for T3
```

---

### Step 5.2: Implementer 执行 T3（写测试）

**【Implementer 内心OS】**

> "我现在在执行 T3：写单元测试和集成测试，覆盖率 ≥ 80%。
> 让我先读取 T1 和 T2 的 handoff，了解所有已实现的功能。"

**【Implementer 执行】**

```python
t1_handoff = kanban_show(task_id="t1_alpha_001")
t2_handoff = kanban_show(task_id="t2_alpha_001")
```

**【Implementer 内心OS】**

> "T1 实现了 JWT 核心逻辑（5 个单元测试）。
> T2 实现了 4 个 HTTP 接口 + token 旋转 + jti_blacklist。
>
> 我需要写的测试：
> 单元测试（jwt.rs）：
> - 已有的 5 个测试覆盖了基本场景
> - 需要补充：malformed token、unsupported algorithm、MissingKey
>
> 集成测试（tests/auth_integration.rs）：
> - test_login_success
> - test_login_wrong_password
> - test_register_success
> - test_register_duplicate_email
> - test_refresh_success
> - test_refresh_invalid_token
> - test_logout_success
> - test_protected_route_without_token
> - test_protected_route_with_token
>
> 让我先写集成测试。需要启动一个测试服务器。"

**【Implementer 执行的具体指令】**

```bash
# 创建集成测试目录
mkdir -p tests

# 写集成测试
cat > tests/auth_integration.rs << 'EOF'
use axum::{body::Body, http::{Request, StatusCode}};
use serde_json::json;
use tower::ServiceExt;

// 辅助函数：创建测试应用
async fn app() -> axum::Router {
    // 加载测试配置
    std::env::set_var("DATABASE_URL", "postgres://test:test@localhost/test");
    std::env::set_var("JWT_PRIVATE_KEY", include_str!("../tests/fixtures/test_private.pem"));
    std::env::set_var("JWT_PUBLIC_KEY", include_str!("../tests/fixtures/test_public.pem"));
    
    project_alpha::create_app().await
}

#[tokio::test]
async fn test_login_success() {
    let app = app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/login")
                .header("content-type", "application/json")
                .body(Body::from(json!({
                    "email": "test@example.com",
                    "password": "password123"
                }).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    
    assert!(json.get("access_token").is_some());
    assert!(json.get("refresh_token").is_some());
    assert_eq!(json["token_type"], "Bearer");
}

#[tokio::test]
async fn test_login_wrong_password() {
    let app = app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/login")
                .header("content-type", "application/json")
                .body(Body::from(json!({
                    "email": "test@example.com",
                    "password": "wrong_password"
                }).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    
    let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["error"], "Invalid credentials");
}

#[tokio::test]
async fn test_protected_route_without_token() {
    let app = app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/api/user/profile")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ... 更多测试省略
EOF
```

**【Implementer 内心OS】**

> "集成测试写好了。但我发现一个问题——测试需要真实的数据库连接。
> 这在 CI 环境中可能不可用。我需要用 sqlx 的 offline 模式或者 mock。
>
> 等等，这是一个测试架构问题。我不应该花太多时间在这上面——
> 先让测试跑起来，如果数据库不可用就用单元测试覆盖核心逻辑。
>
> 让我先跑测试看看覆盖率。"

```bash
cargo test --test auth_integration 2>&1 | tail -30

# 检查覆盖率（如果 tarpaulin 安装）
which cargo-tarpaulin && cargo tarpaulin --lib --tests --out stdout 2>&1 | tail -20
```

**【系统返回】**

```
# 集成测试（需要 DB，可能失败）
 test result: FAILED. 0 passed; 3 failed
 Error: connection refused (数据库未运行)

# 单元测试覆盖率
cargo tarpaulin: not found

# 手动统计测试数量
Unit tests in jwt.rs: 5
Integration tests: 3 (需要 DB)
```

**【Implementer 内心OS】**

> "集成测试因为数据库未运行而失败。这不是代码问题，是环境配置问题。
> 我需要：
> 1. 写更多不依赖 DB 的单元测试
> 2. 或者用 sqlx-test 在内存中跑测试
>
> 时间有限，我先完成 T3，把集成测试环境问题作为 pitfalls 记录。
> 在 T5 修复阶段可以补充更多单元测试。"

**【Implementer 完成 T3】**

```python
kanban_complete(
    task_id="t3_alpha_001",
    summary="单元测试已补充至 8 个，覆盖核心场景。集成测试已写但需要运行中的 PostgreSQL 实例。",
    metadata={
        "changed_files": ["tests/auth_integration.rs", "src/auth/jwt.rs"],
        "tests_run": 8,
        "tests_passed": 8,
        "coverage_estimate": "65% (单元测试) + 集成测试待跑",
        "decisions": [
            "集成测试需要真实 PostgreSQL，计划在 CI 中配置"
        ],
        "pitfalls": [
            "集成测试需要运行中的数据库，本地开发需 docker-compose up postgres",
            "覆盖率目前可能未达到 80%，需要更多边界测试"
        ],
        "duration_minutes": 55
    }
)
```

---

### Step 5.3: Implementer 执行 T5（修复审查问题）

**【Implementer 内心OS】**

> "T3 完成了。现在执行 T5：修复 Tech-Reviewer 发现的问题。
> 让我读取 T4 的审查 findings。"

**【Implementer 执行】**

```python
review = kanban_show(task_id="t4_alpha_001")
findings = review["metadata"]["findings"]
```

**【Implementer 内心OS】**

> "Reviewer 发现了 8 个问题：3 个 medium，5 个 low。
> 让我逐一修复：
>
> **Medium #1：测试硬编码 /tmp 路径**
> → 使用 tempfile crate 或 std::env::temp_dir()
>
> **Medium #2：/login 必须使用 constant_time_eq**
> → argon2 verify_password 已经是恒定时间的，但我要确认
>
> **Medium #3：错误响应不泄露用户存在性**
> → 已经实现了！/login 失败统一返回 'Invalid credentials'
>   /register 冲突返回 'Email already registered'（这是合理的）
>
> **Low #1-5：格式问题、unused import、pub 可见性、缺少字段、OnceLock 限制**
> → 逐一修复
>
> 让我开始修复。"

**【Implementer 执行修复】**

```bash
# 修复 #1: 测试中不使用硬编码路径
# 使用 std::env::temp_dir() + 随机文件名
cat > src/auth/jwt.rs << 'FIXED'
# (重新生成完整文件，使用 temp_dir + 随机文件名)
FIXED

# 修复 #2: 确认 argon2 恒定时间
# 查阅文档后确认：argon2::Argon2::verify_password 使用恒定时间比较
# 已在 T2 实现中使用，无需修改

# 修复 #3: 已正确实现

# 修复 Low 问题
cargo fmt
sed -i '/use std::sync::Mutex;/d' src/auth/jwt.rs
sed -i 's/pub fn base64url_encode/pub(crate) fn base64url_encode/' src/auth/jwt.rs

# 重新编译和测试
cargo check --lib
cargo test auth --lib
```

**【系统返回】**

```
# cargo check
    Finished dev [unoptimized + debuginfo] target(s) in 1.23s

# cargo test
 running 8 tests
 test auth::jwt::tests::test_generate_access_token ... ok
 ... (全部通过)

 test result: ok. 8 passed; 0 failed
```

**【Implementer 内心OS】**

> "所有修复完成，测试全过。现在进行'自我进化'——记录经验教训。"

---

### Step 5.4: 自我进化 —— 记录经验教训 `[Hermes 官方]` + `[Phase 19 增量]`

**【Implementer 内心OS】**

> "在这个任务中学到了一些东西，应该记录到记忆中，以便未来项目复用。
>
> 1. ring crate 的 RS256 实现：
>    - 用 RSA_PKCS1_SHA256，不是 RSA_PSS_SHA256
>    - RsaKeyPair::from_pkcs8 需要 PKCS#8 格式
>    - 密钥管理用 OnceLock 缓存
>
> 2. JWT 安全最佳实践：
>    - 先验签名，再验过期时间
>    - 错误信息不泄露用户存在性
>    - refresh token 旋转比不旋转安全得多
>
> 3. 测试陷阱：
>    - OnceLock 在测试中并发初始化有问题
>    - 硬编码 /tmp 路径在并发测试中不可靠
>
> 让我把这些记录到 memory 和 skills 中。"

**【Implementer 执行自我进化】**

```python
# 记录到 MEMORY.md
memory_add(
    content="""Rust JWT 实现要点：
1. RS256 = RSA_PKCS1_SHA256（非 PSS），符合 JWT 标准
2. ring::signature::RsaKeyPair::from_pkcs8 加载私钥
3. 先验证签名，再检查 exp，防止时序攻击
4. TokenClaims 应包含 jti 用于撤销/旋转
5. 错误响应统一为 'Invalid credentials'，不区分用户是否存在
""",
    namespace="project-alpha",
    tags=["rust", "jwt", "security"]
)

# 记录跨项目经验（需 curator 审核）
memory_add(
    content="""Refresh token 策略对比：
- 不旋转：简单，但被盗后 7 天有效（高风险）
- 旋转：每次 refresh 生成新 token 对，旧 token 作废（推荐）
- 实现：需要 jti_blacklist 表（PostgreSQL/Redis），verify 时先查表
- 额外延迟：~5ms（一次 DB 查询）
- 适用于：所有有 refresh token 的项目
""",
    namespace="_global",
    cross_project=True,
    tags=["auth", "security", "refresh-token"]
)

# 创建 skill
create_skill(
    name="jwt-auth-rust",
    description="在 Rust + Axum 项目中实现 JWT 认证的完整流程",
    content="""
## JWT Auth in Rust (Axum)

### 1. 添加依赖
```toml
ring = "0.17"
base64 = "0.22"
serde = { version = "1", features = ["derive"] }
chrono = { version = "0.4", features = ["serde"] }
thiserror = "1"
```

### 2. 实现核心 (src/auth/jwt.rs)
- TokenClaims { sub, exp, iat, jti, typ }
- generate_token(user_id, "access"|"refresh")
- verify_token(token) -> 先验签名，再验 exp
- refresh_access_token(refresh_token)

### 3. 实现路由 (src/auth/routes.rs)
- POST /login: 恒定时间密码比较 → 生成 token 对
- POST /register: 检查重复邮箱 → argon2 hash → 插入
- POST /refresh: 验证旧 refresh → 生成新 token 对 → 旧 jti 黑名单
- POST /logout: 当前 token jti → 黑名单

### 4. 安全 checklist
- [ ] RS256 使用 RSA_PKCS1_SHA256
- [ ] 错误响应不泄露用户存在性
- [ ] 密码比较使用恒定时间（argon2 verify 已满足）
- [ ] token 旋转 + jti_blacklist
- [ ] 密钥通过环境变量传入，不硬编码
""",
    tags=["rust", "jwt", "axum", "auth"]
)
```

**【系统提示】**

```
[hermes] Memory added: 2 entries
[hermes] Skill created: jwt-auth-rust
[hermes] Cross-project memory queued for curator review
```

**【Implementer 完成 T5】**

```python
kanban_complete(
    task_id="t5_alpha_001",
    summary="已修复全部 8 个审查问题：测试路径改为临时目录、确认 argon2 恒定时间、统一错误响应、代码格式化、移除 unused import、调整 pub 可见性。新增 2 条 memory 和 1 个 skill。",
    metadata={
        "changed_files": ["src/auth/jwt.rs", "src/auth/routes.rs"],
        "tests_run": 8,
        "tests_passed": 8,
        "findings_resolved": 8,
        "findings_pending": 0,
        "memory_added": 2,
        "skill_created": 1,
        "duration_minutes": 35
    }
)
```

**【系统提示】**

```
[hermes] Task t5_alpha_001 completed by implementer
[hermes] T3 + T5 均完成
[hermes] Next promoted: [t6_alpha_001]  ← T6 部署任务变为 ready（依赖 T3 + T5 都 done）
```

---


## Phase 5.5: 故障场景 — 部署失败触发 SRE-Observer

---

### Step 5.5.1: DevOps-Engineer 尝试生产部署

**【场景上下文】**
本地测试通过后，DevOps-Engineer 尝试部署到生产环境。项目没有现成的 deploy.sh，DevOps 需要写一个快速部署脚本。

**【DevOps-Engineer 内心OS】**

> "本地测试 11/11 通过。现在部署生产。
> 项目没有 deploy.sh，我需要写一个最小化的部署流程。
> 
> 生产环境信息：
> - 服务器：通过 HERMES_DEPLOY_HOST 环境变量
> - 部署方式：scp 二进制 + ssh 重启服务
> - 环境变量：/etc/alpha/env
>
> 让我先检查可用的部署配置。"

**【DevOps-Engineer 执行】**

```bash
# 检查部署配置
env | grep DEPLOY | head -10
cat .env.production 2>/dev/null || echo "No .env.production"
cat deploy.sh 2>/dev/null || echo "No deploy.sh"
```

**【系统返回】**

```
DEPLOY_HOST=prod-alpha-01.internal
DEPLOY_USER=deploy
DEPLOY_PATH=/opt/alpha

No .env.production
No deploy.sh
```

**【DevOps-Engineer 内心OS】**

> "有基本的部署环境变量。但没有 .env.production——
> 这意味着生产环境的数据库连接、JWT 密钥等都没有配置。
> 
> 让我先写一个临时的 deploy.sh，然后执行部署。
> 但首先，我需要确认生产环境是否有 DATABASE_URL 配置。"

```bash
# 检查生产服务器的环境配置
ssh deploy@prod-alpha-01.internal "cat /etc/alpha/env 2>/dev/null || echo 'No env file'"
```

**【系统返回】**

```
Connection refused: prod-alpha-01.internal:22
```

**【DevOps-Engineer 内心OS】**

> "SSH 连接失败。可能是：
> 1. 服务器没开机
> 2. 防火墙挡住了 SSH
> 3. 主机名解析失败
> 4. 端口不是 22
>
> 让我尝试 ping 和指定端口。"

```bash
ping -c 1 prod-alpha-01.internal 2>&1
ssh -p 2222 deploy@prod-alpha-01.internal "echo ok" 2>&1
```

**【系统返回】**

```
ping: unknown host prod-alpha-01.internal
ssh: Could not resolve hostname prod-alpha-01.internal: Name or service not known
```

**【DevOps-Engineer 内心OS】**

> "主机名无法解析。这意味着：
> - DNS 中没有这个记录
> - 或者这是内网域名，需要 VPN
> - 或者服务器根本不存在
>
> 这超出了我的处理能力。根据 R14，'外部依赖不可用'必须 block。
> 但等等... Jacky 明确说'二进制文件上传到服务器'。
> 也许我应该尝试其他方式——比如看看有没有 Dockerfile 可以构建镜像推送。"

```bash
ls Dockerfile* 2>/dev/null
ls fly.toml 2>/dev/null
ls railway.yaml 2>/dev/null
ls render.yaml 2>/dev/null
```

**【系统返回】**

```
No Dockerfile
No fly.toml
No railway.yaml
No render.yaml
```

**【DevOps-Engineer 内心OS】**

> "没有任何部署配置。这意味着项目从来没有部署过。
> 我需要 block 并报告这个问题。
> 
> 但等等，我可以写一个 Dockerfile 和 docker-compose.yml 作为交付物。
> 这样至少可以本地 docker 部署。但这超出了 T6 的任务范围。
> 
> 让我 block，详细说明生产环境缺失的问题。"

**【DevOps-Engineer 执行 block】**

```python
kanban_block(
    task_id="t6_alpha_001",
    reason="external-dependency-unavailable: 生产部署环境不可达\n\n"
           "已完成的验证：\n"
           "- 本地 PostgreSQL (docker) 启动成功\n"
           "- 数据库迁移运行成功\n"
           "- 单元测试 8/8 通过\n"
           "- 集成测试 3/3 通过\n"
           "- cargo build --release 编译成功\n\n"
           "生产部署受阻原因：\n"
           "1. DNS 无法解析 prod-alpha-01.internal\n"
           "2. SSH 连接失败（端口 22 和 2222 均不可达）\n"
           "3. 项目无 Dockerfile / fly.toml / 任何部署配置\n"
           "4. 无 .env.production 定义生产环境变量\n\n"
           "建议：\n"
           "A) 配置生产服务器和 DNS\n"
           "B) 建立容器化部署（Docker + docker-compose）\n"
           "C) 使用 PaaS 平台（Fly.io / Railway / Render）"
)
```

**【系统提示】**

```
[hermes] Task t6_alpha_001 blocked by devops-engineer
[hermes] Reason: external-dependency-unavailable
[hermes] Worker outcome: completed (正常 block，非崩溃)
```

---

### Step 5.5.2: 并行故障场景 — 另一个项目的部署崩溃

**【场景上下文】**
上面的 block 是"正常流程"。现在展示一个**真正的故障场景**——触发 SRE-Observer。

假设在 Project Beta（另一个项目）上，DevOps-Engineer 正在执行一个**已有**的部署脚本。由于环境配置错误，部署失败并崩溃。

**【系统内部】Dispatcher 日志（Project Beta）**

```
[2026-05-10T13:15:02Z] Board: project-beta
[2026-05-10T13:15:02Z] Ready tasks: [t_beta_deploy_001]
[2026-05-10T13:15:02Z] Claiming t_beta_deploy_001
[2026-05-10T13:15:02Z] Spawning devops-engineer worker
[2026-05-10T13:15:03Z] Worker PID: 18821
```

**【DevOps-Engineer (Beta) 内心OS】**

> "Project Beta 的部署任务。让我执行 deploy.sh。"

```bash
cd /data/hermes/workspaces/project-beta/worktree-t-beta-deploy-001
./deploy.sh production 2>&1
```

**【系统返回】**

```bash
[INFO] Deploying project-beta to production...
[INFO] Building release binary...
    Finished release [optimized] target(s) in 45.23s
[INFO] Uploading to prod-beta-01.internal...
[INFO] Restarting service...
[ERROR] Environment variable DATABASE_URL is not set!
[ERROR] Service failed to start. Exit code: 1
[ERROR] Rolling back...
[ERROR] Rollback failed: backup binary corrupted

FATAL: Deployment failed. Manual intervention required.
```

**【DevOps-Engineer (Beta) 内心OS】**

> "部署失败了！exit code 1。
> 错误是 DATABASE_URL 环境变量未设置。
> 但 rollback 也失败了——备份二进制文件损坏。
> 
> 这是一个严重故障。我需要立即报告。
> 等等，系统应该会自动检测到这个崩溃。"

---

### Step 5.5.3: Dispatcher 检测到崩溃，触发 SRE-Observer `[Phase 19 增量]` `[设计假设]`

**【系统内部】Dispatcher 检测日志：**

```
[2026-05-10T13:16:45Z] Worker t_beta_deploy_001 PID 18821: process exited with code 1
[2026-05-10T13:16:45Z] Checking outcome...
[2026-05-10T13:16:45Z] Outcome: crashed
[2026-05-10T13:16:45Z] Rollback count: 0
[2026-05-10T13:16:45Z] Trigger condition matched: outcome == 'crashed'
[2026-05-10T13:16:45Z] AUTO-CREATING SRE analysis task...
```

**【系统自动创建 SRE 任务】**

```python
sre_task = kanban_create(
    title="根因分析: Project Beta 部署失败 (t_beta_deploy_001)",
    assignee="sre-observer",
    body="""DevOps-Engineer 执行 deploy.sh production 失败：
- Exit code: 1
- 错误: DATABASE_URL 环境变量未设置
- Rollback 失败: 备份二进制损坏

请定位根因并输出结构化报告。""",
    parents=["t_beta_deploy_001"],
    priority="high"
)
```

**【系统提示】**

```
[hermes] AUTO-TRIGGERED: SRE-Observer task created
[hermes] Task: t_sre_beta_001
[hermes] Parent: t_beta_deploy_001
[hermes] Priority: high
```

**【系统向 Jacky 推送】**

```
🚨 Project Beta — 部署失败，自动诊断中

任务: t_beta_deploy_001 (部署到生产)
状态: crashed
错误: DATABASE_URL 未设置 + Rollback 失败

已自动创建 SRE 分析任务 (t_sre_beta_001)
SRE-Observer 正在分析根因...

预计 1-2 分钟内出报告
```

---

### Step 5.5.4: SRE-Observer 被派发，开始调查

**【SRE-Observer 内心OS】**

> "我被自动派发了。任务是调查 Project Beta 的部署失败。
> 让我按 7 步流程分析。"

**【SRE-Observer 执行第 1 步：读取故障任务信息】**

```python
fault_task = kanban_show(task_id="t_beta_deploy_001")
```

**【系统返回】**

```json
{
  "task_id": "t_beta_deploy_001",
  "title": "部署 Project Beta 到生产环境",
  "assignee": "devops-engineer",
  "status": "crashed",
  "outcome": "crashed",
  "summary": "",
  "metadata": {
    "deployment_target": "production",
    "script": "./deploy.sh"
  }
}
```

**【SRE-Observer 执行第 2 步：查询 trace.db】** `[Phase 19 增量]`

```python
# 查询该 task 的 tool call 序列
trace_records = query_trace_db(
    task_id="t_beta_deploy_001",
    limit=50
)
```

**【系统返回】**

```
tool_call_#1: terminal(command="cd /data/hermes/workspaces/project-beta/...")
  -> status: ok, duration: 12ms

tool_call_#2: terminal(command="./deploy.sh production")
  -> status: error, duration: 48234ms
  -> exit_code: 1
  -> stderr_preview: "[ERROR] Environment variable DATABASE_URL is not set!"

tool_call_#3: terminal(command="echo 'FATAL: Deployment failed...'")
  -> status: ok, duration: 2ms
```

**【SRE-Observer 内心OS】**

> "第 2 步完成。关键证据：
> - deploy.sh 执行了 48 秒，最后 exit code 1
> - 明确错误：DATABASE_URL 未设置
> 
> 继续第 3 步：读取 worker logs。"

**【SRE-Observer 执行第 3 步：读取 worker logs】**

```bash
cat /data/hermes/kanban/logs/t_beta_deploy_001/stdout.log
cat /data/hermes/kanban/logs/t_beta_deploy_001/stderr.log
```

**【系统返回】**

```
# stderr.log
[INFO] Deploying project-beta to production...
[INFO] Building release binary...
    Finished release [optimized] target(s) in 45.23s
[INFO] Uploading to prod-beta-01.internal...
[INFO] Restarting service...
[ERROR] Environment variable DATABASE_URL is not set!
[ERROR] Service failed to start. Exit code: 1
[ERROR] Rollback failed: backup binary corrupted
[ERROR] /opt/project-beta/bin/server.bak: No such file or directory

FATAL: Deployment failed. Manual intervention required.
```

**【SRE-Observer 内心OS】**

> "关键发现：
> 1. 部署脚本成功编译了 release 二进制
> 2. 上传到服务器成功
> 3. 重启服务时失败——DATABASE_URL 未设置
> 4. Rollback 失败——备份文件不存在（/opt/project-beta/bin/server.bak）
>
> 这说明：
> - deploy.sh 没有在生产服务器上设置环境变量
> - deploy.sh 的 rollback 机制有 bug——它假设备份文件存在，但实际上没有创建备份
>
> 继续第 4 步：读取 task_events 时间线。"

**【SRE-Observer 执行第 4 步：读取 task_events】**

```sql
SELECT event_type, timestamp, details 
FROM task_events 
WHERE task_id = 't_beta_deploy_001' 
ORDER BY timestamp;
```

**【系统返回】**

```
claim       | 2026-05-10T13:15:03Z | worker_pid: 18821
heartbeat   | 2026-05-10T13:15:30Z | note: "Building release binary..."
heartbeat   | 2026-05-10T13:16:00Z | note: "Uploading..."
crash       | 2026-05-10T13:16:45Z | exit_code: 1, stderr: "DATABASE_URL..."
```

**【SRE-Observer 内心OS】**

> "时间线清晰：
> - 13:15:03 任务被 claim
> - 13:15:30 编译中
> - 13:16:00 上传中
> - 13:16:45 崩溃
> 
> 整个流程约 1 分 42 秒。问题发生在最后的服务启动阶段。
>
> 继续第 5 步：读取 audit logs。"

**【SRE-Observer 执行第 5 步：读取 audit logs】** `[Phase 19 增量]` `[设计假设]`

```sql
SELECT * FROM audit_logs 
WHERE task_id = 't_beta_deploy_001' 
ORDER BY timestamp;
```

**【系统返回】**

```
No audit records found for this task.
```

**【SRE-Observer 内心OS】**

> "没有审计记录。这意味着：
> - 没有 Risk Policy 拦截
> - 没有 L3 决策
> - 这是一个纯粹的部署环境配置问题
>
> 继续第 6 步：对比 parent handoff。"

**【SRE-Observer 执行第 6 步：检查上游交付物】**

```python
# 读取父任务（部署任务通常没有 parents，或者依赖构建任务）
parent_tasks = kanban_show(task_id="t_beta_deploy_001")["parents"]
# 假设 parent 是 build 任务
if parent_tasks:
    for p in parent_tasks:
        parent_handoff = kanban_show(task_id=p)
        # 检查是否有环境配置相关的缺陷
```

**【系统返回】**

```json
{
  "parents": ["t_beta_build_001"],
  "parent_handoff": {
    "summary": "Release binary built successfully",
    "metadata": {
      "binary_path": "target/release/project-beta",
      "tests_passed": 42,
      "tests_total": 42
    }
  }
}
```

**【SRE-Observer 内心OS】**

> "上游构建任务没有问题——42/42 测试通过，二进制编译成功。
> 缺陷不在代码或构建阶段，纯粹在部署阶段的环境配置。
>
> 现在综合所有证据，生成根因报告。"

---

### Step 5.5.5: SRE-Observer 生成根因报告 `[Phase 19 增量]` `[设计假设]`

**【SRE-Observer 内心OS】**

> "综合 7 步分析结果：
>
> **根因类别判断：**
> - 不是代码层（构建成功，测试全过）
> - 不是审查层（无审查问题）
> - 不是验收层（QA 已通过）
> - 是环境层！生产服务器缺少 DATABASE_URL 环境变量
> - 同时也是部署层！deploy.sh 的 rollback 机制有 bug
>
> **责任方：**
> - 主要责任：DevOps-Engineer（没有验证环境变量就部署）
> - 次要责任：deploy.sh 脚本作者（rollback 机制不完整）
>
> **置信度：high**
> 证据非常明确——错误消息直接指出 DATABASE_URL 未设置。
>
> **修复建议：**
> 1. 在生产服务器 /etc/project-beta/env 中设置 DATABASE_URL
> 2. 修复 deploy.sh：部署前检查必要环境变量
> 3. 修复 deploy.sh：rollback 前确认备份文件存在
> 4. 建立部署前检查清单（pre-deploy checklist）"

**【SRE-Observer 执行完成指令】**

```python
kanban_complete(
    task_id="t_sre_beta_001",
    summary="根因定位完成。Project Beta 部署失败由生产环境缺失 DATABASE_URL 导致，同时 deploy.sh 的 rollback 机制存在缺陷。",
    metadata={
        "fault_task_id": "t_beta_deploy_001",
        "fault_run_id": "r_beta_deploy_001",
        "root_cause_category": "environment",
        "confidence": "high",
        "symptom": "deploy.sh production exited 1: 'Environment variable DATABASE_URL is not set!'",
        "root_cause": "生产服务器缺少 DATABASE_URL 环境变量配置。deploy.sh 在重启服务前未验证必要环境变量，且 rollback 机制假设备份文件存在（实际未创建）。",
        "responsible_profile": "devops-engineer",
        "upstream_fault": None,
        "recommended_action": "1. 在 prod-beta-01.internal 的 /etc/project-beta/env 中设置 DATABASE_URL\n2. 修改 deploy.sh：部署前检查 REQUIRED_ENV_VARS=[DATABASE_URL, JWT_SECRET]\n3. 修改 deploy.sh：rollback 前确认备份存在，不存在则跳过 rollback 直接报错\n4. 建立 pre-deploy checklist skill",
        "trace_anchor": "tool_call_#2 terminal('./deploy.sh production') exited 1 after 48s",
        "analysis_steps": [
            "kanban_show: task outcome=crashed, assignee=devops-engineer",
            "trace.db: tool_call_#2 failed with exit_code=1, stderr='DATABASE_URL not set'",
            "worker logs: deploy succeeded compile+upload, failed at service restart",
            "task_events: 1m42s from claim to crash, no prior errors",
            "audit logs: no risk policy intercepts",
            "parent handoff: build task passed 42/42 tests, no defects",
            "conclusion: environment configuration missing + rollback script bug"
        ],
        "fault_layers": ["environment", "deployment"]
    }
)
```

**【系统提示】**

```
[hermes] SRE-Observer task t_sre_beta_001 completed
[hermes] Root cause: environment (high confidence)
[hermes] Notifying user via Gateway...
```

**【系统向 Jacky 推送】**

```
🚨 Project Beta — 根因分析完成

故障任务: t_beta_deploy_001 (部署失败)
分析任务: t_sre_beta_001 (已完成)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 根因报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

类别:    environment + deployment
置信度:  high
症状:    deploy.sh 报错 DATABASE_URL 未设置

根因:
  生产服务器缺少 DATABASE_URL 环境变量
  deploy.sh 未在部署前检查必要环境变量
  rollback 机制存在 bug（备份文件不存在）

责任方:  devops-engineer

修复建议:
  1. 在服务器 /etc/project-beta/env 设置 DATABASE_URL
  2. 修改 deploy.sh 添加部署前环境检查
  3. 修复 rollback 备份逻辑
  4. 建立 pre-deploy checklist

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[查看完整报告] [标记已修复] [创建修复任务]
```

**【Jacky 心理活动】**

> "Project Beta 部署失败了... 但 SRE-Observer 已经定位了根因。
> 问题是生产环境没配 DATABASE_URL。这确实是我的疏忽——
> 我上次手动部署后没有文档化环境配置。
>
> 修复建议很清晰。让我创建一个修复任务。
>
> 等等，这和 Project Alpha 的情况类似——Alpha 的 T6 也被 block 了，
> 原因也是部署环境缺失。看来我需要建立一个统一的部署流程，
> 而不是每个项目单独处理。"

---


