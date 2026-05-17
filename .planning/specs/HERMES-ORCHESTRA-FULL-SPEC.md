# Hermes Orchestra Full Spec

Date: 2026-05-17
Status: Ready for implementation planning
Primary design knowledge source: Get笔记 knowledge base `qnN4o510`
Terminology source: `CONTEXT.md`

## 1. Purpose

This document is the canonical entry point for the complete Hermes Orchestra design after the MVP slice.

The full system keeps the `qnN4o510` architecture shape:

`Kimi -> Gateway -> Hermes Execution Framework -> Debate Engine -> Worker Backends -> Audit and Knowledge`

The full system is not a rewrite of upstream Hermes-Agent. Hermes-Agent, Gateway, Kanban, worker sessions, profiles, tool surfaces, state, audit, and artifacts form the lower execution framework. Kimi remains the external upper orchestrator that interprets intent, supervises progress, accepts results, and audits experience.

The Phase 19 design package is historical material and is not the authority for this full spec. When this document conflicts with older phase design text, this document wins.

## 2. Source Alignment

Get笔记 knowledge base `qnN4o510` is a Full-System Design Knowledge Source. It is used to reconstruct design principles, terminology, architecture tradeoffs, and requirements during planning and grill-with-docs sessions. It is not a runtime dependency, runtime knowledge backend, state authority, cache, or completion artifact.

Runtime domain knowledge is a separate project capability. Specialized domains such as WeChat Mini Program development require a project-owned Runtime Domain Knowledge Base with explicit ingestion, schema, retrieval, freshness, and audit policy. The target backend is gbrain with its local PGLite brain, CLI, and MCP surface. Hermes must not build a separate SQLite runtime knowledge base while gbrain is the configured backend. The runtime knowledge base is not `qnN4o510`.

The full system must preserve these `qnN4o510` principles:

- Kimi owns upper orchestration, supervision, final low/medium-risk acceptance, and experience audit.
- Hermes Gateway is the API, state, projection, and adapter boundary.
- Hermes-Agent plus Kanban is the execution framework and task lifecycle substrate.
- Debate teams provide multi-perspective decision input before important direction, solution, and global evaluation decisions.
- Schema, DAG/Kanban, Gateway State, Harness evidence, and Audit prevent process drift and model self-report completion.
- Kimi-audited self evolution decides what becomes durable learning, skill, or rule change.
- External services such as Redis, GSD, remote messaging, and design-source retrieval remain optional adapters unless explicitly configured.

## 3. Authority Chain

Runtime authority comes from:

- Hermes Kanban lifecycle state.
- Gateway State, including command journals, run state, event store, pending decisions, and checkpoint refs.
- Immutable Audit artifacts.
- Schema-valid stage artifacts.
- Harness and test execution evidence.
- Scoped artifact references.

The following are not authority:

- Cache hits.
- Model self-report.
- Tmux transcripts alone.
- Event projections alone.
- Get笔记 content at runtime.
- Debate recommendations without Kimi Decision or Human Approval.

### 3.1 Command Reconciliation Divergence Rule

Command Reconciliation must never blindly replay an unfinished Command Journal entry.

If Gateway restart finds that a command has produced a Hermes Kanban side effect but the matching Audit, Gateway State, or required artifact refs are missing or contradictory, the condition is Authority Chain Divergence. Gateway must:

- preserve the observed Kanban, State, Audit, and artifact evidence;
- write a `command_reconciliation_report` with `reconciliation_status: "blocked"`;
- keep or move the run to Blocked Run state;
- avoid repeating the side effect;
- avoid fabricating missing immutable Audit after the fact; and
- ask Kimi to decide whether to accept the orphan side effect through an explicit repair path, create a revision/repair task, stop the run, or escalate for Human Approval.

Missing or corrupt Gateway Events alone are Projection Inconsistency, not Authority Chain Divergence, when Gateway State, Audit, Hermes Kanban, and artifact refs still agree.

Every `command_reconciliation_report` must include enough evidence for Kimi to decide the repair path:

- `journal_step_status`
- `state_observation`
- `audit_observation`
- `kanban_observation`
- `artifact_observation`
- `divergence_class`
- `side_effect_replay_allowed: false`
- `synthetic_audit_allowed: false`
- `recommended_repair_options`

### 3.2 Idempotency Retention Rule

Idempotency records are Gateway State, not cache. The default store is the local filesystem Gateway State under the project idempotency directory. Redis, memory, or a remote database are not the baseline authority store.

An Idempotency Key is scoped by:

`project_id + endpoint + resource_path + idempotency_key`

An `idempotency_record` must preserve:

- `payload_hash`
- `command_id`
- command status
- command record ref
- authority result or Projection-Degraded Command Result
- `created_at`
- `last_seen_at`
- `retention_policy: "retain_with_gateway_state"`
- `expires_at: null`

Idempotency records have no independent TTL. They are retained with Gateway State for active, blocked, stopped, failed, and completed runs. Retrying the same key with the same payload after days or weeks returns the original command result. Retrying the same key with a different payload returns `idempotency_conflict`.

The idempotency record must not expire before the authority side effect it protects. If a future archive or garbage collection profile moves Gateway State, the idempotency record must move with that state or leave a durable archived record that prevents the key from becoming a fresh command. In that case Gateway may return `idempotency_record_archived` or `state_restore_required`, but it must not execute the command as new work.

### 3.3 Degradation Model

`degraded` is not a Six-Stage Run status. Run status remains only `queued`, `running`, `blocked`, `failed`, `completed`, or `stopped`.

Degradation describes artifact, backend, projection, or evidence quality. The unified degradation state machine is:

`normal -> degraded -> recovered`

`degraded -> blocked_due_to_degradation -> recovered`

Degradation may be triggered by:

- template debate fallback;
- required real backend unavailable where fixture or partial evidence is allowed;
- Event Projection append failure after authority writes are durable;
- runtime knowledge that is expired or candidate-only;
- optional Debate Member Invocation failure while coverage remains satisfied; or
- schema mismatch or required evidence degradation.

Every degraded or recovered artifact must include a `degradation_record` with:

- `degradation_class`
- `cause`
- `affected_evidence_refs`
- `decision_required`
- `recovery_options`
- `accepted_by_ref`
- `completion_evidence_allowed`

The default policy is that degraded artifacts cannot satisfy required completion evidence. An artifact family may allow degraded evidence only when `config/degradation/policy.json` explicitly allows it and the required Kimi Decision or Human Approval is recorded. Template debate fallback never counts as required debate coverage.

Recovery requires replacement evidence or a repair artifact. The system must not overwrite the original degraded artifact. It writes replacement evidence and marks the later artifact or projection as `recovered`.

## 4. Core Workflow

The top-level workflow is a Six-Stage Run:

1. `direction_debate`
2. `solution_debate`
3. `implementation`
4. `improvement`
5. `global_evaluation`
6. `continuous_improvement`

Kimi may create and supervise runs through the Run Projection API. Kimi must not operate raw Kanban CRUD as a product API.

There is one Active Run per project. Run-internal parallelism is allowed only when a Parallel Independence Policy proves that tasks have non-overlapping write scopes, isolated workspaces, conflict detection, and review or merge gates.

### 4.1 Gateway Runtime Contract

The full-system Gateway target extends the current MVP runtime shape instead of introducing a language or storage rewrite before cutover.

The default Gateway runtime is:

- a project-local Python HTTP service;
- JSON over HTTP for Kimi-facing Run Projection API operations;
- optional `/v1/*` reverse proxying to the upstream Official Hermes API Server;
- Hermes Kanban CLI or API adapter integration for task lifecycle side effects;
- local filesystem Gateway State, Audit, Event Store, Command Journal, and Idempotency Key records; and
- local loopback, CLI, or SSH trust boundary for the default local deployment.

