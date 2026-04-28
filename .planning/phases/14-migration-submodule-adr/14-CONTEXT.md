# Phase 14: Migration & Submodule ADR - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase decides and executes the Dev Orchestra directory migration based on Phase 13 evidence, then writes an upstream pin ADR for `NousResearch/hermes-agent`.

**In scope:**
- Migrate `docs/hermes-dev-orchestra/` to `docs/orchestra/` using `git mv`.
- Update references so the old `docs/hermes-dev-orchestra/` path is not a supported compatibility path.
- Write an ADR comparing installer/probe pin, git submodule, manifest pin, and vendor snapshot.
- Select manifest pin as the v1.2 upstream pin strategy.
- Verify migration and ADR outputs against Phase 14 success criteria.

**Out of scope:**
- Creating the Phase 15 `specs/` derived specification system.
- Creating the Phase 16 Makefile or `make upstream-status` target.
- Consolidating broad agent rules beyond references affected by the migration.
- Adopting git submodule in this phase.

</domain>

<decisions>
## Implementation Decisions

### Directory Migration

- **D-14-01:** Execute the directory migration. The target path is `docs/orchestra/`.
- **D-14-02:** Use `git mv docs/hermes-dev-orchestra docs/orchestra` for the physical move.
- **D-14-03:** Do not keep a compatibility shim, duplicate directory, symlink, or supported pointer at `docs/hermes-dev-orchestra/`.
- **D-14-04:** Update references instead of preserving old-path compatibility. The planning target is that `rg -n "docs/hermes-dev-orchestra"` returns zero actionable old-path references after migration. If a historical planning artifact cannot be updated without corrupting audit evidence, the plan must call that out explicitly before execution.

### Upstream Pin ADR

- **D-14-05:** The ADR must compare all four required strategies: installer/probe pin, git submodule, manifest pin, and vendor snapshot.
- **D-14-06:** Select **manifest pin** as the recommended and intended v1.2 strategy.
- **D-14-07:** The manifest pin should be repo-local and machine-readable, recording at minimum upstream repository, pinned commit, observed version/probe evidence, install source or command, and update procedure.
- **D-14-08:** The ADR should explain that git submodule is intentionally not selected for v1.2 because this repository is an adapter layer and does not need to vendor or checkout upstream core source as part of normal development.

### ADR Location and Validation

- **D-14-09:** Write the ADR at `.planning/adr/ADR-001-upstream-pin.md`.
- **D-14-10:** Because submodule is not selected, the `.gitmodules` plus `hermes-agent` gitlink staging check from UPST-02 is not applicable. The ADR must state this explicitly.
- **D-14-11:** Required verification for planning should include: post-migration path reference search, existing smoke tests under the migrated script tree, shell syntax checks for migrated shell scripts, and `git status --short` review.

### the agent's Discretion

- Exact manifest file path and schema, as long as it is repo-local, machine-readable, and easy for Phase 16 `make upstream-status` to consume later.
- Exact ADR section structure and wording.
- Exact verification command list, as long as it covers path references, shell syntax, and existing smoke fixtures.
- Whether to add a short migration note in reader-facing docs after paths are updated.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and Roadmap
- `.planning/REQUIREMENTS.md` — Phase 14 requirements MIGR-02, UPST-01, and conditional UPST-02.
- `.planning/ROADMAP.md` — Phase 14 goal and success criteria.
- `.planning/PROJECT.md` — Upstream-first adapter boundary, current v1.2 state, and no standalone runtime constraint.
- `.planning/STATE.md` — Current project position.
- `.planning/SPEC.md` — Canonical planning specification and architecture constraints.

### Phase 13 Evidence
- `.planning/phases/13-evidence-audit-and-discoverability/13-CONTEXT.md` — Locked decisions from the evidence and discoverability phase.
- `.planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md` — Old-path inventory and repository snapshot that drives this migration.

### Upstream Baseline and Adapter Boundary
- `.planning/DIRECTION-CORRECTION.md` — Upstream-first correction requiring `NousResearch/hermes-agent`.
- `.planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md` — Locked decisions D1-D9, including upstream commit pin and local `orch-*` boundary.
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md` — Install/probe evidence and pinned upstream commit.
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-CONTEXT.md` — Installed adapter package layout and setup decisions.
- `.planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-CONTEXT.md` — Runtime/file-bus decisions that refer to the Dev Orchestra docs and scripts.
- `.planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md` — Risk, audit, and smoke fixture decisions that refer to the Dev Orchestra docs and scripts.

### Current Pre-Migration Source Paths
- `docs/hermes-dev-orchestra/README.md` — Product behavior baseline; to move to `docs/orchestra/README.md`.
- `docs/hermes-dev-orchestra/WORKFLOW.md` — Installation and usage guide; to move to `docs/orchestra/WORKFLOW.md`.
- `docs/hermes-dev-orchestra/hermes/SOUL.md` — Orchestra SOUL file; to move under `docs/orchestra/`.
- `docs/hermes-dev-orchestra/skills/` — Four orchestra skills; to move under `docs/orchestra/`.
- `docs/hermes-dev-orchestra/scripts/` — `orch-*` helpers and smoke tests; to move under `docs/orchestra/`.
- `docs/COVERAGE-MATRIX.md` — Contains current path and upstream pin references that must be updated.
- `README.md`, `AGENTS.md`, and `CLAUDE.md` — Root discoverability and agent instruction files that currently point at the old path.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md`: existing old-path inventory; use it as the migration checklist seed.
- `docs/hermes-dev-orchestra/scripts/tests/run-all.sh`: existing smoke runner; after migration, it should run from `docs/orchestra/scripts/tests/run-all.sh`.
- `docs/hermes-dev-orchestra/scripts/bin/orch-verify`: existing public verification command; update internal paths if needed.
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md`: existing upstream install/probe evidence and pinned commit.

### Established Patterns
- This repository is an adapter layer over upstream Hermes Agent; local commands remain `orch-*`.
- Shell helpers and tests currently compute `REPO_ROOT` and reference paths under `docs/hermes-dev-orchestra/`; these need path updates after migration.
- Planning artifacts live under `.planning/`; ADR placement under `.planning/adr/` is consistent with the spec-first boundary.

### Integration Points
- Physical move: `docs/hermes-dev-orchestra/` -> `docs/orchestra/`.
- Root reader links: `README.md`, `AGENTS.md`, and `CLAUDE.md`.
- Verification scripts and smoke tests under the migrated `docs/orchestra/scripts/` tree.
- Upstream pin manifest path chosen during implementation must be readable by future Phase 16 developer workflow tooling.

</code_context>

<specifics>
## Specific Ideas

- Suggested ADR sections: Context, Decision, Options Considered, Comparison Table, Consequences, Verification.
- Suggested manifest fields: `upstream_repo`, `pinned_commit`, `observed_version`, `install_method`, `probe_date`, `probe_commands`, `runtime_path`, and `update_procedure`.
- The manifest pin should point to commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3` unless implementation discovers a deliberate update is needed and records that deviation.
- The migration should prefer direct reference updates over compatibility aliases. Old-path compatibility is not part of the desired result.

</specifics>

<deferred>
## Deferred Ideas

- Creating a `specs/` derived documentation system — Phase 15.
- Creating `make upstream-status` to compare repo-local and runtime pins — Phase 16.
- Broad `AGENTS.md` rule consolidation beyond path references — Phase 17.
- Actual git submodule adoption — deferred unless a future phase explicitly reverses the manifest pin decision.

</deferred>

---

*Phase: 14-migration-submodule-adr*
*Context gathered: 2026-04-28*
*Decisions locked: D-14-01 through D-14-11*
