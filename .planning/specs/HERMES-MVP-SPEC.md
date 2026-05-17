# Hermes Orchestra MVP Spec

Date: 2026-05-16
Status: Draft for implementation planning
Source material: `.planning/notes/hermes-mvp-grill-decisions.md`

## 1. Purpose

Build a complete vertical MVP of the Hermes Orchestra architecture. The MVP must run the full workflow happy path end to end, but it is not a production-hardened release.

The goal is a working local single-user pipeline:

`Kimi -> Gateway adapter :8642 -> Hermes Kanban + CLI workers -> debate reports -> implementation/review/test -> audit/closeout`

This document is the execution contract for the next phase. If this spec conflicts with the grill decision note, this spec wins only when it explicitly marks the older decision as superseded.

## 2. Scope

MVP includes:

- Local Gateway adapter on `127.0.0.1:8642`.
- `/orchestra/*` workflow-run API.
- `/v1/*` proxy to optional official Hermes API Server.
- Real official Hermes Kanban usage through `hermes kanban`.
- Six-stage workflow DAG.
- Harness knowledge artifacts under `.workflow/knowledge/`.
- Debate team and mode registries with real-debate support when available and template fallback for degraded/scaffold runs.
- Worker backend registry with real Codex implementer and Claude reviewer by default.
- Official Kanban `worktree` workspace for code worker tasks by default.
- Local filesystem cache.
- AI test-plan and test-execution artifacts.
- State/Audit/Cache artifact URI model.
- Stage 6 closeout plus system improvement proposals.
- End-to-end demo task.

MVP excludes:

- Redis as a required dependency.
- Get笔记 as a runtime dependency.
- Gateway authentication, because MVP is local single-user only.
- Public network exposure.
- Automatic CI/CD modification.
- Automatic root `AGENTS.md`, `CLAUDE.md`, or `SOUL.md` modification.
- Container isolation per task.
- Same-project parallel runs and merge arbitration.
- UI automation platform integration.
- Automatic official Hermes API Server startup.

## 3. Architecture

Layers:

- Upper orchestration: Kimi stays external and supervises intent, progress, acceptance, and audit.
- Communication access: local Gateway adapter owns port `8642`.
- Execution framework: Hermes Agent + official Kanban + CLI workers.
- Decision engine: 16 debate teams and 8 debate modes via registries.
- Data support: local project knowledge base plus local filesystem cache.

Get笔记 knowledge base `qnN4o510` was used only as planning background. Runtime config, artifacts, and worker prompts must not depend on it.

The local filesystem cache is an explicit MVP downgrade from the `qnN4o510` production premise that pairs local knowledge with Redis cache. Redis remains a future optional cache adapter, not a required MVP dependency and never a canonical state store.

## 4. Gateway

Gateway process:

- Entrypoint: `scripts/bin/orch-gateway`.
- Implementation target: `scripts/lib/orch_gateway.py`.
- Technology: Python standard library `http.server` and small local router.
- Host default: `127.0.0.1`.
- Port default: `8642`.
- Upstream API URL default: `http://127.0.0.1:8643`.

Routes:

- `GET /health`
- `GET /orchestra/capabilities`
- `POST /orchestra/runs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`
- `POST /orchestra/runs/{run_id}/stop`
- `POST /orchestra/decisions/{decision_id}`
- `/v1/*` reverse proxy to official Hermes API Server

Gateway does not start the official Hermes API Server. If upstream is unavailable, `/health` reports `upstream_api: degraded`, `/v1/*` returns `502`, and `/orchestra/*` continues to work.

The Orchestra run API is intentionally separate from the official Hermes API Server run surface. `/orchestra/runs` means a six-stage product workflow run owned by the Gateway Adapter; official `/v1/runs` remains an upstream agent-run/session surface and must not be redefined as the six-stage workflow contract. This explicitly supersedes any earlier wording that implied the official API Server run model should carry Orchestra workflow semantics.

Gateway must not expose raw Kanban CRUD as a Kimi-facing API in MVP. There is no `/orchestra/tasks/{id}/create`, `/orchestra/tasks/{id}/edit`, `/orchestra/tasks/{id}/link`, `/orchestra/tasks/{id}/complete`, or `/orchestra/tasks/{id}/block` surface. `GET /orchestra/runs/{run_id}/tasks` is a read-only projection. Internal calls to `hermes kanban create/link/complete/block/unblock` must be driven by workflow rules, structured artifacts, and decision authority routing.

Authentication is out of MVP scope. This is a deliberate local-only downgrade. The Gateway must bind to `127.0.0.1` by default and must not be exposed publicly without adding authentication.

Mutating command idempotency:

- `POST /orchestra/runs`, `POST /orchestra/decisions/{decision_id}`, and `POST /orchestra/runs/{run_id}/stop` require `idempotency_key`.
- The Gateway scopes idempotency by project, endpoint, resource path, and `idempotency_key`.
- Idempotency replay is checked before active-run conflict checks, so a retry of the original run-create command returns the original result instead of `409 active run`.
- On first accepted command, Gateway stores a `command_id`, request payload hash, resulting resource refs, response summary, event refs, and audit refs.
- Same scope + same `idempotency_key` + same canonical payload returns the original command result and must not create a second run, decision resolution, stop marker, Kanban task, Event, or Audit evidence record.
- Same scope + same `idempotency_key` + different canonical payload returns `409 conflict`.
- If the original command is still in progress, retry returns the existing command status and resource refs without creating duplicate side effects.
- If all authoritative State, Audit, Kanban, and artifact side effects succeed but Event append fails, the mutating command response is still successful and replayable. It must include `event_projection_degraded: true`, `projection_status: inconsistent`, and projection issue refs. Retrying the same `idempotency_key` returns the same authority result and must not repeat side effects.
- Audit and Events produced by mutating commands must include `command_id`.
- `command_id` is evidence correlation only. It is not run identity, task identity, resume authority, or completion authority.
- Idempotency records are Gateway State. They may be referenced by Audit, but cache must not be used as command dedupe authority.

