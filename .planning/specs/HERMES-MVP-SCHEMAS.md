# Hermes MVP Schema Summary

Date: 2026-05-16
Status: Draft schema contract

All API responses and artifacts use `schema_version: "orchestra.v1"` unless noted. Events use `schema_version: "orchestra.event.v1"`. Worker envelopes keep `protocol: "hermes-role-engine/v1"`.

This document summarizes required fields. Exact machine-readable schemas should be added later under `config/schemas/*.schema.json`.

## Run Create Request

Required:

- `intent` or `ticket`
- `idempotency_key`

Optional:

- `intent`: string
- `ticket`: object
- `options`: object
- `source_run_id`: string
- `resume_from_refs`: array of Artifact References

`ticket` fields:

- `background`: string
- `goal`: string
- `deliverables`: array of strings
- `acceptance_criteria`: array of strings
- `hard_constraints`: array of strings
- `soft_constraints`: array of strings
- `related_tasks`: array
- `failure_strategy`: string

Six-stage execution gate:

- If only `intent` is provided, the run may be created for intake/normalization.
- The six-stage DAG must not start until `ticket` or `structured_prd.json` is schema-valid.
- Missing acceptance criteria, constraints, or failure strategy blocks the run with `authority_required: kimi`.

`options` fields:

- `worker_pairing.implementer`: string
- `worker_pairing.reviewer`: string
- `auto_approve_low_risk`: boolean
- `mode`: enum, only `mvp_full` in MVP

`worker_pairing` values must be registered backend names. Unknown, disabled, unavailable, or role-incompatible backend names fail request validation.

`source_run_id` and `resume_from_refs` are allowed only when creating a new lineage run from a terminal `failed` or `stopped` source run. They must not be used to resume an active `blocked` run.

## Run Response

Fields:

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
- `event_projection_degraded`
- `projection_status`
- `projection_issue_refs`

Status enum:

`queued | running | blocked | failed | completed | stopped`

`source_run_id` and `lineage_ref` are null unless the run was created from a terminal source run.

## Run Status

Fields:

- `schema_version`
- `run_id`
- `status`
- `project`
- `last_command_id`
- `source_run_id`
- `lineage_ref`
- `created_at`
- `updated_at`
- `current_stage`
- `progress`
- `stages`
- `blocked_reason`
- `failure_reason`
- `failure_report_ref`
- `failure_audit_ref`
- `last_good_checkpoint_ref`
- `lineage_hint_refs`
- `pending_decision_id`
- `pending_decision_refs`
- `resume_checkpoint_refs`
- `stopped_reason`
- `stop_audit_ref`
- `artifact_refs`

## Run Lineage

Fields:

- `schema_version`
- `artifact_type`
- `lineage_id`
- `run_id`
- `source_run_id`
- `source_status`
- `resume_from_refs`
- `source_state_refs`
- `source_audit_refs`
- `source_kanban_refs`
- `source_closeout_ref`
- `source_failure_refs`
- `rationale`
- `created_at`

`artifact_type` value:

`run_lineage`

`source_status` enum:

`failed | stopped`

Lineage records are append-only. They let a new run read source evidence without mutating the source run. `resume_from_refs` must be scoped refs from the source run and cannot include cache refs as authority.

## Run Failure Report

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `failure_class`
- `terminal_failure_reason`
- `failed_stage`
- `failed_task_id`
- `authority_chain_assessment`
- `unrecoverable_artifact_refs`
- `unauthorized_write_refs`
- `invariant_violation_refs`
- `last_good_checkpoint_ref`
- `preserved_state_refs`
- `preserved_audit_refs`
- `preserved_kanban_refs`
- `preserved_artifact_refs`
- `lineage_hint_refs`
- `run_failed_event_ref`
- `created_at`

`artifact_type` value:

`run_failure_report`

`terminal_failure_reason` enum:

`authority_chain_corrupt | critical_artifact_unrecoverable | unauthorized_write_untrusted | invariant_unrecoverable`

