# Hermes Orchestra

Hermes Orchestra is a local AI engineering workflow that lets an external orchestrator supervise a Hermes-backed execution pipeline without forking upstream Hermes-Agent.

## Language

**Kimi**:
The external upper orchestrator that interprets intent, supervises progress, accepts results, and audits experience.
_Avoid_: embedding Kimi logic inside the Hermes execution core

**Gateway Adapter**:
The project-local API layer that exposes workflow-run operations to Kimi and translates them into Hermes execution activity.
_Avoid_: raw Kanban API, upstream fork

**Run Projection API**:
The product-level Gateway API surface that lets Kimi create, inspect, stop, and decide Six-Stage Runs without operating the Kanban board directly.
_Avoid_: task CRUD API

**Idempotency Key**:
A caller-provided key that makes a mutating Run Projection API command safe to retry without duplicating workflow side effects.
_Avoid_: correlation id, event id

**Command ID**:
The Gateway-assigned identifier for one accepted mutating command, recorded on State, Audit, and Events.
_Avoid_: run id, task id

**Command Journal**:
The write-ahead Gateway State record that stores an accepted command intent and recoverable execution steps before side effects are applied.
_Avoid_: audit trail, cache entry

**Command Reconciliation**:
The startup recovery process that resolves unfinished Command Journal entries from Gateway State, Audit, Hermes Kanban, and artifact refs.
_Avoid_: blind replay

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

**Event Sequence**:
The per-run monotonic `seq` used by Gateway Events and `since_seq` subscriptions to detect gaps.
_Avoid_: global ordering, command id

**Official Hermes API Server**:
The upstream OpenAI-compatible Hermes HTTP server that may run behind the Gateway Adapter for `/v1/*` traffic.
_Avoid_: product workflow API, six-stage run authority

**Hermes Execution Framework**:
The lower execution layer made of Gateway, Hermes-Agent, Kanban, profiles, workers, and evidence plumbing that carries out Kimi-supervised runs.
_Avoid_: top-level product orchestrator, Hermes Agent Master

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

**Structured Ticket**:
The validated intake contract that states background, goal, deliverables, acceptance criteria, constraints, related tasks, and failure strategy before execution begins.
_Avoid_: short intent as execution-ready work

**Structured PRD**:
The run-scoped artifact produced from a Structured Ticket or clarification loop that gates entry into the Six-Stage Run.
_Avoid_: optional documentation

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

**Run Completion Evidence**:
The combined proof from Hermes Kanban lifecycle, Gateway State, Audit, and schema-valid required artifacts that a Six-Stage Run is complete.
_Avoid_: cache hit, model self-report

**Debate Report**:
A structured decision-input artifact produced by the debate engine for a workflow stage.
_Avoid_: final decision, user approval

**Debate Engine**:
The decision engine that runs configured debate teams and modes to produce Debate Reports for direction, solution, risk, and global evaluation stages.
_Avoid_: optional reviewer prompt, single-model self-justification

**Real Debate Backend**:
A non-template LLM/API backend that actually invokes debate roles and produces decision input from model reasoning.
_Avoid_: simulation-only acceptance proof

**Template Debate Fallback**:
A degraded debate backend used for fixtures, schema tests, or environments without a real debate backend.
_Avoid_: strong decision evidence

**Kimi Decision**:
An orchestration decision made by Kimi for low or medium workflow risk below human-risk gates.
_Avoid_: approval for L3/L4 or forbidden automatic modifications

**Human Approval**:
An explicit user approval required before any L3/L4, destructive, publishing, permission, secret, CI/CD, policy, or root-rule modification can proceed.
_Avoid_: timeout approval, agent approval

**System Improvement Proposal**:
A structured Stage 6 recommendation that may include proposed patch references for rules, worker config, debate routing, or workflow configuration.
_Avoid_: applied change

**Kimi-Audited Self Evolution**:
The evolution loop where Hermes gathers candidate learnings and changes, but Kimi audits run evidence before deciding what should be promoted, changed, or summarized.
_Avoid_: autonomous agent self-modification, unsupervised memory growth

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

**Worker Backend**:
A replaceable CLI or API executor selected by role capability for implementation, review, debate, or related work.
_Avoid_: fixed tool name as workflow semantics

