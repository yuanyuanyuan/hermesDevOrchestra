# Requirements Revision 1: Path Layering, Remote Decision Fallback, and Risk Authority

**Date:** 2026-04-25  
**Applies to:** REQUIREMENTS.md v1 (2026-04-25)  
**Status:** Merged into `.planning/REQUIREMENTS.md` on 2026-04-25  
**Author:** ce-brainstorm analysis  

---

## 1. Revision Summary

This revision addresses three interrelated structural risks identified during requirements review:

| # | Risk | Severity | Root Cause | Sections |
|---|------|----------|------------|----------|
| 1 | File bus path conflation (XDG durable vs. `/tmp` volatile) | High | RUNT-03 and README.md use conflicting path semantics; audit/state/bus are not physically separated | §2 |
| 2 | L3/L4 remote decision unavailability in v1 | High | REMOTE-01 forbids binding to any transport, leaving no concrete channel for async approval | §3 |
| 3 | Ambiguous risk classification authority across Hermes/Claude/Codex | Medium | AGENT-02/AGENT-04/AGENT-06 overlap on risk without clear precedence or schema | §4 |

Each section states the **original requirement(s)** being modified, the **new or revised requirement text**, and the **rationale**.

---

## 2. Risk 1 — File Bus Path Layering

### 2.1 Original Requirements Affected

- **RUNT-03**: "config, state, audit, cache, and runtime directory layout using XDG-style durable paths and runtime-only scratch paths"
- **BUS-01**: JSON/JSONL canonical protocol
- **BUS-05**: "atomic write, locking, stale-message rejection, correlation checks, schema validation, and archive rules"
- **REC-01**: recovery behavior includes `/tmp` cleanup

### 2.2 Problem Statement

RUNT-03 demands XDG-style paths. The existing input material (`docs/hermes-dev-orchestra/README.md`) places the entire file bus under `/tmp/hermes-orchestra/`. `/tmp` is volatile (systemd-tmpfiles cleans files ≥10 days; reboot clears it). Audit records and task state snapshots stored there are not durable. REC-01 requires recovery from `/tmp` cleanup, but if state itself lives in `/tmp`, recovery has no ground truth to reconstruct from.

### 2.3 Revisions

#### 2.3.1 RUNT-03 — Revised (Replace)

> **RUNT-03 [REVISED]**
> The specification defines a four-layer directory layout. All paths resolve through XDG Base Directory Specification environment variables with deterministic fallbacks. No layer may conflate the path of another layer.
>
> | Layer | Env Var | Fallback | Purpose | Lifetime |
> |-------|---------|----------|---------|----------|
> | Runtime Bus | `XDG_RUNTIME_DIR` | `/tmp/hermes-orchestra` | Active task files, pending decisions, inter-agent messages | Process-scoped; recreated on Hermes start |
> | State | `XDG_STATE_HOME` | `~/.local/state/hermes-orchestra` | Task state machine snapshots, process registry, heartbeat records, session index | Durable; explicit archive or user deletion |
> | Audit | `XDG_DATA_HOME` | `~/.local/share/hermes-orchestra` | Completed task audit chains, decision records, evidence files | Durable; archived and optionally compressed |
> | Cache | `XDG_CACHE_HOME` | `~/.cache/hermes-orchestra` | Agent output cache, indexes, temporary downloads | Rebuildable; safe to purge anytime |
>
> A `paths.json` manifest written to the State layer on Hermes startup records the resolved absolute path of each layer. All bus readers/writers validate the manifest path before I/O.

#### 2.3.2 BUS-06 — New

> **BUS-06 [NEW]**
> Bus artifacts and audit/state artifacts are physically separated.
>
> - Runtime bus files MUST NOT be referenced as durable evidence. Before a task or decision is considered complete, its canonical record MUST be atomically migrated to the Audit layer.
> - The migration sequence is: (1) write complete record to `${AUDIT}/pending/`, (2) fsync, (3) write a completion marker to the Runtime bus, (4) on next read, the consumer MUST check the Audit layer for the canonical record.
> - State snapshots (for recovery) MUST be written to the State layer, never the Runtime layer.
> - A validation gate rejects any message whose `author` claims a record exists in Runtime but no matching audit entry is found after a grace period of 30 seconds.

#### 2.3.3 REC-03 — New

