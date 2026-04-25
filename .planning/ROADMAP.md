# Roadmap: Hermes Dev Orchestra

## Overview

Hermes Dev Orchestra v1 delivers a specification package, not a runnable orchestrator. The roadmap moves from product scope and authority, through runtime and protocol contracts, into multi-project scheduling, agent collaboration, risk/remote decisions, and final recovery/verification handoff. Each phase produces spec-checkable artifacts that make later implementation possible without depending on an existing executable system.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Scope, Package Coverage & Authority** - Locks v1 boundaries, inline spec coverage, and actor approval authority.
- [ ] **Phase 2: Runtime, Installation & Command Contracts** - Defines safe no-sudo host assumptions, invocation profiles, paths, and CLI command contracts.
- [ ] **Phase 3: File Bus, Decision Envelope, State & Audit** - Freezes the canonical JSON/JSONL protocol, state machine, and durable evidence model.
- [ ] **Phase 4: Multi-Project Scheduling & Isolation** - Specifies append-anytime routing across isolated projects with blocked-project yielding.
- [ ] **Phase 5: Agent Protocol, Challenge & Evidence** - Defines Hermes, Claude, and Codex collaboration rules plus verifiable completion evidence.
- [ ] **Phase 6: Risk Rulebook & Remote Decision Contract** - Specifies risk gates, static rule enforcement, Remote Decision Channel behavior, and local fallback.
- [ ] **Phase 7: Recovery, Observability, Verification & Handoff** - Completes status, recovery, acceptance scenarios, traceability, and implementation handoff.

## Phase Details

### Phase 1: Scope, Package Coverage & Authority
**Goal**: Reviewers can verify the v1 spec package scope, inline coverage model, and decision authority boundaries before any downstream contracts are planned.
**Depends on**: Nothing (first phase)
**Requirements**: SPEC-01, SPEC-02, SCOPE-01, SCOPE-02, SCOPE-03, AUTH-01, AUTH-02, AUTH-03
**Success Criteria** (what must be TRUE):
  1. Reviewer can verify v1 is a standalone specification package and every requirement maps to concrete spec/roadmap coverage without relying on external docs.
  2. Reader can identify the primary persona, append-anytime workflow, SSH/Hermes CLI entry, Remote Decision Channel abstraction, and explicit v1 non-goals.
  3. Actor authority tables state what Hermes, Claude Supervisor, Codex Executor, Remote Decision Channel, and user may write, approve, reject, escalate, or never approve.
  4. L3/L4 decisions are explicitly reserved for user approval and cannot be approved by timeout, Claude, Codex, or fallback behavior.
**Plans**: TBD

### Phase 2: Runtime, Installation & Command Contracts
**Goal**: Reviewers can validate safe host, installation, invocation, path, and command assumptions for a no-sudo SSH-based Hermes environment.
**Depends on**: Phase 1
**Requirements**: RUNT-01, RUNT-02, RUNT-03, CMD-01, CMD-02, CMD-03
**Success Criteria** (what must be TRUE):
  1. Reviewer can trace supported host, SSH, tmux, Git, Node, Claude Code CLI, Codex CLI, Hermes Agent, and no-sudo assumptions.
  2. Safe Claude/Codex invocation profiles list required sandbox/approval behavior and forbidden bypass flags.
  3. The four-layer Runtime Bus, State, Audit, and Cache layout has deterministic fallbacks and a startup `paths.json` manifest contract.
  4. Each command contract covers inputs, outputs, idempotency, error cases, and required safety checks.
  5. Doctor/preflight probes cover CLI capability, auth, hooks, sandbox, tmux, Git, and JSON output behavior before use.
**Plans**: TBD

### Phase 3: File Bus, Decision Envelope, State & Audit
**Goal**: Reviewers can validate the canonical bus protocol, decision schema, task state machine, and durable audit model without running agents.
**Depends on**: Phase 2
**Requirements**: SPEC-03, BUS-01, BUS-02, BUS-03, BUS-04, BUS-05, BUS-06, STATE-01, STATE-02, AUDIT-01
**Success Criteria** (what must be TRUE):
  1. JSON/JSONL is the canonical protocol for task, event, question, decision, escalation, result, review, and archive records; Markdown is only a human-readable projection.
  2. The decision envelope is schema-ready and includes rulebook, assessment, execution, and history fields.
  3. Writer/reader ownership, atomic writes, locking, stale-message rejection, correlation checks, schema validation, and archive rules are specified for every bus artifact.
  4. Task/project state transitions cover ready, queued, executing, waiting, reviewing, completed, failed, cancelled, recovering, partial writes, stale decisions, process loss, and runtime cleanup.
  5. Runtime bus, State, and Audit artifacts are physically separated, and durable audit records are required before final outcomes are accepted.
**Plans**: TBD

