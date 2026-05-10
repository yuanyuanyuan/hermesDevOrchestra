## 附录 D：AI 失败模式

> 主文档展示的是 AI 的"理想执行路径"。本节补充**每个角色在真实运行中可能犯的错**，用于校准预期和设计兜底机制。

> 📎 **相关 ASCII 流程图**：
> - [`ascii-core-flows.md`](./ascii-core-flows.md) — F3 L3 风险升级、F4 自动故障检测
> - [`ascii-decision-matrix.md`](./ascii-decision-matrix.md) — L3 升级流程（完整路径）
> - [`ascii-kanban-subflows.md`](./ascii-kanban-subflows.md) — Worker 崩溃状态回滚

---

### D.1 Implementer — 过度自信地自行决定

**【失败场景】**

T1 任务中，Implementer 遇到"RS256 vs HS256"的选型问题。Jacky 在任务 body 中写了"使用 RS256"，但 Implementer 发现项目里已经有一个 `hmac` 依赖，为了"减少依赖"，它**没有调用 `kanban_block`**，直接把算法改成了 HS256。

**【后果】**

- Tech-Reviewer 在 T4 中发现算法不符，标记为"违反需求"
- T5（修复任务）被创建，Implementer 重新改回 RS256
- 浪费了 ~20 分钟 + 一轮 API 调用

**【为什么发生】**

LLM 的"帮助性偏差"（helpfulness bias）——它倾向于"帮用户解决问题"而非"承认不确定"。当问题看起来"简单"时，它倾向于自行决定。

**【兜底机制】**

- R9 SOUL.md 强制规则：遇到架构决策必须 block
- R14 checklist：明确列出必须 block 的触发条件
- R6 Risk Policy：某些技术选型可配置为 L2（需要记录但不需要用户审批），降低 block 频率

---

### D.2 Implementer — 未发现隐藏的安全问题

**【失败场景】**

Implementer 在实现 `verify_token` 时，使用了 `jsonwebtoken` 库的默认验证选项。它没有注意到该库默认**不验证 `exp` 声明**，需要显式设置 `validation.validate_exp = true`。

测试用例中，所有 token 都是新签发的（未过期），所以测试通过。但生产环境中，被盗的 access token 可以**永久有效**。

**【后果】**

- Tech-Reviewer 可能遗漏（静态分析工具不一定能检测库配置）
- QA-Tester 的测试用例如果没有显式测试过期 token，也无法发现
- 安全漏洞流入生产

**【兜底机制】**

- Tech-Reviewer 的 SOUL.md 必须包含"JWT 安全 checklist"（显式检查 exp 验证、算法限制、密钥长度）
- 安全相关的测试用例必须在 QA-Tester 的 checklist 中独立存在

---

### D.3 Tech-Reviewer — 误报安全"问题"

**【失败场景】**

Tech-Reviewer 看到代码中使用了 `ring::rand::SystemRandom` 生成 nonce，认为"random 生成器不可预测，不够安全"，标记为"高风险"。

实际上 `ring::rand::SystemRandom` 是操作系统级 CSPRNG（密码学安全伪随机数生成器），安全性完全足够。

**【后果】**

- T5（修复任务）被创建，Implementer 花 15 分钟调研后回复"当前实现已安全"
- Tech-Reviewer 在 T5 的 review 中承认误报
- 一轮无效迭代

**【为什么发生】**

LLM 对库和 API 的了解来自训练数据，可能将"使用 random"的通用警告错误地应用到密码学安全的具体实现上。

**【兜底机制】**

- Reviewer 的 SOUL.md 要求"标记问题前，先确认你对相关库的了解"；不确定时 block 而非直接标记
- 引入"争议仲裁"机制：当 reviewer 和 implementer 对同一问题有分歧时，升级到 orchestrator 或用户

---

### D.4 Tech-Reviewer — 遗漏真正的安全问题

**【失败场景】**

Tech-Reviewer 审查 T1 的 `jwt.rs`，注意到 `verify_token` 返回 `Result<TokenClaims, JwtError>`，但没有检查代码中是否所有调用点都正确处理了 `Err`。

