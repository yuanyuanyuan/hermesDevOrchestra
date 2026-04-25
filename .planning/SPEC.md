# Hermes Dev Orchestra — v1 Specification

**Version:** 1.0.0  
**Date:** 2026-04-25  
**Applies to:** REQUIREMENTS.md v1 (60 requirements)  
**Status:** COMPLETE — v1 specification package verified by GSD phases 1-7  

This document specifies the Hermes Dev Orchestra system: a single-developer, multi-project AI development orchestration layer that coordinates Claude Code CLI (supervision/decision) and Codex CLI (execution) through a per-project file bus, with three-layer risk authority and remote decision support.

---

## 0. Specification Package Coverage

### SPEC-01 — Unified specification map

This `SPEC.md` is the unified v1 specification package. Appendix C maps every v1 requirement from `.planning/REQUIREMENTS.md` to a concrete section in this document.

### SPEC-02 — Inline implementable contracts

This document restates the implementable contracts inline. Source materials such as README files, role skills, setup scripts, and design notes are treated as inputs only; no v1 requirement depends on an external document without an equivalent contract in this specification.

### SPEC-03 — Decision envelope schema readiness

The decision envelope is specified in §3 and Appendix B as a schema-ready contract with `rulebook`, `assessment`, `execution`, and `history` fields.

### SPEC-04 — Risk rule table artifact

The v1 static risk rule table is specified in §6 and Appendix A with 10 concrete rules covering database schema, auth, secrets, CI/CD, public API, system commands, dependency updates, file deletion, network config, and cost-sensitive operations.

### SPEC-05 — Acceptance and traceability

Acceptance scenarios are specified in §8, and Appendix C proves requirement-to-section coverage for the complete v1 package.

## 1. Scope and Authority

### SCOPE-01 — Standalone specification package

v1 is a specification package, not a runnable orchestrator implementation. The deliverable is a set of documents that an independent engineer can use to build a compatible Hermes system. Implementation is deferred to v2 per the roadmap in §8.

### SCOPE-02 — Primary persona

The primary user is a single developer managing multiple software projects through SSH into an Ubuntu/Linux host. The developer uses Windows as their local OS and interacts with Hermes via SSH session or tmux reattachment. No team collaboration, shared approvals, or multi-user audit roles are in scope.

### SCOPE-03 — Explicit non-goals (v1)

The following are explicitly excluded from v1:

| Feature | Reason |
|---------|--------|
| `gbrain` integration | User selected standalone spec, not integration into existing gbrain repo |
| Telegram/Discord binding | Remote channel is abstracted (REMOTE-01); concrete adapters deferred to v2 (ADPT-01) |
| Team collaboration platform | v1 persona is single developer |
| AI factory / high-throughput mode | v1 prioritizes safe decision flow over throughput |
| Web/mobile dashboard | SSH/Hermes CLI is the required primary entry |
| Automatic L3/L4 approval | Violates safety premise; high-risk actions require explicit user approval |
| Runnable orchestrator implementation | v1 deliverable is spec + roadmap |
| Push notification to external devices | v1 remote decision requires SSH or active tmux session (REMOTE-05 limitation) |

### AUTH-01 — Actor definitions and authority boundaries

Four actors participate in the system:

| Actor | Role | Scope |
|-------|------|-------|
| **Hermes** | Orchestrator | Task dispatch, bus routing, state snapshots, audit records, escalation routing, final decision writes. Hermes does NOT make technical or architectural decisions. |
| **Claude** | Supervisor | Technical assessment, code review, architecture decisions, risk classification, escalation recommendations. Claude may approve L1/L2 decisions within a single project. |
| **Codex** | Executor | Implementation, testing, refactoring. Codex may challenge risk classifications but cannot override them. |
| **User** | Final arbiter | L3/L4 decisions, policy overrides, manual intervention for stalled tasks. |

### AUTH-02 — What each actor may write, approve, reject, or never approve

- **Hermes** may write: task dispatch records, bus routing metadata, state snapshots, audit records, escalation routing decisions, final decision writes after validation. Hermes never approves technical decisions.
- **Claude** may write: `claude-decision.md`, `review-result.md`, `escalation.md`. Claude may approve L1/L2 technical decisions within a single project. Claude never approves L3/L4 decisions, cross-project decisions, or system-wide changes.
- **Codex** may write: `codex-result.md`, `codex-question.md`. Codex never approves any decision; it executes or challenges.
- **User** may write: decision responses via any channel (SSH CLI, file-based fallback, future adapters). User may approve/reject L3/L4 and override policy.

**Three-layer classification authority:**

1. **Preset Rule Floor (Hermes):** Hermes loads the static risk rule table (RISK-05). The rule table maps operation types to minimum risk levels. Hermes validates every `claude-decision.md` against this table before forwarding. If the rule table mandates minimum L3 but Claude labels L2, Hermes upgrades to L3, appends a `rulebook_override` field to the decision, and records the override in the audit log.
2. **Technical Assessment (Claude):** Claude evaluates the specific context and may upgrade (increase risk level) from the rule table baseline. Claude MAY NOT downgrade below the rule table minimum. Claude's classification is advisory above the floor and binding at the floor.
3. **Execution Challenge (Codex):** Codex reads the assessed level from `claude-decision.md`. If Codex encounters new risk factors during execution, it MAY pause and write a `codex-question.md` requesting re-assessment. This is a challenge, not an override. Hermes routes challenges to Claude. Claude may maintain the original classification or upgrade. The same task permits at most 3 challenge rounds; beyond 3, Hermes marks the task `stalled` and notifies the user for manual intervention.

### AUTH-03 — L3/L4 decisions require explicit user approval

L3 (Danger) and L4 (Critical) risk decisions MUST block the affected project until the user explicitly approves or rejects the proposal. No timeout-based auto-approval is permitted. No agent (Claude, Codex, or Hermes) may auto-approve L3/L4 by fallback or timeout. The default safe action on timeout is **rejection** (see §6.3, RISK-04 REVISED).

---

## 2. Runtime and Commands

### RUNT-01 — Host assumptions

The target runtime environment is:

- **OS**: Ubuntu 22.04+ or equivalent Linux distribution
- **Privileges**: No `sudo` required for installation or operation
- **SSH**: OpenSSH server accessible from Windows client
- **tmux**: >= 3.0 (for persistent PTY sessions)
- **Git**: >= 2.30 (Codex CLI requires a git repository)
- **Node.js**: >= 18 (for Claude Code and Codex CLI)
- **Claude Code CLI**: >= v2.1.110 with `--permission-mode` and hooks support
- **Codex CLI**: >= v0.122.0 with `exec --full-auto` and `--json` support
- **Hermes Agent**: >= v0.10.0 (reference implementation; spec does not depend on Hermes internals)

### RUNT-02 — Safe invocation profiles

