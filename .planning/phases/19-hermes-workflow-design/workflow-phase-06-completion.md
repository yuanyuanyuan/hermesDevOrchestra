## Phase 6: 完成通知 + 用户审核决策

> 📎 **相关 ASCII 流程图**：[`ascii-end-to-end.md`](./ascii-end-to-end.md) — Phase 6 完成通知

---

### Step 6.1: Project Alpha 全部任务完成

**【场景上下文】**
回到 Project Alpha。T6 被 block 了（staging 环境缺失），但 Jacky 已经做了决策"先本地验证，再想办法部署"。实际上，T6 的 block 并不意味着项目失败——代码已经完成并通过测试，只是部署环境需要配置。

系统将所有 done 的任务汇总，向 Jacky 推送完成通知。

**【系统向 Jacky 推送】**

```
📬 Project Alpha — 用户认证模块 开发完成

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
任务完成汇总
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ T1: JWT 核心逻辑 (42min)
   测试: 5/5 通过
   关键: RS256 实现、token 生成/验证/刷新

✅ T2: HTTP 接口 (78min + block 决策)
   4 个接口: /login /register /refresh /logout
   架构决策: Jacky 选择 token 旋转策略 (B)
   
✅ T3: 测试 (55min)
   单元测试: 8/8 通过
   集成测试: 3/3 通过 (本地 DB)
   覆盖率: ~65% (单元) + 集成待 CI

✅ T4: 代码审查 (30min)
   审查员: Tech-Reviewer
   结果: 通过 (附 8 个修复要求，已全部修复)
   安全评分: B+ | 代码质量: B

✅ T5: 修复 + 自我进化 (35min)
   修复: 8/8 审查问题
   经验沉淀: 2 条 memory + 1 个 skill

⚠️ T6: 部署准备 (blocked)
   原因: staging/生产环境缺失
   状态: 等待用户配置部署环境

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
代码变更
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

新增文件:
  src/auth/mod.rs
  src/auth/jwt.rs
  src/auth/error.rs
  src/auth/routes.rs
  src/auth/middleware.rs
  tests/auth_integration.rs
  migrations/20260510_add_jti_blacklist.sql

修改文件:
  Cargo.toml (新增依赖)
  src/lib.rs (添加 auth 模块)
  src/main.rs (注册路由和中间件)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
经验沉淀
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧠 Memory (项目级):
  • Rust JWT 实现要点 (RS256、ring、安全实践)

🧠 Memory (全局，待审核):
  • Refresh token 策略对比 (旋转 vs 不旋转)

🛠️ Skill (全局):
  • jwt-auth-rust: Rust + Axum JWT 认证完整流程

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
技术债务
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ jti_blacklist 表无自动清理
⚠️ 集成测试需要真实 PostgreSQL
⚠️ OnceLock 并发测试问题 (cargo test --test-threads=1)
⚠️ 覆盖率可能未达 80% 目标
⚠️ 生产部署环境未配置

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[查看代码] [查看测试报告] [查看审查详情]
[归档项目] [创建部署任务] [追加需求]
```

---

### Step 6.2: Jacky 审核并做决策

**【Jacky 心理活动】**

> "Project Alpha 的 JWT 模块开发完成了。让我看看结果...
>
> **代码层面：**
> - 核心逻辑实现了，测试通过了。RS256 用对了（PKCS#1 v1.5 不是 PSS）。
> - 4 个 HTTP 接口都实现了，token 旋转策略也按我的要求做了。
> - 审查发现了 8 个问题，全部修复了。安全评分 B+，不错。
>
> **测试层面：**
> - 单元测试 8/8 通过，集成测试 3/3 通过。
> - 但覆盖率只有 65%，没达到我要求的 80%。
> - 而且集成测试需要真实 PostgreSQL，CI 中还没配置。
>
> **经验沉淀：**
> - 2 条 memory + 1 个 skill。skill 是"jwt-auth-rust"，以后新项目可以直接用。
> - 全局 memory 关于 refresh token 策略还在 curator 审核中。
>
> **技术债务：**
> - jti_blacklist 没有自动清理——这可能导致表无限增长。
> - 覆盖率未达标——我需要让 Implementer 补充更多边界测试。
> - 部署环境缺失——这是基础设施问题，我需要自己解决。
>
> **我的决策：**
> 1. 代码可以合并到主分支
> 2. 但需要补充测试覆盖率到 80%
> 3. jti_blacklist 清理需要加一个 cron 任务
> 4. 部署环境我下周配置
>
> 让我通过系统下达指令。"

