---
name: dev-orchestra
description: 多项目AI开发编排系统：管理Claude Code(决策监督)与Codex(执行)的协作，处理三级决策流转，支持并行多项目开发
version: 2.0.0
metadata:
  hermes:
    tags: [orchestration, claude-code, codex, multi-project, ai-development]
    category: autonomous-ai-agents
    requires_version: ">=0.10.0"
---

# Dev Orchestra Skill

## When to Use

当用户需要同时管理多个项目的AI辅助开发，且要求：
- Hermes 作为顶层编排器
- Claude Code CLI 负责监督、决策和代码审查
- Codex CLI 负责实际编码执行
- 三级决策流转：一般决策(Claude) → 危险决策(Hermes) → 用户确认

## Architecture Overview

```
User (Windows SSH / abstract Remote Decision Channel)
    ↓
Hermes Agent (Ubuntu) —— 顶层编排器
    ├─ todo 管理多项目任务队列
    ├─ memory 持久化项目状态
    ├─ terminal/process 启动/监控子进程
    ├─ clarify/send_message 向用户请求决策
    └─ 共享文件总线 /tmp/hermes-orchestra/{project}/
    ├─ task.md          当前任务
    ├─ codex-question.md   Codex 的疑问
    ├─ claude-decision.md  Claude 的决策
    ├─ escalation.md    升级标记（危险/产品影响）
    └─ codex-result.md     Codex 执行结果
    ↓
Project A: [tmux: hermes-A-claude] ← 文件通信 → [tmux: hermes-A-codex]
Project B: [tmux: hermes-B-claude] ← 文件通信 → [tmux: hermes-B-codex]
Project C: [tmux: hermes-C-claude] ← 文件通信 → [tmux: hermes-C-codex]
```

## Prerequisites

- Hermes Agent >= v0.11.0
- Claude Code CLI >= v2.1.110
- Codex CLI >= v0.122.0 (with `exec --full-auto` support)
- tmux >= 3.0
- Node.js >= 18
- 项目目录均为 git 仓库（Codex CLI 要求）

## Procedure

### Phase 1: 项目初始化

1. 检查项目目录是否存在 `.git`：
   ```bash
   terminal(command="ls -la {project_dir}/.git")
   ```
   如果不存在，初始化 git：
   ```bash
   terminal(command="cd {project_dir} && git init && git add . && git commit -m 'init' || true")
   ```

2. 通过 `orch-init <project-id> <project-dir>` 创建四层项目目录：
   ```bash
   terminal(command="orch-init {project_id} {project_dir}")
   ```

3. 当用户向项目分配任务时，Hermes 写入 Runtime `task.md`。文件名保留 `.md` 兼容命名，内容必须是 JSON envelope，包含 `schema_version`、`message_id`、`project_id`、`task_id`、`correlation_id`、`status`、`author`、`authority`、`timestamp`、`description`、`requirements`、`constraints`、`priority`：
   ```bash
   terminal(command="cat > /tmp/hermes-orchestra/{project_name}/task.md << 'EOF'
{
  \"schema_version\": \"1.0\",
  \"message_id\": \"msg-{uuid}\",
  \"project_id\": \"{project_id}\",
  \"task_id\": \"task-{uuid}\",
  \"correlation_id\": \"corr-{uuid}\",
  \"status\": \"queued\",
  \"author\": \"hermes\",
  \"authority\": \"orchestrator\",
  \"timestamp\": \"{iso8601}\",
  \"description\": \"{task_description}\",
  \"requirements\": [\"{requirement_1}\"],
  \"constraints\": [\"{constraint_1}\"],
  \"priority\": \"normal\"
}
   EOF")
   ```

4. Remote Decision Channel 在 v1 中保持抽象：Hermes 可以通过 SSH/local fallback 或后续适配器通知用户，但不得把 v1 绑定到 Telegram、Discord 或任何具体传输。

### Phase 2: 启动 Claude Code 监督进程

Claude Code 作为监督者，使用 **tmux + PTY 模式** 保持持久会话，通过 Hooks 拦截权限请求并写入 escalation 文件。

```bash
# 启动 tmux 会话运行 Claude Code（监督模式）
terminal(
    command="tmux new-session -d -s hermes-{project}-claude -x 180 -y 40 'cd {project_dir} && claude --permission-mode auto'",
    background=true,
    pty=true,
    notify_on_complete=false,
)
# Returns session_id for the tmux process
```

**关键配置说明：**
- `--permission-mode auto`：Claude Code 自动批准低风险操作，高风险操作触发 PermissionRequest Hook
- 实际生产中推荐配置 `.claude/settings.json` Hooks（见下方附录）

### Phase 3: 启动 Codex 执行进程

Codex 作为执行者，使用 `codex exec --full-auto` 在 tmux 中运行，通过文件与 Claude Code 通信。