The full system must not require Node, Go, Redis, a shared database, or a remote service deployment as the baseline Gateway architecture. Those may become optional adapters or future deployment profiles only after explicit readiness gates.

Run Projection API responses are JSON objects. Kimi must not receive raw Kanban CRUD as the product workflow surface. Remote authentication and remote approval transport are separate adapter concerns; they do not replace Gateway validation, idempotency, decision expiry, responder binding, or authority-chain checks.

The minimum Kimi-facing Run Projection API surface is:

- `GET /health`
- `GET /orchestra/capabilities`
- `POST /orchestra/runs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`
- `POST /orchestra/runs/{run_id}/stop`
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `POST /orchestra/runs/{run_id}/verdicts`
- `POST /orchestra/runs/{run_id}/global-evaluations`
- `POST /orchestra/runs/{run_id}/closeout`
- `POST /orchestra/runs/{run_id}/failures`
- `POST /orchestra/decisions/{decision_id}`
- `/v1/*` upstream Hermes API proxy routes, when an upstream Official Hermes API Server is configured

All mutating Run Projection API endpoints require an Idempotency Key and record a Command ID before authority side effects are applied.

### 4.2 Capability Authority Matrix

The full target actor capability map lives at `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md`.

The matrix is part of the authority contract. It distinguishes request authority, decision authority, approval authority, execution authority, and state-advancement authority across Kimi, Human, Gateway, Workers, Debate Backends, release execution, runtime knowledge, self-evolution, and full-contract cutover.

Default rule: Kimi and Human may request or decide within their authority boundaries, but Gateway validates, executes, and advances authority state. Workers and backends produce scoped outputs or evidence; they do not mutate Gateway State, Audit, Hermes Kanban, release state, or full-schema readiness state directly.

### 4.3 Full Contract Validation Tool

The full target validation tool is `scripts/bin/orch-full-contract-validate`.

The tool validates the Full Schema Package and staged full-system configs without making them active Gateway runtime validators. It uses Draft 2020-12 validation through `jsonschema` when available and falls back to a built-in validator for the schema subset used by staged full configs, so the tool does not add a mandatory runtime dependency to the MVP Gateway. It must check at least:

- `config/schemas/orchestra.full.schema.json` parses and is a valid Draft 2020-12 schema.
- Full debate package configs validate against the full schema and preserve canonical team and mode ids.
- Full worker backend and role registries validate against the full schema.
- Full contract readiness gate policy validates against the full schema.
- Performance SLO policy validates against the full schema.
- Full fixture policy validates against the full schema.
- Self evolution review queue policy validates against the full schema.
- Degradation, release, remote decision, and runtime knowledge configs validate against the full schema.
- Release pipeline command refs resolve through `config/release/commands.json`.
- Disabled formal configs remain disabled before implementation cutover.

This tool is a readiness and planning validator, not a runtime state advancement path. Passing it does not mean Gateway consumes full artifacts yet.

### 4.4 Gateway Full Runtime Readiness

The current executable Gateway remains the MVP/current runtime until artifact-family readiness gates pass. The Gateway Runtime Contract defines the full target architecture, but the full runtime is not considered implemented until the runtime can consume full schema artifacts, full target configs, capability negotiation, release execution, runtime knowledge, remote decisions, and closeout gates through the same authority chain.

Gateway full-runtime readiness requires:

- `orch-full-contract-validate` passing in CI or the selected validation path.
- A Full Contract Readiness Gate for each artifact family being activated, using `config/cutover/full-readiness-gates.json`.
- Compatibility checks against MVP/current artifacts and projections.
- Runtime code that consumes the full contract for that artifact family.
- Explicit cutover confirmation that the MVP Runtime Schema is no longer the active validation target for that artifact family.

### 4.5 MVP-To-Full Cutover Policy

MVP-to-full cutover is staged by artifact family. A global one-shot switch from `config/schemas/orchestra.schema.json` to `config/schemas/orchestra.full.schema.json` is not allowed.

The staged cutover policy lives at `config/cutover/full-readiness-gates.json` with `artifact_type: "full_contract_readiness_gate_policy"`.

The policy must keep:

- `global_cutover_allowed: false`
- `artifact_family_cutover_required: true`
- `mvp_schema_remains_default: true`
- `historical_run_rewrite_allowed: false`

Each artifact family gate must require:

- a full contract validation report;
- an MVP compatibility report for existing artifacts, projections, or config;
- runtime consumption tests proving Gateway uses the full contract for that family;
- projection compatibility checks where Kimi-facing projections are affected;
- a rollback or disable plan that preserves already-written full artifacts; and
- an explicit cutover decision.

Historical runs keep their original schema versions and artifact shapes. Gateway may read them through compatibility paths and may write lineage refs or migration reports, but it must not rewrite historical artifacts in place. New runs write full artifacts only for artifact families that have passed their gate. Mixed-family runs are allowed during staged cutover; completion evaluates each artifact family against the active contract for that family.

### 4.6 Performance SLO Policy

The full target performance policy lives at `config/performance/slo-policy.json` with `artifact_type: "performance_slo_policy"`.

The full system uses target budgets with degradation, not a fixed wall-clock completion SLA for a Six-Stage Run. Six-Stage elapsed time is recorded and reported for planning, trend analysis, and capacity review, but it is not enforced as a completion SLA.

The policy must keep:

- `fixed_run_duration_sla_allowed: false`
- `human_wait_excluded_from_slo: true`
- `external_backend_wait_reported_separately: true`
- `budget_policy.hard_completion_sla_for_six_stage_run: false`

Component budgets cover Gateway API projections, Event Projection, full contract validation, Debate Engine, worker execution, Runtime Domain Knowledge, Release Pipeline, and Remote Decisions.

Budget misses must produce explicit behavior rather than hidden slowness:

- authority writes that succeed but miss Event Projection budget return a projection-degraded result;
- required debate coverage timeout blocks the stage;
- optional debate member timeout may write a degraded partial report;
- worker heartbeat timeout routes through the Gateway Worker Session Sweeper and blocks the worker task;
- runtime knowledge timeout continues only as warning context and cannot become strong completion evidence;
- release command timeout writes a timed-out deployment report and blocks; and
- remote human response wait is excluded, while delivery failures fall back to the local decision path when configured.

SLO claims require enough samples to report percentiles. Before enough samples exist, the policy is a target budget and measurement contract, not an availability or latency guarantee.

### 4.7 Full Fixture Policy

The full target fixture policy lives at `config/testing/full-fixture-policy.json` with `artifact_type: "full_fixture_policy"`.

The full system has two fixture layers:

- **Contract fixtures** validate schemas, configs, edge cases, and readiness gates. They do not execute runtime paths, mutate state, satisfy completion evidence, or satisfy release evidence.
- **Runtime fake adapters** exercise Gateway adapter and recovery paths in isolated integration tests. They may mutate only test sandbox state and must be marked as fixture backends, degraded fixtures, and test-scope only.

Fixture coverage must include debate, worker execution, release pipeline, recovery, runtime knowledge, and remote decision paths.

Fixtures must not become completion evidence, release evidence, approval authority, strong debate evidence, authority repair proof, or production backend evidence.

Every runtime fake adapter must emit fixture markers, degradation records where applicable, and audit refs. Raw fixture payloads must not be stored as durable Audit body text.

## 5. Debate Engine

The Debate Engine is a first-class subsystem. It reads full debate packages from configuration, assembles debate runs dynamically, invokes member personas through backend adapters, and writes Debate Reports plus Debate Audit Trails.

Debate output is decision input. It never replaces Kimi Decision or Human Approval.

### 5.1 Full Debate Package

The full package keeps the `qnN4o510` shape:

- 16 canonical debate teams.
- At least 3 Debate Member Personas per team.
- 8 canonical debate modes.
- Package-defined Debate Coverage Policy.
- Configurable Debate Backend Policy.
- Debate-local checklists.

Low-cost or local packages may select fewer teams or members, but they must be marked as low-cost or degraded and cannot represent full-system acceptance.

### 5.2 Canonical Team Set

The canonical full-system debate teams are:

- `security`
- `compliance`
- `data_engineering`
- `devops_sre`
- `frontend`
- `ai_feature`
- `scalability_arch`
- `chaos_engineering`
- `platform`
- `privacy_ethics`
- `oss_compliance`
- `observability`
- `business`
- `documentation`
- `api_design`
- `i18n_l10n`

The qnN4o510 registry is the authority for full-package team ids. Legacy or earlier-spec ids such as `product`, `business_product`, `integration`, `platform_integration`, `architecture`, `ux`, `data`, `testing`, `operations`, `reliability`, `performance`, `maintainability`, `privacy`, and `release` are not canonical in the full package.

### 5.3 Canonical Mode Set

The canonical full-system debate modes are:

- `sequential_review`
- `parallel_debate`
- `adversarial_debate`
- `jury_panel`
- `dynamic_assembly`
- `meta_review`
- `risk_priority_matrix`
- `cross_team_conflict_detector`

The qnN4o510 registry is the authority for full-package mode ids. Legacy or earlier-spec ids such as `red_team`, `risk_review`, `consensus`, `closeout_review`, `tradeoff_matrix`, `implementation_review`, `test_strategy`, and `architecture_review` are not carried forward as canonical aliases.

### 5.3.1 Legacy MVP Config Migration

The existing `config/debate/teams.json` and `config/debate/modes.json` files are legacy MVP registries. They may be used as migration source material, but they cannot define full-package runtime aliases or represent full-system acceptance.

Full Debate Package implementation must consume the staged qnN4o510 canonical team and mode registries under `config/debate/full/` until an explicit cutover replaces the legacy runtime registries. If an implementation needs to keep the old root registry shape temporarily, it must mark that package as `legacy_mvp`, low-cost, or degraded rather than as a Full Debate Package.

### 5.3.2 Target Config Artifacts

The canonical Full Debate Package is staged beside the existing runtime config paths:

- `config/debate/full/teams.json` stores the sixteen canonical teams. Each team entry includes its qnN4o510 dimensions and at least three default member personas.
- `config/debate/full/modes.json` stores the eight canonical modes. Each mode entry includes purpose, selection rules, and output contract.
- `config/debate/full/coverage-policy.json` stores package coverage minimums.
- `config/debate/full/backend-policy.json` stores package backend selection and fallback policy.

Both registries must identify themselves as full-package registries with `package_kind: "full_debate_package"` and `registry_authority: "qnN4o510"`.

Debate Coverage Policy and Debate Backend Policy should be separate package configuration artifacts. They should not be embedded inside team or mode registries because they are runtime policy, not registry identity.

### 5.3.3 Debate Team Registry Required Fields

`config/debate/full/teams.json` must contain the following root fields:

- `schema_version`
- `artifact_type: "debate_team_registry"`
- `package_kind: "full_debate_package"`
- `registry_authority: "qnN4o510"`
- `teams`

Each team entry must contain:

- `id`
- `name`
- `focus`
- `dimensions`
- `members`

Each member entry must contain:

- `id`
- `focus`
- `dimension_refs`
- `checklist_refs`
- `output_requirements`

The registry must contain exactly sixteen teams. Each team must have at least three members. Team ids must come from the Canonical Debate Team Set; legacy MVP ids must not appear in a full-package registry.

### 5.3.4 Debate Mode Registry Required Fields

`config/debate/full/modes.json` must contain the following root fields:

- `schema_version`
- `artifact_type: "debate_mode_registry"`
- `package_kind: "full_debate_package"`
- `registry_authority: "qnN4o510"`
- `modes`

Each mode entry must contain:

- `id`
- `name`
- `purpose`
- `mechanism`
- `selection_rules`
- `required_inputs`
- `output_contract`

The registry must contain exactly eight modes. Mode ids must come from the Canonical Debate Mode Set; legacy MVP ids must not appear in a full-package registry.

`selection_rules` describe when a mode applies. They must not define coverage minimums. Debate Coverage Policy and Debate Backend Policy remain separate package configuration artifacts.

### 5.4 Members, Personas, and Checklists

A Debate Team Configuration contains member personas, rubrics, required outputs, and optional checklist references.

A Debate Member Persona is not a Hermes skill and is not a permanent subagent. It is a configured expert viewpoint such as `security.threat_modeler`, `compliance.policy_guardian`, or `api_design.contract_reviewer`.

Personas should reference Debate Checklists by default:

- Use `checklist_refs` for debate-local reusable checklists.
- Use `hermes_skill_refs` only for installed Hermes skills that were promoted through Kimi-Audited Self Evolution.

Debate Checklists cannot automatically become Hermes skills. Stage 6 may propose promotion through a System Improvement Proposal, but Kimi audit and any required Human Approval are required before installing or changing a Hermes skill.

### 5.5 Member Output Schema

Every Debate Member Invocation must produce a schema-valid Debate Member Opinion with at least:

- Identity fields: `schema_version`, `artifact_type: "debate_member_opinion"`, `opinion_id`, `debate_id`, `run_id`, `stage`, `invocation_id`, and `created_at`.
- Member routing fields: `package_ref`, `team_id`, `member_id`, `mode`, and `backend_id`.
- Input fields: `question`, `input_refs`, and `checklist_refs`.
- Opinion content fields: `position`, `findings`, `evidence_refs`, `risks`, `recommendations`, `confidence`, and `open_questions`.
- Decision hint fields: `verdict`, `blocking`, `requires_kimi_decision`, `degraded`, and `warnings`.

Teams may add fields, but the common fields are mandatory.

Debate Member Opinion artifacts must not persist raw prompts, secrets, or raw stdout. `team_id`, `member_id`, and `mode` must be traceable to the package configuration used for the debate run.

### 5.6 Backend Model

Debate Backend Policy is configurable per package or project. Supported backend families may include:

- API fan-out, such as MiniMax or OpenRouter.
- AI CLI invocation, such as Kimi, Claude, or Codex.
- Hermes delegation.
- Hermes MoA.
- Template fallback for fixtures and schema development.

The Debate Backend Adapter executes member work but does not own team semantics, workflow authority, or final decisions.

MiniMax may be a useful backend because `qnN4o510` emphasizes cost-effective debate, but no backend provider is hard-coded.

Kimi may be configured as a debate backend, but if Kimi contributes debate evidence for a stage, the stage must record Kimi Self-Review Risk and include at least one non-Kimi Debate Member Opinion before Kimi can advance the stage below human-risk gates.

### 5.6.1 Backend Adapter Protocol

All Debate Backend Adapters use a common artifact contract:

- They receive the same Debate Member Invocation Envelope.
- They return a schema-valid Debate Member Opinion plus an invocation receipt or status.
- API, CLI, Hermes delegation, and MoA backends differ by transport and execution strategy, not by output artifact contract.
- Template or simulation backends may only be used as explicitly degraded fixtures. They must not be represented as real LLM debate evidence.

Adapters do not own team semantics, coverage policy, or final decision authority. Those remain owned by the Debate Engine, Kimi Decision, and Human Approval gates.

Every adapter invocation must record `backend_id`, backend capabilities, timing, retry state, degraded state, and `error_class` so the Debate Audit Trail can prove which backend produced each Debate Member Opinion.

### 5.6.2 Debate Member Invocation Envelope

Every Debate Backend Adapter receives a Debate Member Invocation Envelope with at least:

