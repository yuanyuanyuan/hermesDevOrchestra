# Hermes Dev Orchestra 用户使用手册

> 版本: 1.0 | 基于 PRD 合规审计 v1 | 合规率: 90.3%

---

## 1. 开始之前：环境准备和安装验证

嘿，欢迎。这是一份"老手带新手"风格的 SOP 手册——我不会跟你讲架构哲学，而是告诉你敲什么命令、看到什么输出、出了问题怎么办。

### 1.1 你需要什么

Hermes Dev Orchestra 是一个**编排适配层**，它不自带 LLM，而是协调三个外部工具一起干活。所以下面这些东西你得先装好：

| 工具 | 最低版本 | 干什么用的 | 验证命令 |
|------|---------|-----------|---------|
| git | >= 2.30 | 版本控制（Codex 硬性要求） | `git --version` |
| node | >= 18 | 运行 CLI 工具 | `node --version` |
| tmux | >= 3.0 | 维持 Claude/Codex 持久会话 | `tmux -V` |
| python3 | >= 3.10 | Gateway 辅助脚本 | `python3 --version` |
| Hermes Agent | >= 0.11.0 | 顶层编排器 | `hermes --version` |
| Claude Code CLI | >= 2.1.110 | 监督者（审查、决策） | `claude --version` |
| Codex CLI | >= 0.122.0 | 执行者（写代码） | `codex --version` |

**整体耗时**：如果已经有 API Key 和订阅账号，约 15-20 分钟；需要注册的话 30-60 分钟。

### 1.2 一键自检

别猜，先跑自检脚本：

```bash
bash scripts/check-prerequisites.sh
```

它会用彩色输出告诉你：哪些已就绪、哪些缺 API Key、哪些没装。**如果全绿，直接跳到 1.4。**

### 1.3 安装缺失依赖

#### 基础工具

```bash
# Ubuntu/Debian
apt install git tmux
# macOS
brew install git tmux
# Node.js 推荐用 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install 20
```

#### 上游 CLI

```bash
# Hermes Agent
git clone https://github.com/NousResearch/hermes-agent.git ~/.hermes/hermes-agent
cd ~/.hermes/hermes-agent
git checkout 023b1bff11c2a01a435f1956a0e2ac1773a065f3
# 按上游文档完成安装

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
claude auth   # 必须用 OAuth Token，不支持 raw API key

# Codex CLI
npm install -g @openai/codex
codex login   # 需要 OpenAI API Key
```

> **重要**：Claude Code CLI 自 2026.4 起必须使用 OAuth Token（`sk-ant-oat01-*`），raw API key（`sk-ant-api03-*`）已失效。

#### API Key 配置

如果你用的是本地 CLI 各自已登录的模式，Orchestra 不强制要求在 `.env` 里重复配置。但如果你想完整配置：

```bash
mkdir -p ~/.hermes
cat >> ~/.hermes/.env << 'EOF'
OPENROUTER_API_KEY=sk-or-xxx
OPENAI_API_KEY=sk-xxx
ANTHROPIC_API_KEY=sk-ant-oat01-xxx
EOF
```

把 `xxx` 替换为你的真实 Key。

### 1.4 安装 Orchestra 本体

```bash
cd /path/to/hermes   # 仓库根目录
bash scripts/setup.sh
```

`setup.sh` 做的事：
1. 检查 `hermes`、`tmux` 是否存在（必须）
2. 安装 SOUL.md 到 `~/.hermes/`
3. 安装 4 个 Skills 到 `~/.hermes/skills/`
4. 安装 CLI 工具（`orch-*`）到 `~/.local/bin/`
5. 安装 Gateway/helper 库、配置模板、风险策略
6. 创建运行时目录

成功后你会看到：

```
========================================
 Setup Complete!
========================================

Installed:
  SOUL:       /home/you/.hermes/SOUL.md
  Skills:     /home/you/.hermes/skills/{dev-orchestra,claude-supervisor,codex-executor,escalation-handler}
  Helpers:    /home/you/.local/bin/orch-*
```