Command journal and write-ahead order:

- After request schema and idempotency validation, Gateway writes a Gateway State `command_record` with `status: in_progress`, `command_id`, canonical payload hash, command intent, and planned side-effect steps before applying State, Audit, Kanban, worker, or artifact side effects.
- Command side effects execute as journaled steps. Each step records `step_id`, `target_authority`, `operation`, `status`, and verifiable refs such as State refs, Audit refs, Kanban task ids, artifact refs, or response refs.
- Gateway must not issue a workflow side effect that is not represented in the command journal.
- For run creation, command journal is written before creating the parent Kanban task, six stage tasks, run State, run-created Event, or Audit entries.
- For decision commands, command journal is written before decision resolution, revised child task creation, State/Audit writes, or Kanban lifecycle changes.
- For stop commands, command journal is written before cancel markers, `run_stopped`, stop Audit, partial closeout, or scheduling changes.
- Event append steps are projection steps and must run after the authoritative State, Audit, Kanban, or artifact refs they report are durable.
- Gateway marks a command `completed` after all required authoritative side-effect refs are durable and the response summary is stored. Event append failure may complete the command with degraded projection metadata instead of failing the command.
- If a command step fails, Gateway records the failed step and routes through the existing blocked/failed boundary. It must not erase the command journal.

Command crash recovery:

- On startup, Gateway scans Gateway State for `command_record.status: in_progress`.
- For each in-progress command, Gateway reconciles recorded steps against Gateway State, Audit, Hermes Kanban, and artifact refs.
- If reconciliation proves the command completed, Gateway backfills missing response refs and marks the command `completed` without re-executing side effects.
- If reconciliation proves a step has not executed, Gateway may continue from the next unexecuted journaled step.
- If reconciliation cannot prove whether a side effect happened, Gateway marks the related run or task `blocked`, emits `decision_required`, records `command_reconciliation_report`, and does not blindly replay the command.
- Recovery decisions must prefer preserving evidence over progress. Cache, worker summaries, and stdout are not reconciliation authority.

Events and Audit authority:

- `GET /orchestra/runs/{run_id}/events` exposes a Gateway Event Projection for Kimi progress supervision, SSE, and UI updates. It is not the evidence authority for run completion, resume, or recovery.
- Events are append-only within one run and ordered by a per-run monotonic `seq`. JSON polling uses `since_seq` and `limit`; SSE uses the same per-run sequence order.
- Event payloads include `command_id` when caused by a mutating command, summary messages, and scoped artifact refs. They must not include raw prompts, secrets, full worker stdout/stderr, large report bodies, or absolute local paths.
- Event emission is post-commit. Gateway must not append an Event until the State, Audit, Hermes Kanban, or artifact change the Event reports is durable and can be referenced or re-read.
- Events must not pre-announce stage completion, task completion, decision resolution, stop, failure, artifact write, or run completion. If the authoritative write fails, the Event must not be emitted.
- If Event append fails after authoritative refs are durable, Gateway treats it as Projection Inconsistency and recovers or rebuilds the Event Projection. It must not roll back durable State, Audit, Kanban, or artifact changes solely because the Event append failed.
- Mutating commands with durable authority writes and failed Event append return a successful authority result with projection degradation fields, not a generic failure. This prevents Kimi from retrying the command and duplicating side effects.
- Missing or corrupt Event Projection data may be rebuilt from Gateway State, Audit, Hermes Kanban, and artifact refs. Rebuild must not invent Audit evidence.
- Audit is immutable evidence authority. Audit cannot be reconstructed from Events, and Events must not be treated as a replacement for Audit records.
- Event-only projection damage does not change run status to `blocked`, `failed`, or `stopped` when Gateway State, Audit, Hermes Kanban, and required artifact refs are complete and mutually consistent. Gateway should mark the projection `inconsistent` or rebuild it, and Kimi should resync before acting on Events.
- If the projection cannot be rebuilt because Gateway State, Audit, Hermes Kanban, or required artifact refs are themselves inconsistent or missing, the run follows the normal blocked-vs-failed authority boundary.
- MVP Event Store retention has no TTL, no truncation, and no per-event compression for active or terminal runs. If future archival is needed, it must archive the whole run State or preserve a complete sequence manifest; it must not delete a middle or prefix range that breaks `since_seq`, SSE resume, command response refs, or projection rebuild.
- Kimi should subscribe with `since_seq`. If Kimi observes a sequence gap, duplicate sequence, stale projection, or projection inconsistency, it must resync via `GET /orchestra/runs/{run_id}`, `GET /orchestra/runs/{run_id}/tasks`, and `GET /orchestra/runs/{run_id}/events` before making further decisions.
- Kimi must not advance workflow state from stale Events. Mutating decisions and stop requests must be based on current run status, task projection, decision refs, and authoritative artifact refs.

## 5. Run API

`POST /orchestra/runs` accepts:

- `idempotency_key`
- `intent`
- optional structured `ticket`
- `options`
- optional `source_run_id`
- optional `resume_from_refs`

`intent` and `ticket` cannot both be absent. If only `intent` is provided, Gateway normalizes it into `structured_prd.json` and emits `ticket_normalized`.

Short `intent` is an intake input, not execution-ready work. Before the six-stage DAG starts, the Gateway must have either a structured `ticket` or a schema-valid `structured_prd.json` with requirement summary, acceptance criteria, constraints, risks, and failure strategy. If normalization cannot produce those fields, the run must stay `blocked` and emit `decision_required` with `authority_required: kimi`; it must not enter `direction_debate`.

Kimi should prefer sending a structured `ticket`. Short `intent` is acceptable for smoke/demo intake or draft generation, but it does not bypass the structured PRD gate.