**Worker Backend Registry**:
The project config that declares enabled Worker Backends, adapters, health checks, modes, and capabilities.
_Avoid_: hard-coded CLI dispatch

**Worker Role Registry**:
The project config that maps workflow roles to required capabilities, preferred backends, and explicit fallback backends.
_Avoid_: Kimi-selected arbitrary tool

**Capability Negotiation**:
The Gateway step that validates requested worker pairing against registered roles and currently available backend capabilities.
_Avoid_: assuming an installed CLI can perform any role

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
An explicit MVP downgrade where a Worker Backend modifies the project checkout directly because worktree execution is unavailable or unsuitable for the run.
_Avoid_: default worker isolation strategy

## Relationships

- **Kimi** supervises one or more **Six-Stage Runs**
- **Kimi** is the top-level orchestrator; the **Hermes Execution Framework** is the lower execution framework for those runs
- A project may have only one **Active Run**
- A **Blocked Run** is still an **Active Run** and holds the project run slot until it is revised, rejected, stopped, or completed
- A **Blocked Run** may resume in place through approval or create a **Revision Attempt** through a revise decision
- The **Failure Boundary** defaults recoverable workflow problems to **Blocked Run**
- A **Failed Run** must record a **Last Good Checkpoint** when one exists
- A stop request turns an **Active Run** into a **Stopped Run** without approving, rejecting, or deleting its pending evidence
- A **Terminal Run** cannot be resumed in place in MVP
- A new **Six-Stage Run** may reference a failed or stopped **Terminal Run** through **Run Lineage** without mutating the source run
- **Run-Internal Parallelism** may happen inside an **Active Run** when the Development Plan proves tasks are independent
- A **Structured Ticket** or schema-valid **Structured PRD** gates the start of a **Six-Stage Run**
- A **Gateway Adapter** exposes the **Run Projection API** for **Six-Stage Runs**
- Mutating **Run Projection API** commands require an **Idempotency Key**
- The **Gateway Adapter** records one **Command ID** for each accepted mutating command
- The **Command Journal** records command intent before State, Audit, Kanban, or artifact side effects
- **Command Reconciliation** resolves unfinished commands after Gateway restart
- **Audit** and **Gateway Events** include the **Command ID** so retries cannot create duplicate evidence
- **Event Store** belongs to **Gateway State**, not **Audit**
- **Event Retention** keeps the full Event Store with the run State so `since_seq`, SSE resume, and command response refs remain stable
- The **Event Emission Gate** makes **Gateway Events** post-commit projections, never predictions of future State, Audit, Kanban, or artifact changes
- **Gateway Events** form an **Event Projection** for Kimi progress supervision, SSE, and UI updates
- **Event Sequence** is per-run and lets Kimi detect missed or inconsistent **Gateway Events**
- A **Projection Inconsistency** pauses Event-based supervision and requires resync, but does not by itself change a **Six-Stage Run** to **Blocked Run** when **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs are consistent
- A **Projection-Degraded Command Result** is still the idempotency result for the mutating command; retrying the same **Idempotency Key** returns that result and must not duplicate authority side effects
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
- **Debate Engine** produces **Debate Reports** for Stage 1, Stage 2, and Stage 5 of a **Six-Stage Run**
- A **Debate Report** informs **Kimi** but does not replace a **Kimi Decision** or **Human Approval**
- A **Real Debate Backend** should produce at least one **Debate Report** in an MVP acceptance run when available
- **Template Debate Fallback** may scaffold a run but must be recorded as degraded
- A **Kimi Decision** may advance work below human-risk gates
- **Human Approval** is required for L3/L4 and forbidden automatic modification boundaries
- **Global Evaluation** produces a **Global Evaluation Report** before **Final Acceptance**
- **Final Acceptance** may be Kimi-owned only below human-risk gates
- **Continuous Improvement** starts only after **Global Evaluation** has `pass` or Kimi-accepted `pass_with_warnings`
- **Continuous Improvement** writes a **Closeout Report** and **System Improvement Proposals** before any run can complete
- **Kimi-Audited Self Evolution** decides which **System Improvement Proposals**, learnings, skills, or rule changes should actually be promoted
- A **Stopped Run** writes **Partial Closeout** evidence instead of satisfying the **Closeout Completion Gate**
- The **Closeout Completion Gate** validates closeout artifacts, **Audit**, **Hermes Kanban**, and **Gateway State** before a run becomes completed
- **System Improvement Proposals** may lead to future approved changes but do not themselves modify root rule files, CI/CD, policy, or worker/debate/Gateway configuration
- A **Test Plan** must produce a **Test Execution Report** before a **Six-Stage Run** can complete
- A **Review Verdict** or **QA Verdict** may trigger an **Improvement Cycle** but cannot be overwritten by it
- An **Improvement Cycle** is constrained by **Improvement Scope** and must produce an **Improvement Report**
- A **Re-Review Artifact** records post-improvement validation as new evidence
- A **Worker Backend** executes role-scoped tasks under **Hermes Kanban**
- A **Worker Backend Registry** declares available executors, while a **Worker Role Registry** declares which executors may satisfy each role
- **Capability Negotiation** validates Kimi-requested worker pairing before a **Selected Worker Backend** is recorded
- A **Worker Adapter** hides CLI/API differences behind the `hermes-role-engine/v1` role protocol
- A **Worker Context Envelope** gives a **Worker Backend** structured task context, artifact references, risk state, and **Worker Write Scope**
- A **Worker Context Bundle** is read-only and scoped to the task; it must not become raw chat history or a full project dump
- A **Worker Output Envelope** may request completion, but only the **Gateway Advancement Gate** can advance **Gateway State**, **Audit**, or **Hermes Kanban**
- A **Worker Backend** should use a task-scoped **Worker Workspace** before falling back to **Direct Project Fallback**
- An **Artifact Reference** links **Hermes Kanban**, **Gateway State**, and **Audit** without embedding large artifacts in task bodies
- **State Artifacts** support resume, while **Audit Artifacts** support evidence and **Cache Artifacts** support acceleration
- **Repository Knowledge Artifacts** inform future runs but do not store run-scoped raw tickets or temporary state
- **Run Completion Evidence** excludes **Cache Artifacts** and model self-report

