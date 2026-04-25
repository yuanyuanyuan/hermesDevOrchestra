# Project Research Summary

**Project:** Hermes Dev Orchestra  
**Domain:** Single-developer local AI development orchestration specification package  
**Researched:** 2026-04-25  
**Confidence:** HIGH for product/protocol direction; MEDIUM-HIGH for CLI stack pending version smoke tests

## Executive Summary

Hermes Dev Orchestra v1 is a **specification package**, not a runnable orchestrator. The core product is a single-developer, multi-project AI development control plane where the user connects through SSH/Hermes CLI, appends tasks at any time, and lets Hermes coordinate Claude Code as supervisor/reviewer and Codex CLI as executor. v1 must remain standalone: no `gbrain` integration, no Telegram binding, no team platform, and no concrete implementation as the milestone output.

The recommended approach is a **policy-enforced three-agent control plane over a per-project structured file bus**. Hermes owns state, scheduling, process lifecycle, escalation, audit, and user communication; Claude owns technical judgment, risk classification, and review; Codex owns implementation and verification. The source of truth should be schema-validated JSON/JSONL plus durable state/audit records, with Markdown used only as human-readable projections. tmux is a PTY/session envelope, not the protocol or supervisor.

The main risks are unsafe implicit trust boundaries: mutable `/tmp` Markdown files, stale approvals, remote reply spoofing, tmux state drift, cross-project leakage, broad Claude authority, CLI version drift, prompt injection through inter-agent files, and non-idempotent recovery. Mitigate by specifying schemas, atomic writes, correlation IDs, an authority matrix, risk taxonomy, fail-closed preflight checks, per-project isolation, durable audit logs, and explicit user approval for all L3/L4 decisions.

## Key Findings

### Stack Choices

v1 should specify a Linux-first local stack: Ubuntu/Linux host, SSH entry, tmux for persistent PTY sessions, Git as the safety boundary, Claude Code for supervision/review, Codex CLI for bounded execution, JSON/JSONL for protocol artifacts, JSON Schema for validation, and XDG-aligned state/config directories. Node 24 LTS is the recommended validation/helper runtime, with Node 22 as minimum; Bash/coreutils, `jq`, `flock`, `mktemp`, and atomic rename semantics are required for future implementation scripts.

**Core technologies:**
- Ubuntu 24.04 LTS preferred / 22.04 acceptable — primary local execution host.
- SSH + Hermes CLI — required operator entry and baseline decision channel.
- tmux `>=3.3` — resilient PTY/session layer across SSH disconnects.
- Git — required repo boundary, checkpoint, rollback, and diff evidence mechanism.
- Claude Code CLI — supervisor/reviewer in structured print/JSON mode; not a second executor.
- Codex CLI — executor via explicit sandbox/approval flags and structured result output.
- JSON/JSONL + JSON Schema 2020-12 — canonical bus and contract validation format.
- SQLite + XDG state/config layout — durable project/task/decision registry and audit archive.
- Remote Decision Channel abstraction — transport-neutral `notice`, `request_decision`, `reply`, `healthcheck`, and `ack` operations.

**Stack corrections to carry forward:**
- Do not parse raw Markdown as protocol state; Markdown is a projection only.
- Do not make Telegram, Discord, MCP, Cloud, or web dashboards part of v1 core.
- Treat Hermes Agent runtime/API assumptions as LOW confidence until implementation research verifies them.
- Forbid Codex/Claude sandbox or approval bypass modes in normal operation.
- Store durable audit/state outside `/tmp`; use `/tmp` only for runtime scratch.

### Table Stakes and Differentiators

**Must have (table stakes):**
- Product scope and non-goals — locks v1 to a standalone spec package for one developer.
- SSH/Hermes CLI command contracts — define init/start/stop/status/task append/decision reply behavior.
- Append-anytime task intake — support appending tasks while projects are running or blocked.
- Project registry and isolation — canonical project IDs, paths, sessions, env, logs, and bus roots.
- Three-agent authority matrix — define what Hermes, Claude, Codex, and user may write/approve.
- Per-project file-bus protocol — schemas, writers/readers, statuses, atomic writes, stale handling, archive rules.
- Task state machine — canonical transitions, invalid transitions, recovery states, and blocked-project yielding.
- Claude decision/review protocol — technical decisions, risk flags, review results, escalation triggers.
- Codex execution/result protocol — pause rules, changed files, tests, dependencies, partial/failure states.
- Risk escalation policy — L0-L4/L1-L4 examples, owners, timeouts, audit, and blocking rules.
- Remote Decision Channel interface — transport-neutral notices, choices, health, idempotency, and acknowledgements.
- Audit, evidence, recovery, troubleshooting, and verification scenarios — make the spec testable before implementation.