实际上 `src/auth/routes.rs` 中有一个路径：

```rust
// 某处代码（不在 reviewer 的审查范围内）
let claims = verify_token(&token).unwrap();  // ← panic on invalid token!
```

Tech-Reviewer 的审查范围仅限于 T1 的 changed_files，没有覆盖下游调用点。这个 `.unwrap()` 在 T2 的实现中被引入，但 T4 审查时 T2 还未创建。

**【后果】**

- 带有 `.unwrap()` 的代码进入 main
- 生产环境中收到无效 token 时服务 panic
- SRE-Observer 在事后分析中定位到"代码缺陷 + 审查范围不足"

**【兜底机制】**

- R13 handoff metadata 要求列出 `changed_files`，但 reviewer 的审查范围应可配置为"changed_files + 直接调用方"
- 引入"交叉审查"：T2 完成后，Tech-Reviewer 可自动触发对 T1+T2 的联合审查

---

### D.5 Orchestrator — 任务拆分过细

**【失败场景】**

Orchestrator 收到"实现 JWT 认证模块"的需求后，拆分了 15 个子任务：
- T1: 生成 RSA 密钥对
- T2: 实现 TokenClaims 结构体
- T3: 实现 generate_token 函数
- T4: 实现 verify_token 函数
- T5: 实现 refresh_access_token 函数
- T6: 写 generate_token 的单元测试
- ...（共 15 个）

每个任务只有 20-30 行代码的 scope。Dispatcher 在 15 个任务间来回切换，开销远大于实际工作量。

**【后果】**

- 总 token 消耗增加 3-4 倍（每个任务都有独立的 spawn/setup/teardown 开销）
- Jacky 收到 15 个"任务完成"通知，信息过载
- 实际耗时比"粗粒度拆分"更长

**【为什么发生】**

LLM 对"原子任务"的理解偏机械——倾向于按代码文件/函数拆分，而非按"可独立验收的单元"拆分。

**【兜底机制】**

- SOUL.md 中明确"任务粒度指导"：每个任务应能在 15-60 分钟内完成，产出应可独立验收
- Orchestrator 的 SOUL.md 要求"拆分后自检：如果两个任务必须在同一个 worktree 中顺序执行，考虑合并"

---

### D.6 Orchestrator — 依赖关系设错

**【失败场景】**

Orchestrator 创建任务时，将 T3（测试）设置为 T2（HTTP 接口）的 **child**，但 T4（代码审查）设置为 T1（JWT 核心）的 child。

实际上审查应该在 T2 完成后进行（审查完整的认证流程），而不是 T1 完成后。

**【后果】**

- Tech-Reviewer 审查的是"不完整的实现"（只有 JWT 核心，没有 HTTP 接口）
- T4 完成后，T2 才做完；T2 做完后又需要第二轮审查
- 审查价值大幅降低

**【兜底机制】**

- Orchestrator 的 SOUL.md 要求"设置 parents 后，反向验证：每个下游任务拿到上游的 handoff 后能否独立完成？"
- 引入"依赖图可视化"：Jacky 可在任务创建后查看依赖图，发现错误时手动调整

---

### D.7 QA-Tester — 测试覆盖不全

**【失败场景】**

QA-Tester 执行 T3（写测试），编写了 8 个单元测试：
- 生成 access token → 通过
- 验证合法 token → 通过
- refresh token 生成新 access token → 通过
- 过期 token 拒绝 → 通过

但遗漏了：
- **token 篡改测试**（修改 payload 后验证失败）
- **算法切换攻击**（用 HS256 公钥作为 HMAC 密钥的攻击）
- **并发刷新竞争**（两个请求同时用同一个 refresh token）

**【后果】**

- 测试覆盖率报告显示 85%，但实际有 3 个安全场景未覆盖
- 这些漏洞在生产环境中被发现

**【兜底机制】**

- QA-Tester 的 SOUL.md 必须包含"JWT 安全测试 checklist"（明确列出必须覆盖的攻击场景）
- 引入"测试用例审查"：Tech-Reviewer 在审查代码时，同时审查测试用例的完整性

