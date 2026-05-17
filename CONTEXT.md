# Hermes Orchestra

Hermes Orchestra is a local AI engineering workflow that lets an external orchestrator supervise a Hermes-backed execution pipeline without forking upstream Hermes-Agent.

## Language

**Kimi**:
The external upper orchestrator that interprets intent, supervises progress, accepts results, and audits experience.
_Avoid_: embedding Kimi logic inside the Hermes execution core

**Gateway Adapter**:
The project-local API layer that exposes workflow-run operations to Kimi and translates them into Hermes execution activity.
_Avoid_: raw Kanban API, upstream fork

**Gateway Runtime Contract**:
The full-system implementation contract that keeps the Gateway as a project-local Python HTTP service exposing JSON Run Projection operations, optional `/v1/*` upstream proxying, and local filesystem-backed Gateway State, Audit, Events, command journals, and idempotency records.
_Avoid_: upstream Hermes fork, shared database as default, raw Kanban API surface

**Run Projection API**:
The product-level Gateway API surface that lets Kimi create, inspect, stop, and decide Six-Stage Runs without operating the Kanban board directly.
_Avoid_: task CRUD API

**Idempotency Key**:
A caller-provided key that makes a mutating Run Projection API command safe to retry without duplicating workflow side effects.
_Avoid_: correlation id, event id

**Idempotency Record**:
The Gateway State record keyed by project, endpoint, resource path, and Idempotency Key that stores payload hash, Command ID, command result, retention policy, and retry metadata.
_Avoid_: cache entry, memory-only replay guard, expiring lock

**Idempotency Retention Rule**:
The rule that an Idempotency Record is retained with Gateway State and has no independent TTL, so it cannot disappear before the authority side effect it protects.
_Avoid_: cache TTL, key reuse after archive, retry window

**Command ID**:
The Gateway-assigned identifier for one accepted mutating command, recorded on State, Audit, and Events.
_Avoid_: run id, task id

**Command Journal**:
The write-ahead Gateway State record that stores an accepted command intent and recoverable execution steps before side effects are applied.
_Avoid_: audit trail, cache entry

**Command Reconciliation**:
The startup recovery process that resolves unfinished Command Journal entries from Gateway State, Audit, Hermes Kanban, and artifact refs.
_Avoid_: blind replay

**Command Reconciliation Report**:
The audited recovery artifact that records Command Journal, Gateway State, Audit, Hermes Kanban, and artifact observations plus blocked repair options for an unfinished command.
_Avoid_: blocked status only, synthetic audit record

**Authority Chain Divergence**:
A recovery-time mismatch among Gateway State, Audit, Hermes Kanban, and artifact refs that blocks automatic command completion or replay until Kimi decides the repair path.
_Avoid_: projection inconsistency, harmless event gap, auto-repaired audit

**Gateway Event**:
A run-scoped append-only progress entry exposed to Kimi through JSON polling or SSE.
_Avoid_: audit record, state transition authority

**Event Store**:
The Gateway State-backed append-only storage for Gateway Events, such as the run's `events.jsonl`.
_Avoid_: audit artifact, cache object

**Event Retention**:
The MVP rule that the Event Store is retained with run State without TTL, truncation, or per-event compaction.
_Avoid_: cache TTL, log rotation

**Event Emission Gate**:
The Gateway check that appends a Gateway Event only after the State, Audit, Kanban, or artifact change it reports is durable.
_Avoid_: pre-commit notification, optimistic status

**Event Projection**:
The recoverable Gateway view of run progress derived from Gateway State, Audit, Hermes Kanban, and artifact references.
_Avoid_: immutable evidence trail, completion proof

**Projection Inconsistency**:
A gap, duplicate, stale, corrupt, or unverifiable Event Projection condition that requires client resync or projection rebuild.
_Avoid_: run failure, workflow blocker

**Projection-Degraded Command Result**:
A successful mutating command response whose authority changes are durable but whose Event Projection needs repair or rebuild.
_Avoid_: command failure, retry trigger

**Degradation Status**:
The artifact, backend, projection, or evidence quality state: `normal`, `degraded`, `recovered`, or `blocked_due_to_degradation`.
_Avoid_: Run status, terminal failure, generic warning

**Degradation Record**:
The structured explanation attached to degraded or recovered evidence, including class, cause, affected evidence refs, decision requirement, recovery options, acceptance ref, and completion-evidence policy.
_Avoid_: boolean-only degraded marker

**Degradation Policy**:
The project policy that defines degradation state transitions, default completion-evidence denial, artifact-family exceptions, and replacement-evidence recovery requirements.
_Avoid_: hidden per-artifact exception, degraded evidence as automatic completion proof

**Event Sequence**:
The per-run monotonic `seq` used by Gateway Events and `since_seq` subscriptions to detect gaps.
_Avoid_: global ordering, command id

**Official Hermes API Server**:
The upstream OpenAI-compatible Hermes HTTP server that may run behind the Gateway Adapter for `/v1/*` traffic.
_Avoid_: product workflow API, six-stage run authority

**Hermes Execution Framework**:
The lower execution layer made of Gateway, Hermes-Agent, Kanban, profiles, workers, and evidence plumbing that carries out Kimi-supervised runs.
_Avoid_: top-level product orchestrator, Hermes Agent Master

**Workflow Methodology Adapter**:
An optional adapter that maps a specific development methodology into the Six-Stage Run without becoming part of the core workflow authority.
_Avoid_: required runtime dependency, replacement top-level workflow

**Six-Stage Run**:
One end-to-end R&D loop composed of direction debate, solution debate, implementation, improvement, global evaluation, and continuous improvement.
_Avoid_: treating `pm -> implementer -> reviewer -> qa` as the top-level workflow

**Active Run**:
A Six-Stage Run that is queued, running, or blocked for a project.
_Avoid_: same-project parallel workflow runs

**Blocked Run**:
An Active Run that is waiting on required decision, repair, or external evidence before it can continue.
_Avoid_: terminal failure, partial completion

**Failed Run**:
A terminal Six-Stage Run whose workflow authority or evidence chain is no longer safe to continue in place.
_Avoid_: ordinary blocked work, failed test

**Stopped Run**:
A terminal Six-Stage Run intentionally halted by a stop request while preserving its workflow evidence.
_Avoid_: cancelled cleanup, rejected run

**Failure Boundary**:
The rule that escalates a run from blocked to failed only when Gateway, State, Audit, Kanban, or critical artifact integrity is unrecoverable.
_Avoid_: retry limit, reviewer rejection

**Last Good Checkpoint**:
The latest trusted State, Audit, Kanban, and artifact reference set that can seed a future lineage run.
_Avoid_: cache snapshot, model summary

**Terminal Run**:
A Six-Stage Run whose status is completed, failed, or stopped and whose workflow state is no longer mutated for continuation in MVP.
_Avoid_: in-place resume target

**Revision Attempt**:
A revised child task or stage attempt created inside a Blocked Run without overwriting the original evidence.
_Avoid_: artifact overwrite, hidden retry

**Run Lineage**:
The audited relationship from a new Six-Stage Run to source run evidence used to seed the new run.
_Avoid_: mutating the source run

**Run-Internal Parallelism**:
Limited parallel execution inside one Six-Stage Run for independent debate or non-overlapping child tasks.
_Avoid_: merge arbitration

**Parallel Independence Policy**:
The run-level rule that proves which tasks may execute concurrently by declaring non-overlapping write scopes, workspaces, locks, and merge or review gates.
_Avoid_: optimistic same-project parallel editing

**Conflict Scan**:
The pre-merge mechanical and authority-boundary check for parallel worker outputs, covering write scope, overlapping files, declared locks, and protected authority files.
_Avoid_: semantic compatibility proof, full correctness review

**Semantic Conflict Boundary**:
The rule that logical compatibility between parallel worker outputs is validated by serial integration tests and review gates, not by Conflict Scan alone.
_Avoid_: claiming diff scan proves behavior compatibility

**Structured Ticket**:
The validated intake contract that states background, goal, deliverables, acceptance criteria, constraints, related tasks, and failure strategy before execution begins.
_Avoid_: short intent as execution-ready work

**Structured PRD**:
The run-scoped artifact produced from a Structured Ticket or clarification loop that gates entry into the Six-Stage Run.
_Avoid_: optional documentation

**MVP Runtime Schema**:
The current executable schema contract used by the MVP or current runtime while the full system is not yet implemented.
_Avoid_: full-system acceptance schema

**Full Schema Package**:
The parallel human-readable and machine-readable schema contract that defines full-system acceptance without replacing the MVP Runtime Schema before implementation cutover.
_Avoid_: overwriting current runtime schema, hidden migration

**Full Schema Guardrail Boundary**:
The validation boundary that strictly checks identity, authority, routing, evidence, degradation, freshness, and forbidden persistence surfaces while leaving deep content bodies structurally typed but not over-specified in the first full schema version.
_Avoid_: free-form artifact, fully rigid content model

**Full Schema Coverage Set**:
The first Full Schema Package artifact set required to verify full-system acceptance across Gateway authority, Six-Stage evidence, Full Debate Package, Worker execution, Runtime Domain Knowledge Base, Release, and decisions.
_Avoid_: only-new-artifacts schema, exhaustive implementation-internal schema

**Full Target Coverage Matrix**:
The readiness matrix for full-system target contracts, configs, and implementation status, kept separate from the current MVP implementation coverage matrix.
_Avoid_: mixing current runtime coverage with full target readiness

**Capability Authority Matrix**:
The full-target actor capability map that separates request, decision, approval, execution, and state-advancement authority across Kimi, Human, Gateway, and Worker or Backend actors.
_Avoid_: flat yes/no permission list

**Full Contract Validation Harness**:
The independent validation path that checks the Full Schema Package and staged full-system configs without making them active Gateway runtime validators.
_Avoid_: runtime cutover, schema existence as capability proof

**Full Contract Validation Tool**:
The concrete `scripts/bin/orch-full-contract-validate` command that validates the Full Schema Package, staged full configs, cross-config refs, and disabled formal config state before runtime cutover.
_Avoid_: Gateway runtime validator, implementation proof

**Full Contract Readiness Gate**:
The artifact-family cutover gate that must pass before `orchestra.full.schema.json` can become a Gateway runtime validation target for that family.
_Avoid_: one-shot schema switch, replacing MVP validation without compatibility checks

**Artifact-Family Staged Cutover**:
The MVP-to-full migration model where each artifact family activates the Full Schema Package only after its own readiness gate passes.
_Avoid_: global full-schema switch, rewriting historical runs

**Gateway Full Runtime**:
The future runtime state where Gateway consumes full schema artifacts and full target configs as active validation and execution contracts.
_Avoid_: current MVP Gateway with full docs nearby

**Performance SLO Policy**:
The full-target performance contract that defines component target budgets, measurement rules, and budget-miss degradation actions without promising fixed Six-Stage Run duration.
_Avoid_: fixed run completion SLA, hiding backend or human wait time

**Continuous Improvement**:
The final stage of a Six-Stage Run that closes the iteration, audits what happened, and proposes future system improvements.
_Avoid_: automatic root rule-file mutation

**Global Evaluation**:
The Stage 5 independent audit that evaluates the full run evidence before closeout.
_Avoid_: implementer self-acceptance, skipped final audit

**Global Evaluation Report**:
A Stage 5 artifact that records final audit inputs, unresolved issues, verdict, and acceptance routing.
_Avoid_: informal final summary

**Final Acceptance**:
The Kimi or Human Approval decision that allows a run to proceed from Global Evaluation into Continuous Improvement and completion.
_Avoid_: automatic completion from worker or cache evidence

**Agent Run**:
An upstream Hermes execution session exposed through official `/v1/*` API surfaces.
_Avoid_: Six-Stage Run

**Hermes Kanban**:
The official Hermes task board that owns task lifecycle state, dependencies, assignment, blocking, and completion.
_Avoid_: simulated Kanban, local task store

