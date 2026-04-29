# Hermes Dev Orchestra — 单人全周期工作流指南

> **版本**: 2026.4.28
> **适用**: Hermes Agent v0.11.0+ | Claude Code CLI v2.1.110+ | Codex CLI v0.122.0+
> **目标读者**: 单人开发者，通过 SSH 管理多项目 AI 辅助开发

---

边界："10x" means lower coordination overhead across multiple projects for one developer；v1.2 does not promise same-project parallel Codex execution、team-scale concurrency 或 AI-factory throughput。Same-project parallelism is out of scope for v1.2. 未来若支持，需要另起设计覆盖 JSONL/event bus semantics、per-task file namespaces、per-task locks、worktrees or per-task branches、merge/review arbitration。

## 一、流程全景图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           单人全周期工作流                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   [需求] ──► [初始化] ──► [开发] ──► [审查] ──► [测试] ──► [验收] ──► [归档]  │
│      │          │          │         │         │         │         │        │
│      │          │          │         │         │         │         │        │
│   口头/       orch-init  Codex    Claude   Codex     用户    audit.jsonl   │
│   文字        orch-start 编码    代码审查  跑测试    确认    通信文件归档   │
│   描述                                                                       │
│                                                                             │
│   ▲                              异常分支                                   │
│   │                              ────────                                   │
│   │  codex-question.md ──► claude-decision.md (秒级)                       │
│   │  escalation.md      ──► L3/L4 用户确认 (阻塞)                           │
│   └──────────────────────────────────────────────────────────────────────   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 二、阶段详解

### Phase 0: 环境准备（一次性）

#### 2.0.1 前置依赖确认

```bash
# 开发机（无 sudo Ubuntu）上必须已安装
git --version       # >= 2.30
node --version      # >= 18
tmux -V             # >= 3.0
python3 --version   # >= 3.10
```

#### 2.0.2 API Key 配置

```bash
# 编辑 Hermes 环境变量
nano ~/.hermes/.env

# 添加以下内容：
OPENROUTER_API_KEY=sk-or-xxx           # Hermes 使用的 LLM
OPENAI_API_KEY=sk-xxx                  # Codex CLI 使用
ANTHROPIC_API_KEY=sk-ant-oat01-xxx     # Claude Code CLI 使用 (OAuth Token)
```

> **2026.4 重要更新**：Claude Code CLI 不再支持 raw API key，必须使用 Claude Max 订阅的 **OAuth Token**（`sk-ant-oat01-*`），有效期 1 年。

#### 2.0.3 CLI 首次认证(不需要做验证，本地cli已经处理好验证问题)

```bash
# Claude Code 首次认证（必须手动跑一次）
claude auth

# Codex CLI 首次认证
codex login
```

#### 2.0.4 安装 Dev Orchestra 适配包

```bash
cd ~/hermes-dev-orchestra
bash docs/orchestra/scripts/setup.sh
```

`setup.sh` 会自动完成：
- 检查上游 `hermes` 和 `tmux` 是否已安装
- 安装 SOUL.md、4 个自定义 Skills、Claude hooks 模板
- 创建目录结构：`/tmp/hermes-orchestra/`、`~/.local/state/hermes-orchestra/`、`~/.local/share/hermes-orchestra/`、`~/.cache/hermes-orchestra/`
- 安装 `orch-*` helper 命令到 PATH

#### 2.0.5 验证安装

```bash
hermes doctor && claude --version && codex --version && tmux -V
```

---

### Phase 1: 需求录入

#### 2.1.1 启动 Hermes 主控

```bash
# SSH 到 Ubuntu 后启动 Hermes CLI
hermes chat

# 在 Hermes 中激活编排技能
/dev-orchestra
```

#### 2.1.2 向 Hermes 描述需求

需求可以非常自然，无需写规格文档：

```
用户: "在 api-gateway 项目里实现用户注册 API，
      要求用 bcrypt 做密码哈希，返回 JWT token"

Hermes:
  1. todo 添加任务 [api-gateway] 实现用户注册 API
  2. 检查 hermes-api-gateway-claude 和 hermes-api-gateway-codex 是否在运行
  3. 写入 /tmp/hermes-orchestra/api-gateway/task.md (JSON envelope)
```

#### 2.1.3 任务文件格式

