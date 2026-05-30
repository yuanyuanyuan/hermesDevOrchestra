<!-- generated-by: gsd-doc-writer -->

# Hermes Dev Orchestra

[English](README.md) | 简体中文

多项目 AI 开发编排系统 —— 通过 Hermes Agent 协调 Claude Code CLI（监督者）与 Codex CLI（执行者），实现单人多项目并行开发。

<!-- VERIFY: 需要预装 Hermes Agent v0.11.0+、Claude Code CLI v2.1.110+、Codex CLI v0.122.0+ -->

---

## 问题 → 方案 → 结果

### 问题

开发者在管理多个项目时，使用 AI 编程助手的工作流是碎片化的：

- **上下文丢失**：手动在 Claude Code 与 Codex CLI 之间切换，任务上下文不断丢失——你需要在不同会话中反复解释相同的需求。
- **无审计追踪**：没有集中式日志，你无法追溯哪个 AI 在何时做了什么改动、以及为什么。
- **高风险命令无人把关**：危险操作（如 `docker system prune`、`rm -rf`、schema 迁移）未经审查或审批就直接执行。
- **手动协调**：你需要打开两个终端、分别登录 Claude 和 Codex、复制粘贴任务描述、再手动审查代码——每个项目都重复这套流程。

### 方案

Hermes Dev Orchestra 将整个 Claude↔Codex 协作流水线自动化，一键初始化项目并管理隔离会话：

- **一键设置**：`orch-init` 脚手架式地生成项目配置、目录结构和风险策略。
- **隔离的 tmux 会话对**：`orch-start` 自动为每个项目创建成对的 tmux 会话（`hermes-{project}-claude` / `hermes-{project}-codex`）。
- **文件交换任务流**：`/tmp/hermes-orchestra/{project}/` 下的结构化文件自动在代理之间派发任务、问题、决策和结果。
- **L1–L4 风险拦截**：`orch-risk-check` 依据 `config/risk-policy.yaml` 评估命令；L3/L4 操作会被阻塞，等待通过 `orch-approve` / `orch-reject` 进行人工审批。
- **内置审计**：每一次操作都写入 `~/.local/share/hermes-orchestra/{project}/audit.jsonl`，实现完整可追溯。

### 结果

用自然语言描述任务，编排器会处理其余一切：

- **Before（之前）**：打开两个终端 → 分别登录 Claude 和 Codex → 复制粘贴任务描述 → 手动审查每一处代码改动 → 无日志、无回滚、无监管。
- **After（之后）**：`orch-init my-app ~/projects/my-app` → `orch-start my-app ~/projects/my-app` → 在 `hermes chat` 中输入 `/dev-orchestra` 并描述任务 → watcher 自动派发 → Claude 决策 → Codex 执行 → 结果自动审查 → `orch-audit my-app --limit 20` 查看完整审计链。

所有项目彼此隔离，所有操作都有记录，危险命令被阻断直到你审批通过。

---

## 安装

前置依赖（需预先安装）：

```bash
git --version       # >= 2.30
node --version      # >= 18
tmux -V             # >= 3.0
python3 --version   # >= 3.10
hermes --version    # >= 0.11.0
claude --version    # >= 2.1.110
codex --version     # >= 0.122.0
```

一键安装（无需 sudo，全部安装在用户目录）：

```bash
bash scripts/setup.sh
```

安装脚本会自动完成 SOUL.md、Skills、CLI helpers (`orch-*`)、目录结构及配置模板的安装。

## 快速开始

