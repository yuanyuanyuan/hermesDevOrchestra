# Phase 12: Risk Decisions, Verification & Handoff - Research

**Researched:** 2026-04-25  
**Domain:** Bash-based safety gate, local decision fallback, JSONL audit, smoke verification, handoff documentation  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

All content in this `<user_constraints>` block is copied from `.planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md` and is binding for planning. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

### Locked Decisions

### Decision Fallback CLI Naming (D-12-01)
- **Probe-first approach**: Before creating any adapter commands, check if upstream `hermes` has native `decisions`, `approve`, `reject` commands.
- **If upstream has them**: Use upstream commands directly. Do not create `orch-*` equivalents.
- **If upstream does NOT have them**: Create adapter commands `orch-decisions` (view pending), `orch-approve <id>`, `orch-reject <id>`.
- **REQUIREMENTS.md update**: If the adapter path is taken, update DEC-01 to reference `orch-*` commands instead of `hermes` subcommands.
- **Rationale**: Respects D9 (local entrypoints are `orch-*` only) while avoiding unnecessary duplication if upstream already provides the capability.

### Audit Log Format and Location (D-12-02)
- **Format**: JSON Lines (JSONL) — canonical per PROJECT.md.
- **Location**: Per-project at `~/.local/share/hermes-orchestra/{project}/audit.jsonl`.
- **Schema** (full fields):
  ```json
  {
    "timestamp": "2026-04-25T10:30:00+08:00",
    "level": "L3",
    "project": "project-a",
    "type": "SECURITY",
    "decision": "APPROVED",
    "user_decision": "用户批准执行",
    "details": "需要修改 JWT 密钥轮换策略",
    "approval_id": "uuid-v4",
    "ttl": 3600,
    "task_id": "task-123",
    "escalation_id": "esc-456",
    "agent_source": "escalation-handler",
    "session_id": "sess-789"
  }
  ```
- **Rotation**: Yes, by date or size (daily rotation, or >10MB per file).
- **Writers**: ALL `orch-*` commands write audit records (project init, session start/stop, decisions, escalations).
- **Query**: Provide `orch-audit [project-id]` command to view recent audit records (time-descending, last N entries).
- **SKILL.md update**: Update `escalation-handler/SKILL.md` to use JSONL format and `~/.local/share/hermes-orchestra/{project}/audit.jsonl` location (was `/tmp/hermes-orchestra/audit.log` plain text).

### Rulebook Enforcement Mechanism (D-12-03)
- **Rules file**: `~/.hermes-orchestra/rules.json` (global adapter config, shared across projects).
- **Enforcement form**: Standalone `orch-risk-check` script that reads `rules.json` and evaluates an operation against rules.
- **Timing**: Active checking — `orch-start` and other commands call `orch-risk-check` proactively before executing dangerous operations.
- **Rule schema** (Phase 12):
  ```json
  [
    {"id": "rule-001", "level": "L3", "patterns": ["rm -rf /", "DROP TABLE", "DELETE FROM", "TRUNCATE"], "description": "Destructive data operations"},
    {"id": "rule-002", "level": "L3", "patterns": ["sudo", "chmod 777"], "description": "System privilege escalation"},
    {"id": "rule-003", "level": "L4", "patterns": ["ALTER TABLE DROP", "docker system prune", "kubectl delete"], "description": "System-level destructive commands"},
    {"id": "rule-004", "level": "L3", "patterns": ["ALTER TABLE", "CREATE TABLE", "DROP TABLE"], "description": "Database schema changes"},
    {"id": "rule-005", "level": "L4", "patterns": ["修改 .env", "修改密钥", "修改认证", "修改 JWT"], "description": "Authentication and secret modifications"}
  ]
  ```
- **Extensibility**: Phase 12 provides 3-5 built-in rules only. User customization is deferred to post-v1.1.
- **Integration**: `orch-risk-check` returns exit code 0 (safe), 1 (L1-L2), 2 (L3), 3 (L4). Callers decide how to handle each level.

### Smoke Fixture Runner and Scope (D-12-04)
- **Runner**: Pure bash scripts with custom assertion functions (no external test framework dependency).
- **Structure**:
  - Individual test scripts in `scripts/tests/` directory (e.g., `scripts/tests/test-install-probe.sh`, `scripts/tests/test-skills-load.sh`, etc.)
  - Each script is self-contained, sources a shared assertion library, reports pass/fail
- **Integration**: `orch-verify` command runs all tests in `scripts/tests/`, aggregates results, and prints a summary.
- **Failure reporting**: Detailed — shows test name, expected value, actual value, and relevant log excerpts.
- **Scope** (VER-01, 6 areas):
  1. Upstream install/probe (`hermes --version`, commit pin verification)
  2. Skills load (`hermes skills list` contains our 4 skills)
  3. `orch-init` (Git validation, directory creation, settings.json copy)
  4. `orch-start` (tmux session creation/reuse, process health)
  5. File bus routing (write `task.md` → Codex reads; write `codex-question.md` → Claude reads; write `claude-decision.md` → Codex reads)
  6. Risk block (`orch-risk-check` detects L3/L4 operations; escalation blocks until user decision)
  7. Status (`orch-status` shows project states and file bus stages) — *bonus, if time permits*
- **Coverage matrix** (VER-03): Markdown table with 3 columns (upstream native / adapter-provided / still deferred) × v1.0 specification items. Written to `docs/COVERAGE-MATRIX.md`.

### Claude's Discretion
- Exact `orch-risk-check` implementation details (regex vs keyword matching, output format) are left to implementation discretion.
- Exact `orch-audit` output formatting (table, JSON, plain text) is left to implementation discretion.
- Exact smoke test assertion library design is left to implementation discretion.
- Coverage matrix row granularity (per-requirement or per-feature) is left to implementation discretion.
- Handoff document (VER-04) structure and depth is left to implementation discretion.

### Deferred Ideas (OUT OF SCOPE)

- User-customizable risk rulebook extension (post-v1.1)
- Audit log query/filtering by date range, agent, or escalation type (post-v1.1)
- Remote adapter implementation (deferred to v2+ adapter milestone)
- Team collaboration or multi-user approvals (deferred)
- gbrain integration (deferred)
- Dashboard for audit visualization (deferred)
- Automated audit log backup/archival (deferred)
- Production deployment or package publishing (deferred)

