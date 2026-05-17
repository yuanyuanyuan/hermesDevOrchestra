# Hermes Orchestra Full Schema Package

Date: 2026-05-17
Status: Full target schema contract
Machine schema: `config/schemas/orchestra.full.schema.json`
Related docs: `HERMES-ORCHESTRA-FULL-SPEC`, `HERMES-ORCHESTRA-FULL-PRD`

## 1. Scope

The Full Schema Package defines the full-system acceptance contract for Hermes Orchestra after the MVP slice. It runs in parallel with the current MVP runtime schema.

The current `config/schemas/orchestra.schema.json` remains the MVP/current-runtime schema until implementation cutover. The full schema is a target contract and must not be treated as evidence that the full runtime capability is already implemented.

Full target validation starts through a Full Contract Validation Tool. The tool validates `config/schemas/orchestra.full.schema.json`, `config/debate/full/*`, `config/workers/full/*`, `config/cutover/full-readiness-gates.json`, and disabled formal full-system configs independently from the Gateway runtime advancement path.

`orchestra.full.schema.json` must not become a Gateway runtime validation target through a one-shot schema switch. Each artifact family requires a Full Contract Readiness Gate before cutover, including passing full-target validation, compatibility checks against MVP/current artifacts, runtime consumption tests, rollback or disable plan, and explicit confirmation that the runtime code for that artifact family consumes the full contract.

Historical runs keep their original schema versions and artifact shapes. Gateway may read legacy artifacts through compatibility paths and may write lineage refs or migration reports, but it must not rewrite historical artifacts in place.

## 2. Strictness Boundary

The first full schema version strictly validates guardrail fields:

- Artifact identity: `schema_version`, `artifact_type`, ids, stage, timestamps.
- Authority fields: decision authority, approval boundaries, completion gates.
- Routing fields: team, member, mode, backend, role, run, task.
- Evidence fields: artifact refs, source refs, report refs, audit refs.
- Coverage and degradation fields: required coverage, missing coverage, `degraded`, `degradation_status`, `degradation_record`, `partial`, `warnings`.
- Freshness and provenance fields for runtime knowledge.
- Safety fields that prevent raw prompts, raw stdout, secrets, unscoped paths, and runtime Getnote authority.

Deep business content such as `findings`, `risks`, `recommendations`, `conflicts`, and `synthesis` remains structurally typed as objects or arrays in this version. The schema should block MVP summary objects from pretending to be full artifacts, but it should not overfit every future business field before implementation feedback exists.

## 3. Artifact Coverage

### 3.1 Run and Gateway Authority

Covered artifacts:

- `run_create_request`
- `run_response`
- `run_status`
- `command_record`
- `idempotency_record`
- `command_reconciliation_report`
- `event`
- `event_query_response`
- `task_projection`
- `run_lineage`
- `run_failure_report`

Purpose: prove that Kimi-facing commands, idempotency, command journaling, event projection, terminal status, and lineage remain separate from raw Kanban mutation.

`idempotency_record` must be Gateway State, not cache. It uses `retention_policy: "retain_with_gateway_state"` and `expires_at: null` so an Idempotency Key cannot become reusable while the authority side effect it protects still exists.

`command_reconciliation_report` must carry the recovery evidence Kimi needs to decide blocked repair paths: journal step status, Gateway State observation, Audit observation, Hermes Kanban observation, artifact observation, divergence class, replay and synthetic-audit bans, and recommended repair options.

### 3.2 Six-Stage Evidence

Covered artifacts:

- `structured_ticket`
- `structured_prd`
- `stage_report`
- `development_plan`
- `test_plan`
- `test_execution_report`
- `review_or_qa_verdict`
- `global_evaluation_report`
- `iteration_closeout_report`
- `system_improvement_proposals`
- `self_evolution_review_queue_policy`

Purpose: prove that a Six-Stage Run has structured intake, executable planning, test evidence, review evidence, global evaluation, and closeout evidence before completion.