1. **安装**（见上）
   ```bash
   # 引导式安装/配置/启动/MVP 验收
   orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway
   ```
   验收完成后会生成：
   - `~/.local/state/hermes-orchestra/{project}/mvp-acceptance-report.json`
   - `~/.local/state/hermes-orchestra/{project}/mvp-demo-flow.json`
   - `~/.local/state/hermes-orchestra/{project}/mvp-demo-log.jsonl`

   `mvp-demo-log.jsonl` 逐步记录 demo case 的参与方、输入、输出、API endpoint、artifact refs 和本地证据文件，可直接用于复盘完整 MVP 流程。

   如果要把真实 Codex/Claude CLI 也纳入验收，运行：
   ```bash
   orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway --real-worker-demo
   ```
   这会实际调用 `codex exec` 修改 `.workflow/knowledge/orchestra-real-worker-demo.md`，调用 `claude -p` 审查该低风险改动，并生成 `mvp-real-worker-flow.json` / `mvp-real-worker-log.jsonl`。
2. **初始化项目**（项目目录必须是 git 仓库）：
   ```bash
   orch-init api-gateway ~/projects/api-gateway
   ```
3. **启动编排会话**（自动创建 Claude + Codex tmux 进程对）：
   ```bash
   orch-start api-gateway ~/projects/api-gateway
   ```
4. **查看状态**：
   ```bash
   orch-status
   ```

## 使用示例

### 初始化并启动多项目

```bash
# 项目 A：后端 API
orch-init api-gateway ~/projects/api-gateway
orch-start api-gateway ~/projects/api-gateway

# 项目 B：前端
orch-init web-frontend ~/projects/web-frontend
orch-start web-frontend ~/projects/web-frontend

# 查看所有运行中项目
orch-status
```

### 日常管理命令

```bash
# 查看单个项目详细状态
orch-status api-gateway

# 停止项目编排会话
orch-stop api-gateway

# 查看待审批决策
orch-decisions

# 审批或拒绝
orch-approve <approval_id>
orch-reject <approval_id>

# 风险预检
orch-risk-check "docker system prune"

# 查看审计日志
orch-audit api-gateway --limit 20

# 验证安装
orch-verify

# 引导式配置、启动和 MVP 验收
orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway

# 只做配置/启动，不跑测试和 demo run
orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway --skip-tests

# 额外验收真实 Codex/Claude CLI worker
orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway --real-worker-demo
```

### 运行测试

```bash
# 全部测试（单元测试 + 风险测试 + JSON 校验 + Shell 校验 + 上游版本检查）
make test

# 仅单元测试
make test-unit

# 仅风险相关测试
make test-risk
```

## 项目结构

| 目录 | 说明 |
|------|------|
| `scripts/bin/orch-*` | CLI 工具集：初始化、启动、停止、状态、审批、风控等 |
| `scripts/lib/` | 公共 Bash 函数库 |
| `scripts/tests/` | 自动化测试套件 |
| `skills/` | 4 个 Hermes Skills：dev-orchestra、claude-supervisor、codex-executor、escalation-handler |
| `hermes/` | SOUL.md、角色引擎协议、profile 分发目录 |
| `config/` | risk-policy.yaml、rules.json |
| `specs/` | 派生规范：命令集、任务交换协议、风险决策机制 |

## 核心概念

- **三层代理协作**：Hermes（编排者）→ Claude（监督/决策）→ Codex（执行/编码）
- **文件交换机制**：每个项目在 `/tmp/hermes-orchestra/{project}/` 下通过结构化文件交换任务、问题、决策和结果
- **审计日志**：每个项目的操作审计记录在 `~/.local/share/hermes-orchestra/{project}/audit.jsonl`
- **三级决策流转**：技术决策（Claude 秒级自动）→ 风险升级（Hermes 评估 L1-L4）→ 危险操作（L3/L4 阻塞等待用户批准）
- **多项目隔离**：每个项目拥有独立的 tmux 会话（`hermes-{project}-claude` / `hermes-{project}-codex`）及独立的任务目录

## 相关文档

- [`WORKFLOW.md`](docs/WORKFLOW.md) — 单人全周期工作流详细指南
- [`specs/`](specs/) — 派生规范（命令集、任务交换协议、风险决策）
- [`docs/COVERAGE-MATRIX.md`](docs/COVERAGE-MATRIX.md) — 功能覆盖矩阵