### Reviewed Todos (not folded)
None — Phase 12 scope is self-contained.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SAFE-01 | 静态风险 rulebook 对 L1-L4 决策给出最低风险等级，Claude 只能升级不能降低规则下限。 | Plan `~/.hermes-orchestra/rules.json`, `orch-risk-check`, and a bus-loop enforcement hook before forwarding decisions. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; .planning/SPEC.md] |
| SAFE-02 | L3/L4 决策必须阻塞对应项目，不能被 Hermes、Claude、Codex、timeout 或 fallback 自动批准。 | Existing Phase 11 watcher already stops on `escalation.md`; Phase 12 must replace the placeholder with pending-decision creation and require explicit user approval/rejection before continuation. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop; docs/hermes-dev-orchestra/scripts/bin/orch-status; .planning/REQUIREMENTS.md] |
| DEC-01 | 当远程通道未配置时，Hermes Agent 使用 SSH/local file fallback 请求用户 approve/reject/modify。 | Local probe found no upstream `hermes decisions`, `hermes approve`, or `hermes reject`; adapter path is active, so plan `orch-decisions`, `orch-approve`, and `orch-reject`, plus a DEC-01 wording update. [VERIFIED: local `hermes --help` probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| DEC-02 | 用户决策写入审计记录，并以一次性 approval_id、TTL、project_id、task_id 绑定防止重放。 | Store pending request metadata durably, validate `approval_id`, expiry, `project_id`, `task_id`, and one-time use before writing `claude-decision.md` and `audit.jsonl`. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md; .planning/REQUIREMENTS-REV1.md] |
| VER-01 | smoke/fixture 覆盖上游安装探测、skills 加载、`orch-init`、`orch-start`、文件总线问题转发、风险阻塞和状态查看。 | D-12-04 locks a pure-Bash fixture runner and individual scripts under `scripts/tests/`, driven by `orch-verify`. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| VER-02 | 文档说明上游 Hermes Agent 版本、安装命令、目录布局、helper 命令、已实现范围、未实现范围和手工验证步骤。 | Update README/SOUL/skills to match Phase 9 pin, Phase 10 paths, Phase 11 helper behavior, and Phase 12 safety commands. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md; .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-03-SUMMARY.md] |
| VER-03 | 覆盖矩阵标注哪些 v1.0 规格由上游 Hermes Agent 原生提供、哪些由本仓库适配层提供、哪些仍待实现。 | Create `docs/COVERAGE-MATRIX.md` with upstream-native, adapter-provided, and deferred columns. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| VER-04 | handoff 列出后续 remote adapter、生产化审计、容器隔离、gbrain 集成或 dashboard 的边界。 | Add a handoff section or document that orders remote adapter first, then audit hardening, isolation, and optional product extensions. [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
</phase_requirements>

## Summary

Phase 12 should be planned as the safety/verification finish for the upstream-based v1.1 slice, not as a new orchestration runtime. Phase 10 installed the package layout and helper templates; Phase 11 created project bootstrap, tmux shells, watcher routing, JSON envelope bus files, review capture, and a placeholder block when `escalation.md` appears. [VERIFIED: .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-02-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-03-SUMMARY.md]

The key planning move is to turn the Phase 11 placeholder block into a deterministic safety gate: static rule floor → pending decision request → local approve/reject command → one-time/TTL/project/task validation → JSONL audit append → final user-authored `claude-decision.md` → controlled Codex continuation. [VERIFIED: .planning/SPEC.md; .planning/REQUIREMENTS-REV1.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop]

**Primary recommendation:** implement Phase 12 in five small plans: safety/audit primitives, local decision fallback, watcher integration, smoke fixtures/`orch-verify`, then documentation/coverage/handoff. [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

## Project Constraints

- Keep implementation scoped to the upstream Hermes adapter package, skills, templates, tmux/file-bus glue, verification scripts, and `.planning/` artifacts; do not reintroduce an independent local `hermes` runtime. [VERIFIED: AGENTS.md; .planning/STATE.md; .planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md]
- Preserve the command boundary: upstream owns `hermes`; this repository owns `orch-*` helper commands. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md; .planning/STATE.md]
- Keep Remote Decision Channel abstract; do not bind v1.1 to Telegram, Discord, webhook, or another concrete transport. [VERIFIED: AGENTS.md; .planning/REQUIREMENTS.md; .planning/PROJECT.md]
- Keep `gbrain` out of scope. [VERIFIED: AGENTS.md; .planning/PROJECT.md; .planning/REQUIREMENTS.md]
- L3/L4 decisions must never be auto-approved by Hermes, Claude, Codex, timeout, fallback, or documentation examples. [VERIFIED: AGENTS.md; .planning/REQUIREMENTS.md; .planning/SPEC.md]
- No `CLAUDE.md` file exists in the repository root, so there are no additional CLAUDE.md directives to enforce. [VERIFIED: local `ls CLAUDE.md` probe 2026-04-25]
- No project-local skills exist under `.claude/skills/` or `.agents/skills/`, so no additional project skill rules apply. [VERIFIED: local `find .claude/skills .agents/skills` probe 2026-04-25]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Static risk rule floors | Hermes adapter / Backend shell layer | Claude Supervisor | Hermes enforces minimum floors; Claude can only upgrade assessed risk. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| L3/L4 project blocking | Hermes adapter / Watcher | Codex Executor | The watcher owns routing and can stop continuation; Codex executes only after authority is sufficient. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop; .planning/SPEC.md] |
| Local decision fallback | Hermes adapter / CLI | User via SSH | Upstream lacks native decision subcommands in the pinned local install; adapter commands must expose pending decisions. [VERIFIED: local `hermes --help` probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Decision validation | Hermes adapter / State layer | Audit layer | Replay protection requires durable pending metadata and immutable audit records before unblocking. [VERIFIED: .planning/SPEC.md; .planning/REQUIREMENTS-REV1.md] |
| Audit records | Audit layer | Hermes adapter / CLI | Per-project JSONL audit files are the durable evidence layer and must be queryable through `orch-audit`. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; .planning/SPEC.md] |
| Smoke fixtures | Package verification layer | Fake CLIs / temporary HOME | D-12-04 locks pure Bash fixtures and `orch-verify`; Phase 10/11 validation already used temporary HOME fake CLI patterns. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md] |
| Coverage matrix and handoff | Documentation layer | Planning artifacts | VER-03 and VER-04 are documentation deliverables that separate implemented, adapter, and deferred work. [VERIFIED: .planning/REQUIREMENTS.md; .planning/ROADMAP.md] |

