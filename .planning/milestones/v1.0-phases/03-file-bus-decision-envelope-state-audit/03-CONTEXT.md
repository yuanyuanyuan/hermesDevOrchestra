# Phase 3: File Bus, Decision Envelope, State & Audit - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Smart discuss defaults accepted for autonomous spec-package execution

<domain>
## Phase Boundary

Reviewers can validate the canonical bus protocol, decision schema, task state machine, and durable audit model without running agents.

This is documentation/specification work only. No runnable Hermes orchestrator is implemented in v1.

</domain>

<decisions>
## Implementation Decisions

### Specification Boundary
- JSON/JSONL is canonical for bus messages; Markdown is only a human-readable projection.
- Every bus message includes schema version, IDs, status, author, authority, risk level, and timestamps.
- Decision envelopes include rulebook, assessment, execution, and history fields.
- Single-writer ownership, atomic rename, file locking, stale rejection, correlation checks, schema validation, and archive rules are mandatory.
- Runtime bus files are not durable evidence; final records must migrate to Audit before acceptance.

### the agent's Discretion
- Use concise, checkable Markdown contracts rather than speculative implementation detail.
- Prefer existing project terminology from PROJECT.md, REQUIREMENTS.md, ROADMAP.md, and SPEC.md.
- Keep all changes inside .planning/ unless referencing source input documents as evidence.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- .planning/SPEC.md already contains the unified v1 specification draft.
- .planning/REQUIREMENTS.md contains authoritative v1 requirement IDs and traceability.
- .planning/ROADMAP.md defines phase goals and success criteria.

### Established Patterns
- JSON/JSONL is the canonical protocol; Markdown is human-readable projection.
- GSD artifacts live in .planning/phases/{phase}/ and remain separate from source input documents.

### Integration Points
- Phase completion updates ROADMAP.md, REQUIREMENTS.md, STATE.md, and phase verification evidence.

</code_context>

<specifics>
## Specific Ideas

- Treat docs/hermes-dev-orchestra/ as source input, not as the canonical v1 contract.
- Ensure each requirement in this phase is independently traceable to SPEC.md sections.

</specifics>

<deferred>
## Deferred Ideas

- Runnable Hermes CLI/tool implementation is deferred to the implementation roadmap after v1 spec acceptance.
- Concrete remote transport adapters are deferred to v2 adapter work.

</deferred>
