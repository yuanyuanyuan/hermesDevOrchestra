# Requirements: Hermes Dev Orchestra

**Defined:** 2026-04-28  
**Milestone:** v1.2 — Hermes Dev Orchestra 规范化与迁移  
**Core Value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。

## v1.2 Requirements

**Milestone:** v1.2 — Hermes Dev Orchestra 规范化与迁移  
**Goal:** 通过证据盘点和 gap audit，修复根目录可发现性，按需迁移目录结构，规范化规格体系和开发工作流。

### 仓库可发现性与结构

- [x] **DISC-01**: 根目录包含指向 `docs/orchestra/` 的显式索引（README 或指针文件），解决增强层内容埋太深的问题。
- [x] **DISC-02**: `AGENTS.md` 保留现有 GSD/project/stack/workflow managed blocks，追加 Dev Orchestra 目录定位说明。
- [x] **MIGR-01**: 生成完整迁移前路径引用清单，作为迁移或保留的决策依据。
- [x] **MIGR-02**: 目录迁移（若执行）必须使用 `git mv`，迁移后零旧路径残留，所有测试仍通过。Validated in Phase 14.

### 上游依赖与规格权威

- [x] **UPST-01**: 编写 submodule ADR，比较 installer/probe pin / git submodule / manifest pin / vendor snapshot 四种方案。Validated in Phase 14.
- [x] **UPST-02**: 若选择 submodule，提交前验证暂存区只包含 `.gitmodules` 和 `hermes-agent` gitlink；Phase 14 选择 manifest pin，因此该条件不适用且已验证未引入 submodule artifact。Validated in Phase 14.
- [x] **SPEC-01**: `.planning/SPEC.md` 保持 canonical spec；任何 `specs/*.md` 派生文件必须声明 source、consumer 和 drift check。
- [x] **SPEC-02**: 每个派生 spec 至少有一个可失败的 conformance check；没有当前 consumer 的 spec 不得创建。

### 开发工作流与工具

- [x] **DEV-01**: `Makefile` 只引用真实存在的测试脚本，不存在的 target（如 `test-integration`、`test-e2e`）不得出现。Validated in Phase 16.
- [x] **DEV-02**: `make test-unit` 调用现有 smoke/unit fixtures；`make test-risk` 调用三个风险审批测试。Validated in Phase 16.
- [x] **DEV-03**: `make lint-json` 验证所有 JSON 文件；`make lint-shell` 在无 shellcheck 时明确 skip 不伪失败。Validated in Phase 16.
- [x] **DEV-04**: `make upstream-status` 报告 repo-local pin 与 runtime pin 的一致性（若二者都有）。Validated in Phase 16.

### Agents 规则与边界

- [x] **AGNT-01**: `AGENTS.md` 追加 Dev Orchestra Package Boundary 和 Agent Role Boundary，不覆盖现有 managed sections。
- [x] **AGNT-02**: 若创建 `CLAUDE.md`，必须指向 `AGENTS.md` 和 `.planning/SPEC.md` 作为权威，不重复所有规则。

### 架构约束

- [x] **ARCH-01**: 明确固定文件名 file bus 表示单活动任务限制；若需支持多任务并行，必须另起设计（JSONL bus、per-task locks 等）。Validated in Phase 18.
- [x] **ARCH-02**: 当前 v1.1 的 10x 承诺仅限于"单人多项目，每项目单活动任务"，不得扩展为"同一项目多任务并行"。Validated in Phase 18.

---

## v1.1 Requirements (Completed)

This milestone turns the v1.0 specification package into an upstream-first implementation based on `https://github.com/NousResearch/hermes-agent`. Scope is a minimal, testable vertical slice: install/probe upstream Hermes Agent, load the orchestra SOUL/skills package, bootstrap per-project tmux Claude/Codex sessions, coordinate through the file bus, enforce local L3/L4 decisions, and document the integration boundary.

### Upstream Hermes Agent Baseline