## File Inventory for Planning

| File / Path | Current Role | Phase 12 Action |
|-------------|--------------|-----------------|
| `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` | Shared path, JSON, tmux, state, and archive helpers. [VERIFIED: docs/hermes-dev-orchestra/scripts/lib/orch-common.sh] | Add audit append/rotation helpers, decision metadata helpers, rulebook path helpers, and maybe JSON validation helpers. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` | Routes task/question/decision/result/review files and currently blocks when `escalation.md` exists. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop] | Integrate risk check, create pending decision requests, consume valid approvals/rejections, and only then continue/reject task. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md] |
| `docs/hermes-dev-orchestra/scripts/bin/orch-status` | Shows project stage, sessions, watcher, bus files, result, review, and escalation placeholder. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-status] | Add pending approval id/age/expiry and audit path visibility. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| `docs/hermes-dev-orchestra/scripts/bin/orch-init` | Creates Runtime/State/Audit/Cache project dirs and `$AUDIT_DIR/pending`. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-init] | Ensure `STATE_DIR/decisions`, `RUNTIME_DIR/decisions`, and `AUDIT_DIR/archive`/audit file paths exist if chosen by plan. [VERIFIED: .planning/REQUIREMENTS-REV1.md; .planning/SPEC.md] |
| `docs/hermes-dev-orchestra/scripts/bin/orch-start` | Starts/reuses tmux sessions and watcher. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-start] | Call or expose `orch-risk-check` only for operations the helper itself executes; keep task/escalation enforcement in watcher. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| `docs/hermes-dev-orchestra/scripts/setup.sh` | Installs SOUL, skills, helper templates, and links selected `orch-*` commands. [VERIFIED: docs/hermes-dev-orchestra/scripts/setup.sh] | Install new public helpers `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, `orch-risk-check`, and `orch-verify`; install internal test runner if needed. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` | Still documents `/tmp/hermes-orchestra/audit.log`, Telegram/Discord examples, and L1 timeout approval text. [VERIFIED: rg audit/Telegram probe 2026-04-25; docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md] | Rewrite to JSONL audit path, abstract channel wording, explicit L3/L4 no-auto-approval, and local fallback commands. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; AGENTS.md] |
| `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` | Describes decision escalation and still contains Telegram wording in examples. [VERIFIED: rg Telegram probe 2026-04-25; docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md] | Align examples with abstract Remote Decision Channel and `orch-*` fallback command names. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| `docs/hermes-dev-orchestra/hermes/SOUL.md` | Still says urgent Telegram/Discord notification and `/tmp/hermes-orchestra/audit.log`. [VERIFIED: docs/hermes-dev-orchestra/hermes/SOUL.md; rg audit/Telegram probe 2026-04-25] | Update safety constraints to per-project JSONL audit and abstract remote channel. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| `docs/hermes-dev-orchestra/README.md` | Product docs still include old audit path in safety best practices and examples. [VERIFIED: docs/hermes-dev-orchestra/README.md; rg audit.log probe 2026-04-25] | Document Phase 12 commands, upstream pin, helper list, implemented/deferred scope, and manual verification. [VERIFIED: .planning/REQUIREMENTS.md] |
| `docs/COVERAGE-MATRIX.md` | Not present in current file inventory. [VERIFIED: `rg --files docs` probe 2026-04-25] | Create for VER-03. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| `docs/hermes-dev-orchestra/scripts/tests/` | Not present in current file inventory. [VERIFIED: `rg --files docs/hermes-dev-orchestra/scripts` probe 2026-04-25] | Create pure-Bash smoke fixtures and assertion library. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Bash | 5.2.21 | `orch-*` helper commands and smoke fixtures. | Phase 10/11 helpers are Bash; D-12-04 locks pure Bash tests. [VERIFIED: local version probe 2026-04-25; docs/hermes-dev-orchestra/scripts/bin/orch-start; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Python stdlib | 3.12.3 | JSON read/write helpers in shell scripts. | Existing `orch-common.sh` and `orch-init` already use Python stdlib for JSON serialization. [VERIFIED: local version probe 2026-04-25; docs/hermes-dev-orchestra/scripts/lib/orch-common.sh; docs/hermes-dev-orchestra/scripts/bin/orch-init] |
| jq | 1.7 | JSON validation in smoke checks. | Phase 10/11 verification used `jq empty` for JSON config validation. [VERIFIED: local version probe 2026-04-25; .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md] |
| tmux | 3.4 | Persistent per-project Claude/Codex session envelopes. | Phase 11 implemented tmux session lifecycle around `hermes-{project}-claude` and `hermes-{project}-codex`. [VERIFIED: local version probe 2026-04-25; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-02-SUMMARY.md] |
| Upstream Hermes Agent | v0.11.0 | Top-level upstream agent and skill host. | Phase 9 pinned upstream; local probe confirms installed `hermes` version. [VERIFIED: local version probe 2026-04-25; .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md] |
| Claude Code CLI | 2.1.120 | Supervisor/reviewer jobs in tmux. | Phase 11 routes questions/reviews through `claude -p`; local command is installed. [VERIFIED: local version probe 2026-04-25; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop] |
| Codex CLI | 0.125.0 | Executor jobs in tmux. | Phase 11 dispatches one-shot `codex exec --full-auto --json --output-last-message`; local command is installed. [VERIFIED: local version probe 2026-04-25; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop] |

### Supporting

| Tool | Version / Availability | Purpose | When to Use |
|------|------------------------|---------|-------------|
| uuidgen | Available at `/usr/bin/uuidgen` | Generate `approval_id` values. | Use for one-time decision IDs unless Python `uuid.uuid4()` is already inside the helper path. [VERIFIED: local availability probe 2026-04-25] |
| sha256sum | Available at `/usr/bin/sha256sum` | Content hashes for dedupe and smoke fixtures. | Existing watcher uses SHA-256 hashes for task/question/decision/result dedupe. [VERIFIED: local availability probe 2026-04-25; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop] |
| inotifywait | Missing | Optional watcher acceleration. | Keep polling fallback; do not make fixtures require it. [VERIFIED: local availability probe 2026-04-25; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-CONTEXT.md] |
| shellcheck | Missing | Optional shell lint. | Do not require for acceptance unless the plan installs or skips it. [VERIFIED: local availability probe 2026-04-25] |
| bats | Missing | Optional shell test framework. | Do not use; D-12-04 requires custom Bash assertions. [VERIFIED: local availability probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `orch-decisions` / `orch-approve` / `orch-reject` | Upstream `hermes decisions` / `approve` / `reject` | Local upstream probe shows these commands are not available, so adapter commands are required under D-12-01. [VERIFIED: local `hermes --help` probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Pure Bash custom smoke runner | Bats | Bats is missing locally and D-12-04 explicitly locks pure Bash with custom assertions. [VERIFIED: local availability probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Runtime-only decision files | Runtime + State pending queue + Audit final record | Runtime is volatile; REQUIREMENTS-REV1 says pending queue belongs in State and final decisions in Audit. [VERIFIED: .planning/REQUIREMENTS-REV1.md; .planning/SPEC.md] |
| `/tmp/hermes-orchestra/audit.log` text | Per-project `~/.local/share/hermes-orchestra/{project}/audit.jsonl` | D-12-02 replaces the old text log with durable JSONL. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md] |

**Installation:** no npm/pip package installation is needed for Phase 12; install package assets by extending `docs/hermes-dev-orchestra/scripts/setup.sh` to copy/link new Bash helpers and tests. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; docs/hermes-dev-orchestra/scripts/setup.sh]

**Version verification:** local command probes on 2026-04-25 verified Bash 5.2.21, Python 3.12.3, jq 1.7, Git 2.43.0, tmux 3.4, Hermes Agent v0.11.0, Claude Code 2.1.120, and Codex CLI 0.125.0. [VERIFIED: local version probe 2026-04-25]

## Architecture Patterns

### System Architecture Diagram

```text
Task / Claude decision / escalation text
        |
        v
