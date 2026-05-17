# Hermes Orchestra MVP PRD

## Problem Statement

The user needs a local AI engineering workflow where Kimi can act as the upper orchestrator while Hermes-Agent, official Kanban, and real CLI workers execute the work below it. The current risk is that execution state, audit evidence, progress events, worker output, cache hits, and model summaries can be confused with each other. That confusion makes retries unsafe, completion ambiguous, and recovery unreliable.

The MVP must prove a complete vertical workflow: Kimi submits a structured engineering request, the Gateway turns it into a six-stage run, Hermes Kanban owns lifecycle execution, workers produce evidence, review and tests gate advancement, and closeout happens only when State, Audit, Kanban, and schema-valid artifacts agree.

The product must stay aligned with the `qnN4o510` premise: Kimi is the upper orchestration and supervision layer; Gateway is the API and state boundary; Hermes-Agent plus Kanban is the execution framework; durable State, immutable Audit, Schema, Harness evidence, and Kanban lifecycle form the authority chain. Events and cache are useful, but they must not become workflow truth.

## Solution

Build a local, single-user Hermes Orchestra MVP behind a Gateway Adapter. Kimi calls product-level `/orchestra/*` APIs to create, inspect, stop, and decide workflow runs. The Gateway translates those requests into official Hermes Kanban lifecycle operations, structured artifacts, worker dispatch, debate reports, test evidence, audit records, and event projections.

The user experience should be:

1. Kimi sends a structured ticket or short intake intent.
2. Gateway validates or normalizes the request into a structured PRD before execution begins.
3. Gateway creates one active Six-Stage Run for the project.
4. Hermes Kanban owns task lifecycle and dependency execution.
5. Gateway State owns workflow metadata, command journals, artifact refs, event store, and resume checkpoints.
6. Audit stores immutable evidence for decisions, stage outputs, failures, retries, fallbacks, and closeout.
7. Worker backends execute role-scoped work through a registry and structured envelopes.
8. Review, QA, tests, global evaluation, and closeout gates prevent model self-report or cache hits from completing a run.
9. Kimi supervises progress through run status, task projection, and Events, but must resync when the Event Projection is stale or inconsistent.
10. Mutating commands are idempotent, journaled, recoverable after crashes, and safe to retry without duplicate side effects.

## User Stories