Hermes 自动将需求转换为标准 JSON envelope：

```json
{
  "schema_version": "1.0",
  "message_id": "msg-uuid",
  "project_id": "api-gateway",
  "task_id": "task-uuid",
  "correlation_id": "corr-uuid",
  "status": "queued",
  "author": "hermes",
  "authority": "orchestrator",
  "timestamp": "2026-04-28T10:00:00+08:00",
  "description": "实现用户注册 API，用 bcrypt 做密码哈希，返回 JWT token",
  "requirements": [
    "POST /api/auth/register 端点",
    "bcrypt 密码哈希，cost factor >= 12",
    "返回包含 user_id 和 token 的 JWT",
    "处理邮箱重复注册的错误"
  ],
  "constraints": [
    "仅修改 src/auth/ 目录下的文件",
    "执行前运行 npm test 验证基线"
  ],
  "priority": "normal"
}
```

---

### Phase 2: 项目初始化

#### 2.2.1 初始化新项目（首次）

```bash
# 项目 A：后端 API
orch-init api-gateway ~/projects/api-gateway

# 项目 B：前端
orch-init web-frontend ~/projects/web-frontend

# 项目 C：ML 管道
orch-init ml-pipeline ~/projects/ml-pipeline
```

`orch-init` 会：
1. 确保项目是 git 仓库（Codex 强制要求）
2. 创建独立的 Runtime/State/Audit/Cache per-project 目录
3. 在 State 中写入 `project.env`、`paths.json`、`current-task.json`
4. 在 `projects.json` 注册项目
5. 复制 Claude Code `settings.json`（含 Hooks 配置）到项目目录

#### 2.2.2 启动编排会话

```bash
# 启动项目 A 的 Claude + Codex 进程对
orch-start api-gateway ~/projects/api-gateway

# 启动项目 B
orch-start web-frontend ~/projects/web-frontend

# 启动项目 C
orch-start ml-pipeline ~/projects/ml-pipeline
```

`orch-start` 会：
- 启动/复用 `hermes-{project}-claude` tmux 会话（Claude Supervisor）
- 启动/复用 `hermes-{project}-codex` tmux 会话（Codex Executor）
- 启动 per-project internal watcher，负责扫描 Runtime bus、派发 task.md

#### 2.2.3 验证启动状态

```bash
orch-status
```

预期看到：
```
Project: api-gateway
  Claude tmux: hermes-api-gateway-claude  [running]
  Codex tmux:  hermes-api-gateway-codex   [running]
  Watcher PID: 12345
  Bus files:   task.md, codex-question.md, claude-decision.md, codex-result.md

Project: web-frontend
  ...
```

---

### Phase 3: 开发执行（自动）

#### 2.3.1 Codex 执行流程

```
Hermes 写入 task.md
    │
    ▼
Watcher 检测并派发给 Codex tmux
    │
    ▼
Codex 读取 task.md JSON envelope
    │
    ├── 检查项目技术栈（package.json, requirements.txt 等）
    ├── 运行现有测试，确认基线状态
    ├── 实现功能代码
    ├── 编写/更新测试用例
    ├── 运行测试验证
    ├── 检查代码规范和类型检查
    └── 写入 codex-result.md
```

#### 2.3.2 遇到疑问时的暂停协议

Codex 遇到以下情况时**必须暂停并写入 `codex-question.md`**：

- 任务需求存在歧义或冲突
- 需要选择技术方案但不确定最佳选项
- 发现现有代码与任务需求存在矛盾
- 需要修改非代码文件（配置、文档、CI/CD）
- 发现潜在的安全问题或性能瓶颈
- 预估工作量超出任务描述范围

疑问文件格式：

```json
{
  "schema_version": "1.0",
  "message_id": "msg-uuid",
  "project_id": "api-gateway",
  "task_id": "task-uuid",
  "correlation_id": "corr-uuid",
  "status": "question",
  "author": "codex",
  "authority": "executor",
  "timestamp": "2026-04-28T10:05:00+08:00",
  "body": {
    "question": "应该用 bcrypt 还是 argon2 做密码哈希？",
    "options": ["bcrypt（成熟稳定）", "argon2（更安全但较新）"],
    "context": {
      "current_file": "src/auth/register.ts",
      "related_files": ["src/auth/hash.ts"]
    },
    "urgency": "BLOCKING"
  }
}
```