- Identity fields: `schema_version`, `artifact_type: "debate_member_invocation"`, `invocation_id`, `debate_id`, `run_id`, `stage`, and `created_at`.
- Routing fields: `package_ref`, `team_id`, `member_id`, `mode`, and `backend_id`.
- Backend contract fields: `backend_family`, `backend_capabilities`, `transport`, `timeout_seconds`, and `retry_policy`.
- Scoped input fields: `question`, `context_refs`, `artifact_refs`, `option_refs`, and `evidence_scope`.
- Persona contract fields: `member_focus`, `dimension_refs`, `checklist_refs`, and `output_requirements`.
- Safety fields: `redaction_required`, `secret_scan_required`, `raw_prompt_persistence_allowed: false`, and `raw_stdout_persistence_allowed: false`.
- Expected output fields: `expected_artifact_type: "debate_member_opinion"` and `opinion_schema_ref`.

The envelope is structured input for the adapter. It is not a durable full prompt archive. An adapter may build a temporary prompt for its transport, but durable state stores only references, hashes, status, and the final schema-valid Debate Member Opinion.

### 5.7 Fan-Out and Subagents

The default debate execution pattern is Orchestra-Controlled Debate Fan-Out:

1. The Debate Engine selects member personas through Dynamic Debate Assembly.
2. Each member invocation receives scoped structured input.
3. Each member writes a separate Debate Member Opinion.
4. The Debate Engine synthesizes opinions, conflicts, risks, and recommendations.
5. The system writes a Debate Report and Debate Audit Trail.

A single AI CLI that spawns internal subagents may be used as a backend only if it exposes each member's input, output, evidence refs, timing, and degraded state separately. One opaque CLI summary cannot stand in for all debate members.

### 5.8 Dynamic Assembly and Coverage

The Full Debate Package is complete, but every Debate Run does not need to invoke all teams and members.

Dynamic Debate Assembly is a deterministic policy-driven selector, not a free-form model choice. The selector reads `config/debate/full/assembly-policy.json` plus Debate Coverage Policy, then chooses teams, members, and modes based on stage, task type, risk, affected scopes, and project overrides.

The selection order is:

1. Apply the stage floor from `config/debate/full/coverage-policy.json`.
2. Add task-type overlays from `config/debate/full/assembly-policy.json`.
3. Add risk overlays from `config/debate/full/assembly-policy.json`.
4. Apply project overrides that only increase coverage.
5. Select members with deterministic scoring.

Task-type overlays must cover at least:

- `database_migration` -> `data_engineering`, `devops_sre`, `security`, `observability`
- `api_contract` -> `api_design`, `security`, `platform`, `documentation`
- `frontend_ux` -> `frontend`, `api_design`, `i18n_l10n`
- `ai_model` -> `ai_feature`, `privacy_ethics`, `security`, `observability`
- `release_deploy` -> `devops_sre`, `observability`, `platform`, `security`
- `dependency_oss` -> `oss_compliance`, `security`

Risk overlays use the full-schema risk levels:

- `L1`: stage floor only.
- `L2`: stage floor plus task-type overlays.
- `L3`: add `security`, `compliance`, and `observability`, require `risk_priority_matrix`, and produce Human Approval decision input.
- `L4`: add `security`, `compliance`, `privacy_ethics`, `devops_sre`, `observability`, and `platform`, require adversarial/risk/conflict modes, and produce Human Approval decision input.

Project overrides may add teams, member count, or modes. They must not go below the full package minimum, remove task-type overlays, or remove risk overlays. Coverage-lowering changes require Human Approval as Debate Configuration Changes.

Member selection must choose at least one member from every selected team, then fill the stage minimum member count. Scoring uses member `dimension_refs`, `checklist_refs`, and focus text against task-type tags and affected scopes. Ties are broken by registry order so assembly is reproducible and testable.

Debate Audit Trail must record `assembly_policy_ref`, `assembly_input`, `matched_assembly_rules`, `risk_overlay_applied`, `task_type_overlays_applied`, `project_overrides_applied`, selected and skipped teams, selected members, and member scoring summaries.

Debate Coverage Policy is package configuration, not engine constants.

Minimum coverage must be configured for at least:

- `direction_debate`
- `solution_debate`
- `global_evaluation`

### 5.9 Failures, Partial Reports, and Conflicts

If member invocation failures still leave Debate Coverage Policy satisfied, the engine may write a Partial Debate Report. It must record failed members, degradation, retry attempts, and missing evidence.

If failures break required coverage, the stage becomes blocked and Kimi decides whether to retry, change backend, degrade, or escalate to the user.

Template fallback may only be used when configured. It must be recorded as degraded, cannot be treated as strong decision evidence, and never counts as required debate coverage.

Debate synthesis must preserve material disagreements as Debate Conflicts. Conflicts must record topic, positions, member/team ids, evidence refs, and whether Kimi must decide.

### 5.10 Debate Audit

Every Debate Run must write:

- Debate Report.
- Debate Audit Trail.

### 5.10.1 Debate Report Required Fields

A Debate Report artifact must contain at least:

- Identity fields: `schema_version`, `artifact_type: "debate_report"`, `debate_id`, `run_id`, `stage`, and `created_at`.
- Config fields: `package_ref`, `mode`, `coverage_policy_ref`, and `backend_policy_ref`.
- Assembly field: `assembly_policy_ref`.
- Input fields: `question`, `input_refs`, and `options`.
- Assembly fields: `selected_team_ids`, `selected_member_ids`, and `opinion_refs`.
- Coverage and degradation fields: `coverage_satisfied`, `required_coverage`, `missing_coverage`, `failed_invocation_refs`, `partial`, `degraded`, `degradation_status`, and `degradation_record`.
- Synthesis fields: `findings`, `risks`, `recommendations`, `conflicts`, `synthesis`, and `confidence`.
- Decision handoff fields: `verdict`, `requires_kimi_decision`, `authority_required`, `kimi_decision_inputs`, and `recommended_next_actions`.
- Traceability fields: `audit_trail_ref` and `artifact_refs`.

A Debate Report is a synthesis and decision input. It must not copy raw prompts or raw stdout. Complete member outputs remain linked through `opinion_refs`.

The MVP `debate_report` schema in `config/schemas/orchestra.schema.json` is a degraded local acceptance schema and must be upgraded for the Full Debate Package.

### 5.10.2 Debate Audit Trail

The Debate Audit Trail records package id, selected teams and members, assembly policy, matched assembly rules, backend policy, invocation refs, degraded state, retries, timing, and synthesis refs.

A Debate Audit Trail artifact must contain at least:

- Identity fields: `schema_version`, `artifact_type: "debate_audit_trail"`, `audit_id`, `debate_id`, `run_id`, `stage`, and `created_at`.
- Config snapshot fields: `package_ref`, `package_hash`, `teams_config_ref`, `modes_config_ref`, `coverage_policy_ref`, `assembly_policy_ref`, and `backend_policy_ref`.
- Assembly record fields: `assembly_reason`, `assembly_input`, `matched_assembly_rules`, `risk_overlay_applied`, `task_type_overlays_applied`, `project_overrides_applied`, `selected_team_ids`, `selected_member_ids`, `skipped_team_ids`, `member_selection_scores`, and `coverage_requirements`.
- Invocation records under `invocations`. Each invocation record contains `invocation_id`, `team_id`, `member_id`, `backend_id`, `input_ref`, `opinion_ref`, `status`, `started_at`, `finished_at`, `retry_count`, `degraded`, `degradation_status`, `degradation_record`, and `error_class`.
- Synthesis record fields: `report_ref`, `conflict_refs`, `synthesis_ref`, and `kimi_decision_input_ref`.
- Safety fields: `redaction_applied`, `secret_scan_status`, `raw_prompt_persisted: false`, and `raw_stdout_persisted: false`.

