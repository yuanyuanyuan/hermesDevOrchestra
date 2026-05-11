# Phase 24: Risk Policy & Role Guardrails - Context

**Gathered:** 2026-05-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 24 defines the executable risk-policy and role-guardrail layer for the Hermes-native MVP. It must land a declarative policy path for `L1/L2/L3/L4` command interception, enforce Reviewer/Orchestrator role boundaries through allowlists plus hook-level guardrails, and formalize the Implementer block contract that Phase 23 routing will consume. It does not implement worker timeout cleanup, structured handoff hardening, environment snapshots, backpressure control, or observability persistence; those remain in Phase 25.

</domain>

<decisions>
## Implementation Decisions

### Risk Level Model
- **D-24-01:** Phase 24 keeps four runtime risk levels: `L1`, `L2`, `L3`, and `L4`.
- **D-24-02:** `L1` means record-level only: log and optionally notify, but do not require a task-flow change.
- **D-24-03:** `L2` means intervention-level: supervisor/orchestrator must explicitly intervene, but the event does not automatically escalate to user approval.
- **D-24-04:** `L3` means blocked high-risk work: the task must stop and wait for one explicit approval before continuing.
- **D-24-05:** `L4` is stricter than `L3`: it is reserved for “accident-button” operations and must require stronger confirmation than a normal `L3` approval.

### L4 Scope and Approval Semantics
- **D-24-06:** `L4` is intentionally narrow. It only applies to accident-button classes such as destructive database wipes, destructive production resource deletion, force-push/history rewrite on critical branches, and broad irreversible deletes like `rm -rf`.
- **D-24-07:** Other high-risk but non-accident-button operations stay in `L3`, not `L4`.
- **D-24-08:** `L4` approval must use a fixed confirmation phrase tied to `approval_id`, rather than a freeform approval reply.
- **D-24-09:** `L4` approval must require stronger confirmation than `L3`, such as a second confirmation step or an explicit fixed approval phrase that can be audited and test-validated.

### L2 Intervention Contract
- **D-24-10:** `L2` may change the task flow without escalating to the user by default.
- **D-24-11:** Allowed `L2` interventions include pausing further spread, inserting review/clarification/follow-up tasks, and requiring more evidence, explanation, or review before continuation.
- **D-24-12:** `L2` must never be used to silently downgrade work that truly belongs in `L3` or `L4`.

### Role Guardrail Enforcement
- **D-24-13:** Reviewer and Orchestrator guardrails use three layers with explicit priority: primary enforcement through profile toolsets and CLI `--allowedTools`, secondary enforcement through Hermes `pre_tool_call` hook interception, and outer reminder constraints through SOUL/skills wording.
- **D-24-14:** Prompt-level or SOUL-only guardrails are not sufficient; Phase 24 must treat them as reminder layers, not the main boundary.
- **D-24-15:** Reviewer and Orchestrator should share one policy source, but policy rules branch by role so common rules stay centralized while role-specific exceptions remain explicit.

### Implementer Block Contract
- **D-24-16:** The mandatory Implementer block trigger list is fixed to four categories in this phase: architecture decisions, external dependency unavailable, risk-policy interception, and critical test failure.
- **D-24-17:** Implementer may not self-downgrade or route around one of those four triggers by improvising a lower-risk alternative path.
- **D-24-18:** When one of the mandatory triggers fires, Implementer must emit a structured `kanban_block` rather than continuing with a partial or guessed solution.

### Policy File Structure
- **D-24-19:** Phase 24 uses a single policy file rather than splitting policy into multiple role-specific files.
- **D-24-20:** That single policy file should be organized as shared/common rules plus role branches, with each relevant section segmented by `L1/L2/L3/L4` semantics.

### the agent's Discretion
- Research and planning may decide the exact YAML field names and on-disk location of the policy file, as long as it remains one canonical policy surface with explicit role branches.
- Research and planning may decide the exact fixed `L4` confirmation phrase format, provided it is deterministic, tied to `approval_id`, and stronger than normal `L3` approval.
- Research and planning may decide the exact `kanban_block` payload schema or metadata field names for Implementer block reasons, provided the four mandatory trigger categories remain enforceable and auditable.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 24 scope and milestone authority
- `.planning/ROADMAP.md` — Phase 24 goal, dependencies, success criteria, and v1.3 execution order.
- `.planning/REQUIREMENTS.md` — `SAFE-01`, `SAFE-02`, and `SAFE-03` define the milestone-facing contract for this phase.
- `.planning/PROJECT.md` — current milestone framing, MVP scope, and the external-CLI baseline this phase must preserve.
- `.planning/STATE.md` — current project position after Phase 23 closeout.

