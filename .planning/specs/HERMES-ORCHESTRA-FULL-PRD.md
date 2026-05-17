# Hermes Orchestra Full PRD

Date: 2026-05-17
Status: Saved for implementation triage
Related spec: `HERMES-ORCHESTRA-FULL-SPEC`
Primary design knowledge source: Getnote knowledge base `qnN4o510`

## Problem Statement

The user needs Hermes Orchestra to grow from the proven MVP vertical slice into the full Kimi-supervised engineering workflow described by the full-system design source. The current MVP proves key boundaries, but it does not yet deliver the complete debate package, worker isolation model, release pipeline, remote decision adapter contract, self-evolution loop, or runtime specialized-domain knowledge capability.

The user also needs the design to avoid several authority mistakes:

- Getnote `qnN4o510` is a requirements and design source, not a runtime dependency.
- Runtime domain knowledge must be project-owned and backed by gbrain, not by a new Hermes SQLite knowledge store.
- Debate reports are decision input, not final approval.
- Worker output, tmux transcripts, cache hits, event projections, and model summaries are not completion evidence.
- Kimi remains the external upper orchestrator while Gateway, Hermes-Agent, Kanban, workers, State, Audit, and artifacts form the lower execution framework.

Without a full PRD, implementation planning can drift back to the older MVP registries, legacy debate ids, direct project worker execution, raw Kanban API exposure, hidden template debate evidence, or a confused runtime knowledge boundary.

## Solution

Build the full Hermes Orchestra workflow as a local, auditable AI engineering system where Kimi supervises Six-Stage Runs through a Gateway Adapter. Gateway exposes product-level run projection operations, translates them into Hermes execution activity, and preserves a strict authority chain across Hermes Kanban, Gateway State, immutable Audit, schema-valid artifacts, harness/test evidence, and scoped artifact references.

The Gateway runtime baseline is the current project-local Python HTTP service shape. Kimi communicates with the Gateway through JSON Run Projection operations. The Gateway may reverse-proxy `/v1/*` traffic to the upstream Official Hermes API Server, and it integrates Hermes Kanban through CLI or API adapters. Local filesystem Gateway State, Audit, Events, command journals, and idempotency records remain the default authority stores until a later approved deployment profile changes that contract.

The full product experience should be:

1. Kimi submits or supervises a Structured Ticket or Structured PRD.
2. Gateway creates one Active Six-Stage Run per project and exposes status, task projection, decisions, and events without exposing raw Kanban mutation as the product API.
3. Direction, solution, and global evaluation stages use a Full Debate Package with the canonical qnN4o510 team and mode registries.
4. Debate Engine dynamically assembles relevant teams and members, invokes configured backends through a common adapter protocol, writes per-member opinions, preserves conflicts, and hands decision input to Kimi or Human Approval.
5. Hermes Kanban owns task lifecycle. Gateway State owns run metadata, command journals, event store, checkpoints, pending decisions, and artifact refs.
6. Workers execute through registered backends, scoped context envelopes, explicit write scopes, task-scoped workspaces, and task-scoped ephemeral tmux sessions.
7. Parallel worker execution is allowed only inside one run after explicit independence planning, workspace isolation, conflict scanning, serial integration, and review gates.
8. Runtime specialized-domain knowledge is stored and retrieved through gbrain CLI or MCP, using curated markdown pages with provenance, freshness, applicability, and audit records.
9. Release work follows configured environments, gates, UAT, approval, rollback or recovery evidence, and structured deployment reports.
10. Remote decision channels are optional transports only. Gateway validates responses before state advancement.
11. Kimi-Audited Self Evolution proposes durable improvements, but authority-impacting changes require Kimi audit and Human Approval where required.
12. Completion occurs only when closeout artifacts, Audit, Kanban, Gateway State, and required schema-valid evidence agree.

## User Stories