```bash
# 启动 tmux 会话运行 Codex（执行模式）
terminal(
    command="tmux new-session -d -s hermes-{project}-codex -x 180 -y 40 'cd {project_dir} && codex exec --full-auto --json'",
    background=true,
    pty=true,
    notify_on_complete=false,
)
```

**关键配置说明：**
- `--full-auto`：Codex 在 workspace-write sandbox 中自动执行，无需交互确认
- `--json`：输出 JSON Lines 格式，便于 Hermes 解析执行结果
- `--ephemeral` 可选：如果不需要持久化 Codex 会话文件

### Phase 4: 任务分发与决策流转

#### 4.1 派发编码任务给 Codex

```bash
# 将 canonical JSON envelope 写入共享文件，watcher 读取并派发给 Codex
terminal(command="cat > /tmp/hermes-orchestra/{project_name}/task.md << 'EOF'
{
  \"schema_version\": \"1.0\",
  \"message_id\": \"msg-{uuid}\",
  \"project_id\": \"{project_id}\",
  \"task_id\": \"task-{uuid}\",
  \"correlation_id\": \"corr-{uuid}\",
  \"status\": \"queued\",
  \"author\": \"hermes\",
  \"authority\": \"orchestrator\",
  \"timestamp\": \"{iso8601}\",
  \"description\": \"{detailed_task}\",
  \"requirements\": [\"{requirement_1}\", \"{requirement_2}\"],
  \"constraints\": [\"仅修改 src/ 目录下的文件\", \"执行前运行 npm test 验证\"],
  \"priority\": \"normal\"
}
EOF")

# internal watcher 派发 task.md 到 Codex tmux：
terminal(command="orch-start {project_id} {project_dir}")
```

#### 4.2 处理 Codex 疑问（一般决策）

Codex 执行中遇到疑问，写入 `codex-question.md`：

```bash
# 监控疑问文件变化
terminal(command="inotifywait -q -e create,modify /tmp/hermes-orchestra/{project_name}/codex-question.md 2>/dev/null || sleep 5")

# 读取 Codex 的疑问
read_file(file_path="/tmp/hermes-orchestra/{project_name}/codex-question.md")

# watcher 转发给 Claude Supervisor，Claude 写入 claude-decision.md JSON envelope
terminal(command="orch-status {project_id}")
```

#### 4.3 危险决策升级（Hermes 介入）

Claude Code 遇到以下情况时，写入 `escalation.md`：
- 涉及系统级操作（rm -rf /, 修改 /etc/）
- 影响产品核心需求或架构方向
- 涉及安全凭证、密钥操作
- 破坏性重构无法自动回滚

```bash
# 监控 escalation 文件
terminal(command="ls -la /tmp/hermes-orchestra/{project_name}/escalation.md")

# 读取升级请求
read_file(file_path="/tmp/hermes-orchestra/{project_name}/escalation.md")
```

Hermes 收到 escalation 后，**使用 `clarify` 工具向用户请求最终决策**：

```
clarify(
    question="【项目 {project_name}】需要您决策：\n\n{escalation_content}\n\n选项：",
    choices=[
        "批准执行 - 我确认了解风险",
        "拒绝 - 保持现状，取消此变更",
        "修改方案 - 让我补充约束条件"
    ]
)
```

如果用户配置了具体 Remote Decision Channel，同时发送消息通知：

```bash
send_message(
    action="send",
    target="{remote-channel}",
    message="【开发警报】项目 {project_name} 需要您的决策：{escalation_summary}\n请通过远程通道或 SSH/local fallback 处理。"
)
```

用户决策后，Hermes 将结果写入 `claude-decision.md`，Claude Code 和 Codex 继续执行。远程通道未配置时使用 `orch-decisions`、`orch-approve <approval_id>`、`orch-reject <approval_id>`；当前里程碑的 `modify` 建模为 `orch-reject <approval_id>` 后提交修订任务。风险与审计 helper 为 `orch-risk-check` 和 `orch-audit`。

### Phase 5: 多项目并行管理

```bash
# 查看所有运行中的项目进程
process(action="list")

# 示例输出解读：
# - proc_xxx: tmux hermes-A-claude → Project A 监督进程
# - proc_yyy: tmux hermes-A-codex  → Project A 执行进程
# - proc_zzz: tmux hermes-B-claude → Project B 监督进程
# - proc_www: tmux hermes-B-codex  → Project B 执行进程
```

#### 并行任务分配策略

```bash
# 项目 A：后端 API 开发
todo(todos=[
    {"id": "A-1", "content": "Project A: 实现用户认证模块", "status": "in_progress", "priority": "high"},
    {"id": "A-2", "content": "Project A: 编写单元测试", "status": "pending", "priority": "high"}
])

# 项目 B：前端组件开发
todo(todos=[
    {"id": "B-1", "content": "Project B: 重构表单组件", "status": "in_progress", "priority": "medium"},
    {"id": "B-2", "content": "Project B: 添加响应式布局", "status": "pending", "priority": "medium"}
])
```

