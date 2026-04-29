# Hermes Dev Orchestra — 多项目AI开发编排系统

> **版本**: 2026.4.24  
> **适用**: Hermes Agent v0.11.0+（pin: `023b1bff11c2a01a435f1956a0e2ac1773a065f3`）| Claude Code CLI v2.1.110+ | Codex CLI v0.122.0+  
> **环境**: Ubuntu (无 sudo) + Windows SSH 远程开发

---

## 一、需求理解

你的场景：
- 局域网 Ubuntu 开发机（无 sudo），Windows 通过 SSH 远程接入
- 已安装 `claude` 和 `codex` CLI
- **一个人要同时开发多个项目**
- 需要 **三层代理协作** + **三级决策流转**

边界："10x" means lower coordination overhead across multiple projects for one developer；v1.2 does not promise same-project parallel Codex execution、team-scale concurrency 或 AI-factory throughput。Same-project parallelism is out of scope for v1.2. 未来若支持，需要另起设计覆盖 JSONL/event bus semantics、per-task file namespaces、per-task locks、worktrees or per-task branches、merge/review arbitration。

---

## 二、核心架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    用户层 (Windows SSH)                       │
│              也可通过抽象 Remote Decision Channel 远程决策    │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│              Hermes Agent (Ubuntu 顶层编排器)                │
│  • SOUL.md 定义「开发管理编排者」人格                        │
│  • todo / memory 管理多项目状态                              │
│  • terminal/process 启动/监控子进程                          │
│  • clarify / send_message 向用户请求最终决策                 │
│  • 通过文件总线协调 Claude ↔ Codex 通信                      │
└──────────────┬──────────────────────────────┬─────────────┘
               │                              │
    ┌──────────▼──────────┐      ┌────────────▼────────────┐
    │ Claude Supervisor   │      │ Codex Executor            │
    │ (每个项目独立 tmux)  │      │ (每个项目独立 tmux/exec)   │
    │                     │      │                           │
    │ • 架构决策          │      │ • 实际编码实现             │
    │ • 代码审查          │◄────►│ • 测试/重构               │
    │ • 技术疑问解答      │文件总线│ • 遇到疑问暂停并上报       │
    │ • 标记危险操作      │      │ • 完成后输出结果          │
    │   → escalation.md   │      │                           │
    └─────────────────────┘      └───────────────────────────┘
```

### 文件通信总线 (per-project)

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

## 三、三级决策流转机制

```
Codex 执行中遇到问题
    │
    ▼
┌────────────────────────────────────────┐
│ 问题分类 (由 Claude Supervisor 判断)    │
└────────────────────────────────────────┘
    │
    ├─► 一般技术决策（实现方式、API选择、代码规范）
    │      └──► Claude Code 直接决策 → 回复 codex-question.md
    │            ✅ 秒级响应，无需用户介入
    │
    ├─► 架构/安全相关（影响产品方向、引入风险、修改认证/密钥）
    │      └──► Claude 写入 escalation.md → Hermes 介入
    │            Hermes 评估风险等级 (L1-L4)
    │            ├── L1-L2: 异步通知用户，默认安全路径继续
    │            └── L3-L4: 阻塞，clarify() 向用户请求最终决策
    │            ✅ 分钟级响应，用户有知情权
    │
    └─► 系统级危险操作（rm -rf、DROP TABLE、sudo、生产数据）
           └──► 直接 L4 升级 → Hermes 立即阻断
                 └──► 通过 SSH clarify 或 Remote Decision Channel 向用户确认
                 ✅ 阻塞直到用户明确批准/拒绝
