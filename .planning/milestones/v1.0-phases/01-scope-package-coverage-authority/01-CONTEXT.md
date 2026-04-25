# Phase 1: Scope, Package Coverage & Authority - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Smart discuss defaults accepted for autonomous spec-package execution

<domain>
## Phase Boundary

Reviewers can verify the v1 spec package scope, inline coverage model, and decision authority boundaries before any downstream contracts are planned.

This is documentation/specification work only. No runnable Hermes orchestrator is implemented in v1.

</domain>

<decisions>
## Implementation Decisions

### Specification Boundary
- v1 remains a standalone specification package, not a runnable orchestrator implementation.
- The primary persona is a single developer using SSH/Hermes CLI for append-anytime multi-project work.
- The Remote Decision Channel stays abstract; v1 does not bind to Telegram, Discord, or another transport.
- Hermes enforces static risk floors; Claude may upgrade but not downgrade below floors; Codex may challenge but never approve.
- L3/L4 decisions require explicit user approval and are never auto-approved by timeout or fallback.

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