#### 进程监控与健康检查

```bash
# 检查特定项目状态
process(action="poll", session_id="{claude_session_id}")
process(action="poll", session_id="{codex_session_id}")

# 获取完整日志
process(action="log", session_id="{codex_session_id}")

# 如果进程卡死，重启
timeout 600 process(action="wait", session_id="{codex_session_id}") || process(action="kill", session_id="{codex_session_id}")
```

### Phase 6: 会话结束与清理

```bash
# 任务完成后，保存结果并清理
terminal(command="tmux capture-pane -t hermes-{project}-codex -p -S -100 > /tmp/hermes-orchestra/{project_name}/final-log.txt")

# 关闭 tmux 会话
terminal(command="tmux kill-session -t hermes-{project}-claude 2>/dev/null; tmux kill-session -t hermes-{project}-codex 2>/dev/null")

# 归档通信文件
terminal(command="tar czf /tmp/hermes-orchestra/{project_name}-$(date +%Y%m%d-%H%M%S).tar.gz /tmp/hermes-orchestra/{project_name}/")

# 更新 todo 状态
todo(todos=[{"id": "{task_id}", "content": "{task_name}", "status": "completed", "priority": "{priority}"}])
```

## Pitfalls

- **tmux 会话名称冲突**：每个项目必须使用唯一名称 `hermes-{project}-claude` / `hermes-{project}-codex`
- **PTY 模式必需**：Claude Code 和 Codex 都是 TUI 应用，没有 `pty=true` 会卡死
- **git 仓库要求**：Codex CLI 拒绝在非 git 目录执行，临时目录需要先 `git init`
- **权限模式陷阱**：`--dangerously-skip-permissions` 和 `--dangerously-bypass-approvals-and-sandbox` 只在首次手动运行后生效
- **输出缓冲区限制**：`MAX_OUTPUT_CHARS = 200_000`，超出的输出会被截断。对于大项目，使用 `--json` + `jq` 过滤
- **内存泄漏**：长时间运行的 tmux 会话可能积累大量输出，定期 `process(action="poll")` 清理缓冲区
- **SSH 断开**：tmux 会话在 SSH 断开后保持运行，但 Hermes gateway 进程需要 `loginctl enable-linger $USER`
- **Claude Code OAuth 要求**：Claude Code CLI 不再支持 raw API key，必须使用 OAuth Token（`sk-ant-oat01-*`）

## Verification

运行以下验证命令确认系统就绪：

```bash
terminal(command="hermes doctor && claude --version && codex --version && tmux -V && node --version")
```

预期输出：
- `hermes v0.11.0` 或更高
- `claude` 版本 >= 2.1.110
- `codex` 版本 >= 0.122.0
- `tmux` 版本 >= 3.0
- `node` 版本 >= 18

## Appendix A: Claude Code Hooks 配置（推荐生产环境）

在 `{project_dir}/.claude/settings.json` 中配置 Hooks：

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"
  },
  "hooks": {
    "PermissionRequest": [
      {
        "type": "command",
        "command": ["bash", "/tmp/hermes-orchestra/permission-hook.sh"],
        "matchers": ["Bash", "Edit", "Write"]
      }
    ],
    "Notification": [
      {
        "type": "command",
        "command": ["bash", "/tmp/hermes-orchestra/notify-hook.sh"]
      }
    ]
  }
}
```

## Appendix B: 快速决策矩阵

| 决策类型 | 处理方式 | 响应时间 |
|---------|---------|---------|
| 代码实现细节选择 | Claude Code 直接决策 | 秒级 |
| API 设计/架构调整 | Claude Code 决策，Hermes 记录 | 秒级 |
| 涉及安全/权限操作 | Hermes 标记 + 用户确认 | 分钟级 |
| 产品需求变更 | Hermes 升级 + 用户决策 | 分钟-小时级 |
| 破坏性重构 | Hermes 升级 + 用户确认 + git 备份 | 分钟级 |

## Appendix C: 与 `ai-cli-mcp` 集成（可选高级方案）

如果需要在 MCP 客户端中调用此编排系统，可部署 `ai-cli-mcp`（v2026.4.19）：

```bash
npm install -g ai-cli-mcp
# 配置后可通过 MCP 工具调用：
# - acm_run(claude, "sonnet", task, project_dir)
# - acm_run(codex, "gpt-5.3-codex", task, project_dir)
# - acm_peek() 查看所有运行中进程
```

此方案将 Claude Code 和 Codex 封装为 MCP Server，任何 MCP 客户端（Cursor、Claude Desktop、Windsurf）均可调用。
