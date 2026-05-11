# Phase 22: External CLI Engine Protocol & Role Invocation - Context

**Gathered:** 2026-05-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 22 defines the executable contract for invoking external CLI engines from Hermes workflow profiles. It locks where engine configuration lives, how project overrides change it, what the first `hermes-role-engine/v1` protocol surface must cover, what canonical context state Hermes retains between stateless CLI calls, and how engine failures normalize into retry, fallback, and block behavior. It does not implement state-machine routing, risk policy enforcement, observability storage, or the full seven-role rollout beyond the initial protocol closure set.

</domain>

<decisions>
## Implementation Decisions

### Engine Configuration Ownership
- **D-22-01:** Project overrides may override all `engine` fields: `cli`, `mode`, `flags`, and `fallback`. Base profile definitions only provide defaults.
- **D-22-02:** Canonical engine defaults live directly in each role's checked-in `config.yaml`; there will be no centralized engine matrix file.
- **D-22-03:** `orch-profile-sync` must merge `engine` with field-level deep-merge semantics. A project override may replace only one field such as `flags` without redefining the full object.
- **D-22-04:** `fallback` is opt-in only. It is active only when the profile explicitly declares it.

### Protocol Surface for v1
- **D-22-05:** Phase 22 only has to fully close the protocol loop for `pm`, `implementer`, and `reviewer`. Other workflow roles must align to the same protocol model later, but they are not required to be fully landed in this phase.
- **D-22-06:** The repository must contain a common protocol envelope plus role-specific schema/example contracts for `pm`, `implementer`, and `reviewer`.
- **D-22-07:** `next_action` uses one small shared cross-role enum. Role-specific meaning belongs in role payloads, not in custom `next_action` values.
- **D-22-08:** `status` is role-specific. Each role defines its own `status` enum, while the docs keep a cross-role comparison table for orchestrator and adapter authors.
- **D-22-09:** `correlation_id` is a tracing field only. It does not carry session resume semantics or authority semantics.

### Canonical Context State
- **D-22-10:** Canonical per-task context retained in Kanban metadata is limited to the minimum runtime set: `conversation_history`, `handoff_from_parent`, `task_summary` / `current_stage`, `last_engine_error`, and `rollback_count`.
- **D-22-11:** `conversation_history` must be stored as structured turn data, not as a raw transcript blob. Each turn keeps `role`, `content`, `turn`, and decision tags.
- **D-22-12:** Task comments are for human audit summaries only. They are not a recovery truth source and may not be used as a fallback for missing metadata state.
- **D-22-13:** `handoff_from_parent` may contain structured summaries plus references/paths to richer artifacts, but may not inline large raw upstream outputs as canonical state.
- **D-22-14:** When history grows, compaction must use a two-layer form: summarized earlier context plus the most recent N raw turns. Phase 22 must not use silent oldest-first truncation.

### Failure and Fallback Normalization
- **D-22-15:** The default recovery ladder is fixed: retry once, then block. Fallback execution is only considered when the profile explicitly declares `fallback`.
- **D-22-16:** Any fallback activation must be recorded as an explicit audit event in task metadata/comments, including original engine, trigger reason, and fallback engine.
- **D-22-17:** `JSON parse-error` and protocol/schema mismatch are hard-stop failures. They must `kanban_block` immediately and may not auto-fallback.
- **D-22-18:** Timeout handling uses one shared recovery model across roles, but default timeout thresholds may differ by role.
- **D-22-19:** A successful fallback only applies to that single invocation. The next invocation still starts with the primary engine unless the checked-in profile config changes later.

### the agent's Discretion
- Research and planning may choose the exact file layout for the protocol artifacts (for example, Markdown contracts plus JSON examples, or Markdown plus machine-readable fixtures), as long as the repo clearly ships one common envelope contract and separate role contracts for `pm`, `implementer`, and `reviewer`.
- Research and planning may decide the exact metadata key names for audit/fallback events and summary compaction bookkeeping, as long as they preserve the locked semantics above.
- Research and planning may propose exact default timeout values per role and the exact "recent N turns" compaction threshold, because the user locked the shape of the policy but not the numeric defaults.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 22 scope and milestone authority
- `.planning/ROADMAP.md` — Phase 22 goal, dependencies, success criteria, and the revised v1.3 execution order.
- `.planning/REQUIREMENTS.md` — `ENG-01`, `ENG-02`, and `ENG-03` define the milestone-facing contract this phase must satisfy.
- `.planning/PROJECT.md` — current milestone framing and the 2026-05-11 replan that moved v1.3 onto the external CLI engine baseline.
- `.planning/STATE.md` — current project position, inherited blocker note, and the expected next step after context capture.