1. As Kimi, I want to create a Six-Stage Run through a product-level API, so that I can orchestrate engineering work without manipulating Kanban tasks directly.
2. As Kimi, I want to submit a structured ticket, so that Hermes can begin execution without relying on vague chat context.
3. As Kimi, I want short intent to be intake-only, so that incomplete requests do not skip acceptance criteria, constraints, or failure strategy.
4. As a user, I want only one active run per project, so that two workflows do not compete over the same repository state.
5. As a user, I want run-internal parallelism only when independence is explicit, so that parallel workers do not create merge arbitration problems.
6. As Kimi, I want read-only task projection, so that I can supervise Kanban state without bypassing workflow rules.
7. As Kimi, I want a stop operation, so that I can halt a queued, running, or blocked run without deleting evidence.
8. As a user, I want stopped runs to preserve partial evidence, so that future lineage runs can learn from completed work.
9. As Kimi, I want blocked runs to remain active and recoverable, so that ordinary review, test, schema, or approval failures do not become terminal failures.
10. As a user, I want failed runs reserved for authority-chain corruption, so that normal work failures do not destroy recoverability.
11. As Kimi, I want terminal failed or stopped runs to continue only through a new lineage run, so that prior evidence is not rewritten.
12. As Gateway, I want mutating commands to require idempotency keys, so that retries after timeouts do not create duplicate runs, decisions, stops, Events, Audit records, or Kanban mutations.
13. As Gateway, I want command journals before side effects, so that crash recovery can reconcile what happened instead of replaying blindly.
14. As Kimi, I want retries with the same idempotency key and payload to return the original result, so that uncertain network responses are safe.
15. As Gateway, I want conflicting payloads under the same idempotency key to return a conflict, so that callers cannot accidentally reuse command identity.
16. As Gateway, I want successful authority writes plus failed Event append to return a projection-degraded success, so that Kimi does not retry and duplicate side effects.
17. As Kimi, I want projection degradation fields in mutating responses, so that I can distinguish workflow success from observation-layer repair.
18. As Kimi, I want Events ordered by per-run sequence, so that polling and SSE resume can detect gaps.
19. As Kimi, I want Event Projection inconsistency to require resync, so that stale progress never drives a workflow decision.
20. As a user, I want Events to be observation only, so that UI/SSE state cannot become completion, resume, or audit authority.
21. As Gateway, I want Event Store persistence in Gateway State, so that progress streams are rebuildable without polluting immutable Audit.
22. As Gateway, I want Event emission to be post-commit, so that Events never pre-announce stage, task, decision, stop, failure, artifact, or run completion.
23. As Gateway, I want complete Event Store retention in MVP, so that `since_seq`, SSE resume, idempotency replay, and projection rebuild stay simple.
24. As an auditor, I want Audit to remain immutable and independent from Events, so that evidence survives projection corruption.
25. As an auditor, I want Audit entries for decisions, retries, fallbacks, failures, downgrades, tests, and closeout, so that every important workflow transition is explainable.
26. As Gateway, I want State, Audit, Cache, and Repository Knowledge artifacts separated, so that each storage layer has one authority role.
27. As Gateway, I want scoped artifact references instead of absolute paths, so that APIs do not leak local filesystem details.
28. As Gateway, I want URI resolution to reject traversal and cross-run refs, so that artifact access remains scoped to the current project and run.
29. As a user, I want cache to store only rebuildable optimization data, so that cache hits never complete or resume work.
30. As a user, I want local filesystem cache in MVP and Redis as optional future work, so that the MVP can run locally without production dependencies.
31. As Kimi, I want worker backend selection through a registry, so that CLI and API backends are replaceable without changing workflow semantics.
32. As Gateway, I want capability negotiation before dispatch, so that a requested implementer or reviewer backend is registered, available, and role-compatible.
33. As an auditor, I want backend selection and fallback recorded, so that degraded worker execution is visible in final evidence.
34. As Gateway, I want worker inputs to use structured role envelopes and scoped context bundles, so that workers do not receive raw chat history or full repository dumps.
35. As Gateway, I want workers to return structured output envelopes, so that natural language summaries cannot directly advance State, Audit, or Kanban.
36. As Gateway, I want an Advancement Gate before lifecycle changes, so that worker outputs are validated for schema, identity, artifact refs, write scope, risk, and evidence.
37. As a reviewer, I want review and QA verdicts to be structured, so that feedback routes consistently to approval, request changes, rejection, or block.
38. As Kimi, I want Stage 4 improvement to be bounded to one cycle by default, so that repair does not become an unbounded hidden replanning loop.
39. As a user, I want Stage 4 repairs constrained by the approved development plan, so that automatic improvement cannot expand scope or change architecture.
40. As Kimi, I want Stage 5 global evaluation to audit all run evidence before closeout, so that unresolved warnings, downgrades, and failures cannot be hidden.
41. As a user, I want `pass_with_warnings` to require Kimi final acceptance below human-risk gates, so that residual risk is explicit.
42. As a user, I want L3/L4, destructive, publishing, permission, secret, CI/CD, policy, and root-rule changes to require Human Approval, so that high-risk boundaries cannot be bypassed.
43. As Gateway, I want Stage 6 closeout to write evidence and proposals, so that improvement ideas are captured without automatically changing root rules.
44. As Gateway, I want run completion to require closeout artifacts, Audit evidence, Kanban lifecycle completion, Gateway State consistency, and schema-valid required artifacts, so that completion is never model self-report.
45. As a user, I want Harness knowledge artifacts under project knowledge, so that future runs have durable local context without using external Get笔记 APIs at runtime.
46. As Gateway, I want Harness updates to avoid overwriting root rule files, so that generated learning does not silently change agent behavior.
47. As Kimi, I want debate reports as strong decision input, so that technical direction and solution choices are challenged before execution.
48. As Gateway, I want template debate fallback marked degraded, so that scaffold output is not mistaken for real decision evidence.
49. As a user, I want executable test planning and test execution reports, so that testing is real evidence rather than a checklist.
50. As a user, I want the MVP demo to perform real low-risk code-changing work, so that the vertical workflow proves execution, review, test, audit, events, and closeout.

