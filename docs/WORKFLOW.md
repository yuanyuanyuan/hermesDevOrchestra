# Workflow

> 本文档是当前工作流入口。它描述可直接使用的运行路径，并标出 full-target 能力的边界。

## 当前分层

Hermes Dev Orchestra 现在不是单一形态：

| 层级 | 当前状态 | 入口 |
|---|---|---|
| MVP/local orchestration | active/current | `orch-init`、`orch-start`、tmux Claude/Codex 会话、file bus、risk approval |
| Gateway runtime | partially implemented/current | `orch-gateway`、`/orchestra/runs`、Run Projection API、actor-token authority |
| Strict 0->6 gate | ready/test harness | `scripts/tests/test-e2e-strict-six-stage-flow.sh`、success metrics、schema/doc sync |
| Full-target system | staged/mixed-family | `docs/FULL-COVERAGE-MATRIX.md`、`docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` |

## 常用流程

### 1. 安装与自检

```bash
bash scripts/check-prerequisites.sh
bash scripts/setup.sh
```

本地 CLI 登录模式下，`OPENROUTER_API_KEY`、`OPENAI_API_KEY`、`ANTHROPIC_API_KEY` 缺失会作为 warning 处理；需要强制 `.env` 校验时使用 `orch-mvp-wizard --require-api-keys`。

### 2. 初始化项目

```bash
cd ~/projects/my-app
git status
orch-init my-app ~/projects/my-app
```

项目目录必须是 git 仓库。初始化会写入项目运行时目录、Claude settings、profile workspace 和项目元数据。

### 3. 启动本地编排

```bash
orch-start my-app ~/projects/my-app
orch-status my-app
```

这会创建 `hermes-my-app-claude` 和 `hermes-my-app-codex` 两个 tmux 会话，并启动 watcher。当前 file bus 是每项目一个 active task slot，不是同一项目多任务并行协议。

### 4. 提交任务

```bash
hermes chat
```

在 Hermes 里启用 `/dev-orchestra`，用自然语言描述任务。典型流转是：

1. Hermes 写入 `task.md`。
2. watcher 派发给 Codex。
3. Codex 需要决策时写入 `codex-question.md`。
4. Claude 写入 `claude-decision.md`。
5. Codex 完成后写入 `codex-result.md`。
6. Claude review 后写入 `review-result.md`。
7. runtime 记录迁移到 Audit。

### 5. Gateway 路径

Gateway 是当前 full-system 能力的主要运行边界：

```bash
orch-gateway --project-id my-app
```

可用能力包括 run 创建、任务/事件投影、actor-token authority、部分 worker/debate/closeout/evaluation 路径。完整 full artifact runtime cutover 尚未完成，具体状态以 `docs/FULL-COVERAGE-MATRIX.md` 为准。

### 6. 验证

```bash
orch-verify
make test
```

`orch-verify` 运行 smoke suite；`make test` 运行 smoke、risk、JSON lint、Shell lint 和 upstream pin advisory check。`npm test` 只是代理到 `make test`。

关键专项：

```bash
bash scripts/tests/test-schema-doc-sync.sh
bash scripts/tests/test-success-metrics-pipeline.sh
bash scripts/tests/test-e2e-strict-six-stage-flow.sh
```

## 下一步阅读

- `docs/GETTING-STARTED.md`：上手步骤。
- `docs/INSTALL.md`：依赖、认证和安装细节。
- `docs/ARCHITECTURE.md`：架构说明。
- `docs/FULL-COVERAGE-MATRIX.md`：full-target readiness 和 runtime 状态。
- `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`：full-target actor authority 边界。
- `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`：13-sprint PRD Compliance Audit Remediation 计划入口（Sprint 12 deliverable owner 必读）。