Run failure reports are for terminal `failed` runs only. Ordinary test, review, QA, schema, approval, timeout, and retry failures should produce blocked evidence unless they also cross the terminal failure boundary above.

## Event

Fields:

- `schema_version`
- `seq`
- `timestamp`
- `command_id`
- `idempotency_key`
- `run_id`
- `task_id`
- `stage`
- `type`
- `severity`
- `status`
- `message`
- `artifact_refs`
- `decision_id`

Field rules:

- `seq` is a positive integer, monotonic within one `run_id`, and is the only Event ordering key exposed to Kimi.
- `timestamp` is informational. It must not replace `seq` for ordering or gap detection.
- `command_id` is required when the Event is caused by a mutating Gateway command. It may be null only for derived projection or system observation events.
- `idempotency_key` is present only when the Event is caused by a mutating Kimi-facing command.
- `message` is a concise summary. It must not contain raw prompts, tokens, secrets, full worker stdout/stderr, large report bodies, or absolute local paths.
- `artifact_refs` contains scoped Artifact References only. Events must not embed large artifacts.
- Events are an Event Projection, not Audit authority, resume authority, or completion authority.
- Event append validation requires the reported State, Audit, Kanban, or artifact change to be durable first. Events must not be emitted optimistically before the authority write succeeds.
- If an Event reports `stage_completed`, `task_completed`, `decision_resolved`, `run_stopped`, `run_failed`, or `run_completed`, the corresponding authoritative State/Audit/Kanban/artifact refs must already validate.

Event types:

`run_created | ticket_normalized | knowledge_stale | stage_started | stage_completed | task_created | task_started | task_blocked | task_completed | artifact_written | decision_required | decision_resolved | cache_degraded | debate_degraded | run_failed | run_stopped | run_completed`

## Event Query Response

Fields:

- `schema_version`
- `run_id`
- `since_seq`
- `limit`
- `events`
- `next_seq`
- `has_more`
- `projection_status`
- `event_store_ref`
- `rebuilt_from_refs`
- `authority_refs_checked`
- `projection_issue_refs`

`projection_status` enum:

`current | rebuilt | inconsistent`

`event_store_ref` is a `state://{project}/{run_id}/...` Artifact Reference, normally pointing at the Gateway State Event Store such as `events.jsonl`. It must not be an `audit://` ref.

Event Store retention in MVP is `retain_with_run_state`. `ttl` is null, truncation is forbidden, and lossy compaction is forbidden. Active and terminal runs retain the complete Event Store with stable sequence numbers.

`since_seq` means "return Events with `seq` greater than this value". It must be a non-negative integer. `next_seq` is the next sequence value the client should use as `since_seq` after consuming the response.

The returned `events` array must be strictly increasing by `seq` for the requested `run_id`. Duplicate, missing, or out-of-order `seq` values are projection inconsistencies.

If Event Projection data is missing or corrupt, Gateway may rebuild it from Gateway State, Audit, Hermes Kanban, and artifact refs and return `projection_status: "rebuilt"`. If the Event Projection remains unverifiable while Gateway State, Audit, Hermes Kanban, and artifact refs are mutually consistent, Gateway returns `projection_status: "inconsistent"` without changing the run status, and Kimi must resync run status, task projection, and Events before further decisions.

Audit cannot be reconstructed from Events. Rebuilt Events must reference existing authoritative State, Audit, Kanban, or artifact refs and must not invent new Audit evidence.

Audit records may include Event refs for correlation, but the Event Store is Gateway State. Event persistence must not be modeled as an Audit Artifact or Cache Artifact.

Projection inconsistency alone is not a valid `blocked_reason`, `failure_reason`, resume authority, or completion authority. If the projection cannot be proven because authoritative State, Audit, Kanban, or artifact refs are missing or inconsistent, Gateway must route through the normal blocked-vs-failed authority boundary rather than treating the Event Query Response as the source of truth.

Event append failure after durable authority writes is a Projection Inconsistency, not a reason to roll back State, Audit, Kanban, or artifact changes.

