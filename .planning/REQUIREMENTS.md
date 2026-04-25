# Requirements: Hermes Dev Orchestra

**Defined:** 2026-04-25  
**Milestone:** v1.1 — Upstream Hermes Agent Integration  
**Core Value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。

## v1.1 Requirements

This milestone turns the v1.0 specification package into an upstream-first implementation based on `https://github.com/NousResearch/hermes-agent`. Scope is a minimal, testable vertical slice: install/probe upstream Hermes Agent, load the orchestra SOUL/skills package, bootstrap per-project tmux Claude/Codex sessions, coordinate through the file bus, enforce local L3/L4 decisions, and document the integration boundary.

### Upstream Hermes Agent Baseline

- [x] **UP-01**: 用户可以在无 sudo Ubuntu 环境安装或更新社区 `NousResearch/hermes-agent`，并看到真实上游 `hermes --version` / help 输出。
- [x] **UP-02**: 项目固定并记录上游 Hermes Agent 的版本或 commit、安装方式、能力探测结果和不兼容项。
- [x] **UP-03**: 本仓库不得继续独立重写 Hermes Agent runtime；本地代码只能作为上游适配层、配置、skills、tmux/file-bus glue 或验证脚本。
- [x] **UP-04**: 现有独立 Node CLI scaffolding 必须删除；后续命令入口保留上游 `hermes` 原样，本项目只提供 `orch-*` helper/adapter。

### Orchestra Package Installation

- [x] **PKG-01**: 安装脚本将 `docs/hermes-dev-orchestra/hermes/SOUL.md` 安装到上游 Hermes Agent 可读取的位置。
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

- [ ] **SAFE-01**: 静态风险 rulebook 对 L1-L4 决策给出最低风险等级，Claude 只能升级不能降低规则下限。
- [ ] **SAFE-02**: L3/L4 决策必须阻塞对应项目，不能被 Hermes、Claude、Codex、timeout 或 fallback 自动批准。
- [ ] **DEC-01**: 当远程通道未配置时，Hermes Agent 使用 SSH/local file fallback，通过 `orch-decisions`、`orch-approve <approval_id>`、`orch-reject <approval_id>` 请求并记录用户 approve/reject；modify 在当前里程碑中建模为 reject 后提交修订任务。
- [ ] **DEC-02**: 用户决策写入审计记录，并以一次性 approval_id、TTL、project_id、task_id 绑定防止重放。

### Verification & Handoff

- [ ] **VER-01**: smoke/fixture 覆盖上游安装探测、skills 加载、`orch-init`、`orch-start`、文件总线问题转发、风险阻塞和状态查看。
- [ ] **VER-02**: 文档说明上游 Hermes Agent 版本、安装命令、目录布局、helper 命令、已实现范围、未实现范围和手工验证步骤。
- [ ] **VER-03**: 覆盖矩阵标注哪些 v1.0 规格由上游 Hermes Agent 原生提供、哪些由本仓库适配层提供、哪些仍待实现。
- [ ] **VER-04**: handoff 列出后续 remote adapter、生产化审计、容器隔离、gbrain 集成或 dashboard 的边界。

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
| SAFE-01 | Phase 12 | Pending |
| SAFE-02 | Phase 12 | Pending |
| DEC-01 | Phase 12 | Pending |
| DEC-02 | Phase 12 | Pending |
| VER-01 | Phase 12 | Pending |
| VER-02 | Phase 12 | Pending |
| VER-03 | Phase 12 | Pending |
| VER-04 | Phase 12 | Pending |

**Coverage:**
- v1.1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-25*
*Last updated: 2026-04-25 after Phase 11 project bootstrap, tmux runtime, and file bus execution*