The Audit Trail records references, hashes, statuses, timestamps, and error classes. It must not persist full prompts, secrets, raw stdout, or long-form body text as durable audit content.

### 5.11 Debate Configuration Changes

Debate Configuration Changes include changes to teams, member personas, modes, coverage policy, routing, checklists, or backend policy.

Changes that lower coverage, alter canonical teams or modes, remove members, change backend policy, or affect approval/risk coverage require Human Approval. Stage 6 may propose them but must not apply them automatically.

## 6. Kimi-Audited Self Evolution

The full system uses Kimi-Audited Self Evolution.

Hermes may collect candidate learnings, repeated failures, checklist improvement ideas, skill candidates, routing improvements, worker configuration suggestions, and debate package issues.

Every successful Stage 6 runs a Stage 6 Candidate Evolution Sweep. The sweep writes `system_improvement_proposals` for the current run with `trigger_type: "stage_6_candidate_sweep"`, `source_scope: "single_run"`, `candidate_only: true`, and `auto_applied_refs: []`.

The sweep always writes the artifact, but `proposals` may be empty. Non-empty proposals require at least one conservative `trigger_matches` entry:

- `authority_chain_divergence`
- `worker_session_cleanup_failure`
- `schema_mismatch`
- `full_contract_validation_failure`
- `debate_required_coverage_failure`
- `debate_degraded_required_evidence`
- `same_failure_class_repeated`
- `review_or_qa_same_class_repeated`
- `decision_exposed_rule_or_doc_gap`

Kimi may manually request a Cross-Run Evolution Review when broader patterns across multiple runs need review. Cross-run review writes `system_improvement_proposals` with `trigger_type: "manual_cross_run_review"` and `source_scope: "cross_run"`. It may cite multiple source run ids and audit refs, but it still produces proposals rather than applying changes.

### 6.1 Self Evolution Review Queue

Self-evolution proposals enter an explicit review queue instead of immediately interrupting Kimi for every proposal.

The review queue policy lives at `config/evolution/self-evolution-review-queue.json` with `artifact_type: "self_evolution_review_queue_policy"`.

`system_improvement_proposals` must record `review_queue_required: true`, `review_queue_policy_ref`, and `queued_item_refs`. Empty proposal artifacts may have an empty `queued_item_refs` array. Non-empty proposal artifacts must enqueue review items.

Queue item states are:

- `queued`
- `batched`
- `under_review`
- `accepted`
- `rejected`
- `needs_more_evidence`
- `deferred`
- `superseded`
- `applied`

Priority is based on protected target class, severity, repeated failure count, evidence quality, source run count, and age. Low and medium non-protected proposals may be batched when they share review context. High and critical proposals are reviewed individually; critical proposals may interrupt. Protected target proposals must not be batched.

Protected targets include root rules, CI/CD, install scripts, risk policy, worker config, debate config, Gateway config, runtime config, release config, remote decision config, and full-contract cutover. They require Kimi review before Human Approval and can never auto-apply.

Rejected, deferred, superseded, accepted, and applied proposals are retained with decision refs, reasons, and audit refs. Rejected proposals are not deleted. Low-evidence proposals move to `needs_more_evidence` instead of being accepted.

Kimi audits run evidence before deciding what should be promoted, summarized, or changed.

The system must not automatically modify:

- Root `AGENTS.md`.
- Root `CLAUDE.md`.
- `hermes/SOUL.md`.
- CI/CD.
- Install scripts.
- Risk policy.
- Worker backend config.
- Debate routing config.
- Gateway or runtime config.
- Full Debate Package coverage or canonical sets.

Changes to high-risk or authority-impacting targets require Human Approval.

## 7. Worker Execution

Workers execute under Hermes Kanban through replaceable Worker Backends. Backends are selected through Worker Backend Registry, Worker Role Registry, and Capability Negotiation.

The full system requires:

- Structured Worker Context Envelopes.
- Scoped Worker Context Bundles.
- Explicit Worker Write Scope.
- Structured Worker Output Envelopes.
- Gateway Advancement Gate before State, Audit, or Kanban lifecycle advancement.
- Task-scoped Worker Workspace by default.
- Task-scoped ephemeral Tmux Worker Session for real worker execution or observation.
- Gateway Worker Session Sweeper for startup and periodic cleanup of timed-out, missing, or abandoned sessions.

Direct Project Fallback is allowed only as an explicit low-risk single-worker downgrade. It cannot be used for parallel work, release/deploy work, security work, rule changes, or authority-impacting configuration changes.

Tmux transcripts are useful evidence context but not completion authority.

### 7.0 Worker Registry and Capability Negotiation

The full-system Worker Backend Registry is staged at `config/workers/full/backends.json`. The full-system Worker Role Registry is staged at `config/workers/full/roles.json`. The root `config/workers/backends.json` and `config/workers/roles.json` remain MVP/current runtime configs until worker cutover.

Worker Backend Registry entries must declare at least:

- backend id and display name;
- adapter type and transport;
- enabled state;
- install check and health check;
- compatible roles;
- supported protocols;
- capabilities;
- workspace and session support;
- risk ceiling; and
- whether that backend may be used as a fallback.

Worker Role Registry entries must declare at least:

- role id;
- protocol;
- required capabilities;
- preferred backend;
- explicit fallback backends;
- fallback-allowed failure classes;
- fallback-forbidden conditions; and
- that selection records and negotiation reports are required.

Capability Negotiation validates a requested or default backend against the role registry, backend registry, current availability, required capabilities, protocol compatibility, workspace/session requirements, risk ceiling, and fallback policy.

A backend risk ceiling only states the maximum risk class the backend may execute after required approvals. It does not bypass L3/L4 Human Approval or forbidden automatic modification boundaries.

If Kimi requests a backend that is unknown, disabled, unavailable, role-incompatible, missing required capabilities, above its risk ceiling, or unable to satisfy workspace/session requirements, Gateway must not silently substitute another backend. Gateway writes or returns a `capability_negotiation_report` and blocks for Kimi decision unless an explicit fallback path is allowed.

Fallback may be selected only when all of the following are true:

- the role registry lists the fallback backend explicitly;
- the fallback backend is enabled, available, role-compatible, and capability-compatible;
- the failure class is in `fallback_allowed_failure_classes`;
- none of the role's `fallback_forbidden_when` conditions match; and
- the task is not parallel work, release/deploy work, security work, rule-change work, authority-impacting configuration work, or L3/L4 work.

Every backend selection writes a `worker_selection_record` with requested backend, selected backend, matched capabilities, adapter type, fallback status, attempt, negotiation status, and blocked reason. Blocked negotiations must link a `capability_negotiation_report`.

### 7.1 Tmux Worker Session Lifecycle

The full-system Tmux Worker Session lifecycle is:

`planned -> starting -> running -> stopping -> completed|failed|timed_out|abandoned`

Each real worker execution creates one task-scoped ephemeral Tmux Worker Session. Project-permanent Codex or Claude shells may exist for legacy or local MVP operation, but they are not the full-system default.

Every real worker execution must write a `worker_session_record` artifact with at least:

- `session_id`
- `run_id`
- `task_id`
- `role`
- `backend_id`
- `workspace_ref`
- `write_scope_ref`
- `context_bundle_ref`
- `started_at`
- `ended_at`
- `status`
- `exit_signal`
- `transcript_ref`
- `output_envelope_ref`
- `cleanup_owner`
- `cleanup_status`
- `timeout_seconds`
- `last_heartbeat_at`
- `termination_reason`

Tmux transcripts are short-lived cache or debug artifacts by default, with configurable TTL. Audit may record transcript hashes, transcript refs, key event summaries, and Worker Output Envelope refs, but full transcripts are not completion evidence.