**【Jacky 对白】**

Jacky 打开终端：

```bash
# 查看详细代码
cd /data/hermes/workspaces/project-alpha/worktree-t5-alpha-001
git diff --stat main

# 查看测试报告
cargo test --lib 2>&1 | tail -20

# 查看覆盖率（如果已安装 tarpaulin）
which cargo-tarpaulin && cargo tarpaulin --lib --out stdout 2>&1 | grep -E "Coverage|Total"
```

**【系统返回】**

```
# git diff --stat
 Cargo.toml                      |  6 ++++++
 src/lib.rs                      |  2 ++
 src/auth/mod.rs                 |  5 +++++
 src/auth/jwt.rs                 | 234 ++++++++++++++++++++++++++++++++++
 src/auth/error.rs               |  23 ++++
 src/auth/routes.rs              | 198 +++++++++++++++++++++++++++++++++
 src/auth/middleware.rs          |  67 +++++++++++
 src/main.rs                     |  8 +++-
 tests/auth_integration.rs       | 145 +++++++++++++++++++++++++++++++++
 migrations/20260510_add_jti... |  12 ++++
 10 files changed, 700 insertions(+), 1 deletion(-)

# cargo test
 running 8 tests
 test result: ok. 8 passed; 0 failed

# tarpaulin
Coverage: 64.83%
```

**【Jacky 心理活动】**

> "700 行新增代码。覆盖率 64.83%，离 80% 还有差距。
> 让我看看哪些代码没覆盖到..."

```bash
cargo tarpaulin --lib --out html 2>&1
cat tarpaulin-report.html | grep -o 'missed.*' | head -20
```

**【系统返回】**

```
# 未覆盖代码:
src/auth/routes.rs:87-93  (register 错误处理分支)
src/auth/routes.rs:156-162 (refresh 错误处理分支)
src/auth/jwt.rs:178-185    (MissingKey 错误路径)
src/auth/jwt.rs:210-220    (unsupported algorithm 分支)
src/auth/middleware.rs:45-60 (auth 中间件 extract 失败分支)
```

**【Jacky 心理活动】**

> "未覆盖的主要是错误处理分支。这些边界情况确实需要测试。
> 但核心功能已经覆盖了。
>
> 我决定：
> 1. 批准合并到主分支
> 2. 创建一个后续任务补充错误分支的测试
> 3. 创建 jti_blacklist 自动清理任务
>
> 让我用 Kanban 命令操作。"

**【Jacky 执行决策】**

```bash
# 批准 T6 的 block 决策——暂时归档部署任务
hermes kanban unblock t6_alpha_001 --resolution "代码已完成并通过测试。部署环境配置延后处理，创建独立基础设施任务。"

# 创建补充测试任务
hermes kanban create \
    --title "补充 JWT 模块错误分支测试（覆盖率提升至 80%）" \
    --body "当前覆盖率 64.83%，需要补充以下场景的测试：\n1. register 的数据库错误分支\n2. refresh 的无效 token 分支\n3. jwt.rs 的 MissingKey 路径\n4. unsupported algorithm 分支\n5. auth 中间件 extract 失败分支" \
    --assignee implementer \
    --parents t5_alpha_001 \
    --board project-alpha

# 创建 jti_blacklist 清理任务
hermes kanban create \
    --title "实现 jti_blacklist 自动清理机制" \
    --body "当前 jti_blacklist 表只增不减。需要：\n1. 添加 expired_at 字段\n2. 创建 cron 任务每天清理过期记录\n3. 或者使用 PostgreSQL 分区表自动清理" \
    --assignee implementer \
    --parents t5_alpha_001 \
    --board project-alpha

# 归档主任务
hermes kanban archive t_alpha_001
```