1. As Kimi, I want to create a Six-Stage Run through a product-level Run Projection API, so that I can supervise engineering work without operating raw Kanban CRUD.
2. As a user, I want the full workflow to preserve Kimi as the upper orchestrator, so that Hermes execution internals do not swallow product-level decision authority.
3. As Gateway, I want to translate Kimi-facing run commands into Hermes execution activity, so that upstream Hermes-Agent can remain unforked.
4. As a user, I want one Active Run per project, so that concurrent top-level workflows do not fight over the same repository state.
5. As Kimi, I want Active Runs to distinguish queued, running, and blocked states, so that ordinary work problems remain recoverable.
6. As Kimi, I want stopped and failed terminal runs to preserve lineage evidence, so that future runs can continue without mutating old evidence.
7. As Gateway, I want mutating run commands to use idempotency keys and command journals, so that retries do not duplicate side effects.
8. As Gateway, I want idempotency records retained with Gateway State without independent TTL, so that a retry cannot become a new command while its original authority side effect still exists.
9. As Gateway, I want command reconciliation after restart, so that unfinished commands are resolved from State, Audit, Kanban, and artifact refs instead of blindly replayed.
10. As Kimi, I want Gateway Events to be post-commit projections, so that progress streams never announce state that is not durable.
11. As Kimi, I want event sequence numbers and resync behavior, so that missing or corrupt progress events do not become workflow authority.
12. As an auditor, I want Audit to remain immutable and independent from Events, so that evidence is not reconstructed from a projection layer.
13. As Gateway, I want scoped artifact references, so that API responses do not leak absolute local paths or cross-run implementation details.
14. As a user, I want cache artifacts to be rebuildable only, so that cache hits never complete a run or approve a decision.
15. As Kimi, I want direction debate before solution design, so that the system challenges goals, risks, scope, and strategy before implementation planning.
16. As Kimi, I want solution debate before implementation, so that architecture, tradeoffs, tests, and execution strategy are reviewed before workers change code.
17. As Kimi, I want global evaluation before closeout, so that the whole run is audited independently before final acceptance.
18. As a user, I want final acceptance to be explicit, so that completed tasks do not silently become product acceptance.
19. As a user, I want high-risk and authority-impacting decisions to require Human Approval, so that Kimi or workers cannot bypass safety boundaries.
20. As Debate Engine, I want a Full Debate Package with sixteen canonical teams, so that review coverage matches the qnN4o510 full-system design.
21. As Debate Engine, I want every canonical team to have at least three member personas, so that team output is not a single generic perspective.
22. As Debate Engine, I want the canonical eight debate modes, so that routing and coverage policy use stable full-package semantics.
23. As a maintainer, I want legacy MVP debate ids treated as migration material only, so that old aliases do not dilute the full package.
24. As Debate Engine, I want team and mode registries to identify their package kind and registry authority, so that runtime can reject low-cost packages pretending to be the full package.
25. As Debate Engine, I want coverage policy and backend policy to be separate from team and mode identity, so that operational policy can change without redefining canonical registries.
26. As Debate Engine, I want deterministic Dynamic Debate Assembly from policy, so that each debate run invokes a relevant, auditable subset instead of relying on model-selected teams or always running every team and member.
27. As Debate Engine, I want each member invocation to produce a schema-valid Debate Member Opinion, so that evidence is structured and traceable.
28. As an auditor, I want each Debate Member Opinion to include team, member, mode, backend, evidence refs, risks, recommendations, confidence, warnings, and degradation flags, so that I can verify what happened.
29. As an auditor, I want debate member invocations to avoid durable raw prompts, secrets, and raw stdout, so that debate evidence does not leak sensitive material.
30. As Kimi, I want Debate Reports to synthesize findings, risks, recommendations, conflicts, confidence, and decision inputs, so that I receive usable decision support.
31. As Kimi, I want material disagreements preserved as Debate Conflicts, so that synthesis does not hide unresolved tradeoffs.
32. As Debate Engine, I want Partial Debate Reports only when coverage remains satisfied, so that failed optional member invocations do not block unnecessarily.
33. As Kimi, I want required coverage failure to block the stage, so that missing critical debate evidence is visible and recoverable.
34. As a user, I want template or simulation debate backends marked degraded, so that fixtures are not mistaken for real LLM evidence.
35. As a user, I want Kimi self-review risk recorded when Kimi is also used as a debate backend, so that Kimi cannot approve its own unsupported evidence.
36. As Debate Backend Adapter, I want a common invocation envelope and output contract, so that API, CLI, Hermes delegation, MoA, and template backends differ by transport rather than semantics.
37. As an auditor, I want Debate Audit Trails to record package snapshots, selected teams, selected members, backend choices, retries, timing, failures, degradation, and synthesis refs, so that debate evidence is replayable.
38. As Gateway, I want Worker Backend Registry and Worker Role Registry, so that execution roles are selected by declared capability rather than hard-coded tool names.
39. As Gateway, I want Capability Negotiation before worker dispatch, so that unavailable or incompatible backends cannot receive work and no backend is silently substituted.
40. As Worker Backend, I want structured Worker Context Envelopes and scoped context bundles, so that I receive enough context without full chat history or full repository dumps.
41. As Gateway, I want explicit Worker Write Scope for each task, so that code changes can be checked against the approved boundary.
42. As Worker Backend, I want a task-scoped Worker Workspace by default, so that implementation work is isolated from the main project checkout.
43. As Worker Backend, I want a task-scoped ephemeral Tmux Worker Session for real execution or observation, so that live worker execution is traceable and cleanly terminated.
44. As Gateway, I want a Worker Session Record for each real worker execution, so that session lifecycle, transcript refs, output refs, timeouts, and cleanup are auditable.
45. As an auditor, I want tmux transcripts treated as short-lived cache or debug context, so that transcripts do not become completion authority.
46. As Gateway, I want Worker Output Envelopes validated by a Gateway Advancement Gate, so that workers request advancement but do not directly mutate authority state.
47. As Kimi, I want direct project fallback allowed only as an explicit low-risk single-worker downgrade, so that workspace isolation remains the full-system default.
48. As Kimi, I want parallel worker execution only after a Parallel Independence Policy, so that parallelism is based on declared non-overlap rather than optimism.
49. As Gateway, I want a parallel group plan before parallel execution, so that task ids, workspaces, write scopes, locks, merge order, and review gates are known.
50. As Gateway, I want conflict scans before integration, so that out-of-scope writes, overlapping changes, and unauthorized authority-file edits are caught.
51. As Gateway, I want serial integration merges with tests and review gates, so that parallel output is integrated deterministically.
52. As Kimi, I want merge conflicts to produce a merge conflict report, so that I can decide repair, reorder, scope narrowing, or Human Approval instead of accepting auto-arbitration.
53. As a user, I want runtime domain knowledge separate from Getnote `qnN4o510`, so that design-source notes are not queried as production memory.
54. As a user, I want runtime domain knowledge backed by gbrain, so that Hermes can reuse an existing local brain with CLI and MCP surfaces instead of building another SQLite store.
55. As a domain curator, I want runtime knowledge entries to be markdown pages with required frontmatter and body sections, so that each claim has context, evidence, applicability, guidance, failure modes, and a checklist.
56. As a domain curator, I want unverified entries to start as candidate knowledge, so that raw notes or model conclusions do not become runtime evidence.
57. As a domain curator, I want promotion to domain knowledge to require source refs, verification, confidence, freshness, and applicability boundaries, so that retrieval evidence is trustworthy.
58. As Gateway, I want runtime knowledge queries and results recorded as artifacts, so that later audit can see what knowledge was retrieved and how it was bounded.
59. As a worker, I want gbrain retrieval results to include confidence, freshness, source refs, warnings, and slugs, so that I know whether knowledge can be used as strong evidence.
60. As a user, I want expired or candidate runtime knowledge downgraded to warning context, so that stale SDK, platform, policy, or cloud runtime rules do not mislead execution.
61. As a user, I want critical platform, API, SDK, policy, compliance, release, or security conclusions to trace to official sources, tests, production observations, or Human Approval, so that gbrain retrieval cannot bypass authority.
62. As a WeChat Mini Program developer, I want specialized platform knowledge available at runtime, so that workers can account for platform APIs, review rules, cloud constraints, and recurring gotchas.
63. As Kimi, I want Kimi-Audited Self Evolution, so that repeated failures, checklist improvements, routing fixes, and skill candidates are captured after evidence review.
64. As a user, I want self-evolution to propose rather than automatically apply authority-impacting changes, so that root rules, policies, CI/CD, install scripts, worker config, and debate config remain protected.
65. As Kimi, I want every Stage 6 closeout to record candidate improvement proposals, so that lessons are not lost even when no system change is applied.
66. As Kimi, I want deeper cross-run evolution review to be manually triggered, so that broad pattern analysis happens intentionally instead of as background self-modification.
67. As a release operator, I want a configured release pipeline from dev/test through staging to a project-defined production target, so that deployment is repeatable without assuming public internet production.
68. As a release operator, I want release gates for pre-deploy checks, staging validation, UAT, production approval, post-deploy validation, and rollback or recovery evidence, so that release completion is auditable.
69. As Gateway, I want release commands referenced through trusted command ids or command refs, so that arbitrary shell strings do not become release configuration authority.
70. As Gateway, I want release commands executed by the Gateway Release Executor with explicit approval, timeout, kill, output capture, redaction, and deployment-report contracts, so that workers or Kimi cannot run arbitrary deploy commands.
71. As a user, I want Remote Decision Channel disabled by default, so that local CLI or SSH remains the baseline approval path.
72. As a remote decision adapter, I want to transport decision requests and responses only, so that Gateway remains responsible for validation and state advancement.
73. As Gateway, I want remote decision intake to validate responder binding, expiry, replay protection, fixed phrase requirements, and audit refs, so that remote messages cannot directly approve risky work.
74. As a user, I want optional adapters such as Redis, GSD, remote messaging, and external retrieval to stay optional, so that the core workflow remains local and understandable.
75. As an auditor, I want run completion to require closeout artifacts, Audit, Hermes Kanban, Gateway State, schema-valid artifacts, and required evidence, so that completion is never a model self-report.