- [x] **UP-01**: 用户可以在无 sudo Ubuntu 环境安装或更新社区 `NousResearch/hermes-agent`，并看到真实上游 `hermes --version` / help 输出。
- [x] **UP-02**: 项目固定并记录上游 Hermes Agent 的版本或 commit、安装方式、能力探测结果和不兼容项。
- [x] **UP-03**: 本仓库不得继续独立重写 Hermes Agent runtime；本地代码只能作为上游适配层、配置、skills、tmux/file-bus glue 或验证脚本。
- [x] **UP-04**: 现有独立 Node CLI scaffolding 必须删除；后续命令入口保留上游 `hermes` 原样，本项目只提供 `orch-*` helper/adapter。

### Orchestra Package Installation

- [x] **PKG-01**: 安装脚本将 `docs/orchestra/hermes/SOUL.md` 安装到上游 Hermes Agent 可读取的位置。
- [x] **PKG-02**: 安装脚本将 `dev-orchestra`、`claude-supervisor`、`codex-executor`、`escalation-handler` 四个 skills 安装到上游 Hermes Agent skill layout。
- [x] **PKG-03**: 安装脚本创建 `~/.hermes-orchestra/`、`/tmp/hermes-orchestra/` 和 per-project bus 目录，且不需要 sudo。
- [x] **PKG-04**: `orch-init`、`orch-start`、`orch-stop`、`orch-status` helper 明确调用上游 Hermes Agent、tmux、Claude Code CLI 和 Codex CLI，而不是调用自研 Agent runtime。

### Project Bootstrap, File Bus & Runtime Integration

- [x] **RUN-01**: `orch-init <project-id> <project-dir>` 校验 Git 仓库、创建 per-project bus、复制 Claude hooks 配置，并记录项目状态。
- [x] **RUN-02**: `orch-start` 为每个项目启动或复用 `hermes-{project}-claude` 和 `hermes-{project}-codex` tmux 会话。
- [x] **RUN-03**: Hermes Agent 将用户任务写入 `task.md`，通知 Codex Executor，并轮询或订阅 Codex 输出。
- [x] **RUN-04**: Codex 问题写入 `codex-question.md` 后，Hermes Agent 转发给 Claude Supervisor；Claude 决策写入 `claude-decision.md` 并恢复 Codex。
- [x] **RUN-05**: Claude review、Codex result、escalation 和 audit 记录可被 Hermes Agent 汇总给用户，且带项目名前缀。

### Safety & Local Decisions

- [x] **SAFE-01**: 静态风险 rulebook 对 L1-L4 决策给出最低风险等级，Claude 只能升级不能降低规则下限。
- [x] **SAFE-02**: L3/L4 决策必须阻塞对应项目，不能被 Hermes、Claude、Codex、timeout 或 fallback 自动批准。
- [x] **DEC-01**: 当远程通道未配置时，Hermes Agent 使用 SSH/local file fallback，通过 `orch-decisions`、`orch-approve <approval_id>`、`orch-reject <approval_id>` 请求并记录用户 approve/reject；modify 在当前里程碑中建模为 reject 后提交修订任务。
- [x] **DEC-02**: 用户决策写入审计记录，并以一次性 approval_id、TTL、project_id、task_id 绑定防止重放。

### Verification & Handoff

- [x] **VER-01**: smoke/fixture 覆盖上游安装探测、skills 加载、`orch-init`、`orch-start`、文件总线问题转发、风险阻塞和状态查看。
- [x] **VER-02**: 文档说明上游 Hermes Agent 版本、安装命令、目录布局、helper 命令、已实现范围、未实现范围和手工验证步骤。
- [x] **VER-03**: 覆盖矩阵标注哪些 v1.0 规格由上游 Hermes Agent 原生提供、哪些由本仓库适配层提供、哪些仍待实现。
- [x] **VER-04**: handoff 列出后续 remote adapter、生产化审计、容器隔离、gbrain 集成或 dashboard 的边界。

## Future Requirements

Deferred to later milestones. Tracked but not in v1.1 scope.

### Remote Adapters

- **ADPT-01**: Hermes supports a concrete Remote Decision Channel adapter after transport selection.
- **ADPT-02**: Adapter identity verification, message truncation, replay protection, and delivery retries are implemented.

