## Phase 4: 测试 + 审查（并行）

> 📎 **相关 ASCII 流程图**：
> - [`ascii-end-to-end.md`](./ascii-end-to-end.md) — Phase 4 测试+审查（并行）
> - [`ascii-decision-matrix.md`](./ascii-decision-matrix.md) — L3 升级流程（完整路径）、声明式风险策略引擎
> - [`ascii-core-flows.md`](./ascii-core-flows.md) — F3 L3 风险升级与用户决策
> - [`ascii-kanban-subflows.md`](./ascii-kanban-subflows.md) — Handoff 机制

---

### Step 4.1: Dispatcher 并行派发 T2 和 T4 `[Hermes 官方]`

**【场景上下文】**
T1 完成后，T2（HTTP 接口，assignee=implementer）和 T4（代码审查，assignee=tech-reviewer）同时变为 ready。Dispatcher 检测到两者都满足 parents 条件。

**【系统内部】Dispatcher 决策日志：**

```
[2026-05-10T10:14:02Z] Dispatcher cycle start
[2026-05-10T10:14:02Z] Ready tasks: [t2_alpha_001, t4_alpha_001]
[2026-05-10T10:14:02Z] Backpressure check:
[2026-05-10T10:14:02Z]   implementer_ready: 1
[2026-05-10T10:14:02Z]   reviewer_ready: 1
[2026-05-10T10:14:02Z]   ratio: 1.0 (≤ 2.0, normal)
[2026-05-10T10:14:02Z] Claiming t2_alpha_001 (implementer)
[2026-05-10T10:14:02Z] Claiming t4_alpha_001 (tech-reviewer)
[2026-05-10T10:14:03Z] Spawning 2 workers in parallel
[2026-05-10T10:14:03Z] Worker implementer PID: 18692
[2026-05-10T10:14:03Z] Worker tech-reviewer PID: 18693
```

**【系统向 Jacky 推送】**

```
🔧 Project Alpha — 2 个任务并行启动

T2: 实现 /login /register /refresh /logout 接口
负责人: Implementer
预计: 90 分钟

T4: 技术审查 JWT 实现（安全+规范）
负责人: Tech-Reviewer
预计: 30 分钟

并行执行中...
```

---

### Step 4.2: Tech-Reviewer 被唤醒，读取 T1 Handoff

**【Tech-Reviewer 内心OS】**

> "我被派发了审查任务 T4。让我先读取父任务 T1 的 handoff，了解 Implementer 做了什么。
> 根据 R10，我的 toolsets 是白名单：file_read、kanban_read、kanban_block、kanban_complete、clarify。
> 我可以用 terminal 运行 lint/typecheck，但写操作会被 R8 拦截。
>
> 我的职责是：找安全问题、规范问题、实现缺陷。"

**【Tech-Reviewer 执行的具体指令】**

```python
# 读取自己的审查任务
kanban_show(task_id="t4_alpha_001")
```

**【系统返回】**

```json
{
  "task_id": "t4_alpha_001",
  "title": "T4: 技术审查 JWT 实现（安全+规范）",
  "body": "审查范围：1. src/auth/jwt.rs...",
  "assignee": "tech-reviewer",
  "status": "running",
  "parents": ["t1_alpha_001"]
}
```

**【Tech-Reviewer 执行】**

```python
# 读取父任务 T1 的 handoff
parent = kanban_show(task_id="t1_alpha_001")
# 获取 changed_files
files_to_review = parent["metadata"]["changed_files"]
# 获取 decisions 和 pitfalls
review_context = {
    "decisions": parent["metadata"]["decisions"],
    "pitfalls": parent["metadata"]["pitfalls"]
}
```

**【Tech-Reviewer 内心OS】**

> "Implementer 改了 5 个文件，做了 4 个关键决策，发现了 3 个 pitfalls。
> 让我按 checklist 逐一审查。先看 jwt.rs 的核心实现。"

---

### Step 4.3: Tech-Reviewer 审查 jwt.rs

**【Tech-Reviewer 执行的具体指令】**

```bash
cd /data/hermes/workspaces/project-alpha/worktree-t4-alpha-001

# 读取 jwt.rs 完整内容
cat src/auth/jwt.rs
```

**【Tech-Reviewer 逐行审查内心OS】**

