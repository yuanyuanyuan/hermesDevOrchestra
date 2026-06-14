<!-- generated-by: gsd-doc-writer -->

# 开发指南

本文档面向希望为 Hermes Dev Orchestra 贡献代码或进行二次开发的开发者。

<!-- VERIFY: 本仓库托管于 GitHub，Fork 操作通过 GitHub Web 界面完成 -->

---

## 本地环境搭建

### 前置依赖

在开始之前，请确保已安装以下工具并满足最低版本要求：

| 工具 | 最低版本 | 说明 |
|------|---------|------|
| `git` | 2.30 | 版本控制 |
| `node` | 18 | 部分上游工具依赖 Node 运行时 |
| `tmux` | 3.0 | 多项目会话隔离 |
| `python3` | 3.10 | JSON 校验及辅助脚本 |
| `hermes` | 0.11.0 | 上游 Hermes Agent CLI |
| `claude` | 2.1.110 | Claude Code CLI（监督者代理）；最近本地验证为 2.1.161 |
| `codex` | 0.122.0 | Codex CLI（执行者代理）；最近本地验证为 codex-cli 0.136.0 |

验证安装：

```bash
git --version
node --version
tmux -V
python3 --version
hermes --version
claude --version
codex --version
```

### Fork 与克隆

1. 在 GitHub 上 Fork 本仓库到自己的账号下。
2. 克隆 Fork 后的仓库到本地：

```bash
git clone https://github.com/<你的用户名>/hermesDevOrchestra.git
cd hermesDevOrchestra
```

### 安装 Orchestra 包

项目本身无需编译，通过安装脚本将 SOUL、Skills、CLI helpers 及配置模板部署到本地用户目录：

```bash
bash scripts/setup.sh
```

安装脚本会完成以下操作：

- 验证 `hermes`、`tmux` 等核心依赖是否存在
- 创建 orchestra 目录结构（`~/.hermes-orchestra/`、`~/.local/state/hermes-orchestra/` 等）
- 安装 `hermes/SOUL.md` 到 `~/.hermes/SOUL.md`
- 安装 `skills/` 下的 4 个 Skill 到 `~/.hermes/skills/`
- 安装 `scripts/bin/orch-*` 辅助命令到 `~/.hermes-orchestra/bin/` 并建立到 `~/.local/bin/` 的符号链接
- 安装配置文件模板、hooks、plugins、profile distribution 及测试套件

安装完成后，确保 `~/.local/bin` 在你的 `PATH` 中，以便直接使用 `orch-*` 命令。

### 环境变量（可选）

Orchestra 的所有目录路径和运行时参数均通过环境变量控制，带有合理的默认值。通常情况下无需手动配置 `.env` 文件。

如需自定义，可在 shell profile 中导出以下变量：

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `HERMES_HOME` | `~/.hermes` | Hermes Agent 集成根目录 |
| `ORCHESTRA_HOME` | `~/.hermes-orchestra` | Orchestra 运行时资产根目录 |
| `LOCAL_BIN_DIR` | `~/.local/bin` | `orch-*` 符号链接目标目录 |
| `RUNTIME_ROOT` | `/tmp/hermes-orchestra` | 项目级任务交换运行时目录 |
| `STATE_ROOT` | `~/.local/state/hermes-orchestra` | 项目级状态文件目录 |
| `AUDIT_ROOT` | `~/.local/share/hermes-orchestra` | 审计文件目录 |
| `CACHE_ROOT` | `~/.cache/hermes-orchestra` | 缓存目录 |

完整的变量列表请参阅 [`docs/CONFIGURATION.md`](CONFIGURATION.md)。

---

## 构建命令

本项目使用 `Makefile` 管理验证任务。所有目标均在仓库根目录执行。

| 目标 | 类别 | 说明 |
|------|------|------|
| `make test` | 测试 | 执行完整验证套件：smoke tests + 风险测试 + JSON 校验 + 可用时 Shell lint + upstream pin advisory + 3 strict gates (test-schema-doc-sync / test-success-metrics-pipeline / test-e2e-strict-six-stage-flow, owner: Sprint 12 U14, consumer: Sprint 13 final audit gate) |
| `make test-unit` | 测试 | 运行所有 smoke 测试（`scripts/tests/test-*.sh`，当前 164 个，含 Sprint 12 strict gate 增量） |
| `make test-risk` | 测试 | 运行风险相关专项测试（决策 CLI、风险策略加载等） |
| `make lint-json` | 检查 | 使用 `python3 -m json.tool` 校验源码 `.json` 文件格式；忽略本地 `.tmp/` 缓存 |
| `make lint-shell` | 检查 | 如果已安装 `shellcheck`，检查 `scripts/` 下的 Shell 脚本；未安装时跳过 |
| `make upstream-status` | 检查 | 比对仓库中记录的 upstream Hermes Agent pin 与本地运行时 checkout 的 commit；默认 advisory，不失败 |

常用命令示例：

```bash
# 完整验证（推荐在提交前执行）
make test

# 仅运行 smoke 测试
make test-unit

# 仅运行风险测试
make test-risk

# 单独校验 JSON 格式
make lint-json

# 单独校验 Shell 脚本（需已安装 shellcheck）
make lint-shell
```