**Claude Supervisor invocation:**
```bash
tmux new-session -d -s "hermes-{project-id}-claude" \
  -x 180 -y 40 -c "{project-dir}" \
  "claude --permission-mode auto"
```
- `--permission-mode auto` is required. `--dangerously-skip-permissions` is FORBIDDEN.
- Hooks (settings.json) capture PermissionRequest and Notification events.
- PTY mode is required (`-x 180 -y 40`).

**Codex Executor invocation:**
```bash
tmux new-session -d -s "hermes-{project-id}-codex" \
  -x 180 -y 40 -c "{project-dir}" \
  "codex exec --full-auto --json"
```
- `--full-auto` enables automatic file edit approval within workspace-write sandbox.
- `--json` produces JSON Lines output for programmatic parsing.
- `--dangerously-bypass-approvals-and-sandbox` is FORBIDDEN.
- Codex MUST be invoked inside a git repository.

### RUNT-03 — Directory layout (REVISED per REQUIREMENTS-REV1)

The specification defines a four-layer directory layout. All paths resolve through XDG Base Directory Specification environment variables with deterministic fallbacks. No layer may conflate the path of another layer.

| Layer | Env Var | Fallback | Purpose | Lifetime |
|-------|---------|----------|---------|----------|
| Runtime Bus | `XDG_RUNTIME_DIR` | `/tmp/hermes-orchestra` | Active task files, pending decisions, inter-agent messages | Process-scoped; recreated on Hermes start. **Note:** `XDG_RUNTIME_DIR` (typically `/run/user/$(id -u)`) may be cleared on SSH session logout. For SSH-disconnect survival, implementations MUST either use the `/tmp` fallback as primary or reconstruct Runtime from State + Audit on every reconnection. |
| State | `XDG_STATE_HOME` | `~/.local/state/hermes-orchestra` | Task state machine snapshots, process registry, heartbeat records, session index | Durable; explicit archive or user deletion |
| Audit | `XDG_DATA_HOME` | `~/.local/share/hermes-orchestra` | Completed task audit chains, decision records, evidence files | Durable; archived and optionally compressed |
| Cache | `XDG_CACHE_HOME` | `~/.cache/hermes-orchestra` | Agent output cache, indexes, temporary downloads | Rebuildable; safe to purge anytime |

A `paths.json` manifest written to the State layer on Hermes startup records the resolved absolute path of each layer. All bus readers/writers validate the manifest path before I/O.

### CMD-01 — Command contracts

| Command | Purpose | Input | Output | Idempotency |
|---------|---------|-------|--------|-------------|
| `hermes init <project-id> <project-dir>` | Register a project | project-id, project-dir path | project config JSON | Yes — re-running updates config, does not overwrite state |
| `hermes start <project-id>` | Start Claude + Codex tmux sessions | project-id | session IDs or error | No — creates new sessions; error if already running |
| `hermes stop <project-id>` | Stop sessions for a project | project-id | termination confirmation | Yes — safe to call multiple times |
| `hermes status` | Show all projects and their states | none | JSON array of project status rows | Yes |
| `hermes task <project-id> <task-file>` | Append a task | project-id, task markdown file path | task ID, queued state | Yes — deduplicates by content hash within 5 min |
| `orch-decisions` | List pending local fallback decisions | optional project-id | tabular pending decisions | Yes |
| `orch-approve <approval_id>` | Approve a pending local fallback decision | approval_id | user-authored approved decision envelope | No — approval IDs are one-time use |
| `orch-reject <approval_id>` | Reject a pending local fallback decision | approval_id | user-authored rejected decision envelope | No — approval IDs are one-time use |
| `hermes retry <task-id>` | Retry a stalled/failed task | task-id | new task attempt ID | No — creates new attempt |
| `hermes doctor` | Preflight checks | none | health report JSON | Yes |
| `hermes archive <project-id>` | Archive project state and audit | project-id | archive path | No — destructive to Runtime state |
| `hermes recover` | Recovery procedure after crash | none | recovery report | No — stateful side effects |

### CMD-02 — Command error behavior

Every command returns a structured result:

```json
{
  "success": true,
  "command": "hermes status",
  "timestamp": "2026-04-25T14:30:00Z",
  "data": { ... },
  "error": null
}
```

On failure:
```json
{
  "success": false,
  "command": "hermes start api-gateway",
  "timestamp": "2026-04-25T14:30:00Z",
  "data": null,
  "error": {
    "code": "SESSION_EXISTS",
    "message": "Project api-gateway already has active sessions",
    "suggestion": "Run 'hermes stop api-gateway' first, or use 'hermes status' to inspect."
  }
}
```

Common error codes: `PROJECT_NOT_FOUND`, `SESSION_EXISTS`, `SESSION_NOT_FOUND`, `NOT_GIT_REPO`, `BUS_UNREACHABLE`, `DECISION_NOT_FOUND`, `TASK_NOT_FOUND`, `INVALID_PROJECT_ID`, `PERMISSION_DENIED`.

### CMD-03 — CLI capability probes

Before starting any project, `hermes doctor` verifies:

1. `claude --version` returns >= 2.1.110
2. `codex --version` returns >= 0.122.0
3. `tmux -V` returns >= 3.0
4. `git --version` returns >= 2.30
5. `node --version` returns >= 18.0.0
6. Claude Code authentication: `claude doctor` exits 0
7. Codex authentication: `codex login` status check (or `$OPENAI_API_KEY` set)
8. tmux session creation test: create and destroy a test session
9. Sandbox behavior: `codex exec --full-auto` on a trivial task in a temp git repo
10. JSON output: verify `codex exec --json` produces valid JSON Lines
11. Hooks: verify `.claude/settings.json` PermissionRequest hook writes to expected path

`hermes doctor` returns a JSON report with `checks[]` array; each check has `name`, `passed` (boolean), `detail` (string), and `remediation` (string or null).

---

## 3. File Bus, State, and Audit

### BUS-01 — Canonical protocol

JSON/JSONL is the canonical file-bus protocol. Markdown is a human-readable projection only. Every bus file that carries structured data MUST be valid JSON (single file) or JSON Lines (one JSON object per line). Markdown wrappers MAY be used for human readability but MUST NOT be the source of truth for programmatic consumers.

### BUS-02 — Schema envelopes (REVISED per REQUIREMENTS-REV1)

Every bus message MUST include the following envelope fields:

```json
{
  "schema_version": "1.0",
  "message_id": "uuid-v4",
  "project_id": "string",
  "task_id": "string",
  "correlation_id": "uuid-v4",
  "status": "pending|active|completed|failed|cancelled|stalled",
  "author": "hermes|claude|codex|user",
  "authority": "L1|L2|L3|L4",
  "timestamp": "2026-04-25T14:30:00Z",
  "payload": { ... }
}
```

Message types and their payload schemas:

- **`task.md`** — Task dispatch. Payload: `description` (string), `requirements` (string[]), `constraints` (string), `priority` ("low"|"medium"|"high").
- **`codex-question.md`** — Execution-time question. Payload: `question` (string), `options` (string[]), `context` (object: current_file, line_range, related_files), `urgency` ("LOW"|"MEDIUM"|"HIGH"|"BLOCKING").
- **`claude-decision.md`** — Technical decision. See Appendix B for full decision envelope schema.
- **`escalation.md`** — Risk escalation request. Payload: `level` ("L1"|"L2"|"L3"|"L4"), `type` ("SECURITY"|"ARCHITECTURE"|"PRODUCT_IMPACT"|"DATA_LOSS"), `description` (string), `proposed_action` (string), `impact` (string), `reversible` ("YES"|"NO"|"WITH_DIFFICULTY").
- **`codex-result.md`** — Execution result. Payload: `status` ("COMPLETED"|"PARTIAL"|"FAILED"|"BLOCKED"), `summary` (string), `files_modified` (array of {path, change_description}), `tests` (object: status, coverage, failed_tests), `new_dependencies` (array of {name, version, reason}), `known_issues` (array of {description, severity}), `next_steps` (string[]).
- **`review-result.md`** — Code review output. Payload: `decision` ("APPROVED"|"REJECTED"|"NEEDS_MODIFICATION"), `rationale` (string), `issues` (array of {severity, description, file, line}), `risk_assessment` ("LOW"|"MEDIUM"|"HIGH").
- **`event.jsonl`** — Hook events from Claude Code. Payload: `event_type` ("PermissionRequest"|"Notification"|"SessionStart"|"Stop"), `session` (string), `tool` (string|null), `files` (string[]|null), `timestamp` (ISO8601).

### BUS-03 — Required envelope fields

Every message MUST include: `schema_version`, `message_id`, `project_id`, `task_id`, `correlation_id`, `status`, `author`, `authority`, `timestamp`. Missing fields cause the message to be rejected by the validation gate.

### BUS-04 — Writer/reader ownership

| File | Writer | Readers | Notes |
|------|--------|---------|-------|
| `task.md` | Hermes | Codex, Claude | Overwritten on new task dispatch |
| `codex-question.md` | Codex | Hermes, Claude | Created when Codex pauses; deleted on resolution |
| `claude-decision.md` | Claude, User(via Hermes) | Hermes, Codex | Appended on challenge rounds; see Appendix B for schema |
| `escalation.md` | Claude | Hermes | Created on risk detection; deleted after resolution |
| `codex-result.md` | Codex | Hermes, Claude | Overwritten on each execution attempt |
| `review-result.md` | Claude | Hermes | Written after code review |
| `*.jsonl` (events) | Claude Code hooks | Hermes | Appended; never overwritten |

### BUS-05 — Atomic write, locking, and validation

- **Atomic write**: All bus file writes MUST use write-to-temp + rename pattern. Temp file MUST be in the same filesystem as the target.
- **Locking**: File-level advisory locking via `flock` on a `{filename}.lock` file. Lock timeout: configurable, default 5 seconds; on timeout, Hermes logs a warning and retries once.
- **Stale-message rejection**: Messages older than a configurable threshold (default: 5 minutes) relative to the current task's `last_activity` timestamp are rejected.
- **Correlation checks**: Every message's `correlation_id` MUST match the current task's `task_id` or a known sub-task ID. Mismatches are logged and rejected.
- **Schema validation**: JSON Schema draft-07 validation against the message type's schema. Validation failures are logged to Audit and the message is rejected.
- **Archive rule**: Completed task files (all bus files for a task) are atomically moved to `${AUDIT}/archive/{project-id}/{date}/{task-id}/` after task completion. Archive includes all versions of overwritten files.

### BUS-06 — Physical separation of bus and audit/state (NEW per REQUIREMENTS-REV1)

Bus artifacts and audit/state artifacts are physically separated:

- Runtime bus files MUST NOT be referenced as durable evidence. Before a task or decision is considered complete, its canonical record MUST be atomically migrated to the Audit layer.
- The migration sequence is: (1) write complete record to `${AUDIT}/pending/`, (2) fsync, (3) write a completion marker to the Runtime bus, (4) on next read, the consumer MUST check the Audit layer for the canonical record.
- State snapshots (for recovery) MUST be written to the State layer, never the Runtime layer.
- A validation gate rejects any message whose `author` claims a record exists in Runtime but no matching audit entry is found after a grace period (configurable, default 30 seconds).

### STATE-01 — Task and project states

**Task states:**

```
ready → queued → executing → waiting → reviewing → completed
   ↓        ↓         ↓           ↓          ↓
 cancelled  failed   stalled    recovering
```

| State | Meaning |
|-------|---------|
| `ready` | Task defined but not yet dispatched |
| `queued` | Task in project queue, waiting for agent availability |
| `executing` | Codex is actively working on the task |
| `waiting` | Codex paused for a decision (question or escalation) |
| `reviewing` | Codex completed; Claude is reviewing |
| `completed` | Claude review passed; task done |
| `failed` | Codex or Claude reported failure; not recoverable automatically |
| `cancelled` | User or Hermes cancelled the task |
| `stalled` | Max challenges exceeded or unresolvable deadlock; requires manual intervention |
| `recovering` | Hermes is reconstructing state after restart/crash |

**Project states:**

| State | Meaning |
|-------|---------|
| `inactive` | No active tmux sessions |
| `starting` | Sessions launching |
| `active` | Sessions running, tasks being processed |
| `blocked` | Waiting for user decision (L3/L4) |
| `paused` | User explicitly paused; no new tasks dispatched |
| `error` | Session crash or persistent failure |

### STATE-02 — Valid state transitions

**Task transitions:**

- `ready → queued`: Hermes dispatches task to project queue
- `queued → executing`: Codex picks up task from queue
- `executing → waiting`: Codex writes `codex-question.md` or `escalation.md`
- `waiting → executing`: Decision received, forwarded to Codex
- `executing → reviewing`: Codex writes `codex-result.md`
- `reviewing → completed`: Claude writes `review-result.md` with APPROVED
- `reviewing → failed`: Claude writes REJECTED or Codex reports unrecoverable error
- `executing → failed`: Codex reports unrecoverable error without question
- `any → cancelled`: User or Hermes cancels
- `waiting → stalled`: Max challenges (3) exceeded
- `any → recovering`: Hermes restart detected incomplete task
- `recovering → queued|executing|waiting|failed`: Based on reconstructed state

**Invalid transitions (rejected with audit log):**

- `completed → any`
- `cancelled → any`
- `ready → executing` (must pass through queued)
- `failed → executing` (must use `hermes retry` which creates a new task)

### AUDIT-01 — Durable audit records

Every significant action produces an audit record. Audit records are JSON Lines in `${AUDIT}/audit.jsonl`.

Required fields: `timestamp`, `event_type`, `project_id`, `task_id`, `actor`, `action`, `details`, `correlation_id`.