orch-risk-check reads ~/.hermes-orchestra/rules.json
        |
        +-- exit 0/1 --> normal Phase 11 routing continues
        |
        +-- exit 2/3 --> orch-bus-loop marks project blocked
                         |
                         v
                  create pending decision
                  Runtime mailbox + State queue
                         |
                         v
User over SSH runs orch-decisions -> orch-approve/ orch-reject
                         |
                         v
Hermes adapter validates approval_id + TTL + project_id + task_id + one-time use
                         |
          +--------------+--------------+
          |                             |
          v                             v
   APPROVED: write user-authored   REJECTED/EXPIRED:
   claude-decision.md              write rejection decision/state
          |                             |
          v                             v
   append audit.jsonl              append audit.jsonl
          |                             |
          v                             v
   Codex continuation allowed      Codex branch stopped / project remains safe
```

This diagram follows the Phase 12 locked flow and Phase 11 watcher ownership. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop; .planning/SPEC.md]

### Recommended Project Structure

```text
docs/hermes-dev-orchestra/
├── scripts/
│   ├── bin/
│   │   ├── orch-risk-check      # public risk classifier helper
│   │   ├── orch-decisions       # public pending-decision list
│   │   ├── orch-approve         # public approval response writer
│   │   ├── orch-reject          # public rejection response writer
│   │   ├── orch-audit           # public recent audit viewer
│   │   ├── orch-verify          # public smoke runner
│   │   └── orch-bus-loop        # existing watcher, extended for risk gate
│   ├── lib/
│   │   └── orch-common.sh       # shared paths, JSON, audit, decision helpers
│   └── tests/
│       ├── lib/assert.sh        # custom Bash assertions
│       ├── test-install-probe.sh
│       ├── test-skills-load.sh
│       ├── test-init-start-status.sh
│       ├── test-file-bus.sh
│       └── test-risk-decisions.sh
└── README.md
docs/COVERAGE-MATRIX.md
```

The helper list follows D-12-01, D-12-02, D-12-03, and D-12-04; `scripts/tests/` follows the locked smoke fixture structure. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

### Pattern 1: Rule Floor Before Routing

**What:** evaluate the operation text or escalation payload against `rules.json` before forwarding authority to Codex. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

**When to use:** before dispatching a task, before continuing Codex after a Claude decision, and when `escalation.md` is present. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop; .planning/SPEC.md]

**Example:**

```bash
# Source: D-12-03 and existing orch-bus-loop routing contract.
risk_output="$(printf '%s\n' "$operation_text" | orch-risk-check --project "$PROJECT_ID" --task "$task_id" 2>/dev/null || true)"
risk_code=$?
case "$risk_code" in
  0|1) continue_normal_routing ;;
  2|3) create_pending_decision "$risk_output"; orch_write_project_state "blocked" "$task_id" ;;
  *) echo "risk check failed" >&2; exit 1 ;;