**Differentiators to preserve:**
- Manager/Supervisor/Executor split — separates orchestration, judgment, and implementation authority.
- File bus as source of truth — inspectable, restartable, and tool-neutral orchestration.
- Append-anytime multi-project scheduling — matches the primary user workflow better than batch-only automation.
- Meaningful human interruption — quiet for low-risk work, hard-blocking for product/security/danger decisions.
- SSH-first/no-sudo local workflow — fits the target Ubuntu dev box and remote Windows SSH access.
- Spec-first package with examples and acceptance fixtures — turns the proposal into buildable contracts.

**Defer to v2+:**
- Runnable orchestrator implementation, concrete remote adapters, Telegram binding, `gbrain` integration, web/mobile UI, team collaboration, high-throughput AI factory, MCP/GitHub/PR automation, model/cost routing, and persistent learning/memory productization.

### Architecture Decisions

The architecture should be specified as a three-agent control plane with Hermes enforcing policy over structured bus/state transitions. Where existing drafts show Markdown bus files, the roadmap should normalize them into JSON protocol documents or Markdown projections with a trusted structured envelope; state transitions must never depend on prose or terminal scrollback.

**Major components:**
1. **User Entry** — submits tasks and explicit L3/L4 decisions through SSH/Hermes CLI or optional remote adapters.
2. **Hermes Orchestrator** — owns project/task state, scheduling, process lifecycle, escalation policy, audit, archive, and user communication.
3. **Claude Supervisor** — owns technical decisions, code review, risk classification, and recommendations within authority limits.
4. **Codex Executor** — owns code edits, tests, refactors, pause/questions, and structured execution results.
5. **Project Runtime** — isolates each repo with per-project bus root, tmux sessions, process registry, config, env, and logs.
6. **Remote Decision Channel** — carries notices and structured choices; Hermes validates replies and writes final bus decisions.
7. **Audit/Archive/Observability** — persists events, evidence, approvals, heartbeats, logs, and immutable task bundles.

**Architecture rules:**
- Hermes is the only writer of canonical project state and user-final decisions.
- Claude may recommend or approve only within the configured authority/risk class.
- Codex may proceed only when the decision authority is sufficient for the classified risk.
- Every message requires `schema_version`, `message_id`, `project_id`, `task_id`, `correlation_id`, `status`, `author`, `authority`, `risk_level`, and timestamp fields.
- Files are written atomically, validated by schema, checked for current correlation IDs, and archived immutably.
- The state machine should cover `READY → DISPATCHED → EXECUTING → AWAITING_CLAUDE/AWAITING_USER → REVIEWING → COMPLETED/FAILED/CANCELLED/RECOVERING`.
- tmux supports persistence and observability only; heartbeats, process registry, bus events, and state files define truth.

### Critical Pitfalls and Guardrails

1. **Mutable `/tmp` Markdown protocol** — use JSON/JSONL schemas, event IDs, atomic writes, stale rejection, and durable XDG audit archives.
2. **Tool permission modes mistaken for safety policy** — enforce an orchestra-level permission matrix, fail closed on bypass flags, filter env/secrets, and gate network/package/system capabilities.
3. **Remote approvals not bound to risk events** — require nonce approval IDs, project/task/diff binding, TTL, one-time use, structured choices, actor identity, and default reject/hold on failure.
4. **tmux treated as supervisor** — define tmux as PTY only; require process registry, heartbeats, exit codes, cwd checks, safe restart, and deterministic recovery.
5. **Cross-project leakage** — use immutable project registry IDs, sanitized session/path names, `0700` runtime dirs, per-project logs/events/env, and one writer per repo branch.
6. **Claude authority creep** — classify risk by impact, not file type; auth, secrets, migrations, CI/CD, dependency, public API, and product behavior changes need explicit gates.
7. **Unattended optimism** — keep unattended mode out of v1 core or specify it as low-risk-only with budgets, no deps/migrations/deploys, and mandatory morning review.
8. **CLI/config drift and prompt injection** — version-pin with `orch doctor` smoke tests, fail closed on unknown behavior, treat all payload prose/logs/repo content as untrusted data, and parse only structured authority fields.

## Requirements Implications

