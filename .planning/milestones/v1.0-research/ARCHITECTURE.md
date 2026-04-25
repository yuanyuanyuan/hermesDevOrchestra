# Architecture Patterns: Hermes Dev Orchestra

**Domain:** Local AI development orchestration for one developer managing multiple projects  
**Researched:** 2026-04-25  
**Confidence:** HIGH for local specification architecture; MEDIUM for exact CLI feature behavior until implementation verifies installed versions

## Recommendation

v1 should specify Hermes Dev Orchestra as a **three-agent control plane over a per-project file bus**:

1. **Hermes Orchestrator** owns project/task state, process lifecycle, scheduling, risk escalation, audit logging, and user communication.
2. **Claude Supervisor** owns technical judgment: architecture choices, code review, risk classification, and decisions that are not product/security/system-dangerous.
3. **Codex Executor** owns implementation: code edits, tests, refactors, result reporting, and pausing when uncertainty exceeds executor authority.

The spec should make the **file bus the source of truth**, not tmux transcripts or chat history. tmux is the process envelope; Markdown/JSON files are the protocol.

## System Shape

```text
User over SSH / Hermes CLI
        │
        │ blocking clarify / async notices
        ▼
Remote Decision Channel abstraction
        │
        ▼
Hermes Orchestrator
  ├─ Project registry + scheduler
  ├─ File-bus writer/reader
  ├─ tmux/process supervisor
  ├─ Escalation gatekeeper
  ├─ Audit/archive manager
  └─ Remote channel router
        │
        ├── /tmp/hermes-orchestra/{project}/  per-project bus
        │
        ├── tmux: hermes-{project}-claude  → Claude Supervisor
        │
        └── tmux: hermes-{project}-codex   → Codex Executor
```

## Component Boundaries

| Component | Owns | Reads | Writes | Must Not Do |
|-----------|------|-------|--------|-------------|
| User Entry | Product intent and final L3/L4 decisions | Status summaries, decision prompts | CLI tasks, remote replies | Depend on Telegram as required transport |
| Hermes Orchestrator | Global state, project routing, process lifecycle, escalation policy | All bus files, process registry, hook events | `task.md`, `project-state.json`, final `claude-decision.md`, `audit.log`, archives | Implement code, make deep technical design alone, auto-approve L3/L4 |
| Project Runtime | One project workspace plus isolated process pair | Project config, bus directory | tmux sessions, `.claude/settings.json` | Share sessions or bus files across projects |
| Claude Supervisor | Technical decisions, review, risk classification | `task.md`, `codex-question.md`, `codex-result.md` | `claude-decision.md`, `review-result.md`, `escalation.md` | Approve destructive, credential, production-data, or product-direction changes |
| Codex Executor | Code implementation and verification | `task.md`, `claude-decision.md` | `codex-question.md`, `codex-result.md` | Decide architecture/security/dependency policy alone; bypass sandbox approvals |
| Remote Decision Channel | Transport abstraction for notices and choices | Hermes decision requests | Structured replies to Hermes | Write file-bus files directly or accept ambiguous L3/L4 responses |
| Hook/Event Collector | Observability from Claude lifecycle events | Claude hook payloads | `/tmp/hermes-orchestra/claude-events.jsonl` | Act as the canonical state store |
| Audit/Archive | Durable accountability and post-task trace | Completed bus files, escalation outcomes | `audit.log`, task archives | Keep only `/tmp` copies for critical audit history |

## File-Bus Contract

### Directory Layout

```text
/tmp/hermes-orchestra/
  audit.log                    # global append-only risk/user-decision log
  claude-events.jsonl          # global hook/event stream
  {project}/
    project-state.json         # Hermes-owned state snapshot
    task.md                    # active task from Hermes to Codex
    codex-question.md          # active question from Codex
    claude-decision.md         # active technical or user-backed decision
    escalation.md              # active risk escalation from Claude/Hermes
    codex-result.md            # active execution result from Codex
    review-result.md           # active review result from Claude
    final-log.txt              # optional captured tmux/process tail
    archive/{task_id}/...      # immutable completed task bundle
```