**Task Projection**:
A read-only Gateway view of Kanban lifecycle data combined with Gateway State, Audit, and artifact references.
_Avoid_: task mutation endpoint

**Gateway State**:
The Gateway-owned runtime state that owns Orchestra workflow metadata such as run stage, artifact references, risk, approval, and resume policy.
_Avoid_: Kanban metadata for workflow metadata

**Local Filesystem Cache**:
The MVP cache backend under the local cache root that stores only rebuildable, non-authoritative results.
_Avoid_: canonical state, approval state, sensitive raw input

**Redis Cache Adapter**:
An optional cache backend that may replace the local cache through the same cache adapter interface for cost and latency optimization.
_Avoid_: required MVP dependency

**Audit**:
The immutable evidence trail for stage reports, decisions, retries, fallbacks, failures, and closeout. Audit is not reconstructed from Gateway Events.
_Avoid_: model self-report as completion proof

**Artifact Reference**:
A scoped URI that points to a state, audit, cache, or repository artifact without exposing an absolute local path.
_Avoid_: absolute paths in API responses

**State Artifact**:
A resumable run artifact that stores Gateway-owned runtime state, pending decisions, resume checkpoints, and artifact references.
_Avoid_: Kanban lifecycle state, cache object, completion proof

**Audit Artifact**:
An immutable evidence artifact that records stage reports, decisions, failures, downgrades, and closeout.
_Avoid_: mutable runtime state, rebuildable cache

**Cache Artifact**:
A rebuildable optimization artifact used to reduce repeated work without owning workflow authority.
_Avoid_: canonical state, approval state, completion evidence

**Repository Knowledge Artifact**:
A long-lived project knowledge artifact stored under `.workflow/knowledge/`.
_Avoid_: run-scoped requirement, raw ticket, temporary state

**Full-System Design Knowledge Source**:
A non-runtime reference source used to reconstruct requirements, complete system design, terminology, and architecture alignment.
_Avoid_: runtime dependency, runtime knowledge backend, state authority, completion evidence

**Runtime Domain Knowledge Base**:
A project-owned runtime knowledge capability for specialized domain knowledge, backed first by gbrain, with explicit storage, ingestion, retrieval, freshness, provenance, and audit policy.
_Avoid_: Get笔记 design source, personal notes, unversioned prompt memory, separate SQLite runtime KB

**Runtime Knowledge Entry**:
A gbrain markdown page with YAML frontmatter that records one specialized-domain claim, context, evidence, applicability, operational guidance, failure modes, and review checklist.
_Avoid_: raw clipped page, unverifiable chat conclusion, custom SQLite row

**Knowledge Ingestion Record**:
A gbrain report or equivalent audited artifact that records a runtime knowledge entry's source refs, verification method, operator, timestamp, affected slugs, and status change.
_Avoid_: silent promotion, untracked overwrite, chat-only rationale

**Runtime Knowledge Retrieval Result**:
A gbrain-backed retrieval artifact that records query inputs, matched slugs, snippets, confidence, freshness, source refs, warnings, and evidence-use boundaries.
_Avoid_: final authority, unstamped memory, source-less answer

**Runtime Knowledge Freshness Policy**:
The re-verification policy that determines when runtime domain knowledge can be used as strong evidence and when it must downgrade to warning context.
_Avoid_: permanently trusted platform memory, stale SDK rule, unverified policy claim

**qnN4o510 Knowledge Synthesis**:
The repository-local synthesis of Get笔记 `qnN4o510` used to trace which external knowledge shaped this spec.
_Avoid_: runtime KB, authority-chain evidence, complete mirror of private notes

**Run Completion Evidence**:
The combined proof from Hermes Kanban lifecycle, Gateway State, Audit, and schema-valid required artifacts that a Six-Stage Run is complete.
_Avoid_: cache hit, model self-report

**Debate Report**:
A structured decision-input artifact produced by the debate engine for a workflow stage.
_Avoid_: final decision, user approval

**Debate Engine**:
The decision engine that runs configured debate teams and modes to produce Debate Reports for direction, solution, risk, and global evaluation stages.
_Avoid_: optional reviewer prompt, single-model self-justification

**Debate Team Configuration**:
A config-defined expert group containing member personas, rubrics, output requirements, and optional skill references.
_Avoid_: long-running Hermes agent, hard-coded team logic

**Full Debate Package**:
The complete debate configuration package that keeps the qnN4o510 registry shape: sixteen canonical teams, each with at least three member personas, plus mode routing.
_Avoid_: low-cost package, partial team registry

**Staged Full Debate Config**:
The concrete Full Debate Package target configuration stored beside the legacy runtime debate registry until full implementation cutover.
_Avoid_: replacing MVP runtime config early, schema-only target

**Canonical Debate Team Set**:
The qnN4o510 registry-authoritative full-system set of sixteen debate teams: security, compliance, data_engineering, devops_sre, frontend, ai_feature, scalability_arch, chaos_engineering, platform, privacy_ethics, oss_compliance, observability, business, documentation, api_design, and i18n_l10n.
_Avoid_: ad hoc team names, hidden team aliases, legacy spec aliases

**Canonical Debate Mode Set**:
The qnN4o510 registry-authoritative full-system set of eight debate modes: sequential_review, parallel_debate, adversarial_debate, jury_panel, dynamic_assembly, meta_review, risk_priority_matrix, and cross_team_conflict_detector.
_Avoid_: legacy mode names, implicit aliases, earlier spec aliases

**Debate Member Persona**:
One expert viewpoint inside a Debate Team Configuration, such as a threat modeler, policy guardian, or API contract reviewer.
_Avoid_: mandatory Hermes skill, permanent subagent

**Debate Checklist**:
A debate-local reusable checklist referenced by Debate Member Personas to structure their evaluation without becoming an installed Hermes skill.
_Avoid_: Hermes skill by default, executable workflow authority

**Debate Member Invocation**:
One audited execution of a Debate Member Persona against a specific debate input through a selected backend.
_Avoid_: hidden opinion inside a combined model summary

**Debate Audit Trail**:
The audit evidence for a Debate Run, including package id, selected teams and members, backend policy, invocation refs, degraded state, retries, timing, and synthesis refs.
_Avoid_: full prompts, secrets, raw stdout as durable audit body

**Debate Member Opinion**:
The schema-valid output of one Debate Member Invocation, containing position, findings, evidence refs, risks, recommendations, confidence, and open questions.
_Avoid_: free-form expert paragraph

**Debate Conflict**:
A structured disagreement between debate member opinions that records the topic, positions, evidence refs, affected teams or members, and whether Kimi must decide.
_Avoid_: conflict hidden by synthesis

**Debate Backend Adapter**:
The adapter that executes Debate Member Invocations through an API, AI CLI, Hermes delegation, MoA, or another supported backend.
_Avoid_: source of team semantics, final decision authority

**Debate Backend Policy**:
The configurable package or project rule that selects preferred, fallback, and degraded debate backends for a debate stage.
_Avoid_: hard-coded model choice, backend-owned workflow semantics

**Orchestra-Controlled Debate Fan-Out**:
The default execution pattern where the Debate Engine explicitly launches separate Debate Member Invocations and then synthesizes their outputs.
_Avoid_: one opaque CLI summary standing in for all members

**Dynamic Debate Assembly**:
The per-run selection of relevant teams, member personas, and modes from the Full Debate Package based on stage, risk, and task type.
_Avoid_: always running all sixteen teams, model-only team selection

**Debate Assembly Policy**:
The deterministic project policy that selects debate teams, members, and modes from stage floors, task-type overlays, risk overlays, additive project overrides, and stable member scoring.
_Avoid_: hidden prompt routing, ad hoc debate team choice

**Debate Coverage Policy**:
The package-defined minimum team, member, and mode coverage required for each debate stage.
_Avoid_: hard-coded stage coverage, project override below full-package minimum

**Debate Configuration Change**:
A change to debate teams, member personas, modes, coverage policy, routing, checklists, or backend policy.
_Avoid_: low-risk automatic self-improvement by default

**Real Debate Backend**:
A non-template LLM/API backend that actually invokes debate roles and produces decision input from model reasoning.
_Avoid_: simulation-only acceptance proof

**Template Debate Fallback**:
A degraded debate backend used for fixtures, schema tests, or environments without a real debate backend.
_Avoid_: strong decision evidence

**Contract Fixture**:
A schema/config/edge-case fixture used to validate contracts without executing runtime paths or mutating Gateway authority state.
_Avoid_: fake runtime proof, completion evidence

**Runtime Fake Adapter**:
A test-only adapter that exercises Gateway integration paths in an isolated sandbox while marked as fixture backend and degraded fixture.
_Avoid_: production backend, release evidence, approval authority

**Partial Debate Report**:
A Debate Report produced after one or more non-required member invocations failed while Debate Coverage Policy still remained satisfied.
_Avoid_: pretending all members succeeded

**Kimi Decision**:
An orchestration decision made by Kimi for low or medium workflow risk below human-risk gates.
_Avoid_: approval for L3/L4 or forbidden automatic modifications

**Kimi Self-Review Risk**:
The risk condition where Kimi contributes debate evidence for a stage and would also make the stage decision without independent non-Kimi evidence.
_Avoid_: unmarked self-approval

**Human Approval**:
An explicit user approval required before any L3/L4, destructive, publishing, permission, secret, CI/CD, policy, or root-rule modification can proceed.
_Avoid_: timeout approval, agent approval

**Remote Decision Channel**:
An optional configured channel that lets Gateway send approval or decision requests outside the local CLI and receive the user's response.
_Avoid_: required default runtime path, single-platform dependency

**Disabled Formal Config**:
A full-system configuration file stored at its final project path while explicitly disabled until the corresponding implementation capability is ready.
_Avoid_: staged shadow path, file-exists-means-enabled

**System Improvement Proposal**:
A structured Stage 6 recommendation that may include proposed patch references for rules, worker config, debate routing, or workflow configuration.
_Avoid_: applied change

**Stage 6 Candidate Evolution Sweep**:
The automatic Continuous Improvement step that records candidate System Improvement Proposals for the just-finished run without applying them.
_Avoid_: manual-only learning capture, automatic system modification

**Candidate Evolution Trigger**:
A conservative run-evidence condition that allows the Stage 6 Candidate Evolution Sweep to emit one or more non-empty System Improvement Proposals.
_Avoid_: speculative improvement idea, every warning becoming system work

**Cross-Run Evolution Review**:
A Kimi-triggered review that compares evidence across multiple runs to propose broader durable learnings or system changes.
_Avoid_: always-on background self-modification, unstaged memory growth

**Kimi-Audited Self Evolution**:
The evolution loop where Hermes gathers candidate learnings and changes, but Kimi audits run evidence before deciding what should be promoted, changed, or summarized.
_Avoid_: autonomous agent self-modification, unsupervised memory growth

**Self Evolution Review Queue**:
The explicit review queue for System Improvement Proposals, with priority, batching, protected-target, backlog, evidence, and retention policy.
_Avoid_: interrupting Kimi for every proposal, deleting rejected proposals

**Closeout Report**:
The Stage 6 artifact that records final acceptance, warnings, downgrades, unresolved decisions, executed evidence, knowledge updates, and future proposals for a Six-Stage Run.
_Avoid_: completion self-report

**Partial Closeout**:
A closeout evidence record for a Stopped Run that preserves completed work, incomplete stages, pending decisions, and resume entry points without claiming success.
_Avoid_: completed closeout, failure cleanup

**Closeout Completion Gate**:
The Gateway validation step that marks a Six-Stage Run completed only after closeout artifacts, Audit, Kanban lifecycle, and Gateway State are consistent.
_Avoid_: Stage 6 self-completion

**Test Plan**:
A run-scoped artifact that maps development acceptance criteria to executable test cases.
_Avoid_: generic checklist

**Test Execution Report**:
A run-scoped artifact that records actual test commands, outcomes, and evidence.
_Avoid_: unexecuted plan

**Review Verdict**:
A structured reviewer decision on implementation output with findings, severity, affected acceptance criteria, required fixes, and evidence.
_Avoid_: free-form reviewer opinion