#### 2.3.3 疑问处理流程

```
Codex 写入 codex-question.md
    │
    ▼
Watcher 检测并转发给 Claude tmux
    │
    ▼
Claude 读取 codex-question.md
    │
    ├── 评估技术选项
    ├── 考虑项目规范和安全要求
    └── 写入 claude-decision.md
    │
    ▼
Watcher 检测 claude-decision.md 更新
    │
    ▼
Codex 读取决策并继续执行
```

Claude 决策文件格式：

```json
{
  "schema_version": "1.0",
  "message_id": "msg-uuid",
  "project_id": "api-gateway",
  "task_id": "task-uuid",
  "correlation_id": "corr-uuid",
  "status": "decided",
  "author": "claude-supervisor",
  "authority": "technical-supervisor",
  "timestamp": "2026-04-28T10:06:00+08:00",
  "decision": "APPROVED",
  "rationale": "选择 bcrypt，因为项目已有 bcrypt 依赖，且 cost factor 12 已足够安全。argon2 虽然更安全但引入新依赖不值得。",
  "execution": {
    "authority_sufficient": true,
    "guidance": "使用 bcrypt.hash(password, 12)，确保在 src/auth/hash.ts 中统一封装"
  }
}
```

> **一般技术决策（代码实现细节、API选择、代码规范）由 Claude 秒级自动处理，用户无感知。**

---

### Phase 4: 风险升级（按需）

#### 2.4.1 何时触发升级

Claude 遇到以下情况时**写入 `escalation.md`**，不再自行决策：

| 等级 | 标识 | 示例 |
|------|------|------|
| L1 | 注意 | 引入新依赖、修改构建脚本 |
| L2 | 警告 | 修改数据库 schema、删除旧 API |
| L3 | 危险 | 系统级命令、修改认证逻辑 |
| L4 | 紧急 | 删除生产数据、修改密钥 |

#### 2.4.2 升级处理流程

```
Claude 检测到高风险操作
    │
    ├── 写入 escalation.md (JSON envelope)
    │
    ▼
Hermes 检测到 escalation.md
    │
    ├── L1-L2: 异步通知用户，默认安全路径继续
    ├── L3-L4: 阻塞，向用户请求最终决策
    │
    ▼
用户决策 (SSH clarify / orch-approve / orch-reject)
    │
    ▼
Hermes 写入审计日志 audit.jsonl
    ├── 批准 → 写入 claude-decision.md (APPROVED)
    ├── 拒绝 → 写入 claude-decision.md (REJECTED)
    └── 修改 → 提交修订任务
    │
    ▼
Codex 按用户决策继续或回滚
```

Escalation 文件格式：

```json
{
  "schema_version": "1.0",
  "message_id": "msg-uuid",
  "project_id": "api-gateway",
  "task_id": "task-uuid",
  "correlation_id": "corr-uuid",
  "status": "blocked",
  "author": "claude-supervisor",
  "authority": "escalation-recommender",
  "timestamp": "2026-04-28T10:10:00+08:00",
  "risk_level": "L3",
  "body": {
    "description": "需要修改 auth_sessions 表结构，添加 refresh_token 字段",
    "proposed_action": "ALTER TABLE auth_sessions ADD COLUMN refresh_token VARCHAR(255)",
    "potential_impact": "此 ALTER TABLE 可能使现有 JWT token 失效，已登录用户会被登出",
    "recommended_user_action": "建议在低峰期执行，或先创建新表做双写再灰度迁移"
  }
}
```

#### 2.4.3 用户决策方式

```bash
# 查看待决策列表
orch-decisions

# 输出示例：
# ID          Project        Level   Description
# apr-001     api-gateway    L3      修改 auth_sessions 表结构
# apr-002     web-frontend   L2      添加 tailwindcss 依赖

# 批准某个决策
orch-approve apr-001 "确认执行，已备份数据库"

# 拒绝某个决策
orch-reject apr-001 "风险过高，采用双写迁移方案"

# 查看审计日志
orch-audit api-gateway --limit 20
```

> **L3/L4 决策必须阻塞直到用户明确批准或拒绝。任何 agent、timeout、fallback 都不得自动批准。**

---

### Phase 5: 代码审查

#### 2.5.1 自动审查触发

