# Phase 21: Profiles, Overrides & Board Isolation - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 21 only defines the executable packaging and repository-facing contract for workflow profiles, project-level profile overrides, board/workspace/profile/memory isolation, and the base naming rules that prevent cross-project bleed. It does not implement Kanban routing logic, risk policy enforcement, worker lifecycle control, or observability collection.

</domain>

<decisions>
## Implementation Decisions

### Override Merge Semantics
- **D-21-01:** `model` uses direct project-level override. If a project override specifies a model, it replaces the global profile model for that project.
- **D-21-02:** `toolsets` keep the dual-set shape `enabled` / `disabled`. Runtime merge uses combined sets, with project-level override taking precedence wherever a conflict exists.
- **D-21-03:** `SOUL.md` uses `extends: global`. Assembly order is fixed as: global rules → project rules → role rules.

### Multi-Project Isolation Naming
- **D-21-04:** Each project has exactly one canonical `project_slug`. All isolation surfaces derive from that slug instead of inventing separate identifiers.
- **D-21-05:** Board slug is exactly `{project_slug}`.
- **D-21-06:** Workspace root is `.hermes/projects/{project_slug}/`.
- **D-21-07:** Project-level profile override directory is `{repo}/.hermes/profiles/`.
- **D-21-08:** Memory namespace is `project:{project_slug}`.
- **D-21-09:** Any task/log/run prefix introduced in this phase should also derive from the same `project_slug`.

### Memory Promotion Boundary
- **D-21-10:** All learnings default to the project namespace `project:{project_slug}`.
- **D-21-11:** Only `orchestrator` or the user with an explicit `cross-project` mark may promote a learning into the global namespace.
- **D-21-12:** Curator may suggest promotion or generate a review task, but may not silently auto-promote a project learning into the global namespace.
- **D-21-13:** Query precedence is project namespace first, then global namespace.
- **D-21-14:** If project and global entries are thematically similar but conflict in content, the read path must surface an explicit `conflict_warning`; it may not silently prefer one and hide the conflict.

### the agent's Discretion
- Research and planning may choose the exact on-disk file layout and schema fields needed to implement D-21-01 through D-21-14, as long as they preserve the locked merge semantics, naming contract, and memory promotion boundary above.
- Research and planning may decide whether Phase 21 should materialize profile artifacts as repo templates, installer-generated outputs, or a hybrid path, because the user did not lock the delivery mechanism in this discussion.
- Research and planning may decide whether role naming normalization (`reviewer` vs `tech-reviewer`, reserved-role final names) needs an explicit Phase 21 decision or can stay aligned to the existing design package unchanged.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 21 scope and traceability
- `.planning/ROADMAP.md` — Phase 21 goal, success criteria, dependencies, and its position after the Phase 20 boundary lock.
- `.planning/REQUIREMENTS.md` — `PROF-01`, `PROF-02`, `FLOW-02`, and `MEM-01` define the milestone-facing contract this phase must satisfy.
- `.planning/STATE.md` — Current execution position after Phase 20 and the remaining external blocker note.
- `.planning/PROJECT.md` — Current milestone framing, isolation constraints, and the v1.3 active scope.

### Phase 19 design source for profiles and isolation
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` §3.2–3.7 — profile catalog, toolsets examples, override registry, and reserved-role placeholders.
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` — `R3`, `R7`, `R7b`–`R7e`, `R10`, and `R11` establish the intended override, namespace, and tool boundary semantics.
- `.planning/phases/19-hermes-workflow-design/WORKFLOW-EXPLAINED.md` — narrative source for how these roles are expected to cooperate once packaged.
- `.planning/phases/19-hermes-workflow-design/WORKFLOW-ASCII-DIAGRAMS.md` — reference map from profile/isolation requirements to the workflow package.

### Phase 20 boundary authority
- `.planning/phases/20-capability-verification-boundary-lock/20-CAPABILITY-MATRIX.md` — authoritative distinction between official Hermes coverage and local workflow semantics, especially for memory, curator, gateway, and `skill_manage`.
- `.planning/phases/20-capability-verification-boundary-lock/20-CONTEXT.md` — matrix-first writeback rule and backlog policy established before this phase.
- `.planning/phases/20-capability-verification-boundary-lock/20-VERIFICATION.md` — confirms what Phase 20 settled and the external upstream-pin blocker still visible in the repo gate.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` already contains the intended 8 active + 3 reserved profile inventory, toolsets sketches, and override examples. Phase 21 should refine that into an executable contract instead of inventing a second model.
- `docs/orchestra/hermes/SOUL.md` is the current upstream-installed orchestra SOUL surface; it provides a concrete base for thinking about how global/project/role rule layering might assemble.
- Phase 20 matrix rows for `profile`, `memory`, `session_search`, `toolsets`, and `skill_manage` provide the latest authoritative boundary on what Hermes officially exposes versus what remains local orchestration logic.

### Established Patterns
- This repository prefers matrix-first or evidence-first clarification before large downstream writeback, as seen in Phase 18 and Phase 20.
- v1.3 milestone phases are intentionally narrow: Phase 21 should only define packaging/override/isolation behavior, leaving routing, guards, and observability to later phases.
- Single-developer, multi-project isolation is a hard product boundary. Same-project parallel execution is already excluded by earlier architecture bounds.

### Integration Points
- Phase 21 outputs will feed directly into Phase 22 routing because assignee names, board names, and workspace conventions must be stable before task graph generation.
- Phase 21 decisions about memory namespace and promotion boundaries must remain compatible with v1.4 future requirements for curator clustering and conflict warnings.
- Any on-disk profile or override contract chosen here must not contradict the official/local split established in the Phase 20 matrix.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly wants a “single primary key” isolation rule: one `project_slug` should derive board, workspace, override, and memory identities.
- The user accepted a layered rule assembly for `SOUL.md` rather than a full replace model.
- The user accepted that curator can recommend or queue promotion but may not silently promote across projects.

</specifics>

<deferred>
## Deferred Ideas

- Profile delivery shape was not locked here: whether active/reserved profiles should live as repo templates, installer-generated outputs, or another packaging form remains open for research/planning.
- Final role naming normalization (`reviewer` vs `tech-reviewer`, and whether reserved names stay exactly as in the design package) was not locked here.

</deferred>

---
*Phase: 21-profiles-overrides-board-isolation*
*Context gathered: 2026-05-10*