### 1.5 确认 PATH

```bash
which orch-init
```

如果找不到：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 1.6 最终验证

```bash
orch-verify          # 冒烟测试
# 或者完整测试
make test            # smoke + risk + JSON lint + Shell lint + upstream advisory
```

全部通过？恭喜，环境就绪。往下走。

---

## 2. 初始化项目：orch-init 的完整交互流程

### 2.1 前提

Orchestra 只管理**已经是 git 仓库**的项目。如果你的项目还没有 git：

```bash
cd ~/projects/my-app
git init
echo "# My App" > README.md
git add . && git commit -m "init"
```

### 2.2 执行初始化

```bash
orch-init my-app ~/projects/my-app
```

**预期输出：**

```
[INFO] Registering project my-app...
[INFO] Project runtime directory: /tmp/hermes-orchestra/my-app
[OK] Project initialized: my-app
```

**它背后做了什么？**

1. 验证项目目录是 git 仓库
2. 创建运行时目录结构（`/tmp/hermes-orchestra/my-app/`）
3. 将项目注册到全局项目列表
4. 复制 Claude Code `settings.json`（含 Hooks）到项目 `.claude/`
5. 编译角色 profile 到项目级 workspace

### 2.3 一键引导安装（可选）

如果你不想手动一步步来，可以用 MVP 向导：

```bash
orch-mvp-wizard --project-id my-app --project-dir ~/projects/my-app
```

这个向导会自动完成：安装、配置、启动 Gateway/编排会话、运行 MVP 验收测试。验收完成后会生成：

- `~/.local/state/hermes-orchestra/my-app/mvp-demo-flow.json`：结构化总览
- `~/.local/state/hermes-orchestra/my-app/mvp-demo-log.jsonl`：逐步日志

可选参数：
- `--skip-tests`：只配置/启动，不跑测试
- `--skip-demo`：跳过 demo run
- `--real-worker-demo`：用真实 Codex/Claude CLI worker 做验收
- `--yes`：无人值守模式

### 2.4 多项目初始化

每个项目独立初始化，互不影响：

```bash
orch-init api-gateway ~/projects/api-gateway
orch-init web-frontend ~/projects/web-frontend
orch-init ml-pipeline ~/projects/ml-pipeline
```

---

## 3. 提交开发任务

### 3.1 启动编排会话

```bash
orch-start my-app ~/projects/my-app
```

**预期输出：**

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

**它做了什么？**

1. 运行 `orch-profile-sync` 编译 profile catalog
2. 创建两个 tmux 会话：
   - `hermes-my-app-claude` — Claude Code 监督会话
   - `hermes-my-app-codex` — Codex 执行会话
3. 注入环境变量（`HERMES_HOME`、`HERMES_KANBAN_BOARD`、`HERMES_MEMORY_NAMESPACE`）
4. 启动 per-project watcher，自动协调任务流转

### 3.2 用自然语言提交任务

```bash
hermes chat
```

进入 Hermes 交互界面后，激活编排技能：

```
/dev-orchestra
```

然后用自然语言描述你的任务。例如：

```
在 my-app 项目里实现用户注册 API，要求用 bcrypt 做密码哈希，返回 JWT token
```

### 3.3 简化工作流：6 命令速通

如果你不想手动管理每个阶段，`hermes-gsd` 技能把 60+ 个 GSD 命令压缩为 6 个：

| 命令 | 一句话说明 | 记忆口诀 |
|------|-----------|---------|
| `/dev start "描述"` | 开始一个新功能 | 开始 |
| `/dev do` | 执行当前阶段 | 做 |
| `/dev review` | 多模型审查代码 | 审 |
| `/dev next` | 自动推进下一步 | 继续 |
| `/dev status` | 查看项目状态 | 状态 |
| `/dev ship` | 发布当前阶段 | 发布 |

**完整示例：添加用户认证模块**

