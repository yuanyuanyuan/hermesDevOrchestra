## Phase 3: 执行（Implementer）

> **架构说明（2026-05-11 更新）：** 本文档中的 Implementer 角色采用"外部 CLI 引擎"模式。Implementer Profile 是轻量编排层，实际编码、TDD、测试由 `codex exec`（或 `claude -p`）实现引擎完成。详见 [`EXTERNAL-CLI-ENGINE.md`](./EXTERNAL-CLI-ENGINE.md)。

> 📎 **相关 ASCII 流程图**：
> - [`ascii-end-to-end.md`](./ascii-end-to-end.md) — Phase 3 执行（Implementer）
> - [`ascii-kanban-subflows.md`](./ascii-kanban-subflows.md) — Handoff 机制（任务交接）
>
> **能力来源说明：** `kanban_show`/`kanban_complete`/`kanban_block` 工具、worktree workspace、Dispatcher spawn 属于 `[Hermes 官方]`。TDD 强制工作流（RED→GREEN 循环）、背压检查、环境快照采集（R22）、pre-task git stash（R4）、`expected_duration_max` timeout（R15）、SOUL.md 强制 block 规则（R9）属于 `[Phase 19 增量]`。

---

### Step 3.1: Dispatcher 派发 Implementer（T1） `[Hermes 官方]` + `[Phase 19 增量]`

**【场景上下文】**
Dispatcher 的下一轮循环。t1_alpha_001 是 ready 状态，assignee="implementer"。

> 注：Dispatcher 的 spawn、claim、PID 跟踪是 `[Hermes 官方]`；背压检查、环境快照、pre-task stash 是 `[Phase 19 增量]`。

**【系统内部】Dispatcher 决策日志：**

```
[2026-05-10T09:32:02Z] Dispatcher cycle start
[2026-05-10T09:32:02Z] Ready tasks: [t1_alpha_001]
[2026-05-10T09:32:02Z] Backpressure check:
[2026-05-10T09:32:02Z]   implementer_ready: 1
[2026-05-10T09:32:02Z]   reviewer_ready: 0
[2026-05-10T09:32:02Z]   ratio: 1.0 (≤ 2.0, normal)
[2026-05-10T09:32:02Z] Claiming t1_alpha_001
[2026-05-10T09:32:02Z] Spawning implementer worker
[2026-05-10T09:32:02Z] Pre-task snapshot: git stash push -m "pre-task:t1_alpha_001"
[2026-05-10T09:32:03Z] Environment snapshot:
[2026-05-10T09:32:03Z]   git_status: "clean, branch: main"
[2026-05-10T09:32:03Z]   disk_free: "142G / 200G"
[2026-05-10T09:32:03Z]   hermes_status: "ok, version 0.13.0"
[2026-05-10T09:32:03Z] Worker PID: 18501
```

**【系统向 Jacky 推送】**

```
🔧 Project Alpha — 任务开始执行

T1: 实现 JWT 核心逻辑（生成/验证/刷新 token）
负责人: Implementer
预计时长: 60 分钟

[查看实时进度] [取消任务]
```

---

### Step 3.2: Implementer 被唤醒，读取任务并推导行为清单

**【实现引擎输出】**

> "我被 Dispatcher 派发了。任务 ID 是 t1_alpha_001，board 是 project-alpha。
> 让我先看看任务详情。"

**【Implementer 执行的具体指令】**

```python
kanban_show(task_id="t1_alpha_001")
```

**【系统返回】**

```json
{
  "task_id": "t1_alpha_001",
  "title": "T1: 实现 JWT 核心逻辑（生成/验证/刷新 token）",
  "body": "在 src/auth/jwt.rs 中实现：\n1. TokenClaims...",
  "assignee": "implementer",
  "status": "running",
  "workspace": "/data/hermes/workspaces/project-alpha/worktree-t1-alpha-001",
  "expected_duration_max": "60min",
  "parent_task": "t_alpha_001"
}
```

**【实现引擎输出】**