`system_improvement_proposals` must identify whether proposals came from the automatic Stage 6 Candidate Evolution Sweep or a Kimi-triggered Cross-Run Evolution Review. The artifact must remain candidate-only, must not record auto-applied system changes, and must carry review queue refs when proposals are non-empty.

The artifact may contain an empty `proposals` array when no conservative trigger matched. Non-empty proposals must include `trigger_matches` so Kimi can audit why the proposal exists.

`self_evolution_review_queue_policy` defines queue states, priority ordering, batching limits, protected target handling, backlog rules, review evidence sources, and rejected proposal retention. Rejected proposals are retained with reasons and audit refs; protected targets require Human Approval and cannot auto-apply.

### 3.3 Full Debate Package

Covered artifacts:

- `debate_team_registry`
- `debate_mode_registry`
- `debate_coverage_policy`
- `debate_assembly_policy`
- `debate_backend_policy`
- `debate_member_invocation`
- `debate_member_opinion`
- `debate_report`
- `debate_audit_trail`

Purpose: prove that debate is a first-class, auditable subsystem with canonical qnN4o510 team/mode registries, deterministic assembly policy, per-member outputs, coverage policy, backend policy, degraded evidence markers, and decision handoff.

`debate_assembly_policy` must define deterministic selection order, required inputs, task-type overlays, L1-L4 risk overlays, project override rules, member scoring, and audit requirements. Dynamic Debate Assembly must not rely on model-only free-form team selection.

`debate_audit_trail` must record the assembly policy ref, assembly inputs, matched rules, risk overlay, task-type overlays, project overrides, selected/skipped teams, selected members, and member scoring summaries.

Degraded debate artifacts must record `degradation_status` and `degradation_record`. Template debate fallback never counts as required debate coverage.

### 3.4 Worker Execution

Covered artifacts:

- `worker_backend_registry`
- `worker_role_registry`
- `capability_negotiation_report`
- `worker_selection_record`
- `worker_context_envelope`
- `worker_context_bundle`
- `worker_output_envelope`
- `worker_session_record`
- `parallel_group_plan`
- `conflict_scan`
- `merge_conflict_report`

Purpose: prove that workers execute through registered capabilities, scoped context, explicit write scope, task-scoped workspace/session records, Gateway-owned session cleanup, and controlled parallel integration.

`worker_backend_registry` and `worker_role_registry` are full target root artifacts staged under `config/workers/full/`. They must keep implicit backend fallback disabled and require explicit capabilities, install/health checks, workspace/session support, risk ceilings, fallback backends, and fallback-forbidden conditions.

`capability_negotiation_report` records blocked or fallback-capable backend selection evidence. If a requested backend is unknown, disabled, unavailable, role-incompatible, missing required capabilities, above risk ceiling, or workspace/session incompatible, Gateway must not silently substitute another backend.

`worker_selection_record` must record requested backend, selected backend, matched capabilities, adapter type, fallback status, attempt, negotiation status, and blocked reason.

`worker_session_record` must carry cleanup owner, cleanup status, timeout, heartbeat, and termination fields so tmux leaks are detected and handled by the Gateway Worker Session Sweeper rather than hidden inside a Worker Backend.

`conflict_scan` and `merge_conflict_report` must record `semantic_conflict_detection: "not_claimed"` because they cover mechanical and authority-boundary conflicts only. Semantic compatibility belongs to serial integration tests and review gates.

### 3.5 Runtime Domain Knowledge Base

Covered artifacts:

- `runtime_knowledge_entry`
- `knowledge_ingestion_record`
- `runtime_knowledge_query`
- `runtime_knowledge_result`
- `runtime_domain_knowledge_config`

Purpose: prove that runtime specialized-domain knowledge is project-owned, gbrain-backed, provenance-aware, freshness-aware, auditable, and separate from Getnote `qnN4o510`.

Expired or candidate-only runtime knowledge results must use warning-context degradation and cannot become strong completion evidence.

`runtime_domain_knowledge_config` validates the disabled formal runtime knowledge config at `config/knowledge/runtime-kb.json`: gbrain is the storage authority, PGLite is the default gbrain engine, no separate Hermes SQLite runtime knowledge store is allowed, gbrain retrieval is not final authority, and Human Approval cannot be bypassed.