## Implementation Decisions

- Build a local Gateway Adapter that exposes product-level run, status, events, tasks, decisions, stop, capabilities, and health APIs for Kimi.
- Preserve the upstream Hermes-Agent boundary and existing upstream pin strategy. The MVP extends through an adapter and must not fork or vendor upstream core as normal development flow.
- Keep official `/v1/*` agent-run/session traffic separate from `/orchestra/*` Six-Stage Run semantics.
- Do not expose raw Kanban CRUD to Kimi. Gateway may call official Kanban commands internally only as consequences of workflow rules and accepted artifacts.
- Use one active Six-Stage Run per project, with active statuses `queued`, `running`, and `blocked`.
- Use the top-level six-stage DAG: direction debate, solution debate, implementation, improvement, global evaluation, continuous improvement.
- Treat the existing planner, implementer, reviewer, and QA flow as an implementation sub-DAG, not the top-level workflow.
- Require structured ticket or schema-valid structured PRD before the six-stage DAG starts.
- Use Gateway State for workflow metadata, command journals, pending decisions, resume checkpoints, artifact refs, Event Store, and projection helpers.
- Use immutable Audit artifacts for stage reports, decisions, retries, fallbacks, failures, downgrades, test evidence, and closeout.
- Use Cache only for rebuildable optimization data. Cache must never store canonical state, approval state, Kanban lifecycle, immutable Audit, or raw sensitive input.
- Use scoped artifact refs for State, Audit, Cache, and Repository Knowledge artifacts.
- Use official Hermes Kanban as the canonical task lifecycle source.
- Use Gateway task projection as a read-only view synthesized from Kanban, Gateway State, Audit, and artifact references.
- Require idempotency keys for mutating run, decision, and stop commands.
- Scope idempotency by project, endpoint, resource path, and idempotency key.
- Write a command journal before mutating side effects.
- Recover in-progress commands by reconciling State, Audit, Kanban, and artifact refs.
- Never blindly replay a mutating command after crash or restart.
- Treat `command_id` as evidence correlation, not run identity, task identity, resume authority, or completion authority.
- Treat Event append steps as post-commit projection steps after authority writes.
- Store Event Store under Gateway State and expose it through State artifact refs.
- Retain complete Event Store in MVP without TTL, truncation, rotation, or lossy compaction.
- Treat Events as recoverable projection for Kimi progress, SSE, JSON polling, and UI replay.
- Treat Audit as immutable evidence authority. Audit cannot be reconstructed from Events.
- When Event append fails after authority writes succeed, return a successful authority result with projection degradation fields rather than a command failure.
- Require Kimi to resync from run status, task projection, and Events when sequence gaps or projection inconsistencies are detected.
- Use worker backend and role registries instead of hard-coded tool semantics.
- Dispatch workers only after capability negotiation.
- Use structured worker context envelopes, scoped context bundles, and explicit write scopes.
- Treat worker outputs as requests for advancement; Gateway validates before State, Audit, or Kanban lifecycle changes.
- Keep automatic Stage 4 improvement bounded and within approved development plan scope.
- Route review, QA, test, schema, approval, and repeated worker failures to blocked by default unless they cross the terminal failure boundary.
- Reserve terminal failed for unrecoverable authority-chain corruption, unrecoverable critical artifact loss, unauthorized writes that make evidence untrusted, or unrecoverable internal invariant violations.
- Require terminal failed and stopped runs to continue only through a new lineage run.
- Require Stage 5 global evaluation before Stage 6 closeout.
- Require closeout artifacts, Audit evidence, Kanban lifecycle, Gateway State consistency, and required schema-valid artifacts before run completion.
- Keep Get笔记 `qnN4o510` as planning background only. It is not an MVP runtime dependency.