Cache TTL rules do not apply to Event Store retention. A future archive format must preserve `seq` continuity and a complete sequence manifest before replacing the live run State copy.

## Command Record

Fields:

- `schema_version`
- `command_id`
- `idempotency_key`
- `project`
- `endpoint`
- `resource_path`
- `payload_hash`
- `intent_ref`
- `planned_steps`
- `completed_steps`
- `current_step_id`
- `reconciliation_ref`
- `status`
- `response_ref`
- `result_resource_refs`
- `event_refs`
- `audit_refs`
- `event_projection_degraded`
- `projection_status`
- `projection_issue_refs`
- `created_at`
- `completed_at`

`status` enum:

`accepted | in_progress | completed | conflict | failed`

Command records are Gateway State. They deduplicate mutating commands and may be referenced by Audit, but cache must not be used as command dedupe authority.

If authoritative State, Audit, Kanban, and artifact side effects succeed but Event append fails, `status` remains `completed`, `event_projection_degraded` is `true`, `projection_status` is `inconsistent`, and `projection_issue_refs` records the failed append or rebuild issue. The stored `response_ref` must replay the successful authority result with the same degradation metadata.

Command step fields:

- `step_id`
- `target_authority`
- `operation`
- `status`
- `input_refs`
- `output_refs`
- `started_at`
- `completed_at`

`target_authority` enum:

`gateway_state | audit | hermes_kanban | artifact_store | worker_scheduler`

Step `status` enum:

`planned | in_progress | completed | failed | ambiguous`

Gateway must not apply a mutating side effect unless it is represented by a planned command step.

## Command Reconciliation Report

Fields:

- `schema_version`
- `artifact_type`
- `command_id`
- `idempotency_key`
- `run_id`
- `reconciliation_status`
- `reconciled_steps`
- `ambiguous_steps`
- `state_refs_checked`
- `audit_refs_checked`
- `kanban_refs_checked`
- `artifact_refs_checked`
- `decision_required_ref`
- `blocked_reason`
- `created_at`

`artifact_type` value:

`command_reconciliation_report`

`reconciliation_status` enum:

`completed_without_replay | continued_from_checkpoint | blocked_ambiguous`

Command reconciliation reports are Audit artifacts. They explain how Gateway resolved an in-progress command after crash or restart.

## Task Projection

Read-only Gateway projection. This schema is not a task mutation request and must not be used as raw Kanban CRUD.

Fields:

- `schema_version`
- `task_id`
- `title`
- `kind`
- `stage`
- `role`
- `backend`
- `status`
- `parents`
- `children`
- `started_at`
- `completed_at`
- `artifact_refs`
- `risk_level`
- `blocked_reason`

## Artifact Reference

All `artifact_refs`, `input_artifact_refs`, `output_artifact_refs`, `source_refs`, `proposed_patch_refs`, and generated artifact reference fields use scoped URIs. They must not contain absolute filesystem paths.

Required fields:

- `uri`
- `artifact_type`
- `authority`

Optional fields:

- `sha256`
- `created_at`
- `immutable`
- `schema_version`

`authority` enum:

`state | audit | cache | repo`

URI schemes:

- `state://{project}/{run_id}/...`
- `audit://{project}/{run_id}/...`
- `cache://{project}/{sha256}`
- `repo://.workflow/knowledge/...`

Validation rules:

- `state://` and `audit://` refs must match the enclosing run project and run ID.
- `cache://` refs must use hash-addressed keys and cannot be required for run completion.
- `repo://` refs must stay under `.workflow/knowledge/`.
- Unknown schemes, absolute paths, `..` path segments, or cross-project/cross-run refs are invalid.
- Missing or invalid critical State, Audit, or Repo refs block the current stage.
- Missing Cache refs trigger rebuild or `cache_degraded`; cache never becomes resume or completion authority.

## Structured PRD

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `requirement_summary`
- `clarification_log`
- `touched_modules`
- `decomposed_requirements`
- `acceptance_criteria`
- `constraints`
- `risks`
- `input_artifact_refs`