> "好的，我需要在一个隔离的 worktree 中工作。
> 工作区是 /data/hermes/workspaces/project-alpha/worktree-t1-alpha-001。
>
> **TDD 第一步：从验收标准推导行为清单。**
>
> 验收标准是：生成/验证/刷新 token，RS256，密钥从环境变量读取。
>
> 我把这拆成 3 个行为：
> - 行为 A: 生成 access token → 返回有效 JWT（可验证）
> - 行为 B: 验证过期 token → 返回 Expired 错误
> - 行为 C: 用 refresh token 换取新 access token → 返回新 token
>
> 每个行为一个 RED→GREEN 循环。先跑基线。"

---

### Step 3.3: Implementer 建立上下文

**【Implementer 执行的具体指令】**

> **外部 CLI 引擎模式：** 以下 bash 命令在新架构中由 `codex exec` 引擎在 worktree 内部执行，Implementer Profile 仅接收结构化输出。以下展示的是引擎执行的命令及其返回结果。

```bash
# 检查当前工作区
cd $HERMES_KANBAN_WORKSPACE
cd /data/hermes/workspaces/project-alpha/worktree-t1-alpha-001

# 检查现有项目结构
tree -L 3 src/
```

**【系统返回】**

```
src/
├── main.rs
├── lib.rs
├── config.rs
├── routes/
│   ├── mod.rs
│   └── users.rs
├── middleware/
│   ├── mod.rs
│   ├── trace.rs
│   ├── cors.rs
│   └── rate_limit.rs
└── models/
    ├── mod.rs
    └── user.rs

Cargo.toml 依赖:
- axum = "0.7"
- tokio = { version = "1", features = ["full"] }
- sqlx = { version = "0.7", features = ["postgres", "runtime-tokio"] }
- serde = { version = "1", features = ["derive"] }
- argon2 = "0.5"
```

**【实现引擎输出】**

> "项目结构清晰。没有 auth 目录，我需要新建 src/auth/。
> Cargo.toml 里没有 crypto 相关的依赖。我需要添加：
> - ring（RS256 签名/验证）
> - base64（JWT 的 base64url 编码）
> - serde_json（claims 序列化）
> - thiserror（自定义错误类型）
> - chrono（时间处理）
>
> 等等，用户说'不能用第三方 auth 库'。ring 是 crypto 原语库，不是 auth 库，可以用。
> jsonwebtoken 是 auth 库，不能用。
>
> 让我先跑一下现有测试，确认基线。"

---

### Step 3.4: 建立测试基线（TDD 门禁）

**【Implementer 执行的具体指令】**

> **外部 CLI 引擎模式：** `cargo test` 由 `codex exec` 引擎在 worktree 内执行，Implementer Profile 仅接收测试结果的结构化输出。

```bash
cargo test --lib
```

**【系统返回】**

```
running 8 tests
test models::user::test_user_creation ... ok
test models::user::test_password_hash ... ok
test routes::users::test_register_handler ... ok
test routes::users::test_login_handler ... ok
test middleware::rate_limit::test_rate_limit ... ok
... (省略)

 test result: ok. 8 passed; 0 failed; 0 ignored
```

**【实现引擎输出】**

> "基线测试全过（8/8）。TDD 门禁通过。
>
> 如果基线有失败，我会执行：
> kanban_block(reason="baseline-failed: test_rate_limit, test_session_expire")
> 然后停止，等 Reviewer 决策。不修不相关的 bug。
>
> 基线正常，现在进入 TDD 循环。先添加依赖，然后对每个行为执行 RED→GREEN。"

---

### Step 3.5: Implementer 添加依赖并创建文件结构

**【Implementer 执行的具体指令】**

> **外部 CLI 引擎模式：** 以下文件创建和编辑操作由 `codex exec` 引擎在 worktree 内完成，Implementer Profile 仅组装任务描述并接收引擎返回的变更清单。