> **REC-03 [NEW]**
> Recovery procedure for Hermes restart or crash:
> 1. Read the most recent state snapshot from the State layer into memory.
> 2. Scan the Runtime layer for any bus files newer than the snapshot timestamp.
> 3. For each newer bus file, validate its schema and correlation ID against the reconstructed state model.
> 4. Reject any bus file whose:
>    - schema version is unsupported,
>    - correlation ID references a non-existent task in the state snapshot,
>    - message ID duplicates an already-archived audit record,
>    - timestamp predates the snapshot by more than a configurable stale threshold (default: 5 minutes).
> 5. Write a recovery event to the Audit layer before resuming normal scheduling.

### 2.4 Rationale

Separating the four layers eliminates the contradiction between XDG durability and `/tmp` volatility. It gives recovery a ground truth (State + Audit) that survives Runtime cleanup. The `paths.json` manifest prevents path drift across restarts. The migration rule (BUS-06) ensures canonical records are always durable even if the Runtime layer is wiped mid-task.

---

## 3. Risk 2 — L3/L4 Remote Decision Availability

### 3.1 Original Requirements Affected

- **RISK-03**: "L3/L4 decisions block the affected project until the user explicitly approves, rejects, or modifies the proposal"
- **RISK-04**: "safe default behavior when a risk decision times out, remote channels fail, or approval text is ambiguous"
- **REMOTE-01**: abstraction without binding to any transport
- **REMOTE-02**: interface includes notice, decision request, reply, healthcheck, acknowledgement, timeout, cancellation

### 3.2 Problem Statement

RISK-03 requires blocking behavior for L3/L4. RISK-04 requires safe defaults on timeout/channel failure. REMOTE-01 forbids binding to Telegram, Discord, webhook, or any specific transport. The net effect: v1 defines a complete async decision interface but provides **no concrete transport**. A user who SSH-disconnects while an L3 decision is pending has no mechanism to receive the request or send approval. The core value proposition — "remote decision via phone" — is unrealizable in v1 as scoped.

### 3.3 Revisions

#### 3.3.1 REMOTE-05 — New

> **REMOTE-05 [NEW]**
> Hermes MUST provide a file-based local fallback channel that satisfies the REMOTE-02 interface without external network dependencies.
>
> **Mechanism:**
> - When no remote adapter is configured, Hermes writes decision requests to `${RUNTIME}/decisions/{project-id}/{decision-id}.json`.
> - The user lists pending decisions via `hermes decisions` (CMD-01 family).
> - The user responds via `hermes approve <decision-id>` or `hermes reject <decision-id>`.
> - Hermes polls `${RUNTIME}/decisions/` every 5 seconds for new `.response.json` files written by the CLI commands.
> - On read, Hermes validates the response (one-time use, TTL check, project/task binding), writes the final decision to the Audit layer, and deletes the response file.
>
> **Interface compliance:**
> - The file-based channel implements all REMOTE-02 operations:
>   - `notice` → write `.notice.json` to Runtime
>   - `decision_request` → write `.request.json` to Runtime
>   - `reply` → read `.response.json` from Runtime
>   - `healthcheck` → check directory writability and polling thread liveness
>   - `acknowledgement` → write `.ack.json` on receipt
>   - `timeout` → enforced by Hermes based on decision TTL
>   - `cancellation` → write `.cancel.json` to invalidate a pending request
>
> **Limitation disclosure:**
> - This fallback channel is local to the Hermes host. It does NOT push notifications to mobile devices or external services. A user must SSH back into the host to respond.
> - v1 acceptance scenarios for REMOTE MUST exercise both the fallback channel and the abstract interface. v2 will provide concrete adapters (webhook, Matrix, etc.) that implement the same interface.

#### 3.3.2 RISK-04 — Revised (Replace)

