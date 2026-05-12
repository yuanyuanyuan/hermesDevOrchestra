# 安装指南

> **本文档解决一个问题：你的机器是否已满足运行 Hermes Dev Orchestra 的全部前提条件？**
>
> 如果你已经装好了所有依赖，只想尽快跑起来，请直接阅读 [`GETTING-STARTED.md`](GETTING-STARTED.md)。

---

## 诚实的前置条件

Hermes Dev Orchestra 本身只是一个**编排适配层**（约 250 行的 `setup.sh` + 一些配置模板）。但在它能工作之前，你需要先安装并配置好 **3 个外部 CLI 工具** 和 **3 个基础依赖**。这些都不是标准系统包，无法通过 `apt`/`brew` 一键搞定。

**整体流程预估时间**：如果你已有 API Key 和订阅账号，约 15-20 分钟；如果需要注册和订阅，可能需要 30-60 分钟。

---

## 第一步：快速自检（推荐先运行）

在项目根目录运行：

```bash
bash scripts/check-prerequisites.sh
```

你会看到彩色输出，明确列出：
- ✅ 已就绪的工具及版本
- ⚠️ 缺失的 API Key
- ❌ 未安装或版本不足的依赖

**如果自检全部通过，直接跳到第三步。**

---

## 第二步：安装前置依赖

### 2.1 基础工具（系统包管理器安装）