**QA Verdict**:
A structured quality decision on test and acceptance evidence with findings, severity, affected acceptance criteria, required fixes, and evidence.
_Avoid_: informal QA summary

**Improvement Cycle**:
A bounded Stage 4 repair pass triggered by review, QA, or test feedback within the approved Development Plan scope.
_Avoid_: unbounded retry loop, scope expansion

**Improvement Scope**:
The approved Development Plan boundary that defines what Stage 4 automatic repair may change.
_Avoid_: new requirement, architecture redirection, policy change

**Improvement Report**:
A Stage 4 artifact that links source feedback, repair changes, test evidence, and re-review or re-test requirements.
_Avoid_: informal fix summary

**Re-Review Artifact**:
A new review or QA artifact written after an Improvement Cycle without overwriting the original verdict.
_Avoid_: mutating prior review evidence

**Release Pipeline**:
The configured deployment path from dev/test through staging to a project-defined production target with validation, UAT, approval, and rollback evidence.
_Avoid_: assuming public production only, deploy script as completion proof

**Release Command Registry**:
The trusted project config that resolves release `command_ref` values to argv, cwd, env allowlist, timeout, kill, output capture, redaction, and approval policy.
_Avoid_: inline shell string, worker-owned deploy command

**Gateway Release Executor**:
The Gateway-owned process runner that executes registered release commands, enforces approvals and timeouts, captures redacted output refs, and writes deployment reports.
_Avoid_: Kimi shell execution, worker backend deploy authority

**Deployment Report**:
The structured release evidence artifact for each deploy or rollback command execution, including command refs, executor, output refs, exit code, timing, timeout, kill, health-check, approval, rollback, and recovery evidence.
_Avoid_: raw stdout dump, deploy success self-report

**Worker Backend**:
A replaceable CLI or API executor selected by role capability for implementation, review, debate, or related work.
_Avoid_: fixed tool name as workflow semantics

**Tmux Worker Session**:
A task-scoped ephemeral terminal session used by the full system to host or observe one real Worker Backend execution.
_Avoid_: project-permanent worker shell, debug-only pane, completion evidence

**Gateway Worker Session Sweeper**:
The Gateway-owned cleanup process that detects timed-out, missing, or abandoned Tmux Worker Sessions and records the cleanup result.
_Avoid_: worker-owned cleanup authority, manual tmux pruning

**Worker Backend Registry**:
The project config that declares enabled Worker Backends, adapters, health checks, modes, and capabilities.
_Avoid_: hard-coded CLI dispatch

**Worker Role Registry**:
The project config that maps workflow roles to required capabilities, preferred backends, and explicit fallback backends.
_Avoid_: Kimi-selected arbitrary tool

**Capability Negotiation**:
The Gateway step that validates requested worker pairing against registered roles and currently available backend capabilities.
_Avoid_: assuming an installed CLI can perform any role, implicit fallback

**Capability Negotiation Report**:
The evidence artifact written or returned when worker backend selection is blocked or requires explicit fallback decision.
_Avoid_: silent tool substitution, generic unavailable error

**Selected Worker Backend**:
The audited backend choice for a role in a run after capability negotiation.
_Avoid_: implicit default, unrecorded fallback

**Worker Adapter**:
The Gateway adapter that converts the role protocol into a specific CLI or API invocation.
_Avoid_: leaking CLI-specific behavior into workflow semantics

**Worker Context Envelope**:
The structured `hermes-role-engine/v1` input package assembled for a Worker Backend.
_Avoid_: raw chat history, whole project dump

**Worker Context Bundle**:
A scoped read-only artifact bundle that gives a Worker Backend the specific project and run context needed for its task.
_Avoid_: unbounded repository scan, unrelated conversation

**Worker Write Scope**:
The explicit set of files or operations a Worker Backend may change for a task.
_Avoid_: implicit permission to edit the project

**Worker Output Envelope**:
The structured `hermes-role-engine/v1` JSON response returned by a Worker Backend.
_Avoid_: natural-language result as state authority

**Gateway Advancement Gate**:
The Gateway validation step that decides whether a Worker Output Envelope may advance State, Audit, or Kanban lifecycle.
_Avoid_: worker-declared completion

**Worker Workspace**:
The task-scoped workspace where a Worker Backend performs code changes before review and audit.
_Avoid_: shared checkout as the default execution surface

**Direct Project Fallback**:
An explicit downgrade where a Worker Backend modifies the project checkout directly because workspace execution is unavailable and the low-risk task is approved for direct execution.
_Avoid_: default worker isolation strategy

## Relationships

- **Kimi** supervises one or more **Six-Stage Runs**
- **Kimi** is the top-level orchestrator; the **Hermes Execution Framework** is the lower execution framework for those runs
- A **Workflow Methodology Adapter** may specialize a **Six-Stage Run** for GSD or another methodology without becoming required
- A project may have only one **Active Run**
- A **Blocked Run** is still an **Active Run** and holds the project run slot until it is revised, rejected, stopped, or completed
- A **Blocked Run** may resume in place through approval or create a **Revision Attempt** through a revise decision
- The **Failure Boundary** defaults recoverable workflow problems to **Blocked Run**
- A **Failed Run** must record a **Last Good Checkpoint** when one exists
- A stop request turns an **Active Run** into a **Stopped Run** without approving, rejecting, or deleting its pending evidence
- A **Terminal Run** cannot be resumed in place in MVP
- A new **Six-Stage Run** may reference a failed or stopped **Terminal Run** through **Run Lineage** without mutating the source run
- **Run-Internal Parallelism** may happen inside an **Active Run** only when the **Parallel Independence Policy** proves tasks are independent
- **Parallel Independence Policy** requires non-overlapping **Worker Write Scopes**, isolated **Worker Workspaces**, conflict detection, and review or merge gates
- A **Conflict Scan** detects mechanical and authority-boundary conflicts only; the **Semantic Conflict Boundary** routes logical compatibility risk to serial integration tests and review gates
- A **Structured Ticket** or schema-valid **Structured PRD** gates the start of a **Six-Stage Run**
- A **Gateway Adapter** exposes the **Run Projection API** for **Six-Stage Runs**
- Mutating **Run Projection API** commands require an **Idempotency Key**
- **Idempotency Records** are Gateway State, scoped by project, endpoint, resource path, and key, and retained by the **Idempotency Retention Rule**
- The **Gateway Adapter** records one **Command ID** for each accepted mutating command
- The **Command Journal** records command intent before State, Audit, Kanban, or artifact side effects
- **Command Reconciliation** resolves unfinished commands after Gateway restart
- **Command Reconciliation** writes a **Command Reconciliation Report** with journal, State, Audit, Kanban, and artifact observations
- **Authority Chain Divergence** during **Command Reconciliation** makes the run blocked by default; Gateway must preserve observed evidence and write a reconciliation report rather than blindly replaying or fabricating missing Audit
- **Audit** and **Gateway Events** include the **Command ID** so retries cannot create duplicate evidence
- **Event Store** belongs to **Gateway State**, not **Audit**
- **Event Retention** keeps the full Event Store with the run State so `since_seq`, SSE resume, and command response refs remain stable
- The **Event Emission Gate** makes **Gateway Events** post-commit projections, never predictions of future State, Audit, Kanban, or artifact changes
- **Gateway Events** form an **Event Projection** for Kimi progress supervision, SSE, and UI updates
- **Event Sequence** is per-run and lets Kimi detect missed or inconsistent **Gateway Events**
- A **Projection Inconsistency** pauses Event-based supervision and requires resync, but does not by itself change a **Six-Stage Run** to **Blocked Run** when **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs are consistent
- A **Projection-Degraded Command Result** is still the idempotency result for the mutating command; retrying the same **Idempotency Key** returns that result and must not duplicate authority side effects
- **Degradation Status** applies to artifacts, backends, projections, and evidence, not to **Six-Stage Run** status
- Every degraded or recovered artifact must carry a **Degradation Record**
- **Degradation Policy** defaults degraded evidence to not satisfying required completion evidence unless an artifact-family exception and required acceptance are recorded
- **Template Debate Fallback** is degraded fixture evidence and never counts as required debate coverage
- **Audit** is immutable evidence authority; **Gateway Events** may be rebuilt from **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs, but **Audit** cannot be rebuilt from **Gateway Events**
- A **Gateway Adapter** may reverse-proxy `/v1/*` traffic to the **Official Hermes API Server**
- A **Gateway Adapter** translates Kimi-facing workflow commands into the **Hermes Execution Framework**
- **Hermes Kanban** owns task lifecycle for a **Six-Stage Run**
- A **Task Projection** is read-only and must not become raw Kanban CRUD
- **Gateway State** owns workflow metadata for a **Six-Stage Run**
- **Local Filesystem Cache** may accelerate rebuildable results but never owns canonical state
- **Redis Cache Adapter** may replace **Local Filesystem Cache** without changing workflow semantics and must remain optional
- **Audit** stores immutable evidence for a **Six-Stage Run**
- **Debate Engine** is a first-class subsystem in the full system, not an optional profile side effect
- **Debate Engine** reads **Debate Team Configuration** and **Debate Member Personas** from config; Hermes Agent does not invent or auto-maintain debate teams at runtime
- A **Full Debate Package** requires sixteen **Debate Team Configurations**, each with at least three **Debate Member Personas**
- **Canonical Debate Team Set** is the team id authority for the full package; legacy `product`, `business_product`, `integration`, `platform_integration`, and earlier spec aliases such as `architecture`, `ux`, `data`, `testing`, `operations`, `reliability`, `performance`, `maintainability`, `privacy`, and `release` are not canonical ids
- **Canonical Debate Mode Set** is the mode id authority for the full package; legacy and earlier-spec debate mode aliases are not carried forward
- **Debate Member Personas** should reference **Debate Checklists** by default; installed Hermes skill references are separate and require Kimi-audited promotion
- Every **Debate Member Invocation** must produce a schema-valid **Debate Member Opinion**
- **Debate Backend Adapter** executes member work through API, AI CLI, Hermes delegation, MoA, or another backend without owning team semantics
- **Debate Backend Policy** is configurable; MiniMax, Kimi, Claude, Codex, OpenRouter, Hermes delegation, MoA, or template backends may be selected by package or project config
- **Orchestra-Controlled Debate Fan-Out** is the default for auditability; one AI CLI may use internal subagents only if each member's input, output, and evidence remain separately auditable
- **Dynamic Debate Assembly** selects a subset of the **Full Debate Package** for each Debate Run; the package is full-size, but every run need not execute all teams
- **Debate Assembly Policy** makes **Dynamic Debate Assembly** deterministic: stage floor, task-type overlays, risk overlays, additive project overrides, then stable member scoring
- **Debate Coverage Policy** is stored in debate package config, and project overrides may extend but not go below the full-package minimum
- **Debate Engine** produces **Debate Reports** for Stage 1, Stage 2, and Stage 5 of a **Six-Stage Run**
- **Debate Reports** must include per-member outputs, conflicts, evidence, and synthesis rather than only a single natural-language summary
- Material disagreements must be preserved as **Debate Conflicts** and routed into Kimi decision input when they affect direction, solution, risk, or approval boundaries
- Every Debate Run must write both a **Debate Report** and a **Debate Audit Trail**
- A **Partial Debate Report** may continue only when **Debate Coverage Policy** remains satisfied; otherwise the stage becomes blocked for Kimi decision
- A **Debate Report** may include a recommended verdict, but it informs **Kimi** and does not replace a **Kimi Decision** or **Human Approval**
- A **Real Debate Backend** should produce at least one **Debate Report** in an MVP acceptance run when available
- **Template Debate Fallback** may scaffold a run but must be recorded as degraded
- A **Kimi Decision** may advance work below human-risk gates
- If Kimi is used as a **Debate Backend Adapter** for a stage, **Kimi Self-Review Risk** must be recorded and at least one non-Kimi **Debate Member Opinion** is required before a Kimi Decision can advance that stage
- **Human Approval** is required for L3/L4 and forbidden automatic modification boundaries
- **Remote Decision Channel** is disabled by default and only participates when configured
- **Global Evaluation** produces a **Global Evaluation Report** before **Final Acceptance**
- **Final Acceptance** may be Kimi-owned only below human-risk gates
- **Continuous Improvement** starts only after **Global Evaluation** has `pass` or Kimi-accepted `pass_with_warnings`
- **Continuous Improvement** writes a **Closeout Report** and **System Improvement Proposals** before any run can complete
- The **Stage 6 Candidate Evolution Sweep** runs for every completed run and records candidate-only **System Improvement Proposals**
- A **Stage 6 Candidate Evolution Sweep** always writes a proposal artifact, but non-empty proposals require at least one **Candidate Evolution Trigger**
- A **Cross-Run Evolution Review** runs only when Kimi explicitly requests broader review across multiple runs
- **Kimi-Audited Self Evolution** decides which **System Improvement Proposals**, learnings, skills, or rule changes should actually be promoted
- **System Improvement Proposals** enter the **Self Evolution Review Queue** by default instead of interrupting Kimi immediately
- Low and medium non-protected proposals may be batched; high, critical, and protected-target proposals are reviewed individually
- Rejected **System Improvement Proposals** are retained with decision refs, rejection reasons, and audit refs; they are not deleted
- **Debate Checklists** may be proposed for Hermes skill promotion only through **Kimi-Audited Self Evolution**
- **Debate Configuration Changes** that lower coverage, alter canonical teams or modes, remove members, change backend policy, or affect approval and risk coverage require **Human Approval**
- A **Stopped Run** writes **Partial Closeout** evidence instead of satisfying the **Closeout Completion Gate**
- The **Closeout Completion Gate** validates closeout artifacts, **Audit**, **Hermes Kanban**, and **Gateway State** before a run becomes completed
- **System Improvement Proposals** may lead to future approved changes but do not themselves modify root rule files, CI/CD, policy, or worker/debate/Gateway configuration
- A **Test Plan** must produce a **Test Execution Report** before a **Six-Stage Run** can complete
- A **Review Verdict** or **QA Verdict** may trigger an **Improvement Cycle** but cannot be overwritten by it
- An **Improvement Cycle** is constrained by **Improvement Scope** and must produce an **Improvement Report**
- A **Re-Review Artifact** records post-improvement validation as new evidence
- A **Release Pipeline** must define its project production target and record deployment gates, UAT, approval, and rollback or recovery evidence
- A **Release Command Registry** resolves deploy and rollback command refs; arbitrary shell strings are not release authority
- The **Gateway Release Executor** is the only component that executes release commands; Kimi, Debate Backends, and Worker Backends do not own deploy execution
- Staging and production release execution require approval refs before command start, and production approval is always **Human Approval**
- A timed-out release command writes a **Deployment Report** with `timed_out` status and blocks the run; rollback success requires its own deployment report
- A **Worker Backend** executes role-scoped tasks under **Hermes Kanban**
- The full system creates one task-scoped **Tmux Worker Session** per real worker execution, while Gateway State, Audit, and Kanban remain the authority chain
- The **Gateway Worker Session Sweeper** owns fallback cleanup of **Tmux Worker Sessions** on startup and periodic scans; **Worker Adapters** may request graceful stop but do not own cleanup authority
- A **Worker Backend Registry** declares available executors, while a **Worker Role Registry** declares which executors may satisfy each role
- The full target **Worker Backend Registry** and **Worker Role Registry** are staged under `config/workers/full/` while root `config/workers/*.json` remain MVP/current runtime configs until worker cutover
- **Capability Negotiation** validates Kimi-requested worker pairing before a **Selected Worker Backend** is recorded
- **Capability Negotiation** must not silently substitute a backend; blocked selection writes or returns a **Capability Negotiation Report**
- Worker fallback is allowed only when the **Worker Role Registry** explicitly lists the fallback backend and the failure class, risk level, task type, and authority boundary permit it
- A **Worker Adapter** hides CLI/API differences behind the `hermes-role-engine/v1` role protocol
- A **Worker Context Envelope** gives a **Worker Backend** structured task context, artifact references, risk state, and **Worker Write Scope**
- A **Worker Context Bundle** is read-only and scoped to the task; it must not become raw chat history or a full project dump
- A **Worker Output Envelope** may request completion, but only the **Gateway Advancement Gate** can advance **Gateway State**, **Audit**, or **Hermes Kanban**
- The full system requires a task-scoped **Worker Workspace** by default for real worker code changes
- **Direct Project Fallback** is allowed only for explicit low-risk single-worker downgrade paths and cannot be used for parallel, release, deploy, security, or rule-change work
- An **Artifact Reference** links **Hermes Kanban**, **Gateway State**, and **Audit** without embedding large artifacts in task bodies
- **State Artifacts** support resume, while **Audit Artifacts** support evidence and **Cache Artifacts** support acceleration
- **Repository Knowledge Artifacts** inform future runs but do not store run-scoped raw tickets or temporary state
- Get笔记 `qnN4o510` is a **Full-System Design Knowledge Source**, not a runtime dependency, runtime knowledge backend, or authority-chain artifact
- Runtime domain knowledge for specialized domains, such as WeChat Mini Program development, must be built as a separate **Runtime Domain Knowledge Base** with gbrain as the first target backend and its own storage and retrieval contract
- **Run Completion Evidence** excludes **Cache Artifacts** and model self-report
- The **Capability Authority Matrix** is the full-target actor map; Kimi and Human may request or decide inside authority boundaries, while Gateway validates, executes, and advances authority state
- The **Full Contract Validation Tool** validates full target contracts while the **MVP Runtime Schema** remains active
- **Artifact-Family Staged Cutover** is required: each **Full Contract Readiness Gate** applies to one artifact family, not the whole system
- Historical runs keep their original schema versions and artifact shapes; compatibility paths or lineage refs may be added, but historical artifacts are not rewritten in place
- The **Gateway Runtime Contract** keeps the full-system Gateway on the current Python local HTTP service path rather than introducing a Node, Go, or shared-database rewrite before cutover
- The **Gateway Full Runtime** is not the current MVP executable runtime; it requires artifact-family readiness gates and runtime code that consumes full contracts
- The **Performance SLO Policy** uses component target budgets and degradation actions; it does not promise a fixed completion SLA for a **Six-Stage Run**
- Human approval wait is excluded from SLO measurement, and external backend wait is reported separately
- **Contract Fixtures** and **Runtime Fake Adapters** are separate fixture layers; neither can satisfy completion, approval, release, strong debate, or authority repair evidence