---

## 13-Sprint 修复计划中的验证门禁

13-sprint PRD Compliance Audit Remediation 计划正在 active 执行中（Sprint 12 deliverable owner, Sprint 13 final audit gate consumer）。本地仓库 `main` 已同步最新状态。完整 6 个 Cross-Sprint Contract 详见 [`docs/gateway-integration-architecture.md`](gateway-integration-architecture.md) `## Cross-Sprint Contract Surfaces`。

| 维度 | 状态 | 引用 |
|---|---|---|
| Source truth | `sprint-overview.md` Sprint Table + `schema.md` | `docs/sprints/prd-compliance-audit-remediation-full/` |
| Cross-sprint contracts surfaced | 6（conflict_ledger / run.lifecycle_status / run.channel_decision / authority_route+override_record / mini-debate consensus_score 0.60 / Sprint 12→13 gate scripts） | `gateway-integration-architecture.md ## Cross-Sprint Contract Surfaces` |
| Strict gate 脚本 | 3 个：`test-schema-doc-sync.sh` / `test-success-metrics-pipeline.sh` / `test-e2e-strict-six-stage-flow.sh` | `scripts/tests/` |
| Sprint 12 deliverable owner | U14（3 SP） | `plan-sprint-12.md` |
| Sprint 13 consumer | final audit gate | `plan-sprint-13.md` |

### Known Limitations of the in-flight plan

- **Conflict Ledger gate slice 归档**：前置 gate slice 已归档在 `docs/archive/sprints/prd-compliance-audit-remediation/`，本计划不覆盖。
- **DAG scope**：DAG work 仅在 Gateway integration seam（消费 `scripts/lib/dag_validator.py` 结果作为阻断证据）。低层 cycle detection 已存在，不在范围内。
- **Rollback scope**：rollback 实现仅限 `current-run refs[]`（per `rollback_report.affected_refs[]` in `schema.md` L42-44）。禁止触碰无关 branch 与 protected target；`protected_target_check` 为 `rollback_report` 必填字段。

---

## 代码风格

本项目主要使用 **Bash** 编写 CLI 工具和测试，辅以少量 **Python** 辅助脚本。

### Shell 脚本

- 所有新增脚本应以 `#!/usr/bin/env bash` 开头，并启用 `set -euo pipefail`。
- 使用 `shellcheck` 进行静态检查：`make lint-shell`。
- 公共函数应放入 `scripts/lib/orch-common.sh`。
- 可执行命令脚本放入 `scripts/bin/orch-*`。
- 测试脚本放入 `scripts/tests/test-*.sh`，并使用 `run-all.sh` 汇总运行。

### JSON 文件

- 所有 `.json` 文件必须可通过 `python3 -m json.tool` 解析。
- 运行 `make lint-json` 进行批量校验。

### 其他约定

- 无 Prettier、ESLint、Biome 等前端格式化工具配置。
- 无 `.editorconfig` 文件；建议保持 4 空格缩进（Bash 数组/嵌套结构可适当调整）。

---

## 分支规范

- **默认分支**：`main`
- 功能开发请从 `main` 切出独立分支：

```bash
git checkout -b feature/简短描述
```

推荐分支命名前缀：

| 前缀 | 用途 |
|------|------|
| `feature/` | 新功能或增强 |
| `fix/` | 缺陷修复 |
| `docs/` | 文档更新 |
| `test/` | 测试补充或调整 |

---

## PR 流程

1. **创建分支**：从最新的 `main` 切出功能分支。
2. **本地验证**：在提交前运行完整测试套件：
   ```bash
   make test
   ```
3. **提交变更**：编写清晰的提交信息，说明变更目的和影响范围。
4. **推送到 Fork**：
   ```bash
   git push origin feature/你的分支名
   ```
5. **发起 Pull Request**：通过 GitHub 向 `main` 分支发起 PR。
6. **等待审查**：维护者会审查代码并反馈。请确保 CI 检查（如有配置）通过。

### 提交前检查清单

- [ ] `make test` 全部通过
- [ ] `make lint-shell` 无警告（如已安装 shellcheck）
- [ ] `make lint-json` 无格式错误
- [ ] 新增脚本具有可执行权限（`chmod +x`）
- [ ] 文档（如 `README.md`、本文件、`docs/` 下的相关文档）已同步更新

---

## 相关文档

- [`README.md`](../README.md) — 项目总览与快速开始
- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — 系统架构与数据流
- [`docs/gateway-integration-architecture.md`](gateway-integration-architecture.md) — 6 个 Cross-Sprint Contract Surfaces 入口（FR-1 ~ FR-13 全集）
- [`docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`](sprints/prd-compliance-audit-remediation-full/sprint-overview.md) — 13-sprint PRD Compliance Audit Remediation 计划入口
- [`docs/CONFIGURATION.md`](CONFIGURATION.md) — 环境变量与配置文件说明
- [`specs/`](../specs/) — 命令集、任务交换协议、风险决策机制规范