## Testing Decisions

- Tests should verify externally observable behavior through API responses, stored artifacts, run/task projections, command records, and audit records. They should not assert private helper implementation details.
- Test the Gateway API contract for run creation, status, events, task projection, decisions, stop, capabilities, and health.
- Test schema validation for run requests, structured tickets, structured PRDs, fixed stage reports, Event responses, command records, worker envelopes, review/QA verdicts, test plans, test execution reports, global evaluation reports, closeout reports, lineage records, and failure reports.
- Test idempotency behavior for same-key same-payload replay, same-key different-payload conflict, in-progress command replay, decision replay, and stop replay.
- Test command journal recovery for completed-without-replay, continue-from-checkpoint, and ambiguous-blocked paths.
- Test authority ordering: command journal before side effects; authority writes before Event append; response summary after required authority refs.
- Test projection degradation: authority writes succeed, Event append fails, response is successful with projection degradation fields, retry does not repeat side effects.
- Test Event Projection behavior: per-run monotonic sequence, `since_seq` semantics, SSE resume compatibility, gap detection, rebuild from authorities, and projection inconsistency resync requirements.
- Test artifact resolver behavior for valid scoped refs, unknown schemes, absolute paths, traversal, cross-project refs, and cross-run refs.
- Test Kanban bridge behavior with official lifecycle states and read-only task projection.
- Test one-active-run enforcement and run-internal parallelism constraints.
- Test blocked vs failed classification for ordinary test/review/schema failures and unrecoverable authority-chain failures.
- Test stop semantics for queued, running, and blocked runs, including preserved evidence and partial closeout.
- Test lineage creation from terminal failed and stopped runs, and rejection of lineage creation from active blocked runs.
- Test worker backend registry and capability negotiation for known, unknown, disabled, unavailable, and role-incompatible backends.
- Test worker context envelope redaction and scoped context bundle behavior.
- Test Gateway Advancement Gate validation for protocol, identity, artifact refs, write scope, risk boundary, and required evidence.
- Test Stage 4 bounded improvement budget and scope enforcement.
- Test Stage 5 global evaluation routing for `pass`, `pass_with_warnings`, `fail`, and `block`.
- Test Stage 6 completion gate to ensure closeout text alone cannot complete a run.
- Test privacy and safety constraints: no raw prompts, tokens, secrets, full stdout/stderr, absolute paths, or unredacted raw tickets in Events or repository knowledge.
- Prior art for tests is the existing planning package: schema summaries, ADRs, validation policy notes, and phase-style verification docs. New tests should follow that contract-first style.

## Out of Scope

- Production hardening beyond a local single-user MVP.
- Public network exposure or Gateway authentication.
- Redis as a required dependency.
- Get笔记 as a runtime dependency.
- Automatic official Hermes API Server startup.
- Automatic modification of root rule files, CI/CD, install scripts, permission policy, risk policy, worker backend config, debate routing config, or Gateway/runtime config.
- Container isolation per task.
- Same-project parallel Six-Stage Runs, merge arbitration, and automatic conflict resolution.
- Full production-quality debate team implementation for all 16 teams and 8 modes.
- Full UI automation platform integration.
- External deployment or publishing workflows.
- Multi-user tenancy, remote authorization, or enterprise access control.
- Replacing official Hermes Kanban with a local simulated task store.

## Further Notes

- This PRD is based on `CONTEXT.md`, the accepted Hermes MVP grill decisions, MVP spec, schema summary, ADR-001 through ADR-025, and the later Event Projection/idempotency decisions through decision 316.
- The PRD was checked against Get笔记 knowledge base `qnN4o510`. The alignment constraint is that Kimi remains the upper orchestrator, Gateway is the API/state boundary, Hermes Kanban owns execution lifecycle, and State/Audit/Schema/Harness evidence remain the authority chain.
- Any later implementation plan should preserve the distinction between authority data and projection data. In particular, Events are useful for supervision and UX, but they do not complete, resume, or audit a run.