Codex 完成并写入 `codex-result.md` 后，watcher 自动转发给 Claude 审查：

```json
{
  "schema_version": "1.0",
  "message_id": "msg-uuid",
  "project_id": "api-gateway",
  "task_id": "task-uuid",
  "correlation_id": "corr-uuid",
  "status": "completed",
  "author": "codex",
  "authority": "executor",
  "timestamp": "2026-04-28T10:15:00+08:00",
  "body": {
    "summary": "实现了用户注册 API，包含 bcrypt 哈希和 JWT 签发",
    "files_modified": [
      {"path": "src/auth/register.ts", "change": "新增注册路由和控制器"},
      {"path": "src/auth/hash.ts", "change": "新增 bcrypt 封装"},
      {"path": "tests/auth/register.test.ts", "change": "新增单元测试"}
    ],
    "tests": {"status": "PASSED", "commands": ["npm test -- src/auth/"]},
    "known_issues": [],
    "next_steps": ["考虑添加邮箱验证流程"]
  }
}
```

#### 2.5.2 Claude 审查 Checklist

Claude 审查时逐项确认：

- [ ] 是否有 SQL 注入、XSS、路径遍历等安全漏洞？
- [ ] 是否引入了新的依赖？依赖是否可信？
- [ ] 是否修改了配置文件或环境变量？
- [ ] 是否符合项目的代码规范？
- [ ] 是否有足够的错误处理？
- [ ] 是否包含测试用例？
- [ ] 性能是否可接受？（是否有 N+1 查询、内存泄漏等）

审查结果写入 `review-result.md`：

```json
{
  "schema_version": "1.0",
  "message_id": "msg-uuid",
  "project_id": "api-gateway",
  "task_id": "task-uuid",
  "correlation_id": "corr-uuid",
  "status": "reviewed",
  "author": "claude-supervisor",
  "authority": "technical-supervisor",
  "timestamp": "2026-04-28T10:16:00+08:00",
  "decision": "APPROVED",
  "rationale": "代码质量良好，测试通过，bcrypt 使用正确，JWT 签发逻辑合理",
  "body": {
    "findings": [],
    "required_changes": []
  },
  "execution": {
    "authority_sufficient": true
  }
}
```

审查结论有三种：
- **APPROVED** — 通过，无需修改
- **NEEDS_MODIFICATION** — 需要修改，Codex 按意见调整后重新提交
- **REJECTED** — 拒绝，回滚已做的修改

---

### Phase 6: 测试验证

#### 2.6.1 Codex 自测

Codex 在完成任务时已经执行了测试（任务要求的一部分）：

```bash
# 基线确认
npm test  # 或 pytest, cargo test, go test 等

# 实现后测试
npm test -- src/auth/
```

测试结果记录在 `codex-result.md` 的 `tests` 字段。

#### 2.6.2 用户验收测试

```bash
# 查看任务完成摘要
orch-status api-gateway

# 手动验证（SSH 连接到项目目录）
cd ~/projects/api-gateway
git diff --stat                    # 查看变更文件列表
git diff src/auth/register.ts      # 审查关键文件
npm test                           # 运行全部测试
npm run lint                       # 检查代码规范
npm run typecheck                  # 类型检查

# 连接到 tmux 查看完整执行日志
tmux attach -t hermes-api-gateway-codex
# 按 Ctrl+B 再按 D 退出（不终止会话）
```

#### 2.6.3 不通过的处理

```
用户: "注册 API 缺少邮箱格式验证"
    │
    ▼
Hermes 将反馈作为新任务写入 task.md
    │
    ▼
Codex 执行补充修改
    │
    ▼
Claude 审查
    │
    ▼
用户再次验收
```

---

### Phase 7: 验收确认

#### 2.7.1 用户确认

```
Hermes: "【api-gateway】用户注册 API 已完成：

  实现内容：
  - src/auth/register.ts: 新增注册路由
  - src/auth/hash.ts: bcrypt 封装
  - tests/auth/register.test.ts: 单元测试（全部通过）

  Claude 审查结果：APPROVED，无安全漏洞

  是否确认验收？"

用户: "确认验收"
```

#### 2.7.2 Hermes 更新状态

- todo 标记任务完成
- 写入审计日志
- 可选：归档通信文件

---

### Phase 8: 归档与清理

#### 2.8.1 审计日志