## Example dialogue

> **Dev:** "Should `run_id` and `workflow_stage` be stored as Kanban task metadata?"
> **Domain expert:** "No. **Hermes Kanban** is the lifecycle authority, but **Gateway State** owns Orchestra workflow metadata. The **Gateway Adapter** combines both into the task projection Kimi sees."

> **Dev:** "Can Kimi approve a risky change if the debate report recommends it?"
> **Domain expert:** "Only below the human-risk gate. L3/L4 and forbidden automatic modifications require **Human Approval** even when Kimi recommends proceeding."

> **Dev:** "Does the full system require Telegram, Slack, or another remote channel before it can run?"
> **Domain expert:** "No. **Remote Decision Channel** is optional and disabled by default; local CLI/SSH decisions remain the default path unless a channel is configured."

> **Dev:** "Can the implementer just edit the project checkout?"
> **Domain expert:** "Only as explicit low-risk **Direct Project Fallback**. The full-system default is a task-scoped **Worker Workspace** so implementation, review, and audit can separate worker changes from existing user changes."

> **Dev:** "Does Stage 6 automatically update `AGENTS.md` after Kimi audits a run?"
> **Domain expert:** "No. **Continuous Improvement** writes a **System Improvement Proposal** and patch references. Root rule-file changes require **Human Approval** before application."

> **Dev:** "Does self-evolution run only when Kimi manually asks for it?"
> **Domain expert:** "No. The **Stage 6 Candidate Evolution Sweep** runs every completed run, but it only records candidate proposals. **Cross-Run Evolution Review** is the manual Kimi-triggered path for broader pattern review."

> **Dev:** "Should Stage 6 propose system changes every time?"
> **Domain expert:** "No. It always writes `system_improvement_proposals`, but non-empty proposals require a **Candidate Evolution Trigger** such as authority divergence, worker cleanup failure, schema mismatch, debate coverage failure, repeated same-class failures, repeated review/QA changes, or a decision that exposed a rule or documentation gap."

> **Dev:** "Can Curator promote a repeated worker lesson to global memory by itself?"
> **Domain expert:** "No. Curator may surface candidates, conflicts, or review tasks, but **Kimi-Audited Self Evolution** decides what becomes durable shared knowledge."

> **Dev:** "Can a frequently used Debate Checklist automatically become a Hermes skill?"
> **Domain expert:** "No. It can become a **System Improvement Proposal**, but promotion to an installed Hermes skill requires **Kimi-Audited Self Evolution** and any required **Human Approval**."

> **Dev:** "Can Stage 6 remove a debate member or switch the full package to template-only?"
> **Domain expert:** "No. That is a **Debate Configuration Change** affecting coverage or backend policy and requires **Human Approval**."

> **Dev:** "Does MVP need Redis because the production premise mentions Redis?"
> **Domain expert:** "No. **Local Filesystem Cache** is the default. **Redis Cache Adapter** is optional, must keep the same adapter interface, and must not become canonical state."

> **Dev:** "Should workers call Get笔记 during a run because `qnN4o510` shaped the full-system design?"
> **Domain expert:** "No. Get笔记 `qnN4o510` is a **Full-System Design Knowledge Source**. Runtime authority remains local State, Audit, Schema, Harness evidence, and Kanban."

> **Dev:** "Can a template debate report satisfy the decision engine requirement?"
> **Domain expert:** "Only as **Template Debate Fallback**. If a **Real Debate Backend** is available, at least one core debate stage should use it; template output is scaffold evidence, not strong decision evidence."

> **Dev:** "Can the full workflow skip debate and let the implementer justify its own plan?"
> **Domain expert:** "No. The **Debate Engine** is a first-class decision subsystem; implementer reasoning can inform work, but **Debate Reports** are separate inputs to Kimi."

> **Dev:** "If `jury_panel` recommends pass, can the run advance automatically?"
> **Domain expert:** "No. The **Debate Report** can recommend a verdict, but a **Kimi Decision** is required to advance below human-risk gates."

> **Dev:** "Are the sixteen debate teams maintained as Hermes agents or skills?"
> **Domain expert:** "No. They are **Debate Team Configurations** with **Debate Member Personas**. Personas usually reference **Debate Checklists**, not installed Hermes skills."

> **Dev:** "Should a persona field named `skill_refs` point to Hermes skills?"
> **Domain expert:** "No. Use `checklist_refs` for **Debate Checklists** and reserve `hermes_skill_refs` for Kimi-audited installed Hermes skills."

> **Dev:** "Can a full debate package define one security member and call the team complete?"
> **Domain expert:** "No. A **Full Debate Package** keeps the qnN4o510 shape: sixteen teams, and each team has at least three **Debate Member Personas**."

> **Dev:** "Does every debate run need to invoke all forty-eight member personas?"
> **Domain expert:** "No. Use **Dynamic Debate Assembly**. The package must be full, but each run selects the relevant teams and members for its stage and risk."

> **Dev:** "Can the model just decide which debate teams seem relevant?"
> **Domain expert:** "No. **Dynamic Debate Assembly** follows **Debate Assembly Policy**. The audit trail must show stage floor, task-type overlays, risk overlays, project overrides, and member scoring."

> **Dev:** "Should minimum debate coverage be hard-coded in the engine?"
> **Domain expert:** "No. **Debate Coverage Policy** lives in the full package config; projects can add coverage but cannot drop below the package minimum."