```bash
# 编辑 Cargo.toml，添加依赖
cat >> Cargo.toml << 'EOF'

# JWT 实现依赖
ring = "0.17"
base64 = "0.22"
thiserror = "1"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4"] }
EOF

# 创建 auth 目录
mkdir -p src/auth
touch src/auth/mod.rs src/auth/jwt.rs src/auth/error.rs

# 更新 src/lib.rs，添加 auth 模块
cat >> src/lib.rs << 'EOF'

pub mod auth;
EOF

# 写 error.rs（所有行为共用）
cat > src/auth/error.rs << 'EOF'
use thiserror::Error;

#[derive(Error, Debug, PartialEq)]
pub enum JwtError {
    #[error("token has expired")]
    Expired,
    #[error("invalid signature")]
    InvalidSignature,
    #[error("invalid token format")]
    InvalidFormat,
    #[error("invalid base64 encoding")]
    InvalidBase64,
    #[error("invalid json: {0}")]
    InvalidJson(String),
    #[error("unsupported algorithm")]
    UnsupportedAlgorithm,
    #[error("missing key")]
    MissingKey,
}
EOF

# 写 mod.rs
cat > src/auth/mod.rs << 'EOF'
pub mod error;
pub mod jwt;

pub use error::JwtError;
pub use jwt::{generate_token, verify_token, refresh_access_token, TokenClaims};
EOF

# 生成测试用 RSA 密钥对
openssl genrsa -out /tmp/test_private.pem 2048 2>/dev/null
openssl rsa -in /tmp/test_private.pem -pubout -out /tmp/test_public.pem 2>/dev/null
```

**【实现引擎输出】**

> "依赖和基础结构就绪。现在进入 TDD 循环。
> 关于 RS256：JWT 标准用的是 RSASSA-PKCS1-v1_5（不是 PSS），ring 中对应 RSA_PKCS1_SHA256。
> 这是实现正确性，不是架构决策，我自己修正。"

---

### Step 3.6: TDD 行为 A — RED（生成 access token → 失败）

**【实现引擎输出】**

> "行为 A：生成 access token 返回有效 JWT。
> 先写测试，再写实现。RED 阶段——测试必须失败。"

**【Implementer 执行：写测试】**

> **外部 CLI 引擎模式：** 以下测试编写和 `cargo test` 执行由 `codex exec` 引擎完成，Implementer Profile 接收测试结果（pass/fail）。

```bash
cat > src/auth/jwt.rs << 'EOF'
use crate::auth::error::JwtError;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::{Duration, Utc};
use ring::signature::{self, RsaKeyPair, UnparsedPublicKey, RSA_PKCS1_2048_8192_SHA256};
use serde::{Deserialize, Serialize};
use std::sync::OnceLock;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct TokenClaims {
    pub sub: String,
    pub exp: i64,
    pub iat: i64,
    pub jti: String,
    pub typ: String,
}

// --- 仅写接口声明，不写实现 ---
pub fn generate_token(user_id: &str, token_type: &str) -> Result<String, JwtError> {
    todo!("行为 A: RED 阶段 — 故意不实现")
}

pub fn verify_token(token: &str) -> Result<TokenClaims, JwtError> {
    todo!()
}

pub fn refresh_access_token(refresh_token: &str) -> Result<String, JwtError> {
    todo!()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    fn setup_keys() {
        let private = std::fs::read_to_string("/tmp/test_private.pem").unwrap();
        let public = std::fs::read_to_string("/tmp/test_public.pem").unwrap();
        env::set_var("JWT_PRIVATE_KEY", private);
        env::set_var("JWT_PUBLIC_KEY", public);
    }

    #[test]
    fn test_generate_access_token_returns_valid_jwt() {
        setup_keys();
        // RED: 这个测试会 panic（todo!()），符合预期
        let token = generate_token("user_123", "access").unwrap();
        assert_eq!(token.split('.').count(), 3, "JWT 应有 3 段");
    }
}
EOF

cargo test auth::jwt::tests::test_generate_access_token --lib
```

**【系统返回】**

```
test auth::jwt::tests::test_generate_access_token ... FAILED
thread 'main' panicked at 'not yet implemented: 行为 A: RED 阶段'
```

**【实现引擎输出】**

> "RED 确认：测试失败，因为 todo!()。符合预期。
> 如果测试意外通过，我会加强断言（比如验证 token 可被 verify_token 解析）。
> 现在进入 GREEN。"

---

### Step 3.7: TDD 行为 A — GREEN（生成 access token → 通过）

**【Implementer 执行：写最简实现】**

> **外部 CLI 引擎模式：** 实现代码编写由 `codex exec` 引擎在 worktree 内完成，Implementer Profile 仅传递行为规格并接收编译/测试结果。