> **RISK-04 [REVISED]**
> The specification defines safe default behavior for timeout, remote channel failure, and ambiguous approval.
>
> **Timeout:**
> - Default L3/L4 timeout: 24 hours (configurable per project).
> - On timeout: the decision is automatically **rejected** (not approved).
> - Hermes writes a `timeout-rejection` audit record including the original request, the elapsed time, and the configured threshold.
> - Codex receives the rejection as a decision result and MUST terminate the current task branch.
> - The user MAY reactivate the task via `hermes retry <task-id>`, which re-queues the task from its last checkpoint (or from the beginning if no checkpoint exists).
> - Timeout rejection does NOT auto-re-escalate. Re-escalation requires explicit user action.
>
> **Remote channel failure:**
> - If a configured remote adapter fails healthcheck, Hermes:
>   1. Logs the failure to the Audit layer.
>   2. Immediately activates the file-based fallback channel (REMOTE-05).
>   3. Notifies the user on next SSH/tmux reconnection that remote channel is down and fallback is active.
>   4. Retries the remote adapter healthcheck every 60 seconds.
>   5. Does NOT drop pending decisions; they remain in the queue until resolved, rejected, or cancelled.
>
> **Ambiguous approval:**
> - If a user response does not match the structured choices (approve/reject/modify), Hermes:
>   1. Rejects the response as invalid.
>   2. Rewrites the decision request with a clearer prompt.
>   3. If ambiguity persists after 3 attempts, auto-rejects and escalates to manual user review via `hermes decisions`.

#### 3.3.3 SCOPE-03 — Revised (Append)

> **SCOPE-03 [REVISED — append to existing non-goals]**
> The following are also explicit non-goals for v1:
> - Concrete remote transport adapter (e.g. Telegram bot, Discord webhook, mobile push). REMOTE-01 mandates an abstraction; REMOTE-05 provides a local file fallback that implements the interface. A concrete network adapter is deferred to v2 (ADPT-01).
> - Push notification to devices outside the Hermes host. v1 remote decision requires the user to SSH back into the host or keep an active tmux session.

### 3.4 Rationale

REMOTE-05 gives v1 a real, testable implementation of the decision channel interface without violating REMOTE-01's abstraction principle. It acknowledges the practical limitation (no mobile push) while preserving the architecture for v2 adapters. The timeout semantics in RISK-04 eliminate the ambiguity between "safe default" and "cannot auto-approve" — rejection is the only safe choice, with an explicit retry path. The SCOPE-03 amendment sets correct user expectations about v1 capabilities.

---

## 4. Risk 3 — Risk Classification Authority

### 4.1 Original Requirements Affected

- **AGENT-02**: Claude "risk classification, review outputs, confidence, and escalation recommendations"
- **AGENT-04**: Codex "pause and ask a structured question when ... ambiguous"
- **AGENT-06**: "Codex can proceed only when the decision authority is sufficient for the classified risk level"
- **AUTH-02**: "what each actor may write, approve, reject, or never approve"
- **BUS-02**: schema envelopes for task, event, question, decision, escalation, result, review, archive records

### 4.2 Problem Statement

Three agents (Hermes, Claude, Codex) all touch risk classification, but authority boundaries are undefined. AGENT-02 says Claude does "risk classification" — but RISK-01 says the specification "defines risk levels, examples, owners." Is Claude applying preset rules or inventing them? If Codex disagrees with Claude's classification, who wins? If Claude under-classifies a dangerous operation, does Hermes have override authority? Without a schema for `claude-decision.md`, Codex cannot reliably extract the assessed level, authority level, or conditions — making AGENT-06 impossible to implement deterministically.

### 4.3 Revisions

#### 4.3.1 AUTH-02 — Revised (Replace)