> **Dev:** "Is saving the Debate Report enough evidence?"
> **Domain expert:** "No. The run also needs a **Debate Audit Trail** showing which package, teams, members, backends, invocation refs, degradation, retries, and synthesis refs were used."

> **Dev:** "If two debate members time out, can the debate still finish?"
> **Domain expert:** "Only if **Debate Coverage Policy** is still satisfied. Then write a **Partial Debate Report** with failures and degradation; otherwise block for Kimi decision."

> **Dev:** "Can synthesis hide disagreement and just pick the cleaner conclusion?"
> **Domain expert:** "No. Material disagreement must be recorded as a **Debate Conflict** with evidence and decision routing."

> **Dev:** "Are `product`, `business_product`, `integration`, `architecture`, `ux`, or `release` canonical team ids?"
> **Domain expert:** "No. The **Canonical Debate Team Set** follows the qnN4o510 registry: `security`, `compliance`, `data_engineering`, `devops_sre`, `frontend`, `ai_feature`, `scalability_arch`, `chaos_engineering`, `platform`, `privacy_ethics`, `oss_compliance`, `observability`, `business`, `documentation`, `api_design`, and `i18n_l10n`."

> **Dev:** "Can the full debate package keep using `red_team` or `risk_review` as mode ids?"
> **Domain expert:** "No. The **Canonical Debate Mode Set** replaces legacy mode ids; use `adversarial_debate` and `risk_priority_matrix` instead."

> **Dev:** "Is `tradeoff_matrix` a canonical full-package debate mode?"
> **Domain expert:** "No. Following the qnN4o510 registry, use `dynamic_assembly` as the canonical mode for automatic team selection; `tradeoff_matrix` is an earlier-spec alias or local convenience, not a canonical mode id."

> **Dev:** "Should one CLI spawn internal subagents and return one final debate summary?"
> **Domain expert:** "Not as the default. Use **Orchestra-Controlled Debate Fan-Out** so Kimi can audit each **Debate Member Invocation**. A CLI subagent backend is acceptable only when it exposes per-member inputs, outputs, and evidence."

> **Dev:** "Can each debate member write its opinion in its own prose format?"
> **Domain expert:** "No. Each **Debate Member Invocation** must produce a schema-valid **Debate Member Opinion** so Kimi can compare findings, risks, confidence, and open questions."

> **Dev:** "Is MiniMax the required debate backend?"
> **Domain expert:** "No. **Debate Backend Policy** is configurable. MiniMax may be a good package default, but backend selection is not hard-coded."

> **Dev:** "Can Kimi generate debate member opinions and then approve the stage by itself?"
> **Domain expert:** "No. That creates **Kimi Self-Review Risk**. Record the risk and require at least one non-Kimi **Debate Member Opinion** before Kimi can decide below human-risk gates."

> **Dev:** "Can Kimi send a short intent and immediately start implementation?"
> **Domain expert:** "No. A short intent can start intake, but execution waits for a schema-valid **Structured Ticket** or **Structured PRD** with acceptance criteria, constraints, and failure strategy."

> **Dev:** "Does the full system require GSD commands to run?"
> **Domain expert:** "No. GSD can be a **Workflow Methodology Adapter**, but the core **Six-Stage Run** must work without it."

> **Dev:** "Can a real worker demo count if no tmux session exists?"
> **Domain expert:** "For MVP yes if the CLI work and evidence are real. For the full system, real worker execution should be hosted or observable through **Tmux Worker Sessions**."

> **Dev:** "Should each project keep a permanent Codex and Claude tmux shell?"
> **Domain expert:** "No. The full system uses task-scoped ephemeral **Tmux Worker Sessions** so context, logs, and audit evidence map to one Kanban task."

> **Dev:** "If a worker crashes and leaves a tmux session behind, is the backend responsible for cleanup?"
> **Domain expert:** "No. The **Gateway Worker Session Sweeper** owns fallback cleanup. It checks worker session records, actual tmux sessions, heartbeats, and timeouts, then records cleanup status and any blocked task."

> **Dev:** "Can two implementers work in the same project at the same time?"
> **Domain expert:** "Only inside one **Active Run** when the **Parallel Independence Policy** proves their write scopes do not conflict and separate review or merge gates exist."

> **Dev:** "If `conflict_scan` passes, did we prove the parallel changes are semantically compatible?"
> **Domain expert:** "No. **Conflict Scan** only covers mechanical and authority-boundary conflicts. The **Semantic Conflict Boundary** says behavior compatibility is tested during serial integration and review gates."

> **Dev:** "Does production have to mean a public internet service?"
> **Domain expert:** "No. A **Release Pipeline** production target is project-defined, but staging, UAT, approval, and rollback or recovery evidence are still required."

> **Dev:** "Can Kimi create or link Kanban tasks directly through the Gateway?"
> **Domain expert:** "No. Kimi uses the **Run Projection API**. **Task Projection** is read-only; Kanban mutations happen internally through workflow rules."

> **Dev:** "Should the full-system Gateway be redesigned as a Node, Go, or shared-database service before cutover?"
> **Domain expert:** "No. The **Gateway Runtime Contract** extends the current Python local HTTP Gateway. Kimi speaks JSON Run Projection API, `/v1/*` may proxy to upstream Hermes, and local filesystem State/Audit remain the default authority store."

> **Dev:** "Can two runs modify the same project at the same time?"
> **Domain expert:** "No. MVP allows one **Active Run** per project. **Run-Internal Parallelism** is allowed only for independent work declared in the Development Plan."

> **Dev:** "Is writing `test_plan.json` enough to satisfy AI testing?"
> **Domain expert:** "No. A **Test Plan** must be executed, and the resulting **Test Execution Report** must record the commands and outcomes."

> **Dev:** "Can a cache hit prove the run is complete?"
> **Domain expert:** "No. **Run Completion Evidence** comes from **Hermes Kanban**, **Gateway State**, **Audit Artifacts**, and schema-valid required artifacts. **Cache Artifacts** can speed recomputation, but they never decide completion."

> **Dev:** "Can Kimi choose any installed CLI as reviewer?"
> **Domain expert:** "No. Kimi may request a pairing, but **Capability Negotiation** must confirm it is registered, role-compatible, and available before the Gateway records a **Selected Worker Backend**."

> **Dev:** "If Codex is unavailable, can Gateway quietly switch the implementer to another CLI?"
> **Domain expert:** "No. Worker fallback is explicit only. Gateway writes a **Capability Negotiation Report** and blocks for Kimi unless the **Worker Role Registry** declares a safe fallback for that failure and context."

> **Dev:** "Can we just pass the whole chat and repo to Codex?"
> **Domain expert:** "No. Workers receive a **Worker Context Envelope** plus scoped **Worker Context Bundles** and **Worker Write Scope**. Extra context must be requested through artifact refs, not dumped wholesale."

> **Dev:** "If the worker returns `complete`, is the Kanban task done?"
> **Domain expert:** "No. `complete` in a **Worker Output Envelope** is only a request. The **Gateway Advancement Gate** must validate evidence and then advance **Hermes Kanban**."

> **Dev:** "Can Kimi accept a change even though QA requested fixes?"
> **Domain expert:** "Only through the decision path and below human-risk gates. A **QA Verdict** with `request_changes` triggers an **Improvement Cycle**; high-risk `block` cannot be bypassed."

> **Dev:** "Can Stage 4 use the review failure to redesign the feature?"
> **Domain expert:** "No. **Improvement Scope** only covers fixes inside the approved Development Plan. Redesign or scope expansion needs a revision decision."

> **Dev:** "Can Stage 6 close out if tests passed but global evaluation found unresolved warnings?"
> **Domain expert:** "Only if the **Global Evaluation Report** is `pass` or Kimi accepts `pass_with_warnings` below human-risk gates. `fail` and `block` cannot be skipped."

> **Dev:** "If Stage 6 writes a closeout summary, is the run completed?"
> **Domain expert:** "No. The **Closeout Report** is evidence. The **Closeout Completion Gate** must also validate schema, **Audit**, **Hermes Kanban**, and **Gateway State** before the run is marked completed."

> **Dev:** "If I cancel a blocked run, do we delete its artifacts and clear the pending decision?"
> **Domain expert:** "No. Cancel maps to a **Stopped Run**. The Gateway writes **Partial Closeout** evidence and preserves **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs; pending decisions remain recorded as unresolved."

> **Dev:** "Can we resume a stopped or failed run by changing its status back to running?"
> **Domain expert:** "No. A stopped or failed run is a **Terminal Run**. Continue by creating a new **Six-Stage Run** with **Run Lineage** pointing to the source evidence."

> **Dev:** "If tests fail twice or schema validation fails, is the run failed?"
> **Domain expert:** "No. That is normally a **Blocked Run**. Cross the **Failure Boundary** only when workflow authority or evidence integrity is unrecoverable."

> **Dev:** "If Kimi retries `POST /orchestra/runs` after a timeout, do we create another run?"
> **Domain expert:** "No. The same **Idempotency Key** and payload return the original result and **Command ID**. A different payload with the same key is rejected."

> **Dev:** "If Kimi retries the same Idempotency Key three days later, should the Gateway treat it as a new command?"
> **Domain expert:** "No. The **Idempotency Retention Rule** keeps the **Idempotency Record** with Gateway State. Same payload returns the original result; different payload is `idempotency_conflict`."

> **Dev:** "Can archive or garbage collection delete idempotency records while keeping the run evidence?"
> **Domain expert:** "No. The **Idempotency Record** must move with the protected Gateway State or leave an archived stub that prevents the key from becoming fresh work."

> **Dev:** "If the Gateway crashes after creating Kanban tasks but before returning the run response, should restart replay the command?"
> **Domain expert:** "No. **Command Reconciliation** first checks **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs. It completes, continues, or blocks from evidence; it never blindly replays."

> **Dev:** "If **Hermes Kanban** shows a task was created but **Audit** has no matching **Command ID**, can Gateway fill in the missing audit record and continue?"
> **Domain expert:** "No. That is **Authority Chain Divergence**. Gateway writes a reconciliation report, preserves the Kanban evidence, blocks the run, and asks Kimi to choose the repair path."

> **Dev:** "Can the reconciliation report just say `blocked`?"
> **Domain expert:** "No. A **Command Reconciliation Report** must include the journal step status, State, Audit, Kanban, and artifact observations, divergence class, replay and synthetic-audit bans, and recommended repair options."

> **Dev:** "Can Kimi advance a run just because the latest SSE event says a stage completed?"
> **Domain expert:** "No. **Gateway Events** are a recoverable **Event Projection**. Kimi must resync from run status, task projection, and authoritative artifact refs if **Event Sequence** has a gap or looks stale."

> **Dev:** "If the event stream is corrupt but State, Audit, and Kanban all agree, should the run become blocked?"
> **Domain expert:** "No. That is a **Projection Inconsistency**, not a workflow blocker. Rebuild or resync the **Event Projection**; only authority-chain inconsistency can block or fail the run."

> **Dev:** "Can Gateway emit `stage_completed` before Audit and Kanban completion are durable?"
> **Domain expert:** "No. The **Event Emission Gate** appends Events only after the authority records they summarize are durable. Events cannot pre-announce state transitions."

> **Dev:** "If the authority writes succeed but appending the event fails, should Kimi retry the command?"
> **Domain expert:** "No. Return a **Projection-Degraded Command Result** and repair the **Event Projection**. Retrying the same **Idempotency Key** must not repeat the authority writes."

> **Dev:** "Is `degraded` a run status?"
> **Domain expert:** "No. **Degradation Status** describes artifact, backend, projection, or evidence quality. A run remains queued, running, blocked, failed, completed, or stopped."

> **Dev:** "Can degraded evidence complete a required gate?"
> **Domain expert:** "Not by default. **Degradation Policy** must explicitly allow that artifact family, and the required Kimi or Human acceptance must be recorded. **Template Debate Fallback** never satisfies required debate coverage."

> **Dev:** "Can a recovered backend overwrite the degraded artifact?"
> **Domain expert:** "No. Recovery writes replacement evidence and marks the later artifact as recovered; the original degraded evidence remains in Audit."