```

### 决策矩阵

| 决策类型 | 处理层级 | 响应时间 | 用户感知 |
|---------|---------|---------|---------|
| 代码实现细节 | Claude Code | 秒级 | 无（自动） |
| API 设计/技术选型 | Claude Code | 秒级 | 无（自动） |
| 引入新依赖 | Claude → Hermes L1 | 异步 | Remote Decision Channel 通知 |
| 修改数据库 Schema | Claude → Hermes L2 | 5 分钟内 | 远程通知 + 可能阻塞 |
| 修改认证/安全逻辑 | Claude → Hermes L3 | 立即 | SSH clarify / Remote Decision Channel |
| 删除生产数据/系统命令 | Claude → Hermes L4 | 立即阻塞 | SSH clarify + 远程紧急通知 |

---

## 四、多项目并行管理

### tmux 会话命名规范

```
hermes-{project}-claude   → Claude Code 监督会话
hermes-{project}-codex    → Codex CLI 执行会话
```

示例（3 项目并行）：
```
hermes-api-gateway-claude    hermes-api-gateway-codex
hermes-web-frontend-claude   hermes-web-frontend-codex
hermes-ml-pipeline-claude    hermes-ml-pipeline-codex
```

### Hermes 多项目调度策略

1. **todo 列表分项目追踪**：每个任务前缀 `[Project Name]`
2. **进程轮询**：`process(action="list")` 查看所有运行中项目
3. **阻塞不卡死**：当项目 A 的 Codex 等待决策时，Hermes 自动切换到项目 B 的任务
4. **消息前缀**：所有用户通知都带 `[Project Name]` 前缀，避免混淆

---

## 五、完整部署步骤（无 sudo Ubuntu）

### Step 0: 前置依赖确认

```bash
# 这些应该已经由你的管理员安装好
git --version       # >= 2.30
node --version      # >= 18
tmux -V             # >= 3.0
python3 --version   # >= 3.10
```

### Step 1: 一键安装

```bash
# 下载本方案包并解压
cd ~/hermes-dev-orchestra

# 运行安装脚本（无需 sudo，全部安装在用户目录）
bash docs/orchestra/scripts/setup.sh
```

setup.sh 会自动完成：
- 检查上游 `hermes` 和 `tmux` 是否已安装
- 提示 `claude` 和 `codex` CLI 是否可用，但不安装或更新它们
- setup.sh installs Dev Orchestra SOUL、4 个自定义 Skills、4 层目录根、Claude hooks 模板、默认 `rules.json` 和 `orch-*` helper
- 创建目录结构 `/tmp/hermes-orchestra/`、`~/.local/state/hermes-orchestra/`、`~/.local/share/hermes-orchestra/`、`~/.cache/hermes-orchestra/` 和 `~/.hermes-orchestra/`
- 将 4 个自定义 Skills 安装到上游 layout：`~/.hermes/skills/{skill-name}/`
- 备份并安装 SOUL.md 到上游读取路径：`~/.hermes/SOUL.md`
- 安装 PATH helper：`orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-risk-check`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, `orch-verify`

### Step 2: 配置 API Key 和认证

```bash
# 编辑 Hermes 环境变量
nano ~/.hermes/.env

# 添加以下内容：
OPENROUTER_API_KEY=sk-or-xxx           # Hermes 使用的 LLM
OPENAI_API_KEY=sk-xxx                  # Codex CLI 使用
ANTHROPIC_API_KEY=sk-ant-oat01-xxx     # Claude Code CLI 使用 (OAuth Token)

# Claude Code 首次认证（必须手动跑一次）
claude auth

# Codex CLI 首次认证
codex login
```

> ⚠️ **2026.4 重要更新**：Claude Code CLI 不再支持 raw API key (`sk-ant-api03-*`)，必须使用 Claude Max 订阅的 **OAuth Token** (`sk-ant-oat01-*`)，有效期 1 年。

### Step 3: 配置 Remote Decision Channel（可选）

v1 将远程决策通道保持为抽象接口，不绑定 Telegram、Discord、webhook 或任何具体传输。远程通道未配置时，本地 SSH/file fallback 使用 `orch-decisions`、`orch-approve <approval_id>`、`orch-reject <approval_id>` 处理用户 approve/reject；modify 在当前里程碑中建模为 reject 后提交修订任务。

需要保证的行为只有：
- L1/L2 可以异步通知用户
- L3/L4 必须阻塞直到用户明确批准或拒绝
- 所有用户决策必须写入 `~/.local/share/hermes-orchestra/{project}/audit.jsonl`

本地决策命令：

```bash
orch-decisions
orch-approve <approval_id>
orch-reject <approval_id>
orch-audit <project-id> --limit 20
```

### Step 4: 初始化你的项目

```bash
# 项目 A：后端 API
orch-init api-gateway ~/projects/api-gateway

