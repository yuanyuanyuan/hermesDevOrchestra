# Requirements: Hermes Dev Orchestra

**Defined:** 2026-04-25  
**Core Value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。

## v1 Requirements

Requirements for the initial specification package. Each requirement defines a checkable contract or document section that later roadmap phases must cover.

### Specification Deliverables

- [ ] **SPEC-01**: The specification package includes a unified `SPEC.md` that maps every v1 requirement to at least one concrete specification section.
- [ ] **SPEC-02**: `SPEC.md` resolves referenced ideas inline; no v1 requirement relies on “as described in README/SKILL.md” without restating the implementable contract.
- [ ] **SPEC-03**: The decision envelope is specified as JSON Schema draft-07 or an equivalent schema-ready definition, including rulebook, assessment, execution, and history fields.
- [ ] **SPEC-04**: The risk rule table is provided as a JSON artifact or appendix with at least 10 concrete rules covering database schema, auth changes, secret handling, CI/CD, public API, system commands, dependency updates, file deletion, network config, and cost-sensitive operations.
- [ ] **SPEC-05**: The specification package includes acceptance scenarios and traceability proving complete coverage of v1 requirements, including happy path, Codex question, Claude escalation, L3/L4 block, append-while-running, multi-project block/yield, and process restart.

### Scope and Authority

- [ ] **SCOPE-01**: User can understand that v1 is a standalone specification package, not a runnable orchestrator implementation.
- [ ] **SCOPE-02**: User can identify the primary persona as a single developer managing multiple projects through SSH/Hermes CLI.
- [ ] **SCOPE-03**: User can see explicit non-goals for v1, including no `gbrain` integration, no Telegram binding, no team platform, no AI factory/high-throughput mode, no concrete remote transport adapter (REMOTE-05 provides a local file fallback implementing the abstract interface; network adapters deferred to v2), and no push notification to devices outside the Hermes host.
- [ ] **AUTH-01**: The specification defines Hermes, Claude Supervisor, Codex Executor, Remote Decision Channel, and user authority boundaries.
- [ ] **AUTH-02**: The specification defines what each actor may write, approve, reject, escalate, or never approve. Authority is layered: (1) Preset Rule Floor — Hermes loads a static risk rule table (RISK-05) and enforces minimum risk levels; may upgrade Claude's classification if it undercuts the floor. (2) Technical Assessment — Claude evaluates context and may upgrade from the rule table baseline; may NOT downgrade below the floor. (3) Execution Challenge — Codex may pause and request re-assessment if new risk factors emerge during execution; this is a challenge, not an override. A challenge permits at most 3 rounds per task; beyond 3, Hermes marks the task `stalled` and notifies the user.
- [ ] **AUTH-03**: The specification states that L3/L4 risk decisions require explicit user approval and cannot be auto-approved by timeout, Claude, Codex, or remote-channel fallback.

### Runtime and Commands

- [ ] **RUNT-01**: User can see the supported host assumptions for no-sudo Ubuntu/Linux, SSH access, tmux, Git, Node, Claude Code CLI, Codex CLI, and Hermes Agent.
- [ ] **RUNT-02**: User can see safe invocation profiles for Claude Supervisor and Codex Executor, including required sandbox/approval behavior and forbidden bypass flags.
- [ ] **RUNT-03**: User can see the expected four-layer directory layout: Runtime Bus (`XDG_RUNTIME_DIR`), State (`XDG_STATE_HOME`), Audit (`XDG_DATA_HOME`), and Cache (`XDG_CACHE_HOME`), each with deterministic fallbacks. A `paths.json` manifest records resolved paths on Hermes startup. Bus artifacts are physically separated from audit/state artifacts.
- [ ] **CMD-01**: The specification defines command contracts for project init, start, stop, status, task append, decision reply, doctor/preflight, archive, and recovery.
- [ ] **CMD-02**: Each command contract includes inputs, outputs, idempotency behavior, error cases, and required safety checks.
- [ ] **CMD-03**: The specification defines how CLI capability probes verify Claude, Codex, tmux, Git, auth, hooks, sandbox, and JSON output behavior before use.

### File Bus and State

