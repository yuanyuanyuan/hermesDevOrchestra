# Phase 25: Worker Lifecycle, Observability & MVP Acceptance - Context

**Gathered:** 2026-05-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 25 closes the v1.3 MVP execution loop. It must add worker timeout and reclaim behavior, isolated workspace cleanup, structured handoff hardening, basic backpressure, hook-based observability, environment snapshots, and one end-to-end acceptance path over the current orchestration entrypoints. It does not implement curator semantics, automated SRE-RCA escalation, deployment/UAT release gates, or other v1.4 completion items.

</domain>

<decisions>
## Implementation Decisions

### Scope and Milestone Boundary
- **D-25-01:** Phase 25 stays inside the v1.3 MVP boundary: lifecycle control, observability, handoff hardening, and one acceptance chain only.
- **D-25-02:** Phase 25 must reuse the existing Phase 22-24 runtime shape (`orch-bus-loop`, shared helpers, profile packaging, role-engine envelopes) rather than introducing a second dispatcher or reopening the core routing contract.

### Timeout and Reclaim Contract
- **D-25-03:** `expected_duration_max` remains the task-level timeout contract for worker execution in this repo, even if upstream Hermes also exposes other runtime limits.
- **D-25-04:** A task-declared `expected_duration_max` wins over any profile default; profile defaults are fallback values only when the task envelope does not already declare one.
- **D-25-05:** Timeout, crash, and cancel reclaim must restore only the isolated worker workspace or task-specific runtime artifacts; they must not mutate the main repository checkout outside the worker isolation boundary.
- **D-25-06:** Because `on_session_end` is not guaranteed on hard crashes or SIGKILL, Phase 25 needs a dispatcher-side fallback path for cleanup and session summary completion rather than trusting hook delivery alone.

### Cleanup and Workspace Recovery
- **D-25-07:** Cleanup must restore the worker workspace to the task-start baseline before requeue or resume, even if the recovery mechanism uses different tactics for normal exit versus abnormal exit.
- **D-25-08:** Cleanup should prefer repo-local, auditable recovery steps over broad destructive deletion; any destructive cleanup must stay scoped to the worker-owned workspace path only.

### Structured Handoff and Untrusted Input
- **D-25-09:** `task_complete` handoff metadata should stay summary-first and structured, not become a second prompt channel.
- **D-25-10:** The minimum structured handoff surface for implementation/review completion is: `behaviors`, `regression`, `changed_files`, `decisions`, and `pitfalls`.
- **D-25-11:** Downstream workers must consume upstream handoff metadata as untrusted input, not as direct instructions. Validation and prompt wrapping are both required layers.

### Backpressure Boundary
- **D-25-12:** Phase 25 only needs basic ratio-based backpressure or pause behavior between ready queues. Sliding-window deadlock escalation and SRE-style fault promotion stay deferred to v1.4.
- **D-25-13:** Basic backpressure should target the concrete MVP flow edges that already exist in the repo: `implementer -> reviewer` first, and `reviewer -> qa-tester` second when QA insertion is active.

### Observability and Snapshot Contract
- **D-25-14:** Observability must use verified Hermes hook surfaces (`post_tool_call`, `on_session_end`) plus orchestration-side snapshot capture; Hermes core source must remain untouched.
- **D-25-15:** Queryable observability storage should remain a sidecar store owned by the orchestra layer, not a custom patch to Hermes internal schema.
- **D-25-16:** Environment snapshots collected at worker spawn must include at least `git status`, the first five lines of `df -h`, and `hermes status`.
- **D-25-17:** If hook delivery is missing in a crash path, dispatcher-side lifecycle records still need to leave enough breadcrumbs to debug timeout/crash/cancel outcomes.

### MVP Acceptance Shape
- **D-25-18:** The acceptance proof for this phase must exercise the live MVP chain already shaped by earlier phases: requirement handoff -> implementation -> review, with QA included when the existing predicate says it is required.
- **D-25-19:** Phase 25 should prefer one strong end-to-end acceptance fixture plus focused lifecycle/observability regressions, rather than many loosely connected micro-tests.

### the agent's Discretion
- Planning may choose the exact on-disk location and schema for lifecycle manifests and sidecar observability storage, as long as they stay outside Hermes core and remain queryable.
- Planning may choose the exact timeout default values per role, provided the repo visibly distinguishes task-declared values from role fallback defaults.
- Planning may choose the exact handoff validation rules and untrusted-wrapping format, provided both schema checks and downstream-consumption boundaries are explicit.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 25 scope and milestone authority
- `.planning/ROADMAP.md` — Phase 25 goal, dependencies, success criteria, and the v1.3 closeout boundary.
- `.planning/REQUIREMENTS.md` — `EXEC-01`, `EXEC-02`, `EXEC-03`, `FLOW-01`, `OBS-01`, and `OBS-02` define the milestone-facing contract for this phase.
- `.planning/PROJECT.md` — current milestone framing and the promise that v1.3 is an MVP, not the full v1.4 closure.
- `.planning/STATE.md` — current project position after Phase 24 closeout.