# 项目 B：前端
touch ~/projects/web-frontend/.gitkeep  # 确保目录存在
orch-init web-frontend ~/projects/web-frontend

# 项目 C：ML 管道
orch-init ml-pipeline ~/projects/ml-pipeline
```

`orch-init` 会：
1. 确保项目是 git 仓库（Codex 强制要求）
2. 创建独立的 Runtime/State/Audit/Cache per-project 目录
3. 在 State 中写入 `project.env`、`paths.json`、`current-task.json`，并在 `projects.json` 注册项目
4. 复制 Claude Code `settings.json`（含 Hooks 配置）到项目目录（若项目尚未配置）

### Step 5: 启动编排会话

```bash
# 启动项目 A 的 Claude + Codex 进程对
orch-start api-gateway ~/projects/api-gateway

# 启动项目 B
orch-start web-frontend ~/projects/web-frontend

# 启动项目 C
orch-start ml-pipeline ~/projects/ml-pipeline

# 查看所有状态
orch-status
```

`orch-start` 会启动或复用两个 tmux shell 会话（`hermes-<project>-claude`、`hermes-<project>-codex`），并启动一个 per-project internal watcher。watcher 负责扫描 Runtime bus、派发 `task.md`、转发 Claude/Codex 文件并记录 State。

### Step 6: 启动 Hermes 主控

```bash
# SSH 到 Ubuntu 后启动 Hermes CLI
hermes chat

# 在 Hermes 中激活编排技能
/dev-orchestra

# 或直接在启动时指定任务
hermes chat -q "管理 api-gateway 项目：实现 JWT 认证中间件"
```

---

## 六、日常使用示例

文件名保留 `.md` 兼容命名，但内容使用 canonical JSON envelopes：`task.md`、`codex-question.md`、`claude-decision.md`、`codex-result.md`、`review-result.md` 都应包含 `schema_version`、`project_id`、`task_id`、`correlation_id`、`status`、`author`、`authority`、`timestamp` 等字段。

### 示例 1：单项目开发任务

```
用户 (SSH): "在 api-gateway 项目里实现用户注册 API"

Hermes:
  1. todo 添加任务 [api-gateway] 实现用户注册 API
  2. 检查 hermes-api-gateway-claude 和 hermes-api-gateway-codex 是否在运行
  3. 写入 /tmp/hermes-orchestra/api-gateway/task.md JSON envelope
  4. internal watcher 将 task.md 派发给 Codex tmux
  5. orch-status api-gateway 查看阶段、结果和审查状态

Codex 执行中:
  - 读取 task.md JSON envelope
  - 开始实现代码
  - 发现："应该用 bcrypt 还是 argon2 做密码哈希？"
  - 写入 codex-question.md JSON envelope，暂停执行

Hermes 检测到 codex-question.md:
  1. 读取问题
  2. watcher 转发给 Claude Code tmux
  3. Claude 写入 claude-decision.md JSON envelope
  4. watcher 用新的 codex exec 注入 task + decision 继续执行

Codex 继续执行:
  - 完成实现
  - 写入 codex-result.md
  - watcher 转发给 Claude review，生成 review-result.md
  - Hermes 汇总带 [api-gateway] 前缀的结果
  - todo 标记完成
```

### 示例 2：危险操作升级

```
Codex 执行中需要修改数据库认证表结构
→ 涉及现有用户数据

Claude Code 检测到风险:
  - 在 review 中标记："此 ALTER TABLE 可能使现有 JWT token 失效"
  - 写入 escalation.md（L3 危险级别）

Hermes 检测到 escalation.md:
  1. 读取内容，确认是 L3
  2. 立即停止该项目的 Codex 执行
  3. 通过 Remote Decision Channel 抽象或 SSH 端 clarify() 向用户显示：
     "【api-gateway】Codex 需要修改 auth_sessions 表结构，
      这将使所有现有 JWT token 失效，已登录用户会被登出。
      选项：A) 批准 B) 拒绝 C) 修改方案"

用户回复 "C) 修改方案 - 先创建新表做双写，再灰度迁移"