所有决策和升级自动记录到：

```bash
~/.local/share/hermes-orchestra/{project}/audit.jsonl
```

格式示例：
```
{"timestamp":"2026-04-28T10:00:00+08:00","level":"INFO","project":"api-gateway","type":"TASK_START","task_id":"task-001","agent_source":"hermes"}
{"timestamp":"2026-04-28T10:06:00+08:00","level":"INFO","project":"api-gateway","type":"DECISION","decision":"APPROVED","approval_id":"dec-001","agent_source":"claude-supervisor"}
{"timestamp":"2026-04-28T10:10:00+08:00","level":"WARN","project":"api-gateway","type":"ESCALATION","risk_level":"L3","approval_id":"esc-001","agent_source":"claude-supervisor"}
{"timestamp":"2026-04-28T10:12:00+08:00","level":"INFO","project":"api-gateway","type":"USER_DECISION","decision":"APPROVED","approval_id":"esc-001","user_decision":"确认执行，已备份数据库"}
```

#### 2.8.2 通信文件归档

```bash
# 任务完成后，归档通信文件
tar czf /tmp/hermes-orchestra/api-gateway-$(date +%Y%m%d-%H%M%S).tar.gz \
  /tmp/hermes-orchestra/api-gateway/

# 清理旧的 Runtime 文件（保留 audit.jsonl）
rm /tmp/hermes-orchestra/api-gateway/task.md
rm /tmp/hermes-orchestra/api-gateway/codex-question.md
rm /tmp/hermes-orchestra/api-gateway/claude-decision.md
rm /tmp/hermes-orchestra/api-gateway/codex-result.md
rm /tmp/hermes-orchestra/api-gateway/review-result.md
```

#### 2.8.3 Git 提交

```bash
cd ~/projects/api-gateway
git add .
git commit -m "feat(auth): 实现用户注册 API

- POST /api/auth/register 端点
- bcrypt 密码哈希 (cost=12)
- JWT token 签发
- 邮箱重复注册错误处理
- 单元测试覆盖

Claude 审查: APPROVED
Hermes 任务: task-001"
```

> **安全最佳实践**：Hermes 在危险操作前自动执行 `git stash` 或 `git branch backup-{timestamp}`

---

## 三、多项目并行管理

### 3.1 同时管理多个项目

```bash
# 用户一次性下达多个任务：
"同时处理：
  1. api-gateway: 修复登录 Bug
  2. web-frontend: 添加响应式布局
  3. ml-pipeline: 更新数据预处理脚本"
```

Hermes 内部状态：

```
todo:
  [api-gateway] 修复登录 Bug              — in_progress
  [web-frontend] 添加响应式布局          — in_progress
  [ml-pipeline] 更新数据预处理脚本       — in_progress

进程:
  hermes-api-gateway-claude    [running]
  hermes-api-gateway-codex     [running]
  hermes-web-frontend-claude   [running]
  hermes-web-frontend-codex    [running]
  hermes-ml-pipeline-claude    [running]
  hermes-ml-pipeline-codex     [running]
```

### 3.2 并行调度策略

1. **todo 列表分项目追踪**：每个任务前缀 `[Project Name]`
2. **进程轮询**：`process(action="list")` 查看所有运行中项目
3. **阻塞不卡死**：当项目 A 的 Codex 等待决策时，Hermes 自动切换到项目 B 的任务
4. **消息前缀**：所有用户通知都带 `[Project Name]` 前缀，避免混淆

### 3.3 状态查看

```bash
# 查看所有项目状态
orch-status

# 查看特定项目
orch-status api-gateway

# 输出示例：
# Project: api-gateway
#   Status: waiting_decision
#   Current task: 修复登录 Bug
#   Last codex result: 已实现修复，等待 Claude 审查
#   Last review: PENDING
#
# Project: web-frontend
#   Status: in_progress
#   Current task: 添加响应式布局
#   Last codex result: 正在编写 CSS...
#
# Project: ml-pipeline
#   Status: in_progress
#   Current task: 更新数据预处理脚本
#   Last codex result: 测试通过，写入 result 文件
```

---

## 四、通信时序图

### 4.1 正常流程