## Example dialogue

> **Dev:** "Should `run_id` and `workflow_stage` be stored as Kanban task metadata?"
> **Domain expert:** "No. **Hermes Kanban** is the lifecycle authority, but **Gateway State** owns Orchestra workflow metadata. The **Gateway Adapter** combines both into the task projection Kimi sees."

> **Dev:** "Can Kimi approve a risky change if the debate report recommends it?"
> **Domain expert:** "Only below the human-risk gate. L3/L4 and forbidden automatic modifications require **Human Approval** even when Kimi recommends proceeding."

> **Dev:** "Can the implementer just edit the project checkout?"
> **Domain expert:** "Only as **Direct Project Fallback**. The default code path should use a task-scoped **Worker Workspace** so implementation, review, and audit can separate worker changes from existing user changes."

> **Dev:** "Does Stage 6 automatically update `AGENTS.md` after Kimi audits a run?"
> **Domain expert:** "No. **Continuous Improvement** writes a **System Improvement Proposal** and patch references. Root rule-file changes require **Human Approval** before application."

> **Dev:** "Can Curator promote a repeated worker lesson to global memory by itself?"
> **Domain expert:** "No. Curator may surface candidates, conflicts, or review tasks, but **Kimi-Audited Self Evolution** decides what becomes durable shared knowledge."

> **Dev:** "Does MVP need Redis because the production premise mentions Redis?"
> **Domain expert:** "No. **Local Filesystem Cache** is the default. **Redis Cache Adapter** is optional, must keep the same adapter interface, and must not become canonical state."

> **Dev:** "Can a template debate report satisfy the decision engine requirement?"
> **Domain expert:** "Only as **Template Debate Fallback**. If a **Real Debate Backend** is available, at least one core debate stage should use it; template output is scaffold evidence, not strong decision evidence."

> **Dev:** "Can the full workflow skip debate and let the implementer justify its own plan?"
> **Domain expert:** "No. The **Debate Engine** is a first-class decision subsystem; implementer reasoning can inform work, but **Debate Reports** are separate inputs to Kimi."