Hermes:
  1. 记录审计日志到 ~/.local/share/hermes-orchestra/{project}/audit.jsonl
  2. 将用户决策写入 claude-decision.md
  3. 通知 Claude Code 更新方案
  4. Claude 更新决策后，Codex 按新方案继续执行
```

### 示例 3：多项目并行

```
用户: "同时处理三个任务：
  1. api-gateway: 修复登录 Bug
  2. web-frontend: 添加响应式布局
  3. ml-pipeline: 更新数据预处理脚本"

Hermes:
  todo:
    [api-gateway] 修复登录 Bug — in_progress
    [web-frontend] 添加响应式布局 — in_progress
    [ml-pipeline] 更新数据预处理脚本 — in_progress

  三个项目同时有活跃的 Claude + Codex 进程
  Hermes 轮询每个项目的状态文件
  
  当 web-frontend 的 Codex 等待 Claude 决策时，
  Hermes 不阻塞，继续处理 ml-pipeline 的新输出
  
  所有结果分别汇总，带 [Project Name] 前缀报告给用户
```

---

## 七、关键配置文件详解

### 1. Hermes SOUL.md (`~/.hermes/SOUL.md`)

定义 Hermes 的核心人格：
- 你是管理者，不是编码者
- 信任 Claude 的技术决策
- 只在危险/产品级问题上升级用户
- 多项目并行时保持上下文隔离

### 2. Claude Code settings.json (per-project `.claude/settings.json`)

配置 Hooks，将权限请求和通知写入事件文件：

```json
{
  "hooks": {
    "PermissionRequest": {
      "command": ["bash", "-c", "echo event_json >> /tmp/hermes-orchestra/claude-events.jsonl"]
    },
    "Notification": {
      "command": ["bash", "-c", "echo event_json >> /tmp/hermes-orchestra/claude-events.jsonl"]
    }
  },
  "permissionMode": "autoEdit"
}
```

`permissionMode: autoEdit` 表示 Claude 自动批准文件编辑，但仍会对高风险操作弹出权限请求（被 Hooks 捕获）。

### 3. 4 个自定义 Skills

| Skill | 用途 | 触发方式 |
|-------|------|---------|
| `dev-orchestra` | 主编排技能，定义完整工作流 | `/dev-orchestra` |
| `claude-supervisor` | 定义 Claude Code 的监督者角色 | 被 dev-orchestra 调用 |
| `codex-executor` | 定义 Codex 的执行者角色 | 被 dev-orchestra 调用 |
| `escalation-handler` | 处理危险升级请求 | 检测到 escalation.md 时自动 |

---

## 八、进程管理速查表

```bash
# 手工验证
hermes --version
hermes skills list
orch-verify
orch-risk-check "docker system prune"
orch-decisions
orch-status <project-id>

# 查看所有 orchestra 进程
orch-status
# 或 tmux ls | grep hermes-

# 连接到监督会话查看 Claude 状态
tmux attach -t hermes-api-gateway-claude
# 按 Ctrl+B 再按 D 退出（不终止会话）

# 连接到执行会话查看 Codex 状态
tmux attach -t hermes-api-gateway-codex

# 查看项目通信文件
ls -lt /tmp/hermes-orchestra/api-gateway/
cat /tmp/hermes-orchestra/api-gateway/codex-result.md

# 手动向 Codex 发送指令
tmux send-keys -t hermes-api-gateway-codex 'cat /tmp/hermes-orchestra/api-gateway/task.md | codex exec --full-auto --json --output-last-message /tmp/hermes-orchestra/api-gateway/codex-result.md -' Enter

# 停止项目
orch-stop api-gateway