```
用户: /dev start "添加用户认证模块（JWT + OAuth2）"
→ 系统自动：检测状态 → 定位 phase → 讨论 → 计划 → Codex 审查计划 → 输出 PLAN.md

用户: /dev do
→ 系统自动：执行阶段 → 代码审查 → Codex 审查代码 → 验证工作 → 输出代码 + UAT.md

用户: /dev review
→ 系统自动：深度代码审查 → 多模型审查 → 合并结果到 REVIEWS.md

用户: /dev ship
→ 系统自动：最终验证 → 创建 PR → 里程碑审计
```

每个命令执行后，系统会自动检查上下文使用率。如果超过 70%，会自动暂停并提示你退出后重新进入，执行 `/dev next` 继续。

---

## 4. 观察执行：tmux 会话监控

### 4.1 查看项目状态

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

两个 `running` = 一切正常。

查看单个项目详情：

```bash
orch-status my-app
```

### 4.2 实时观察 Claude/Codex

```bash
# 查看 Claude 监督会话
tmux attach -t hermes-my-app-claude
# 按 Ctrl+B，然后按 D 退出（不终止会话）

# 查看 Codex 执行会话
tmux attach -t hermes-my-app-codex

# 查看所有 tmux 会话
tmux ls
```

### 4.3 查看任务交换文件

任务流转通过文件进行，你可以随时查看：

```bash
# 查看运行时目录
ls -lt /tmp/hermes-orchestra/my-app/

# 查看 Codex 执行结果
cat /tmp/hermes-orchestra/my-app/codex-result.md

# 查看 Claude 审查结果
cat /tmp/hermes-orchestra/my-app/review-result.md

# 查看 Codex 的疑问
cat /tmp/hermes-orchestra/my-app/codex-question.md
```

### 4.4 文件交换时序

正常流转是这样的：

```
1. Hermes → task.md              （写入任务）
2. Codex → codex-question.md     （有疑问时写入）
3. Claude → claude-decision.md   （决策回复）
4. Codex → codex-result.md       （执行完成，输出结果）
5. Claude → review-result.md     （审查意见）
6. (如有) Claude → escalation.md （升级到用户）
```

---

## 5. 处理审批请求

### 5.1 风险等级说明

Orchestra 对危险操作有四级拦截：

| 等级 | 标识 | 含义 | 示例 | 行为 |
|------|------|------|------|------|
| L1 | Notice | 注意 | session_start | 仅记录 |
| L2 | Warning | 警告 | production migration, rollback plan | 异步通知 |
| L3 | Danger | 危险 | ALTER TABLE, sudo, 修改 .env | **阻塞等待用户批准** |
| L4 | Critical | 紧急 | rm -rf /, DROP DATABASE, force-push main | **阻塞，需输入固定短语确认** |

### 5.2 预检命令风险

在执行前可以先查风险等级：

```bash
orch-risk-check "docker system prune"
```

### 5.3 查看待审批决策

```bash
orch-decisions
```

### 5.4 批准或拒绝

```bash
# 批准
orch-approve <approval_id>

# 拒绝
orch-reject <approval_id>
```

L4 操作需要输入固定短语确认，格式为：`APPROVE-L4 <approval_id>`

### 5.5 超时策略

- L1：30 分钟后默认批准
- L2：15 分钟后提醒一次，30 分钟后默认拒绝
- L3/L4：阻塞直到响应，不自动处理

---

## 6. 查看执行结果

### 6.1 codex-result.md 解读

Codex 完成任务后会写入 `codex-result.md`，结构如下：

```json
{
  "status": "completed",
  "body": {
    "summary": "做了什么",
    "files_modified": [{"path": "src/auth.js", "change": "描述"}],
    "tests": {"status": "PASSED", "commands": ["npm test"]},
    "known_issues": [],
    "next_steps": ["建议的下一步"]
  }
}
```