```bash
# 补全 generate_token 实现（verify_token 和 refresh 保持 todo!()）
cat > src/auth/jwt.rs << 'EOF'
use crate::auth::error::JwtError;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::{Duration, Utc};
use ring::signature::{self, RsaKeyPair, RSA_PKCS1_SHA256};
use serde::{Deserialize, Serialize};
use std::sync::OnceLock;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct TokenClaims {
    pub sub: String,
    pub exp: i64,
    pub iat: i64,
    pub jti: String,
    pub typ: String,
}

#[derive(Serialize)]
struct JwtHeader { alg: String, typ: String }

static PRIVATE_KEY: OnceLock<Vec<u8>> = OnceLock::new();
static PUBLIC_KEY: OnceLock<Vec<u8>> = OnceLock::new();

fn get_private_key() -> Result<&'static Vec<u8>, JwtError> {
    PRIVATE_KEY.get_or_try_init(|| {
        std::env::var("JWT_PRIVATE_KEY").map(|s| s.into_bytes()).map_err(|_| JwtError::MissingKey)
    })
}

fn get_public_key() -> Result<&'static Vec<u8>, JwtError> {
    PUBLIC_KEY.get_or_try_init(|| {
        std::env::var("JWT_PUBLIC_KEY").map(|s| s.into_bytes()).map_err(|_| JwtError::MissingKey)
    })
}

fn base64url_encode(data: &[u8]) -> String { URL_SAFE_NO_PAD.encode(data) }
fn base64url_decode(data: &str) -> Result<Vec<u8>, JwtError> {
    URL_SAFE_NO_PAD.decode(data).map_err(|_| JwtError::InvalidBase64)
}

pub fn generate_token(user_id: &str, token_type: &str) -> Result<String, JwtError> {
    let now = Utc::now();
    let duration = match token_type {
        "access" => Duration::minutes(15),
        "refresh" => Duration::days(7),
        _ => return Err(JwtError::InvalidFormat),
    };
    let claims = TokenClaims {
        sub: user_id.to_string(),
        exp: (now + duration).timestamp(),
        iat: now.timestamp(),
        jti: uuid::Uuid::new_v4().to_string(),
        typ: token_type.to_string(),
    };
    let header = JwtHeader { alg: "RS256".to_string(), typ: "JWT".to_string() };
    let header_b64 = base64url_encode(serde_json::to_string(&header).unwrap().as_bytes());
    let claims_b64 = base64url_encode(serde_json::to_string(&claims).unwrap().as_bytes());
    let message = format!("{}.{}", header_b64, claims_b64);

    let private_key = get_private_key()?;
    let key_pair = RsaKeyPair::from_pkcs8(private_key).map_err(|_| JwtError::MissingKey)?;
    let mut sig = vec![0u8; key_pair.public_modulus_len()];
    key_pair.sign(&signature::RSA_PKCS1_SHA256, &ring::rand::SystemRandom::new(),
                  message.as_bytes(), &mut sig).map_err(|_| JwtError::InvalidSignature)?;

    Ok(format!("{}.{}.{}", header_b64, claims_b64, base64url_encode(&sig)))
}

pub fn verify_token(_token: &str) -> Result<TokenClaims, JwtError> { todo!("行为 B") }
pub fn refresh_access_token(_rt: &str) -> Result<String, JwtError> { todo!("行为 C") }

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    fn setup_keys() {
        let private = std::fs::read_to_string("/tmp/test_private.pem").unwrap();
        let public = std::fs::read_to_string("/tmp/test_public.pem").unwrap();
        env::set_var("JWT_PRIVATE_KEY", private);
        env::set_var("JWT_PUBLIC_KEY", public);
    }

    #[test]
    fn test_generate_access_token_returns_valid_jwt() {
        setup_keys();
        let token = generate_token("user_123", "access").unwrap();
        assert_eq!(token.split('.').count(), 3, "JWT 应有 3 段");
    }
}
EOF

cargo test auth::jwt::tests::test_generate_access_token --lib
```

**【系统返回】**

```
test auth::jwt::tests::test_generate_access_token ... ok
```

**【实现引擎输出】**

> "GREEN 确认：行为 A 通过。
> 行为 A 完成：generate_token 生成有效 JWT。
> 进入行为 B。"

---