> "让我逐段审查...
>
> **TokenClaims 结构体：**
> sub, exp, iat, jti, typ — 字段齐全。但缺少 `nbf` (not before) 和 `iss` (issuer)。
> 这不是安全问题，只是完整性。先标记为建议。
>
> **get_private_key / get_public_key：**
> 使用 OnceLock 缓存，避免重复读取环境变量。好。
> 但环境变量的错误处理只返回 MissingKey，没有区分"未设置"和"读取失败"。
> 轻微问题。
>
> **generate_token：**
> - 使用 SystemRandom::new() 每次调用都创建新实例。ring 文档说可以复用，但这不是安全问题。
> - Duration::minutes(15) 和 Duration::days(7) — 符合需求。
> - jti 包含 uuid + timestamp — 足够唯一。
> - 等等... uuid crate 的依赖增加了。Implementer 在 pitfalls 中提到了。
>
> **verify_token：**
> - 检查 parts.len() == 3 — 好。
> - base64url 解码 — 好。
> - 签名验证... 等等！
>
> 🔴 **发现严重问题：**
> verify_token 在验证签名之前，先解码了 claims 并检查了 exp？
> 不，让我再看一遍代码...
>
> 代码顺序是：
> 1. 分割 token
> 2. base64 解码 header, claims, signature
> 3. 验证签名（public_key.verify）
> 4. 解析 header，检查 alg == "RS256"
> 5. 解析 claims
> 6. 检查 exp > now
>
> 这个顺序是对的！先验签名，再验过期时间。
> 但有一个时序攻击风险：如果 signature 验证失败，我们立即返回 InvalidSignature，
> 但解析 claims 是在签名验证之后。所以攻击者无法通过错误响应判断 token 是否过期。
> 这其实是好的！
>
> 等等，还有一个问题...
>
> 🔴 **发现安全问题 #1：**
> `generate_token` 没有对 `user_id` 做长度限制。如果 user_id 非常长，
> 可能导致 token 超出 HTTP header 大小限制。虽然这不是直接的安全漏洞，
> 但可能导致拒绝服务（DoS）。
> 严重性：low。建议加上长度检查。
>
> 🔴 **发现安全问题 #2：**
> 测试代码中 `setup_keys()` 使用了 `std::fs::read_to_string("/tmp/test_private.pem")`。
> 这意味着测试依赖文件系统的 /tmp 目录。更关键的是，
> 如果测试在生产环境中运行（虽然不应该），可能读取到系统上的其他 PEM 文件。
> 严重性：medium。测试不应该硬编码路径。
>
> 🔴 **发现安全问题 #3（最重要）：**
> 在 routes.rs 还没实现（那是 T2 的任务），但我需要审查 checkilst 中提到的
> '密码比较使用恒定时间比较'。
> 目前 jwt.rs 中没有涉及密码比较，那是 T2 的范畴。
> 但我要在审查报告中提醒：T2 实现 /login 时必须使用 constant_time_eq。
>
> **算法正确性：**
> Implementer 在 decisions 中说'RS256 使用 RSA_PKCS1_SHA256（非 PSS）'。
> 让我验证... 代码中确实用了 `RSA_PKCS1_SHA256`。
> 这是正确的。RS256 = RSASSA-PKCS1-v1_5 using SHA-256。
>
> **密钥管理：**
> 私钥/公钥通过环境变量传入，没有硬编码。✓
> 但 OnceLock 是全局状态，这意味着：
> - 不支持运行时轮换密钥（需要重启进程）
> - 多租户场景下无法区分不同租户的密钥
> 对于当前单租户 SaaS 来说这不是问题，但未来扩展时需要注意。
> 标记为建议。
>
> **错误信息泄露：**
> JwtError 的 Display 实现：
> - `Expired` → "token has expired"
> - `InvalidSignature` → "invalid signature"
> - `InvalidFormat` → "invalid token format"
> 这些错误信息不会泄露用户存在性。✓
> 但如果 T2 的 /login 返回 "user not found" vs "password incorrect"，
> 就会泄露用户存在性。我需要在审查报告中提醒。
>
> 让我运行一下静态分析和测试。"

---

### Step 4.4: Tech-Reviewer 运行静态分析

**【Tech-Reviewer 执行的具体指令】**