## Flagged ambiguities

- "Kanban metadata" was used to mean both upstream Hermes Kanban run metadata and Orchestra workflow metadata. Resolved: **Hermes Kanban** owns lifecycle state; **Gateway State** owns workflow metadata.
- "run" was used to mean both **Six-Stage Run** and **Agent Run**. Resolved: `/orchestra/runs` means **Six-Stage Run**; official `/v1/runs` remains an upstream **Agent Run** surface.
- "final decision authority" was used for both Kimi orchestration decisions and user approvals. Resolved: **Kimi Decision** is final below human-risk gates; **Human Approval** is final for L3/L4 and forbidden automatic modification boundaries.
- "remote notification" was used to imply a required default channel. Resolved: **Remote Decision Channel** is optional and disabled until configured.
- "worker isolation" was used to mean both per-task workspace isolation and direct repo execution. Resolved: **Worker Workspace** is the full-system default; **Direct Project Fallback** is an explicit low-risk downgrade.
- "system evolution" was used to imply automatic rule-file edits. Resolved: **Continuous Improvement** produces **System Improvement Proposals**; root rule-file application requires **Human Approval**.
- "self evolution" was used to imply automatic agent growth. Resolved: **Kimi-Audited Self Evolution** requires Kimi audit before promotion, rule changes, skill changes, or durable experience summaries.
- "self-evolution trigger" was used without distinguishing routine capture from deeper review. Resolved: **Stage 6 Candidate Evolution Sweep** runs automatically for every completed run, while **Cross-Run Evolution Review** is Kimi-triggered.
- "candidate proposal" was used as if Stage 6 should always suggest system changes. Resolved: the artifact is always written, but non-empty proposals require a **Candidate Evolution Trigger**.
- "self-evolution review" was used as if every proposal should immediately interrupt Kimi. Resolved: proposals enter the **Self Evolution Review Queue**; low/medium non-protected items may batch, protected targets require Kimi review plus Human Approval, and rejected proposals are retained.
- "debate configuration" was used to imply ordinary low-risk tuning. Resolved: coverage-lowering or authority-impacting **Debate Configuration Changes** require **Human Approval**.
- "cache" was used to imply both required Redis and local cache. Resolved: **Local Filesystem Cache** is the default; **Redis Cache Adapter** is an optional adapter interface implementation, not a required runtime dependency.
- "Get笔记" was used to imply both design reference and runtime knowledge dependency. Resolved: `qnN4o510` is a **Full-System Design Knowledge Source** only.
- "knowledge base" was used for both external requirements/design references and runtime domain retrieval. Resolved: Get笔记 `qnN4o510` supports requirements and design synthesis only; the project's runtime specialized-domain retrieval belongs to a separate **Runtime Domain Knowledge Base**.
- "SQLite runtime KB" was considered as a backend for specialized domain knowledge. Resolved: do not build a separate SQLite runtime KB when gbrain is available; gbrain is the Runtime Domain Knowledge Base backend, and PGLite is gbrain's internal storage engine choice.
- "runtime knowledge entry" was used without a stable shape. Resolved: each entry is a gbrain markdown page with required frontmatter and sections; unverified content starts as `candidate_knowledge` and must be verified before promotion to `domain_knowledge`.
- "runtime knowledge ingestion" was used as if Hermes could write directly to its own DB. Resolved: ingestion follows gbrain CLI/MCP operations (`put`, `import`, `sync`, `link`, `query`, `report`, `serve`) and every promotion, overwrite, supersession, or deprecation requires a **Knowledge Ingestion Record**.
- "runtime knowledge retrieval" was used as if a matching memory result could settle a question. Resolved: gbrain retrieval produces **Runtime Knowledge Retrieval Result** artifacts with freshness/source warnings; results may inform workers or debate members but do not replace source refs, tests, official docs, Kimi Decision, or Human Approval.
- "runtime knowledge freshness" was treated as optional metadata. Resolved: platform, SDK, cloud runtime, project observation, and conceptual entries have explicit re-verification windows, provenance requirements, redaction rules, audit records, and evidence-use boundaries.
- "template debate" was used to imply both fixture scaffolding and real decision work. Resolved: **Real Debate Backend** is preferred for acceptance when available; **Template Debate Fallback** is degraded scaffold output.
- "debate" was used to imply optional reviewer commentary. Resolved: **Debate Engine** is a first-class subsystem in the full workflow, producing separate **Debate Reports** for Kimi.
- "debate team" was used to imply a long-running Hermes agent or a required skill. Resolved: a team is **Debate Team Configuration**; members are **Debate Member Personas** with optional checklist references.
- "skill_refs" was used to imply debate-local checklists and installed Hermes skills are the same thing. Resolved: **Debate Checklist** refs and Hermes skill refs are separate.
- "full debate package" was used to imply any registry with team names. Resolved: a **Full Debate Package** requires sixteen teams with at least three member personas per team.
- "full debate" was used to imply every run must execute all configured teams. Resolved: **Dynamic Debate Assembly** selects a stage-appropriate subset from the full package.
- "dynamic assembly" was used as if the model could freely choose teams. Resolved: **Debate Assembly Policy** is deterministic and auditable, using stage floors, task-type overlays, risk overlays, additive project overrides, and stable member scoring.
- "minimum debate coverage" was used to imply code constants. Resolved: **Debate Coverage Policy** is package configuration, not hard-coded engine logic.
- "debate evidence" was used to imply the report alone is enough. Resolved: each Debate Run writes a **Debate Report** and a **Debate Audit Trail**.
- "partial debate" was used to imply silent success after failed members. Resolved: **Partial Debate Report** is allowed only when coverage remains satisfied and degradation is recorded.
- "debate synthesis" was used to imply conflicts can be smoothed into one conclusion. Resolved: material disagreements become **Debate Conflicts**.
- "canonical debate team" was used for the earlier full-spec aliases `architecture`, `ux`, `data`, `testing`, `operations`, `reliability`, `performance`, `maintainability`, `privacy`, and `release`, while qnN4o510 records a concrete sixteen-team registry. Resolved: **Canonical Debate Team Set** follows the qnN4o510 registry ids: `security`, `compliance`, `data_engineering`, `devops_sre`, `frontend`, `ai_feature`, `scalability_arch`, `chaos_engineering`, `platform`, `privacy_ethics`, `oss_compliance`, `observability`, `business`, `documentation`, `api_design`, and `i18n_l10n`.
- "product", "business_product", "integration", and "platform_integration" were used as canonical debate team ids. Resolved: these are legacy or local aliases, not canonical ids in the **Canonical Debate Team Set**.
- "red_team", "risk_review", and other legacy mode ids were used as canonical debate modes. Resolved: **Canonical Debate Mode Set** replaces them without legacy aliases in the full package.
- "tradeoff_matrix" was used as a canonical debate mode in the earlier full spec, while qnN4o510 records `dynamic_assembly` in the concrete eight-mode registry. Resolved: **Canonical Debate Mode Set** follows qnN4o510 and uses `dynamic_assembly`, not `tradeoff_matrix`.
- `config/debate/teams.json` and `config/debate/modes.json` were used as if they were current full-package registries. Resolved: they are legacy MVP registries and may only serve as migration source material unless marked `legacy_mvp`, low-cost, or degraded.
- "debate package JSON schema and directory layout" was used to imply a possible new monolithic package file or immediate root-registry replacement. Resolved: the Full Debate Package is staged under `config/debate/full/`, while root `config/debate/teams.json` and `config/debate/modes.json` remain MVP/current runtime registries until cutover.
- "team registry schema" was used without distinguishing registry identity, team dimensions, and member personas. Resolved: `config/debate/full/teams.json` requires full-package authority markers, sixteen canonical teams, qnN4o510 dimensions, and at least three member persona entries per team.
- "mode registry schema" was used without separating mode selection from coverage policy. Resolved: `config/debate/full/modes.json` requires full-package authority markers, eight canonical modes, mode mechanism, selection rules, required inputs, and output contract; coverage/backend policy remain separate artifacts.
- "member opinion schema" was used as only content fields. Resolved: a **Debate Member Opinion** must include artifact identity, invocation identity, package/member routing, inputs, opinion content, decision hints, and safe persistence constraints.
- "debate report schema" was used as an MVP summary object. Resolved: a Full Debate Package **Debate Report** must include identity, config, inputs, assembly, coverage/degradation, synthesis, decision handoff, and traceability fields while linking complete member outputs by `opinion_refs`.
- "debate audit trail schema" was used as a loose evidence log. Resolved: a **Debate Audit Trail** records config snapshots, assembly choices, per-member invocation records, synthesis refs, and safety flags without persisting raw prompts, secrets, raw stdout, or long-form body text.
- "backend adapter protocol" was used as if each backend family could define its own output shape. Resolved: API, CLI, Hermes delegation, and MoA backends all use the same Debate Member Invocation Envelope and return schema-valid **Debate Member Opinion** artifacts; backend differences stay in transport and execution strategy.
- "debate member invocation" was used without a stable adapter input contract. Resolved: the **Debate Member Invocation Envelope** carries identity, routing, backend contract, scoped inputs, persona contract, safety flags, and expected output schema while forbidding durable raw prompt/stdout persistence.
- "subagent debate" was used to imply one CLI can hide all expert work behind a final summary. Resolved: **Orchestra-Controlled Debate Fan-Out** is the default, and any subagent backend must preserve separately auditable **Debate Member Invocations**.
- "member opinion" was used to imply free-form expert prose. Resolved: each member output is a schema-valid **Debate Member Opinion**.
- "full schema" was used as if it might replace the current schema file immediately. Resolved: the **Full Schema Package** is added in parallel, while the **MVP Runtime Schema** remains the current executable runtime contract until full implementation cutover.
- "strict schema" was used as if the first full schema must lock every nested business field. Resolved: the **Full Schema Guardrail Boundary** strictly validates authority, routing, evidence, degradation, freshness, and forbidden persistence while keeping deep findings/risks/recommendations/conflicts/synthesis content structurally typed but not over-specified in the first version.
- "schema coverage" was used as if full schema could cover only newly introduced artifacts. Resolved: the **Full Schema Coverage Set** covers Gateway authority, Six-Stage evidence, Full Debate Package, Worker execution, Runtime Domain Knowledge Base, Release, and decisions so full-system acceptance has one coherent contract.
- "full debate config" was used as if it should overwrite the current runtime registry immediately. Resolved: create **Staged Full Debate Config** under `config/debate/full/` for full-system validation and cutover planning while root `config/debate/teams.json` and `config/debate/modes.json` remain MVP/current runtime registries until implementation cutover.
- "coverage matrix" was used as if current implementation coverage and full target readiness should share one table. Resolved: keep current `docs/COVERAGE-MATRIX.md` for MVP/current runtime coverage and add a separate **Full Target Coverage Matrix** for full-system readiness and implementation status.
- "can Kimi or Human do X" was used as a flat permission question. Resolved: the **Capability Authority Matrix** splits request, decision, approval, execution, and state-advancement authority so Human, Kimi, Gateway, and Worker capabilities are not conflated.
- "full contract validation" was used as if the Full Schema Package should immediately become runtime validation. Resolved: add a **Full Contract Validation Tool** first, then require a **Full Contract Readiness Gate** before artifact-family runtime cutover.
- "MVP-to-full cutover" was used as if a global schema switch could activate the full system. Resolved: use **Artifact-Family Staged Cutover** through `config/cutover/full-readiness-gates.json`; global cutover and historical in-place rewrites are forbidden.
- "SLA" was used as if a whole Six-Stage Run can promise fixed wall-clock completion. Resolved: the **Performance SLO Policy** uses target budgets per component, records actual timings, excludes human wait, reports external backend wait separately, and routes budget misses to degraded or blocked outcomes.
- "mock backend" was used as if one fake layer could both validate contracts and prove runtime behavior. Resolved: split **Contract Fixtures** from **Runtime Fake Adapters** through `config/testing/full-fixture-policy.json`; runtime fakes are test-sandbox-only degraded fixtures and cannot satisfy authority evidence.
- "debate backend" was used to imply a fixed model provider. Resolved: **Debate Backend Policy** makes backend selection configurable per package or project.
- "Kimi as debate backend" was used to imply Kimi can self-approve its own evidence. Resolved: **Kimi Self-Review Risk** requires explicit marking and independent non-Kimi debate evidence.
- "intent" was used to imply execution-ready input. Resolved: short intent is intake-only; **Structured Ticket** or schema-valid **Structured PRD** is required before six-stage execution starts.
- "GSD workflow" was used to imply the core workflow. Resolved: GSD is an optional **Workflow Methodology Adapter**, not a core dependency.
- "tmux" was used to imply either project-permanent shells or debug-only observation. Resolved: the full system uses task-scoped ephemeral **Tmux Worker Sessions**, records a `worker_session_record`, treats transcripts as short-lived debug/cache artifacts, and does not use tmux transcripts as completion evidence.
- "tmux cleanup" was used as if each Worker Backend owns leak prevention. Resolved: **Gateway Worker Session Sweeper** owns fallback cleanup, while Worker Adapters may only perform graceful stop attempts.
- "tasks API" was used to imply both projection and mutation. Resolved: **Task Projection** is read-only; Gateway must not expose raw Kanban CRUD to Kimi in MVP.
- "parallel execution" was used for both multi-run concurrency and safe child-task parallelism. Resolved: one **Active Run** per project; **Run-Internal Parallelism** is allowed only with an explicit **Parallel Independence Policy**.
- "parallel merge" was used as if independent worker branches could be optimistically combined. Resolved: parallel child tasks require isolated **Worker Workspaces**, explicit **Worker Write Scopes**, `parallel_group_plan`, `conflict_scan`, serial merge into an integration workspace, and `merge_conflict_report` for Kimi decision when conflicts appear.
- "conflict scan" was used as if it can prove semantic compatibility between parallel changes. Resolved: **Conflict Scan** is mechanical and authority-boundary only; semantic compatibility is covered by serial integration tests and review gates.
- "release pipeline config" was used as if a deploy script alone could prove release completion. Resolved: `config/release/pipeline.json` defines environments, gates, command refs, approval policy, rollback policy, and evidence requirements; completion still requires structured release evidence.
- "release command ref" was used as if it could be an inline script or worker-owned command. Resolved: `deploy_command_ref` and `rollback_command_ref` must resolve through the **Release Command Registry** at `config/release/commands.json`, and only the **Gateway Release Executor** executes them.
- "deployment report" was used as if command output could be pasted into Audit or treated as success proof. Resolved: **Deployment Report** records refs, hashes, exit code, timing, timeout/kill fields, approval refs, health-check refs, and rollback/recovery refs; raw stdout/stderr stay out of durable Audit, Events, Kanban, and report bodies.
- "optional full config" was used as if formal config file presence means the feature is active. Resolved: Release Pipeline, Remote Decision Channel, and Runtime Domain Knowledge Base use **Disabled Formal Config** files at their final paths with `enabled: false` until implementation cutover.
- "remote decision channel" was used as if an external channel could become an approval authority or workflow mutation path. Resolved: Remote Decision Channel is disabled by default, only transports decision requests/responses, and Gateway remains responsible for validation, replay protection, expiry, responder binding, fixed phrase checks, and state advancement.
- "AI testing" was used to imply both test planning and test execution. Resolved: **Test Plan** must be executed and produce a **Test Execution Report** before completion.
- "artifact" was used for state, evidence, cache, and project knowledge. Resolved: **State Artifacts** restore runs, **Audit Artifacts** prove what happened, **Cache Artifacts** are rebuildable, and **Repository Knowledge Artifacts** are long-lived project knowledge.
- "worker pairing" was used to imply Kimi can pick arbitrary tools. Resolved: Kimi may request a pairing, but **Worker Backend Registry**, **Worker Role Registry**, and **Capability Negotiation** decide whether it can run.
- "worker fallback" was used as if an unavailable requested backend can be silently replaced. Resolved: fallback is explicit only; blocked selection writes or returns a **Capability Negotiation Report** unless the role registry permits a safe fallback.
- "worker context" was used to imply raw chat history or all project files. Resolved: workers receive a **Worker Context Envelope** and scoped **Worker Context Bundles** only.
- "worker complete" was used to imply direct task completion. Resolved: worker output is a request; **Gateway Advancement Gate** owns state and lifecycle advancement.
- "review failed" was used to imply either optional feedback or hard rejection. Resolved: **Review Verdict** and **QA Verdict** use explicit verdicts, and non-approval routes through **Improvement Cycle**, Kimi decision, or Human Approval.
- "improvement" was used to imply both bounded repair and scope-changing redesign. Resolved: Stage 4 automatic **Improvement Cycle** is bounded by **Improvement Scope**; redesign requires decision routing.
- "production" was used to imply only a public service. Resolved: **Release Pipeline** production target is project-defined, while approval and rollback evidence remain mandatory.
- "final acceptance" was used to imply closeout can trust completed subtasks. Resolved: **Global Evaluation** must produce a verdict before **Final Acceptance** and Stage 6.
- "closeout" was used to imply a Stage 6 self-report can complete the run. Resolved: **Closeout Report** is evidence; **Closeout Completion Gate** decides completion from closeout artifacts, **Audit**, **Hermes Kanban**, and **Gateway State**.
- "cancel" was used to imply destructive cleanup or rejection. Resolved: Kimi-facing cancel maps to stop-and-archive, producing a **Stopped Run** and **Partial Closeout** without resolving pending approvals.
- "resume" was used to mean both unblocking an active run and continuing a terminal run. Resolved: **Blocked Runs** resume in place; stopped or failed **Terminal Runs** continue only through a new run with **Run Lineage**.
- "failed" was used to mean both ordinary task/test failure and terminal run failure. Resolved: ordinary work failure blocks; **Failed Run** is reserved for crossing the **Failure Boundary**.
- "retry" was used to imply re-running a mutating API command. Resolved: mutating commands are deduplicated by **Idempotency Key** and traced by **Command ID**.
- "idempotency TTL" was used as if retry safety is a cache window. Resolved: **Idempotency Records** have no independent TTL and are retained with Gateway State by the **Idempotency Retention Rule**.
- "crash recovery" was used to imply command replay. Resolved: unfinished commands are recovered through **Command Reconciliation**, not blind replay.
- "crash recovery repair" was used to imply Gateway may auto-complete missing Audit when Kanban side effects exist. Resolved: missing or contradictory authority evidence is **Authority Chain Divergence** and blocks for Kimi repair decision.
- "reconciliation report" was used as if blocked status alone is enough. Resolved: **Command Reconciliation Report** must include four-source observations, divergence class, replay and synthetic-audit bans, and repair options.
- "events" was used to imply both progress stream and evidence trail. Resolved: **Gateway Events** are a recoverable **Event Projection**; **Audit** remains immutable evidence authority.
- "event corruption" was used to imply run corruption. Resolved: **Projection Inconsistency** does not block a run when **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs remain consistent.
- "event emission" was used to imply progress can be announced before durable writes. Resolved: **Event Emission Gate** makes Events post-commit projections only.
- "event append failure" was used to imply mutating command failure. Resolved: if authority writes are durable, Gateway returns a **Projection-Degraded Command Result** instead of inviting duplicate retries.
- "degraded" was used as if it might be a run status or generic warning. Resolved: **Degradation Status** applies to artifacts, backends, projections, and evidence only, and every degraded or recovered artifact needs a **Degradation Record**.
- "degraded evidence" was used as if Kimi could treat it as completion evidence by default. Resolved: **Degradation Policy** denies completion evidence by default; artifact-family exceptions require recorded acceptance, and **Template Debate Fallback** never counts as required debate coverage.
- "Hermes Agent Master" was used to imply Hermes is the whole-system top-level orchestrator. Resolved: **Kimi** is the external upper orchestrator; **Hermes Execution Framework** is the lower execution layer.
- "Gateway technology stack" was used as if the full system might require a new Node, Go, or shared-database service. Resolved: the **Gateway Runtime Contract** extends the current Python local HTTP Gateway with JSON Run Projection operations, optional `/v1/*` proxying, and filesystem-backed State, Audit, Events, command journals, and idempotency records as the default.