- [ ] **BUS-01**: The specification defines JSON/JSONL as the canonical file-bus protocol and Markdown as human-readable projection only.
- [ ] **BUS-02**: The specification defines schema envelopes for task, event, question, decision, escalation, result, review, and archive records. The decision envelope (`claude-decision.md`) MUST include: `rulebook` (version, matched_rules, baseline_level, overridable), `assessment` (assessed_level, escalation_required, escalation_reason, confidence, conditions), `execution` (authority_sufficient, granted_by, granted_at, expires_at, challenge_count, max_challenges), and `history` (state change trace for audit).
- [ ] **BUS-03**: Each bus message includes schema version, message ID, project ID, task ID, correlation ID, status, author, authority, risk level, and timestamps.
- [ ] **BUS-04**: The specification defines writer/reader ownership for every bus artifact.
- [ ] **BUS-05**: The specification defines atomic write, locking, stale-message rejection, correlation checks, schema validation, and archive rules.
- [ ] **BUS-06**: Bus artifacts and audit/state artifacts are physically separated. Runtime bus files MUST NOT be referenced as durable evidence. Complete records are atomically migrated to the Audit layer before a task or decision is considered final. State snapshots are written to the State layer, never the Runtime layer. A validation gate rejects messages lacking audit entries after a grace period.
- [ ] **STATE-01**: The specification defines task and project states from ready/queued through executing, waiting, reviewing, completed, failed, cancelled, and recovering.
- [ ] **STATE-02**: The specification defines valid and invalid state transitions, including recovery from partial writes, stale decisions, process loss, and `/tmp` cleanup.
- [ ] **AUDIT-01**: The specification defines durable audit and evidence records for tasks, decisions, escalations, approvals, rejections, reviews, and final outcomes.

### Multi-Project Scheduling and Isolation

- [ ] **MULTI-01**: User can register multiple projects with immutable project IDs, canonical paths, sanitized runtime names, and per-project policy.
- [ ] **MULTI-02**: User can append a task at any time while other tasks or projects are running, blocked, reviewing, or recovering.
- [ ] **MULTI-03**: Hermes can route appended tasks to a project, queue or reject invalid tasks, deduplicate repeated submissions, and report the resulting task state.
- [ ] **MULTI-04**: The specification defines per-project tmux sessions, bus roots, logs, env filtering, state rows, and archive locations.
- [ ] **MULTI-05**: The scheduler continues polling and progressing other projects when one project waits for Claude or user input.
- [ ] **MULTI-06**: The specification defines same-repository concurrency policy, including serialization or future worktree requirements to avoid branch races.

### Agent Protocol and Evidence

- [ ] **AGENT-01**: The specification defines Hermes orchestration behavior for task dispatch, process supervision, escalation, audit, archive, and user communication.
- [ ] **AGENT-02**: The specification defines Claude Supervisor behavior for technical decisions, risk classification, review outputs, confidence, and escalation recommendations.
- [ ] **AGENT-03**: The specification defines Codex Executor behavior for task intake, implementation constraints, pause/question rules, result reporting, tests, dependencies, and known issues.
- [ ] **AGENT-04**: Codex can pause and ask a structured question when requirements, code state, safety, dependencies, or implementation approach are ambiguous.
- [ ] **AGENT-05**: Claude can answer low-risk technical questions or escalate higher-risk decisions with sufficient rationale and impact analysis.
- [ ] **AGENT-06**: Codex can proceed only when the decision authority is sufficient for the classified risk level.
- [ ] **AGENT-07**: Codex challenge mechanism is constrained: a single task permits at most 3 challenge rounds (Codex question → Hermes route → Claude re-assessment → Codex receive). Hermes tracks `challenge_count` per task in the State layer. On count == 3, task state becomes `stalled`, an audit event is written, and the user is notified. A challenge is valid only if it presents new information; Hermes applies a deterministic, documented deduplication rule with a configurable default before re-routing challenges. Claude's re-assessment must reference new context; identical re-assessments are flagged `no_new_assessment` and count toward the limit.
- [ ] **EVID-01**: The specification defines required execution evidence, including changed files, commands run, tests, dependency changes, review result, residual risks, and next steps.
- [ ] **EVID-02**: The specification requires direct repository evidence for completion and forbids trusting agent summaries alone for final verification.

### Risk and Remote Decision