> **Dev:** "Can Kimi send a short intent and immediately start implementation?"
> **Domain expert:** "No. A short intent can start intake, but execution waits for a schema-valid **Structured Ticket** or **Structured PRD** with acceptance criteria, constraints, and failure strategy."

> **Dev:** "Can Kimi create or link Kanban tasks directly through the Gateway?"
> **Domain expert:** "No. Kimi uses the **Run Projection API**. **Task Projection** is read-only; Kanban mutations happen internally through workflow rules."

> **Dev:** "Can two runs modify the same project at the same time?"
> **Domain expert:** "No. MVP allows one **Active Run** per project. **Run-Internal Parallelism** is allowed only for independent work declared in the Development Plan."

> **Dev:** "Is writing `test_plan.json` enough to satisfy AI testing?"
> **Domain expert:** "No. A **Test Plan** must be executed, and the resulting **Test Execution Report** must record the commands and outcomes."

> **Dev:** "Can a cache hit prove the run is complete?"
> **Domain expert:** "No. **Run Completion Evidence** comes from **Hermes Kanban**, **Gateway State**, **Audit Artifacts**, and schema-valid required artifacts. **Cache Artifacts** can speed recomputation, but they never decide completion."

> **Dev:** "Can Kimi choose any installed CLI as reviewer?"
> **Domain expert:** "No. Kimi may request a pairing, but **Capability Negotiation** must confirm it is registered, role-compatible, and available before the Gateway records a **Selected Worker Backend**."

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

> **Dev:** "If the Gateway crashes after creating Kanban tasks but before returning the run response, should restart replay the command?"
> **Domain expert:** "No. **Command Reconciliation** first checks **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs. It completes, continues, or blocks from evidence; it never blindly replays."

> **Dev:** "Can Kimi advance a run just because the latest SSE event says a stage completed?"
> **Domain expert:** "No. **Gateway Events** are a recoverable **Event Projection**. Kimi must resync from run status, task projection, and authoritative artifact refs if **Event Sequence** has a gap or looks stale."

> **Dev:** "If the event stream is corrupt but State, Audit, and Kanban all agree, should the run become blocked?"
> **Domain expert:** "No. That is a **Projection Inconsistency**, not a workflow blocker. Rebuild or resync the **Event Projection**; only authority-chain inconsistency can block or fail the run."

> **Dev:** "Can Gateway emit `stage_completed` before Audit and Kanban completion are durable?"
> **Domain expert:** "No. The **Event Emission Gate** appends Events only after the authority records they summarize are durable. Events cannot pre-announce state transitions."

> **Dev:** "If the authority writes succeed but appending the event fails, should Kimi retry the command?"
> **Domain expert:** "No. Return a **Projection-Degraded Command Result** and repair the **Event Projection**. Retrying the same **Idempotency Key** must not repeat the authority writes."

## Flagged ambiguities