esac
```

### Pattern 2: Durable Pending Decision + Runtime Mailbox

**What:** keep mutable pending decision state under State, expose request/response files in Runtime for local fallback, and append immutable final records to Audit. [VERIFIED: .planning/REQUIREMENTS-REV1.md; .planning/SPEC.md]

**When to use:** every L3/L4 decision request and local fallback response. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md]

**Example:**

```bash
# Source: REMOTE-03/REMOTE-05 and D-12-02.
STATE_DECISION="$STATE_DIR/decisions/$approval_id.request.json"
RUNTIME_DECISION="$RUNTIME_DIR/decisions/$approval_id.request.json"
AUDIT_LOG="$AUDIT_DIR/audit.jsonl"
```

### Pattern 3: Audit Before Unblock

**What:** write the user decision to `audit.jsonl` before generating or forwarding the user-authored `claude-decision.md`. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

**When to use:** approval, rejection, expiry/stale approval rejection, rulebook override, and escalation resolution. [VERIFIED: .planning/SPEC.md]

**Example:**

```bash
# Source: AUDIT-01 and D-12-02.
orch_append_audit "escalation_resolved" "$PROJECT_ID" "$task_id" "$approval_id" "$decision"
write_user_decision_envelope "$decision"
```

### Anti-Patterns to Avoid

- **Adding local `hermes` subcommands:** violates D9 unless upstream already owns the command; local adapter commands must be `orch-*`. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- **Storing final audit only in `/tmp`:** contradicts the four-layer path decision and D-12-02. [VERIFIED: .planning/REQUIREMENTS-REV1.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- **Treating TTL expiry as approval:** violates SAFE-02; stale approvals must be rejected or require a fresh request. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md]
- **Letting Claude approval unblock L3/L4:** Claude may classify or recommend, but user is final authority for L3/L4. [VERIFIED: .planning/SPEC.md; AGENTS.md]
- **Binding examples to Telegram/Discord:** v1.1 keeps Remote Decision Channel abstract. [VERIFIED: AGENTS.md; .planning/REQUIREMENTS.md; docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md]

## Dependency and Plan Order Recommendations

| Order | Plan Slice | Why First / Next |
|-------|------------|------------------|
| 12-01 | Safety primitives and audit foundation | Shared helpers, `rules.json`, `orch-risk-check`, audit append/rotation, and setup installation are prerequisites for decisions and tests. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; docs/hermes-dev-orchestra/scripts/setup.sh] |
| 12-02 | Local decision fallback CLI | `orch-decisions`, `orch-approve`, `orch-reject`, pending queue validation, and DEC-01 update should land before watcher integration. [VERIFIED: local `hermes --help` probe 2026-04-25; .planning/REQUIREMENTS.md] |
| 12-03 | Smoke runner infrastructure and docs fixture | After behavior and docs exist, add pure-Bash assertions, aggregate runner, `orch-verify`, installer wiring, and docs grep fixture. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| 12-04 | Docs, coverage matrix, handoff | Docs should reflect actual helper names, tested behavior, remaining deferred work, README link to `docs/COVERAGE-MATRIX.md`, and handoff order. [VERIFIED: .planning/REQUIREMENTS.md; .planning/ROADMAP.md] |
| 12-05 | Functional smoke fixtures | Add pure-Bash fixtures for install/probe, skill load, helpers, file bus, risk block, under-classified Claude decisions, local decision CLI, replay protection, and status. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| External remote transport | Telegram/Discord/webhook adapter in Phase 12 | Abstract Remote Decision Channel language + local `orch-*` fallback | Concrete remote adapters are deferred and v1 must not bind to a transport. [VERIFIED: AGENTS.md; .planning/REQUIREMENTS.md] |
| Shell JSON escaping | String-concatenated JSON | Existing Python stdlib `json.dump` pattern | Phase 11 fixed shell JSON serialization bugs by moving serialization into Python. [VERIFIED: .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-03-SUMMARY.md; docs/hermes-dev-orchestra/scripts/lib/orch-common.sh] |
| UUID generation | Ad-hoc timestamp IDs for approvals | `uuidgen` or Python `uuid.uuid4()` | `uuidgen` is available locally and DEC-02 requires replay-resistant one-time approval IDs. [VERIFIED: local availability probe 2026-04-25; .planning/REQUIREMENTS.md] |
| Test framework | Bats or npm test harness | Pure Bash assertions in `scripts/tests/lib/assert.sh` | D-12-04 locks pure Bash; Bats is missing locally. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; local availability probe 2026-04-25] |
| Upstream runtime replacement | New independent Hermes orchestrator | Extend existing `orch-*` adapter helpers | Project direction requires upstream Hermes Agent as foundation and adapter-only local code. [VERIFIED: .planning/STATE.md; .planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md] |

**Key insight:** Phase 12 risk safety is mostly state-machine enforcement and evidence recording; custom remote messaging, new runtimes, and broad policy engines would expand beyond locked v1.1 scope. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; .planning/ROADMAP.md]

## Common Pitfalls

### Pitfall 1: Upstream Command Boundary Drift
**What goes wrong:** implementation adds `hermes decisions` locally because SPEC.md still lists `hermes decisions`. [VERIFIED: .planning/SPEC.md; .planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md]  
**Why it happens:** older spec text predates D9 and D-12-01. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]  
**How to avoid:** probe upstream first, then implement `orch-decisions`, `orch-approve`, and `orch-reject` because the local upstream install lacks native commands. [VERIFIED: local `hermes --help` probe 2026-04-25]  
**Warning signs:** new local files or docs refer to `hermes approve` as an implemented v1.1 command. [VERIFIED: rg command-reference probe 2026-04-25]

### Pitfall 2: Runtime-Only Pending Decisions
**What goes wrong:** decision requests survive only under `/tmp`, so a cleanup or reboot loses the pending approval context. [VERIFIED: .planning/REQUIREMENTS-REV1.md]  
**Why it happens:** REMOTE-05 mentions Runtime mailbox paths, while the cross-cutting revision requires State pending queue and Audit final records. [VERIFIED: .planning/SPEC.md; .planning/REQUIREMENTS-REV1.md]  
**How to avoid:** use Runtime as the interaction mailbox, State as the durable pending queue, and Audit as the immutable final record. [VERIFIED: .planning/REQUIREMENTS-REV1.md]  
**Warning signs:** no decision metadata appears under `$STATE_DIR` and `orch-decisions` lists only Runtime files. [VERIFIED: .planning/REQUIREMENTS-REV1.md]

### Pitfall 3: TTL Reopens an Auto-Approval Path
**What goes wrong:** an expired approval token is accepted, or timeout silently approves a high-risk operation. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md]  
**Why it happens:** existing `escalation-handler` contains old L1 default-approval text and transport examples that can be copied accidentally. [VERIFIED: docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md; rg 默认批准 probe 2026-04-25]  
**How to avoid:** validate `expires_at` before decision write; expired approvals return failure and never unblock Codex. [VERIFIED: .planning/SPEC.md]  
**Warning signs:** `orch-approve` does not read the pending request before writing a response. [VERIFIED: .planning/SPEC.md]

### Pitfall 4: Risk Check False Confidence
**What goes wrong:** pattern matching catches a few command strings but misses changes in auth files, `.env`, SQL migrations, or Claude decisions. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]  
**Why it happens:** D-12-03 allows implementation discretion between regex and keyword matching. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]  
**How to avoid:** test both command text and JSON envelope fields; include fixtures for every built-in rule. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]  
**Warning signs:** `orch-risk-check` only tests literal `"rm -rf /"` and `"npm install lodash"` examples. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

### Pitfall 5: Smoke Fixtures Depend on Real Authenticated CLIs
**What goes wrong:** verification fails in agent/CI environments because Claude or Codex authentication is unavailable. [VERIFIED: .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md]  
**Why it happens:** Phase 10/11 succeeded by using temporary HOME and fake CLI smoke checks; Phase 12 can accidentally regress to live-only checks. [VERIFIED: .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md]  
**How to avoid:** keep `orch-verify` fake-CLI capable by default and document a separate manual live smoke. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]  
**Warning signs:** `scripts/tests/` invokes live `claude` or `codex` without a fake PATH option. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

## Code Examples

Verified patterns from local sources and locked decisions:

### Audit Append Helper

```bash
# Source: D-12-02 + existing Python JSON pattern.
orch_append_audit() {
  local event_type="$1"
  local project_id="$2"
  local task_id="$3"
  local approval_id="$4"
  local decision="$5"
  mkdir -p "$AUDIT_DIR"
  python3 - "$AUDIT_DIR/audit.jsonl" "$event_type" "$project_id" "$task_id" "$approval_id" "$decision" "$(orch_now)" <<'PY'
import json, os, sys
path, event_type, project_id, task_id, approval_id, decision, timestamp = sys.argv[1:]
record = {
    "timestamp": timestamp,
    "event_type": event_type,
    "project_id": project_id,
    "task_id": task_id,
    "approval_id": approval_id,
    "decision": decision,
}
with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    handle.flush()
    os.fsync(handle.fileno())
PY
}
```

### Pending Decision Validation

```bash
# Source: REMOTE-03/REMOTE-04 and DEC-02.
validate_pending_decision() {
  local request_json="$1"
  local expected_project="$2"
  local expected_task="$3"
  python3 - "$request_json" "$expected_project" "$expected_task" "$(date +%s)" <<'PY'
import json, sys
path, expected_project, expected_task, now = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
request = json.load(open(path, encoding="utf-8"))
if request.get("used_at"):
    raise SystemExit("DECISION_ALREADY_USED")
if request.get("project_id") != expected_project or request.get("task_id") != expected_task:
    raise SystemExit("DECISION_BINDING_MISMATCH")
if int(request.get("expires_at_epoch", 0)) < now:
    raise SystemExit("DECISION_EXPIRED")
PY
}
```

### Pure Bash Assertion Shape

```bash
# Source: D-12-04.
assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "$expected" != "$actual" ]; then
    printf 'FAIL %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    return 1
  fi
}
```

## State of the Art

| Old Approach | Current Phase 12 Approach | When Changed | Impact |
|--------------|---------------------------|--------------|--------|
| Plain text `/tmp/hermes-orchestra/audit.log` | Per-project JSONL `~/.local/share/hermes-orchestra/{project}/audit.jsonl` | Locked by D-12-02 on 2026-04-25 | Planner must update SOUL, skills, README, helper code, and fixtures. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md] |
| Spec-local `hermes decisions/approve/reject` | Adapter `orch-decisions/ orch-approve/ orch-reject` | Locked by D9 and D-12-01; local probe confirmed upstream lacks native commands | Planner must update DEC-01 wording if adapter path is taken. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; local `hermes --help` probe 2026-04-25] |
| Phase 11 `escalation.md` placeholder block | Full pending-decision gate with audit and explicit user response | Phase 12 | Planner must modify `orch-bus-loop` and `orch-status`. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop; docs/hermes-dev-orchestra/scripts/bin/orch-status; .planning/ROADMAP.md] |
| README/skill Telegram examples | Abstract Remote Decision Channel plus SSH/local fallback | v1/v1.1 constraints | Planner must remove hard binding from user-facing docs. [VERIFIED: AGENTS.md; .planning/REQUIREMENTS.md; rg Telegram probe 2026-04-25] |

**Deprecated/outdated:**
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` audit examples using `/tmp/hermes-orchestra/audit.log` are outdated for Phase 12. [VERIFIED: docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- `docs/hermes-dev-orchestra/hermes/SOUL.md` audit path and Telegram/Discord urgent notification wording are outdated for Phase 12. [VERIFIED: docs/hermes-dev-orchestra/hermes/SOUL.md; .planning/REQUIREMENTS.md]
- `.planning/SPEC.md` command table still names `hermes decisions/approve/reject`; D-12-01 requires `orch-*` if upstream lacks native support. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; local `hermes --help` probe 2026-04-25]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | All claims in this research were verified from local repository artifacts, local command probes, or cited official sources; no `[ASSUMED]` claims are intentionally used. | All sections | If a source artifact is stale relative to user intent, planning should prefer `12-CONTEXT.md` locked decisions. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