- [ ] **RISK-01**: The specification defines risk levels, examples, owners, default actions, timeout behavior, and user-required cases.
- [ ] **RISK-02**: Dependency, auth, secrets, database schema, CI/CD, public API, system command, and production-data changes are explicitly classified for escalation.
- [ ] **RISK-05**: The specification defines a static risk rule table loaded by Hermes at startup. Each entry contains: `rule_id`, `pattern`, `match_criteria` (file_glob, command_regex, scope), `minimum_level`, `rationale`, and `overridable`. Hermes validates every `claude-decision.md` against matching rules; the highest minimum_level wins. If `overridable: false`, Hermes unconditionally enforces the minimum level, upgrades the classification, appends `rulebook_override` to the decision, and records the override in the audit log. The rule table version is included in every classified decision's audit record.
- [ ] **RISK-03**: L3/L4 decisions block the affected project until the user explicitly approves or rejects the proposal. In v1, “modify” is represented as rejection plus `hermes retry <task-id>` with updated requirements; direct remote modify responses are deferred to future adapters.
- [ ] **RISK-04**: The specification defines safe default behavior when a risk decision times out, remote channels fail, or approval text is ambiguous. Timeout default is 24 hours (configurable); timeout action is automatic rejection with audit record; user may retry the task. Remote channel failure activates the file-based fallback channel (REMOTE-05), preserves pending decisions, and retries adapter healthcheck every 60 seconds. Ambiguous approval is rejected; after 3 attempts, auto-rejects and escalates to manual review.
- [ ] **REMOTE-01**: The specification defines a Remote Decision Channel abstraction without binding v1 to Telegram, Discord, webhook, or any specific transport.
- [ ] **REMOTE-02**: The Remote Decision Channel interface includes notice, decision request, reply, healthcheck, acknowledgement, timeout, and cancellation behavior.
- [ ] **REMOTE-03**: Remote approvals are bound to project ID, task ID, risk event, approval ID, TTL, actor identity, structured choices, and one-time use.
- [ ] **REMOTE-04**: The remote channel never writes canonical bus decisions directly; Hermes validates replies and writes final decisions with audit entries.
- [ ] **REMOTE-05**: Hermes provides a file-based local fallback channel implementing the REMOTE-02 interface without external network dependencies. When no remote adapter is configured, decision requests are written to `${RUNTIME}/decisions/`. The user responds via `hermes approve/reject <decision-id>`. Hermes polls every 5 seconds, validates one-time use and TTL, writes the final decision to the Audit layer, and deletes the response file. This fallback is local to the Hermes host; push notifications to external devices are deferred to v2.

### Recovery, Observability, and Verification

- [ ] **OBS-01**: User can inspect project status showing project, task, process/session, cwd, heartbeat age, risk wait, last event, and next required action.
- [ ] **OBS-02**: The specification defines process registry and heartbeat requirements for Hermes, Claude, Codex, tmux sessions, and remote decision adapters.
- [ ] **REC-01**: The specification defines recovery behavior for SSH disconnect, Hermes restart, Claude/Codex crash, tmux loss, stale bus files, `/tmp` cleanup, and auth failure.
- [ ] **REC-02**: Recovery procedures preserve audit evidence before killing, restarting, or archiving sessions.
- [ ] **REC-03**: Recovery for Hermes restart or crash: (1) read state snapshot from State layer, (2) scan Runtime layer for newer bus files, (3) validate schema and correlation ID against reconstructed state, (4) reject files with unsupported schema, unknown correlation ID, duplicate message ID, or stale timestamp, (5) write recovery event to Audit layer before resuming.
- [ ] **VERIFY-01**: The specification includes acceptance scenarios for happy path task execution, Codex question, Claude decision, Claude escalation, L3/L4 block, remote decision failure, append-while-running, multi-project block/yield, stale approval rejection, process restart, and `/tmp` cleanup.
- [ ] **VERIFY-02**: Each acceptance scenario includes initial state, inputs, expected bus messages, expected state transitions, expected audit records, and pass/fail criteria.
- [ ] **HANDOFF-01**: The specification includes a roadmap handoff that orders implementation phases by protocol dependencies rather than UI or script convenience.
- [ ] **HANDOFF-02**: The specification marks future implementation assumptions that require fresh research, including Hermes Agent API, Claude/Codex CLI drift, remote adapter details, SQLite schema, and unattended-mode safety.

## v2 Requirements

Deferred to future releases. Tracked but not in the current v1 specification package.

### Implementation

- **IMPL-01**: Build a runnable `orch-*` command-line tool from the v1 command contracts.
- **IMPL-02**: Implement JSON Schema validation, file-bus readers/writers, process registry, and status command.
- **IMPL-03**: Implement Claude and Codex runners with actual tmux/session lifecycle management.
- **IMPL-04**: Implement durable SQLite state and audit storage.

### Remote Adapters

- **ADPT-01**: Implement a concrete Remote Decision Channel adapter after choosing a transport.
- **ADPT-02**: Support optional webhook, Matrix, Discord, email, mobile push, or future Hermes gateway adapters.
- **ADPT-03**: Add adapter-specific identity verification, message truncation handling, delivery retries, and replay protection.

### Product Extensions

