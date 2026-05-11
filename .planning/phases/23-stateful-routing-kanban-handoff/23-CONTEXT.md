# Phase 23: Stateful Routing & Kanban Handoff - Context

**Gathered:** 2026-05-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 23 defines the executable routing and handoff contract for the Hermes-native MVP after Phase 22 locked the external CLI protocol surface. This phase must replace the legacy file-bus routing model with Kanban-native task graph progression, state-aware routing, and block-resume handoff behavior across `pm`, `researcher`, `implementer`, `reviewer`, and `qa-tester`. It does not implement risk-policy enforcement, worker timeout/cleanup, structured handoff validation hardening, or observability persistence; those remain in later phases.

</domain>

<decisions>
## Implementation Decisions

### Routing State Model
- **D-23-01:** Routing remains anchored on Hermes-native `status + parents`; this phase may add only a small amount of metadata instead of inventing a second full task-state system.
- **D-23-02:** The minimum routing metadata set is exactly four fields: `workflow_state`, `routing_reason`, `resume_target`, and `handoff_ref`.
- **D-23-03:** Routing rules should prefer code-enforced behavior first, with docs acting as a human-readable mirror rather than the canonical execution source.

### Task Graph Creation
- **D-23-04:** PM should create a skeleton task graph first, then expand it incrementally as research, review, or QA outcomes clarify the next branches.
- **D-23-05:** Phase 23 should avoid one-shot full graph generation for uncertain flows; downstream tasks may be appended later with explicit `parents`.
- **D-23-06:** Research task creation must use an explicit trigger list, not PM freeform judgment.

### Block and Resume Contract
- **D-23-07:** Blocked work should resume the original task by default once the blocking condition is resolved.
- **D-23-08:** New child tasks should be created only when responsibility genuinely changes role, such as `pm -> researcher`, `implementer -> reviewer`, or implementation work that must continue into QA.
- **D-23-09:** `kanban_block` reasons must use lightweight structured prefixes such as `needs-user:`, `needs-review:`, and `research-required:` followed by human-readable detail.

### Handoff Shape
- **D-23-10:** Handoff data should use minimal structured summaries plus file references; large outputs stay in artifacts/files, not inline in metadata.
- **D-23-11:** `handoff_ref` should point to the canonical artifact or summary source needed by the next role, rather than duplicating full upstream output into task metadata.
- **D-23-12:** Human-readable `kanban_comment` records are audit summaries only; they must not become the recovery truth source.

### Review and QA Insertion
- **D-23-13:** Code implementation tasks must always pass through `reviewer`.
- **D-23-14:** QA is selectively mandatory rather than universal.
- **D-23-15:** A task must route into `qa-tester` when any of these apply: user-visible behavior changed, cross-module or cross-boundary integration is involved, or acceptance/regression risk is materially high.

### Research Trigger Contract
- **D-23-16:** A `researcher` task must be created whenever the work touches an unverified new stack/capability area in the project.
- **D-23-17:** A `researcher` task must be created when the problem contains real solution branching or tradeoffs that would change the downstream task graph.
- **D-23-18:** A `researcher` task must be created when the requirement explicitly asks for research, comparison, proposal, or feasibility judgment.

### Audit Density
- **D-23-19:** `kanban_comment` should be written only at key inflection points: initial graph creation, entering blocked, leaving blocked, role handoff, and final delivery completion.

### the agent's Discretion
- Research and planning may choose the exact `workflow_state` enum values, as long as they remain a thin routing layer over Hermes-native status rather than a duplicated full task-state machine.
- Research and planning may define the exact allowed `resume_target` values and the normalized prefix vocabulary for `routing_reason`, provided they preserve the lightweight structured contract above.
- Research and planning may decide the concrete code location for routing rules (script/module/config structure), as long as execution truth stays code-first and documentation remains a mirror.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 23 scope and milestone authority
- `.planning/ROADMAP.md` — Phase 23 goal, dependencies, success criteria, and the v1.3 execution order.
- `.planning/REQUIREMENTS.md` — `ENG-03`, `ROUTE-01`, and `ROUTE-02` define the milestone-facing contract this phase must satisfy.
- `.planning/PROJECT.md` — current milestone framing, MVP boundary, and the rule that same-project parallelism remains out of scope.
- `.planning/STATE.md` — current project position and the expected handoff after Phase 22 closeout.