> **AUTH-02 [REVISED]**
> The specification defines what each actor may write, approve, reject, escalate, or never approve. Authority is layered: static rules (Hermes) set the floor; dynamic assessment (Claude) may raise; execution judgment (Codex) may challenge but cannot override.
>
> | Actor | Authority | May Write | May Read | May Approve/Reject | Never Approve |
> |-------|-----------|-----------|----------|--------------------|---------------|
> | **Hermes** | Orchestration + rule enforcement | Task dispatch, bus routing, state snapshots, audit records, escalation routing, final decision writes | All bus layers, all projects | N/A (Hermes does not make technical decisions; it validates decision authority is sufficient before forwarding) | Any technical or architectural decision; any code review judgment |
> | **Claude** | Technical assessment + escalation recommendation | `claude-decision.md`, `review-result.md`, `escalation.md` | `task.md`, `codex-question.md`, `codex-result.md`, bus metadata | Low-risk (L1/L2) technical decisions within a single project | L3/L4 decisions; cross-project decisions; any decision with system-wide impact |
> | **Codex** | Execution + execution-time challenge | `codex-result.md`, `codex-question.md` | `task.md`, `claude-decision.md` | N/A (Codex never approves; it executes or challenges) | Any risk classification; any escalation decision; any action on another project |
> | **User** | Final arbiter for L3/L4 + policy override | Decision responses (via any channel), policy configuration | All audit records, all project status | L3/L4 decisions; policy overrides | N/A |
>
> **Three-layer classification authority:**
> 1. **Preset Rule Floor (Hermes):** Hermes loads the static risk rule table (RISK-01/RISK-02). The rule table maps operation types to minimum risk levels. Hermes validates every `claude-decision.md` against this table before forwarding. If the rule table mandates minimum L3 but Claude labels L2, Hermes upgrades to L3, appends a `rulebook_override` field to the decision, and records the override in the audit log.
> 2. **Technical Assessment (Claude):** Claude evaluates the specific context and may upgrade (increase risk level) from the rule table baseline. Claude MAY NOT downgrade — i.e., may not label an operation below the rule table minimum. Claude's classification is advisory above the floor and binding at the floor.
> 3. **Execution Challenge (Codex):** Codex reads the assessed level from `claude-decision.md`. If Codex encounters new risk factors during execution, it MAY pause and write a `codex-question.md` requesting re-assessment. This is a challenge, not an override. Hermes routes challenges to Claude. Claude may maintain the original classification or upgrade. The same task permits at most 3 challenge rounds; beyond 3, Hermes marks the task `stalled` and notifies the user for manual intervention.

#### 4.3.2 RISK-05 — New

> **RISK-05 [NEW]**
> Risk rule table structure and enforcement.
>
> The rule table is a static JSON file shipped with the specification (and later with the implementation). Each entry contains:
> ```json
> {
>   "rule_id": "R001",
>   "pattern": "database_schema_change",
>   "match_criteria": {
>     "file_glob": ["*migration*", "*schema*", "*.sql"],
>     "command_regex": ["DROP", "ALTER", "CREATE.*TABLE"],
>     "scope": "single_project"
>   },
>   "minimum_level": "L3",
>   "rationale": "Database schema changes affect data integrity and rollback complexity",
>   "overridable": false
> }
> ```
> - Hermes loads this table at startup.
> - On each `claude-decision.md` write, Hermes extracts the proposed operation type and checks against matching rules.
> - If multiple rules match, the highest minimum_level wins.
> - If `overridable: false`, Hermes unconditionally enforces the minimum level.
> - The rule table version is included in the audit record for every classified decision.

#### 4.3.3 BUS-02 — Revised (Append schema for `decision` envelope)

> **BUS-02 [REVISED — append to existing schema envelopes]**
>
> **Decision envelope (`claude-decision.md` / user response / audit record):**
> ```json
> {
>   "schema_version": "1.0",
>   "message_id": "uuid",
>   "project_id": "string",
>   "task_id": "string",
>   "correlation_id": "string",
>   "timestamp": "ISO8601",
>   "author": "claude|user|hermes",
>   "authority": "L1|L2|L3|L4",
>
>   "decision_type": "risk_classification | technical_decision | implementation_approval | user_override",
>   "rulebook": {
>     "version": "1.0",
>     "matched_rules": ["R001", "R007"],
>     "baseline_level": "L2",
>     "overridable": false
>   },
>   "assessment": {
>     "assessed_level": "L3",
>     "escalation_required": true,
>     "escalation_reason": "Schema change matched R001; baseline L2 upgraded to L3",
>     "confidence": "high|medium|low",
>     "conditions": ["Run tests in staging before deploy", "Require rollback script"]
>   },
>   "execution": {
>     "authority_sufficient": true,
>     "granted_by": "claude|user",
>     "granted_at": "ISO8601",
>     "expires_at": "ISO8601",
>     "challenge_count": 0,
>     "max_challenges": 3
>   },
>   "history": [
>     {
>       "event": "classified",
>       "actor": "claude",
>       "timestamp": "ISO8601",
>       "level": "L3"
>     }
>   ]
> }
> ```
> - `rulebook.baseline_level` is the minimum from the static rule table.
> - `assessment.assessed_level` is Claude's (or user's) final classification.
> - `execution.authority_sufficient` is set by Hermes after validating that the grantor's authority covers the assessed level.
> - `execution.challenge_count` increments on each Codex challenge.
> - `history` appends every state change for audit traceability.

#### 4.3.4 AGENT-07 — New