```bash
cd /data/hermes/workspaces/project-alpha/worktree-t4-alpha-001

# 运行 cargo clippy（lint）
cargo clippy --lib -- -D warnings 2>&1 | head -50

# 运行 cargo check
cargo check --lib 2>&1 | head -30

# 运行 cargo fmt 检查
cargo fmt -- --check 2>&1
```

**【系统返回】**

```
# clippy 输出
warning: unused import: `std::sync::Mutex`
  --> src/auth/jwt.rs:1:1
   |
   | use std::sync::Mutex;
   |     ^^^^^^^^^^^^^^^^^
   |
   = note: `#[warn(unused_imports)]` on by default

warning: function `base64url_encode` is never used outside of tests
  --> src/auth/jwt.rs:45:4
   |
   | pub fn base64url_encode(data: &[u8]) -> String {
   |     ^^^^^^^^^^^^^^^^^^^
   |
   = note: this function is `pub` but not used externally

# cargo check
    Finished dev [unoptimized + debuginfo] target(s) in 0.12s

# cargo fmt
src/auth/jwt.rs: diff found
```

**【Tech-Reviewer 内心OS】**

> "Clippy 有两个 warning：
> 1. unused import Mutex — Implementer 尝试修复 OnceLock 问题时加的，但没用到。清洁问题。
> 2. base64url_encode is never used outside of tests — 这个函数只在 jwt.rs 内部使用，
>    但标记为 pub。虽然测试在 mod 内部可以访问 private 函数，但 Implementer 可能为了测试方便标记为 pub。
>    建议改为 pub(crate)。
>
> cargo fmt 发现格式问题 — Implementer 没有运行 fmt。
>
> 让我再运行测试确认通过性。"

---

### Step 4.5: Tech-Reviewer 运行测试并确认

**【Tech-Reviewer 执行的具体指令】**

```bash
# 运行测试
export JWT_PRIVATE_KEY=$(cat /tmp/test_private.pem)
export JWT_PUBLIC_KEY=$(cat /tmp/test_public.pem)
cargo test auth::jwt --lib 2>&1

# 检查测试覆盖率（用 cargo tarpaulin，如果已安装）
# 或者至少检查测试数量
grep -c "fn test_" src/auth/jwt.rs
```

**【系统返回】**

```
 running 5 tests
 test auth::jwt::tests::test_generate_access_token ... ok
 test auth::jwt::tests::test_generate_refresh_token ... ok
 test auth::jwt::tests::test_refresh_access_token ... ok
 test auth::jwt::tests::test_verify_expired_token ... ok
 test auth::jwt::tests::test_verify_invalid_signature ... ok

 test result: ok. 5 passed; 0 failed; 0 ignored

5 tests found
```

**【Tech-Reviewer 内心OS】**

> "5 个测试都过了。但我注意到测试没有覆盖所有边界情况：
> - 缺少 malformed token 测试（不是 3 段的 token）
> - 缺少 unsupported algorithm 测试
> - 缺少 MissingKey 测试（环境变量未设置）
> - 测试使用全局 /tmp 文件，有并发问题
>
> 不过审查任务的范围是审查'已实现'的代码，不是写新的测试。
> 这些可以作为建议提出。
>
> 让我汇总审查结果。"

---

### Step 4.6: Tech-Reviewer 提交审查报告

**【Tech-Reviewer 内心OS】**

> "让我按严重性分类 findings：
>
> **High（必须修复）：**
> 1. 无 — 核心安全逻辑是正确的
>
> **Medium（建议修复）：**
> 1. 测试代码硬编码 /tmp 路径，应使用临时目录
> 2. /login 实现（T2）必须使用恒定时间密码比较（constant_time_eq）
> 3. 错误响应不能泄露用户存在性（T2）
>
> **Low（可选优化）：**
> 1. cargo fmt 未运行，代码格式不一致
> 2. base64url_encode 应为 pub(crate) 而非 pub
> 3. unused import Mutex
> 4. TokenClaims 缺少 nbf/iss 字段
> 5. OnceLock 不支持运行时密钥轮换
>
> 总体评价：JWT 核心逻辑实现正确，安全逻辑无重大缺陷。
> 但需要在 T2 和 T5 中修复上述问题。
> 我批准 T1 通过，但附带条件。"

**【Tech-Reviewer 执行完成指令】**

```python
kanban_complete(
    task_id="t4_alpha_001",
    summary="审查完成。JWT 核心逻辑实现正确，RS256 算法使用正确，无重大安全缺陷。发现 3 个 medium 和 5 个 low 级别问题，需要在 T2/T5 中修复。",
    metadata={
        "approved": True,
        "approval_conditions": ["T2 必须使用 constant_time_eq 比较密码", "T2 错误响应不能泄露用户存在性"],
        "findings": [
            {
                "severity": "medium",
                "file": "src/auth/jwt.rs",
                "line": "test section",
                "issue": "测试代码硬编码 /tmp/test_private.pem 路径，应使用 std::env::temp_dir() 或 tempfile crate",
                "rationale": "硬编码路径在并发测试或不同环境中会失败"
            },
            {
                "severity": "medium",
                "file": "src/auth/routes.rs (T2)",
                "line": "待实现",
                "issue": "/login 密码比较必须使用 constant_time_eq，防止时序攻击",
                "rationale": "argon2 verify 通常已做恒定时间，但需显式确认"
            },
            {
                "severity": "medium",
                "file": "src/auth/routes.rs (T2)",
                "line": "待实现",
                "issue": "错误响应必须统一：/login 失败时返回 'Invalid credentials'，不区分 'user not found' 和 'wrong password'",
                "rationale": "区分错误类型会泄露用户注册状态，可被用于用户枚举攻击"
            },
            {
                "severity": "low",
                "file": "src/auth/jwt.rs",
                "line": "1",
                "issue": "unused import: std::sync::Mutex",
                "rationale": "清洁问题，clippy warning"
            },
            {
                "severity": "low",
                "file": "src/auth/jwt.rs",
                "line": "45",
                "issue": "base64url_encode 标记为 pub 但只在模块内使用，建议改为 pub(crate)",
                "rationale": "减少 API 表面，避免外部误用"
            },
            {
                "severity": "low",
                "file": "全项目",
                "line": "N/A",
                "issue": "cargo fmt 未运行，代码格式不一致",
                "rationale": "清洁问题，影响可读性"
            },
            {
                "severity": "low",
                "file": "src/auth/jwt.rs",
                "line": "15-22",
                "issue": "TokenClaims 缺少 nbf (not before) 和 iss (issuer) 字段",
                "rationale": "不影响安全性，但不符合 JWT 最佳实践"
            },
            {
                "severity": "low",
                "file": "src/auth/jwt.rs",
                "line": "27-42",
                "issue": "OnceLock 全局缓存不支持运行时密钥轮换",
                "rationale": "当前单租户场景无影响，未来多租户需重构"
            }
        ],
        "security_score": "B+",
        "code_quality_score": "B"
    }
)
```

**【系统提示】**

```
[hermes] Task t4_alpha_001 completed by tech-reviewer
[hermes] Approved: True (with conditions)
[hermes] Findings: 3 medium, 5 low
[hermes] Next promoted: [t5_alpha_001]  ← T5 修复任务变为 ready
```

---

### Step 4.7: 同时——Implementer 执行 T2（HTTP 接口）

**【场景上下文】**
在 Tech-Reviewer 审查 T1 的同时，Implementer 正在执行 T2（HTTP 接口）。这两个任务是并行的。

**【Implementer 内心OS】**

> "我现在在执行 T2：实现 4 个 HTTP 接口。
> 让我读取 T1 的 handoff，了解 JWT 核心逻辑的 API。"

**【Implementer 执行】**

```python
parent = kanban_show(task_id="t1_alpha_001")
```

**【Implementer 内心OS】**

> "T1 已经完成。JWT 核心逻辑提供了这些 API：
> - generate_token(user_id, token_type) -> String
> - verify_token(token) -> Result<TokenClaims, JwtError>
> - refresh_access_token(refresh_token) -> Result<String, JwtError>
> - TokenClaims { sub, exp, iat, jti, typ }
> - JwtError { Expired, InvalidSignature, InvalidFormat, ... }
>
> 我需要实现：
> 1. src/auth/routes.rs — 4 个 Axum handler
> 2. src/auth/middleware.rs — auth 中间件（验证 access token）
> 3. 更新 src/main.rs 注册路由
> 4. 更新 Cargo.toml（如果缺依赖）
>
> 先检查现有 users 表和路由结构。"

---

### Step 4.8: Implementer 查看现有代码并规划实现

**【Implementer 执行的具体指令】**

```bash
cat src/models/user.rs
cat src/routes/users.rs
cat src/main.rs
```

**【系统返回】**

```rust
// src/models/user.rs
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(FromRow, Serialize, Debug)]
pub struct User {
    pub id: String,
    pub email: String,
    pub password_hash: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

// src/routes/users.rs
use axum::{extract::State, http::StatusCode, Json};
use serde::Deserialize;
use sqlx::PgPool;

#[derive(Deserialize)]
pub struct RegisterRequest {
    email: String,
    password: String,
}

pub async fn register_handler(
    State(pool): State<PgPool>,
    Json(req): Json<RegisterRequest>,
) -> StatusCode {
    // 现有实现：argon2 hash + insert
    StatusCode::CREATED
}

// src/main.rs
use axum::{routing::post, Router};
use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() {
    let pool = PgPoolOptions::new()
        .connect(&std::env::var("DATABASE_URL").unwrap())
        .await
        .unwrap();
    
    let app = Router::new()
        .route("/register", post(routes::users::register_handler))
        .route("/login", post(routes::users::login_handler))
        .layer(middleware::cors::cors_layer())
        .layer(middleware::rate_limit::rate_limit_layer())
        .with_state(pool);
    
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

**【Implementer 内心OS】**

> "好的，现有代码结构清晰：
> - User 模型已有 id, email, password_hash
> - 已有 /register 和 /login 路由（但可能是简单的 session-based）
> - main.rs 使用 Axum Router，已有 cors 和 rate_limit 中间件
> - 数据库连接通过 State 传递
>
> 我需要：
> 1. 改造 /register 和 /login 返回 JWT token 对
> 2. 新增 /refresh 和 /logout
> 3. 新增 auth 中间件（从 Header 提取 token）
> 4. 在 Router 中插入 auth 中间件
>
> 关于密码比较：现有代码用 argon2，它的 verify 函数内部已经做了恒定时间比较。
> 但我需要确认这一点... 根据 argon2 crate 文档，`argon2::Argon2::verify_password` 确实是恒定时间的。
> 好，这满足 reviewer 的要求。
>
> 关于错误响应不泄露用户存在性：
> - /login 失败时统一返回 'Invalid credentials'（401）
> - /register 时如果邮箱已存在，返回 'Email already registered'（409）—— 这是正常的，因为用户需要知道注册是否成功
>
> 让我开始编码。"

---

### Step 4.9: Implementer 实现 HTTP 接口（节选）

**【Implementer 执行的具体指令】**

```bash
cat > src/auth/routes.rs << 'EOF'
use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    Json,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;

use crate::auth::{generate_token, verify_token, refresh_access_token, JwtError};
use crate::models::user::User;

#[derive(Deserialize)]
pub struct LoginRequest {
    email: String,
    password: String,
}

#[derive(Deserialize)]
pub struct RegisterRequest {
    email: String,
    password: String,
}

#[derive(Deserialize)]
pub struct RefreshRequest {
    refresh_token: String,
}

#[derive(Serialize)]
pub struct TokenResponse {
    access_token: String,
    refresh_token: String,
    token_type: String,
    expires_in: i64,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

fn token_error_to_status(err: JwtError) -> StatusCode {
    match err {
        JwtError::Expired => StatusCode::UNAUTHORIZED,
        JwtError::InvalidSignature | JwtError::InvalidFormat => StatusCode::UNAUTHORIZED,
        _ => StatusCode::BAD_REQUEST,
    }
}

pub async fn login_handler(
    State(pool): State<PgPool>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<TokenResponse>, (StatusCode, Json<ErrorResponse>)> {
    let user = sqlx::query_as::<_, User>(
        "SELECT id, email, password_hash, created_at FROM users WHERE email = $1"
    )
    .bind(&req.email)
    .fetch_optional(&pool)
    .await
    .map_err(|e| (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(ErrorResponse { error: "Database error".to_string() })
    ))?;
    
    let user = match user {
        Some(u) => u,
        None => {
            // 统一错误消息，不泄露用户是否存在
            return Err((
                StatusCode::UNAUTHORIZED,
                Json(ErrorResponse { error: "Invalid credentials".to_string() })
            ));
        }
    };
    
    // argon2 verify_password 是恒定时间比较
    let argon2 = argon2::Argon2::default();
    let parsed_hash = argon2::PasswordHash::new(&user.password_hash)
        .map_err(|_| (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: "Internal error".to_string() })
        ))?;
    
    let password_match = argon2.verify_password(
        req.password.as_bytes(),
        &parsed_hash
    ).is_ok();
    
    if !password_match {
        return Err((
            StatusCode::UNAUTHORIZED,
            Json(ErrorResponse { error: "Invalid credentials".to_string() })
        ));
    }
    
    let access = generate_token(&user.id, "access")
        .map_err(|e| (token_error_to_status(e), Json(ErrorResponse { error: "Token error".to_string() })))?;
    let refresh = generate_token(&user.id, "refresh")
        .map_err(|e| (token_error_to_status(e), Json(ErrorResponse { error: "Token error".to_string() })))?;
    
    Ok(Json(TokenResponse {
        access_token: access,
        refresh_token: refresh,
        token_type: "Bearer".to_string(),
        expires_in: 15 * 60,
    }))
}

pub async fn register_handler(
    State(pool): State<PgPool>,
    Json(req): Json<RegisterRequest>,
) -> Result<StatusCode, (StatusCode, Json<ErrorResponse>)> {
    // 检查邮箱是否已存在
    let existing = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM users WHERE email = $1")
        .bind(&req.email)
        .fetch_one(&pool)
        .await
        .map_err(|e| (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: format!("Database error: {}", e) })
        ))?;
    
    if existing > 0 {
        return Err((
            StatusCode::CONFLICT,
            Json(ErrorResponse { error: "Email already registered".to_string() })
        ));
    }
    
    // argon2 hash 密码
    let argon2 = argon2::Argon2::default();
    let salt = argon2::password_hash::SaltString::generate(&mut argon2::password_hash::rand_core::OsRng);
    let password_hash = argon2.hash_password(req.password.as_bytes(), &salt)
        .map_err(|_| (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: "Password hashing failed".to_string() })
        ))?
        .to_string();
    
    let user_id = uuid::Uuid::new_v4().to_string();
    
    sqlx::query("INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3)")
        .bind(&user_id)
        .bind(&req.email)
        .bind(&password_hash)
        .execute(&pool)
        .await
        .map_err(|e| (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: format!("Database error: {}", e) })
        ))?;
    
    Ok(StatusCode::CREATED)
}

pub async fn refresh_handler(
    Json(req): Json<RefreshRequest>,
) -> Result<Json<TokenResponse>, (StatusCode, Json<ErrorResponse>)> {
    let access = refresh_access_token(&req.refresh_token)
        .map_err(|e| (token_error_to_status(e), Json(ErrorResponse { error: "Invalid refresh token".to_string() })))?;
    
    let refresh = generate_token("unknown", "refresh")
        .map_err(|e| (token_error_to_status(e), Json(ErrorResponse { error: "Token error".to_string() })))?;
    
    Ok(Json(TokenResponse {
        access_token: access,
        refresh_token: refresh,
        token_type: "Bearer".to_string(),
        expires_in: 15 * 60,
    }))
}

pub async fn logout_handler(
    headers: HeaderMap,
) -> StatusCode {
    let _auth = headers.get("authorization");
    // TODO: 将 token jti 加入黑名单
    // 当前简化实现：仅返回 204
    StatusCode::NO_CONTENT
}
EOF
```

**【Implementer 内心OS】**

> "等等，refresh_handler 有一个 bug！
> 我调用了 `generate_token("unknown", "refresh")` 来生成新的 refresh token。
> 但 generate_token 需要 user_id，而 refresh_access_token 只返回 access token，不返回 user_id。
> 我需要从 refresh token 中解析出 user_id，然后生成新的 refresh token。
>
> 但 verify_token 返回 TokenClaims，里面有 sub（user_id）。
> 让我修改 refresh_handler：先用 verify_token 解析 refresh token 获取 user_id，
> 然后生成新的 access 和 refresh token。
>
> 实际上，标准的 JWT refresh 流程通常只返回新的 access token，不返回新的 refresh token。
> 但需求说'refresh token 有效期 7 天'，如果用户每天都刷新，旧的 refresh token 一直有效，
> 那安全性有问题（被盗的 refresh token 7 天内都可用）。
>
> 更安全的做法是：refresh 时同时返回新的 access + refresh token，并作废旧的 refresh token。
> 但这需要 token 黑名单/旋转机制，比较复杂。
>
> 这是一个架构决策！根据 R9，我不应该自行决定，应该 kanban_block。"

**【Implementer 面临决策】**

> "让我评估一下：
> - 选项 A：只返回新的 access token（标准做法，但旧 refresh token 仍有效 7 天）
> - 选项 B：返回新的 access + refresh token（更安全，但需要 token 旋转机制）
> - 选项 C：返回新的 access token，同时缩短 refresh token 有效期
>
> 这是一个涉及安全策略的决策。用户（Jacky）在需求中只说了'refresh token 有效期 7 天'，
> 没有说是否旋转。我应该 block 并询问。"

**【Implementer 执行 block】**

```python
kanban_block(
    task_id="t2_alpha_001",
    reason="architecture-decision: Refresh token rotation policy\n\n"
           "问题：/refresh 接口应该只返回新的 access token，还是同时返回新的 refresh token？\n\n"
           "背景：\n"
           "- 如果只返回 access token，被盗的 refresh token 在 7 天内都有效\n"
           "- 如果同时返回新的 refresh token（旋转），旧 refresh token 应立即作废，安全性更高\n"
           "- 旋转机制需要 token 黑名单存储（Redis/DB），增加复杂度\n\n"
           "建议选项：\n"
           "A) 仅返回 access token（简单，安全性较低）\n"
           "B) 返回 access + refresh，并实现 token 旋转（推荐，安全性高）\n"
           "C) 仅返回 access token，但将 refresh token 有效期缩短到每次使用后的 N 小时（折中）"
)
```

**【系统提示】**

```
[hermes] Task t2_alpha_001 blocked by implementer
[hermes] Reason: architecture-decision: Refresh token rotation policy
[hermes] Blocked tasks: [t2_alpha_001]
[hermes] Downstream blocked: [t3_alpha_001] (depends on T2)
```

**【系统向 Jacky 推送】**

```
⚠️ Project Alpha — 任务阻塞，需要决策

T2: 实现 /login /register /refresh /logout 接口
状态: blocked — 等待用户决策

问题: Refresh token 旋转策略
Implementer 在实现 /refresh 接口时遇到架构决策：

当前方案（A）: 只返回新 access token
  ✅ 实现简单
  ❌ 被盗 refresh token 7 天内有效

建议方案（B）: 返回新 access + refresh，旋转旧 token
  ✅ 安全性高，旧 token 立即作废
  ❌ 需要 Redis/DB 存储黑名单

折中方案（C）: 滑动过期
  ⚖️ 每次刷新后延长 7 天

[选择 A] [选择 B] [选择 C] [要求更多信息]
```

---

### Step 4.10: Jacky 收到阻塞通知并做决策

**【场景上下文】**
Jacky 正在吃午饭，手机收到 Telegram 通知。

**【Jacky 心理活动】**

> "嗯？T2 被 block 了。让我看看...
>
> Refresh token 旋转策略。这是个好问题，Implementer 考虑得很周到。
>
> 选项 A（不旋转）：最简单，但安全性确实有问题。如果用户的 refresh token 被盗，
> 攻击者可以用它 7 天内一直获取新的 access token。
>
> 选项 B（旋转）：最安全，但需要一个存储层来跟踪已作废的 token。
> 我们已经有 PostgreSQL，可以把作废的 jti 存到表里。
> 但这也意味着每次 refresh 都要查 DB，增加延迟。
>
> 选项 C（滑动过期）：每次刷新后延长 7 天。但如果用户每天都用，
> 相当于 refresh token 永不过期，更差。
>
> 我觉得选 B。虽然复杂一点，但安全性好得多。
> 而且我们可以用 PostgreSQL 的 jti_blacklist 表，不需要额外引入 Redis。
> 延迟增加一点点（一次 DB 查询），可以接受。
>
> 让我回复。"

**【Jacky 对白】**

Jacky 在 Telegram 中回复：

```
选择 B：返回新 access + refresh，旋转旧 token。

具体要求：
1. /refresh 验证旧 refresh token 后，生成新的 access + refresh token 对
2. 将旧 refresh token 的 jti 加入 jti_blacklist 表
3. jti_blacklist 表结构: jti (TEXT PK), revoked_at (TIMESTAMP)
4. verify_token 时先查 jti_blacklist，如果 jti 在表中则返回 InvalidSignature
5. 定期清理过期的黑名单记录（可以以后做，先手动清理）

安全性优先，延迟可接受。
```

**【系统提示】**

```
[hermes] User decision received for t2_alpha_001
[hermes] Decision: B (Token rotation with blacklist)
[hermes] Unblocking t2_alpha_001
[hermes] Re-spawning implementer worker
```

---

### Step 4.11: Implementer 恢复执行，实现旋转机制

**【Implementer 内心OS】**

> "Jacky 选了 B。我需要：
> 1. 创建 jti_blacklist 表
> 2. 修改 verify_token 检查黑名单
> 3. 修改 refresh_handler 旋转 token
> 4. 修改 logout_handler 将 token 加入黑名单
>
> 让我继续完成 T2。"

**【Implementer 执行的具体指令】**

```bash
# 创建数据库迁移（简化版，直接写 SQL）
cat > migrations/20260510_add_jti_blacklist.sql << 'EOF'
CREATE TABLE IF NOT EXISTS jti_blacklist (
    jti TEXT PRIMARY KEY,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_jti_blacklist_jti ON jti_blacklist(jti);
EOF

# 修改 jwt.rs：verify_token 检查黑名单
cat >> src/auth/jwt.rs << 'EOF'

use sqlx::PgPool;

pub async fn is_token_revoked(jti: &str, pool: &PgPool) -> Result<bool, JwtError> {
    let count = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM jti_blacklist WHERE jti = $1")
        .bind(jti)
        .fetch_one(pool)
        .await
        .map_err(|_| JwtError::InvalidFormat)?;
    Ok(count > 0)
}
EOF

# 修改 routes.rs：实现旋转和黑名单
# (具体代码略，Implementer 会正确实现)
```

> "代码修改完成。让我运行编译和测试。"

```bash
cargo check --lib 2>&1 | tail -20
cargo test auth --lib 2>&1
```

**【系统返回】**

```
# cargo check
    Finished dev [unoptimized + debuginfo] target(s) in 2.34s

# cargo test
 running 8 tests
 test auth::jwt::tests::test_generate_access_token ... ok
 ... (其他测试通过)

 test result: ok. 8 passed; 0 failed
```

**【Implementer 内心OS】**

> "编译通过，测试通过。T2 完成了。
> 但我没有写完整的集成测试——那是 T3 的任务。
> 让我提交 handoff。"

**【Implementer 执行完成指令】**

```python
kanban_complete(
    task_id="t2_alpha_001",
    summary="4 个 HTTP 接口已实现，包含 token 旋转机制。/refresh 验证旧 token 后生成新 token 对，旧 token jti 加入黑名单。",
    metadata={
        "changed_files": [
            "src/auth/routes.rs",
            "src/auth/middleware.rs",
            "src/main.rs",
            "migrations/20260510_add_jti_blacklist.sql"
        ],
        "tests_run": 0,  # 集成测试在 T3
        "tests_passed": 0,
        "decisions": [
            "Jacky 选择 B: Token rotation with jti_blacklist",
            "/refresh 返回新 access + refresh token",
            "旧 refresh token jti 加入 PostgreSQL 黑名单",
            "verify_token 检查 jti_blacklist 表",
            "logout 将当前 token jti 加入黑名单"
        ],
        "pitfalls": [
            "jti_blacklist 表需要定期清理（当前无自动清理）",
            "每次 verify_token 需要 DB 查询，增加延迟 ~5ms",
            "并发 refresh 可能导致竞态条件（两个请求同时用同一个 refresh token）"
        ],
        "duration_minutes": 78
    }
)
```

**【系统提示】**

```
[hermes] Task t2_alpha_001 completed by implementer
[hermes] Status: done
[hermes] Duration: 78 minutes（预计 90 分钟）
[hermes] Next promoted: [t3_alpha_001]  ← T3 测试任务变为 ready
```

---