### Phase 19 design source for routing and handoff
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` — canonical architecture baseline for Kanban states, parents, block/resume, and handoff behavior.
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` — `R32` through `R38` plus the routing-related requirements and flow narratives that Phase 23 narrows into MVP execution rules.
- `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` — authoritative description of metadata-backed context accumulation, `next_action`, and the rejection of CLI session resume.
- `.planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md` — invariant checklist for Hermes-hosted scheduling, metadata truth, and stateless external CLI execution.
- `.planning/phases/19-hermes-workflow-design/workflow-phase-02-orchestrator.md` — concrete PM task decomposition and parent-chain examples that planning should adapt into the Phase 23 runtime contract.
- `.planning/phases/19-hermes-workflow-design/ascii-kanban-subflows.md` — dependency-chain and dispatcher flow reference for Kanban-native progression.
- `.planning/phases/19-hermes-workflow-design/ascii-end-to-end.md` — end-to-end routing examples covering PM, implementer, reviewer, and QA flow transitions.
- `.planning/phases/19-hermes-workflow-design/workflow-appendix-decisions.md` — rationale for replacing session resume with metadata-backed orchestration.
- `.planning/phases/19-hermes-workflow-design/workflow-appendix-failure-modes.md` — failure examples showing when block/resume must preserve authority and routing correctness.

### Prior phase constraints that Phase 23 must reuse
- `.planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md` — locked Phase 22 decisions on canonical context state, audit semantics, and protocol boundaries.
- `.planning/phases/22-external-cli-engine-protocol-role-invocation/22-VERIFICATION.md` — proof that the first protocol loop for `pm`, `implementer`, and `reviewer` is closed before routing expands.
- `.planning/phases/21-profiles-overrides-board-isolation/21-CONTEXT.md` — project slug, workspace root, and isolation decisions that routing and handoff must preserve.
- `.planning/phases/20-capability-verification-boundary-lock/20-CONTEXT.md` — official-vs-local boundary authority that keeps this phase inside the verified Hermes surface.

### Existing repository surfaces and tests
- `docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md` — shared `next_action` contract the routing layer must consume.
- `docs/orchestra/hermes/role-engine-protocol/v1/roles/pm.md` — PM response states that trigger question loops, research tasks, and task creation.
- `docs/orchestra/hermes/role-engine-protocol/v1/roles/implementer.md` — implementer response states that map to completion, user decision waits, and blocks.
- `docs/orchestra/hermes/role-engine-protocol/v1/roles/reviewer.md` — reviewer response states that map to completion, findings, and rejection/block behavior.
- `docs/orchestra/scripts/tests/test-role-engine-protocol.sh` — executable proof of the shared `next_action` contract that Phase 23 routing must consume consistently.
- `docs/orchestra/scripts/tests/test-risk-decisions.sh` — legacy decision-resume behavior worth using as a migration reference for unblock/resume expectations, not as the future architecture truth.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/orchestra/hermes/role-engine-protocol/v1/roles/{pm,implementer,reviewer}.md`: already define the role-specific engine outcomes that routing must interpret.
- `docs/orchestra/scripts/tests/test-role-engine-protocol.sh`: gives a concrete executable surface for validating that routing still respects the shared `next_action` model.
- `.planning/phases/19-hermes-workflow-design/workflow-phase-02-orchestrator.md`: already shows realistic task graph and parent-link examples that can be narrowed into the MVP routing contract.

### Established Patterns
- Hermes-native `status + parents` remains the primary execution truth; metadata is additive, not a replacement task engine.
- Comments are human-audit artifacts only; Phase 22 already locked metadata as the canonical continuity mechanism.
- Phase 21 already fixed project-scoped isolation under `.hermes/projects/{project_slug}/`; routing must not reintroduce cross-project identity drift.
- Same-project parallelism is still out of scope, so routing can assume one active implementation lane per project at this milestone.

### Integration Points
- PM task outputs must translate into Kanban graph creation that Orchestrator can later dispatch without CLI session continuity.
- Implementer/reviewer/QA transitions must consume the existing `hermes-role-engine/v1` outputs and map them into Kanban-native progression.
- `routing_reason`, `resume_target`, and `handoff_ref` will form the minimal bridge between task metadata, unblock logic, and downstream task creation.

</code_context>

<specifics>
## Specific Ideas

- Keep the routing layer visibly small: the product direction favors explicit, lightweight orchestration over a heavyweight second workflow engine.
- Use code as the authoritative routing table, with docs mirroring the behavior for humans and future audits.
- Prefer stable, parseable block prefixes with human-readable tails so unblock logic stays deterministic without losing operator readability.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 23-stateful-routing-kanban-handoff*
*Context gathered: 2026-05-11*