Timeouts and interruption must record `timeout_seconds`, `last_heartbeat_at`, and `termination_reason`. Gateway Advancement Gate decides whether a timed-out or interrupted worker may retry, degrade, or block the run.

Completed, failed, timed-out, or abandoned sessions should be killed and cleaned up. The Gateway Worker Session Sweeper owns fallback cleanup, not the Worker Backend.

The Gateway Worker Session Sweeper runs at Gateway startup and on a periodic interval. It checks `worker_session_record` artifacts, actual tmux sessions, heartbeat timestamps, and timeout policy:

- `running` with expired heartbeat becomes `timed_out`, then the sweeper requests graceful stop.
- If graceful stop fails, the sweeper kills the tmux session and records `cleanup_status`, `termination_reason`, and cleanup timing.
- If a session record exists but the tmux session is missing, the sweeper marks the record `abandoned` or `failed` and writes audit evidence.
- If cleanup fails, the associated worker task becomes blocked. The broader run is not failed unless workspace or artifact integrity is also compromised.

### 7.2 Worker Workspace Parallel Merge and Review

Parallel worker execution is allowed only inside one Active Run and only when a Parallel Independence Policy explicitly declares it safe.

Each parallel child task must have an isolated Worker Workspace and explicit Worker Write Scope.

Before parallel execution starts, the system must write a `parallel_group_plan` artifact containing at least:

- `parallel_group_id`
- `task_ids`
- `workspace_refs`
- `write_scope_refs`
- `declared_conflict_locks`
- `merge_order`
- `review_gate`

Before merge, the system must run a `conflict_scan` that checks:

- Actual changed files are inside each worker's approved write scope.
- Changed files do not conflict across parallel workspaces.
- Declared conflict locks are respected.
- Authority-impacting files were not touched without the required approval.

`conflict_scan` is not a semantic compatibility proof. It must record `semantic_conflict_detection: "not_claimed"`. Behavioral or logical conflicts between parallel outputs are discovered by serial integration, configured tests, and review gates.

The default merge strategy is serial merge into an integration workspace according to `merge_order`. After each merge, the system runs the configured tests and review gate for that task or group.

If conflicts are detected, the system must not auto-arbitrate them. It writes a `merge_conflict_report` with `semantic_conflict_detection: "not_claimed"` and Kimi decides whether to reorder the merge, narrow scope, dispatch a repair task, or request Human Approval.

Direct Project Fallback is forbidden for parallel worker tasks.

## 8. Optional Adapters

The following are optional and disabled unless configured:

- Redis Cache Adapter.
- GSD Workflow Methodology Adapter.
- Remote Decision Channel.
- External design-source retrieval or import tooling.

Redis remains a cache adapter only. It must not become canonical state.

GSD may specialize a Six-Stage Run for projects using GSD, but the core workflow must run without GSD commands.

Remote Decision Channel may send approval requests and receive user responses when configured. Local CLI/SSH decision flow remains the default when no remote channel is configured.

Get笔记 `qnN4o510` remains a requirements and design knowledge source, not a runtime dependency or Runtime Domain Knowledge Base.

### 8.1 Remote Decision Channel Adapter Contract

Remote Decision Channel is disabled by default. Local CLI/SSH decision flow remains the default path unless a remote channel is explicitly configured.

Remote channel configuration lives at `config/decisions/remote-channel.json` and contains at least:

- `enabled`
- `channel_type`
- `adapter_id`
- `delivery_policy`
- `response_policy`
- `security_policy`
- `audit_policy`

Remote decision delivery sends a `decision_request` artifact with at least:

- `decision_id`
- `run_id`
- `task_id`
- `authority_required`
- `risk_level`
- `question`
- `options`
- `required_phrase`
- `expires_at`
- `artifact_refs`

Remote decision intake records a `decision_response` artifact with at least:

- `decision_id`
- `response_id`
- `responder_id`
- `decision`
- `rationale`
- `received_at`
- `channel_message_ref`
- `signature_or_proof_ref`

Remote channels only transport user decisions. They must not directly mutate workflow state. Gateway validates the response, replay protection, expiry, responder binding, and required phrase before advancing state.

L4 or high-risk approvals must preserve a fixed phrase or equivalent strong confirmation mechanism. Timeout approval, agent approval, and default approval are forbidden.

Audit must record delivery status, response binding, replay protection, expiry, `used_at`, and audit refs.

## 9. Release Pipeline

The full system includes a Release Pipeline.

The default logical path is:

`dev/test -> staging -> production`

The production target is project-defined. It may be a local service, internal service, container, static site, remote server, or project command. Public internet production is not required by the core spec.

Release evidence must include:

- Deployment gates.
- Test and validation results.
- UAT decision.
- Production approval when production is configured.
- Rollback or recovery evidence.
- Structured deployment report.

### 9.1 Release Pipeline Configuration

Release Pipeline project configuration lives at `config/release/pipeline.json` with `artifact_type: "release_pipeline_config"`.

The root configuration must contain at least:

- `schema_version`
- `artifact_type`
- `enabled`
- `project_target_type`
- `command_registry_ref`
- `environments`
- `gates`
- `commands`
- `approval_policy`
- `rollback_policy`
- `evidence_requirements`

Each environment entry must contain:

- `id`
- `kind`
- `target_ref`
- `deploy_command_ref`
- `health_check_refs`
- `requires_approval`

Release gates must include:

- `pre_deploy_checks`
- `staging_validation`
- `uat`
- `production_approval`
- `post_deploy_validation`

Commands store command references that must resolve through the trusted Release Command Registry at `config/release/commands.json`. Arbitrary shell strings are not trusted release configuration by themselves.

Rollback policy must include `rollback_command_ref`, `rollback_checkpoints`, and `recovery_evidence_required`.

Release evidence requirements must include `deployment_report_ref`, `test_execution_report_refs`, `uat_decision_ref`, `approval_refs`, and `rollback_or_recovery_refs`.

Production may be a local service, internal service, container, static site, remote server, or project command. Public internet production is not required, but staging validation, UAT, approval, and rollback or recovery evidence remain release completion requirements.

### 9.2 Release Command Registry

Release command definitions live at `config/release/commands.json` with `artifact_type: "release_command_registry"`.

The registry is disabled until release implementation cutover, but it is still the full target contract for `deploy_command_ref` and `rollback_command_ref` resolution.

Each command entry must define:

- `command_ref`
- `enabled`
- `argv`
- `cwd_ref`
- `env_allowlist`
- `timeout_seconds`
- `kill_policy`
- `output_capture_policy`
- `redaction_policy`
- `approval_policy`

Command entries are argv arrays, not shell strings. The Gateway Release Executor resolves the command ref, validates approvals, builds the allowed environment, starts the process, captures output to artifact refs, applies redaction, and writes the deployment report.

The registry must set `arbitrary_shell_allowed: false`. Workers, Debate Backends, and Kimi do not execute release commands directly.

### 9.3 Release Execution And Reports

Staging and production command execution requires approval refs before process start. Production approval is always Human Approval and requires the configured fixed phrase or equivalent strong confirmation mechanism.

If a release command exceeds `timeout_seconds`, the Gateway Release Executor sends the configured graceful signal, waits the graceful timeout, then sends the configured force signal. The deployment report records `deployment_status: "timed_out"`, timing fields, timeout fields, kill policy, output refs, and any partial health-check refs. The run is blocked for Kimi or Human repair decision. Gateway must not assume rollback succeeded unless a separate rollback command execution writes its own schema-valid deployment report and rollback or recovery evidence.