**关注字段：**
- `status`：`completed` 表示正常完成，`question` 表示有疑问需要决策
- `tests.status`：`PASSED` 才算通过，`FAILED` 需要排查
- `files_modified`：改了哪些文件，方便 review
- `known_issues`：已知但未解决的问题

### 6.2 review-result.md 解读

Claude 审查后会写入 `review-result.md`：

```json
{
  "decision": "APPROVED",
  "rationale": "审查理由",
  "body": {
    "findings": [],
    "required_changes": []
  }
}
```

**`decision` 取值：**
- `APPROVED`：通过，可以提交
- `REJECTED`：拒绝，需要重做
- `NEEDS_MODIFICATION`：需要修改，看 `required_changes`

### 6.3 查看审计日志

```bash
orch-audit my-app --limit 20
```

审计日志位于 `~/.local/share/hermes-orchestra/my-app/audit.jsonl`，每行记录一次操作的完整信息：时间、类型、决策、用户操作等。

---

## 7. 提交代码：git 操作和测试验证

### 7.1 运行测试

```bash
# 完整测试套件（smoke + risk + JSON lint + Shell lint + upstream advisory）
make test

# 只跑单元测试
make test-unit

# 只跑风险相关测试
make test-risk
```

### 7.2 Git 操作

Codex 修改的代码在你的项目目录里，你可以正常 git 操作：

```bash
cd ~/projects/my-app
git status
git diff
git add .
git commit -m "feat: 用户注册 API (bcrypt + JWT)"
```

### 7.3 停止项目

任务完成后，停止编排会话：

```bash
orch-stop my-app
```

这会关闭 tmux 会话和 watcher 进程。你的代码和审计日志不会丢失。

---

## 8. 常见问题与调试

### 8.1 安装类问题

| 问题 | 诊断步骤 | 解决方案 |
|------|---------|---------|
| `setup.sh` 报 "Hermes Agent not found" | 运行 `which hermes` | 确认 Hermes Agent 已安装并在 PATH 中 |
| `setup.sh` 报 "tmux is required" | 运行 `tmux -V` | `apt install tmux` 或 `brew install tmux` |
| `orch-*` 命令找不到 | 运行 `echo $PATH \| grep .local/bin` | `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc` |
| `claude auth` 失败 | 检查使用的 key 格式 | 必须用 OAuth Token（`sk-ant-oat01-*`），不支持 raw API key |
| `make upstream-status` 显示 mismatch | Hermes Agent 版本不一致 | `cd ~/.hermes/hermes-agent && git checkout 023b1bff11c2a01a435f1956a0e2ac1773a065f3` |

### 8.2 任务执行类问题

| 问题 | 诊断步骤 | 解决方案 |
|------|---------|---------|
| `orch-init` 报 "must be a Git repository" | `ls -la {project_dir}/.git` | `cd {project_dir} && git init && git add . && git commit -m "init"` |
| Codex 无输出卡住 | `orch-status` 检查 watcher 是否运行 | 确保通过 `orch-start` 启动（它自动处理 tmux 环境） |
| Codex 报 "not a git repository" | `git rev-parse --git-dir` 在项目目录执行 | `git init && git add . && git commit -m "init"` |
| `hermes chat` 后 `/dev-orchestra` 无响应 | `ls ~/.hermes/skills/dev-orchestra/SKILL.md` | 重新运行 `bash scripts/setup.sh` |
| `/dev start` 无响应 | 检查 GSD 是否安装 | `npx get-shit-done-cc@latest --claude --global` |

### 8.3 审批类问题

| 问题 | 诊断步骤 | 解决方案 |
|------|---------|---------|
| `orch-decisions` 无输出 | 检查运行时目录是否存在 escalation 文件 | `ls /tmp/hermes-orchestra/{project}/escalation.md` |
| L3/L4 操作一直阻塞 | 检查是否有待审批项 | `orch-decisions` 查看，然后 `orch-approve <id>` |
| L4 短语确认失败 | 检查短语格式 | 必须精确输入 `APPROVE-L4 <approval_id>` |
| Claude 自行批准了危险操作 | 检查 settings.json 配置 | 不要使用 `--dangerously-skip-permissions` |