### Phase 19 protocol and architecture source
- `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` — canonical source for role-to-engine mapping, request/response envelope shape, and recovery narratives.
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` — `R31` through `R38` define the intended external CLI engine requirements for config, protocol, context accumulation, recovery, and orchestrator behavior.
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` — architecture baseline, especially the external CLI execution model, metadata-backed recovery, and profile responsibilities.
- `.planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md` — invariant checklist for the new baseline: Hermes as host, CLI as stateless executor, metadata as truth source, and `hermes-role-engine/v1` as the only protocol.
- `.planning/phases/19-hermes-workflow-design/workflow-appendix-decisions.md` — rationale for adopting the "Hermes scheduling + external CLI execution" model and for keeping authority in Hermes Profiles instead of the CLI layer.

### Phase 21 packaging and merge surface
- `.planning/phases/21-profiles-overrides-board-isolation/21-CONTEXT.md` — locked Phase 21 decisions on merge semantics, project-scoped runtime layout, and naming/isolation constraints that Phase 22 must reuse.
- `.planning/phases/21-profiles-overrides-board-isolation/21-VERIFICATION.md` — proof that the project-scoped profile assembly path is already working and should be extended rather than replaced.
- `docs/orchestra/hermes/profile-distribution/distribution.yaml` — canonical active profile inventory and reviewer naming authority.
- `docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml` — existing checked-in PM config surface where default engine fields now belong.
- `docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml` — existing checked-in Implementer config surface where default engine fields now belong.
- `docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml` — existing checked-in Reviewer config surface where default engine fields now belong.
- `docs/orchestra/scripts/bin/orch-profile-sync` — current profile assembly helper that must absorb the locked `engine` deep-merge behavior.

### Existing invocation evidence and legacy adapter surface
- `docs/orchestra/poc-headless-gsd-execution.md` — observed behavior of `claude -p` and `codex exec` in headless/automated execution, useful for planning timeout and fallback rules.
- `docs/orchestra/scripts/bin/orch-bus-loop` — historical adapter showing how this repo currently shells out to `codex exec` and `claude -p`; useful as a migration reference, not as the future architecture truth.
- `docs/orchestra/README.md` — current documented runtime wrapper behavior and project-scoped profile sync path that future implementation must stay compatible with until replaced intentionally.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/orchestra/hermes/profile-distribution/profiles/*/config.yaml`: checked-in per-role config files already exist and provide the natural place to add default `engine` settings.
- `docs/orchestra/scripts/bin/orch-profile-sync`: the repo already has one assembly helper for merging canonical base profiles with project overrides; Phase 22 should extend this helper instead of inventing a parallel config compiler.
- `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md`: the design package already contains concrete request/response examples and role mappings that can be converted into executable protocol artifacts.
- `docs/orchestra/poc-headless-gsd-execution.md`: the repo already captured practical CLI invocation evidence for `claude -p` and `codex exec`, including headless and sandbox behaviors.

### Established Patterns
- Phase 21 locked project-scoped runtime output under `.hermes/projects/{project_slug}/`; Phase 22 must keep using that path as the assembled runtime source.
- The runtime canonical reviewer slug is already `reviewer`; Phase 22 must not reintroduce `tech-reviewer` drift into protocol examples or config paths.
- The Phase 19 architecture baseline explicitly rejects using CLI session resume as the workflow truth source; metadata and structured handoff are the continuity mechanism.
- This project already treats comments as audit-facing artifacts and keeps actual execution truth in structured state or generated files; Phase 22 should preserve that split.

### Integration Points
- Profile assembly: default `engine` settings and project overrides connect directly to `docs/orchestra/hermes/profile-distribution/` plus `docs/orchestra/scripts/bin/orch-profile-sync`.
- Invocation adapter: the future Hermes wrapper/adapter layer will need a stable contract for launching `claude -p` / `codex exec` and parsing their JSON outputs.
- Kanban task state: Phase 22 decisions define what metadata Phase 23 routing and later lifecycle logic may rely on.
- Review pipeline: the first closed protocol loop includes `pm`, `implementer`, and `reviewer`, so role payload design must support downstream routing without reopening these decisions in Phase 23.

</code_context>

<specifics>
## Specific Ideas

- The user consistently chose explicit over implicit behavior: no hidden fallback defaults, no hidden centralized engine matrix, no silent long-history truncation.
- The user wants project-level engine switching to stay first-class, so one project can override an `implementer` or `devops` engine without rewriting the canonical base catalog.
- The user wants protocol errors (`parse-error`, `schema mismatch`) to surface as workflow-visible blocks instead of being silently absorbed by engine switching.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 22-external-cli-engine-protocol-role-invocation*
*Context gathered: 2026-05-11*