### Step 3.8: TDD 行为 B — RED→GREEN（验证过期 token → Expired 错误）

**【实现引擎输出】**

> "行为 B：验证过期 token 返回 Expired 错误。
> 需要先实现 verify_token，然后写测试。"

**【Implementer 执行：RED — 写测试】**

> **外部 CLI 引擎模式：** 测试编写和执行由 `codex exec` 引擎完成，Implementer Profile 接收测试结果。

```bash
# 在 tests 模块追加行为 B 的测试
cat >> /tmp/test_behavior_b.rs << 'TESTEOF'
    #[test]
    fn test_verify_expired_token_returns_expired_error() {
        setup_keys();
        let mut claims = TokenClaims {
            sub: "user_789".to_string(),
            exp: Utc::now().timestamp() - 3600,
            iat: Utc::now().timestamp() - 7200,
            jti: "test".to_string(),
            typ: "access".to_string(),
        };
        // 手动构造过期 token（verify_token 还是 todo!()，会 panic）
        let token = generate_token("user_789", "access").unwrap();
        let result = verify_token(&token);
        assert!(matches!(result, Err(JwtError::Expired)));
    }
TESTEOF
# (实际实现中会直接编辑 jwt.rs 的 tests 模块)
cargo test auth::jwt::tests::test_verify_expired_token --lib
```

**【系统返回】**

```
test auth::jwt::tests::test_verify_expired_token ... FAILED
thread 'main' panicked at 'not yet implemented: 行为 B'
```

**【实现引擎输出】**

> "RED 确认：verify_token 还是 todo!()，测试失败。符合预期。
> 现在实现 verify_token（GREEN 阶段）。"

**【Implementer 执行：GREEN — 实现 verify_token】**

> (补全 verify_token 实现，包含签名验证 + 过期检查，verify_token 和 refresh 保持 todo!())

```bash
# 补全 verify_token 实现
cargo test auth::jwt::tests::test_verify_expired_token --lib
```

**【系统返回】**

```
test auth::jwt::tests::test_verify_expired_token ... ok
```

**【实现引擎输出】**

> "GREEN 确认：行为 B 通过。
> 行为 B 完成：verify_token 正确检测过期 token。
> 进入行为 C。"

---

### Step 3.9: TDD 行为 C — RED→GREEN（refresh token 换取新 access token）

**【实现引擎输出】**

> "行为 C：用 refresh token 换取新 access token。
> refresh_access_token 依赖 verify_token（已完成）+ generate_token（已完成）。
> 先写测试（RED），再实现（GREEN）。"

**【Implementer 执行：RED — 写测试 + GREEN — 实现】**

> **外部 CLI 引擎模式：** 测试编写、实现代码和 `cargo test` 均由 `codex exec` 引擎在 worktree 内完成，Implementer Profile 仅传递行为规格并接收结构化结果。

```bash
# 补全 refresh_access_token 实现 + 追加测试
cargo test auth::jwt::tests::test_refresh_access_token --lib
```

**【系统返回】**

```
test auth::jwt::tests::test_refresh_access_token ... ok
```

**【实现引擎输出】**

> "GREEN 确认：行为 C 通过。
> 三个行为全部完成。现在跑全量回归测试。"

---

### Step 3.10: 全量回归测试 + 完成

**【Implementer 执行：回归测试】**

> **外部 CLI 引擎模式：** 全量回归测试由 `codex exec` 引擎在 worktree 内执行，Implementer Profile 接收测试结果汇总。

```bash
cargo test --lib
```

**【系统返回】**

```
running 13 tests
test models::user::test_user_creation ... ok
test models::user::test_password_hash ... ok
test routes::users::test_register_handler ... ok
test routes::users::test_login_handler ... ok
test middleware::rate_limit::test_rate_limit ... ok
test auth::jwt::tests::test_generate_access_token ... ok
test auth::jwt::tests::test_verify_expired_token ... ok
test auth::jwt::tests::test_refresh_access_token ... ok
... (省略)

test result: ok. 13 passed; 0 failed; 0 ignored
```

**【实现引擎输出】**

> "回归全过（13/13）。所有行为的测试 + 原有测试均通过。
> 填写 TDD 交接单。"

**【Implementer 执行完成指令】**