MVP run mode supports only `mvp_full`.

Response includes:

- `schema_version`
- `command_id`
- `idempotency_key`
- `run_id`
- `status`
- `source_run_id`
- `lineage_ref`
- `run_uri`
- `events_url`
- `tasks_url`

`source_run_id` and `lineage_ref` are null unless the run was created from a terminal source run.

Run statuses:

`queued | running | blocked | failed | completed | stopped`

Only one active run is allowed per project. Active statuses are `queued`, `running`, and `blocked`. A second run request returns `409 conflict`.

The one-active-run rule applies at the Six-Stage Run level. Run-internal parallelism is allowed only when the workflow stage and `development_plan.json.parallelism_policy` prove tasks are independent.

Status and stop semantics:

- `blocked` is an active, recoverable state. It does not write completion closeout and does not release the one-active-run slot.
- A blocked run must preserve current Gateway State, Audit entries, Kanban task states, artifact refs, blocker reason, pending decision refs, and resume checkpoints.
- `stop` is the canonical Kimi-facing operation; UI or conversational `cancel` maps to `POST /orchestra/runs/{run_id}/stop`.
- `stop` may be requested for `queued`, `running`, or `blocked` runs and moves the run to terminal `stopped`.
- `stop` is stop-and-archive behavior, not destructive cleanup. It must not delete State, Audit, Cache, repo artifacts, Kanban tasks, or existing worker evidence.
- Stopping a run emits `run_stopped`, writes Audit evidence, stops future scheduling, and writes cancel markers for this run's bound workers.
- `force=true` may only terminate this run's bound runner process or session. It must not kill global tmux sessions, unrelated workers, or unrelated runs.
- Stopping does not approve, reject, or revise any pending decision, including pending L3/L4 or Human Approval items. Those decisions remain recorded as unresolved.
- A stopped-before-completion run writes partial closeout evidence with `closeout_kind: stopped_before_completion`. This is not Stage 6 completion and must not satisfy the `completed` acceptance path.
- Later resume or revise must restore from Hermes Kanban lifecycle plus Gateway State, State Artifacts, and Audit Artifacts. Cache objects, worker summaries, and partial closeout text are not resume authority.

Resume, revise, and lineage semantics:

- `blocked` runs recover in place through the decision API.
- `approve` on a blocked decision resumes the original task or stage attempt from validated artifact refs, writes `decision_resolved`, and preserves the prior blocker evidence in Audit.
- `revise` on a blocked decision creates a revised child task or revised stage attempt inside the same run. It must set `revision_of`, link source artifact refs, and write new artifacts instead of overwriting original artifacts.
- `reject` keeps the rejected evidence immutable and routes the current task, stage, or run to blocked or failed according to recoverability and authority routing.
- `failed` and `stopped` are terminal run statuses in MVP. They must not transition back to `queued`, `running`, or `blocked`.
- Continuing after `failed` or `stopped` requires a new `POST /orchestra/runs` request with `source_run_id` and `resume_from_refs`.
- A lineage run receives a new `run_id`, emits a new `run_created` event, and records `source_run_id`, source terminal status, and validated `resume_from_refs` in Gateway State and Audit.
- The source run remains read-only for workflow continuation. The new run may read source Gateway State, State Artifacts, Audit Artifacts, Kanban task projection, and scoped artifacts, but it must not mutate the source run.
- `resume_from_refs` must be scoped artifact refs from the source run. Cache refs and worker summaries may be included as background only when rebuildable, but they are never resume authority.
- Creating a new run from a `blocked` source run is rejected in MVP because the blocked run is still active and holds the one-active-run slot.

## 6. Workflow

Top-level DAG:

`direction_debate -> solution_debate -> implementation -> improvement -> global_evaluation -> continuous_improvement`

Fixed stage artifacts:

- `best_choice_report.json`
- `implementation_plan_report.json`
- `task_feedback_report.json`
- `improvement_report.json`
- `global_evaluation_report.json`
- `iteration_closeout_report.json`

Stage 6 `continuous_improvement` additionally writes `system_improvement_proposals.json`. The stage may auto-update low-risk `.workflow/knowledge/*` files, but it must not automatically modify root `AGENTS.md`, root `CLAUDE.md`, `hermes/SOUL.md`, CI/CD, install scripts, permission/risk policy, worker backend config, debate routing config, or Gateway/runtime configuration. For those targets, Stage 6 may write proposal records and `proposed_patch_refs`; applying them requires the decision authority routing in Section 13, including Human Approval for root rule-file or high-risk changes.

Stage 6 closeout boundary:

- Stage 6 `continuous_improvement` may start only after `global_evaluation_report.json` has verdict `pass` or Kimi-accepted `pass_with_warnings`.
- Stage 6 must write `iteration_closeout_report.json` and `system_improvement_proposals.json`.
- `iteration_closeout_report.json` records final acceptance, accepted warnings, downgraded capabilities, unresolved or deferred decisions, executed tests and reviews, worker fallbacks, knowledge updates, and future proposal refs.
- Only low-risk `.workflow/knowledge/*` updates may be auto-applied during Stage 6.
- Root `AGENTS.md`, root `CLAUDE.md`, `hermes/SOUL.md`, CI/CD, install scripts, permission/risk policy, worker backend config, debate routing config, and Gateway/runtime configuration are proposal-only targets in MVP and require approval before application.
- The run may become `completed` only after closeout artifacts are schema-valid, Audit records the closeout evidence, all required Kanban stage tasks are done, and Gateway State agrees with the artifact and decision refs.
- `iteration_closeout_report.json` and `system_improvement_proposals.json` are evidence, not completion authority by themselves.

Implementation sub-DAG may include:

- `prd_preprocess`
- `dev_workflow_plan`
- `code_task_*`
- `review_task_*`
- `qa_task_*`