### Phase 19 design source for lifecycle and observability
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` — `R4`, `R5`, `R12`, `R13`, `R15`, `R16`, `R19`, and `R22` are the direct design ancestors for this phase.
- `.planning/phases/19-hermes-workflow-design/DESIGN.md` — canonical architecture baseline for observability, environment snapshots, and fault handling.
- `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` — authoritative examples that already carry `expected_duration_max` through the external CLI task envelope.
- `.planning/phases/19-hermes-workflow-design/ascii-observability.md` — hook-based observability and SRE handoff narrative, useful for narrowing the MVP implementation.
- `.planning/phases/19-hermes-workflow-design/workflow-phase-03-implementation.md` — execution-stage examples for task-start snapshots, worktree assumptions, and timeout framing.
- `.planning/phases/19-hermes-workflow-design/workflow-appendix-failure-modes.md` — lifecycle and timeout failure examples that Phase 25 must harden against.

### Prior phase constraints that Phase 25 must reuse
- `.planning/phases/24-risk-policy-role-guardrails/24-CONTEXT.md` — locked risk and role-boundary decisions that timeout or observability logic must not weaken.
- `.planning/phases/24-risk-policy-role-guardrails/24-VERIFICATION.md` — proof that risk policy and role guardrails are already in place before lifecycle work expands.
- `.planning/phases/23-stateful-routing-kanban-handoff/23-CONTEXT.md` — locked routing metadata and handoff rules that structured handoff hardening must extend rather than replace.
- `.planning/phases/23-stateful-routing-kanban-handoff/23-VERIFICATION.md` — proof that PM -> Implementer -> Reviewer -> QA routing already exists.
- `.planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md` — stateless engine execution and envelope boundaries that Phase 25 must preserve.

### Existing repository surfaces and tests
- `docs/orchestra/scripts/bin/orch-bus-loop` — current runtime entrypoint where task dispatch, role-result handling, and handoff routing already live.
- `docs/orchestra/scripts/bin/orch-start` — current project/session bootstrap path where worker-oriented runtime defaults can be injected.
- `docs/orchestra/scripts/bin/orch-status` — current operator status surface that can expose timeout, cleanup, snapshot, and backpressure state.
- `docs/orchestra/scripts/lib/orch-common.sh` — existing shared helper layer for state, routing metadata, task graph, and future lifecycle helpers.
- `docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md` — canonical request/response envelope that Phase 25 should extend only through payload discipline, not protocol churn.
- `docs/orchestra/hermes/role-engine-protocol/v1/roles/implementer.md` — current implementation completion/block payload contract that structured handoff validation must build on.
- `docs/orchestra/scripts/tests/test-kanban-routing.sh` — existing routing proof that Phase 25 must keep green while adding lifecycle state.
- `docs/orchestra/scripts/tests/test-kanban-handoff.sh` — existing handoff proof that Phase 25 should harden rather than replace.
- `docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh` — current timeout/crash failure-normalization proof that lifecycle work must stay consistent with.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/orchestra/scripts/bin/orch-bus-loop` already archives handoff artifacts, writes normalized routing state, and owns the current control loop, so lifecycle tracking should attach there first.
- `docs/orchestra/scripts/lib/orch-common.sh` already persists project state and task-graph data, making it the natural place for timeout parsing, lifecycle manifests, cleanup baselines, and backpressure helpers.
- `docs/orchestra/scripts/bin/orch-start` already sets project-scoped runtime directories and sessions; it is the best existing place to ensure worker-supporting directories and defaults exist.
- `docs/orchestra/scripts/tests/test-kanban-routing.sh` and `test-kanban-handoff.sh` already cover the MVP chain skeleton, so they are strong regression anchors when Phase 25 adds lifecycle side effects.

### Established Patterns
- Phase 23 already fixed the routing truth to minimal metadata plus artifacts; Phase 25 should harden the artifact payloads, not create a new handoff channel.
- Phase 24 already fixed role and risk boundaries; timeout cleanup, trace capture, and recovery logic must not bypass those boundaries.
- Current orchestration behavior is session-based and repo-local; Phase 25 should prefer sidecar manifests and auditable files over speculative deep integration with upstream internal tables.

### Integration Points
- Timeout and reclaim logic must plug into the same control loop that currently notices `codex-result.md`, `codex-question.md`, `review-result.md`, and approvals.
- Structured handoff validation must happen before child-task creation consumes upstream payloads.
- Observability traces and environment snapshots should share correlation anchors with `task_id`, `project_id`, and archived handoff/runtime artifacts so later diagnosis stays joinable.

</code_context>

<specifics>
## Specific Ideas

- Keep the first lifecycle layer conservative: one manifest per active task/run is easier to reason about than a broad hidden state machine.
- Use sidecar queryable storage for observability so Phase 25 can stay zero-intrusion to Hermes core while still giving operators something concrete to inspect.
- Favor one end-to-end acceptance fixture that proves the whole MVP chain, then add narrowly scoped lifecycle tests for timeout, cleanup, snapshots, and backpressure.

</specifics>

<deferred>
## Deferred Ideas

- Automatic SRE-Observer task creation, deadlock escalation windows, and fault-notification policy remain v1.4 work.
- Deployment/UAT/production release gates remain out of scope for this phase.

</deferred>

---
*Phase: 25-worker-lifecycle-observability-mvp-acceptance*
*Context gathered: 2026-05-11*