### Protocol Rules

- **One canonical project id:** all filenames, tmux sessions, task prefixes, remote messages, and audit entries use the same sanitized `{project}`.
- **Common envelope:** every Markdown file should start with frontmatter containing `schema_version`, `project`, `task_id`, `correlation_id`, `status`, `writer`, `created_at`, and `updated_at`.
- **Atomic writes:** writers create `{file}.tmp` and rename to `{file}`; consumers ignore partial files and mismatched `correlation_id`.
- **Single writer per file:** ownership is fixed by contract; Hermes is the only component that may write user-final decisions.
- **Status-first parsing:** agents should parse frontmatter/status before freeform Markdown.
- **Stale-file safety:** a new task must rotate old active files into `archive/{task_id}` or mark them stale before dispatch.
- **Events are observational:** `claude-events.jsonl` and terminal logs help diagnostics, but state transitions come from bus files and `project-state.json`.

### File Contracts

| File | Writer | Consumer | Required Status Values | Purpose |
|------|--------|----------|------------------------|---------|
| `project-state.json` | Hermes | All components | `READY`, `DISPATCHED`, `EXECUTING`, `AWAITING_CLAUDE`, `AWAITING_USER`, `REVIEWING`, `COMPLETED`, `FAILED`, `CANCELLED`, `RECOVERING` | Source-of-truth task/process state |
| `task.md` | Hermes | Codex, Claude | `PENDING`, `DISPATCHED`, `RUNNING`, `CANCELLED` | Task description, constraints, allowed scope, verification expectations |
| `codex-question.md` | Codex | Hermes, Claude | `OPEN`, `ANSWERED`, `ESCALATED`, `CANCELLED` | Pause point when executor needs guidance |
| `claude-decision.md` | Claude or Hermes | Codex, Hermes, Claude | `APPROVED`, `REJECTED`, `NEEDS_MODIFICATION`, `NEEDS_ESCALATION` | Technical decision or user-final approval/denial |
| `escalation.md` | Claude, optionally Hermes | Hermes | `OPEN`, `NOTIFIED`, `WAITING_USER`, `APPROVED`, `REJECTED`, `TIMEOUT` | Risk request requiring Hermes policy handling |
| `codex-result.md` | Codex | Hermes, Claude | `COMPLETED`, `PARTIAL`, `FAILED`, `BLOCKED` | Changed files, tests, dependencies, known issues |
| `review-result.md` | Claude | Hermes, Codex | `APPROVED`, `CHANGES_REQUESTED`, `REJECTED`, `ESCALATED` | Code review and release/readiness recommendation |

## Task State Machine

```text
UNINITIALIZED
  └─ orch-init succeeds
READY
  └─ Hermes writes task.md
DISPATCHED
  └─ Codex starts task
EXECUTING
  ├─ Codex writes codex-question.md ──────────────┐
  ├─ Codex writes codex-result.md                 │
  └─ process failure                              │
AWAITING_CLAUDE                                   │
  ├─ Claude writes claude-decision.md ──┐          │
  ├─ Claude writes escalation.md        │          │
  └─ timeout/process failure            │          │
AWAITING_USER                            │          │
  ├─ User approves/rejects/modifies ────┘          │
  └─ L1/L2 timeout policy                          │
EXECUTING ◄────────────────────────────────────────┘
  └─ Codex writes codex-result.md
REVIEWING
  ├─ Claude approves → COMPLETED
  ├─ Claude requests changes → EXECUTING
  ├─ Claude escalates → AWAITING_USER
  └─ Claude rejects → FAILED
COMPLETED / FAILED / CANCELLED
  └─ Hermes archives bus files and updates todo
```

### State Ownership

- Hermes is the only writer of `project-state.json`.
- Claude and Codex signal transitions by writing their owned bus files.
- Hermes validates every transition against the state machine before notifying another process.
- If a project enters `AWAITING_USER`, the scheduler must continue polling other projects.

## Process Lifecycle

### Project Initialization