## Session Progress

- Full-system reconstruction now uses Get笔记 `qnN4o510` as the design knowledge source and treats Phase 19 as historical material only.
- Created `.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md` as the canonical full-spec entry point.
- Confirmed Full Debate Package shape: 16 canonical teams, at least 3 member personas per team, 8 canonical modes, dynamic assembly, package-defined coverage, configurable backend policy, and auditable member fan-out.
- Confirmed canonical debate teams from the qnN4o510 registry: `security`, `compliance`, `data_engineering`, `devops_sre`, `frontend`, `ai_feature`, `scalability_arch`, `chaos_engineering`, `platform`, `privacy_ethics`, `oss_compliance`, `observability`, `business`, `documentation`, `api_design`, `i18n_l10n`.
- Recorded ADR [0001](docs/adr/0001-full-debate-package-team-registry.md) for making the qnN4o510 registry the canonical Full Debate Package team id authority.
- Confirmed canonical debate modes from the qnN4o510 registry: `sequential_review`, `parallel_debate`, `adversarial_debate`, `jury_panel`, `dynamic_assembly`, `meta_review`, `risk_priority_matrix`, `cross_team_conflict_detector`.
- Recorded ADR [0002](docs/adr/0002-full-debate-package-mode-registry.md) for making the qnN4o510 registry the canonical Full Debate Package mode id authority.
- Confirmed default member personas so far:
  - `security`: `threat_modeler`, `secrets_auditor`, `policy_guardian`.
  - `compliance`: `legal_reviewer`, `internal_policy_reviewer`, `ethics_reviewer`.
  - `data_engineering`: `pipeline_reliability_reviewer`, `data_quality_reviewer`, `data_architecture_reviewer`.
  - `devops_sre`: `deployment_pipeline_reviewer`, `slo_reliability_reviewer`, `automation_iac_reviewer`.
  - `frontend`: `ux_flow_reviewer`, `frontend_performance_reviewer`, `compatibility_accessibility_reviewer`.
  - `ai_feature`: `model_fit_reviewer`, `prompt_contract_reviewer`, `human_ai_interaction_reviewer`.
  - `business`: `value_reviewer`, `cost_reviewer`, `acceptance_reviewer`.
  - `platform`: `platform_architecture_reviewer`, `maintainability_reviewer`, `infrastructure_fit_reviewer`.
  - `privacy_ethics`: `data_privacy_reviewer`, `ai_ethics_reviewer`, `content_safety_reviewer`.
  - `scalability_arch`: `capacity_planning_reviewer`, `horizontal_scaling_reviewer`, `resource_efficiency_reviewer`.
  - `chaos_engineering`: `fault_injection_reviewer`, `resilience_reviewer`, `blast_radius_reviewer`.
  - `oss_compliance`: `license_compliance_reviewer`, `dependency_security_reviewer`, `sbom_provenance_reviewer`.
  - `observability`: `monitoring_alerting_reviewer`, `tracing_reviewer`, `logging_metrics_reviewer`.
  - `documentation`: `coverage_reviewer`, `accuracy_reviewer`, `maintainability_docs_reviewer`.
  - `api_design`: `contract_versioning_reviewer`, `api_security_rate_limit_reviewer`, `developer_experience_reviewer`.
  - `i18n_l10n`: `translation_completeness_reviewer`, `locale_format_reviewer`, `rtl_multilingual_reviewer`.