### Phase 4: Multi-Project Scheduling & Isolation
**Goal**: Users can append tasks at any time while Hermes routes work across isolated projects and keeps unblocked projects moving.
**Depends on**: Phase 3
**Requirements**: MULTI-01, MULTI-02, MULTI-03, MULTI-04, MULTI-05, MULTI-06
**Success Criteria** (what must be TRUE):
  1. User can register multiple projects with immutable project IDs, canonical paths, sanitized runtime names, and per-project policy.
  2. User can append a task while projects are running, blocked, reviewing, or recovering and receive a queued, rejected, deduplicated, or current task state.
  3. Scheduler rules show that a project waiting for Claude or user input yields while other projects continue polling and progressing.
  4. Per-project tmux sessions, bus roots, logs, environment filtering, state rows, archive locations, and same-repository concurrency policy prevent cross-project collisions.
**Plans**: TBD

### Phase 5: Agent Protocol, Challenge & Evidence
**Goal**: Reviewers can validate Hermes, Claude, and Codex collaboration rules, challenge limits, and completion evidence contracts.
**Depends on**: Phase 4
**Requirements**: AGENT-01, AGENT-02, AGENT-03, AGENT-04, AGENT-05, AGENT-06, AGENT-07, EVID-01, EVID-02
**Success Criteria** (what must be TRUE):
  1. Hermes, Claude Supervisor, and Codex Executor responsibilities are stated for dispatch, supervision, classification, questions, reviews, execution, reporting, audit, and archive.
  2. Codex pause/questions and Claude low-risk answers/escalations use structured message fields with sufficient rationale and impact analysis.
  3. Codex proceeds only when decision authority is sufficient for the classified risk level.
  4. The Codex challenge loop is deduplicated, capped at three rounds per task, and stalls with audit evidence when exhausted.
  5. Completion requires direct repository evidence for changed files, commands, tests, dependency changes, review result, residual risks, and next steps.
**Plans**: TBD

### Phase 6: Risk Rulebook & Remote Decision Contract
**Goal**: Reviewers can verify that risk gates, rule enforcement, high-risk blocking, and local fallback decisions are safe and replay-resistant.
**Depends on**: Phase 5
**Requirements**: SPEC-04, RISK-01, RISK-02, RISK-05, RISK-03, RISK-04, REMOTE-01, REMOTE-02, REMOTE-03, REMOTE-04, REMOTE-05
**Success Criteria** (what must be TRUE):
  1. Risk levels, examples, owners, default actions, timeout behavior, and user-required cases are specified by impact.
  2. Static risk rule table artifact includes at least 10 concrete rules for database schema, auth, secrets, CI/CD, public API, system commands, dependency updates, file deletion, network config, and cost-sensitive operations.
  3. L3/L4 decisions block the affected project until explicit user approval or rejection; timeouts, remote failure, and ambiguous replies default to rejection or safe hold with audit.
  4. Every decision reply is bound to project ID, task ID, risk event, approval ID, TTL, actor identity, structured choice, and one-time use.
  5. File-based local fallback implements notice, decision request, reply, healthcheck, acknowledgement, timeout, and cancellation without external network or push-notification assumptions.
**Plans**: TBD

### Phase 7: Recovery, Observability, Verification & Handoff
**Goal**: Reviewers can accept the full spec package through status/recovery contracts, acceptance scenarios, traceability, and implementation handoff.
**Depends on**: Phase 6
**Requirements**: SPEC-05, OBS-01, OBS-02, REC-01, REC-02, REC-03, VERIFY-01, VERIFY-02, HANDOFF-01, HANDOFF-02
**Success Criteria** (what must be TRUE):
  1. Status contracts expose project, task, process/session, cwd, heartbeat age, risk wait, last event, and next required action.
  2. Recovery procedures preserve audit evidence before kill, restart, archive, or resume actions and cover SSH disconnect, Hermes restart, Claude/Codex crash, tmux loss, stale bus files, runtime cleanup, and auth failure.
  3. Acceptance scenarios cover happy path task execution, Codex question, Claude decision, Claude escalation, L3/L4 block, remote decision failure, append-while-running, multi-project block/yield, stale approval rejection, process restart, and runtime cleanup.
  4. Each acceptance scenario states initial state, inputs, expected bus messages, expected state transitions, expected audit records, and pass/fail criteria.
  5. Handoff orders future implementation phases by protocol dependencies and labels assumptions requiring fresh research.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scope, Package Coverage & Authority | 0/TBD | Not started | - |
| 2. Runtime, Installation & Command Contracts | 0/TBD | Not started | - |
| 3. File Bus, Decision Envelope, State & Audit | 0/TBD | Not started | - |
| 4. Multi-Project Scheduling & Isolation | 0/TBD | Not started | - |
| 5. Agent Protocol, Challenge & Evidence | 0/TBD | Not started | - |
| 6. Risk Rulebook & Remote Decision Contract | 0/TBD | Not started | - |
| 7. Recovery, Observability, Verification & Handoff | 0/TBD | Not started | - |