- **EXT-01**: Integrate with `gbrain` as an optional plugin or memory backend.
- **EXT-02**: Add web/mobile dashboard views for multi-project status.
- **EXT-03**: Add GitHub issue/PR automation and MCP integrations.
- **EXT-04**: Add team collaboration, shared approvals, and multi-user audit roles.
- **EXT-05**: Add low-risk unattended mode with budgets, no-go operations, and morning review bundles.
- **EXT-06**: Add cost/model routing and persistent learning/memory productization.

## Out of Scope

Explicitly excluded from v1 to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Runnable orchestrator implementation | v1 deliverable is a specification package and roadmap, not code implementation. |
| Telegram-specific integration | User wants remote decisions abstracted, not bound to Telegram. |
| `gbrain` integration | User selected a standalone specification package rather than integrating this into the existing `gbrain` repo. |
| Team collaboration platform | v1 persona is a single developer managing multiple projects. |
| AI factory/high-throughput automation | v1 prioritizes append-anytime task intake and safe decision flow over throughput. |
| Web or mobile dashboard | SSH/Hermes CLI is the required primary entry; dashboards can follow after core contracts. |
| Automatic L3/L4 approval | Violates the safety premise; high-risk actions require explicit user approval. |
| Binding protocol state to Markdown files | Markdown is readable output only; canonical protocol must be structured and schema-validated. |
| Treating tmux scrollback as source of truth | tmux is a PTY/session layer, not the orchestration protocol. |
| Unrestricted unattended execution | Requires additional safety budgets and no-go rules, deferred to a future profile. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SPEC-01 | TBD | Pending |
| SPEC-02 | TBD | Pending |
| SPEC-03 | TBD | Pending |
| SPEC-04 | TBD | Pending |
| SPEC-05 | TBD | Pending |
| SCOPE-01 | TBD | Pending |
| SCOPE-02 | TBD | Pending |
| SCOPE-03 | TBD | Pending |
| AUTH-01 | TBD | Pending |
| AUTH-02 | TBD | Pending |
| AUTH-03 | TBD | Pending |
| RUNT-01 | TBD | Pending |
| RUNT-02 | TBD | Pending |
| RUNT-03 | TBD | Pending |
| CMD-01 | TBD | Pending |
| CMD-02 | TBD | Pending |
| CMD-03 | TBD | Pending |
| BUS-01 | TBD | Pending |
| BUS-02 | TBD | Pending |
| BUS-03 | TBD | Pending |
| BUS-04 | TBD | Pending |
| BUS-05 | TBD | Pending |
| BUS-06 | TBD | Pending |
| STATE-01 | TBD | Pending |
| STATE-02 | TBD | Pending |
| AUDIT-01 | TBD | Pending |
| MULTI-01 | TBD | Pending |
| MULTI-02 | TBD | Pending |
| MULTI-03 | TBD | Pending |
| MULTI-04 | TBD | Pending |
| MULTI-05 | TBD | Pending |
| MULTI-06 | TBD | Pending |
| AGENT-01 | TBD | Pending |
| AGENT-02 | TBD | Pending |
| AGENT-03 | TBD | Pending |
| AGENT-04 | TBD | Pending |
| AGENT-05 | TBD | Pending |
| AGENT-06 | TBD | Pending |
| AGENT-07 | TBD | Pending |
| EVID-01 | TBD | Pending |
| EVID-02 | TBD | Pending |
| RISK-01 | TBD | Pending |
| RISK-02 | TBD | Pending |
| RISK-05 | TBD | Pending |
| RISK-03 | TBD | Pending |
| RISK-04 | TBD | Pending |
| REMOTE-01 | TBD | Pending |
| REMOTE-02 | TBD | Pending |
| REMOTE-03 | TBD | Pending |
| REMOTE-04 | TBD | Pending |
| REMOTE-05 | TBD | Pending |
| OBS-01 | TBD | Pending |
| OBS-02 | TBD | Pending |
| REC-01 | TBD | Pending |
| REC-02 | TBD | Pending |
| REC-03 | TBD | Pending |
| VERIFY-01 | TBD | Pending |
| VERIFY-02 | TBD | Pending |
| HANDOFF-01 | TBD | Pending |
| HANDOFF-02 | TBD | Pending |

**Coverage:**
- v1 requirements: 60 total (55 prior + 5 from SPEC/design review)
- Mapped to phases: 0
- Unmapped: 60 ⚠️

---
*Requirements defined: 2026-04-25*
*Last updated: 2026-04-25 after SPEC/design review (added specification deliverable requirements and aligned risk/challenge semantics)*
