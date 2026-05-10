# Phase 20: Capability Verification & Boundary Lock - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 20 only establishes executable evidence for which Hermes capabilities used by the phase 19 workflow design are truly official and usable in the current environment, then locks the boundary between official coverage and local extension work. It does not implement profile overrides, dispatcher behavior, risk policy, worker lifecycle, or observability features themselves.

</domain>

<decisions>
## Implementation Decisions

### Verification Evidence Standard
- **D-20-01:** Capability verification uses a minimum-runnable-evidence standard. If a capability can be exercised locally with a minimal end-to-end command path, the verification matrix must include the exact command, exit code, and key output fragment from that local run.
- **D-20-02:** Documentation-only or help-level evidence is allowed only for capabilities that are clearly not practical to close locally in this environment during Phase 20. Those entries must be labeled explicitly so they are distinguishable from local runtime verification.

### Matrix-First Writeback Flow
- **D-20-03:** Verification verdicts are gathered into a dedicated capability-verification matrix first. Phase 19 design documents are updated only after the matrix has a stable set of verdicts.
- **D-20-04:** Any capability that fails official verification must be reclassified through the matrix before downstream docs are edited. The matrix is the audit entrypoint; document edits are a later consolidation step.

### Failed Verification Handling
- **D-20-05:** Unsupported or unverified official-claim items must be converted into follow-up backlog work automatically rather than being dropped silently.
- **D-20-06:** Those follow-up items land in `.planning/ROADMAP.md` backlog, not only in narrative notes, so later phases have an execution entrypoint.

### the agent's Discretion
- Downstream research and planning should decide the exact first-pass official capability subset for Phase 20, rather than asking the user again in discuss-phase.
- Downstream research and planning should decide the version anchor strategy for the matrix (for example, exact local install vs. design-target version), provided the chosen strategy is stated explicitly in the Phase 20 research and plan artifacts.
- The exact matrix schema, status names, and backlog entry format are left to research and planning, as long as they preserve the matrix-first audit flow and unsupported-item backlog rule above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 20 scope and milestone authority
- `.planning/ROADMAP.md` — Phase 20 goal, success criteria, execution order, and backlog destination already used by this milestone.
- `.planning/REQUIREMENTS.md` — VFY-01 and VFY-02 plus the MVP-vs-full boundary for v1.3/v1.4.
- `.planning/PROJECT.md` — Current milestone framing, active scope, and the rule that phase 19 is a design-source directory for two later execution milestones.
- `.planning/STATE.md` — Current milestone status and carry-forward decisions from prior phases.

### Phase 19 design-source documents
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` — F0 Phase 0 capability-confirmation flow, R1/R2, and deferred technical questions that remain downstream concerns.
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` — Appendix A official-capability table and the core architecture claims that must be verified or downgraded.
- `.planning/phases/19-hermes-workflow-design/WORKFLOW-EXPLAINED.md` — Narrative mapping of `[Hermes 官方]` vs `[Phase 19 增量]` labels, useful for finding where official claims leak into the design package.
- `.planning/phases/19-hermes-workflow-design/WORKFLOW-ASCII-DIAGRAMS.md` — Cross-reference map from requirements to workflow subflows, especially the F0 capability-verification path.

### Hermes docs retrieval workflow
- `reference/hermes-docs-index/SKILL.md` — Mandatory retrieval procedure for Hermes documentation questions in this repository; downstream research must use the index-first workflow instead of memory.
- `reference/hermes-docs-index/hermes_docs_index.md` — Human-readable navigation index for official Hermes docs pages such as Kanban, profiles, gateway, memory, and plugins.
- `reference/hermes-docs-index/hermes_docs_index.json` — Machine index for locating exact Hermes docs pages and command references during verification research.

### Existing repository projections that may need later correction
- `docs/orchestra/README.md` — Current user-facing workflow projection that may contain claims needing downgrade after the matrix settles.
- `docs/orchestra/WORKFLOW.md` — Current workflow projection that may also need alignment after official/local boundaries are verified.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `reference/hermes-docs-index/` — Repository-local Hermes docs retrieval aid; strongest existing asset for locating exact official command and feature pages before making verification claims.
- `docs/orchestra/README.md` and `docs/orchestra/WORKFLOW.md` — Existing public-facing projections that provide a concrete comparison surface for later writeback after the matrix is complete.
- `.planning/phases/18-architecture-bounds-verification/18-CONTEXT.md`, `18-RESEARCH.md`, and `18-01-PLAN.md` — Recent example of evidence-first documentation work that clarified architectural boundaries before broader implementation.

### Established Patterns
- `.planning/` holds canonical planning and milestone artifacts; `docs/orchestra/` is a derived, human-facing projection layer.
- Recent planning work prefers verification-first documentation changes, explicit boundary language, and grep/test evidence before marking requirements complete.
- This repository treats phase source packages under `.planning/phases/NN-*` as durable references rather than disposable scratch docs; Phase 19 must remain intact as a design source.

### Integration Points
- Phase 20 will likely create its own capability-verification artifacts inside `.planning/phases/20-capability-verification-boundary-lock/`.
- Matrix verdicts must later feed into `.planning/phases/19-hermes-workflow-design/DESIGN.md` and `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md`.
- Unsupported official-claim items must connect to `.planning/ROADMAP.md` backlog entries rather than staying as buried notes.

</code_context>

<specifics>
## Specific Ideas

- A useful matrix distinction is between locally runnable verification and documentation-backed verification, because the user explicitly prefers local runnable evidence whenever feasible.
- The official-capability sweep should start from Phase 19 Appendix A plus every `[Hermes 官方]` label, not from generic feature brainstorming.
- Unsupported items should produce backlog entries that point back to the failed matrix row, so later phases know exactly which official claim broke.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---
*Phase: 20-capability-verification-boundary-lock*
*Context gathered: 2026-05-10*