# 查看 Hermes 日志
journalctl --user -u hermes-gateway -f
```

---

## 九、故障排查

项目卡住时，先运行 `orch-status <project-id>`。它会显示 Runtime/State/Audit 路径、watcher PID、tmux session、bus 文件、最后 Codex 结果、最后 review 决策和 escalation 状态。

| 问题 | 原因 | 解决 |
|------|------|------|
| 项目卡住 | watcher、tmux 或 bus 文件状态未知 | 先运行 `orch-status <project-id>`，再查看 `~/.local/state/hermes-orchestra/<project>/orch-bus-loop.log` |
| Codex 拒绝执行 | 目录不是 git 仓库 | `git init && git add . && git commit -m init` |
| Codex 卡住无输出 | 缺少 PTY | 确保用 tmux 启动，或使用 `codex exec` 而非交互式 `codex` |
| Claude 审批弹窗阻断 | Hook 未生效 | 检查 `.claude/settings.json` 是否存在且格式正确 |
| Hermes 收不到远程决策回复 | Remote Decision Channel 未配置或不可达 | 检查所选通道配置，并确认 L3/L4 可回写用户决策 |
| tmux 会话丢失 | SSH 断开 | tmux 会话默认保留，用 `tmux ls` 查看并 `tmux attach` |
| 权限被拒绝 | 无 sudo | 所有安装都在 `$HOME/.local/` 和 `$HOME/.hermes/`，无需 sudo |
| Codex 输出被截断 | 超过 200KB 缓冲区 | 使用 `--json` 过滤，或拆分任务为更小的子任务 |

---

## 十、2026年4月最新特性利用

### Hermes Agent v0.11.0 baseline
- ✅ **Pinned upstream**: `NousResearch/hermes-agent` commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`
- ✅ **Nous Tool Gateway**: 付费订阅者可使用 Firecrawl 搜索、FLUX 2 图像生成、Browser Use 自动化
- ✅ **notification_hook / notify**: 可选地写入 `.codex-done` 加速 watcher 扫描；正确性仍以文件轮询、进程检查和 `codex-result.md` 为准
- ✅ **process registry 持久化**: `~/.hermes/processes.json` 崩溃恢复

### Claude Code CLI (2026.4)
- ✅ **22 个 Hook 生命周期事件**: `PermissionRequest`, `Notification`, `Stop` 等
- ✅ **Print 模式 `-p`**: 单查询后退出，适合脚本化调用
- ✅ **`--bare` 模式**: 跳过 hooks/LSP/plugins，纯脚本执行

### Codex CLI v0.122.0 (2026.4.22)
- ✅ **`codex exec --ignore-user-config`**: 完全隔离的自动化运行
- ✅ **`--json`**: JSON Lines 输出，便于程序解析
- ✅ **`--output-last-message`**: 将最终结果写入 `codex-result.md`，供 watcher 和 Claude review 消费
- ✅ **Memory mode controls**: TUI 中控制记忆模式

---

## 十一、安全最佳实践

1. **审计日志不可删**: `~/.local/share/hermes-orchestra/{project}/audit.jsonl` 是 durable JSONL 记录，应纳入后续备份/留存策略
2. **git 是底线**: 任何危险操作前，Hermes 自动执行 `git stash` 或 `git branch backup-{timestamp}`
3. **L3-L4 绝不自动**: 任何标记为 DANGER/CRITICAL 的操作，必须用户明确输入 "批准"
4. **API Key 隔离**: Claude Code 用 Anthropic OAuth，Codex 用 OpenAI Key，Hermes 用 OpenRouter，互不混用
5. **tmux 会话分离**: 不同项目的会话相互隔离，防止交叉污染

---

## 十二、扩展路线

| 阶段 | 扩展内容 | 收益 |
|------|---------|------|
| 当前 | 基础三层编排 | 单人管多项目 |
| +1 | 接入 `ai-cli-mcp` | 任何 MCP 客户端可调用（Cursor/Claude Desktop） |
| +2 | 启用 Claude Code Agent Teams | 单个项目内多 Claude 协作（实验性） |
| +3 | Hermes cronjob 定时任务 | 自动化 nightly build / 日报生成 |
| +4 | 接入 GitHub MCP | PR review、issue 管理自动化 |
| +5 | 部署到 Modal/容器沙箱 | Codex 在隔离容器中执行，更安全 |

---

## Current Handoff Order

覆盖矩阵见 `docs/COVERAGE-MATRIX.md`。

1. Remote adapter identity/replay/delivery
2. Audit hardening: retention, backup, and tamper evidence
3. Isolation hardening: container, worktree, and sandbox boundaries
4. Optional product extensions: gbrain, dashboard, and team approvals

---

**Happy Orchestrating! 🎼**
