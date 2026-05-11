<!-- generated-by: gsd-doc-writer -->

# Hermes Dev Orchestra

多项目 AI 开发编排系统 —— 通过 Hermes Agent 协调 Claude Code CLI（监督者）与 Codex CLI（执行者），实现单人多项目并行开发。

<!-- VERIFY: 需要预装 Hermes Agent v0.11.0+、Claude Code CLI v2.1.110+、Codex CLI v0.122.0+ -->

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
| `specs/` | 派生规范：命令集、文件总线协议、风险决策机制 |

## 核心概念

- **三层代理协作**：Hermes（编排者）→ Claude（监督/决策）→ Codex（执行/编码）
- **文件通信总线**：每个项目在 `/tmp/hermes-orchestra/{project}/` 下通过结构化 Markdown 文件交换任务、问题、决策和结果
- **三级决策流转**：技术决策（Claude 秒级自动）→ 风险升级（Hermes 评估 L1-L4）→ 危险操作（L3/L4 阻塞等待用户批准）
- **多项目隔离**：每个项目拥有独立的 tmux 会话（`hermes-{project}-claude` / `hermes-{project}-codex`）及通信总线

## 相关文档

- [`WORKFLOW.md`](WORKFLOW.md) — 单人全周期工作流详细指南
- [`specs/`](specs/) — 派生规范（命令集、文件总线、风险决策）
- [`docs/COVERAGE-MATRIX.md`](docs/COVERAGE-MATRIX.md) — 功能覆盖矩阵