Existing `pm -> implementer -> reviewer -> qa(optional)` remains an engineering sub-DAG inside implementation and improvement, not the top-level workflow.

Stage 4 `improvement` boundary:

- Automatic improvement is limited to one cycle per run by default.
- Automatic improvement may fix only findings from review, QA, or test evidence that are inside the approved `development_plan.json` scope.
- Automatic improvement may repair code defects, tests, artifact gaps, or implementation drift against approved acceptance criteria.
- Automatic improvement must not expand requirements, change architecture direction, change risk policy, modify worker backend config, modify debate routing config, modify Gateway/runtime configuration, or touch any Human Approval target.
- Automatic improvement must not proceed when required fixes require L3/L4 approval, forbidden automatic modification targets, external publish/write, secret/permission changes, CI/CD changes, or root rule-file changes.
- Each improvement cycle writes `improvement_report.json` with source feedback refs, failure class, scope assessment, changed files, diff summary, tests run, test results, and re-review/re-test refs.
- Improvement output must trigger re-review and/or re-test for the original failing criteria before advancement.
- If re-review, QA, or tests still fail after one automatic improvement cycle, the run becomes `blocked` and emits a decision requirement. Kimi or Human Approval then chooses `revise`, chooses `reject`, or requests stop through the run stop endpoint according to authority routing.

Stage 5 `global_evaluation` boundary:

- Global evaluation is an independent audit stage before Stage 6 closeout.
- It must read `structured_prd.json`, `development_plan.json`, debate reports, implementation evidence, review and QA verdicts, test execution reports, improvement reports, downgrade records, unresolved decision records, and relevant Audit entries.
- It writes `global_evaluation_report.json`.
- Verdict enum is `pass | pass_with_warnings | fail | block`.
- `pass` may proceed to Stage 6 when the Gateway Advancement Gate confirms required artifacts, tests, review/QA verdicts, and decision records are valid.
- `pass_with_warnings` requires Kimi Final Acceptance before Stage 6 and must record warning refs, residual risk, and rationale.
- `fail` may return to Stage 4 only if automatic improvement budget remains, findings are inside the approved `development_plan.json` scope, and no human-risk gate is hit. Otherwise it blocks and emits a decision requirement.
- `block` routes to Kimi or Human Approval according to the decision authority chain.
- Kimi is the final acceptance authority for low and medium risk only. Kimi must not override L3/L4, schema failure, test failure, write-scope violation, security boundary, forbidden target, or Human Approval boundary.
- Stage 6 `continuous_improvement` must not start until global evaluation is `pass` or Kimi-accepted `pass_with_warnings`.

Parallelism boundary:

- Top-level six-stage execution is serial.
- `global_evaluation` may run debate teams in parallel through `parallel_debate`.
- `implementation` may run read-only or non-overlapping child tasks in parallel.
- Code-changing child tasks default to serial execution unless `development_plan.json.parallelism_policy` declares disjoint write sets and the tasks use `kanban_worktree`.
- Same-project parallel Six-Stage Runs, merge arbitration, and automatic conflict resolution are out of MVP scope.

## 7. Kanban

MVP must use official Hermes Kanban, not a local simulated board.

Gateway startup:

- Run `hermes kanban init`.
- Ensure project board exists.

Run creation:

- Create one parent workflow task.
- Create six stage tasks.
- Link dependencies with `hermes kanban link`.
- Advance task state with official `complete`, `block`, and `unblock`.

Kanban is the canonical task lifecycle source. It owns task existence, native status, parent/child dependencies, assignee, tenant, blocking, and completion. This explicitly supersedes the grill decision note where items 26-32 imply that Orchestra workflow metadata is stored as native Kanban task metadata.

Gateway State is the canonical workflow metadata source for Orchestra semantics:

- `run_id`
- `task_kind`
- `workflow_stage`
- `stage_index`
- `role`
- `backend_preference`
- `artifact_refs`
- `approval_required`
- `risk_level`
- `resume_policy`

Gateway task projection is synthesized from official `hermes kanban list/show` output plus Gateway State, Audit, and artifact references. Local State files are not a simulated Kanban board and must not replace native Kanban lifecycle state.

Gateway task projection is read-only for Kimi. Future task-level control, if needed, must be constrained workflow actions such as a `revise` decision that creates a child task through the normal decision and audit path, not raw board mutation.

Do not extend native Kanban statuses.

## 8. Artifacts

Directory model:

```text
STATE_ROOT/{project}/runs/{run_id}/
STATE_ROOT/{project}/runs/{run_id}/events.jsonl
AUDIT_ROOT/{project}/runs/{run_id}/
CACHE_ROOT/{project}/
{project_dir}/.workflow/knowledge/
```

URI model:

```text
state://{project}/{run_id}/...
audit://{project}/{run_id}/...
cache://{project}/{sha256}
repo://.workflow/knowledge/...
```

Gateway APIs return URIs, not absolute paths. The resolver must validate project/run scope and prevent path traversal.

Artifact authority:

- State stores resumable runtime state: Gateway run metadata, current stage, pending decision IDs, resume checkpoints, artifact refs, and projection helpers. State does not own Kanban lifecycle.
- Audit stores immutable evidence: stage reports, decisions, retries, fallbacks, failures, downgrades, test evidence, and closeout.
- Cache stores rebuildable optimization results only. Cache misses may slow a run, but must not change workflow truth.
- Repo knowledge stores long-lived project knowledge under `.workflow/knowledge/*`. It must not store raw tickets, temporary run requirements, approval state, or resume checkpoints.

Resolver rules:

- `state://` and `audit://` URIs must include the current project and run ID.
- `cache://` URIs must address content by hash and must not include arbitrary filesystem paths.
- `repo://` URIs are limited to `.workflow/knowledge/*`.
- Unknown URI schemes, absolute paths, `..` path segments, and refs outside the project/run scope are invalid.
- Invalid critical State, Audit, or Repo artifact refs block the current stage. Cache misses are rebuilt or reported as degraded; they do not block unless the rebuilt required artifact also fails.

Recovery authority comes from Hermes Kanban lifecycle plus Gateway State, State Artifacts, and Audit Artifacts. Cache objects and model self-report must not be used as resume authority.

Audit artifacts are immutable. Revisions write new versions or child artifacts.

Run completion authority comes from Kanban lifecycle, Gateway State, Audit, and schema-valid required artifacts. A cache hit, generated summary, or worker/model self-report is never sufficient to mark a run `completed`.

Events are projection artifacts for observation. Their primary persisted store is Gateway State, for example `STATE_ROOT/{project}/runs/{run_id}/events.jsonl`, exposed as a `state://` ref when referenced. Events may support Kimi supervision and UI replay, but missing or corrupt Events are rebuilt from Gateway State, Audit, Hermes Kanban, and artifact refs. Events cannot rebuild Audit and cannot independently satisfy resume or completion authority.

Event Store writes are post-commit projection writes. A stored Event must refer only to already durable State refs, Audit refs, Kanban lifecycle observations, or artifact refs.

Event Store retention is tied to run State retention. MVP must not apply cache TTL, log rotation, prefix deletion, middle deletion, or lossy compaction to `events.jsonl`.

Audit may reference Event refs for correlation, but Audit must not use the Event Store as its primary record. Audit records are written as their own immutable artifacts under `AUDIT_ROOT`.

Cache backend contract:

- MVP default backend is `local_filesystem`.
- Future optional backend is `redis`.
- Cache objects are rebuildable only and must not store approval state, Kanban lifecycle state, immutable Audit artifacts, or sensitive raw user input.
- Cache keys use `hermes:mvp:{project_slug}:{cache_type}:{sha256}` regardless of backend.
- MVP cache object types and TTLs are `debate_result` 24h, `knowledge_summary` 6h, `test_plan` 24h, `capabilities` 5m, and `gateway_projection` 30s.
- If Redis is configured later and unavailable, the Gateway emits `cache_degraded`, falls back to `local_filesystem`, and continues the run.

## 9. Harness

`workflow-init` produces:

- `.workflow/knowledge/project-summary.json`
- `.workflow/knowledge/tech-stack.json`
- `.workflow/knowledge/api-surface.json`
- `.workflow/knowledge/module-map.json`
- `.workflow/knowledge/coding-rules.json`
- `.workflow/knowledge/test-strategy.json`
- `.workflow/knowledge/risk-notes.json`
- `.workflow/knowledge/update-manifest.json`

Included scan inputs:

- Root engineering files such as `README.md`, `Makefile`, `package.json`, `AGENTS.md`, `CLAUDE.md`, `hermes/SOUL.md`.
- Key directories: `scripts/`, `hermes/`, `skills/`, `specs/`, `docs/`.
- Read-only summaries from `reference/hermes-docs-index/`.
- CodeMap summaries such as `.mycodemap/AI_MAP.md` and `.mycodemap/env-contract.json`.

Excluded inputs:

- `.git/`, `.planning/`, `.tmp_index_work/`.
- State/Audit/Cache roots.
- zip files, large logs, generated batches, historical archives.
- secrets, tokens, `.env`.

`knowledge-update` is explicit-command triggered. It uses `update-manifest.json` hash/mtime diffs and updates only affected `.workflow/knowledge/*` files.

Changes to root `AGENTS.md`, root `CLAUDE.md`, or `hermes/SOUL.md` may cause rules to be re-extracted into `.workflow/knowledge/*`, but `workflow-init`, `knowledge-update`, and `continuous_improvement` must not directly apply root rule-file edits in MVP. They may only produce System Improvement Proposals or proposed patch references for later approval.

## 10. Debate

MVP includes:

- `config/debate/teams.json`
- `config/debate/modes.json`

All 16 teams and 8 modes must be expressible in config, but routing dynamically selects only relevant teams/modes per stage.

Debate backend contract:

- The registry must remain backend-neutral.
- `template` is allowed for offline tests, schema fixtures, or unavailable API-key environments.
- If a real debate backend such as MiniMax/API-backed debate is available, an MVP acceptance run must use it for at least one core debate stage: `direction_debate` or `solution_debate`.
- If no real debate backend is available, the Gateway may use template fallback, but it must emit `debate_degraded` or write an Audit downgrade, record the downgrade in `iteration_closeout_report.json`, and mark the corresponding `debate_report.json` as degraded.
- Template fallback verdicts are scaffold input only and must not be treated as strong decision evidence for auto-advance.

Default routing:

- `direction_debate`: `dynamic_assembly` plus `jury_panel`.
- `solution_debate`: `sequential_review` plus `risk_priority_matrix`.
- `improvement`: `risk_priority_matrix` over feedback-relevant teams.
- `global_evaluation`: `parallel_debate`.
- Strong conflicts: add `cross_team_conflict_detector` or `meta_review`.

Debate output is strong input, not final authority. Kimi is the final orchestration and acceptance authority below human-risk gates, but Kimi must not approve L3/L4 or forbidden automatic modification boundaries by itself.

Auto-advance requires:

- `confidence >= 0.75`
- `risk_level <= medium`
- no unresolved conflicts

High/critical risk, unresolved conflicts, `reject`/`modify` verdicts, and schema failures must block or require follow-up.

## 11. Workers

MVP includes:

- `config/workers/backends.json`
- `config/workers/roles.json`

Default pairing:

- implementer: `codex`
- reviewer: `claude`

Worker backend authority:

