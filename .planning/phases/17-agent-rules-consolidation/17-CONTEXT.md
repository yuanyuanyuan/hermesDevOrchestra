# Phase 17: Agent Rules Consolidation - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 17 consolidates Dev Orchestra agent rules in `AGENTS.md` without overwriting existing managed sections, and verifies that `CLAUDE.md` points to `AGENTS.md` and `.planning/SPEC.md` as authorities instead of duplicating all rules.

Current repository evidence shows `AGENTS.md` already contains the Dev Orchestra managed block and `CLAUDE.md` already contains authority pointers. This phase is therefore a convergence and verification phase: inspect, patch only real gaps, and verify.

**In scope:**
- Verify `AGENTS.md` preserves all existing managed sections.
- Verify the Dev Orchestra block contains Package Boundary and Agent Role Boundary coverage.
- Patch `AGENTS.md` only if actual gaps or stale references are found.
- Verify `CLAUDE.md` remains pointer-only and references `AGENTS.md` plus `.planning/SPEC.md`.
- Run static agent-rule checks and `make test`.

**Out of scope:**
- Rewriting the full Dev Orchestra section when current content already satisfies the contract.
- Copying `.planning/SPEC.md` or `AGENTS.md` rules into `CLAUDE.md`.
- Adding new runtime capabilities, new `orch-*` commands, or changing upstream Hermes Agent core code.
- Changing `~/.hermes-orchestra/rules.json`.

</domain>

<decisions>
## Implementation Decisions

### Phase Scope Handling
- **D-17-01:** Treat Phase 17 as minimal verification and necessary small fixes. Do not perform a broad rewrite of existing agent rules.
- **D-17-02:** If `AGENTS.md` and `CLAUDE.md` already satisfy the Phase 17 success criteria, implementation may be verification-only for those files.

### `AGENTS.md` Dev Orchestra Block
- **D-17-03:** Keep the existing `<!-- hermes-dev-orchestra-start -->` / `<!-- hermes-dev-orchestra-end -->` block concise.
- **D-17-04:** Patch only real gaps: stale paths, missing required sections, missing actual `orch-*` helpers, inaccurate authority wording, or managed-section damage.
- **D-17-05:** Do not expand `AGENTS.md` into a duplicate of `.planning/SPEC.md`. The Dev Orchestra block should remain a navigation and boundary summary.

### `CLAUDE.md` Handling
- **D-17-06:** Keep `CLAUDE.md` pointer-only for Dev Orchestra authority.
- **D-17-07:** `CLAUDE.md` should reference `AGENTS.md` for agent rules and `.planning/SPEC.md` for canonical specification authority.
- **D-17-08:** Do not copy the full Dev Orchestra rule set into `CLAUDE.md`; avoid future drift between agent instruction files.

### Merge Verification Standard
- **D-17-09:** Phase 17 verification must include static agent-rule checks plus `make test`.
- **D-17-10:** Static checks should cover managed marker preservation, Dev Orchestra delimiter presence, required headings, actual helper list coverage, L3/L4 no-auto-approval wording, and `CLAUDE.md` authority pointers.

### the agent's Discretion
- Exact grep/Python/Bash implementation for static checks.
- Exact wording of small fixes if a real gap is found.
- Whether no `AGENTS.md` / `CLAUDE.md` source edit is needed when verification already passes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning Authority
- `.planning/REQUIREMENTS.md` - Defines AGNT-01 and AGNT-02.
- `.planning/ROADMAP.md` - Phase 17 goal and success criteria.
- `.planning/PROJECT.md` - Current v1.2 state and adapter-layer constraints.
- `.planning/STATE.md` - Current project position and accumulated decisions.
- `.planning/SPEC.md` - Canonical specification, especially command, agent, and risk authority boundaries.

### Prior Phase Decisions
- `.planning/phases/13-evidence-audit-and-discoverability/13-CONTEXT.md` - Original append-only `AGENTS.md` and pointer-only `CLAUDE.md` decisions.
- `.planning/phases/13-evidence-audit-and-discoverability/13-01-SUMMARY.md` - Evidence that current `AGENTS.md` / `CLAUDE.md` content was already added and verified.
- `.planning/phases/14-migration-submodule-adr/14-CONTEXT.md` - `docs/orchestra/` path migration and no old-path compatibility decision.
- `.planning/phases/15-specification-system/15-CONTEXT.md` - `.planning/SPEC.md` remains canonical; derived specs are projections.
- `.planning/phases/16-makefile-dev-workflow/16-01-SUMMARY.md` - `make test` is available as the local verification entrypoint.

### Files Under Direct Review
- `AGENTS.md` - Agent rules and Dev Orchestra boundary block.
- `CLAUDE.md` - Claude-facing entrypoint that should point to authorities without duplicating them.
- `Makefile` - Local verification target surface; `make test` is the selected Phase 17 verification gate.
- `specs/commands.md` - Derived command surface projection for the actual `orch-*` helper list.
- `specs/risk-decisions.md` - Derived risk decision projection for L3/L4 blocking and no-auto-approval behavior.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AGENTS.md`: Already contains a delimited Dev Orchestra block with Package Boundary, Agent Role Boundary, and Directory Navigation.
- `CLAUDE.md`: Already contains `## Hermes Dev Orchestra References` pointing to `AGENTS.md` and `.planning/SPEC.md`.
- `Makefile`: Provides `make test`, aggregating smoke tests, risk tests, JSON lint, shell lint, and upstream pin status.
- `specs/commands.md`: Lists the current `orch-*` helper surface.
- `specs/risk-decisions.md`: Captures L3/L4 blocking and no timeout/fallback auto-approval behavior.

### Established Patterns
- GSD-managed content in `AGENTS.md` is protected by `<!-- GSD:* -->` delimiters.
- Project-specific Dev Orchestra rules use `<!-- hermes-dev-orchestra-start -->` and `<!-- hermes-dev-orchestra-end -->`.
- `CLAUDE.md` should be a pointer file for Dev Orchestra authority, not a second copy of the full rules.
- `.planning/SPEC.md` is canonical; `specs/*.md` and `docs/orchestra/*` are projections.

### Integration Points
- If source edits are needed, they should be limited to `AGENTS.md` and/or `CLAUDE.md`.
- Planning artifacts for this phase live under `.planning/phases/17-agent-rules-consolidation/`.
- Verification should run from the repository root.

</code_context>

<specifics>
## Specific Ideas

Suggested static verification coverage:

```bash
grep -q '<!-- GSD:project-start' AGENTS.md
grep -q '<!-- GSD:workflow-end -->' AGENTS.md
grep -q '<!-- hermes-dev-orchestra-start -->' AGENTS.md
grep -q '<!-- hermes-dev-orchestra-end -->' AGENTS.md
grep -q '### Package Boundary' AGENTS.md
grep -q '### Agent Role Boundary' AGENTS.md
for cmd in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-audit orch-decisions orch-approve orch-reject orch-verify; do grep -q "$cmd" AGENTS.md; done
grep -q 'must not auto-approve L3/L4' AGENTS.md
grep -q 'Hermes Dev Orchestra References' CLAUDE.md
grep -q 'AGENTS.md' CLAUDE.md
grep -q '.planning/SPEC.md' CLAUDE.md
make test
```

No specific wording changes are required unless the checks expose a real mismatch.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within Phase 17 scope.

</deferred>

---

*Phase: 17-agent-rules-consolidation*
*Context gathered: 2026-04-28*