---

### D.8 DevOps-Engineer — 环境变量遗漏

**【失败场景】**

DevOps-Engineer 编写 `deploy.sh`：

```bash
#!/bin/bash
set -e
scp target/release/alpha $DEPLOY_HOST:/opt/alpha/
ssh $DEPLOY_HOST "systemctl restart alpha"
```

没有检查 `DEPLOY_HOST` 是否设置。在本地测试时 `DEPLOY_HOST` 碰巧在 `.bashrc` 中定义了，所以测试通过。但在 CI/CD 环境中该变量未设置，`deploy.sh` 执行 `scp target/release/alpha :/opt/alpha/`（空主机名），报错。

**【后果】**

- 部署失败，任务 crashed
- SRE-Observer 分析后定位到"环境变量未验证"
- 需要重新编写 deploy.sh 并验证

**【兜底机制】**

- DevOps-Engineer 的 SOUL.md 要求"部署脚本必须以 `set -u` 开头，所有环境变量在使用前检查"
- Risk Policy 可将 `"scp .* :"` 或 `"ssh .*@"` 中主机名为空的模式标记为 L2

---

### D.9 SRE-Observer — 根因归因错误

**【失败场景】**

Project Beta 部署失败后，SRE-Observer 分析：
- trace.db 显示 `terminal(command="deploy.sh")` 返回 exit_code=1
- worker logs 显示 "DATABASE_URL not set"
- 环境快照显示 disk free 98%（正常）

SRE-Observer 得出结论：`root_cause_category="code"`，`responsible_profile="devops-engineer"`，`recommended_action="修复 deploy.sh 以检查环境变量"`。

但实际上，生产环境的 `/etc/project-beta/env` **是有** `DATABASE_URL` 的。真正的问题是 deploy.sh 没有 `source /etc/project-beta/env`，而是期望环境变量已经在 shell 中设置。SRE-Observer 没有深入检查"环境变量应该从哪里来"，只看到了"环境变量没设置"。

**【后果】**

- 推荐的修复方向错误： Implementer 按建议修改 deploy.sh 添加了环境变量检查，但问题根源是 deploy.sh 的设计假设（环境变量来源）
- 下一轮部署仍然可能失败（如果环境变量来源方式改变）

**【为什么发生】**

LLM 倾向于"就近归因"——看到的第一个错误原因就是根因。深入调查需要主动追问"为什么环境变量没设置"，但 LLM 可能在得到表面解释后停止。

**【兜底机制】**

- SRE-Observer 的 SOUL.md 要求"5 Whys"：对每个发现的"直接原因"，追问至少 3 层"为什么"
- 根因报告 metadata 中 `confidence` 字段：当调查深度不足时，必须标记为 `low` 或 `medium`
- 人的最终审核：Jacky 作为 L3 决策者，对 SRE 报告做最终判断

---

### D.10 SRE-Observer — 过度自信的结论

**【失败场景】**

SRE-Observer 分析一个 `timed_out` 任务后，输出：
- `root_cause_category="environment"`
- `confidence="high"`
- `root_cause="Worker 进程内存不足，OOM killed"`

但实际上，`dmesg` 中没有 OOM 记录， worker logs 的最后一条是 "Starting compilation..." 然后就没有下文了。真正的原因是：任务被拆分的 scope 过大，编译时间超过 `max_runtime_seconds`，被 Dispatcher 超时回收。

SRE-Observer 没有检查 `max_runtime_seconds` 配置和任务的 `expected_duration_max` 声明，就匆忙归因于 OOM。

**【后果】**

- Jacky 收到"内存不足"的结论，可能错误地增加服务器内存
- 实际问题（任务拆分过粗）没有被解决，后续类似任务继续超时

**【兜底机制】**

- SRE-Observer 的 SOUL.md 要求"排除所有其他可能后再给出 high confidence 结论"
- RCA metadata schema 要求列出"被排除的其他假设"，强制结构化思考
- 人的审核：Jacky 对 `confidence="high"` 的报告要求必须附上完整的排除推理

---