- Requirements should be **contract-first**, not implementation-first: define commands, schemas, state transitions, role ownership, risk gates, evidence, and acceptance scenarios before scripts or adapters.
- The primary workflow requirement is **append-anytime task intake**: append, route, queue, reject, pause, resume, deduplicate, and continue other projects while one project waits for Claude/user.
- Every requirement should name the exact **actor, file/message, status, authority, risk level, timeout behavior, and acceptance check**.
- The file-bus requirements must specify JSON/JSONL canonical artifacts, writer/reader ownership, atomic write rules, correlation checks, archive behavior, and generated Markdown projections.
- The CLI requirements must cover `init`, `start`, `stop`, `status`, `task append`, `decision reply`, `doctor`, recovery/status reporting, idempotency, and error cases.
- The risk requirements must state that **L3/L4 cannot auto-approve** through timeout, remote failure, Claude approval, or convenience defaults.
- The Remote Decision Channel requirement should define only the abstract interface and SSH/CLI baseline; concrete transports are roadmap extensions.
- Verification requirements should include scenario fixtures for happy path, Codex question, Claude escalation, L3/L4 block, append-while-running, multi-project block/yield, stale approval rejection, restart recovery, and `/tmp` cleanup.

## Implications for Roadmap

### Phase 1: Scope, Glossary, and Authority Contract

**Rationale:** All later contracts depend on knowing who v1 serves, what is out of scope, and who can approve which risk.  
**Delivers:** Persona, workflow boundaries, non-goals, glossary, risk taxonomy, authority matrix, and “must not do” rules.  
**Addresses:** Product scope, three-agent role boundaries, risk escalation policy.  
**Avoids:** Claude authority creep, L3/L4 auto-approval, implementation/gbrain/Telegram scope drift.

### Phase 2: Runtime and Installation Contract

**Rationale:** CLI flags, hooks, permissions, auth, and no-sudo paths are fast-moving assumptions that must fail closed.  
**Delivers:** Version matrix, safe Claude/Codex invocation profiles, XDG directory layout, auth prerequisites, env filtering, forbidden flags, and `doctor` smoke-test requirements.  
**Addresses:** SSH/Hermes CLI baseline, no-sudo Ubuntu environment, safety stack.  
**Avoids:** CLI drift, unsafe inherited credentials, sandbox bypass, `/tmp` as durable state.

### Phase 3: File Bus and State Machine Contract

**Rationale:** The file bus and task state machine are the buildable core; process runners and adapters should wait until this contract is frozen.  
**Delivers:** JSON/JSONL schemas, envelope fields, status enums, writer/readers, atomic writes, locks, stale/correlation checks, event ledger, state transitions, archives, and fixtures.  
**Addresses:** Per-project file-bus protocol, task state machine, audit/evidence model.  
**Avoids:** Mutable Markdown races, prompt injection through prose, stale approvals, invalid transitions.

### Phase 4: Multi-Project Scheduling and Isolation Contract

**Rationale:** Append-anytime value depends on routing tasks safely across multiple isolated projects while blocked projects yield.  
**Delivers:** Project registry, sanitized IDs, tmux naming, task prefixes, per-project dirs/logs/env, queue rules, same-repo serialization/worktree policy, blocked-project yielding, cleanup rules.  
**Addresses:** Append-anytime intake, project registry/isolation, multi-project concurrency.  
**Avoids:** Cross-project leakage, shell injection through names, repo branch races, ambiguous status.

### Phase 5: Agent Protocol, Review, and Evidence Contract

**Rationale:** Claude and Codex need precise bus-level contracts before implementation prompts or skills can be trusted.  
**Delivers:** Hermes/Claude/Codex responsibilities, question/decision/result/review formats, pause rules, review inputs, direct repo verification evidence, dependency/change reporting, partial/failure semantics.  
**Addresses:** Claude decision/review protocol, Codex execution/result protocol, verification expectations.  
**Avoids:** Trusting Codex summaries, insufficient decision authority, unverified completion claims.

### Phase 6: Remote Decision and Escalation Contract

**Rationale:** Remote decisions are valuable but dangerous unless bound to structured risk events; v1 should specify the interface, not a Telegram implementation.  
**Delivers:** `send_notice`, `request_decision`, `receive_reply`, `healthcheck`, `acknowledge`, approval IDs, TTL, idempotency, actor identity, structured choices, timeout/default-deny rules, audit entries.  
**Addresses:** Remote Decision Channel abstraction, L3/L4 user blocking, meaningful interruptions.  
**Avoids:** Spoofed/replayed/truncated approvals, free-text approval ambiguity, Telegram lock-in.

### Phase 7: Recovery, Observability, Verification, and Roadmap Handoff

**Rationale:** The spec is only actionable if it defines what happens after crashes, disconnects, partial edits, and review failures.  
**Delivers:** Status surface, process registry, heartbeats, SSH disconnect behavior, tmux/process loss recovery, `/tmp` cleanup recovery, audit retention/redaction, acceptance scenario suite, implementation roadmap, and v2 unattended constraints.  
**Addresses:** Health/recovery/troubleshooting, verification scenarios, roadmap handoff.  
**Avoids:** tmux-as-truth, non-idempotent recovery, lost audit logs, secret leakage, unsafe unattended expansion.