```
  User      Hermes     Watcher    Codex      Claude
   │          │          │          │          │
   │ 任务描述  │          │          │          │
   ├─────────►│          │          │          │
   │          │ 写入     │          │          │
   │          ├────task.md─────────►│          │
   │          │          │ 检测     │          │
   │          │          ├─────────►│          │
   │          │          │          │ 执行编码  │
   │          │          │          │ ────────►│
   │          │          │          │ 写入     │
   │          │◄──codex-result.md───┤          │
   │          │          │ 检测     │          │
   │          │          ├────────────────────►│
   │          │          │          │          │ 审查
   │          │◄──review-result.md─────────────┤
   │          │          │          │          │
   │ 结果汇总  │          │          │          │
   │◄─────────┤          │          │          │
```

### 4.2 有疑问的流程

```
  User      Hermes     Watcher    Codex      Claude
   │          │          │          │          │
   │          │          │          │ 遇到疑问  │
   │          │          │          │ 写入     │
   │          │◄─codex-question.md──┤          │
   │          │          │ 转发     │          │
   │          │          ├────────────────────►│
   │          │          │          │          │ 决策
   │          │          │          │          │ 写入
   │          │          │◄─claude-decision.md─┤
   │          │          │ 转发     │          │
   │          │          ├─────────►│          │
   │          │          │          │ 继续执行  │
```

### 4.3 有风险升级的流程

```
  User      Hermes     Watcher    Codex      Claude
   │          │          │          │          │
   │          │          │          │          │ 检测到 L3
   │          │          │          │          │ 写入
   │          │◄──escalation.md────────────────┤
   │          │          │ 阻塞项目  │          │
   │ 决策请求  │          │          │          │
   │◄─────────┤          │          │          │
   │ 用户决策  │          │          │          │
   ├─────────►│          │          │          │
   │          │ 写入     │          │          │
   │          ├────claude-decision.md          │
   │          │          │ 转发     │          │
   │          │          ├─────────►│          │
   │          │          │          │ 继续/回滚 │
```

---

## 五、日常使用速查表

### 5.1 常用命令

| 命令 | 用途 |
|------|------|
| `hermes chat` | 启动 Hermes 主控 |
| `/dev-orchestra` | 激活编排技能 |
| `orch-init <id> <dir>` | 初始化新项目 |
| `orch-start <id> <dir>` | 启动项目的 Claude + Codex |
| `orch-stop <id>` | 停止项目进程 |
| `orch-status [id]` | 查看项目状态 |
| `orch-decisions` | 查看待决策列表 |
| `orch-approve <id> [reason]` | 批准决策 |
| `orch-reject <id> [reason]` | 拒绝决策 |
| `orch-risk-check <cmd>` | 检查命令风险等级 |
| `orch-audit <id> --limit N` | 查看审计日志 |
| `orch-verify` | 运行 smoke 验证 |
| `tmux ls \| grep hermes-` | 查看所有 tmux 会话 |
| `tmux attach -t hermes-{p}-codex` | 连接 Codex 会话 |
| `tmux attach -t hermes-{p}-claude` | 连接 Claude 会话 |

### 5.2 决策矩阵速查

| 决策类型 | 处理层级 | 响应时间 | 用户感知 |
|---------|---------|---------|---------|
| 代码实现细节 | Claude Code | 秒级 | 无（自动） |
| API 设计/技术选型 | Claude Code | 秒级 | 无（自动） |
| 引入新依赖 | Claude -> Hermes L1 | 异步 | 远程通知 |
| 修改数据库 Schema | Claude -> Hermes L2 | 5 分钟内 | 通知 + 可能阻塞 |
| 修改认证/安全逻辑 | Claude -> Hermes L3 | 立即 | SSH clarify / 远程紧急通知 |
| 删除生产数据/系统命令 | Claude -> Hermes L4 | 立即阻塞 | SSH clarify + 远程紧急通知 |

### 5.3 文件通信总线

每个项目在 `/tmp/hermes-orchestra/{project}/` 下有：

| 文件 | 写入者 | 读取者 | 用途 |
|------|--------|--------|------|
| `task.md` | Hermes | Codex | 任务描述与需求 |
| `codex-question.md` | Codex | Hermes/Claude | Codex 遇到的疑问 |
| `claude-decision.md` | Claude | Hermes/Codex | Claude 的技术决策 |
| `escalation.md` | Claude | Hermes | 危险/产品级升级请求 |
| `codex-result.md` | Codex | Hermes/Claude | 执行结果与产出 |
| `review-result.md` | Claude | Hermes | 代码审查意见 |