- "Kanban metadata" was used to mean both upstream Hermes Kanban run metadata and Orchestra workflow metadata. Resolved: **Hermes Kanban** owns lifecycle state; **Gateway State** owns workflow metadata.
- "run" was used to mean both **Six-Stage Run** and **Agent Run**. Resolved: `/orchestra/runs` means **Six-Stage Run**; official `/v1/runs` remains an upstream **Agent Run** surface.
- "final decision authority" was used for both Kimi orchestration decisions and user approvals. Resolved: **Kimi Decision** is final below human-risk gates; **Human Approval** is final for L3/L4 and forbidden automatic modification boundaries.
- "worker isolation" was used to mean both ideal per-task isolation and direct repo execution. Resolved: **Worker Workspace** is the default; **Direct Project Fallback** is an explicit MVP downgrade.
- "system evolution" was used to imply automatic rule-file edits. Resolved: **Continuous Improvement** produces **System Improvement Proposals**; root rule-file application requires **Human Approval**.
- "self evolution" was used to imply automatic agent growth. Resolved: **Kimi-Audited Self Evolution** requires Kimi audit before promotion, rule changes, skill changes, or durable experience summaries.
- "cache" was used to imply both required Redis and local cache. Resolved: **Local Filesystem Cache** is the default; **Redis Cache Adapter** is an optional adapter interface implementation, not a required runtime dependency.
- "template debate" was used to imply both fixture scaffolding and real decision work. Resolved: **Real Debate Backend** is preferred for acceptance when available; **Template Debate Fallback** is degraded scaffold output.
- "debate" was used to imply optional reviewer commentary. Resolved: **Debate Engine** is a first-class subsystem in the full workflow, producing separate **Debate Reports** for Kimi.
- "intent" was used to imply execution-ready input. Resolved: short intent is intake-only; **Structured Ticket** or schema-valid **Structured PRD** is required before six-stage execution starts.
- "tasks API" was used to imply both projection and mutation. Resolved: **Task Projection** is read-only; Gateway must not expose raw Kanban CRUD to Kimi in MVP.
- "parallel execution" was used for both multi-run concurrency and safe child-task parallelism. Resolved: one **Active Run** per project; **Run-Internal Parallelism** is allowed only with an explicit independence policy.
- "AI testing" was used to imply both test planning and test execution. Resolved: **Test Plan** must be executed and produce a **Test Execution Report** before completion.
- "artifact" was used for state, evidence, cache, and project knowledge. Resolved: **State Artifacts** restore runs, **Audit Artifacts** prove what happened, **Cache Artifacts** are rebuildable, and **Repository Knowledge Artifacts** are long-lived project knowledge.
- "worker pairing" was used to imply Kimi can pick arbitrary tools. Resolved: Kimi may request a pairing, but **Worker Backend Registry**, **Worker Role Registry**, and **Capability Negotiation** decide whether it can run.
- "worker context" was used to imply raw chat history or all project files. Resolved: workers receive a **Worker Context Envelope** and scoped **Worker Context Bundles** only.
- "worker complete" was used to imply direct task completion. Resolved: worker output is a request; **Gateway Advancement Gate** owns state and lifecycle advancement.
- "review failed" was used to imply either optional feedback or hard rejection. Resolved: **Review Verdict** and **QA Verdict** use explicit verdicts, and non-approval routes through **Improvement Cycle**, Kimi decision, or Human Approval.
- "improvement" was used to imply both bounded repair and scope-changing redesign. Resolved: Stage 4 automatic **Improvement Cycle** is bounded by **Improvement Scope**; redesign requires decision routing.
- "final acceptance" was used to imply closeout can trust completed subtasks. Resolved: **Global Evaluation** must produce a verdict before **Final Acceptance** and Stage 6.
- "closeout" was used to imply a Stage 6 self-report can complete the run. Resolved: **Closeout Report** is evidence; **Closeout Completion Gate** decides completion from closeout artifacts, **Audit**, **Hermes Kanban**, and **Gateway State**.
- "cancel" was used to imply destructive cleanup or rejection. Resolved: Kimi-facing cancel maps to stop-and-archive, producing a **Stopped Run** and **Partial Closeout** without resolving pending approvals.
- "resume" was used to mean both unblocking an active run and continuing a terminal run. Resolved: **Blocked Runs** resume in place; stopped or failed **Terminal Runs** continue only through a new run with **Run Lineage**.
- "failed" was used to mean both ordinary task/test failure and terminal run failure. Resolved: ordinary work failure blocks; **Failed Run** is reserved for crossing the **Failure Boundary**.
- "retry" was used to imply re-running a mutating API command. Resolved: mutating commands are deduplicated by **Idempotency Key** and traced by **Command ID**.
- "crash recovery" was used to imply command replay. Resolved: unfinished commands are recovered through **Command Reconciliation**, not blind replay.
- "events" was used to imply both progress stream and evidence trail. Resolved: **Gateway Events** are a recoverable **Event Projection**; **Audit** remains immutable evidence authority.
- "event corruption" was used to imply run corruption. Resolved: **Projection Inconsistency** does not block a run when **Gateway State**, **Audit**, **Hermes Kanban**, and artifact refs remain consistent.
- "event emission" was used to imply progress can be announced before durable writes. Resolved: **Event Emission Gate** makes Events post-commit projections only.
- "event append failure" was used to imply mutating command failure. Resolved: if authority writes are durable, Gateway returns a **Projection-Degraded Command Result** instead of inviting duplicate retries.
- "Hermes Agent Master" was used to imply Hermes is the whole-system top-level orchestrator. Resolved: **Kimi** is the external upper orchestrator; **Hermes Execution Framework** is the lower execution layer.