### Product Extensions

- **EXT-01**: Optional gbrain integration or memory backend.
- **EXT-02**: Web/mobile dashboard for multi-project status.
- **EXT-03**: Low-risk unattended mode with budgets and no-go rules.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Reimplementing Hermes Agent core runtime | User direction requires building on community `NousResearch/hermes-agent`. |
| Concrete Telegram/Discord/webhook adapter as the mandatory channel | v1.0 keeps Remote Decision Channel abstract; concrete adapters need a separate identity/replay design pass. |
| Team collaboration or multi-user approvals | Project remains focused on a single developer. |
| gbrain integration | Upstream Hermes Agent integration first; integration remains optional future work. |
| Unrestricted unattended execution | Safety budgets and no-go operations are future work. |
| Production deployment or package publishing | This milestone targets a local upstream integration slice and verification fixtures. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| UP-01 | Phase 9 | Completed |
| UP-02 | Phase 9 | Completed |
| UP-03 | Phase 9 | Completed |
| UP-04 | Phase 9 | Completed |
| PKG-01 | Phase 10 | Completed |
| PKG-02 | Phase 10 | Completed |
| PKG-03 | Phase 10 | Completed |
| PKG-04 | Phase 10 | Completed |
| RUN-01 | Phase 11 | Completed |
| RUN-02 | Phase 11 | Completed |
| RUN-03 | Phase 11 | Completed |
| RUN-04 | Phase 11 | Completed |
| RUN-05 | Phase 11 | Completed |
| SAFE-01 | Phase 12 | Complete |
| SAFE-02 | Phase 12 | Complete |
| DEC-01 | Phase 12 | Complete |
| DEC-02 | Phase 12 | Complete |
| VER-01 | Phase 12 | Complete |
| VER-02 | Phase 12 | Complete |
| VER-03 | Phase 12 | Complete |
| VER-04 | Phase 12 | Complete |

### v1.2 Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISC-01 | Phase 13 | Complete |
| DISC-02 | Phase 13 | Complete |
| MIGR-01 | Phase 13 | Complete |
| MIGR-02 | Phase 14 | Complete |
| UPST-01 | Phase 14 | Complete |
| UPST-02 | Phase 14 | Complete |
| SPEC-01 | Phase 15 | Complete |
| SPEC-02 | Phase 15 | Complete |
| DEV-01 | Phase 16 | Complete |
| DEV-02 | Phase 16 | Complete |
| DEV-03 | Phase 16 | Complete |
| DEV-04 | Phase 16 | Complete |
| AGNT-01 | Phase 17 | Complete |
| AGNT-02 | Phase 17 | Complete |
| ARCH-01 | Phase 18 | Complete |
| ARCH-02 | Phase 18 | Complete |

**Coverage:**
- v1.2 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

### v1.1 Traceability (Completed)

| Requirement | Phase | Status |
|-------------|-------|--------|
| UP-01 | Phase 9 | Completed |
| UP-02 | Phase 9 | Completed |
| UP-03 | Phase 9 | Completed |
| UP-04 | Phase 9 | Completed |
| PKG-01 | Phase 10 | Completed |
| PKG-02 | Phase 10 | Completed |
| PKG-03 | Phase 10 | Completed |
| PKG-04 | Phase 10 | Completed |
| RUN-01 | Phase 11 | Completed |
| RUN-02 | Phase 11 | Completed |
| RUN-03 | Phase 11 | Completed |
| RUN-04 | Phase 11 | Completed |
| RUN-05 | Phase 11 | Completed |
| SAFE-01 | Phase 12 | Complete |
| SAFE-02 | Phase 12 | Complete |
| DEC-01 | Phase 12 | Complete |
| DEC-02 | Phase 12 | Complete |
| VER-01 | Phase 12 | Complete |
| VER-02 | Phase 12 | Complete |
| VER-03 | Phase 12 | Complete |
| VER-04 | Phase 12 | Complete |

**Coverage:**
- v1.1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-28*
*Last updated: 2026-04-29 — Phase 18 completed*
