# Phase 15: Specification System - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 15 establishes a `specs/` derived specification system while preserving `.planning/SPEC.md` as the canonical specification. This phase creates only derived specs with current consumers, defines how each derived spec declares source/consumer/drift/conformance metadata, and adds failing conformance checks for those specs. It does not add runtime capabilities, remote adapters, or Makefile workflow targets.

</domain>

<decisions>
## Implementation Decisions

### Derived Spec Inventory and Consumers
- **D-01:** Use a minimum effective derived spec inventory: create only specs that have current repository consumers.
- **D-02:** Create `specs/file-bus.md`. Current consumers are `docs/orchestra/scripts/bin/orch-bus-loop`, file-bus smoke tests, `docs/orchestra/README.md`, and `docs/orchestra/WORKFLOW.md`.
- **D-03:** Create `specs/risk-decisions.md`. Current consumers are `docs/orchestra/scripts/bin/orch-risk-check`, `docs/orchestra/config/rules.json`, decision CLI helpers, and risk/decision smoke tests.
- **D-04:** Create `specs/commands.md`. Current consumers are `orch-*` scripts, `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md`, and docs smoke tests.
- **D-05:** Create `specs/README.md` as the index for derived specs and their consumers.

### Spec File Shape and Metadata
- **D-06:** Each derived spec uses fixed Markdown sections: `## Source`, `## Consumers`, `## Drift Check`, and `## Conformance Checks`.
- **D-07:** Each derived spec points to relevant `.planning/SPEC.md` sections as the primary source. `docs/orchestra/*` documents may be cited as implementation projections, not as competing authorities.
- **D-08:** Consumers must be listed as concrete file paths. Categories may be added for readability, but concrete paths are authoritative.
- **D-09:** Derived specs should extract only downstream-required, checkable contracts. They should not duplicate the full canonical specification.

### Conformance Checks
- **D-10:** Add `docs/orchestra/scripts/tests/test-specs.sh` for derived spec conformance checks.
- **D-11:** Rely on existing `docs/orchestra/scripts/tests/run-all.sh` discovery so `orch-verify` reaches `test-specs.sh`.
- **D-12:** For every derived spec, the test must fail if required fixed sections are missing, the primary source does not point to `.planning/SPEC.md`, a listed concrete consumer path does not exist, a drift check command is missing, or no conformance check is listed.
- **D-13:** `specs/README.md` must index every `specs/*.md` file and list its consumers. Tests should fail if a spec file is not indexed.
- **D-14:** Do not add Makefile targets in Phase 15. Phase 16 owns Makefile creation; Phase 15 only ensures the existing smoke runner can execute spec checks.

### Canonical Conflict Handling
- **D-15:** `.planning/SPEC.md` always wins over `specs/*.md`.
- **D-16:** `specs/*.md` files are projections, not authorities. If a derived spec conflicts with `.planning/SPEC.md`, update the derived spec to match canonical.
- **D-17:** If implementation code conflicts with a derived spec, conformance checks should fail fast and point to either updating the implementation or updating canonical first and then regenerating/revising the derived spec.
- **D-18:** If `.planning/SPEC.md` is stale or missing v1.2 detail, Phase 15 should not perform broad canonical rewrites. Record a deferred follow-up or make only the smallest necessary reference clarification.
- **D-19:** Downstream agents should read in this order: `.planning/SPEC.md`, then relevant `specs/*.md`, then `docs/orchestra/*` implementation projections.

### the agent's Discretion
- Exact wording and section ordering inside each derived spec, as long as the fixed required sections exist.
- Exact grep/Python/Bash implementation details of `test-specs.sh`.
- Exact drift check command text, provided it is concrete and can fail.
- Exact grouping in `specs/README.md`, provided every spec file is indexed with concrete consumers.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning Authority
- `.planning/SPEC.md` - Canonical specification; primary authority for derived specs.
- `.planning/REQUIREMENTS.md` - Defines SPEC-01 and SPEC-02 for Phase 15.
- `.planning/ROADMAP.md` - Phase 15 goal, success criteria, and dependency on Phase 14.
- `.planning/STATE.md` - Current project state and Phase 14 decisions carried forward.