| 工具 | 最低版本 | 验证命令 | 安装方式 |
|------|---------|---------|---------|
| `git` | >= 2.30 | `git --version` | `apt install git` / `brew install git` |
| `node` | >= 18 | `node --version` | [nodejs.org](https://nodejs.org/) 或 `nvm` |
| `tmux` | >= 3.0 | `tmux -V` | `apt install tmux` / `brew install tmux` |
| `python3` | >= 3.10 | `python3 --version` | 通常系统预装 |

### 2.2 上游 CLI（需单独安装和认证）

这三个工具是 Orchestra 的核心上游依赖，**缺一不可**。

#### Hermes Agent（编排器）

```bash
# 从上游仓库安装到 ~/.hermes/hermes-agent
git clone https://github.com/NousResearch/hermes-agent.git ~/.hermes/hermes-agent
cd ~/.hermes/hermes-agent
# 切换到项目锁定的版本
git checkout 023b1bff11c2a01a435f1956a0e2ac1773a065f3
# 按上游文档完成安装，确保 hermes 命令加入 PATH
hermes --version  # 应输出 >= 0.11.0
```

> **注意**：Hermes Agent 的安装方式以上游仓库文档为准。如果上游提供了安装脚本，优先使用安装脚本。

#### Claude Code CLI（监督者）

```bash
npm install -g @anthropic-ai/claude-code
claude --version  # 应输出 >= 2.1.110
```

**认证要求**：
- Claude Code CLI 自 2026.4 起不再支持 raw API key (`sk-ant-api03-*`)，必须使用 **Claude Max 订阅的 OAuth Token** (`sk-ant-oat01-*`)。
- 首次使用必须运行：
  ```bash
  claude auth
  ```

#### Codex CLI（执行者）

```bash
npm install -g @openai/codex
codex --version  # 应输出 >= 0.122.0
```

**认证要求**：
- 需要 OpenAI API Key。
- 首次使用必须运行：
  ```bash
  codex login
  ```

### 2.3 API Key 配置（最小必需项）

Orchestra 运行**至少需要**以下 3 个 Key。如果你已通过 Hermes Agent 安装获得了完整的 `.env` 模板（内含多模型、工具、Gateway 等配置），**不要覆盖它**——只需确保这 3 个变量已设置即可。

```bash
mkdir -p ~/.hermes

# 检查现有 .env 是否已有这 3 个变量
grep -E '^(OPENROUTER_API_KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY)=' ~/.hermes/.env 2>/dev/null

# 如果缺失，追加到文件末尾（不要覆盖已有配置）
cat >> ~/.hermes/.env << 'EOF'
OPENROUTER_API_KEY=sk-or-xxx
OPENAI_API_KEY=sk-xxx
ANTHROPIC_API_KEY=sk-ant-oat01-xxx
EOF
```

将 `xxx` 替换为你的真实 Key。这三个 Key 分别对应：
- `OPENROUTER_API_KEY` — Hermes Agent 的 LLM 路由
- `OPENAI_API_KEY` — Codex CLI
- `ANTHROPIC_API_KEY` — Claude Code CLI（OAuth Token 格式）

> **关于完整 `.env` 配置**：Hermes Agent 的 `.env` 支持多模型 Provider（Gemini、Kimi、GLM、Ollama、Qwen 等）、工具 API（Exa、Firecrawl、Browserbase）、Messaging Gateway（Slack、Telegram、Email）等大量配置。如果你使用的是 Hermes Agent 自带的 `.env` 模板，请保留其中的注释和配置，只补充 Orchestra 需要的这 3 个 Key。

---

## 第三步：安装 Orchestra 包

前置条件全部就绪后，在克隆下来的仓库根目录运行：

```bash
bash scripts/setup.sh
```

### setup.sh 会做什么？

| 步骤 | 行为 | 失败时 |
|------|------|--------|
| 检查 `hermes` | 必须存在，否则退出 | 提示完成 Phase 9 安装 |
| 检查 `tmux` | 必须存在，否则退出 | 提示安装 tmux |
| 检查 `claude`/`codex` | 仅警告，不阻断 | 提示后续手动安装 |
| 安装 SOUL.md | `hermes/SOUL.md` → `~/.hermes/SOUL.md` | 退出 |
| 安装 4 个 Skills | `skills/*/` → `~/.hermes/skills/` | 退出 |
| 安装 CLI 工具 | `scripts/bin/orch-*` → `~/.local/bin/` | 退出 |
| 安装配置模板 | `claude-config/settings.json` → `~/.hermes-orchestra/claude-config-template/` | 退出 |
| 安装风险策略 | `config/risk-policy.yaml` → `~/.hermes-orchestra/` | 退出 |
| 安装 Profile/Hooks/Plugins | 复制到 `~/.hermes-orchestra/` | 警告 |
| 创建运行时目录 | `/tmp/hermes-orchestra/`、`~/.local/state/` 等 | 退出 |

### 成功后的输出示例

```
========================================
 Setup Complete!
========================================

Installed:
  SOUL:       /home/you/.hermes/SOUL.md
  Skills:     /home/you/.hermes/skills/{dev-orchestra,claude-supervisor,codex-executor,escalation-handler}
  Helpers:    /home/you/.local/bin/orch-*
  ...

Next steps:
  1. Ensure Claude Code and Codex CLI are installed and authenticated.
  2. Run: orch-init my-app ~/projects/my-app
  3. Run: orch-start my-app ~/projects/my-app
  4. Start upstream Hermes with: hermes chat
```

### 确保 PATH 正确

```bash
which orch-init
```

如果找不到，添加 PATH：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## 第四步：验证安装

```bash
orch-verify
```

这会运行内置的冒烟测试套件。如果通过，你会看到所有测试项的通过报告。

完整验证（包含风险测试、JSON 校验、Shell 校验和上游版本对齐检查）：

```bash
make test
```

---

## 常见安装问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `setup.sh` 报 "Hermes Agent not found" | `hermes` 不在 PATH | 完成上游 Hermes Agent 安装，确保 `hermes --version` 可执行 |
| `setup.sh` 报 "tmux is required" | tmux 未安装 | `apt install tmux` 或 `brew install tmux` |
| `orch-*` 命令找不到 | `~/.local/bin` 不在 PATH | 添加到 shell profile 并 `source` |
| `claude auth` 失败 | 使用了 raw API key | 改用 OAuth Token (`sk-ant-oat01-*`) |
| `make test` 的 `upstream-status` 失败 | Hermes Agent 的版本与仓库锁定版本不一致 | `cd ~/.hermes/hermes-agent && git checkout 023b1bff11c2a01a435f1956a0e2ac1773a065f3` |

---

## 安装后文件速查

```
~/.hermes/
├── SOUL.md                   # 编排器人格（setup.sh 安装）
├── skills/                   # 4 个 Skills（setup.sh 安装）
│   ├── dev-orchestra/
│   ├── claude-supervisor/
│   ├── codex-executor/
│   └── escalation-handler/
└── .env                      # API Key 配置（手动创建）

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
```

---

## 下一步

- **[`GETTING-STARTED.md`](GETTING-STARTED.md)** — 从安装完成到提交第一个编排任务
- **[`ARCHITECTURE.md`](ARCHITECTURE.md)** — 系统架构与数据流
- **[`CONFIGURATION.md`](CONFIGURATION.md)** — 环境变量与配置详解