`deployment_report` must record `command_ref`, `command_registry_ref`, `executor`, `argv_hash`, `stdout_ref`, `stderr_ref`, `exit_code`, `started_at`, `finished_at`, `duration_ms`, `timeout_seconds`, `timed_out`, `kill_policy`, `health_check_refs`, gate results, test report refs, approval refs, rollback or recovery refs, and creation time. Raw stdout or stderr must not be embedded in Audit, Events, Kanban tasks, or report bodies; durable records carry refs, hashes, exit code, and timing metadata.

## 10. Acceptance Criteria

The full system is acceptable when it can demonstrate:

- Kimi creates and supervises a Six-Stage Run without raw Kanban CRUD.
- Gateway runs as the project-local Python HTTP service described by the Gateway Runtime Contract, with JSON Run Projection operations and local filesystem authority stores as the baseline.
- Idempotency records are retained with Gateway State without independent TTL and cannot expire before the authority side effects they protect.
- Degradation is modeled as artifact, backend, projection, or evidence state, not as Run status.
- Get笔记 `qnN4o510` is used as design reference but not runtime authority.
- A Full Debate Package exists with sixteen canonical teams and at least three member personas per team.
- The canonical eight debate modes are used without legacy aliases.
- Dynamic Debate Assembly deterministically selects a stage-appropriate subset from the full package using the assembly policy.
- Debate Coverage Policy is read from package config.
- Every member invocation writes schema-valid Debate Member Opinion.
- Debate Report preserves per-member outputs, Debate Conflicts, recommendations, and Kimi decision inputs.
- Debate Audit Trail records package, team, member, backend, invocation, retry, degraded, and synthesis refs.
- Kimi Decision, not Debate Report, advances low/medium-risk stages.
- Human Approval gates high-risk and authority-impacting changes.
- Kimi-Audited Self Evolution writes candidate proposals into an explicit review queue and does not automatically apply authority-impacting changes.
- Worker Backend Registry and Worker Role Registry use staged full target configs, explicit capability negotiation, and no implicit backend fallback.
- Real worker execution uses task-scoped Worker Workspace and Tmux Worker Session.
- Run-internal parallelism requires Parallel Independence Policy.
- Direct Project Fallback is limited to explicit low-risk single-worker downgrade.
- Redis, GSD, and Remote Decision Channel remain optional adapters.
- Release Pipeline resolves deploy and rollback commands through the trusted Release Command Registry, executes them through the Gateway Release Executor, and records schema-valid deployment reports with timeout, kill, output-ref, approval, health-check, rollback, and recovery evidence.
- Performance policy records component budgets and degradation actions without promising fixed Six-Stage Run completion time.
- Fixture policy separates contract fixtures from runtime fake adapters and forbids fixtures from satisfying completion, approval, release, or strong evidence gates.

## 11. Current Open Design Branches

No open grill branches remain before implementation planning. Remaining items in the coverage matrix are implementation gaps or adapter plans, not unresolved design decisions.

## 11.1 Runtime Domain Knowledge Base

The Runtime Domain Knowledge Base is a project-owned runtime retrieval capability for specialized domain knowledge. The first target backend is gbrain.

The gbrain-first decision means:

- Runtime domain knowledge is stored in a local gbrain brain, using gbrain's default PGLite engine unless a later approved migration chooses another gbrain engine.
- Hermes integrates through gbrain CLI and/or MCP adapter surfaces.
- Hermes does not build or maintain a separate SQLite runtime knowledge base when gbrain is available. PGLite is gbrain's internal storage engine choice, not a Hermes-level SQLite design option.
- Get笔记 `qnN4o510` remains an external requirements and design source and is not queried at runtime.

The runtime knowledge base must support domain material such as WeChat Mini Program development, cloud development constraints, platform API limits, review rules, provider-specific gotchas, and recurring implementation pitfalls.

### 11.1.1 Runtime Knowledge Entry Schema

Each Runtime Domain Knowledge Base entry is a gbrain markdown page with YAML frontmatter. Hermes must not create separate custom database tables for runtime domain knowledge.

Slug format:

`domain/<domain>/<topic>/<short-id>`

Example:

`domain/wechat-miniprogram/cloud-functions/request-domain-boundary`

Required frontmatter fields:

- `type`
- `domain`
- `topic`
- `source_type`
- `source_refs`
- `confidence`
- `freshness`
- `valid_from`
- `last_verified_at`
- `tags`
- `owner`

Required body sections:

- `Claim`
- `Context`
- `Applies When`
- `Does Not Apply When`
- `Evidence`
- `Operational Guidance`
- `Failure Modes`
- `Review Checklist`

Use gbrain typed links for relationships such as `depends_on`, `supersedes`, `contradicts`, and `same_platform_area`.

Unverified material enters as `candidate_knowledge`. It may only be promoted to `domain_knowledge` after verification.

### 11.1.2 Runtime Knowledge Ingestion Policy

Runtime knowledge ingestion must follow gbrain's CLI and MCP usage model rather than a custom database writer.

Allowed source classes:

- Official documentation.
- Code or SDK examples.
- Platform rules and review requirements.
- Project test or production observations.
- Human expert entries.
- Reviewed summaries from external notes.

Forbidden direct promotion sources:

- Model chat conclusions without source evidence.
- Unverified blog summaries.
- Raw Get笔记 note copies.
- Stale platform rules.

Ingestion states:

- `candidate_knowledge`: unverified or partially verified material.
- `domain_knowledge`: verified material allowed in runtime retrieval.

Promotion to `domain_knowledge` requires `source_refs`, `last_verified_at`, `confidence`, applicability boundaries, non-applicability boundaries, evidence, and review checklist.

Concrete gbrain operations:

- Use `gbrain put <slug> --content <markdown-with-frontmatter>` or the MCP `put_page` tool to create or update one entry.
- Use `gbrain import <dir>` only for curated markdown directories whose files already follow the Runtime Knowledge Entry schema.
- Use `gbrain sync --repo <path>` only for approved repository-backed knowledge directories.
- Use `gbrain link <from> <to> --link-type <type>` or the MCP `add_link` tool for typed relationships.
- Use `gbrain query <question>` or the MCP `query` tool for hybrid retrieval.
- Use `gbrain report --type knowledge-ingestion --title ... --content ...` or an equivalent MCP/report path for ingestion audit records.
- Use `gbrain serve` only as the MCP server surface, not as an independent authority path.

Every promotion, overwrite, supersession, or deprecation must create a `knowledge_ingestion_record` through gbrain report or an equivalent audited artifact. The record includes source refs, verification method, operator, timestamp, affected slugs, and resulting status.

Platform, SDK, API, and policy entries must define a re-verification cadence. Expired entries cannot serve as strong evidence; they may only be returned as warning-context retrieval.

### 11.1.3 Runtime Knowledge Retrieval Contract

Hermes and Gateway retrieve runtime domain knowledge through gbrain CLI or MCP. The default retrieval mode is gbrain hybrid query.

Runtime knowledge queries are represented by a `runtime_knowledge_query` artifact with at least:

- `query_id`
- `run_id`
- `task_id`
- `domain`
- `question`
- `allowed_types`
- `required_freshness`
- `max_results`
- `evidence_scope`

Runtime knowledge results are represented by a `runtime_knowledge_result` artifact with at least:

- `query_id`
- `backend: "gbrain"`
- `result_refs`
- `slugs`
- `titles`
- `snippets`
- `confidence`
- `freshness_status`
- `source_refs`
- `warnings`
- `created_at`

Default retrieval returns only `domain_knowledge`. `candidate_knowledge` may only be returned in explicit research or debate modes and must carry warnings.

Expired entries cannot serve as strong evidence. They may only be returned as warning-context retrieval.

Workers and debate members may cite runtime knowledge results, but retrieval results are not final authority. Critical conclusions still require source refs, tests, official documentation, or human approval when relevant.