1. Validate prerequisites: `git`, `node`, `python3`, `tmux`, Hermes, Claude Code, Codex, and required authentication.
2. Validate or initialize a git repository because Codex requires project git context.
3. Create `/tmp/hermes-orchestra/{project}` and persistent project metadata under `~/.hermes-orchestra/`.
4. Copy `.claude/settings.json` into the project.
5. Write `project-state.json` as `READY`.

### Session Startup

- Start two named tmux sessions per project:
  - `hermes-{project}-claude`
  - `hermes-{project}-codex`
- Require PTY/tmux for long-running interactive flows.
- Use `codex exec --full-auto --json` for execution, but keep sandbox bypass flags forbidden.
- Prefer file-bus state over long terminal context; print-mode Claude is allowed for one-shot review, but outputs must be written back to bus files.

### Monitoring and Recovery

- Hermes polls process registry/tmux and bus file mtimes.
- Claude hooks append `PermissionRequest`, `Notification`, `SessionStart`, and `Stop` events to `claude-events.jsonl`.
- On SSH disconnect, tmux sessions survive; on Hermes restart, recover by reading `project-state.json`, active bus files, tmux session list, and archives.
- On `/tmp` cleanup, critical audit/history must be restorable from `~/.hermes-orchestra/logs` or `backups`; v1 should specify backup cadence.

### Shutdown and Archive

1. Capture final tmux/process log tail.
2. Ensure `codex-result.md` and `review-result.md` exist or record explicit failure.
3. Archive active bus files to `archive/{task_id}`.
4. Update todo/project state to terminal status.
5. Stop tmux sessions only when no active task remains or user requested shutdown.

## Remote Decision Channel Abstraction

v1 should not mention Telegram as a required dependency. It should define a transport-neutral interface:

| Operation | Input | Output | Required Behavior |
|-----------|-------|--------|-------------------|
| `send_notice` | project, task_id, level, summary, details_url/text | message_id | Non-blocking, project-prefixed, audit reference |
| `request_decision` | project, task_id, level, prompt, choices, timeout_policy, correlation_id | request_id | Blocking for L3/L4, choices rendered clearly |
| `receive_reply` | request_id or correlation_id | structured decision | Authorized actor only, idempotent, timestamped |
| `healthcheck` | channel config | healthy/unhealthy + reason | Used before relying on remote channel |
| `acknowledge` | request_id, outcome | delivery status | Confirms user decision was applied |

### Channel Rules

- SSH/Hermes CLI `clarify()` is the required baseline channel.
- Remote adapters are optional: Telegram, Discord, Matrix, email, mobile push, or future Hermes gateway.
- L3/L4 prompts must offer explicit choices: approve, modify with constraints, reject. Freeform-only approval is invalid.
- The channel never writes `claude-decision.md`; Hermes translates a validated reply into a bus decision and audit entry.
- If all remote channels fail, L3/L4 stay blocked. L1/L2 follow timeout policy.

## Risk Escalation Flow

| Level | Owner | Examples | Default Behavior | User Required |
|-------|-------|----------|------------------|---------------|
| L0 Technical | Claude | implementation detail, API style, local refactor | Claude decides; Codex continues | No |
| L1 Notice | Hermes policy after Claude flag | new dependency, build script edit | Async notice; proceed only if reversible and within task scope | No |
| L2 Warning | Hermes policy after Claude flag | schema change, compatibility break, config/CI change | Notify, remind, default reject or safe alternative on timeout | Maybe |
| L3 Danger | User through Hermes | auth logic, secret handling, system-level command | Stop project execution, create git checkpoint, block | Yes |
| L4 Critical | User through Hermes | production data deletion, `sudo`, `DROP TABLE`, credential mutation | Hard block, urgent multi-channel request, no timeout approval | Yes |

### Escalation Sequence