- `config/workers/backends.json` is the backend declaration authority. It declares enabled backend adapters, CLI/API invocation shape, supported modes, declared capabilities, health check command, and version probe.
- `config/workers/roles.json` is the role routing authority. It maps workflow roles to required capabilities, preferred backends, explicit fallback backends, and fallback-allowed failure classes.
- `/orchestra/capabilities` reports observed runtime availability, versions, missing dependencies, and role-to-backend compatibility. It is a projection, not a policy source.
- `options.worker_pairing` may request implementer/reviewer backends, but the Gateway accepts them only if they are registered, enabled, role-compatible, and currently available.
- Unknown, disabled, unavailable, or role-incompatible requested backends cause run creation to fail validation instead of silently selecting another backend.
- Before dispatching a worker task, the Gateway records `selected_backend`, backend version, matched capabilities, adapter type, and fallback status in Gateway State and Audit.

Fallback is allowed only when configured, role-compatible, currently available, and triggered by a retryable failure class. Fallback is forbidden for `parse_error`, `schema_mismatch`, security policy hits, Human Approval boundaries, forbidden automatic modification targets, and worker output that cannot be validated. Every fallback activation must be audited with original backend, failure class, attempt number, selected fallback backend, and rationale.

Worker input context boundary:

- Worker input uses a `hermes-role-engine/v1` Worker Context Envelope, not raw chat history or a whole-repository prompt dump.
- The envelope includes structured task data, role, selected backend, stage, risk level, approval state, allowed write scope, workspace strategy, artifact refs, context bundle refs, and test requirements.
- Worker Context Bundles are read-only and scoped. They may include relevant `structured_prd.json`, `development_plan.json`, debate or stage reports, selected `.workflow/knowledge/*` summaries, task projection data, baseline diff/status artifacts, and explicitly selected source-file excerpts or summaries.
- Worker input must not include secrets, secret environment values, absolute local paths, full raw chat history, unrelated prior conversation, full project dumps, or unredacted temporary raw tickets.
- If a worker needs more context, it must return `next_action: request_context` with a structured context request. The Gateway may satisfy it only by adding validated artifact refs or a new scoped Context Bundle and recording that addition in Audit.

Worker output must be structured JSON. Natural-language summaries can explain the result, but they must not advance workflow state without schema-valid structured output. `schema_mismatch` hard-blocks the task.

Worker output and state advancement boundary:

- A Worker Backend may return `next_action: complete`, `block`, `create_tasks`, `request_context`, or `defer_to_human`, but those are requests to the Gateway, not direct lifecycle authority.
- Worker Backends must not directly mark Kanban tasks complete, mutate Gateway State, mark stages complete, or mark a run complete.
- The Gateway Advancement Gate validates worker output before any State, Audit, or Kanban lifecycle change.
- The validation gate checks protocol/schema validity, correlation and task identity, artifact refs, required artifact schemas, allowed write scope, forbidden path violations, risk/approval boundaries, and required test or review evidence.
- For code-changing tasks, the gate compares changed files and diff summary against `allowed_write_scope` and recorded baseline state before accepting completion.
- Missing or invalid critical artifacts blocks or requests revision. Test failure enters the bounded improvement path. Write-scope, forbidden-target, or approval-boundary violations block for Human Approval or fail according to policy.
- When validation passes, the Gateway writes State and Audit first, then advances official Hermes Kanban lifecycle through workflow-controlled `complete`, `block`, or `unblock` commands.
- Worker stdout/stderr and natural-language summaries may be stored as evidence, but they are never state transition authority.

Worker adapters hide CLI/API-specific details behind the role protocol. Workflow semantics must depend on role capabilities and structured worker output, not on tool-specific command names.

Code tasks use official Kanban `--workspace worktree` by default. This explicitly supersedes the grill decision note where items 63-65 allowed direct project repository modification as the MVP default.

Direct project checkout modification is allowed only as an explicit MVP downgrade fallback when worktree creation fails, a selected CLI worker cannot operate correctly from the worktree, or the demo run needs the shortest viable loop. Any Direct Project Fallback must be recorded in `iteration_closeout_report.json`.

Each code task must record:

- baseline `git status --short`
- environment snapshot
- workspace strategy and fallback reason, if any
- changed files
- diff summary
- test commands
- test results

Reviewer must inspect artifact refs and git diff, not only implementer summary.

Review and QA feedback contract:

- Reviewer and QA outputs must be structured verdict artifacts, not free-form summaries.
- Verdict enum is `approve | request_changes | reject | block`.
- Each verdict must include findings, severity, affected acceptance criteria, required fixes, evidence refs, and whether the issue is inside the approved `development_plan.json` scope.
- `approve` still passes through the Gateway Advancement Gate before any task, stage, or run advancement.
- `request_changes` enters Stage 4 `improvement` for at most one automatic fix cycle when the required fixes are within approved scope and below human-risk gates.
- `reject` blocks the task or requires a Kimi decision, depending on whether the reviewer describes a recoverable revision path.
- `block` requires Kimi decision or Human Approval according to the decision authority chain. L3/L4, forbidden targets, security boundaries, write-scope violations, schema failures, and test failures cannot be bypassed by Kimi acceptance.
- Kimi may accept, reject, or request revision below human-risk gates, but it must not override high-risk blocks, schema failures, test failures, write-scope violations, or Human Approval boundaries.
- Improvement output must create new review/QA artifacts for re-review. It must not overwrite the original review or QA verdict.
- Re-review must inspect the improvement diff, original findings, acceptance criteria, artifact refs, and test evidence before allowing advancement.

## 12. Testing

MVP testing artifacts:

- `test_plan.json`
- `test_execution_report.json`
- optional `generated_test_script_ref`
- conditional `test_fix_report.json`
- `ci_recommendation.json`

`test_plan.json` must be derived from `development_plan.json` acceptance criteria and must identify the commands or generated scripts that will exercise those criteria. A generic checklist is not sufficient.

