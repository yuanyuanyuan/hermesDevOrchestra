# Getting Started

> **本文档假设你已经完成 [`INSTALL.md`](INSTALL.md) 中的全部前置安装。**
>
> 我们将带你从 `orch-init` 开始，到成功提交第一个编排任务。

---

## 第一步：初始化第一个项目

Orchestra 只管理**已经是 git 仓库**的项目。

### 使用现有项目

```bash
cd ~/projects/my-app
git status   # 确认是 git 仓库

orch-init my-app ~/projects/my-app
```

### 或创建一个新项目

```bash
mkdir -p ~/projects/my-app
cd ~/projects/my-app
git init
echo "# My App" > README.md
git add . && git commit -m "init"

orch-init my-app ~/projects/my-app
```

### 预期输出

```
[INFO] Registering project my-app...
[INFO] Project runtime directory: /tmp/hermes-orchestra/my-app
[OK] Project initialized: my-app
```

**`orch-init` 做了什么？**

1. 验证项目目录是 git 仓库
2. 创建该项目的运行时目录结构（`/tmp/hermes-orchestra/my-app/` 等）
3. 将项目注册到全局项目列表
4. 复制 Claude Code `settings.json`（含 Hooks）到项目 `.claude/` 目录
5. 编译角色 profile 到项目级 workspace

---

## 第二步：启动编排会话

```bash
orch-start my-app ~/projects/my-app
```

### 预期输出

```
[INFO] Syncing profiles...
[OK] Profile sync complete
[INFO] Creating tmux sessions...
[OK] tmux session: hermes-my-app-claude
[OK] tmux session: hermes-my-app-codex
[INFO] Starting watcher...
[OK] Watcher started (pid 12345)
[OK] Project my-app orchestration started
```

**`orch-start` 做了什么？**

1. 运行 `orch-profile-sync` 编译 profile catalog
2. 创建两个 tmux 会话：
   - `hermes-my-app-claude` — Claude Code 监督会话
   - `hermes-my-app-codex` — Codex 执行会话
3. 注入环境变量：`HERMES_HOME`、`HERMES_KANBAN_BOARD`、`HERMES_MEMORY_NAMESPACE`
4. 启动 per-project watcher，自动协调 Claude 与 Codex 之间的任务流转

### 验证运行状态

```bash
orch-status
```

**预期输出：**

```
=== Hermes Dev Orchestra Status ===
[my-app] Project: my-app
[my-app] Board: my-app
[my-app] Claude session: hermes-my-app-claude running
[my-app] Codex session: hermes-my-app-codex running
[my-app] Watcher: running pid 12345
[my-app] Runtime: /tmp/hermes-orchestra/my-app
```

如果看到两个 `running`，说明一切正常。

---

## 第三步：提交第一个任务

### 3.1 启动 Hermes 主控

```bash
hermes chat
```

进入 Hermes 交互界面后，激活编排技能：

```
/dev-orchestra
```

你应该会看到 Orchestra 技能加载成功的提示。

### 3.2 用自然语言描述任务

例如：

```
在 my-app 项目里实现用户注册 API，要求用 bcrypt 做密码哈希，返回 JWT token
```

### 3.3 观察任务流转

Hermes 会自动完成以下协作流程：

1. **派发** — Hermes 将任务写入 `task.md`，watcher 派发给 Codex
2. **执行** — Codex 在 `hermes-my-app-codex` tmux 会话中开始编码
3. **提问** — Codex 遇到不确定的问题 → 写入 `codex-question.md` → watcher 转发给 Claude
4. **决策** — Claude 在 `hermes-my-app-claude` 会话中决策 → 写入 `claude-decision.md` → watcher 回传给 Codex
5. **完成** — Codex 完成编码 → 写入 `codex-result.md` → Claude review → `review-result.md`

你可以随时查看任务交换目录中的文件：

```bash
ls -lt /tmp/hermes-orchestra/my-app/
cat /tmp/hermes-orchestra/my-app/codex-result.md
```

---

## 第四步：连接到 tmux 会话查看实时状态

如果你想实时观察 Claude 或 Codex 在做什么：

```bash
# 查看 Claude 监督会话
tmux attach -t hermes-my-app-claude
# 按 Ctrl+B，然后按 D 退出（不终止会话）

# 查看 Codex 执行会话
tmux attach -t hermes-my-app-codex
```

查看所有 tmux 会话：

```bash
tmux ls
```

---

## 第五步：日常管理

### 停止项目

```bash
orch-stop my-app
```

### 查看单个项目详情

```bash
orch-status my-app
```

### 多项目并行（可选）

```bash
orch-init web-frontend ~/projects/web-frontend
orch-start web-frontend ~/projects/web-frontend

orch-init ml-pipeline ~/projects/ml-pipeline
orch-start ml-pipeline ~/projects/ml-pipeline

orch-status
```

---

## 风险管理速览

Orchestra 对危险操作有自动分级拦截：

| 级别 | 行为 | 示例 |
|------|------|------|
| L1 | 仅记录 | session_start |
| L2 | 异步通知 | production migration, rollback plan |
| L3 | 阻塞等待用户批准 | ALTER TABLE, sudo, 修改 .env |
| L4 | 需输入固定短语确认 | rm -rf /, DROP DATABASE, force-push main |

日常命令：

```bash
# 预检命令风险
orch-risk-check "docker system prune"

# 查看待审批决策
orch-decisions

# 批准 / 拒绝
orch-approve <approval_id>
orch-reject <approval_id>

# 查看审计日志
orch-audit my-app --limit 20
```

---

## 常见上手问题

### `orch-init` 报 "must be a Git repository"

项目目录必须是 git 仓库：

```bash
cd ~/projects/my-app
git init && git add . && git commit -m "init"
orch-init my-app ~/projects/my-app
```

### `orch-start` 报 "command not found: claude"

Claude Code CLI 未安装或未在 PATH 中。回到 [`INSTALL.md`](INSTALL.md) 检查第二步。

### `hermes chat` 后输入 `/dev-orchestra` 无响应

检查 Skills 是否正确安装：

```bash
ls ~/.hermes/skills/dev-orchestra/SKILL.md
```

如果不存在，重新运行 `bash scripts/setup.sh`。

### Codex 无输出卡住

- 确保 `orch-start` 成功创建了两个 tmux 会话
- 检查 watcher 是否运行：`orch-status`
- Codex 需要 PTY，确保是通过 `orch-start` 启动（它自动处理 tmux 环境）

---

## 下一步阅读

- **[`WORKFLOW.md`](WORKFLOW.md)** — 单人全周期工作流详细指南
- **[`ARCHITECTURE.md`](ARCHITECTURE.md)** — 系统架构与数据流
- **[`CONFIGURATION.md`](CONFIGURATION.md)** — 环境变量与配置详解
- **[`DEVELOPMENT.md`](DEVELOPMENT.md)** — 开发贡献指南
- **[`TESTING.md`](TESTING.md)** — 测试策略与编写规范
- **[`../specs/`](../specs/)** — 命令集、任务交换协议、风险决策规范