Event types: `task_created`, `task_dispatched`, `task_started`, `question_raised`, `decision_made`, `escalation_triggered`, `escalation_resolved`, `review_completed`, `task_completed`, `task_failed`, `task_cancelled`, `state_snapshot`, `recovery_started`, `recovery_completed`, `challenge_raised`, `challenge_resolved`, `rulebook_override`, `timeout_rejection`.

Audit records are immutable. The audit log MUST be fsynced before any dependent state change is considered durable.

---

## 4. Multi-Project Scheduling and Isolation

### MULTI-01 — Project registration

Each project has:
- **project_id**: Immutable, user-defined string. Must match regex `^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$` (minimum 3 characters, maximum 32 characters, lowercase alphanumeric and hyphens, must start and end with alphanumeric).
- **canonical_path**: Absolute path to project directory. Must be a git repository.
- **runtime_name**: Sanitized version of project_id used for tmux session names: `hermes-{project_id}-{claude|codex}`.
- **policy**: Per-project configuration including risk timeout, auto-retry count, and allowed sandbox modes.

Project registry is stored in `${STATE}/projects.json`.

### MULTI-02 — Task append while running

A user MAY append a task at any time while other tasks or projects are running, blocked, reviewing, or recovering. The new task enters the `ready` state for its target project. Hermes queues it without interrupting in-progress work.

### MULTI-03 — Task routing and deduplication

- Hermes routes the task to the target project's queue.
- Invalid tasks (missing project_id, non-existent project, empty description) are rejected with error.
- Deduplication: within a configurable window (default: 5 minutes), tasks with identical `description` + `requirements` hash are rejected as duplicates. The user receives the existing task ID.
- On successful append, Hermes returns the task ID, current queue position, and estimated start time (if calculable).

### MULTI-04 — Per-project isolation

Each project has:
- Independent tmux sessions (`hermes-{project_id}-claude`, `hermes-{project_id}-codex`)
- Independent bus root: `${RUNTIME}/{project_id}/`
- Independent logs: `${STATE}/logs/{project_id}/`
- Independent state: `${STATE}/projects/{project_id}.json`
- Independent archive: `${AUDIT}/archive/{project_id}/`
- Environment variable filtering: only `HOME`, `PATH`, `PWD`, `HERMES_PROJECT_ID`, and project-specific env vars are passed to agent tmux sessions.

### MULTI-05 — Scheduler polling and yield

Hermes polls each active project at a configurable interval (default: 5 seconds). The poll sequence:

1. Check tmux session liveness (`tmux has-session -t {name}`)
2. Read project's bus directory for new messages
3. If project is `blocked` (waiting for L3/L4), skip to next project
4. If project has a completed task, trigger Claude review
5. If project is `active` with no pending work, check queue for next task

When one project is blocked, Hermes continues polling other projects. No project monopolizes the scheduler.

### MULTI-06 — Same-repository concurrency

If multiple registered projects point to the same git repository path, Hermes MUST serialize their access. Only one project's Codex session may actively modify files at a time. This is enforced by a repository-level lock file `.hermes-lock` in the repository root.

Future work (v2): worktree-based isolation may allow true parallel access to the same repository.

---

## 5. Agent Protocol and Evidence

### AGENT-01 — Hermes orchestration behavior

Hermes performs the following orchestration functions:

1. **Task dispatch**: Writes `task.md` to target project's bus, updates task state to `queued`.
2. **Process supervision**: Monitors tmux session liveness, restarts crashed sessions with configurable backoff (default: 5s, 10s, 20s, max 60s).
3. **Escalation routing**: Reads `escalation.md`, classifies risk per RISK-05, routes to appropriate channel.
4. **Audit**: Writes audit records for every state transition and significant event.
5. **Archive**: On task completion, moves bus files to Audit archive.
6. **User communication**: Sends status updates via active decision channel (SSH CLI output, or REMOTE-05 fallback, or future adapter).

### AGENT-02 — Claude Supervisor behavior

Claude performs the following supervision functions:

1. **Technical decisions**: Evaluates `codex-question.md` and writes `claude-decision.md` with APPROVED/REJECTED/NEEDS_MODIFICATION.
2. **Risk classification**: Assesses operations against the risk rule table (RISK-05). May upgrade from baseline but NEVER downgrade below the rule table minimum.
3. **Code review**: Reviews `codex-result.md` against checklist (security, dependencies, config changes, code style, error handling, tests, performance).
4. **Escalation recommendations**: Writes `escalation.md` for operations exceeding Claude's approval authority.
5. **Confidence scoring**: Every decision includes `confidence: high|medium|low`.

### AGENT-03 — Codex Executor behavior

Codex performs the following execution functions:

1. **Task intake**: Reads `task.md`, checks out project branch, runs existing tests for baseline.
2. **Implementation**: Writes code, tests, and documentation per task requirements.
3. **Pause protocol**: On ambiguity, conflict, security concern, or scope overrun, writes `codex-question.md` and pauses.
4. **Result reporting**: Writes `codex-result.md` with status, modified files, test results, dependencies, issues, and next steps.
5. **Decision compliance**: Reads `claude-decision.md` and proceeds only if `execution.authority_sufficient` is true.

### AGENT-04 — Codex pause and question

Codex MUST pause and write `codex-question.md` when:
- Task requirements are ambiguous or contradictory
- Multiple valid technical approaches exist and best choice is unclear
- Existing code contradicts task requirements
- Non-code files need modification (config, docs, CI/CD)
- Potential security or performance issues are discovered
- Estimated effort exceeds task scope

The question file MUST include: clear question, enumerated options, current file context, related files, and urgency level (LOW/MEDIUM/HIGH/BLOCKING).

"Pause" means: Codex stops processing new inputs from the task file. The current Codex process is allowed to complete its current operation (e.g., finish writing the current file) before halting. Hermes does not dispatch new tasks to Codex until the question is resolved.

### AGENT-05 — Claude answers low-risk questions

Claude may answer L1/L2 technical questions directly without escalation. The answer is written to `claude-decision.md` with `authority: L1` or `L2`. For L3/L4 questions, Claude MUST escalate via `escalation.md` with sufficient rationale and impact analysis.

### AGENT-06 — Codex proceeds only with sufficient authority

Codex reads `claude-decision.md` and checks `execution.authority_sufficient`. If false, Codex MUST NOT proceed. If the assessed level (from `assessment.assessed_level`) exceeds the grantor's authority, Codex treats this as an insufficient-authority condition and pauses.

### AGENT-07 — Codex challenge mechanism (NEW per REQUIREMENTS-REV1)

