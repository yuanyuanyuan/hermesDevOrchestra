# Phase 22: External CLI Engine Protocol & Role Invocation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-11
**Phase:** 22-external-cli-engine-protocol-role-invocation
**Areas discussed:** Engine configuration ownership, Protocol minimum surface, Context accumulation boundary, Failure and fallback policy

---

## Engine Configuration Ownership

### Project override authority

| Option | Description | Selected |
|--------|-------------|----------|
| Base defaults, full project override | Project override may replace `cli`, `mode`, `flags`, and `fallback` | ✓ |
| Base locks `cli/mode` | Project override may only change `flags` and `fallback` | |
| Base fully locks engine | Project override may only change Hermes routing-layer model | |

**User's choice:** Base only provides defaults; project override may replace all engine fields.
**Notes:** User preferred maximum per-project flexibility so a project can switch `implementer` or `devops` engines without changing the canonical profile catalog.

### Canonical default location

| Option | Description | Selected |
|--------|-------------|----------|
| Per-role `config.yaml` | Each profile keeps its own default engine settings | ✓ |
| Central engine matrix | Separate file injected by `orch-profile-sync` | |
| Mixed split | `cli/mode` local, shared `flags/fallback` template | |

**User's choice:** Canonical defaults live in each role's `config.yaml`.
**Notes:** User rejected an extra centralized mapping layer.

### Merge semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Deep merge | Project override may replace only specific engine fields | ✓ |
| Whole-object replace | Any `engine:` override replaces the full object | |
| Hybrid replace | `cli/mode` trigger full replace, `flags/fallback` may inherit | |

**User's choice:** `orch-profile-sync` must deep-merge engine fields.
**Notes:** User wanted partial override safety without forcing projects to restate every field.

### Fallback enablement

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit only | Fallback is active only when declared in profile config | ✓ |
| Auto-default for some roles | `implementer/devops` get implicit fallback defaults | |
| Mandatory for all roles | Every role must declare a fallback | |

**User's choice:** Fallback is opt-in only.
**Notes:** User preferred explicit, auditable behavior over hidden resiliency defaults.

---

## Protocol Minimum Surface

### First closure set

| Option | Description | Selected |
|--------|-------------|----------|
| `pm + implementer + reviewer` | Close the main task decomposition, execution, and review loop first | ✓ |
| All seven execution roles | Full role rollout in Phase 22 | |
| `implementer + reviewer` only | Leave PM outside the first closure set | |

**User's choice:** Phase 22 first fully closes `pm + implementer + reviewer`.
**Notes:** User wanted enough protocol surface to unblock later routing work without inflating this phase to all roles.

### Artifact granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Common envelope + 3 role contracts | Shared envelope plus `pm`, `implementer`, and `reviewer` schema/examples | ✓ |
| Common envelope only | Role differences described in prose only | |
| Full JSON Schema system | Formal schema files plus validation tooling immediately | |

**User's choice:** Ship the common envelope plus role-specific contracts/examples for the first three roles.
**Notes:** User wanted something concrete enough for implementation, but not a premature full schema-engineering project.

### `next_action` style

| Option | Description | Selected |
|--------|-------------|----------|
| Shared small enum | Cross-role `next_action` set, role nuance in payload | ✓ |
| Per-role enums | Every role defines custom `next_action` values | |
| Status-only routing | Omit `next_action`, route from `status` only | |

**User's choice:** Shared small `next_action` enum.
**Notes:** User favored simpler orchestrator logic and less protocol drift.

### `status` strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Role-specific `status` enums | Each role defines its own statuses; keep a cross-role comparison table | ✓ |
| One global `status` enum | Force all roles into one shared status vocabulary | |
| First-three-only status docs | Define statuses only for the initial roles and defer the rest | |

**User's choice:** Role-specific `status` enums with a comparison table.
**Notes:** User wanted real role semantics preserved without pretending all roles share the same status language.

### `correlation_id` semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Trace only | Pure tracing field, no resume or authority meaning | ✓ |
| Resume anchor | Also used for call-chain resume | |
| Authority key | Part of permission/authority validation | |

**User's choice:** `correlation_id` is trace-only.
**Notes:** User stayed aligned with the new metadata-based recovery model and rejected session-style coupling.

---

## Context Accumulation Boundary