### Implementation Projections
- `docs/orchestra/README.md` - Product behavior baseline and command/documentation projection.
- `docs/orchestra/WORKFLOW.md` - Workflow projection and command/user-flow details.
- `docs/COVERAGE-MATRIX.md` - Existing capability coverage projection that may inform derived spec consumers.

### Script Consumers
- `docs/orchestra/scripts/bin/orch-bus-loop` - File bus routing consumer.
- `docs/orchestra/scripts/bin/orch-risk-check` - Risk rulebook consumer.
- `docs/orchestra/config/rules.json` - Risk floor data consumed by risk checks.
- `docs/orchestra/scripts/bin/orch-init` - Command/package boundary consumer.
- `docs/orchestra/scripts/bin/orch-start` - Command/package boundary consumer.
- `docs/orchestra/scripts/bin/orch-stop` - Command/package boundary consumer.
- `docs/orchestra/scripts/bin/orch-status` - Command/package boundary consumer.
- `docs/orchestra/scripts/bin/orch-decisions` - Decision fallback command consumer.
- `docs/orchestra/scripts/bin/orch-approve` - Decision fallback command consumer.
- `docs/orchestra/scripts/bin/orch-reject` - Decision fallback command consumer.
- `docs/orchestra/scripts/bin/orch-audit` - Audit command consumer.
- `docs/orchestra/scripts/bin/orch-verify` - Smoke verification entrypoint consumer.
- `docs/orchestra/scripts/tests/run-all.sh` - Existing smoke runner that should discover `test-specs.sh`.

### Test Consumers and Patterns
- `docs/orchestra/scripts/tests/lib/assert.sh` - Existing Bash assertion helpers.
- `docs/orchestra/scripts/tests/test-file-bus.sh` - File bus conformance consumer.
- `docs/orchestra/scripts/tests/test-risk-check.sh` - Risk check conformance consumer.
- `docs/orchestra/scripts/tests/test-risk-decisions.sh` - Risk decision flow conformance consumer.
- `docs/orchestra/scripts/tests/test-decision-cli.sh` - Decision CLI conformance consumer.
- `docs/orchestra/scripts/tests/test-docs.sh` - Documentation smoke test pattern.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/orchestra/scripts/tests/lib/assert.sh`: Existing Bash assertion library for failing checks.
- `docs/orchestra/scripts/tests/run-all.sh`: Discovers and runs `test-*.sh`, so a new `test-specs.sh` is automatically included.
- `docs/orchestra/scripts/bin/orch-verify`: Calls the package or installed smoke runner, giving Phase 15 checks a user-facing verification path.

### Established Patterns
- Smoke tests are pure Bash scripts under `docs/orchestra/scripts/tests/`.
- Existing tests use concrete path/content assertions rather than external test frameworks.
- Documentation projections live under `docs/orchestra/`; planning authority remains in `.planning/`.

### Integration Points
- Add `specs/README.md`, `specs/file-bus.md`, `specs/risk-decisions.md`, and `specs/commands.md`.
- Add `docs/orchestra/scripts/tests/test-specs.sh`.
- Keep Makefile work out of Phase 15; Phase 16 can later wire the existing smoke tests into make targets.

</code_context>

<specifics>
## Specific Ideas

- Treat derived specs as narrow, checkable projections for concrete consumers.
- Make the "no current consumer, no derived spec" rule visible in `specs/README.md`.
- Prefer simple failing checks over broad prose review.
- Do not let `docs/orchestra/*` or `specs/*.md` challenge `.planning/SPEC.md`.

</specifics>

<deferred>
## Deferred Ideas

- Full split of all major `.planning/SPEC.md` sections is deferred until concrete consumers exist.
- Makefile targets for spec checks are deferred to Phase 16.
- Broad `.planning/SPEC.md` rewrites for v1.2 detail gaps are deferred unless a later phase explicitly scopes them.

</deferred>

---

*Phase: 15-specification-system*
*Context gathered: 2026-04-28*