### 8.4 性能类问题

| 问题 | 诊断步骤 | 解决方案 |
|------|---------|---------|
| 上下文频繁满载 | `/gsd-health --context` | 降低阶段粒度：每个阶段只做一件事；配置 `"workflow.research": false` |
| tmux 会话内存泄漏 | `tmux list-panes -t hermes-{project}-codex -F "#{pane_pid} #{pane_current_command}"` | 定期 `orch-stop` 再 `orch-start` 重启会话 |
| `/dev next` 卡住 | `/gsd-progress` 查看详细状态 | 手动指定下一步：`/gsd-execute-phase N` 或 `/gsd-verify-work N` |
| SSH 断开后任务丢失 | 检查 tmux 会话是否存活 | `loginctl enable-linger $USER` 保持用户会话 |
| Codex Review 未触发 | `which codex && codex --version` | 手动触发：`/gsd-review --phase N --codex` |

---

## 9. 命令速查表

### 9.1 项目管理

| 命令 | 说明 |
|------|------|
| `orch-init <id> <dir>` | 初始化项目 |
| `orch-start <id> <dir>` | 启动编排会话 |
| `orch-stop <id>` | 停止编排会话 |
| `orch-status` | 查看所有项目状态 |
| `orch-status <id>` | 查看单个项目详情 |

### 9.2 审批与风险

| 命令 | 说明 |
|------|------|
| `orch-decisions` | 查看待审批决策列表 |
| `orch-approve <id>` | 批准决策 |
| `orch-reject <id>` | 拒绝决策 |
| `orch-risk-check "命令"` | 预检命令风险等级 |

### 9.3 审计与验证

| 命令 | 说明 |
|------|------|
| `orch-audit <id> --limit N` | 查看最近 N 条审计日志 |
| `orch-verify` | 运行冒烟测试 |
| `make test` | 运行完整测试套件 |
| `make test-unit` | 只跑单元测试 |
| `make test-risk` | 只跑风险测试 |

### 9.4 引导与配置

| 命令 | 说明 |
|------|------|
| `orch-mvp-wizard --project-id <id> --project-dir <dir>` | 一键引导安装/配置/启动/验收 |
| `orch-profile-sync` | 编译 profile catalog |
| `orch-doctor` | 诊断安装和配置问题 |

### 9.5 GSD 简化命令（在 hermes chat 中使用）

| 命令 | 说明 |
|------|------|
| `/dev start "描述"` | 开始新功能 |
| `/dev do` | 执行当前阶段 |
| `/dev review` | 多模型审查 |
| `/dev next` | 推进下一步 |
| `/dev status` | 查看状态 |
| `/dev ship` | 发布当前阶段 |

### 9.6 tmux 操作

| 命令 | 说明 |
|------|------|
| `tmux ls` | 列出所有 tmux 会话 |
| `tmux attach -t hermes-<id>-claude` | 连接 Claude 监督会话 |
| `tmux attach -t hermes-<id>-codex` | 连接 Codex 执行会话 |
| `Ctrl+B, D` | 从 tmux 会话中退出（不终止） |

---

## 10. 附录

### 10.1 完整任务流转示例

假设你要在 `my-app` 项目里实现一个用户注册 API。完整流程：