> **AGENT-07 [NEW]**
> Codex challenge mechanism constraints.
>
> - A single task permits at most **3 challenge rounds**. A challenge round consists of: Codex writes `codex-question.md` → Hermes routes to Claude → Claude writes revised `claude-decision.md` (maintain or upgrade) → Codex receives revised decision.
> - Hermes tracks `challenge_count` per task in the State layer. On count == 3, Hermes:
>   1. Sets task state to `stalled`.
>   2. Writes a `stalled` event to the Audit layer with reason `max_challenges_exceeded`.
>   3. Notifies the user via the active decision channel (REMOTE-05 fallback or configured adapter).
>   4. Does not re-route to Claude automatically; user must explicitly `hermes retry <task-id>` or `hermes override <task-id>`.
> - A challenge is valid only if it presents **new information** not present in the prior decision round. Hermes performs a lightweight deduplication check: if the `codex-question.md` body is ≥80% similar (Levenshtein ratio) to the previous challenge, Hermes rejects the challenge, writes a rejection notice to the Runtime bus, and instructs Codex to proceed with the current decision.
> - Claude's re-assessment must reference the new context. If Claude's revised decision is identical to the previous one (same assessed_level, same conditions, same rationale), Hermes flags it as `no_new_assessment` and increments challenge count without creating a new decision record.

### 4.4 Rationale

The three-layer authority model (preset floor → dynamic assessment → execution challenge) removes ambiguity about who decides what. Hermes enforces the rule table, preventing both accidental under-classification by Claude and endless back-and-forth by Codex. The decision schema makes AGENT-06 implementable: Codex reads `execution.authority_sufficient` and `assessment.assessed_level` deterministically. The challenge limit (3 rounds) prevents livelock. The deduplication rule prevents Codex from spamming questions to stall execution.

---

## 5. Cross-Cutting Impact

These three revisions are not independent. Their interaction:

| Interaction | Before Revision | After Revision |
|-------------|-----------------|----------------|
| Path + Remote | Decision requests in `/tmp` lost on cleanup; user never sees them | Decision requests in Runtime; pending queue in State; final decisions in Audit — all recoverable |
| Path + Risk | `claude-decision.md` in `/tmp` may be lost mid-upgrade, breaking authority chain | Decision file written to Runtime, migrated to Audit on completion; schema includes full history |
| Remote + Risk | L3/L4 blocks project with no recovery path on SSH disconnect | Timeout rejection with retry; fallback channel keeps queue alive; user reconnects and sees backlog |
| All three | Three agents disagree on risk → infinite loop or unsafe execution | Rule table floor prevents under-classification; challenge limit prevents infinite loop; schema enables deterministic enforcement |

---

## 6. Acceptance Criteria for This Revision

Before REQUIREMENTS-REV1.md is merged into REQUIREMENTS.md, the following must hold:

- [ ] Each revised requirement (RUNT-03, RISK-04, AUTH-02, BUS-02) is reviewed for consistency with all other v1 requirements.
- [ ] Each new requirement (BUS-06, REC-03, REMOTE-05, RISK-05, AGENT-07) has at least one VERIFY-01 scenario covering it.
- [ ] The decision schema (§4.3.3) validates against a JSON Schema draft-07 checker.
- [ ] The risk rule table (§4.3.2) includes at least 10 concrete rules covering: database schema, auth changes, secret handling, CI/CD, public API, system commands, dependency updates, file deletion, network config, and cost-sensitive operations.
- [ ] The path layout (§2.3.1) is reviewed for compatibility with no-sudo Ubuntu environments and tmux session persistence.

---

## 7. Traceability Update

| Requirement | Status | Origin |
|-------------|--------|--------|
| RUNT-03 | REVISED | §2.3.1 |
| BUS-02 | REVISED | §4.3.3 |
| AUTH-02 | REVISED | §4.3.1 |
| RISK-04 | REVISED | §3.3.2 |
| SCOPE-03 | REVISED | §3.3.3 |
| BUS-06 | NEW | §2.3.2 |
| REC-03 | NEW | §2.3.3 |
| REMOTE-05 | NEW | §3.3.1 |
| RISK-05 | NEW | §4.3.2 |
| AGENT-07 | NEW | §4.3.4 |

---

*Revision drafted: 2026-04-25*  
*Pending: review and merge into REQUIREMENTS.md*
