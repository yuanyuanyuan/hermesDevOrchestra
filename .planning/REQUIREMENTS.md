# Requirements: Hermes Dev Orchestra

**Defined:** 2026-04-25  
**Milestone:** v1.1 — Hermes CLI Prototype  
**Core Value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。

## v1.1 Requirements

This milestone turns the v1.0 specification package into a local Hermes CLI prototype. Scope is a minimal, testable vertical slice: command shell, path/state/bus foundations, project/task/status operations, doctor/preflight, local decision fallback, and prototype verification.

### CLI Shell & Installation

- [ ] **CLI-01**: 用户可以在仓库内运行本地 Hermes CLI 原型并看到 hermes --help、hermes --version 和命令列表。
- [ ] **CLI-02**: 用户可以通过无 sudo 的本地安装/开发入口运行 CLI；不要求全局系统安装或 root 权限。
- [ ] **CLI-03**: CLI 每个命令都支持机器可读 JSON 输出，并在失败时返回结构化错误对象。

### Path, State & File Bus

- [ ] **BUS-01**: CLI 启动时解析 Runtime、State、Audit、Cache 四层路径并写入 State 层 paths.json manifest。
- [ ] **BUS-02**: CLI 使用 JSON/JSONL 作为 canonical 文件总线格式，并为 task、event、decision、state 记录提供 schema-ready envelope。
- [ ] **BUS-03**: CLI 写入总线和状态文件时使用同文件系统临时文件加 rename 的原子写入策略。
- [ ] **BUS-04**: CLI 将 Runtime bus、State snapshot 和 Audit evidence 物理分离，Runtime 文件不得作为最终证据。

### Project Registry, Tasks & Status

- [ ] **PROJ-01**: 用户可以通过 hermes init <project-id> <project-dir> 注册项目，并获得可重复执行的项目配置结果。
- [ ] **PROJ-02**: CLI 校验 project-id、canonical path、Git 仓库状态和 per-project 目录，并拒绝不安全或无效输入。
- [ ] **TASK-01**: 用户可以通过 hermes task <project-id> <task-file> 追加任务，并获得 task ID、queue 状态和 audit/event 记录。
- [ ] **TASK-02**: CLI 对短时间重复提交的同内容 task 提供可验证的去重或明确的新任务创建行为。
- [ ] **STAT-01**: 用户可以通过 hermes status 查看项目、任务、cwd、heartbeat age、risk wait、last event 和 next action。

### Doctor, Safety & Local Decisions

- [ ] **DOC-01**: hermes doctor 可以探测 Node、Git、tmux、Claude Code CLI、Codex CLI、认证提示、sandbox/JSON 能力并输出 JSON health report。
- [ ] **SAFE-01**: CLI 原型加载静态 risk rulebook，并能对匹配规则计算最低风险等级。
- [ ] **SAFE-02**: L3/L4 决策在 CLI 原型中默认阻塞，不能通过 timeout、Claude、Codex 或 fallback 自动批准。
- [ ] **DEC-01**: 本地文件 fallback 可以创建 decision request，并支持 hermes decisions 列出待处理决策。
- [ ] **DEC-02**: 用户可以通过 hermes approve <decision-id> 或 hermes reject <decision-id> 写入一次性 decision reply，CLI 校验 TTL、项目、任务和 approval ID。

### Prototype Verification & Handoff

- [ ] **VER-01**: 原型包含覆盖 init、task、status、doctor、decision fallback、路径解析和错误输出的自动化 smoke/fixture 检查。
- [ ] **VER-02**: 原型文档说明支持命令、环境变量、路径布局、已实现范围、未实现范围和手工验证步骤。
- [ ] **VER-03**: 交付物明确标注哪些 v1.0 规格已由原型实现、哪些仍是 stub/dry-run、哪些进入下一里程碑。
- [ ] **VER-04**: 实现 handoff 列出下一阶段需要接入的 tmux session lifecycle、Claude/Codex runner、review loop 和 remote adapter 工作。

## Future Requirements

Deferred to later milestones. Tracked but not in v1.1 scope.

### Agent Runtime Integration

- **RUN-01**: Hermes starts, monitors, and stops real Claude Supervisor and Codex Executor tmux sessions.
- **RUN-02**: Hermes routes Codex questions to Claude and routes Claude decisions back to Codex through real process I/O.
- **RUN-03**: Hermes captures agent outputs, review results, command evidence, and final archives from live executions.

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
| Full autonomous Claude/Codex execution loop | Prototype first proves CLI, bus, state, safety, and local fallback before live agent orchestration. |
| Concrete Telegram/Discord/webhook adapter | v1.0 requires Remote Decision Channel abstraction; concrete adapters need a separate identity/replay design pass. |
| Team collaboration or multi-user approvals | Project remains focused on a single developer. |
| gbrain integration | Standalone Hermes prototype first; integration remains optional future work. |
| Unrestricted unattended execution | Safety budgets and no-go operations are future work. |
| Production deployment or package publishing | This milestone targets a local prototype and verification fixtures. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLI-01 | Phase 8 | Pending |
| CLI-02 | Phase 8 | Pending |
| CLI-03 | Phase 8 | Pending |
| BUS-01 | Phase 9 | Pending |
| BUS-02 | Phase 9 | Pending |
| BUS-03 | Phase 9 | Pending |
| BUS-04 | Phase 9 | Pending |
| PROJ-01 | Phase 10 | Pending |
| PROJ-02 | Phase 10 | Pending |
| TASK-01 | Phase 10 | Pending |
| TASK-02 | Phase 10 | Pending |
| STAT-01 | Phase 10 | Pending |
| DOC-01 | Phase 11 | Pending |
| SAFE-01 | Phase 11 | Pending |
| SAFE-02 | Phase 11 | Pending |
| DEC-01 | Phase 11 | Pending |
| DEC-02 | Phase 11 | Pending |
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
*Last updated: 2026-04-25 after starting v1.1 milestone*