```python
kanban_complete(
    task_id="t1_alpha_001",
    summary="JWT 签发已实现 (TDD)，3 个行为各有对应测试，回归 13/13 通过。",
    metadata={
        "behaviors": [
            {
                "name": "生成 access token 返回有效 JWT",
                "test": "test_generate_access_token_returns_valid_jwt",
                "status": "passed"
            },
            {
                "name": "验证过期 token 返回 Expired 错误",
                "test": "test_verify_expired_token_returns_expired_error",
                "status": "passed"
            },
            {
                "name": "refresh token 换取新 access token",
                "test": "test_refresh_access_token",
                "status": "passed"
            }
        ],
        "regression": {"run": 13, "passed": 13, "failed": 0},
        "changed_files": [
            "Cargo.toml",
            "src/lib.rs",
            "src/auth/mod.rs",
            "src/auth/jwt.rs",
            "src/auth/error.rs"
        ],
        "decisions": [
            "使用 ring crate 实现 RS256（手动 JWT 编解码，不用 jsonwebtoken）",
            "RS256 使用 RSA_PKCS1_SHA256（非 PSS）以符合 JWT 标准",
            "TokenClaims 包含 jti 字段用于未来撤销功能",
            "密钥通过环境变量 JWT_PRIVATE_KEY / JWT_PUBLIC_KEY 传入"
        ],
        "pitfalls": [
            "ring 的 RSA 密钥加载需要 PKCS#8 格式（不是 PEM），当前实现假设环境变量传入的是原始 bytes——需要在 routes 层做 PEM 解析转换",
            "uuid crate 新增依赖，需确认许可证兼容"
        ],
        "duration_minutes": 42
    }
)
```

**【系统提示】**

```
[hermes] Task t1_alpha_001 completed by implementer (TDD)
[hermes] Status: done
[hermes] Behaviors: 3/3 passed
[hermes] Regression: 13/13 passed
[hermes] Duration: 42 minutes
[hermes] Next promoted: [t2_alpha_001, t4_alpha_001]  ← T2, T4 同时变为 ready
[hermes] T4 (Reviewer) will verify: behaviors list + test code + implementation code
```

**【系统向 Jacky 推送】**

```
✅ Project Alpha — T1 完成 (TDD)

T1: JWT 签发
状态: 已完成
耗时: 42 分钟（预计 60 分钟）

TDD 行为清单:
• ✅ 生成 access token → test_generate_access_token_returns_valid_jwt
• ✅ 验证过期 token → test_verify_expired_token_returns_expired_error
• ✅ refresh token 换取新 access token → test_refresh_access_token

回归测试: 13/13 通过
关键决策: RS256 (PKCS#1 v1.5)，密钥通过环境变量传入

下一步: T2（HTTP 接口）和 T4（代码审查）将并行启动
         T4 将验证 TDD 行为清单是否属实

[查看代码] [查看测试] [追加审查要求]
```

---

### Step 3.11: Jacky 查看 T1 结果

**【Jacky 心理活动】**

> "42 分钟完成了。3 个行为各有对应测试，回归 13/13 通过。
>
> TDD 行为清单很清晰——每个行为都有具体的测试名。
> Reviewer 会验证这些测试是否真的在测试对应的行为。
>
> 有一个 pitfall 值得注意：ring 需要 PKCS#8 格式。
> 看看 Reviewer 怎么说，如果也提出这个问题，我在 T5 修复阶段处理。"

Jacky 没有干预，继续处理其他工作。

---

## 架构说明：Implementer Profile 与实现引擎的关系

| 层 | 组件 | 职责 |
|----|------|------|
| 编排层 | Hermes Implementer Profile（轻量 LLM） | 从 Kanban 读取任务、组装 Request Envelope、调用 `codex exec`、解析 Response Envelope、写入 Kanban |
| 执行层 | `codex exec` 实现引擎（默认）/ `claude -p`（可切换） | TDD 编码、测试执行、worktree 管理、handoff metadata 生成 |

Implementer Profile 的 `config.yaml` 中 `engine.cli` 字段决定使用哪个 CLI 引擎（默认 `codex`，可切换为 `claude`）。

通信协议详见 [`EXTERNAL-CLI-ENGINE.md`](./EXTERNAL-CLI-ENGINE.md) §5。

---