**【系统提示】**

```
[hermes] Task t6_alpha_001 unblocked
[hermes] Task t_alpha_001 archived
[hermes] Created: t_alpha_007 (补充测试)
[hermes] Created: t_alpha_008 (jti_blacklist 清理)
[hermes] Project Alpha JWT module: DONE (with follow-ups)
```

**【系统向 Jacky 推送】**

```
✅ Project Alpha — JWT 认证模块 已归档

主任务 t_alpha_001 已归档

后续任务已创建:
• t_alpha_007: 补充错误分支测试 (implementer)
• t_alpha_008: jti_blacklist 自动清理 (implementer)

技术债务跟踪:
✅ 代码审查问题 (8/8 修复)
⚠️  覆盖率 64.83% → 目标 80% (t_alpha_007)
⚠️  jti_blacklist 无清理 (t_alpha_008)
⚠️  生产部署环境未配置 (延后)

经验沉淀:
🧠 2 条 memory + 1 个 skill

[查看代码变更] [查看后续任务]
```

---

### Step 6.3: Jacky 的最终反思

**【Jacky 心理活动】**

> "整个流程走完了。让我复盘一下：
>
> **效率方面：**
> - 从需求提交到代码完成：约 3.5 小时（9:30 ~ 13:00）
> - 我实际投入的时间：约 15 分钟（写需求 + 2 次决策）
> - AI 团队处理了：任务拆解、编码、测试、审查、修复、经验沉淀
> - 这个效率比我一个人干快多了
>
> **质量方面：**
> - 代码经过审查，发现了 8 个问题（包括测试路径硬编码、格式问题等）
> - 安全逻辑正确（RS256 算法、token 旋转、错误信息不泄露）
> - 但覆盖率只有 65%，离 80% 有差距
> - 审查员没有发现的：集成测试需要 DB、jti_blacklist 清理缺失
>
> **流程体验：**
> - PM 拆解得很细，6 个任务 + 清晰的依赖关系
> - Implementer 遇到了技术问题能自己修正（RS256 算法修正）
> - 遇到架构决策（token 旋转）会 block 问我，不会擅自决定
> - Reviewer 审查很仔细，找到了安全隐患（constant_time_eq、用户枚举）
> - DevOps 遇到环境缺失会 block 报告，不会瞎搞
> - SRE-Observer 在另一个项目的故障场景中定位很快
>
> **不足之处：**
> - 部署环境配置是个盲点——AI 团队能写代码但不能凭空变出服务器
> - 覆盖率目标没达到——需要我明确把它作为 hard requirement
> - 审查只覆盖了 T1（JWT 核心），没有覆盖 T2（HTTP 接口）
>   这意味着 /login 的恒定时间比较、错误响应等是由 Implementer 自己保证的
>
> **改进想法：**
> 1. 下次让 PM 把"覆盖率 ≥ 80%"作为 hard gate，不达标不完成
> 2. 增加 T4b 审查 HTTP 接口（或者把 T4 的范围扩大到所有 auth 相关文件）
> 3. 提前配置好 staging 环境，避免部署阶段 block
> 4. 建立统一的部署模板（Dockerfile + docker-compose），新项目直接复用
>
> 总体来说，这个 AI 团队的工作流**基本符合**我的需求。
> 我一个人管理多个项目的模式是可行的，但需要我在基础设施和验收标准上多投入一点。
>
> 我要不要给这个工作流设计提一些反馈？"

Jacky 决定把上述反思整理成反馈，提交给系统作为改进输入。

---


---
