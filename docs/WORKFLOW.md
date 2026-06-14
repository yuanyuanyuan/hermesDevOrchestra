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

## 当前正在执行的修复计划

13-sprint PRD Compliance Audit Remediation 计划正在执行，详细入口见 [`docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`](sprints/prd-compliance-audit-remediation-full/sprint-overview.md)。本节 surface 出 6 个跨 sprint 契约、Sprint 12 deliverable owner 和 Sprint 13 audit gate 关系；完整字段定义见 [`docs/gateway-integration-architecture.md`](gateway-integration-architecture.md) `## Cross-Sprint Contract Surfaces`。

| 维度 | 状态 | 入口 |
|---|---|---|
| Source of truth | `sprint-overview.md` Sprint Table + `schema.md` | `docs/sprints/prd-compliance-audit-remediation-full/` |
| 已 surface 的跨 sprint 契约 | 6 个（见 gateway doc `## Cross-Sprint Contract Surfaces` 节） | Contracts 1-6 |
| Strict 0→6 验证脚本 | `test-e2e-strict-six-stage-flow.sh`、`test-success-metrics-pipeline.sh`、`test-schema-doc-sync.sh` | `## 验证` 节 |
| Sprint 12 deliverable owner | `plan-sprint-12.md` U14 (3 SP) | `scripts/tests/test-prd-remediation-schema-doc-sync.sh` |
| Sprint 13 audit gate consumer | 消费 Sprint 12 evidence refs，作为最终 gate | `plan-sprint-13.md` |
| 归档的前置 gate slice | `docs/archive/sprints/prd-compliance-audit-remediation/`（Sprint 1 only） | `plan-sprint-1.md` L13 |

### 已知边界

audit-remediation-full 计划声明了三条边界（`sprint-overview.md` L38-42）：

- **Prior Conflict Ledger gate slice**：归档于 `docs/archive/sprints/prd-compliance-audit-remediation/`，当前 plan 不覆盖；Sprint 1 的 `conflict_ledger` schema 与 closeout 集成消费之。
- **DAG scope**：DAG 工作仅作 **Gateway integration seam**（消费 `scripts/lib/dag_validator.py` 的结果作为 stage 推进的 blocking 证据），底层 cycle detection 已在 `dag_validator.py` 中存在，**不在** scope。
- **Rollback scope**：rollback 实现限于 `current-run refs[]`（见 `schema.md` L42-44 的 `rollback_report.affected_refs[]`），不可触碰无关分支或 protected targets；`protected_target_check` 是 `rollback_report` 的必填字段。

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
bash scripts/tests/test-schema-doc-sync.sh         # owner: Sprint 12 U14; consumer: Sprint 13 audit gate
bash scripts/tests/test-success-metrics-pipeline.sh  # owner: Sprint 12 U14; consumer: Sprint 13 audit gate
bash scripts/tests/test-e2e-strict-six-stage-flow.sh # owner: Sprint 12 U14; consumer: Sprint 13 audit gate
```

- Run Projection 使用 `X-Projection-Schema-Version: 1.0.0` header（Gateway 实现）；actor token 300s + 30s clock skew；cutover 策略由 `config/cutover/full-readiness-gates.json` 与 `runtime-family-activation.json` 控制。

## 下一步阅读

- `docs/GETTING-STARTED.md`：上手步骤。
- `docs/INSTALL.md`：依赖、认证和安装细节。
- `docs/ARCHITECTURE.md`：架构说明。
- `docs/FULL-COVERAGE-MATRIX.md`：full-target readiness 和 runtime 状态。
- `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`：full-target actor authority 边界。
- `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`：13-sprint PRD Compliance Audit Remediation 计划入口（Sprint 12 deliverable owner 必读）。