Required to start six-stage execution:

- `requirement_summary`
- `acceptance_criteria`
- `constraints`
- `risks`
- `failure_strategy`

## Development Plan

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `mode`
- `child_task_dag`
- `d2c_enabled`
- `dev_enabled`
- `logic_hints_ref`
- `worker_assignment`
- `workspace_strategy`
- `parallelism_policy`
- `test_strategy`
- `rollback_checkpoints`
- `acceptance_criteria`

Mode enum:

`full | layout-only | none`

Workspace strategy enum:

`kanban_worktree | direct_project_fallback | none`

Parallelism policy fields:

- `top_level_serial`: boolean
- `allowed_parallel_groups`: array
- `requires_disjoint_write_sets`: boolean
- `merge_arbitration`: enum
- `notes`: string

`merge_arbitration` enum:

`none | manual_future`

## Debate Report

Fields:

- `schema_version`
- `artifact_type`
- `debate_id`
- `run_id`
- `stage`
- `backend`
- `degraded`
- `mode`
- `teams`
- `question`
- `options`
- `findings`
- `risks`
- `conflicts`
- `verdict`
- `confidence`
- `risk_level`
- `requires_kimi_decision`
- `recommended_next_actions`
- `artifact_refs`

## Stage Report

Common fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `stage`
- `status`
- `input_artifact_refs`
- `output_artifact_refs`
- `decision_refs`
- `summary`
- `risks`
- `next_actions`
- `created_at`

Fixed artifact types:

- `best_choice_report`
- `implementation_plan_report`
- `task_feedback_report`
- `improvement_report`
- `global_evaluation_report`
- `iteration_closeout_report`

## Global Evaluation Report

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `stage`
- `input_artifact_refs`
- `structured_prd_ref`
- `development_plan_ref`
- `debate_report_refs`
- `implementation_evidence_refs`
- `review_verdict_refs`
- `qa_verdict_refs`
- `test_execution_refs`
- `improvement_report_refs`
- `downgrade_refs`
- `unresolved_decision_refs`
- `audit_refs`
- `verdict`
- `warnings`
- `residual_risks`
- `blocking_issues`
- `authority_required`
- `final_acceptance_ref`
- `next_actions`
- `created_at`

`artifact_type` value:

`global_evaluation_report`

`verdict` enum:

`pass | pass_with_warnings | fail | block`

Routing rules:

- `pass` may proceed to Stage 6 after Gateway Advancement Gate validation.
- `pass_with_warnings` requires Kimi Final Acceptance and warning rationale before Stage 6.
- `fail` may return to bounded improvement only when automatic improvement budget remains and findings are in approved scope; otherwise it blocks.
- `block` routes to Kimi decision or Human Approval according to `authority_required`.
- L3/L4, schema failure, test failure, write-scope violation, security boundary, forbidden target, or Human Approval boundary cannot be overridden by Kimi acceptance.

## Improvement Report

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `stage`
- `improvement_cycle`
- `source_failure_refs`
- `source_verdict_refs`
- `source_test_execution_refs`
- `development_plan_ref`
- `scope_assessment`
- `fixes_applied`
- `changed_files`
- `diff_summary`
- `test_commands`
- `test_result_refs`
- `re_review_refs`
- `re_test_refs`
- `blocked_reason`
- `decision_refs`
- `created_at`

`artifact_type` value:

`improvement_report`

`improvement_cycle` starts at `1`. MVP allows at most one automatic improvement cycle before decision routing.

`scope_assessment` fields:

- `within_approved_scope`
- `out_of_scope_items`
- `requires_human_approval`
- `forbidden_targets_touched`

Improvement reports must reference the original review, QA, or test failure artifacts. They must not introduce new requirements, architecture direction changes, risk policy changes, worker/debate/Gateway config changes, or Human Approval targets.

