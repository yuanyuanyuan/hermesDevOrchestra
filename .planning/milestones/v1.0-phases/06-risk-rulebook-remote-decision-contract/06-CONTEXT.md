# Phase 6: Risk Rulebook & Remote Decision Contract - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Smart discuss defaults accepted for autonomous spec-package execution

<domain>
## Phase Boundary

Reviewers can verify that risk gates, rule enforcement, high-risk blocking, and local fallback decisions are safe and replay-resistant.

This is documentation/specification work only. No runnable Hermes orchestrator is implemented in v1.

</domain>

<decisions>
## Implementation Decisions

### Specification Boundary
- Risk levels define owners, examples, default actions, timeout behavior, and user-required cases.
- The static rule table has 10 concrete rules and is loaded by Hermes at startup.
- Hermes upgrades any Claude classification below the rulebook floor and records rulebook overrides in audit.
- L3/L4 blocks remain blocked until explicit user approval or rejection; timeouts and ambiguous replies reject safely.
- Remote Decision Channel is transport-neutral and includes a file-based local fallback without external network assumptions.

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