边界：fixed Runtime bus filenames represent one active task slot per project。当前固定 Runtime bus 文件是 `task.md, codex-question.md, claude-decision.md, escalation.md, codex-result.md, review-result.md`；它们 are not a per-project multi-task parallel execution protocol。排队或追加任务可以存在于 State/todo 层，但同一项目的 Runtime bus 不表达多个同时活动任务。

---

## 六、故障排查

### 6.1 项目卡住

```bash
# 第一步：查看状态
orch-status <project-id>

# 第二步：查看 watcher 日志
tail -50 ~/.local/state/hermes-orchestra/<project>/orch-bus-loop.log

# 第三步：检查 tmux 会话
tmux ls | grep hermes-<project>

# 第四步：手动查看 bus 文件
ls -lt /tmp/hermes-orchestra/<project>/
cat /tmp/hermes-orchestra/<project>/codex-result.md
```

### 6.2 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 项目卡住 | watcher、tmux 或 bus 文件状态未知 | 先运行 `orch-status`，再查看日志 |
| Codex 拒绝执行 | 目录不是 git 仓库 | `git init && git add . && git commit -m init` |
| Codex 卡住无输出 | 缺少 PTY | 确保用 tmux 启动，或使用 `codex exec` |
| Claude 审批弹窗阻断 | Hook 未生效 | 检查 `.claude/settings.json` 是否存在且格式正确 |
| Hermes 收不到远程决策回复 | Remote Decision Channel 未配置 | 使用本地 `orch-approve` / `orch-reject` fallback |
| tmux 会话丢失 | SSH 断开 | tmux 会话默认保留，用 `tmux ls` 查看并 `tmux attach` |
| 权限被拒绝 | 无 sudo | 所有安装都在 `$HOME/`，无需 sudo |
| Codex 输出被截断 | 超过 200KB 缓冲区 | 使用 `--json` 过滤，或拆分任务为更小的子任务 |

---

## 七、安全最佳实践

1. **审计日志不可删**：`~/.local/share/hermes-orchestra/{project}/audit.jsonl` 是 durable JSONL 记录
2. **git 是底线**：任何危险操作前，Hermes 自动执行 `git stash` 或 `git branch backup-{timestamp}`
3. **L3-L4 绝不自动**：任何标记为 DANGER/CRITICAL 的操作，必须用户明确输入 "批准"
4. **API Key 隔离**：Claude Code 用 Anthropic OAuth，Codex 用 OpenAI Key，Hermes 用 OpenRouter，互不混用
5. **tmux 会话分离**：不同项目的会话相互隔离，防止交叉污染

---

## 八、完整示例：从零开始一个项目

```bash
# 1. SSH 到 Ubuntu 开发机
ssh dev@192.168.1.100

# 2. 创建项目目录
mkdir -p ~/projects/api-gateway
cd ~/projects/api-gateway
git init && git add . && git commit -m "init"

# 3. 初始化 Hermes 项目
orch-init api-gateway ~/projects/api-gateway

# 4. 启动 Claude + Codex 进程对
orch-start api-gateway ~/projects/api-gateway

# 5. 启动 Hermes 主控
hermes chat

# 6. 在 Hermes 中激活编排技能
/dev-orchestra

# 7. 下达开发任务
"在 api-gateway 项目里实现用户注册 API，
 要求用 bcrypt 做密码哈希，返回 JWT token"

# 8. （自动流程开始，无需手动干预）
#    - Hermes 写入 task.md
#    - Watcher 派发给 Codex
#    - Codex 编码实现
#    - Claude 审查
#    - 如有疑问自动流转
#    - 如有风险自动升级

# 9. 查看状态
orch-status api-gateway

# 10. 验收（SSH 中查看结果）
cd ~/projects/api-gateway
git diff --stat
npm test

# 11. 确认验收（在 Hermes 中回复）
"确认验收"

# 12. Git 提交
git add .
git commit -m "feat(auth): 实现用户注册 API"

# 13. 停止项目（可选）
orch-stop api-gateway
```

---

*Happy Orchestrating!* 只要问题没有解决，蕾姆就不会休息。这是作为女仆的矜持。