For platform, SDK, API, and policy questions, the result must expose `last_verified_at` and `source_refs`. Without those fields, the result is blocked from strong-evidence use.

### 11.1.4 Runtime Knowledge Freshness, Provenance, Redaction, and Audit

Runtime knowledge freshness policy:

- `platform_policy`, `sdk_api`, and `cloud_runtime` entries default to 30-day re-verification.
- `project_observation` entries default to 90-day re-verification.
- `conceptual_pattern` entries default to 180-day re-verification.
- Expired entries are downgraded to warning-context retrieval.

Runtime knowledge provenance policy:

- Every `domain_knowledge` entry must include `source_refs`, `source_type`, `last_verified_at`, and `verification_method`.
- Official documentation and project test or production observations outrank blogs and external-note summaries.
- External-note summaries may guide research, but they are not sufficient provenance for strong evidence.

Runtime knowledge redaction policy:

- Entries must not persist secrets, tokens, personal data, customer data, or sensitive internal path details.
- If source material contains sensitive content, store only a redacted summary plus source hash or source ref.

Runtime knowledge audit policy:

- Every promotion from `candidate_knowledge` to `domain_knowledge`, overwrite, deprecation, and failed re-verification writes a `knowledge_ingestion_record`.
- Every runtime lookup writes `runtime_knowledge_query` and `runtime_knowledge_result` artifacts so later audit can replay what knowledge was available and how it was interpreted.

Evidence boundary:

- gbrain retrieval is not final fact authority.
- Critical platform, API, SDK, policy, compliance, release, or security conclusions must trace to official sources, test evidence, production observations, or Human Approval where required.
- Kimi and humans may cite gbrain results, but gbrain results cannot bypass Human Approval.

## 12. Draft Default Debate Members

This section records the confirmed default member personas for the Full Debate Package. Each canonical team must eventually have at least three member personas.

### 12.1 `security`

- `threat_modeler` — Finds attack paths, authority-boundary failures, abuse cases, and privilege escalation risks.
- `secrets_auditor` — Checks API keys, tokens, credentials, logs, and configuration for leakage risk.
- `policy_guardian` — Decides whether a proposal triggers L3/L4, Human Approval, forbidden automation, or risk-policy blocking.

### 12.2 `compliance`

- `legal_reviewer` — Reviews laws, contracts, platform terms, and industry compliance boundaries.
- `internal_policy_reviewer` — Checks consistency with project rules, AGENTS, SOUL, Harness, and approval policy.
- `ethics_reviewer` — Reviews fairness, misleading automation, user harm, and ethical risk.

### 12.3 `data_engineering`

- `pipeline_reliability_reviewer` — Reviews data flows, batch or sync paths, retries, idempotency, and recovery.
- `data_quality_reviewer` — Reviews data correctness, completeness, consistency, dirty data, and validation rules.
- `data_architecture_reviewer` — Reviews data models, storage boundaries, scalability, query patterns, and index structure.

### 12.4 `devops_sre`

- `deployment_pipeline_reviewer` — Reviews deployment pipelines, environment tiers, release gates, and rollback paths.
- `slo_reliability_reviewer` — Reviews availability, SLOs, failure recovery, and runtime health.
- `automation_iac_reviewer` — Reviews automation scripts, IaC, permission boundaries, and repeatable deployment.

### 12.5 `frontend`

- `ux_flow_reviewer` — Reviews user flows, interaction paths, information architecture, and understandability.
- `frontend_performance_reviewer` — Reviews first paint, rendering performance, asset weight, and response speed.
- `compatibility_accessibility_reviewer` — Reviews browser and device compatibility, accessibility, and responsive adaptation.

### 12.6 `ai_feature`

- `model_fit_reviewer` — Reviews model suitability, capability boundaries, cost-quality fit, and fallback choices.
- `prompt_contract_reviewer` — Reviews prompt structure, input constraints, output format, and schema alignment.
- `human_ai_interaction_reviewer` — Reviews human-AI collaboration paths, explainability, confirmation points, and misuse risk.

### 12.7 `business`

- `value_reviewer` — Checks whether the work serves the intended outcome instead of optimizing for technical novelty.
- `cost_reviewer` — Reviews token, API, runtime, time, and maintenance cost, especially against the cost-control logic in `qnN4o510`.
- `acceptance_reviewer` — Checks whether acceptance criteria are judgeable, executable, and deliverable.

### 12.8 `platform`

- `platform_architecture_reviewer` — Reviews platform architecture, system boundaries, and composition of core platform capabilities.
- `maintainability_reviewer` — Reviews maintainability, module complexity, and long-term evolution cost.
- `infrastructure_fit_reviewer` — Reviews infrastructure fit, runtime constraints, and upstream Hermes, Gateway, and Kanban boundaries.

### 12.9 `privacy_ethics`

- `data_privacy_reviewer` — Reviews personal information, sensitive data, data minimization, retention, and deletion boundaries.
- `ai_ethics_reviewer` — Reviews fairness, bias, transparency, explainability, and misleading model output risk.
- `content_safety_reviewer` — Reviews content moderation, abuse scenarios, user harm, and platform content risk.

### 12.10 `scalability_arch`

- `capacity_planning_reviewer` — Reviews performance and capacity planning, load growth, throughput, and latency budgets.
- `horizontal_scaling_reviewer` — Reviews horizontal scaling, partitioning and concurrency boundaries, statelessness, and expansion paths.
- `resource_efficiency_reviewer` — Reviews CPU, memory, storage, API, token cost, waste, and bottlenecks.

### 12.11 `chaos_engineering`

- `fault_injection_reviewer` — Reviews fault injection, failure scenarios, dependency exceptions, timeouts, and disconnect simulations.
- `resilience_reviewer` — Reviews recovery ability, degradation strategy, retries, circuit breakers, and state consistency.
- `blast_radius_reviewer` — Reviews failure impact scope, isolation boundaries, rollback or stop mechanisms, and worst-case control.

### 12.12 `oss_compliance`

- `license_compliance_reviewer` — Reviews open-source licenses, copyright, and redistribution constraints.
- `dependency_security_reviewer` — Reviews dependency vulnerabilities, supply-chain risk, versioning, and source trust.
- `sbom_provenance_reviewer` — Reviews SBOM, component provenance, dependency inventory, and audit evidence.

### 12.13 `observability`

- `monitoring_alerting_reviewer` — Reviews monitoring coverage, alert thresholds, false positives or negatives, and on-call actionability.
- `tracing_reviewer` — Reviews distributed tracing, request and task correlation, and cross-component causal diagnosis.
- `logging_metrics_reviewer` — Reviews log structure, metric standards, retention policy, and audit or debugging usefulness.

### 12.14 `documentation`

- `coverage_reviewer` — Reviews documentation coverage, missing topics, and required user or operator paths.
- `accuracy_reviewer` — Reviews factual accuracy, terminology consistency, and alignment with code, configuration, and ADRs.
- `maintainability_docs_reviewer` — Reviews documentation structure, update cost, maintainability, and stale-content risk.

### 12.15 `api_design`

- `contract_versioning_reviewer` — Reviews API contracts, versioning, compatibility, and breaking-change boundaries.
- `api_security_rate_limit_reviewer` — Reviews authentication, authorization, security boundaries, rate limits, and abuse protection.
- `developer_experience_reviewer` — Reviews API usability, error semantics, examples, SDKs, and debugging affordances.

### 12.16 `i18n_l10n`

- `translation_completeness_reviewer` — Reviews translation coverage, missing strings, and consistency across languages.
- `locale_format_reviewer` — Reviews localized dates, numbers, currency, units, time zones, and locale-specific formatting.
- `rtl_multilingual_reviewer` — Reviews RTL support, text expansion, multilingual layouts, and input boundaries.