## Open Questions (RESOLVED)

1. **Does DEC-01 require a first-class `modify` command?**  
   - What we know: DEC-01 text includes approve/reject/modify; D-12-01 locks only `orch-decisions`, `orch-approve`, and `orch-reject`; SPEC says "modify" is not a predefined choice and should be modeled by rejection plus updated requirements. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; .planning/SPEC.md]  
   - Resolution: Phase 12 implements approve/reject only. `modify` is modeled as `orch-reject <approval_id>` plus a revised task or revised task constraints; there is no first-class modify command in v1.1. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

2. **Should TTL expiry auto-reject or only invalidate stale approval tokens?**  
   - What we know: SAFE-02 forbids auto-approval; SPEC contains timeout rejection language; Phase 12 success criteria says L3/L4 block until explicit user approval or rejection. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md; .planning/ROADMAP.md]  
   - Resolution: TTL expiry is fail-closed and never unlocks Codex. Stale `orch-approve` fails with `DECISION_EXPIRED`, keeps or recreates a pending decision state as needed, and does not write an approved continuation envelope. [VERIFIED: .planning/SPEC.md; .planning/REQUIREMENTS.md]

3. **Where exactly should pending decision metadata live?**  
   - What we know: REMOTE-05 describes Runtime decision files; REQUIREMENTS-REV1 says the recoverable design is Runtime decision requests, State pending queue, and Audit final records. [VERIFIED: .planning/SPEC.md; .planning/REQUIREMENTS-REV1.md]  
   - Resolution: use the plan-consistent paths `$STATE_DIR/pending-decisions/{approval_id}.json` as canonical mutable metadata, `$RUNTIME_DIR/decision-request.{approval_id}.json` as the local mailbox projection, `$RUNTIME_DIR/claude-decision.md` for the user-authored final decision envelope, and `$AUDIT_DIR/audit.jsonl` for immutable outcomes. Do not mirror pending metadata under `$AUDIT_DIR/pending`. [VERIFIED: .planning/REQUIREMENTS-REV1.md; .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-02-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| bash | Helpers and tests | ✓ | 5.2.21 | — |
| python3 | JSON serialization/validation | ✓ | 3.12.3 | Use shell only for simple reads, but keep Python for safe JSON writes. [VERIFIED: docs/hermes-dev-orchestra/scripts/lib/orch-common.sh] |
| jq | JSON fixture validation | ✓ | 1.7 | Python `json.tool` for minimal checks. [VERIFIED: local version probe 2026-04-25] |
| git | Project bootstrap fixtures | ✓ | 2.43.0 | None for `orch-init`; Git repo is required. [VERIFIED: docs/hermes-dev-orchestra/scripts/bin/orch-init] |
| tmux | Runtime/session smoke | ✓ | 3.4 | Fake tmux for automated fixtures; manual live smoke uses real tmux. [VERIFIED: .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md] |
| hermes | Upstream install/probe, skill load | ✓ | Hermes Agent v0.11.0 | Fake hermes for automated fixtures; real probe for manual check. [VERIFIED: local version probe 2026-04-25] |
| claude | Supervisor smoke/manual | ✓ | 2.1.120 | Fake claude for automated fixtures. [VERIFIED: local version probe 2026-04-25; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md] |
| codex | Executor smoke/manual | ✓ | 0.125.0 | Fake codex for automated fixtures. [VERIFIED: local version probe 2026-04-25; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md] |
| uuidgen | Approval IDs | ✓ | `/usr/bin/uuidgen` | Python `uuid.uuid4()`. [VERIFIED: local availability probe 2026-04-25] |
| inotifywait | Optional watcher acceleration | ✗ | — | Existing polling fallback. [VERIFIED: local availability probe 2026-04-25; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop] |
| shellcheck | Optional shell lint | ✗ | — | `bash -n` remains required. [VERIFIED: local availability probe 2026-04-25] |
| bats | Optional shell test framework | ✗ | — | Custom Bash assertions per D-12-04. [VERIFIED: local availability probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

**Missing dependencies with no fallback:** none for Phase 12 planning, because D-12-04 avoids external test frameworks and the watcher already has polling fallback. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop]

**Missing dependencies with fallback:**
- `inotifywait` is missing; use the existing polling path in automated fixtures. [VERIFIED: local availability probe 2026-04-25; docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop]
- `shellcheck` and `bats` are missing; use `bash -n` and custom assertions. [VERIFIED: local availability probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Pure Bash custom fixture runner; no external framework. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Config file | none; tests should live under `docs/hermes-dev-orchestra/scripts/tests/`. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Quick run command | `bash -n docs/hermes-dev-orchestra/scripts/setup.sh && find docs/hermes-dev-orchestra/scripts -type f \\( -name 'orch-*' -o -name 'orch-common.sh' \\) -print0 \| xargs -0 -r -n1 bash -n` |
| Full suite command | `docs/hermes-dev-orchestra/scripts/bin/orch-verify` after setup installation, or `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` from the package tree before installation. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SAFE-01 | Static rulebook floors classify sample operations and cannot be downgraded by Claude decision content. | unit/smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh && bash docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | ❌ Wave 0 |
| SAFE-02 | L3/L4 escalation blocks project and no Codex continuation occurs before valid user response. | integration smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | ❌ Wave 0 |
| DEC-01 | Local fallback lists pending decision and writes approve/reject responses through `orch-*` commands. | integration smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | ❌ Wave 0 |
| DEC-02 | Approval IDs are one-time, TTL-bound, project-bound, task-bound, and audited. | integration smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | ❌ Wave 0 |
| VER-01 | Smoke fixtures cover install/probe, skill load, init/start, file bus, risk block, and status. | smoke suite | `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` | ❌ Wave 0 |
| VER-02 | README/SOUL/skills document version, install, layout, helpers, scope, and manual checks. | grep/doc check | `bash docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | ❌ Wave 0 |
| VER-03 | Coverage matrix separates upstream-native, adapter-provided, and deferred capabilities. | doc check | `test -f docs/COVERAGE-MATRIX.md && rg 'Upstream native|Adapter-provided|Deferred' docs/COVERAGE-MATRIX.md` | ❌ Wave 0 |
| VER-04 | Handoff orders remote adapter, audit hardening, isolation, and optional extensions. | doc check | `rg 'remote adapter|audit hardening|isolation|gbrain|dashboard' docs/hermes-dev-orchestra/README.md docs/COVERAGE-MATRIX.md` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** run the quick syntax command and the specific test script for the touched helper or doc. [VERIFIED: .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md]
- **Per wave merge:** run `orch-verify` or `scripts/tests/run-all.sh` with fake PATH/TEMP HOME. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- **Phase gate:** full suite green plus manual live probe instructions documented for real Hermes/Claude/Codex. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

### Wave 0 Gaps

- [ ] `docs/hermes-dev-orchestra/scripts/tests/lib/assert.sh` — shared custom assertions for D-12-04. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- [ ] `docs/hermes-dev-orchestra/scripts/tests/run-all.sh` — package-tree runner used by `orch-verify`. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-install-probe.sh` — covers upstream install/probe and pinned commit evidence. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-skills-load.sh` — covers four custom skills load. [VERIFIED: .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` — covers helper install, init/start/status behavior with fake CLIs. [VERIFIED: .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` — covers task/question/decision routing. [VERIFIED: .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` — covers L3/L4 block and approval/rejection path. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- [ ] `docs/hermes-dev-orchestra/scripts/bin/orch-verify` — public aggregate runner installed by setup. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement` to `false`. [VERIFIED: .planning/config.json]

The table below uses the GSD-required ASVS category lens; OWASP's ASVS repository is the authoritative source for current ASVS materials, and planners should avoid claiming formal ASVS certification from this local safety gate alone. [CITED: https://github.com/OWASP/ASVS]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | Yes | Authentication and secret changes are L3/L4 rulebook matches requiring explicit user approval. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| V3 Session Management | Partial | Approval IDs require TTL and one-time use, but this phase does not implement web/app sessions. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md] |
| V4 Access Control | Yes | Hermes/Claude/Codex/User authority boundaries determine who may approve or execute decisions. [VERIFIED: .planning/SPEC.md; AGENTS.md] |
| V5 Input Validation | Yes | Validate project IDs, approval IDs, task IDs, JSON envelopes, strict approve/reject choices, and risk rule input. [VERIFIED: docs/hermes-dev-orchestra/scripts/lib/orch-common.sh; .planning/SPEC.md] |
| V6 Cryptography | Partial | Do not hand-roll crypto; use UUID generation for approval IDs and treat secret modifications as L4. [VERIFIED: local `uuidgen` availability probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Replay of old approval ID | Spoofing / Elevation of Privilege | Enforce one-time use, TTL, `project_id`, and `task_id` binding before writing user decision. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md] |
| Agent under-classifies risky operation | Elevation of Privilege | Hermes static rule floor upgrades risk and audits rulebook override. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Runtime `/tmp` cleanup loses pending decision | Denial of Service / Repudiation | Mirror pending queue in State and final outcomes in Audit. [VERIFIED: .planning/REQUIREMENTS-REV1.md] |
| Ambiguous free-text approval | Spoofing / Tampering | Accept structured approve/reject only; model modify as reject + revised task unless user locks a separate command. [VERIFIED: .planning/SPEC.md] |
| Audit tampering or truncation | Repudiation | Append JSONL, fsync before state transition, rotate by date/size, and query through `orch-audit`. [VERIFIED: .planning/SPEC.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Cross-project approval mix-up | Tampering | Validate `project_id` and `task_id` against pending decision metadata. [VERIFIED: .planning/REQUIREMENTS.md; .planning/SPEC.md] |

## Coverage Matrix Guidance

| Row Source | Matrix Column Guidance | Source |
|------------|------------------------|--------|
| Upstream Hermes Agent command/skill/runtime features | Mark as upstream-native only when Phase 9 summary or local `hermes --help` confirms upstream support. | [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md; local `hermes --help` probe 2026-04-25] |
| `orch-*` helpers, file bus, tmux lifecycle, decision fallback, risk rulebook, smoke fixtures | Mark as adapter-provided when implemented by this repository. | [VERIFIED: .planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-03-SUMMARY.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Remote adapter, audit hardening beyond JSONL/rotation, container isolation, gbrain, dashboard, team approvals | Mark as deferred. | [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

Recommended columns: `Capability`, `Upstream native`, `Adapter-provided`, `Deferred`, `Evidence`, and `Notes`. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]

## Handoff Guidance

| Handoff Area | Ordering | Boundary |
|--------------|----------|----------|
| Remote adapter | 1 | Define transport adapter after Phase 12 local fallback is stable; do not choose Telegram/Discord in v1.1. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Audit hardening | 2 | Production hardening can add stronger immutability, archival, backup, date filters, and integrity checks beyond Phase 12 JSONL/rotation. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |
| Isolation / containers | 3 | Container or Modal-style isolation remains future hardening, not Phase 12 implementation. [VERIFIED: docs/hermes-dev-orchestra/README.md; .planning/REQUIREMENTS.md] |
| Product extensions | 4 | gbrain integration, dashboards, team collaboration, and multi-user approvals remain deferred. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md` — locked Phase 12 decisions, scope, deferred items, and smoke fixture requirements.
- `.planning/REQUIREMENTS.md` — SAFE-01, SAFE-02, DEC-01, DEC-02, VER-01, VER-02, VER-03, and VER-04.
- `.planning/ROADMAP.md` — Phase 12 goal, dependency, and success criteria.
- `.planning/STATE.md` and `.planning/PROJECT.md` — current v1.1 state, constraints, and prior decisions.
- `.planning/SPEC.md` and `.planning/REQUIREMENTS-REV1.md` — risk authority, fallback decision binding, audit requirements, and state/runtime/audit layering.
- `docs/hermes-dev-orchestra/scripts/*` — current helper implementation and Phase 11 integration points.
- `docs/hermes-dev-orchestra/README.md`, `docs/hermes-dev-orchestra/hermes/SOUL.md`, and `docs/hermes-dev-orchestra/skills/*/SKILL.md` — current docs and skill content requiring alignment.
- Phase 9/10/11 context, summaries, and verification artifacts — upstream pin, package layout, helper behavior, and fake CLI validation pattern.
- Local command probes on 2026-04-25 — tool versions, missing `inotifywait`/`shellcheck`/`bats`, and upstream command availability.

### Secondary (MEDIUM confidence)

- OWASP ASVS GitHub repository — official ASVS material source used only to avoid over-claiming ASVS conformance. [CITED: https://github.com/OWASP/ASVS]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — current helper files and local versions were probed. [VERIFIED: local version probe 2026-04-25; docs/hermes-dev-orchestra/scripts/*]
- Architecture: HIGH — Phase 10/11 implementation and Phase 12 context define the exact integration points. [VERIFIED: .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-03-SUMMARY.md; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
- Pitfalls: HIGH — identified by grep against current docs/scripts plus locked decisions. [VERIFIED: rg audit/Telegram/commands probe 2026-04-25]
- Validation: HIGH — D-12-04 locks pure Bash fixtures and prior phases validated fake CLI smoke strategy. [VERIFIED: .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md; .planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-VERIFICATION.md]
- Security: MEDIUM — local controls are clear, but formal ASVS mapping is a planning lens rather than an external certification. [CITED: https://github.com/OWASP/ASVS]

**Research date:** 2026-04-25  
**Valid until:** 2026-05-25 for local repository planning; re-probe upstream `hermes --help` before implementing if upstream Hermes Agent changes. [VERIFIED: local `hermes --help` probe 2026-04-25; .planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md]