## Iteration Closeout Report

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `global_evaluation_report_ref`
- `closeout_kind`
- `final_acceptance`
- `accepted_warning_refs`
- `downgrade_records`
- `unresolved_decisions`
- `pending_decision_refs`
- `deferred_decisions`
- `completed_stage_refs`
- `incomplete_stage_refs`
- `stop_request_ref`
- `run_stopped_event_ref`
- `preserved_artifact_refs`
- `resume_checkpoint_refs`
- `worker_cancel_marker_refs`
- `test_execution_refs`
- `review_verdict_refs`
- `qa_verdict_refs`
- `worker_fallbacks`
- `knowledge_updates`
- `system_improvement_proposals_ref`
- `completion_gate`
- `created_at`

`artifact_type` value:

`iteration_closeout_report`

`closeout_kind` enum:

`completed | stopped_before_completion`

`final_acceptance` fields:

- `accepted_by`
- `authority`
- `verdict`
- `rationale`
- `decision_ref`

`knowledge_updates` fields:

- `auto_applied_refs`
- `proposal_refs`
- `forbidden_target_refs`

`completion_gate` fields:

- `artifacts_schema_valid`
- `audit_closeout_recorded`
- `kanban_stage_tasks_done`
- `gateway_state_consistent`
- `completion_blockers`

For `closeout_kind: completed`, `final_acceptance`, `global_evaluation_report_ref`, `system_improvement_proposals_ref`, and `completion_gate` are required.

For `closeout_kind: stopped_before_completion`, `final_acceptance`, `global_evaluation_report_ref`, and `system_improvement_proposals_ref` may be null if the run stopped before those stages. The report must include `stop_request_ref`, `run_stopped_event_ref`, `preserved_artifact_refs`, `incomplete_stage_refs`, unresolved `pending_decision_refs` or `unresolved_decisions`, and `resume_checkpoint_refs` when available.

The closeout report is evidence, not completion authority by itself. Gateway may mark a run `completed` only when `closeout_kind` is `completed`, `completion_gate` passes, and the Validation Policy below confirms Kanban lifecycle, Gateway State, Audit, and required artifacts are consistent.

## System Improvement Proposals

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `source_refs`
- `proposals`
- `auto_applied_refs`
- `proposed_patch_refs`
- `approval_required`
- `decision_refs`
- `final_acceptance_ref`
- `downgrade_refs`
- `worker_fallback_refs`
- `knowledge_update_refs`

`artifact_type` value:

`system_improvement_proposals`

Proposal fields:

- `proposal_id`
- `target`
- `summary`
- `rationale`
- `risk_level`
- `authority_required`
- `artifact_refs`
- `status`

`status` enum:

`proposed | auto_applied_low_risk | approved | rejected | deferred`

Only low-risk `.workflow/knowledge/*` proposals may be `auto_applied_low_risk` in MVP. Proposals targeting root `AGENTS.md`, root `CLAUDE.md`, `hermes/SOUL.md`, CI/CD, install scripts, permission/risk policy, worker backend config, debate routing config, or Gateway/runtime configuration require approval before application.

## Test Plan

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `development_plan_ref`
- `acceptance_criteria_refs`
- `source_refs`
- `cases`
- `execution_requirements`
- `review_status`

Case fields:

- `case_id`
- `title`
- `initial_url`
- `preconditions`
- `steps`
- `expected_result`
- `test_type`
- `acceptance_criteria_refs`
- `command`

## Test Execution Report

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `test_plan_ref`
- `commands`
- `exit_code`
- `passed`
- `failed`
- `improvement_cycle`
- `blocked_on_failure`
- `log_summary`
- `artifact_refs`

## Review Or QA Verdict

Fields:

- `schema_version`
- `artifact_type`
- `run_id`
- `task_id`
- `stage`
- `review_kind`
- `verdict`
- `findings`
- `affected_acceptance_criteria_refs`
- `required_fixes`
- `evidence_refs`
- `within_approved_scope`
- `risk_level`
- `authority_required`
- `improvement_cycle`
- `supersedes_ref`
- `created_at`

`artifact_type` enum:

`review_report | qa_report | re_review_report | re_qa_report`

`review_kind` enum:

`code_review | qa | test_review | security_review`

`verdict` enum:

`approve | request_changes | reject | block`

Finding fields:

- `finding_id`
- `severity`
- `summary`
- `affected_files`
- `affected_acceptance_criteria_refs`
- `evidence_refs`
- `required_fix`

Severity enum:

`low | medium | high | critical`

Routing rules:

- `approve` remains subject to Gateway Advancement Gate validation.
- `request_changes` routes to Stage 4 `improvement` when in scope and below human-risk gates.
- `reject` blocks or requests Kimi decision depending on recoverability.
- `block` routes to Kimi decision or Human Approval according to `authority_required`.
- Re-review artifacts must use `supersedes_ref` to point at the prior verdict and must not overwrite it.

## Worker Response

Fields follow `hermes-role-engine/v1`:

- `protocol`
- `role`
- `correlation_id`
- `turn`
- `status`
- `next_action`
- `role_specific_payload`
- `conversation_context`

Shared `next_action` enum:

`continue | request_context | wait_for_user | create_tasks | create_research_task | block | complete | defer_to_human`

`next_action: complete` is a requested transition, not authority to complete a Kanban task or stage.

`conversation_context` must be a compact state summary or artifact-ref list. It must not contain raw chat history, secrets, absolute paths, or whole-project dumps.

Context request payload fields:

- `reason`
- `needed_refs`
- `needed_scope`
- `risk_if_missing`

Context requests must be satisfied through artifact refs or Worker Context Bundle refs, not raw prompt injection.

## State-Advancing Worker Output

State-advancing worker responses are Worker Responses where `next_action` is `complete`, `block`, `create_tasks`, or `defer_to_human`.

Required validation fields:

- `requested_transition`
- `artifact_refs`
- `changed_files`
- `diff_summary`
- `write_scope_result`
- `test_evidence_refs`
- `risk_notes`
- `approval_refs`

For non-code or read-only tasks, `changed_files`, `diff_summary`, or `test_evidence_refs` may be empty when the task type does not require them, but the fields must still be present for validation.

`requested_transition` enum:

`none | task_complete | task_blocked | create_child_tasks | defer_to_human`

`write_scope_result` fields:

- `within_scope`
- `violations`
- `forbidden_paths_touched`

Gateway advancement validation:

- response protocol and schema are valid
- `run_id`, `task_id`, `correlation_id`, and `role` match the dispatched task
- critical `artifact_refs` resolve and referenced artifacts are schema-valid
- changed files are within `allowed_write_scope`
- no forbidden path or approval-boundary violation exists
- required test or review evidence exists when the task type requires it

Only the Gateway may turn a state-advancing Worker Response into Gateway State updates, Audit records, or official Kanban lifecycle commands.

## Worker Context Envelope

Fields follow `hermes-role-engine/v1`:

- `protocol`
- `run_id`
- `task_id`
- `correlation_id`
- `stage`
- `role`
- `selected_backend`
- `task`
- `risk_level`
- `approval_state`
- `allowed_write_scope`
- `workspace_strategy`
- `artifact_refs`
- `context_bundle_refs`
- `test_requirements`
- `output_schema_ref`

`allowed_write_scope` fields:

- `mode`
- `paths`
- `forbidden_paths`
- `requires_human_approval`

`allowed_write_scope.mode` enum:

`read_only | scoped_write | no_write`

Forbidden input fields or payloads:

- raw chat history
- secret environment values
- absolute local filesystem paths
- full project dump
- unrelated prior conversation
- unredacted temporary raw ticket

## Worker Context Bundle

Fields:

- `schema_version`
- `bundle_id`
- `run_id`
- `task_id`
- `scope`
- `source_refs`
- `summaries`
- `file_excerpt_refs`
- `created_at`
- `redaction_applied`

Context bundles are read-only. Additional context must be supplied through new bundle refs or artifact refs and recorded in Audit.

## Worker Backend Registry Entry

Fields:

- `name`
- `enabled`
- `adapter_type`
- `command`
- `api_endpoint`
- `supported_modes`
- `capabilities`
- `health_check`
- `version_probe`
- `workspace_support`

`adapter_type` enum:

`cli | api`

`workspace_support` enum:

`kanban_worktree | direct_project | none`

## Worker Role Registry Entry

Fields:

- `role`
- `required_capabilities`
- `preferred_backends`
- `fallback_backends`
- `fallback_allowed_failure_classes`
- `protocol`

`protocol` must be `hermes-role-engine/v1`.

`fallback_allowed_failure_classes` is limited to retryable backend failures unless explicitly extended by a future ADR. It must not include `schema_mismatch`, security policy hits, Human Approval boundaries, or forbidden automatic modification targets.

## Worker Selection Record

Fields:

- `role`
- `requested_backend`
- `selected_backend`
- `backend_version`
- `matched_capabilities`
- `adapter_type`
- `fallback_used`
- `fallback_reason`
- `failure_class`
- `attempt`
- `audit_ref`

Worker selection records are written to Gateway State and Audit before worker dispatch.

## Decision Request

Fields:

- `schema_version`
- `decision_id`
- `run_id`
- `task_id`
- `stage`
- `reason`
- `risk_level`
- `authority_required`
- `options`
- `expires_at`
- `artifact_refs`

`authority_required` enum:

`kimi | human`

## Decision Command Request

Fields:

- `schema_version`
- `idempotency_key`
- `action`
- `actor`
- `rationale`
- `revision`

Action enum:

`approve | reject | revise`

## Decision Response

Fields:

- `schema_version`
- `command_id`
- `idempotency_key`
- `action`
- `actor`
- `rationale`
- `revision`
- `event_projection_degraded`
- `projection_status`
- `projection_issue_refs`

Action enum:

`approve | reject | revise`

Stopping a run is represented by the run stop endpoint and `run_stopped` event, not by this decision action enum.

Decision command requests require `idempotency_key`. Repeating the same `decision_id`, `idempotency_key`, and canonical action payload returns the prior result. Reusing the same key with a different payload returns `409 conflict`.

`revision` fields for `action: revise`:

- `revision_of_task_id`
- `revision_of_stage`
- `source_artifact_refs`
- `revised_child_task_id`
- `revised_stage_attempt_id`
- `rationale`

Revision actions create new child tasks or stage attempts inside the same blocked run. They must not overwrite source artifacts.

## Stop Run Request

Fields:

- `schema_version`
- `idempotency_key`
- `reason`
- `force`

## Stop Run Response

Fields:

- `schema_version`
- `command_id`
- `idempotency_key`
- `run_id`
- `status`
- `run_stopped_event_ref`
- `stop_audit_ref`
- `partial_closeout_ref`
- `event_projection_degraded`
- `projection_status`
- `projection_issue_refs`

Repeating the same stop payload for the same run and `idempotency_key` returns the same response and must not write another stop Event, Audit record, cancel marker, or partial closeout.

## Capabilities Response

Fields:

- `schema_version`
- `gateway`
- `upstream_api`
- `kanban`
- `workers`
- `roles`
- `cache`
- `debaters`

Worker backend fields:

- `name`
- `enabled`
- `available`
- `version`
- `cli`
- `modes`
- `capabilities`
- `missing_dependency`
- `compatible_roles`
- `health_checked_at`
- `selection_blocked_reason`

Cache fields:

- `backend`
- `available`
- `root`
- `degraded`
- `fallback_backend`

Cache backend enum:

`local_filesystem | redis`

Debater backend fields:

- `name`
- `enabled`
- `available`
- `backend_type`
- `degraded`
- `missing_dependency`

Debater backend type enum:

`real | template`

## Failure Classes

Enum:

`timeout | crash | rate_limit | parse_error | schema_mismatch | test_failed | review_changes_requested | review_rejected | qa_blocked | improvement_exhausted | global_evaluation_failed | global_evaluation_blocked | decision_expired`

## Validation Policy

Request schema failure returns HTTP 400 and creates no run.