- All sixteen canonical teams now have at least three confirmed default member personas.
- Resolved former `architecture` persona mapping: `architecture` is not a canonical team; `system_architect` is the old semantic source for `platform_architecture_reviewer`, `dependency_reviewer` is the old semantic source for `dependency_security_reviewer`, and `migration_risk_reviewer` is a migration-specific checklist candidate rather than a default `scalability_arch` member.
- Resolved mode registry mismatch: `dynamic_assembly` is canonical; `tradeoff_matrix` is not a canonical full-package mode id.
- Confirmed legacy MVP config migration: root `config/debate/teams.json` and `config/debate/modes.json` remain MVP/current runtime registries until explicit cutover; old ids are migration source material only and must not become full-package aliases.
- Confirmed target config artifact shape: stage the Full Debate Package under `config/debate/full/`, with team/mode registries plus separate coverage and backend policy artifacts.
- Confirmed `config/debate/full/teams.json` required fields: root authority markers, team `id/name/focus/dimensions/members`, member `id/focus/dimension_refs/checklist_refs/output_requirements`, exactly sixteen canonical teams, and at least three members per team.
- Confirmed `config/debate/full/modes.json` required fields: root authority markers, mode `id/name/purpose/mechanism/selection_rules/required_inputs/output_contract`, exactly eight canonical modes, no legacy mode ids, and no embedded coverage/backend policy.
- Confirmed Debate Member Opinion required fields: identity, routing, input, opinion content, decision hints, and traceability back to package config without persisting raw prompts, secrets, or raw stdout.
- Confirmed Debate Report required fields: identity, config, input, assembly, coverage/degradation, synthesis, decision handoff, and traceability fields; member details remain linked via `opinion_refs`.
- Confirmed Debate Audit Trail required fields: identity, config snapshot, assembly record, invocation records, synthesis refs, and safety flags without persisting raw prompts, secrets, raw stdout, or long-form body text.
- Confirmed backend adapter protocol: all API, CLI, Hermes delegation, and MoA backends receive a common invocation envelope and return schema-valid Debate Member Opinion artifacts plus invocation status; template or simulation backends are degraded fixtures only.
- Confirmed Debate Member Invocation Envelope required fields: identity, routing, backend contract, scoped input, persona contract, safety, and expected output fields; it is adapter input, not a durable full prompt archive.
- Confirmed Tmux Worker Session lifecycle and retention: task-scoped ephemeral sessions, `worker_session_record`, configurable short-lived transcript retention, timeout/heartbeat/termination records, and cleanup of completed or abandoned sessions.
- Confirmed Worker Workspace parallel merge/review strategy: `parallel_group_plan`, isolated workspaces, explicit write scopes, `conflict_scan`, serial integration merge with tests/review gates, and `merge_conflict_report` for Kimi decision on conflicts.
- Confirmed Release Pipeline project configuration schema: `config/release/pipeline.json` with target type, environments, gates, command refs, approval policy, rollback policy, and release evidence requirements.
- Confirmed Remote Decision Channel adapter contract: disabled by default, transports decision requests/responses only, preserves local approval semantics, validates replay/expiry/binding/fixed phrase through Gateway, and cannot directly mutate workflow state.
- Created `docs/knowledge/qnN4o510-synthesis.md` to record local source inventory, design knowledge map, and spec traceability for the external Get笔记 knowledge source.
- Clarified knowledge boundary: Get笔记 `qnN4o510` is an external requirements/design source only; project runtime specialized-domain knowledge must be implemented separately as a Runtime Domain Knowledge Base.
- Confirmed Runtime Domain Knowledge Base storage direction: gbrain with local PGLite brain and CLI/MCP integration surfaces; Hermes should not build a separate SQLite runtime KB.
- Confirmed Runtime Domain Knowledge Base entry schema: gbrain markdown page with YAML frontmatter, stable `domain/<domain>/<topic>/<short-id>` slug, required evidence/applicability/guidance sections, typed links, and `candidate_knowledge` before verified promotion.
- Confirmed Runtime Domain Knowledge Base ingestion policy: use gbrain CLI/MCP operations, keep unverified material as `candidate_knowledge`, promote only with source/evidence/applicability/checklist fields, and write a Knowledge Ingestion Record for promotion, overwrite, supersession, or deprecation.
- Confirmed Runtime Domain Knowledge Base retrieval contract: gbrain hybrid retrieval via CLI/MCP, query/result artifacts, default `domain_knowledge` only, warnings for candidate or expired entries, and no strong-evidence use without freshness and source refs.
- Confirmed Runtime Domain Knowledge Base freshness/provenance/redaction/audit policy: fixed re-verification windows by entry type, source hierarchy, sensitive-data redaction, query/result audit artifacts, ingestion records, and no Human Approval bypass.
- Closed Runtime Domain Knowledge Base grill branch and marked `.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md` ready for implementation planning.
- Created `.planning/specs/HERMES-ORCHESTRA-FULL-PRD.md` as the full-system PRD for implementation triage, covering Full Debate Package, worker execution, gbrain-backed Runtime Domain Knowledge Base, release pipeline, remote decisions, authority boundaries, and tests.
- Confirmed Full Schema Package packaging: add full-system schema docs and machine schema in parallel rather than replacing the MVP/current runtime schema before full implementation cutover; recorded ADR [0003](docs/adr/0003-full-schema-package-parallel-to-mvp-schema.md).
- Confirmed Full Schema Guardrail Boundary: first full schema strictly validates authority/routing/evidence/degradation/freshness/safety fields while keeping deep content bodies structurally typed but not over-specified; recorded ADR [0004](docs/adr/0004-full-schema-guardrail-strictness.md).
- Confirmed Full Schema Coverage Set: first full schema covers Gateway authority, Six-Stage evidence, Full Debate Package, Worker execution, Runtime Domain Knowledge Base, Release, and decisions.
- Confirmed Staged Full Debate Config: create `config/debate/full/teams.json`, `modes.json`, `coverage-policy.json`, and `backend-policy.json` as the full target package without replacing current MVP runtime debate registries before implementation cutover; recorded ADR [0005](docs/adr/0005-full-debate-config-staged-beside-legacy-runtime-config.md).
- Confirmed Disabled Formal Config pattern: create Release Pipeline, Remote Decision Channel, and Runtime Domain Knowledge Base config at final paths with `enabled: false` so file presence does not imply enabled capability; recorded ADR [0006](docs/adr/0006-full-optional-configs-use-disabled-formal-paths.md).
- Confirmed Full Target Coverage Matrix split: keep `docs/COVERAGE-MATRIX.md` for MVP/current runtime coverage and add `docs/FULL-COVERAGE-MATRIX.md` for full-system target readiness and implementation status.
- Created `.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md` and `config/schemas/orchestra.full.schema.json` as the parallel Full Schema Package while leaving `config/schemas/orchestra.schema.json` as the MVP/current runtime schema.
- Created staged Full Debate Package target configs under `config/debate/full/`: `teams.json`, `modes.json`, `coverage-policy.json`, and `backend-policy.json`.
- Created disabled formal full-system configs: `config/release/pipeline.json`, `config/decisions/remote-channel.json`, and `config/knowledge/runtime-kb.json`.
- Created `docs/FULL-COVERAGE-MATRIX.md` and added a pointer from `docs/COVERAGE-MATRIX.md` to keep full target readiness separate from MVP/current runtime coverage.
- Verified the new JSON files parse successfully; confirmed the staged Full Debate Package has sixteen teams, at least three members per team, and eight modes; confirmed Release Pipeline, Remote Decision Channel, and Runtime Domain Knowledge Base configs remain disabled.
- Confirmed Full Contract Validation path: add an independent validation harness for `orchestra.full.schema.json` and full target configs before any Gateway runtime validation cutover, then use a readiness gate for artifact-family activation.
- Confirmed Command Reconciliation divergence rule: Kanban side effects without matching Audit/State/artifact evidence become **Authority Chain Divergence**, not replay, auto-completion, or synthetic audit repair.
- Confirmed Command Reconciliation Report shape: recovery reports must include journal step status, State/Audit/Kanban/artifact observations, divergence class, replay and synthetic-audit bans, and recommended repair options.
- Recorded ADR [0007](docs/adr/0007-authority-chain-divergence-blocks-command-reconciliation.md) for blocking Command Reconciliation on Authority Chain Divergence instead of replaying side effects or synthesizing Audit.
- Confirmed Gateway Runtime Contract: full-system Gateway extends the current Python local HTTP Gateway, exposes JSON Run Projection operations, may proxy `/v1/*` to upstream Hermes, and keeps filesystem State/Audit/Events/command journals/idempotency as the default authority store; recorded ADR [0008](docs/adr/0008-gateway-runtime-contract-python-local-http.md).
- Confirmed Debate Assembly Policy: Dynamic Debate Assembly uses deterministic stage-floor, task-type overlay, risk overlay, additive project override, and stable member scoring rules rather than model-only team selection.
- Confirmed Worker Capability Negotiation policy: full worker configs are staged under `config/workers/full/`; backend fallback is never implicit and blocked selection produces a Capability Negotiation Report unless an explicit safe fallback is allowed.
- Confirmed Idempotency Retention Rule: idempotency records are Gateway State, have no independent TTL, and must not disappear before the authority side effects they protect.
- Confirmed Degradation Policy: `degraded` is artifact/backend/projection/evidence state, not Run status; degraded evidence does not satisfy required completion evidence by default, and recovery writes replacement evidence.
- Confirmed Gateway Worker Session Sweeper ownership: Gateway performs startup and periodic cleanup of timed-out, missing, or abandoned Tmux Worker Sessions and records cleanup status; cleanup failure blocks the worker task unless workspace or artifact integrity escalates the run.
- Confirmed Conflict Scan semantic boundary: `conflict_scan` and `merge_conflict_report` record `semantic_conflict_detection: "not_claimed"`; semantic compatibility is handled by serial integration tests and review gates.
- Confirmed Kimi-Audited Self Evolution trigger: every Stage 6 runs a candidate-only evolution sweep, while Kimi manually triggers deeper cross-run evolution review.
- Confirmed Candidate Evolution Trigger policy: Stage 6 always writes `system_improvement_proposals`, but non-empty proposals require conservative trigger matches such as authority divergence, cleanup failure, schema failure, debate coverage failure, repeated same-class failures, repeated review/QA changes, or decision-exposed rule/documentation gaps.
- Confirmed Release Pipeline command execution model: deploy and rollback refs resolve through `config/release/commands.json`; Gateway Release Executor owns process execution, approval checks, timeout/kill behavior, redacted output refs, and schema-valid deployment reports; timed-out deploys block instead of pretending rollback succeeded.
- Added `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` as the full-target actor capability map covering Kimi, Human, Gateway, Worker/Backend, release, runtime knowledge, self-evolution, and cutover authority boundaries.
- Added `scripts/bin/orch-full-contract-validate` as the Full Contract Validation Tool; Gateway Full Runtime remains a pending implementation gap while the MVP/current runtime stays active.
- Confirmed MVP-to-full cutover policy: staged by artifact family through `config/cutover/full-readiness-gates.json`; global schema switch and historical artifact rewrites are forbidden.
- Recorded ADR [0014](docs/adr/0014-artifact-family-staged-cutover.md) for artifact-family staged cutover.
- Confirmed Performance SLO Policy: use component target budgets plus degradation actions, not fixed Six-Stage Run completion SLA; human wait is excluded and external backend wait is reported separately.
- Recorded ADR [0015](docs/adr/0015-performance-target-budgets-not-fixed-run-sla.md) for target budgets instead of fixed run SLA.
- Confirmed Full Fixture Policy: split contract fixtures from runtime fake adapters; fixtures must be marked, degraded where applicable, audited, and barred from completion, release, approval, strong debate, or authority repair evidence.
- Recorded ADR [0016](docs/adr/0016-fixtures-split-contract-and-runtime-fakes.md) for fixture layer separation.
- Confirmed Self Evolution Review Queue policy: Stage 6 proposals enter an explicit queue with priority, batching, protected-target, backlog, evidence-quality, and retention rules; rejected proposals are retained with reasons.
- Recorded ADR [0017](docs/adr/0017-self-evolution-uses-explicit-review-queue.md) for explicit review queue behavior.
- No open grill branches remain before implementation planning; remaining items are implementation gaps or adapter plans.