### Phase 19 design source for risk and role boundaries
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` — `R6`, `R8`, `R9`, `R10`, `R14`, and `R37` define the risk-policy, reviewer read-only, implementer block, and CLI allowlist design targets.
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` — canonical architecture baseline for declarative risk policy and layered interception.
- `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` — authoritative description of plugin-hook interception points and role-specific CLI/tool boundaries.
- `.planning/phases/19-hermes-workflow-design/ascii-decision-matrix.md` — phase design narrative for graded risk handling and escalation behavior.
- `.planning/phases/19-hermes-workflow-design/ascii-core-flows.md` — core blocked-flow examples for risk interception and approval routing.
- `.planning/phases/19-hermes-workflow-design/workflow-appendix-decisions.md` — rationale for technical reviewer hard gates and layered enforcement.
- `.planning/phases/19-hermes-workflow-design/workflow-appendix-failure-modes.md` — failure examples that motivate hard guardrails and mandatory block behavior.
- `.planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md` — invariant reminder that reviewer tool access and CLI allowlists must stay read-only.

### Prior phase constraints that Phase 24 must reuse
- `.planning/phases/23-stateful-routing-kanban-handoff/23-CONTEXT.md` — locked Phase 23 routing and block/resume decisions that this phase’s policy layer must plug into.
- `.planning/phases/23-stateful-routing-kanban-handoff/23-VERIFICATION.md` — proof that routing metadata, handoff flow, and child/follow-up task creation are already in place.
- `.planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md` — locked Phase 22 decisions on stateless engine execution and protocol boundaries.
- `.planning/phases/20-capability-verification-boundary-lock/20-CONTEXT.md` — official-vs-local boundary authority showing risk policy is a local extension implemented via verified hook surfaces.

### Existing repository surfaces and tests
- `docs/orchestra/scripts/bin/orch-risk-check` — current static risk checker that Phase 24 should evolve rather than replace blindly.
- `docs/orchestra/scripts/tests/test-risk-decisions.sh` — executable reference for current approval blocking and resume expectations.
- `docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml` — current reviewer toolset and CLI restriction baseline.
- `docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml` — current implementer execution baseline that Phase 24 block rules must constrain.
- `docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml` — current non-executor profile baseline useful for comparing role boundaries.
- `docs/orchestra/skills/claude-supervisor/SKILL.md` — existing L3/L4 escalation and supervisor behavior contract that Phase 24 must either preserve or explicitly supersede.
- `docs/orchestra/scripts/bin/orch-bus-loop` — current runtime loop that already enforces approval blocking and will need policy-layer integration.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/orchestra/scripts/bin/orch-risk-check`: already loads a JSON rules file and maps matched patterns to normalized risk levels, so it is a strong migration base for the Phase 24 policy engine.
- `docs/orchestra/scripts/tests/test-risk-decisions.sh`: already proves approval creation, no-auto-resume before approval, and stale under-classification protection; it is the best starting fixture for policy-layer regression coverage.
- `docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml`: already encodes a read-only reviewer default via toolsets and `--allowedTools Read,Glob,Grep`.
- `docs/orchestra/scripts/bin/orch-bus-loop`: already understands blocked approval flows and routing metadata from Phase 23, so policy enforcement can feed its existing state transitions rather than invent a second approval loop.

### Established Patterns
- Phase 23 already locked that same-role block/unblock resumes the original task, while cross-role transitions create explicit child or follow-up tasks.
- Earlier phases already treat high-risk decisions as approval-bound and auditable; Phase 24 should refine that into role-aware policy, not re-open the basic “must block” invariant.
- Project-scoped profile assembly is already in place from Phase 21, so role guardrails should attach to generated project-scoped configs rather than mutate global profile state.

### Integration Points
- Phase 24 policy decisions must feed the runtime approval path used by `orch-bus-loop` and `pending-decisions`.
- Reviewer/Orchestrator role restrictions must align profile configs, CLI flags, and hook-level interception rather than diverging across those layers.
- Implementer block rules must emit reasons that the Phase 23 routing layer can carry forward through `routing_reason`, `resume_target`, and handoff metadata.

</code_context>

<specifics>
## Specific Ideas

- Keep `L4` intentionally rare; if too many operations qualify, the distinction from `L3` loses value and policy writing becomes noisy.
- Treat the policy file as the executable source of truth and let docs mirror it, following the same code-first principle used in Phase 23.
- Prefer deterministic approval text for `L4`, because this project already relies on auditable file-based approval flows and test fixtures.

</specifics>

<deferred>
## Deferred Ideas

- The exact fixed confirmation phrase format for `L4` approvals remains open for planning, as long as it is deterministic and `approval_id`-bound.
- The exact YAML schema and whether policy data lives under `docs/orchestra/config/`, `docs/orchestra/hermes/`, or another runtime-facing path remains open for planning.

</deferred>

---
*Phase: 24-risk-policy-role-guardrails*
*Context gathered: 2026-05-11*
