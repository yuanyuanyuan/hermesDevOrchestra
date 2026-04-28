# Phase 13: Evidence Audit & Discoverability - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase generates a comprehensive repository state snapshot and path reference inventory, creates an explicit root-directory index pointing to the `docs/hermes-dev-orchestra/` enhancement layer, and appends Dev Orchestra directory navigation to `AGENTS.md` without overwriting existing GSD managed blocks.

**In scope:**
- Root directory index file (`README.md`) with project intro, status, and navigation links
- `AGENTS.md` append-only update with Dev Orchestra Package Boundary, Agent Role Boundary, and directory navigation
- Path reference inventory: all `docs/hermes-dev-orchestra/` references found via `rg`
- Repository state snapshot: branch, commit, git status, untracked files with attribution

**Out of scope:**
- Actual path migration or fixing references (Phase 14)
- Upstream pin ADR (Phase 14)
- Specification system (Phase 15)

</domain>

<decisions>
## Implementation Decisions

### 根目录索引形式 (D-13-01 ~ D-13-03)

- **D-13-01:** Create `README.md` in the repository root as the explicit index. It is a lightweight landing page, NOT a replacement for `docs/hermes-dev-orchestra/README.md`.
- **D-13-02:** `README.md` content includes: (1) brief project intro (1-2 sentences), (2) current status banner ("v1.2 migration in progress"), (3) navigation links to enhancement layer docs (`docs/hermes-dev-orchestra/README.md`, `docs/hermes-dev-orchestra/WORKFLOW.md`, `AGENTS.md`).
- **D-13-03:** `README.md` does NOT include detailed quick-start commands. Command documentation remains the responsibility of enhancement layer docs to avoid duplication and maintenance burden.

### AGENTS.md 追加策略 (D-13-04 ~ D-13-06)

- **D-13-04:** Append at the **end of `AGENTS.md`**, after all existing GSD managed blocks. Use explicit delimiter comments: `<!-- hermes-dev-orchestra-start -->` and `<!-- hermes-dev-orchestra-end -->` to clearly separate project-specific content from GSD-managed content.
- **D-13-05:** Section title: `## Hermes Dev Orchestra`. Contains three subsections:
  - **Package Boundary**: adapter layer role (not standalone runtime), local entrypoints limited to `orch-*`, spec authority at `docs/hermes-dev-orchestra/`
  - **Agent Role Boundary**: Dev Orchestra-specific constraints that complement (not repeat) the existing Architecture section. Examples: Hermes must not bypass `orch-risk-check` L3/L4 blocking; Claude must not modify upstream Hermes Agent core code; Codex must not modify `~/.hermes-orchestra/rules.json`
  - **Directory Navigation**: direct links to `docs/hermes-dev-orchestra/`, `.planning/SPEC.md`, `.planning/STATE.md`
- **D-13-06:** Synchronously update `CLAUDE.md` (root directory) to reference the new Dev Orchestra section in `AGENTS.md` and `.planning/SPEC.md` as canonical authorities (AGNT-02).

### 路径引用清单与仓库快照 (D-13-07 ~ D-13-09)

- **D-13-07:** Path reference inventory and repository state snapshot are merged into a single file: `.planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md`.
- **D-13-08:** Format is structured Markdown with two main sections:
  - **Repository Snapshot**: branch name, latest commit SHA, `git status --short --branch` output, untracked file list with attribution notes, last 5 commits
  - **Path Reference Inventory**: Markdown table with columns: File | Line | Referenced Path | Context | Category (by path type: scripts-bin, scripts-lib, skills, docs)
- **D-13-09:** Inventory covers all matches from `rg -n "docs/hermes-dev-orchestra"` across the repository. Category by path type (not by usage purpose) to support bulk migration decisions in Phase 14.

### Claude's Discretion

- Exact wording and length of `README.md` project intro
- Specific examples used in Agent Role Boundary constraints (D-13-05)
- Whether to include additional navigation links beyond the three mandated ones
- Exact number of recent commits shown in the snapshot (5 is a guideline)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — v1.2 requirement list (DISC-01, DISC-02, MIGR-01)
- `.planning/ROADMAP.md` — Phase 13 goals, success criteria, execution order
- `.planning/PROJECT.md` — Vision, constraints, key decisions, current state
- `.planning/STATE.md` — Current progress and locked decisions

### Existing Documentation
- `docs/hermes-dev-orchestra/README.md` — Product behavior baseline (the enhancement layer that needs discoverability)
- `docs/hermes-dev-orchestra/WORKFLOW.md` — Installation and usage guide
- `AGENTS.md` — Existing agent rules (to be appended, not overwritten)
- `CLAUDE.md` — Existing project instructions (to be updated with cross-references)

### Prior Phase Context
- `.planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md` — D-09: local entrypoints are `orch-*` only
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-CONTEXT.md` — Directory structure decisions
- `.planning/phases/12-risk-decisions-verification-handoff/12-CONTEXT.md` — `orch-risk-check`, `orch-audit`, rules.json location

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/hermes-dev-orchestra/README.md` — Already exists as the canonical product doc; root README.md only needs to point to it
- `AGENTS.md` — Has clear GSD managed block structure (`<!-- GSD:xxx-start/end -->`); append-only strategy is safe
- `CLAUDE.md` — Root-level instructions exist; needs pointer update, not rewrite

### Established Patterns
- GSD managed blocks use HTML comment delimiters (`<!-- GSD:xxx-start/end -->`) — follow this pattern for the new Dev Orchestra section
- Phase context files live in `.planning/phases/{padded_phase}-{slug}/` — follow established convention

### Integration Points
- Root `README.md` is a new file; no conflicts with existing files
- `AGENTS.md` append happens at end-of-file; zero risk of collision with managed blocks
- `13-EVIDENCE.md` is a new artifact; no integration with existing runtime code

</code_context>

<specifics>
## Specific Ideas

1. **README.md status banner format**: Use a blockquote or callout style, e.g.:
   ```markdown
   > **Status:** v1.2 migration in progress (2026-04-28)
   >
   > This repository is transitioning from v1.1 upstream integration to v1.2 normalization.
   > See `.planning/ROADMAP.md` for current phase tracking.
   ```

2. **AGENTS.md delimiter naming**: Use `hermes-dev-orchestra` as the delimiter name to match the project identity while being distinct from GSD's `gsd-` prefix.

3. **Evidence file structure**: The merged `13-EVIDENCE.md` should have a clear heading structure:
   ```markdown
   # Phase 13 Evidence: Repository State & Path References

   ## Repository Snapshot
   ...

   ## Path Reference Inventory
   ...
   ```

4. **Snapshot attribution notes**: For each untracked file, include a brief note like:
   - `gsd_commands_reference.md` — project documentation (safe to commit or gitignore)

</specifics>

<deferred>
## Deferred Ideas

- Actual migration of `docs/hermes-dev-orchestra/` references — Phase 14 (MIGR-02)
- Upstream pin ADR and submodule decision — Phase 14 (UPST-01, UPST-02)
- Specification system with `specs/` directory — Phase 15 (SPEC-01, SPEC-02)
- Makefile and dev workflow — Phase 16 (DEV-01..DEV-04)

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 13-evidence-audit-and-discoverability*
*Context gathered: 2026-04-28*
*Decisions locked: D-13-01 through D-13-09*