### Phase Ordering Rationale

- Start with authority and risk because every command, file, approval, and process transition depends on who is allowed to decide.
- Define runtime assumptions before protocol implementation because CLI drift and unsafe flags can invalidate the safety model.
- Freeze the file bus/state machine before agent prompts, process runners, remote adapters, or notification UX.
- Put multi-project isolation before review/recovery details so every later artifact carries canonical project/task/correlation identity.
- Keep remote adapters and unattended automation after core append/supervise/execute contracts; they are extensions, not v1 foundations.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** CLI behavior must be revalidated against installed Claude Code/Codex versions, hook schemas, permission modes, sandbox flags, and auth flows.
- **Phase 6:** Remote channel identity, replay protection, message truncation, and adapter health semantics need transport-specific research when an adapter is selected.
- **Phase 7:** If unattended mode is included beyond a v2 note, budget controls, network/package policies, and recovery semantics need deeper research.

Phases with standard patterns and enough current context:
- **Phase 1:** Product boundaries and authority matrix are driven by explicit project choices and existing docs.
- **Phase 3:** JSON Schema, JSONL, atomic writes, correlation IDs, and state machines are established patterns.
- **Phase 4:** Project registry, sanitized IDs, per-project dirs, and blocked-queue scheduling are well-understood local orchestration patterns.
- **Phase 5:** Structured question/decision/result/review contracts can be specified from the existing role docs plus repository verification practices.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Codex, Claude, tmux, Git, Node, JSON Schema, JSONL, and XDG choices are supported by local/official-source research; Hermes Agent API remains unverified. |
| Features | HIGH | v1 scope, append-anytime priority, SSH/Hermes CLI entry, no Telegram binding, no `gbrain`, and no L3/L4 auto-approval are explicit project constraints. |
| Architecture | HIGH | Three-agent control plane, per-project bus, authority boundaries, scheduler, and recovery model are consistent across research files. |
| Pitfalls | HIGH | Safety, file protocol, process, remote approval, isolation, and recovery risks are well-supported by local proposal review and established agentic-system patterns. |

**Overall confidence:** HIGH for roadmap direction; MEDIUM-HIGH for exact implementation stack until capability probes are specified.

### Gaps to Address

- **Hermes Agent runtime/API:** Treat as an interface contract in v1; verify concrete CLI/API only during implementation planning.
- **Claude/Codex CLI drift:** Require version matrix and `doctor` smoke tests before relying on hooks, JSON output, sandbox, or approval behavior.
- **Markdown vs JSON bus drafts:** Resolve in requirements by making JSON/JSONL canonical and Markdown generated/human-only.
- **Remote transport details:** Keep v1 abstract; research adapter-specific auth, identity, truncation, and replay controls only when selecting a transport.
- **Durable state schema:** SQLite is recommended, but exact tables and migrations belong to implementation-phase planning.
- **Unattended mode:** Keep out of v1 core; if retained as a future profile, require explicit low-risk scope, budgets, and no-go operations.

## Sources

### Primary (HIGH confidence)
- `.planning/PROJECT.md` — project scope, constraints, active requirements, out-of-scope decisions.
- `.planning/research/STACK.md` — stack recommendations, version assumptions, protocol format corrections.
- `.planning/research/FEATURES.md` — table stakes, differentiators, anti-features, dependency order.
- `.planning/research/ARCHITECTURE.md` — component boundaries, state machine, process lifecycle, remote channel model.
- `.planning/research/PITFALLS.md` — critical guardrails, phase warnings, acceptance checks.
- `docs/hermes-dev-orchestra/README.md` — original architecture and workflow proposal.
- `docs/hermes-dev-orchestra/hermes/SOUL.md` — Hermes orchestrator role and safety posture.
- `docs/hermes-dev-orchestra/skills/*.md` — Claude supervisor, Codex executor, orchestration, and escalation role contracts.

### Secondary (MEDIUM-HIGH confidence)
- OpenAI Codex CLI docs — CLI, non-interactive execution, approvals, sandboxing, and config behavior.
- Anthropic Claude Code docs — CLI reference, hooks, settings, permissions, and sandboxing behavior.
- JSON Schema 2020-12 and JSON Lines format — schema validation and append-only event stream foundations.
- XDG Base Directory Specification — config/state/cache/runtime path layout.
- tmux manual/releases — PTY/session persistence behavior.
- Linux `rename(2)` and `inotify(7)` manuals — atomic replacement and file-event limitations.
- OWASP Agentic AI security materials — agentic trust-boundary and approval safety framing.

---
*Research completed: 2026-04-25*  
*Ready for roadmap: yes*