### Minimum canonical metadata

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal runtime set | Keep only `conversation_history`, `handoff_from_parent`, `task_summary/current_stage`, `last_engine_error`, `rollback_count` | ✓ |
| Broad capture | Store tests, changed files, findings, deploy progress, snapshot refs, etc. immediately | |
| Ultra-minimal | Keep only history and handoff | |

**User's choice:** Minimal runtime set only.
**Notes:** User wanted enough state for recovery without turning metadata into a catch-all store.

### Conversation history form

| Option | Description | Selected |
|--------|-------------|----------|
| Structured turns | Store role/content/turn/decision tags and allow later compaction | ✓ |
| Raw transcript blob | Store the entire transcript as plain text | |
| Summary-only | Keep only per-round summaries | |

**User's choice:** Structured turns with compaction support.
**Notes:** User wanted PM clarification and worker recovery to remain machine-consumable.

### Comment role

| Option | Description | Selected |
|--------|-------------|----------|
| Audit summary only | Comments are human-facing audit artifacts, not recovery truth | ✓ |
| Metadata fallback | Comments may be read if metadata is incomplete | |
| Dual truth | Comments and metadata are equivalent state sources | |

**User's choice:** Comments are audit-only.
**Notes:** User explicitly avoided reintroducing mixed truth sources.

### Handoff granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Summary + refs | Structured summary plus references/paths to large artifacts | ✓ |
| Full raw inline handoff | Parent output copied directly into metadata | |
| One-line summary only | Minimal human summary only | |

**User's choice:** Handoff uses summary plus references only.
**Notes:** User preferred metadata that stays compact and less vulnerable to prompt-injection via giant raw payloads.

### Long-history compaction

| Option | Description | Selected |
|--------|-------------|----------|
| Summary + recent raw turns | Keep a summary of older context plus the most recent N raw turns | ✓ |
| Silent oldest-first truncation | Drop oldest raw content when size grows | |
| Role-specific compaction rules | Let each role decide independently | |

**User's choice:** Summary plus recent raw turns.
**Notes:** User rejected silent truncation and role-by-role divergence.

---

## Failure and Fallback Policy

### Primary recovery ladder

| Option | Description | Selected |
|--------|-------------|----------|
| Retry once, then block | Retry the same engine once; then block; fallback only if explicitly configured | ✓ |
| Fallback first | Switch engines before deciding to block | |
| Block immediately | No automatic recovery step | |

**User's choice:** Retry once, then block; fallback only when explicitly configured.
**Notes:** User wanted deterministic recovery without hiding errors behind aggressive auto-switching.

### Fallback audit visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit workflow audit event | Record original engine, trigger reason, and fallback engine in metadata/comments | ✓ |
| Logs only | Keep fallback detail in low-level logs only | |
| Hidden on success | Do not expose fallback once it succeeds | |

**User's choice:** Fallback must be workflow-visible and auditable.
**Notes:** User prioritized diagnosability over cleaner-looking runtime history.

### Hard-stop failure types

| Option | Description | Selected |
|--------|-------------|----------|
| Parse-error + schema mismatch | Both hard-block, no auto-fallback | ✓ |
| Only schema mismatch | Parse-error may still try fallback | |
| All failures may fallback | No protocol-level hard stops | |

**User's choice:** `JSON parse-error` and `protocol schema mismatch` both hard-block.
**Notes:** User wanted protocol contract drift to surface immediately rather than be silently worked around.

### Timeout shape

| Option | Description | Selected |
|--------|-------------|----------|
| Shared recovery, role-specific defaults | Same recovery ladder, different default timeouts per role | ✓ |
| One global timeout | Same threshold for every role | |
| Role × task-type matrix | Fine-grained defaults immediately | |

**User's choice:** Shared recovery semantics with role-specific default thresholds.
**Notes:** User wanted the policy shape locked without prematurely designing a large timeout matrix.

### Post-fallback next call behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Return to primary next time | Successful fallback does not change the role's long-term primary engine | ✓ |
| Stay on fallback for task lifetime | Use fallback for the rest of the task once switched | |
| Rewrite profile default | Persist fallback as the new default engine | |

**User's choice:** Next invocation still starts with the primary engine.
**Notes:** User kept runtime fallback separate from config mutation.

---

## the agent's Discretion

- Exact artifact filenames and directory layout for the protocol specs/examples
- Exact metadata field names for fallback and compaction bookkeeping
- Exact numeric timeout defaults per role
- Exact "recent N turns" threshold for compaction

## Deferred Ideas

None.