### 3.6 Release and Decisions

Covered artifacts:

- `release_pipeline_config`
- `release_command_registry`
- `deployment_report`
- `decision_request`
- `decision_response`
- `remote_decision_channel_config`
- `stop_run_request`
- `stop_run_response`
- `capabilities_response`

Purpose: prove that release, deployment evidence, local/remote decisions, stop behavior, and capability reporting have explicit contracts and do not bypass Gateway validation.

`release_command_registry` is the trusted resolver for `deploy_command_ref` and `rollback_command_ref`. It defines argv arrays, working-directory refs, allowed environment variables, timeout policy, kill policy, output capture policy, redaction policy, and approval policy for the Gateway Release Executor. Arbitrary shell strings are not release authority.

`deployment_report` must be written for every deploy or rollback command execution. It records command refs, registry ref, Gateway Release Executor identity, argv hash, stdout/stderr artifact refs, exit code, start/finish/duration, timeout and kill fields, health-check refs, gate results, approval refs, and rollback or recovery refs. Raw stdout or stderr must not be embedded in durable Audit/Event/Kanban/report text.

### 3.7 Degradation Policy

Covered artifacts:

- `degradation_policy`

Purpose: prove that `degraded` is a cross-cutting evidence quality state, not a Run status. The policy defines the normal/degraded/recovered/blocked_due_to_degradation state machine, default completion-evidence denial, artifact-family exceptions, and replacement-evidence recovery rule.

### 3.8 Cutover Policy

Covered artifacts:

- `full_contract_readiness_gate_policy`

Purpose: prove that MVP-to-full cutover is staged by artifact family rather than a global schema switch. The policy records required evidence, historical artifact preservation, new-run behavior after activation, family-specific required checks, and rollback or disable rules.

### 3.9 Performance SLO Policy

Covered artifacts:

- `performance_slo_policy`

Purpose: prove that full-system performance is governed by component-level target budgets, measurement, and degradation behavior rather than a fixed Six-Stage Run completion SLA. Human wait time is excluded, external backend wait is reported separately, and component misses produce explicit degraded or blocked outcomes.

### 3.10 Fixture Policy

Covered artifacts:

- `full_fixture_policy`

Purpose: prove that test scaffolding has an explicit evidence boundary. Contract fixtures validate schemas and configs without runtime execution. Runtime fake adapters exercise Gateway integration paths in test sandboxes only. Fixtures must be marked, audited, degraded where applicable, and forbidden from satisfying completion evidence, release evidence, approval authority, strong debate evidence, or authority repair proof.

## 4. Full-System Safety Rules

All durable full-system artifacts must follow these rules:

- Use scoped artifact refs instead of absolute local paths.
- Do not persist raw prompts, raw stdout, secrets, tokens, credentials, personal data, or sensitive internal path details.
- Mark template or simulation backends as degraded fixtures.
- Treat degradation as artifact, backend, projection, or evidence state, not as Run status.
- Require degraded artifacts to record degradation class, cause, affected evidence refs, decision requirement, recovery options, acceptance ref, and completion-evidence policy.
- Do not let degraded evidence satisfy required completion evidence unless an artifact-family policy explicitly allows it and required acceptance is recorded.
- Do not treat Getnote `qnN4o510` as a runtime backend, runtime state authority, cache, or completion artifact.
- Do not treat gbrain retrieval as final authority for critical platform, API, SDK, policy, compliance, release, or security conclusions.
- Do not let remote decision transport directly mutate workflow state.
- Do not let worker output, debate recommendations, event projections, cache hits, or tmux transcripts complete a run.

## 5. Machine Schema Notes

`config/schemas/orchestra.full.schema.json` is the machine-readable target schema. It intentionally uses reusable definitions and allows `additionalProperties` on most artifact bodies so implementation can add fields without breaking the target contract, while still requiring the fields needed to prove authority, routing, evidence, coverage, degradation, freshness, and safety boundaries.