## Implementation Decisions

- Implement the full system as an extension around upstream Hermes-Agent rather than a fork of upstream Hermes-Agent.
- Extend the current Python local HTTP Gateway as the baseline full-system Gateway runtime. Do not introduce a Node, Go, shared-database, Redis, or remote-service rewrite as a prerequisite for full cutover.
- Keep Kimi outside the Hermes execution core as the upper orchestrator, supervisor, decision maker below human-risk gates, and experience auditor.
- Expose product-level Run Projection operations for create, inspect, stop, decide, subscribe, capabilities, and health. Do not expose raw Kanban mutation as the Kimi-facing product API.
- Maintain `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` as the actor-level capability and authority map for Kimi, Human, Gateway, Workers, Debate Backends, release execution, runtime knowledge, self-evolution, and full-contract cutover.
- Use JSON over HTTP for Kimi-facing Run Projection API operations, optional `/v1/*` reverse proxying for upstream Hermes API traffic, and local loopback, CLI, or SSH trust boundaries for the default local deployment.
- Define the minimum Run Projection API surface as health, capabilities, run create/status/events/tasks, stop, worker outputs, verdicts, global evaluations, closeout, terminal failures, decisions, and optional `/v1/*` upstream proxy routes.
- Provide `scripts/bin/orch-full-contract-validate` as the independent Full Contract Validation Tool for the full schema and staged full-system configs. Passing this tool is required before readiness gates but does not activate the full schema in Gateway runtime by itself.
- Keep the executable Gateway on the MVP/current runtime contract until artifact-family Full Contract Readiness Gates confirm validation, compatibility, runtime consumption, and explicit cutover.
- Use `config/cutover/full-readiness-gates.json` as the staged cutover policy. Do not allow a global one-shot switch from MVP Runtime Schema to Full Schema Package.
- Preserve historical run artifacts with their original schema versions. Read legacy artifacts through compatibility paths or lineage refs; do not rewrite them in place.
- After an artifact family passes its readiness gate, new runs write full artifacts for that family while non-activated families remain on their active MVP/current contracts.
- Use `config/performance/slo-policy.json` as the full target performance policy. Define component-level target budgets and degradation actions; do not promise a fixed wall-clock completion SLA for Six-Stage Runs.
- Exclude Human Approval wait time from SLO measurement and report external backend wait separately.
- Use `config/testing/full-fixture-policy.json` as the full target fixture policy. Split fixtures into contract fixtures and runtime fake adapters, and forbid fixtures from satisfying completion, approval, release, strong debate, or authority repair evidence.
- Maintain one Active Run per project. Allow run-internal parallelism only when explicit independence, workspaces, write scopes, locks, merge order, and review gates are declared.
- Use the Six-Stage Run as the top-level workflow: direction debate, solution debate, implementation, improvement, global evaluation, and continuous improvement.
- Keep Hermes Kanban as the task lifecycle authority. Keep Gateway State as the authority for run metadata, command journals, pending decisions, event store, resume checkpoints, and artifact refs.
- Keep immutable Audit as evidence authority for stage reports, decisions, retries, failures, downgrades, worker execution, debate runs, tests, releases, and closeout.
- Treat Gateway Events as a recoverable projection for supervision and UI, not as audit or completion evidence.
- Store idempotency records in local filesystem Gateway State by default, scoped by project id, endpoint, resource path, and Idempotency Key.
- Retain idempotency records with Gateway State without independent TTL. Same key and same payload returns the original command result; same key and different payload returns `idempotency_conflict`.
- For future archive or garbage collection, move idempotency records with the protected state or leave an archived stub that prevents the key from becoming a fresh command.
- Treat command recovery mismatches among Gateway State, Audit, Hermes Kanban, and artifact refs as Authority Chain Divergence. Do not replay side effects or synthesize missing Audit; block and route the repair decision to Kimi.
- Require command reconciliation reports to include journal step status, State/Audit/Kanban/artifact observations, divergence class, replay and synthetic-audit bans, and recommended repair options.
- Treat cache as rebuildable optimization data only. Redis may be an optional cache adapter, but it must not become canonical state.
- Upgrade the debate subsystem into a first-class Debate Engine with registries, dynamic assembly, backend adapters, schemas, coverage policy, backend policy, reports, conflicts, and audit trails.
- Use the qnN4o510 full-package registry as the canonical authority for the sixteen debate teams: security, compliance, data_engineering, devops_sre, frontend, ai_feature, scalability_arch, chaos_engineering, platform, privacy_ethics, oss_compliance, observability, business, documentation, api_design, and i18n_l10n.
- Require at least three default member personas for every canonical team.
- Use the qnN4o510 full-package registry as the canonical authority for the eight debate modes: sequential_review, parallel_debate, adversarial_debate, jury_panel, dynamic_assembly, meta_review, risk_priority_matrix, and cross_team_conflict_detector.
- Treat older MVP team and mode ids as legacy migration material only. They must not become canonical full-package aliases.
- Keep team and mode registry identity separate from Debate Coverage Policy and Debate Backend Policy.
- Add `config/debate/full/assembly-policy.json` as the deterministic Dynamic Debate Assembly policy. Selection starts from stage floor coverage, then adds task-type overlays, risk overlays, project overrides that only increase coverage, and deterministic member scoring.
- Require task-type overlays for database/migration, API/contract, frontend/UX, AI/model, release/deploy, and dependency/OSS work.
- Require L3/L4 risk overlays to add safety and operational teams, require stronger debate modes, and produce Human Approval decision input.
- Require Debate Audit Trails to record assembly inputs, matched rules, overlays, selected/skipped teams, selected members, and member scoring summaries.
- Require Debate Member Invocation Envelopes as structured adapter input. These envelopes carry identity, routing, backend contract, scoped input, persona contract, safety, and expected output metadata.
- Require every Debate Backend Adapter to return a schema-valid Debate Member Opinion plus invocation status or receipt.
- Support API, AI CLI, Hermes delegation, Hermes MoA, and template backend families through the same adapter contract. Template or simulation backends are explicitly degraded fixtures only.
- Treat `degraded` as artifact, backend, projection, or evidence state, not as a Run status.
- Require degraded and recovered artifacts to record `degradation_status`, `degradation_class`, cause, affected evidence refs, required decision, recovery options, acceptance ref, and completion-evidence policy.
- Default degraded artifacts to not satisfying required completion evidence unless `config/degradation/policy.json` explicitly allows the artifact family and the required Kimi Decision or Human Approval is recorded.
- Require recovery to write replacement evidence rather than overwriting the original degraded artifact.
- Record Kimi Self-Review Risk whenever Kimi contributes debate evidence for a stage that Kimi might also advance.
- Require Debate Reports to preserve selected teams, selected members, opinion refs, coverage, degradation, synthesis, risks, recommendations, conflicts, decision handoff, and traceability.
- Require Debate Audit Trails to preserve package snapshots, assembly records, invocation records, backend choices, retry state, timing, errors, degradation, synthesis refs, and safety flags.
- Make debate output decision input only. Kimi Decision and Human Approval remain the advancement authorities.
- Implement Worker Backend Registry, Worker Role Registry, Capability Negotiation, Worker Adapters, Worker Context Envelopes, Worker Context Bundles, Worker Write Scopes, Worker Output Envelopes, and Gateway Advancement Gate as the worker execution boundary.
- Add staged full worker configs under `config/workers/full/backends.json` and `config/workers/full/roles.json` while keeping root `config/workers/*.json` as MVP/current runtime configs until worker cutover.
- Require Worker Backend Registry entries to declare adapter type, install and health checks, compatible roles, protocols, capabilities, workspace/session support, risk ceiling, and fallback eligibility.
- Require Worker Role Registry entries to declare required capabilities, preferred backend, explicit fallback backends, allowed fallback failure classes, and fallback-forbidden conditions.
- Forbid implicit worker backend fallback. If Kimi requests Codex and Codex is unavailable, Gateway writes or returns `capability_negotiation_report` and blocks for Kimi unless the role registry explicitly allows a safe fallback.
- Require `worker_selection_record` for every selected or blocked worker pairing.
- Use task-scoped Worker Workspaces as the full-system default.
- Use task-scoped ephemeral Tmux Worker Sessions for real worker execution or observation, with lifecycle records, heartbeat and timeout fields, output refs, transcript refs, and cleanup status.
- Make Gateway Worker Session Sweeper the fallback owner for startup and periodic cleanup of timed-out, missing, or abandoned tmux sessions; Worker Adapters may attempt graceful stop but do not own cleanup authority.
- Treat tmux transcripts as short-lived cache or debug artifacts by default. They may be referenced or hashed in audit, but they are not completion evidence.
- Permit Direct Project Fallback only as an explicit low-risk single-worker downgrade. Forbid it for parallel work, release/deploy work, security work, rule changes, and authority-impacting configuration changes.
- Implement parallel worker execution through a declared parallel group plan, isolated workspaces, explicit write scopes, conflict locks, conflict scans, serial integration merge, tests, review gates, and conflict reports.
- Define conflict scans as mechanical and authority-boundary checks only. They must not claim semantic compatibility; behavior compatibility is validated by serial integration tests and review gates.
- Implement Kimi-Audited Self Evolution as a proposal and review loop. Do not automatically apply root rule, CI/CD, install, risk policy, worker config, debate routing, Gateway config, or runtime config changes.
- Run a candidate-only Stage 6 Candidate Evolution Sweep for every completed run. Trigger deeper Cross-Run Evolution Review only when Kimi explicitly requests it.
- Allow empty `system_improvement_proposals`; require conservative trigger matches before emitting non-empty proposals, such as authority divergence, worker cleanup failure, schema or full-contract validation failure, debate coverage failure, repeated same-class failures, repeated review/QA changes, or decision-exposed rule/documentation gaps.
- Use `config/evolution/self-evolution-review-queue.json` as the explicit Kimi-Audited Self Evolution review queue policy. Stage 6 proposals are queued by default instead of immediately interrupting Kimi.
- Prioritize self-evolution queue items by protected target, severity, repeated failures, evidence quality, source run count, and age. Batch only low or medium non-protected proposals that share review context.
- Retain accepted, rejected, deferred, superseded, and applied proposal records with decision refs, reasons, and audit refs. Rejected proposals must not be deleted.
- Require Kimi review and Human Approval for protected targets such as root rules, CI/CD, install scripts, risk policy, worker config, debate config, Gateway config, runtime config, release config, remote decision config, and full-contract cutover.
- Implement Runtime Domain Knowledge Base through gbrain CLI and/or MCP. Do not build a separate Hermes SQLite runtime knowledge store while gbrain is the configured backend.
- Store runtime domain knowledge as gbrain markdown pages with required frontmatter, stable slugs, required body sections, typed links, candidate/domain knowledge states, source refs, confidence, freshness, and owner metadata.
- Use gbrain ingestion operations for curated entries, directory imports, repository-backed sync, typed links, hybrid queries, reports, and MCP serving. Hermes should call or adapt gbrain rather than writing custom runtime knowledge tables.
- Record knowledge ingestion changes through knowledge ingestion records for promotion, overwrite, supersession, deprecation, and failed re-verification.
- Record runtime knowledge lookups through runtime knowledge query and result artifacts with domain, question, allowed types, required freshness, result refs, slugs, snippets, confidence, source refs, warnings, and created time.
- Default retrieval to verified domain knowledge. Candidate or expired knowledge may appear only in explicit research or debate contexts with warnings.
- Enforce freshness windows by entry class and downgrade expired entries to warning context.
- Preserve the evidence boundary: gbrain retrieval is useful context but cannot bypass official sources, tests, production observations, Kimi Decision, or Human Approval.
- Implement Release Pipeline configuration as project-defined environments, gates, command refs, approval policy, rollback policy, and evidence requirements.
- Add `config/release/commands.json` as the trusted Release Command Registry. It defines command refs, argv arrays, cwd refs, env allowlists, timeout policy, kill policy, output capture policy, redaction policy, and approval policy.
- Execute deploy and rollback commands only through the Gateway Release Executor. Kimi, Worker Backends, and Debate Backends may request or review release evidence, but they do not execute release commands directly.
- Require staging and production approval refs before command execution. Production approval is always Human Approval with a fixed phrase or equivalent strong confirmation.
- Treat release command timeout as a blocked deployment result. Gateway records `deployment_status: "timed_out"` and does not assume rollback succeeded without a separate schema-valid rollback deployment report.
- Store release stdout/stderr as redacted artifact refs and hashes, not raw Audit, Event, Kanban, or report body text.
- Treat public internet production as optional. Production may be local, internal, containerized, static, remote, or command-based, but UAT, approval, validation, and rollback or recovery evidence remain required when release is enabled.
- Keep Remote Decision Channel disabled by default. Local CLI or SSH decision flow remains the baseline.
- Treat Remote Decision Channel as transport only. Gateway validates decision responses for replay protection, expiry, responder binding, fixed phrase requirements, risk authority, and audit refs before advancing state.
- Keep optional adapters such as Redis, GSD methodology, remote messaging, and external design-source retrieval disabled unless configured.
- Upgrade schemas for debate member opinions, debate reports, debate audit trails, backend invocation envelopes, worker session records, parallel group plans, conflict scans, merge conflict reports, runtime knowledge queries/results, knowledge ingestion records, release pipeline config, decision requests/responses, and closeout artifacts.