1. Codex pauses and writes `codex-question.md`, or Claude detects risk during review.
2. Claude writes `claude-decision.md` with `NEEDS_ESCALATION` and/or writes `escalation.md`.
3. Hermes sets `project-state.json` to `AWAITING_USER` for L3/L4 or policy-managed wait for L1/L2.
4. Hermes sends remote/CLI decision request with project, impact, reversibility, recommended option, and timeout policy.
5. Hermes records the user or timeout decision in `audit.log`.
6. Hermes writes final `claude-decision.md` with `Authority: User Final Approval`, `User Final Denial`, or `Hermes Auto-Reject`.
7. Codex continues, modifies scope, rolls back, or exits according to that decision.

## Build / Specification Order Implications

Roadmap phases should be ordered by protocol dependencies, not UI convenience:

1. **Architecture glossary and IDs** — define project id, task id, correlation id, risk levels, state enums, and authority boundaries.
2. **File-bus protocol** — schemas, examples, atomic-write rules, archive rules, and stale-file handling.
3. **State machine and scheduler rules** — project/task transitions, blocked-project yielding, recovery semantics.
4. **Process lifecycle contract** — `orch-init`, `orch-start`, `orch-stop`, `orch-status`, tmux naming, PTY requirements, health checks.
5. **Agent protocol prompts/skills** — Hermes, Claude, Codex, escalation handler behavior mapped to bus files.
6. **Remote Decision Channel interface** — CLI baseline first, optional adapters second; no Telegram-specific core assumptions.
7. **Verification and acceptance suite** — simulation fixtures for questions, review, escalation, timeouts, restart, and `/tmp` cleanup.

Do not implement adapters, helper scripts, or rich notifications before the file-bus/state-machine contracts are frozen.

## Verification Hooks

| Hook | What It Verifies | Failure It Catches |
|------|------------------|--------------------|
| Schema validator | Frontmatter fields, status enum, writer ownership | malformed/stale bus files |
| Transition validator | `project-state.json` changes follow allowed graph | invalid jumps such as `EXECUTING → COMPLETED` without review |
| Correlation check | every active file matches current `task_id` and `correlation_id` | old decisions applied to new task |
| Process health check | tmux sessions exist and are responsive | SSH/tmux/process drift |
| Hook event monitor | Claude `PermissionRequest` and `Stop` events appear | disabled/misconfigured `.claude/settings.json` |
| Audit checker | every L2-L4 request has outcome in `audit.log` | unaudited dangerous operation |
| Remote channel healthcheck | adapter connectivity and authorization | blocked decisions lost in transport |
| Archive checker | terminal tasks have immutable archive bundle | lost post-mortem context |

## Failure Modes to Design For

| Failure Mode | Risk | Spec Mitigation |
|--------------|------|-----------------|
| Partial file write | Agent reads incomplete instruction | atomic write + rename only |
| Stale decision file | Codex follows old approval | `task_id`/`correlation_id` required everywhere |
| Project name collision | Cross-project contamination | sanitized unique project id registry |
| Missing PTY | Claude/Codex hangs | tmux/PTY required for persistent sessions |
| `/tmp` cleanup | Bus/audit loss | archive and audit backup to `~/.hermes-orchestra/` |
| SSH disconnect | User thinks work stopped | tmux persistence and recovery status command |
| Remote channel outage | L3/L4 prompt never delivered | CLI baseline plus channel health and blocked-safe state |
| Unauthorized remote reply | Dangerous approval spoofing | adapter authorization and signed/recorded actor identity |
| Hook env mismatch | Events lack project/session identity | v1 must define canonical `HERMES_PROJECT` and `HERMES_SESSION_NAME`; do not infer only from `basename $PWD` |
| Codex sandbox bypass | Unbounded system writes | forbid bypass flags; require escalation for network/system operations |
| Output truncation | Lost result context | JSONL result parsing, final bus summaries, captured log tail |

## Sources

- `.planning/PROJECT.md`
- `docs/hermes-dev-orchestra/README.md`
- `docs/hermes-dev-orchestra/hermes/SOUL.md`
- `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md`
- `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md`
- `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md`
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md`
- `docs/hermes-dev-orchestra/scripts/setup.sh`
- `docs/hermes-dev-orchestra/claude-config/settings.json`