```bash
# Step 1: 初始化项目
cd ~/projects/my-app
git status   # 确认是 git 仓库
orch-init my-app ~/projects/my-app

# Step 2: 启动编排
orch-start my-app ~/projects/my-app
orch-status   # 确认两个 session 都 running

# Step 3: 提交任务
hermes chat
# 输入: /dev-orchestra
# 输入: 在 my-app 项目里实现用户注册 API，要求用 bcrypt 做密码哈希，返回 JWT token

# Step 4: 观察执行
tmux attach -t hermes-my-app-codex   # 看 Codex 写代码
# Ctrl+B, D 退出
tmux attach -t hermes-my-app-claude  # 看 Claude 审查
# Ctrl+B, D 退出

# Step 5: 查看结果
cat /tmp/hermes-orchestra/my-app/codex-result.md
cat /tmp/hermes-orchestra/my-app/review-result.md

# Step 6: 处理审批（如有）
orch-decisions
orch-approve <id>   # 或 orch-reject <id>

# Step 7: 运行测试
cd ~/projects/my-app
npm test

# Step 8: 提交代码
git add .
git commit -m "feat: 用户注册 API (bcrypt + JWT)"

# Step 9: 停止编排
orch-stop my-app
```

### 10.2 配置文件位置速查

```
~/.hermes/
├── SOUL.md                   # 编排器人格
├── skills/                   # 4 个 Skills
│   ├── dev-orchestra/
│   ├── claude-supervisor/
│   ├── codex-executor/
│   └── escalation-handler/
└── .env                      # API Key 配置

~/.hermes-orchestra/
├── bin/orch-*                # CLI 工具
├── lib/orch-common.sh        # 公共库
├── hooks/                    # Hook 脚本
├── plugins/                  # 插件
├── profile-distribution/     # Profile catalog
├── risk-policy.yaml          # 风险策略
├── claude-config-template/   # Claude settings 模板
└── tests/                    # 测试套件

~/.local/bin/orch-*           # 符号链接（需在 PATH 中）

/tmp/hermes-orchestra/{project}/   # 每个项目的运行时目录
├── task.md                   # 当前任务
├── codex-question.md         # Codex 的疑问
├── claude-decision.md        # Claude 的决策
├── escalation.md             # 升级标记
├── codex-result.md           # Codex 执行结果
└── review-result.md          # Claude 审查结果

~/.local/share/hermes-orchestra/{project}/
└── audit.jsonl               # 审计日志
```

### 10.3 风险策略配置

风险策略定义在 `config/risk-policy.yaml`，核心规则：

| 规则 ID | 等级 | 描述 |
|---------|------|------|
| risk-db-wipe | L4 | 数据库破坏性擦除 |
| risk-prod-resource-delete | L4 | 生产资源删除 |
| risk-critical-branch-rewrite | L4 | 关键分支 force-push |
| risk-broad-irreversible-delete | L4 | 广泛不可逆删除 |
| risk-schema-change | L3 | 数据库 schema 变更 |
| risk-system-prune | L3 | 系统级清理 |
| risk-auth-secret-change | L3 | 认证/密钥变更 |
| risk-privilege-escalation | L3 | 权限提升 |
| risk-supervisor-intervention | L2 | 建议干预 |

### 10.4 Claude Supervisor 审查 Checklist

Claude 在审查 Codex 输出时会逐项检查：

- 是否有 SQL 注入、XSS、路径遍历等安全漏洞？
- 是否引入了新依赖？依赖是否可信？
- 是否修改了配置文件或环境变量？
- 是否符合项目代码规范？
- 是否有足够的错误处理？
- 是否包含测试用例？
- 性能是否可接受？（N+1 查询、内存泄漏等）

### 10.5 Codex 模型选择

| 模型 | 适用场景 | 速度 | 成本 |
|------|---------|------|------|
| gpt-5.3-codex | 日常编码、小功能、重构 | 快 | 低 |
| gpt-5.3-codex-spark | 快速原型、探索性编码 | 最快 | 最低 |
| gpt-5.4 | 复杂算法、架构设计 | 中等 | 中 |
| gpt-5.4-mini | 小改动、文档生成 | 快 | 低 |
| gpt-5.5 | 高难度任务、深度调试 | 慢 | 高 |

默认推荐 `gpt-5.3-codex`（均衡性价比）。

---

> **手册版本**: 1.0 | 基于 PRD 合规审计结果 | 合规率 90.3% | 已验证 15/16 功能维度