## Testing Decisions

- Tests should verify external behavior through APIs, stored artifacts, schema validation, run/task projections, audit records, command records, worker outputs, release reports, and knowledge query/result artifacts. They should avoid asserting private helper implementation details.
- Keep a contract-first testing style: validate schemas, authority boundaries, artifact refs, lifecycle transitions, and observable side effects before testing implementation internals.
- Test Run Projection operations for create, inspect, stop, decide, status, events, capabilities, and health.
- Test idempotency for same-key same-payload replay, same-key different-payload conflict, in-progress command recovery, decision replay, stop replay, projection-degraded success, long-delay retry, no independent TTL, and archived-state behavior.
- Test command reconciliation after simulated restart using State, Audit, Kanban, and artifact refs.
- Test Authority Chain Divergence cases, including Kanban-created/Audit-missing, State-advanced/Kanban-missing, artifact-ref-missing, and Event-only corruption, and verify only Event-only corruption is projection repair rather than run blocking.
- Test that command reconciliation reports expose the observations and repair options Kimi needs instead of only returning a blocked status.
- Test Event Projection behavior: post-commit emission, per-run sequence, gap detection, resync, projection rebuild, and projection inconsistency isolation from authority state.
- Test scoped artifact reference resolution for valid refs, unknown schemes, absolute paths, traversal attempts, cross-project refs, and cross-run refs.
- Test one-active-run enforcement and blocked/stopped/failed/terminal run semantics.
- Test Six-Stage Run gating so that Structured Ticket or Structured PRD is required before execution starts, and closeout cannot complete without Stage 5 and Stage 6 evidence.
- Test full debate registries for exact canonical team ids, exact canonical mode ids, package authority markers, minimum member counts, and rejection of legacy full-package aliases.
- Test Debate Coverage Policy independently from team and mode registries.
- Test Dynamic Debate Assembly as a deterministic selector: stage floor coverage, task-type overlays, L1-L4 risk overlays, project overrides that only add coverage, member scoring, and stable tie-breaking.
- Test representative assembly fixtures, including database migration, API contract, frontend/UX, AI/model, release/deploy, and dependency/OSS tasks.
- Test Debate Backend Adapter contracts using fake API, fake CLI, fake Hermes delegation, fake MoA, and template backends that return valid and invalid member opinions.
- Test template or simulation backend handling to ensure it is always marked degraded and never counted as strong decision evidence.
- Test runtime fake adapters only in isolated test sandboxes, and verify they cannot advance Gateway authority state without the same validation gates as real adapters.
- Test the unified degradation state machine: normal, degraded, recovered, and blocked_due_to_degradation.
- Test that degraded artifacts do not satisfy required completion evidence by default, and that template debate fallback never counts as required debate coverage.
- Test recovery by writing replacement evidence while preserving the original degraded artifact.
- Test Debate Member Opinion validation for identity, routing, input refs, findings, evidence refs, risks, recommendations, confidence, verdict, blocking flags, degradation, warnings, and traceability.
- Test Debate Report synthesis for coverage, missing coverage, partial reports, failed invocations, conflicts, decision handoff, and audit refs.
- Test Debate Audit Trail records for package snapshots, selected teams, selected members, invocations, retries, timing, errors, degradation, and safety flags.
- Test Kimi Self-Review Risk when Kimi is configured as a debate backend, including the requirement for independent non-Kimi evidence before Kimi advances below human-risk gates.
- Test Human Approval gates for L3/L4, destructive, publishing, permission, secret, CI/CD, policy, root-rule, worker config, debate config, Gateway config, and runtime config changes.
- Test Worker Backend Registry, Worker Role Registry, and Capability Negotiation for enabled, disabled, missing, unavailable, incompatible, and fallback backends.
- Test full Worker Backend Registry and Worker Role Registry configs against `orchestra.full.schema.json`.
- Test Full Contract Readiness Gate policy validation, including global cutover disabled, artifact-family gates required, historical rewrite disabled, required gate evidence, and rollback or disable plans.
- Test Performance SLO Policy validation, including fixed run SLA disabled, human wait excluded, component budgets present, and budget-miss actions mapped to degraded or blocked outcomes.
- Test Full Fixture Policy validation, including contract/runtime fixture separation, required family coverage, fixture markers, degraded runtime fake adapters, and evidence-boundary denial for completion, release, approval, strong debate, and authority repair evidence.
- Test Capability Negotiation for unknown, disabled, unavailable, role-incompatible, missing-capability, protocol-incompatible, workspace/session-incompatible, and risk-ceiling-blocked backends.
- Test that backend fallback is never implicit and only succeeds when an explicit fallback backend, allowed failure class, and non-forbidden task context all match.
- Test Worker Context Envelope and Context Bundle redaction, scoping, and artifact refs.
- Test Worker Write Scope enforcement against actual changed files.
- Test Worker Output Envelope validation through Gateway Advancement Gate, including schema, identity, artifact refs, write scope, risk, required evidence, and failure normalization.
- Test Tmux Worker Session lifecycle for planned, starting, running, stopping, completed, failed, timed_out, and abandoned states.
- Test worker timeout, heartbeat, interruption, cleanup, abandoned session detection, transcript retention, and transcript non-authority.
- Test Gateway Worker Session Sweeper startup scan, periodic scan, graceful stop, forced kill, missing-session marking, cleanup audit, and task blocking on cleanup failure.
- Test Direct Project Fallback rejection for parallel work, release/deploy work, security work, rule changes, and authority-impacting configuration changes.
- Test parallel group planning, isolated workspace creation, conflict locks, conflict scans, serial integration merge order, post-merge tests, review gates, and merge conflict reports.
- Test that `conflict_scan` and `merge_conflict_report` record `semantic_conflict_detection: "not_claimed"` and that semantic failures are caught through post-merge tests or review gates.
- Test Runtime Domain Knowledge Base through a gbrain adapter contract using fake CLI/MCP responses for put, import, sync, link, query, report, and serve behavior.
- Test runtime knowledge entry validation for required frontmatter, required body sections, slug format, source refs, confidence, freshness, owner, and redaction requirements.
- Test candidate knowledge promotion rules and ensure raw Getnote notes, unverified blog summaries, stale platform rules, and model-only conclusions cannot become verified domain knowledge.
- Test runtime knowledge retrieval artifacts for allowed types, required freshness, max results, slugs, snippets, confidence, freshness status, source refs, warnings, and created time.
- Test expired and candidate knowledge downgrade behavior so they cannot be used as strong evidence.
- Test that Getnote `qnN4o510` is never queried as a runtime dependency, runtime knowledge backend, cache, state authority, or completion artifact.
- Test that Hermes does not create or depend on a separate SQLite runtime knowledge base when gbrain is configured.
- Test release pipeline and command registry validation for environments, gates, command refs, registry resolution, argv shape, env allowlist, approval policy, rollback policy, timeout policy, kill policy, output capture, redaction policy, and evidence requirements.
- Test release execution evidence for pre-deploy checks, staging validation, UAT, production approval, post-deploy validation, timeout handling, rollback or recovery, and structured deployment reports.
- Test that release commands are executed only by the Gateway Release Executor, that staging/production commands require approval refs before process start, that timed-out commands produce `timed_out` deployment reports and block the run, and that raw stdout/stderr never appears in Audit, Events, Kanban, or report bodies.
- Test Remote Decision Channel disabled-by-default behavior, local decision fallback, transport-only delivery, response validation, replay protection, expiry, responder binding, fixed phrase checks, and audit records.
- Test Kimi-Audited Self Evolution so candidate learnings and proposals are recorded but protected targets are not automatically modified.
- Test Stage 6 Candidate Evolution Sweep on every completed run, and test that Cross-Run Evolution Review is manual Kimi-triggered rather than always-on background work.
- Test that empty proposal artifacts are valid when no trigger matches exist, and non-empty proposal artifacts include trigger matches.
- Test Self Evolution Review Queue policy validation, including queue-required behavior, priority ordering inputs, protected target Human Approval, batching restrictions, low-evidence handling, rejected proposal retention, and no auto-apply.
- Test privacy and safety constraints across Events, Audit, debate artifacts, worker artifacts, release evidence, and runtime knowledge entries: no raw prompts, secrets, credentials, personal data, raw stdout, or unredacted sensitive paths in durable records.
- Prior art for test style is the existing MVP PRD, full spec, schema planning docs, ADRs, coverage matrix, and phase verification artifacts.