Mutating requests without `idempotency_key` return HTTP 400 before State, Audit, Kanban, worker, or artifact side effects.

Reusing an `idempotency_key` with the same endpoint scope and same canonical payload returns the stored command result. It must not duplicate Events, Audit records, Kanban mutations, run creation, decision resolution, or stop records.

Reusing an `idempotency_key` with the same endpoint scope but a different canonical payload returns HTTP 409.

If the stored command result has `event_projection_degraded: true`, idempotency replay returns the same successful authority result and degradation metadata. Replay must not repeat authoritative side effects merely to repair Events.

Before any mutating side effect, Gateway must write a `command_record` with `status: in_progress`, command intent, canonical payload hash, and planned steps.

On startup, Gateway must reconcile every `in_progress` command record against Gateway State, Audit, Hermes Kanban, and artifact refs.

If reconciliation proves the command completed, Gateway backfills missing response refs and marks the command `completed` without re-executing side effects.

If reconciliation proves a step has not executed, Gateway may continue from the next unexecuted planned step.

If reconciliation cannot prove whether a side effect happened, Gateway writes `command_reconciliation_report`, marks the related run or task `blocked`, emits `decision_required`, and must not blindly replay the command.

Artifact schema failure blocks the current stage.

Worker response schema failure becomes `schema_mismatch` and hard-blocks without fallback.

State-advancing worker output that fails artifact, write-scope, approval, or evidence validation blocks the task or routes through the configured decision/improvement path. It must not advance Gateway State or Kanban lifecycle.

Review and QA verdict artifacts are immutable. Re-review writes a new artifact with `supersedes_ref`.

Automatic improvement beyond cycle `1` is invalid in MVP. Continued failure after the first improvement cycle becomes `improvement_exhausted` and blocks completion.

Stage 6 closeout cannot start until `global_evaluation_report.verdict` is `pass` or Kimi-accepted `pass_with_warnings`.

Closeout validation failure prevents run status from becoming `completed`.

Blocked run validation preserves Gateway State, Audit, Kanban task state, artifact refs, blocker reason, pending decision refs, and resume checkpoints. A blocked run is active and must not produce completed closeout.

Failed run validation is terminal and requires `run_failed`, immutable failure Audit evidence, a `run_failure_report`, preserved State/Audit/Kanban/artifact refs, and `last_good_checkpoint_ref` when one exists. A run may become `failed` only when Gateway/State/Audit/Kanban authority-chain corruption, unrecoverable critical artifact loss, unauthorized writes that make the run untrusted, or unrecoverable internal invariant violation prevents safe continuation.

Ordinary test failure, review rejection, QA block, schema mismatch, decision expiration, missing approval, timeout, rate limit, and repeated worker failure validate as blocked by default. If the Gateway cannot prove terminal failure, it must keep the run blocked and emit decision or repair evidence.

Event Projection inconsistency validates as an observation/projection issue, not a blocked or failed run condition, when State, Audit, Kanban, and artifact refs remain mutually consistent.

Stopped run validation requires `run_stopped`, immutable stop Audit evidence, preserved State/Audit/Kanban/artifact refs, and an `iteration_closeout_report` with `closeout_kind: stopped_before_completion`. It must not resolve pending decisions unless a separate decision record exists.

Terminal run validation forbids in-place resume for `failed` and `stopped` statuses. A continuation must create a new run with a valid `run_lineage` artifact, `source_run_id`, and scoped `resume_from_refs`.

Lineage validation requires the source run to be terminal with status `failed` or `stopped`, the source run to remain read-only for workflow continuation, and all `resume_from_refs` to be scoped to the source run. Active `blocked` runs must resume through the decision API, not through a new lineage run.

Run completion validation requires schema-valid `iteration_closeout_report` with `closeout_kind: completed`, schema-valid `system_improvement_proposals`, Kanban lifecycle completion, Gateway State consistency, immutable Audit closeout evidence, and schema-valid required artifacts. Cache refs, partial closeout records, closeout summaries, and model self-report are ignored as completion authority.