- A single task permits at most **3 challenge rounds**. A challenge round: Codex writes `codex-question.md` → Hermes routes to Claude → Claude writes revised `claude-decision.md` → Codex receives revised decision.
- On count == 3, Hermes sets task state to `stalled`, writes audit event, and notifies user.
- A challenge is valid only if it presents **new information** not present in prior rounds. Hermes performs a lightweight deduplication check: if the `codex-question.md` body is substantially similar to the previous challenge (same core question, same options, same context), Hermes rejects the challenge, writes a rejection notice to the Runtime bus, and instructs Codex to proceed with the current decision. The deduplication heuristic is implementation-defined; a reasonable approach is exact match on normalized (whitespace-collapsed, lowercased) content.
- If Claude's revised decision is identical to the previous one (same assessed_level, same conditions, same rationale), Hermes flags it as `no_new_assessment` and increments challenge count without creating a new decision record.

### EVID-01 — Required execution evidence

Every completed task MUST produce the following evidence:
- Changed files list (with before/after hashes)
- Commands run (with exit codes)
- Test results (pass/fail counts, coverage)
- Dependency changes (added/removed/updated)
- Review result (Claude's assessment)
- Residual risks (outstanding concerns)
- Next steps (suggested follow-up tasks)

Evidence is captured in `codex-result.md` and `review-result.md`, then migrated to the Audit layer (per BUS-06).

### EVID-02 — Direct repository evidence

Completion verification MUST use direct repository evidence (git diff, test output, file timestamps). Agent summaries alone are NOT sufficient for final verification. Hermes runs `git diff --stat`, `git status`, and project-specific test commands to verify Codex's claims.

---

## 6. Risk and Remote Decision

### RISK-01 — Risk levels and examples

| Level | Name | Examples | Owner | Default Action | Timeout |
|-------|------|----------|-------|---------------|---------|
| L1 | Notice | Add new dependency, update build script, refactor internal function | Claude (async notify user) | Proceed with notification | Configurable, default 30 min auto-proceed |
| L2 | Warning | Delete old API, modify CI/CD config, breaking internal changes | Claude (async notify user) | Configurable, default 30 min auto-reject | Configurable, default 30 min auto-reject |
| L3 | Danger | System commands, modify auth logic, database schema change | User (blocking) | Block until user response | Configurable, default 24h, then auto-reject |
| L4 | Critical | Delete production data, modify secrets | User (blocking) | Block until user response | Configurable, default 24h, then auto-reject |

"Auto-proceed" for L1 means: the operation continues without blocking; a notification is sent to the user asynchronously. "Auto-reject" means: the decision is rejected, Codex stops the current branch, and the task may be retried by the user.

### RISK-02 — Explicit risk classification

The following operation categories are explicitly classified:

| Category | Minimum Level | Examples |
|----------|---------------|----------|
| Database schema change | L3 | `DROP TABLE`, `ALTER TABLE DROP COLUMN`, migration files |
| Authentication/authorization | L3 | Modify JWT logic, password hashing, session management |
| Secrets/credentials | L4 | Modify `.env`, API keys, certificates, `.gitignore` for secrets |
| CI/CD configuration | L2 | Modify `.github/workflows/`, build scripts, deployment configs |
| Public API change | L2 | Breaking API modifications, OpenAPI spec changes |
| System command | L3 | `sudo`, `docker system prune`, `kubectl delete`, `rm -rf` on non-temp dirs |
| Dependency update | L1 | `npm install`, `pip install`, `cargo add` |
| File deletion (non-temp) | L2 | Delete source files, config files |
| Network configuration | L2 | Modify firewall rules, proxy settings, CORS config |
| Cost-sensitive operation | L2 | Large model API calls, bulk operations |

### RISK-03 — L3/L4 blocking behavior

L3 and L4 decisions block the affected project until the user explicitly approves or rejects the proposal. During the block:

1. The project's state is set to `blocked`.
2. No new tasks are dispatched to this project.
3. Codex's current execution is paused: Hermes stops sending new inputs to Codex. The current Codex process is allowed to complete its current operation before halting.
4. Hermes continues polling other projects.
5. The decision request is written to the active decision channel.

### RISK-04 — Safe defaults for timeout and failure (REVISED per REQUIREMENTS-REV1)

**Timeout:**
- Default L3/L4 timeout: 24 hours (configurable per project).
- On timeout: the decision is automatically **rejected** (not approved).
- Hermes writes a `timeout-rejection` audit record including the original request, elapsed time, and threshold.
- The user MAY reactivate via `hermes retry <task-id>`, which creates a new task attempt.
- Timeout rejection does NOT auto-re-escalate. Re-escalation requires explicit user action.

**Remote channel failure:**
- If a configured remote adapter fails healthcheck, Hermes:
  1. Logs failure to Audit.
  2. Immediately activates file-based fallback channel (REMOTE-05).
  3. Notifies user on next SSH/tmux reconnection.
  4. Retries remote adapter healthcheck at configurable interval (default: 60 seconds).
  5. Does NOT drop pending decisions.

**Ambiguous approval:**
- If user response does not match structured choices, Hermes rejects the response, rewrites the request with clearer prompt.
- If ambiguity persists after 3 attempts, auto-rejects and escalates to manual review via `orch-decisions`.

### RISK-05 — Risk rule table (NEW per REQUIREMENTS-REV1)

The rule table is a static JSON file. Each entry:

```json
{
  "rule_id": "string",
  "pattern": "string",
  "match_criteria": {
    "file_glob": ["string"],
    "command_regex": ["string"],
    "scope": "single_project|cross_project|system"
  },
  "minimum_level": "L1|L2|L3|L4",
  "rationale": "string",
  "overridable": true|false
}
```

See Appendix A for the complete v1 rule table (10+ rules).

Hermes loads the table at startup. On each `claude-decision.md` write, Hermes extracts the operation type and checks matching rules. Multiple rules match → highest `minimum_level` wins. `overridable: false` → Hermes unconditionally enforces the minimum. Rule table version is included in every audit record.

### REMOTE-01 — Abstraction without transport binding

The Remote Decision Channel is defined as an abstract interface. v1 does NOT bind to Telegram, Discord, webhook, email, or any specific transport. The abstraction allows v2 adapters to plug in without changing core logic.

### REMOTE-02 — Interface operations

The Remote Decision Channel interface includes:

| Operation | Description | Input | Output |
|-----------|-------------|-------|--------|
| `notice` | Send non-blocking notification | project_id, message, level | delivery_status |
| `decision_request` | Send blocking decision request | project_id, task_id, decision_id, question, choices[], ttl | delivery_status, request_id |
| `reply` | Receive user response | request_id, choice, timestamp | validation_result |
| `healthcheck` | Check channel health | none | healthy/unhealthy, latency_ms |
| `acknowledgement` | Confirm receipt | request_id | ack_id |
| `timeout` | Enforce TTL | decision_id, ttl | expired boolean |
| `cancellation` | Cancel pending request | decision_id | cancelled boolean |

### REMOTE-03 — Remote approval binding

Every remote approval is bound to:
- `project_id`: The project the decision affects
- `task_id`: The task that triggered the decision
- `risk_event`: The escalation or decision event
- `approval_id`: UUID uniquely identifying this approval request
- `ttl`: Time-to-live in seconds
- `actor_identity`: The channel and user identity that responded
- `structured_choices`: Predefined options (approve/reject)
- `one_time_use`: Each approval_id can be used exactly once; reused IDs are rejected

Note: "modify" is not a predefined choice in v1. If the user wants to modify a proposal, they reject the current decision and the task is retried with updated requirements.

### REMOTE-04 — Hermes validates remote replies

The remote channel never writes canonical bus decisions directly. Hermes:
1. Receives the reply from the channel adapter
2. Validates: approval_id exists, not expired, not already used, project/task match
3. Writes the final decision to `claude-decision.md` with `author: user`
4. Writes an audit record with full provenance (channel, actor, timestamp)

### REMOTE-05 — File-based local fallback (NEW per REQUIREMENTS-REV1)

When no remote adapter is configured, Hermes provides a file-based fallback:

- Decision requests written to `${RUNTIME}/decisions/{project-id}/{decision-id}.request.json`
- User lists pending decisions: `orch-decisions`
- User responds: `orch-approve <approval_id>` or `orch-reject <approval_id>`
- Response written to `${RUNTIME}/decisions/{project-id}/{decision-id}.response.json`
- Hermes polls the decisions directory at configurable interval (default: 5 seconds)
- On read: validates one-time use, TTL, project/task binding, writes final decision to Audit, deletes response file

**Limitation:** This channel is local to the Hermes host. It does NOT push to mobile devices. User must SSH back or keep active tmux session.

---

## 7. Recovery, Observability, and Verification

### OBS-01 — Status inspection

`hermes status` returns a JSON array of project status rows:

```json
{
  "projects": [
    {
      "project_id": "api-gateway",
      "project_state": "active",
      "task": {
        "task_id": "task-uuid",
        "task_state": "executing",
        "description": "Implement JWT auth"
      },
      "sessions": {
        "claude": { "pid": 12345, "alive": true },
        "codex": { "pid": 12346, "alive": true }
      },
      "cwd": "/home/dev/projects/api-gateway",
      "heartbeat_age_ms": 4200,
      "risk_wait": null,
      "last_event": "2026-04-25T14:30:00Z",
      "next_action": "poll_codex_result"
    }
  ]
}
```

Fields: `project_id`, `project_state`, `task` (id, state, description), `sessions` (pid, alive per agent), `cwd`, `heartbeat_age_ms`, `risk_wait` (pending decision id or null), `last_event` (timestamp), `next_action` (what Hermes will do next).

### OBS-02 — Process registry and heartbeat

Hermes maintains a process registry in `${STATE}/registry.json`:

```json
{
  "hermes_pid": 12340,
  "hermes_started": "2026-04-25T14:00:00Z",
  "projects": {
    "api-gateway": {
      "claude_session": { "pid": 12345, "started": "...", "last_heartbeat": "..." },
      "codex_session": { "pid": 12346, "started": "...", "last_heartbeat": "..." }
    }
  }
}
```

Heartbeat protocol:
- Hermes writes its own heartbeat at configurable interval (default: 30 seconds)
- Each tmux session writes heartbeat at configurable interval (default: 60 seconds). Heartbeats are written by a background shell loop inside the tmux session: `while true; do echo '{"hb":...}' >> ${RUNTIME}/{project}/heartbeat.jsonl; sleep 60; done`
- Heartbeat timeout: configurable (default: 180 seconds, i.e., 3 missed beats) triggers recovery
- Remote adapter heartbeats: configurable (default: every 60 seconds, timeout 300 seconds)

### REC-01 — Recovery scenarios

Hermes defines recovery behavior for:

| Scenario | Recovery Action |
|----------|----------------|
| SSH disconnect | tmux sessions survive; Hermes reattaches on next SSH. If using `XDG_RUNTIME_DIR` fallback (not `/tmp`), Runtime may be lost → reconstruct from State + Audit. |
| Hermes restart | Read state snapshot, scan Runtime for new messages, validate and reconstruct (see REC-03) |
| Claude crash | Restart tmux session with configurable backoff; restore context from bus files |
| Codex crash | Restart tmux session; re-queue current task if not completed |
| tmux loss | Sessions gone → mark project `error`; user must `hermes start` |
| Stale bus files | Validate against state snapshot; reject stale per BUS-05 |
| `/tmp` cleanup | Runtime layer lost → recover from State + Audit (per BUS-06) |
| Auth failure | Log to Audit; pause affected project; notify user on reconnection |

### REC-02 — Preserve audit evidence before recovery

Before killing, restarting, or archiving any session:
1. Flush pending audit records to `${AUDIT}/audit.jsonl` with fsync
2. Write recovery-start event to Audit
3. Snapshot current state to `${STATE}/recovery/{timestamp}.json`
4. Only then perform the destructive action

### REC-03 — Recovery procedure (NEW per REQUIREMENTS-REV1)

On Hermes restart or crash:
1. Read most recent state snapshot from State layer into memory.
2. Scan Runtime layer for bus files newer than snapshot timestamp.
3. For each newer file: validate schema and correlation ID against reconstructed state.
4. Reject files with: unsupported schema version, correlation ID referencing non-existent task, duplicate message ID, or timestamp predating snapshot by more than configurable threshold (default: 5 minutes).
5. Write recovery event to Audit before resuming scheduling.

---

## 8. Verification and Handoff

### VERIFY-01 — Acceptance scenarios

**Scenario 1: Happy path task execution**
- Initial: Project registered, sessions running, no active tasks
- Input: User appends task "Implement user registration API"
- Expected: Task queued → dispatched → Codex executes → writes result → Claude reviews → approves → task completed → bus files archived → audit records complete
- Pass criteria: `hermes status` shows task `completed`; Audit has `task_completed` event; git shows expected changes

**Scenario 2: Codex question**
- Initial: Task executing
- Input: Codex encounters ambiguity, writes `codex-question.md`
- Expected: Hermes detects question → forwards to Claude → Claude writes decision → Hermes forwards to Codex → Codex resumes
- Pass criteria: Task state transitions: `executing → waiting → executing`; Audit has `question_raised` and `decision_made` events

**Scenario 3: Claude escalation**
- Initial: Codex proposes database schema change
- Input: Claude detects risk, writes `escalation.md` (L3)
- Expected: Hermes detects escalation → classifies L3 → blocks project → writes decision request → waits for user
- Pass criteria: Project state `blocked`; decision request file exists; no Codex execution continues

**Scenario 4: L3/L4 block and resolution**
- Initial: Project blocked on L3 escalation
- Input: User approves via `orch-approve <approval_id>`
- Expected: Hermes validates approval → writes decision → unblocks project → Codex resumes
- Pass criteria: Project state `active`; Audit has `escalation_resolved`; task completes

**Scenario 5: Append-while-running**
- Initial: Project A has active task; Project B idle
- Input: User appends task to Project A while Project A is executing
- Expected: New task queued for Project A; Hermes continues current task; no interruption
- Pass criteria: `hermes status` shows two tasks for Project A (one executing, one queued)

**Scenario 6: Multi-project block and yield**
- Initial: Projects A and B both active
- Input: Project A hits L3 escalation and blocks
- Expected: Hermes continues polling Project B; Project A remains blocked
- Pass criteria: Project A `blocked`, Project B `active`; both show progress in audit

**Scenario 7: Stale approval rejection**
- Initial: Decision request pending
- Input: User approves a decision whose TTL has expired
- Expected: Hermes rejects stale approval, writes rejection audit, decision auto-rejected per RISK-04
- Pass criteria: `success: false` with `DECISION_EXPIRED` error; no state change

**Scenario 8: Process restart recovery**
- Initial: Hermes running, Project A mid-task
- Input: Hermes process killed and restarted
- Expected: Hermes reads state snapshot → scans Runtime → validates messages → reconstructs state → resumes polling
- Pass criteria: `hermes status` shows reconstructed state matching pre-crash; Audit has `recovery_completed`

**Scenario 9: `/tmp` cleanup recovery**
- Initial: Runtime layer has active bus files
- Input: System cleans `/tmp` (simulated by deleting Runtime directory)
- Expected: Hermes detects missing Runtime → reconstructs from State + Audit → recreates Runtime with validated state
- Pass criteria: No data loss; all completed tasks have Audit records; in-progress tasks recoverable

### VERIFY-02 — Scenario structure

Each acceptance scenario includes:
- **Initial state**: Project states, active sessions, queue contents
- **Inputs**: User commands, agent actions, external events
- **Expected bus messages**: Which files are written, in what order, with what content
- **Expected state transitions**: Task and project state changes
- **Expected audit records**: Which events are logged
- **Pass/fail criteria**: Observable conditions that confirm success

### HANDOFF-01 — Roadmap ordering by protocol dependencies

Implementation phases must be ordered by protocol dependencies:

1. **Phase 1: Core protocol** — File bus, message schema, path layout (BUS-01..06, RUNT-03)
2. **Phase 2: State machine** — Task/project states, transitions, registry (STATE-01..02, OBS-01..02)
3. **Phase 3: Command shell** — CLI commands, error handling, doctor (CMD-01..03)
4. **Phase 4: Single-project execution** — Task dispatch, Codex runner, Claude review (AGENT-01..03, EVID-01..02)
5. **Phase 5: Risk and escalation** — Rule table, escalation routing, L3/L4 blocking (RISK-01..05)
6. **Phase 6: Remote decision** — Fallback channel, abstract interface (REMOTE-01..05)
7. **Phase 7: Multi-project scheduling** — Project registry, queue, polling, yield (MULTI-01..06)
8. **Phase 8: Recovery** — Crash recovery, `/tmp` cleanup, state reconstruction (REC-01..03)
9. **Phase 9: Verification** — Acceptance scenarios, integration tests (VERIFY-01..02)

### HANDOFF-02 — Future assumptions requiring research

| Assumption | Risk | Mitigation |
|------------|------|------------|
| Hermes Agent API stability (v0.10.0+) | API may change | Monitor Hermes changelog; abstract Hermes calls behind interface |
| Claude Code CLI drift | Hook formats, flags change | Pin version in doctor; test hooks on upgrade |
| Codex CLI drift | `--full-auto` behavior change | Same as above |
| Remote adapter details | v2 needs concrete transport | Interface is already abstracted; adapters are pluggable |
| SQLite schema for durable state | v2 may replace JSON files | Design schema with migration in mind |
| Unattended-mode safety | v2 feature; needs budgets | Defer to v2 spec |

---

## 9. Out of Scope (v1)

| Feature | Reason | Deferred To |
|---------|--------|-------------|
| Runnable orchestrator implementation | v1 is spec only | v2 IMPL-01..04 |
| Telegram/Discord concrete adapter | Abstract interface only | v2 ADPT-01..03 |
| `gbrain` integration | Standalone spec chosen | v2 EXT-01 |
| Team collaboration platform | Single developer persona | v2 EXT-04 |
| AI factory / high-throughput | Safety over throughput | v2 EXT-05 |
| Web/mobile dashboard | CLI is primary entry | v2 EXT-02 |
| Automatic L3/L4 approval | Safety violation | Never |
| Markdown as canonical protocol | JSON/JSONL is canonical | Never |
| tmux scrollback as source of truth | Bus protocol is source | Never |
| Unrestricted unattended execution | Needs safety budgets | v2 EXT-05 |
| Push notification to external devices | v1 requires SSH/tmux session | v2 ADPT-01 |

---

## Appendix A: Risk Rule Table (v1)

```json
[
  {
    "rule_id": "R001",
    "pattern": "database_schema_change",
    "match_criteria": {
      "file_glob": ["*migration*", "*schema*", "*.sql"],
      "command_regex": ["DROP", "ALTER", "CREATE.*TABLE"],
      "scope": "single_project"
    },
    "minimum_level": "L3",
    "rationale": "Database schema changes affect data integrity and rollback complexity",
    "overridable": false
  },
  {
    "rule_id": "R002",
    "pattern": "authentication_change",
    "match_criteria": {
      "file_glob": ["*auth*", "*login*", "*session*", "*jwt*", "*password*"],
      "command_regex": [],
      "scope": "single_project"
    },
    "minimum_level": "L3",
    "rationale": "Authentication changes affect security posture and user access",
    "overridable": false
  },
  {
    "rule_id": "R003",
    "pattern": "secret_handling",
    "match_criteria": {
      "file_glob": [".env*", "*secret*", "*key*", "*credential*", "*.pem"],
      "command_regex": [],
      "scope": "single_project"
    },
    "minimum_level": "L4",
    "rationale": "Secret exposure is irreversible and may require rotation of production credentials",
    "overridable": false
  },
  {
    "rule_id": "R004",
    "pattern": "cicd_change",
    "match_criteria": {
      "file_glob": [".github/workflows/*", ".gitlab-ci*", "Jenkinsfile", "docker-compose*"],
      "command_regex": [],
      "scope": "single_project"
    },
    "minimum_level": "L2",
    "rationale": "CI/CD changes affect build and deployment pipelines",
    "overridable": true
  },
  {
    "rule_id": "R005",
    "pattern": "public_api_change",
    "match_criteria": {
      "file_glob": ["*api*", "*openapi*", "*swagger*", "*endpoint*"],
      "command_regex": [],
      "scope": "single_project"
    },
    "minimum_level": "L2",
    "rationale": "Public API changes affect consumers and may break compatibility",
    "overridable": true
  },
  {
    "rule_id": "R006",
    "pattern": "system_command",
    "match_criteria": {
      "file_glob": [],
      "command_regex": ["^sudo\\b", "^docker system prune", "^kubectl delete", "^chmod 777\\s+/"],
      "scope": "system"
    },
    "minimum_level": "L3",
    "rationale": "System commands can affect host stability and security",
    "overridable": false
  },
  {
    "rule_id": "R007",
    "pattern": "dependency_update",
    "match_criteria": {
      "file_glob": ["package.json", "requirements.txt", "Cargo.toml", "go.mod", "pom.xml"],
      "command_regex": ["npm install", "pip install", "cargo add", "go get"],
      "scope": "single_project"
    },
    "minimum_level": "L1",
    "rationale": "New dependencies introduce supply chain risk but are generally reversible",
    "overridable": true
  },
  {
    "rule_id": "R008",
    "pattern": "file_deletion",
    "match_criteria": {
      "file_glob": [],
      "command_regex": ["^rm -rf\\s+(/|\\.|\\.\\.)"],
      "scope": "single_project"
    },
    "minimum_level": "L2",
    "rationale": "File deletion may remove important source files or configuration",
    "overridable": true
  },
  {
    "rule_id": "R009",
    "pattern": "network_config",
    "match_criteria": {
      "file_glob": ["*proxy*", "*cors*", "*firewall*", "*nginx*"],
      "command_regex": [],
      "scope": "single_project"
    },
    "minimum_level": "L2",
    "rationale": "Network changes affect accessibility and security boundaries",
    "overridable": true
  },
  {
    "rule_id": "R010",
    "pattern": "cost_sensitive",
    "match_criteria": {
      "file_glob": [],
      "command_regex": ["batch.*process", "bulk.*operation", "large.*model"],
      "scope": "single_project"
    },
    "minimum_level": "L2",
    "rationale": "Expensive operations may incur unexpected costs",
    "overridable": true
  }
]
```

---

## Appendix B: Decision Envelope Type Definition

```typescript
interface HermesDecision {
  schema_version: "1.0";
  message_id: string;        // UUID v4
  project_id: string;        // regex: ^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$
  task_id: string;           // UUID v4
  correlation_id: string;    // UUID v4
  timestamp: string;         // ISO 8601
  author: "claude" | "user" | "hermes";
  authority: "L1" | "L2" | "L3" | "L4";
  decision_type: "risk_classification" | "technical_decision" | "implementation_approval" | "user_override";
  rulebook: {
    version: string;
    matched_rules: string[];
    baseline_level: "L1" | "L2" | "L3" | "L4";
    overridable: boolean;
  };
  assessment: {
    assessed_level: "L1" | "L2" | "L3" | "L4";
    escalation_required: boolean;
    escalation_reason?: string;
    confidence: "high" | "medium" | "low";
    conditions?: string[];
  };
  execution: {
    authority_sufficient: boolean;
    granted_by?: "claude" | "user";
    granted_at?: string;     // ISO 8601
    expires_at?: string;     // ISO 8601
    challenge_count: number; // 0-3
    max_challenges: 3;
  };
  history: Array<{
    event: string;
    actor: "claude" | "user" | "hermes" | "codex";
    timestamp: string;       // ISO 8601
    level: "L1" | "L2" | "L3" | "L4";
  }>;
}
```

For JSON Schema validation, use draft-07 with the structural constraints above. `format: "uuid"` and `format: "date-time"` require a validator that supports the `format` keyword (e.g., ajv with format plugin).

---

## Appendix C: Traceability Table

| Requirement | Section | Status |
|-------------|---------|--------|
| SPEC-01 | §0, Appendix C | Specified |
| SPEC-02 | §0 | Specified |
| SPEC-03 | §0, §3, Appendix B | Specified |
| SPEC-04 | §0, §6, Appendix A | Specified |
| SPEC-05 | §0, §8, Appendix C | Specified |
| SCOPE-01 | §1 | Specified |
| SCOPE-02 | §1 | Specified |
| SCOPE-03 | §1, §9 | Specified |
| AUTH-01 | §1 | Specified |
| AUTH-02 | §1 | Specified |
| AUTH-03 | §1, §6 | Specified |
| RUNT-01 | §2 | Specified |
| RUNT-02 | §2 | Specified |
| RUNT-03 | §2 | Specified (REVISED) |
| CMD-01 | §2 | Specified |
| CMD-02 | §2 | Specified |
| CMD-03 | §2 | Specified |
| BUS-01 | §3 | Specified |
| BUS-02 | §3 | Specified (REVISED) |
| BUS-03 | §3 | Specified |
| BUS-04 | §3 | Specified |
| BUS-05 | §3 | Specified |
| BUS-06 | §3 | Specified (NEW) |
| STATE-01 | §3 | Specified |
| STATE-02 | §3 | Specified |
| AUDIT-01 | §3 | Specified |
| MULTI-01 | §4 | Specified |
| MULTI-02 | §4 | Specified |
| MULTI-03 | §4 | Specified |
| MULTI-04 | §4 | Specified |
| MULTI-05 | §4 | Specified |
| MULTI-06 | §4 | Specified |
| AGENT-01 | §5 | Specified |
| AGENT-02 | §5 | Specified |
| AGENT-03 | §5 | Specified |
| AGENT-04 | §5 | Specified |
| AGENT-05 | §5 | Specified |
| AGENT-06 | §5 | Specified |
| AGENT-07 | §5 | Specified (NEW) |
| EVID-01 | §5 | Specified |
| EVID-02 | §5 | Specified |
| RISK-01 | §6 | Specified |
| RISK-02 | §6 | Specified |
| RISK-03 | §6 | Specified |
| RISK-04 | §6 | Specified (REVISED) |
| RISK-05 | §6, Appendix A | Specified (NEW) |
| REMOTE-01 | §6 | Specified |
| REMOTE-02 | §6 | Specified |
| REMOTE-03 | §6 | Specified |
| REMOTE-04 | §6 | Specified |
| REMOTE-05 | §6 | Specified (NEW) |
| OBS-01 | §7 | Specified |
| OBS-02 | §7 | Specified |
| REC-01 | §7 | Specified |
| REC-02 | §7 | Specified |
| REC-03 | §7 | Specified (NEW) |
| VERIFY-01 | §8 | Specified |
| VERIFY-02 | §8 | Specified |
| HANDOFF-01 | §8 | Specified |
| HANDOFF-02 | §8 | Specified |

**Coverage:** 60/60 v1 requirements specified.

---

*Specification generated: 2026-04-25*  
*Based on: REQUIREMENTS.md v1 (60 requirements)*  
*Input materials: README.md, SOUL.md, dev-orchestra/SKILL.md, claude-supervisor/SKILL.md, codex-executor/SKILL.md, escalation-handler/SKILL.md, setup.sh, settings.json*  
*Design doc: ~/.gstack/projects/hermes/stark-main-design-20260425.md*