## Out of Scope

- Replacing or forking upstream Hermes-Agent.
- Making Getnote `qnN4o510` a runtime dependency, runtime knowledge backend, state authority, cache, or completion evidence source.
- Building a separate Hermes SQLite runtime knowledge base while gbrain is the configured runtime knowledge backend.
- Multi-user tenancy, enterprise authorization, or shared team workflow management.
- Same-project parallel top-level Six-Stage Runs.
- Automatic conflict arbitration for parallel worker output.
- Treating template or simulation debate output as real LLM decision evidence.
- Requiring every debate run to invoke all sixteen teams and every member persona.
- Automatic approval for L3/L4 or authority-impacting changes.
- Automatic modification of root rule files, CI/CD, install scripts, risk policy, worker backend config, debate routing config, Gateway config, or runtime config.
- Making Redis, GSD, external design-source retrieval, remote messaging, or public internet production required for the core full system.
- Hard-binding Remote Decision Channel to one platform.
- Treating gbrain retrieval as final truth for platform, API, SDK, policy, compliance, release, or security conclusions.
- Persisting raw prompts, secrets, raw stdout, sensitive personal data, or unredacted sensitive internal details as durable artifacts.
- Delivering a graphical product UI as part of this PRD. Kimi-facing APIs, CLI/SSH supervision, artifacts, and auditability are the product surface for this scope.

## Further Notes

- This PRD is the full-system companion to the existing MVP PRD. The MVP PRD remains the vertical-slice contract; this PRD captures the full implementation target after the grill-with-docs session.
- Source alignment comes from `CONTEXT.md`, `HERMES-ORCHESTRA-FULL-SPEC`, the qnN4o510 synthesis note, and the two ADRs that lock canonical debate team and mode ids.
- The gbrain implementation direction is based on the confirmed local gbrain CLI surface and the upstream gbrain repository. The runtime contract should follow the installed gbrain command behavior during implementation planning.
- The skill normally asks to publish the PRD to an issue tracker with a triage label. No project issue tracker configuration was available in this workspace, so this PRD is saved locally as the triage artifact.