If the project has a test entrypoint, run it first. For this project, the default test command is `make test` and it must run before generated smoke tests.

If no test entrypoint exists or the entrypoint is unavailable, generate and execute a minimal smoke test script. The run still needs a `test_execution_report.json` with at least one executed command.

Playwright is only for UI/frontend tasks. Non-UI tasks must not introduce Playwright just to satisfy the workflow.

If testing fails, the run enters Stage 4 `improvement` for at most one automatic fix cycle. If tests still fail after that cycle, the run must block and must not become `completed`.

Review or QA `request_changes` follows the same bounded improvement budget. After one automatic improvement cycle, remaining review, QA, or test failures block completion and require decision routing.

AI Mock MVP supports static mock/spec fixtures only.

## 13. Decisions And Failures

Decision actions:

`approve | reject | revise`

`POST /orchestra/decisions/{decision_id}` accepts `idempotency_key`. A resolved decision is idempotent only for the same action payload: repeating the same command returns the prior `decision_resolved` result, while a different action or revision payload with the same `idempotency_key` returns `409 conflict`.

Stopping a blocked run uses `POST /orchestra/runs/{run_id}/stop`, not a fourth decision action. If the stop follows a pending decision, the stop audit links the pending decision ref but leaves it unresolved.

`POST /orchestra/runs/{run_id}/stop` accepts `idempotency_key`. Repeating the same stop command returns the same `stopped` status, stop audit ref, partial closeout ref, and `run_stopped` event ref without writing another stop record.

Decision lifecycle:

`pending -> approved | rejected | revised | expired`

`decision_required` triggers:

- high/critical risk
- unresolved debate conflict
- irreversible operation
- external publish/write
- budget/time overrun
- repeated worker failure
- schema validation failure
- missing critical artifact

Decision authority routing:

- Low risk may auto-advance when policy allows it, but the Gateway must record the auto-advance reason or Kimi acceptance.
- Medium risk, unresolved debate conflict, `modify` verdicts, repairable schema issues, and repeated worker failure require a Kimi decision through `POST /orchestra/decisions/{decision_id}`.
- L3/L4 policy hits, forbidden automatic modification targets, destructive operations, external publish/push/deploy, permission or secret changes, CI/CD changes, root `AGENTS.md` / `CLAUDE.md` / `SOUL.md` changes, risk-policy changes, and Gateway port/proxy changes require Human Approval. Kimi may recommend an action, but the Gateway must remain blocked until explicit user approval is recorded.
- The local fallback for Human Approval remains `orch-decisions`, `orch-approve`, and `orch-reject`.

Decision effects:

- `approve` resumes the original blocked task or stage attempt from validated artifact refs.
- `revise` creates a revised child task or revised stage attempt and records `revision_of` plus source artifact refs.
- `reject` blocks or fails according to recoverability and authority routing.
- Decision effects are append-only: they write new State/Audit records and new artifacts instead of overwriting prior evidence.

Failure classes:

`timeout | crash | rate_limit | parse_error | schema_mismatch | test_failed | review_changes_requested | review_rejected | qa_blocked | improvement_exhausted | global_evaluation_failed | global_evaluation_blocked | decision_expired`

Retry policy:

- `timeout`, `crash`, `rate_limit`: retry primary backend once.
- After retry failure, use one fallback only if role config declares it and capability negotiation still passes.
- `parse_error`, `schema_mismatch`: hard block without fallback.
- Security policy hits, Human Approval boundaries, and forbidden automatic modification targets must not fallback around the decision authority chain.
- `test_failed`, `review_changes_requested`: enter improvement loop, max one automatic fix cycle.
- `review_rejected`, `qa_blocked`: block or require decision routing according to risk and recoverability.
- `improvement_exhausted`: stay blocked until Kimi or Human Approval chooses `revise`, chooses `reject`, or requests stop through the run stop endpoint.
- `global_evaluation_failed`: return to bounded improvement only when budget and scope allow it; otherwise block for decision routing.
- `global_evaluation_blocked`: route to Kimi or Human Approval according to authority requirements.
- `decision_expired`: stay blocked.

Blocked vs failed boundary:

- MVP defaults to `blocked` whenever the run can safely preserve evidence and wait for decision, repair, or follow-up.
- Test failure, review rejection, QA block, schema mismatch, decision expiration, missing approval, and repeated worker failure are blocked states by default, not terminal run failures.
- Missing or invalid artifacts block when the artifact can be regenerated, repaired, superseded, or routed through a decision.
- A run becomes terminal `failed` only when the current run can no longer be safely continued because workflow authority or evidence integrity is unrecoverable.
- Terminal `failed` reasons are limited in MVP to: Gateway/State/Audit/Kanban authority-chain corruption, critical State/Audit/artifact loss that cannot be rebuilt or superseded, unauthorized or out-of-scope writes that make the current run evidence untrusted, or internal workflow invariant violation that prevents safe recovery.
- Event Projection inconsistency alone is not authority-chain corruption when State, Audit, Kanban, and artifact refs remain valid. It is handled by projection rebuild or Kimi resync, not by run blocking.
- If the Gateway cannot prove the failure crosses this boundary, it must keep the run `blocked` and emit `decision_required`.
- A failed run must emit `run_failed`, write immutable Audit evidence, write `run_failure_report`, preserve State/Audit/Kanban/artifact refs, record `last_good_checkpoint_ref` when available, and include lineage hints for a future run.
- Marking a run `failed` must not delete State, Audit, Cache, repo artifacts, Kanban tasks, worker evidence, or partial outputs.
- `failed` is terminal and cannot resume in place. Continuation follows the lineage rules above with a new run.

## 14. Security

Forbidden automatic modifications:

- `.git/`
- `.gitignore`
- `.env`
- secret/key/token files
- CI/CD config such as `.github/workflows/*`
- `config/risk-policy.yaml`
- `config/rules.json`
- root `AGENTS.md`
- root `CLAUDE.md`
- `hermes/SOUL.md`
- `scripts/setup.sh`
- `scripts/install-orchestra.sh`
- upstream Hermes runtime directories

Default `decision_required` for:

- L3/L4 policy hits
- destructive delete
- database schema changes
- auth/secret/JWT changes
- `sudo`
- `chmod 777`
- docker/kubectl prune/delete
- worker backend config changes
- debate routing changes
- Gateway proxy port changes
- publish/push/deploy
- external API writes

## 15. Privacy

User raw tickets may be stored in local State/Audit, but not in repo.

`.workflow/knowledge/*` stores long-lived project knowledge only, not full temporary requirements.

Worker Context Envelopes and Context Bundles contain scoped summaries and artifact refs, not full chat history, full raw tickets, secret environment, absolute paths, or whole-project dumps.

Events contain summaries, not full prompts, tokens, secrets, large bodies, full worker stdout/stderr, or absolute local paths.

Simple secret redaction replaces likely secrets matching `API_KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `sk-*`, and `gk_live_*` with `[REDACTED]`.

Audit remains local and is not automatically uploaded or committed.

## 16. Config

Project-local config files:

```text
config/orchestra-gateway.json
config/workers/backends.json
config/workers/roles.json
config/debate/teams.json
config/debate/modes.json
config/schemas/*.schema.json
```

Priority:

`environment variables > project-local config JSON > built-in defaults`

Defaults:

- Gateway: `127.0.0.1:8642`
- Upstream API: `http://127.0.0.1:8643`
- Cache: local filesystem
- Cache backend contract: `local_filesystem` default, `redis` future optional adapter
- Debate backend: real backend preferred when available; template fallback only as degraded scaffold
- Auto-approve low risk: true
- Max improvement auto cycles: 1
- Run mode: `mvp_full`
- Worker workspace: Kanban `worktree` by default, with Direct Project Fallback only as an audited downgrade.
- Parallelism: one active run per project; run-internal parallelism only when explicitly allowed by `parallelism_policy`.

## 17. Acceptance

A successful MVP run requires:

- `GET /orchestra/runs/{run_id}` returns `completed`.
- Completion was derived from Kanban lifecycle, Gateway State, Audit, and schema-valid required artifacts, not cache or model self-report.
- Worker backend selection and any fallback are recorded in Gateway State and Audit.
- All six stage tasks are done in DAG order.
- All six fixed reports exist and are schema-valid.
- `structured_prd.json`, `development_plan.json`, `test_plan.json`, and `test_execution_report.json` exist.
- `test_plan.json` references acceptance criteria from `development_plan.json`, and `test_execution_report.json` records at least one executed command.
- At least one real CLI implementer task executed.
- Worker input used scoped Worker Context Envelopes and Context Bundles, not raw chat history or full project dumps.
- Worker outputs passed the Gateway Advancement Gate before State, Audit, or Kanban lifecycle advancement.
- Reviewer task inspected artifact refs and git diff.
- Reviewer and QA verdict artifacts are schema-valid; any `request_changes` path produced a new re-review artifact instead of overwriting the original verdict.
- Any Stage 4 automatic improvement stayed within approved `development_plan.json` scope, wrote `improvement_report.json`, and produced re-review or re-test evidence.
- `global_evaluation_report.json` is schema-valid and has verdict `pass` or Kimi-accepted `pass_with_warnings`.
- Code worker workspace strategy is recorded; any Direct Project Fallback is documented as an MVP downgrade.
- Stage 6 writes both `iteration_closeout_report.json` and `system_improvement_proposals.json`.
- `iteration_closeout_report.json` records final acceptance, accepted warnings, downgrades, unresolved or deferred decisions, test/review evidence, worker fallbacks, knowledge updates, and future proposals.
- Run completion is held until closeout artifacts are schema-valid, Audit contains closeout evidence, all six Kanban stage tasks are done, and Gateway State is consistent with artifact and decision refs.
- Cache backend is reported, and any Redis-unavailable fallback emits `cache_degraded`.
- Debate backend is reported; if no real debate backend was used, the run records `debate_degraded` or an Audit downgrade.
- `development_plan.json` includes a `parallelism_policy`; any deferred or disabled parallelism is documented in closeout.
- Events include run creation, stage start/completion, task start/completion, and run completion.
- Audit can trace each stage input, output, and failure/skip reason.
- Mutating Gateway commands record `idempotency_key` and `command_id`; retrying the same command does not duplicate runs, decisions, stops, Events, Audit records, or Kanban mutations.
- In-progress command journal recovery is exercised or documented: startup reconciliation can mark completed commands, continue unexecuted steps, or block ambiguous commands without blind replay.
- MVP downgrades used in the run are documented in `iteration_closeout_report.json`.

A stopped run is not a successful MVP acceptance run. It must expose status `stopped`, emit `run_stopped`, preserve State/Audit/Kanban/artifact evidence, and write partial closeout evidence with `closeout_kind: stopped_before_completion`.

A failed run is not a successful MVP acceptance run. It must expose status `failed`, emit `run_failed`, preserve State/Audit/Kanban/artifact evidence, write `run_failure_report`, record `last_good_checkpoint_ref` when available, and provide lineage hints for a future run.

## 18. Demo Task

First end-to-end demo task:

Add or verify Gateway adapter `/orchestra/capabilities` backend health reporting and a curl/shell smoke test.

If `/orchestra/capabilities` is already complete before demo execution, use `/orchestra/runs/{run_id}/tasks` projection as the substitute demo task.

## 19. Implementation Slices

Future execution should proceed in five slices:

1. Gateway shell.
2. Run/artifacts/events.
3. Harness plus debate.
4. Implementation worker loop.
5. Testing plus closeout.

This spec does not start implementation.
