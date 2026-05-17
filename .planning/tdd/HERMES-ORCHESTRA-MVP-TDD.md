# Hermes Orchestra MVP TDD Ledger

Source PRD: `.planning/specs/HERMES-ORCHESTRA-MVP-PRD.md`

## Behavior Backlog

| ID | Behavior | Public Interface | Priority | Status |
|---|---|---|---|---|
| GW-001 | Structured ticket creates a Six-Stage Run with status, events, tasks, State, Audit, and command evidence | `POST /orchestra/runs`; `GET /orchestra/runs/{run_id}`; `GET /orchestra/runs/{run_id}/events`; `GET /orchestra/runs/{run_id}/tasks` | P0 | done |
| GW-002 | Same idempotency key and same payload replays the original run-create result without duplicate side effects | `POST /orchestra/runs` | P0 | done |
| GW-003 | Same idempotency key and different payload returns conflict | `POST /orchestra/runs` | P0 | done |
| GW-004 | Missing idempotency key on mutating run create returns validation failure | `POST /orchestra/runs` | P0 | done |
| GW-005 | A second active run in the same project is rejected after idempotency replay is checked | `POST /orchestra/runs` | P0 | done |
| GW-006 | Short intent without structured acceptance criteria blocks before direction debate and emits decision_required | `POST /orchestra/runs`; events/status | P0 | done |
| GW-007 | Stop moves queued or blocked active run to terminal stopped while preserving State, Audit, Events, tasks, and partial closeout | `POST /orchestra/runs/{run_id}/stop`; status/events/tasks | P0 | done |
| GW-008 | Stop command is idempotent for the same key and payload | `POST /orchestra/runs/{run_id}/stop` | P0 | done |
| GW-009 | Continuing from a stopped run creates a new lineage run and preserves the source run as read-only evidence | `POST /orchestra/runs` with `source_run_id` and `resume_from_refs` | P0 | done |
| GW-010 | Creating a lineage run from an active blocked source is rejected because blocked runs recover in place | `POST /orchestra/runs` with active `source_run_id` | P0 | done |
| GW-011 | Approving a blocked intake decision with a structured ticket resumes the same run and creates six stage tasks | `POST /orchestra/decisions/{decision_id}`; status/events/tasks | P0 | done |
| GW-012 | Decision approve is idempotent for same key and payload | `POST /orchestra/decisions/{decision_id}` | P0 | done |
| GW-013 | Event polling with `limit` returns `next_seq` after the last returned event instead of skipping unread events | `GET /orchestra/runs/{run_id}/events` | P0 | done |
| GW-014 | Lineage `resume_from_refs` reject traversal even when the ref has the source run prefix | `POST /orchestra/runs` with `source_run_id` | P0 | done |
| GW-015 | Capabilities expose worker backend registry and run create rejects unknown or role-incompatible worker pairing | `GET /orchestra/capabilities`; `POST /orchestra/runs` | P0 | done |
| GW-016 | `/v1/*` remains separate from Orchestra semantics and returns degraded proxy responses when upstream Hermes API is unavailable | `GET /health`; `/v1/*` | P0 | done |
| GW-017 | Events endpoint supports SSE resume using the same per-run sequence as JSON polling | `GET /orchestra/runs/{run_id}/events` with `Accept: text/event-stream` | P0 | done |
| GW-018 | Run create returns degraded success when Event append fails after authority writes and replay does not repeat side effects | `POST /orchestra/runs` | P0 | done |
| GW-019 | Event polling rebuilds a missing Event Store from State/Audit/command authorities without inventing Audit evidence | `GET /orchestra/runs/{run_id}/events` | P0 | done |
| GW-020 | Advancement Gate hard-blocks schema-invalid state-advancing worker output before State/Kanban advancement | `POST /orchestra/runs/{run_id}/worker-outputs`; status/events/tasks | P0 | done |
| GW-021 | Advancement Gate blocks state-advancing worker output whose correlation identity does not match the target task | `POST /orchestra/runs/{run_id}/worker-outputs`; status/events/tasks | P0 | done |
| GW-022 | Advancement Gate blocks state-advancing worker output with invalid or out-of-scope artifact refs | `POST /orchestra/runs/{run_id}/worker-outputs`; status/events/tasks | P0 | done |
| GW-023 | Advancement Gate blocks state-advancing worker output that violates allowed write scope or forbidden paths | `POST /orchestra/runs/{run_id}/worker-outputs`; status/events/tasks | P0 | done |
| GW-024 | Advancement Gate blocks code-changing completion requests that lack required test evidence refs | `POST /orchestra/runs/{run_id}/worker-outputs`; status/events/tasks | P0 | done |
| GW-025 | Advancement Gate accepts a valid worker task completion request by writing evidence and completing only the target Kanban task | `POST /orchestra/runs/{run_id}/worker-outputs`; status/events/tasks | P0 | done |
| GW-026 | Structured review verdict `request_changes` writes immutable verdict evidence and routes in-scope feedback to bounded Stage 4 improvement | `POST /orchestra/runs/{run_id}/verdicts`; status/events/tasks | P0 | done |
| GW-027 | Structured review verdict `block` requiring Human Approval keeps the run active blocked with pending decision evidence | `POST /orchestra/runs/{run_id}/verdicts`; status/events/tasks | P0 | done |
| GW-028 | A second `request_changes` verdict after one automatic improvement cycle blocks as `improvement_exhausted` instead of starting another hidden repair loop | `POST /orchestra/runs/{run_id}/verdicts`; status/events/tasks | P0 | done |
| GW-029 | Global evaluation `pass_with_warnings` writes the report and blocks for Kimi final acceptance before Stage 6 can start | `POST /orchestra/runs/{run_id}/global-evaluations`; status/events | P0 | done |
| GW-030 | Kimi final acceptance of `pass_with_warnings` resumes the same run into Stage 6 without completing it | `POST /orchestra/decisions/{decision_id}`; status/events | P0 | done |
| GW-031 | Stage 6 closeout rejects summary-only completion attempts without writing completion evidence | `POST /orchestra/runs/{run_id}/closeout`; status/events | P0 | done |
| GW-032 | Schema-valid Stage 6 closeout with completed stage tasks and final acceptance marks the run completed through the completion gate | `POST /orchestra/runs/{run_id}/closeout`; status/events | P0 | done |
| GW-033 | Global evaluation `pass` writes the report and queues Stage 6 without a final-acceptance decision | `POST /orchestra/runs/{run_id}/global-evaluations`; status/events | P0 | done |
| GW-034 | Capabilities expose Gateway, Kanban, worker, cache, and debater authority-layer projections | `GET /orchestra/capabilities` | P0 | done |
| GW-035 | Event polling detects sequence gaps as projection inconsistency without changing run authority state | `GET /orchestra/runs/{run_id}/events`; status | P0 | done |
| GW-036 | Stage 6 completion gate rejects auto-applied proposals outside `.workflow/knowledge/*` | `POST /orchestra/runs/{run_id}/closeout`; status | P0 | done |
| GW-037 | Startup recovery marks an in-progress create-run command completed without replay when State, Tasks, and Audit already prove completion | Gateway startup; status/command artifact | P0 | done |
| GW-038 | Startup recovery blocks an ambiguous in-progress create-run command with reconciliation evidence instead of replaying side effects | Gateway startup; status/events/command artifact | P0 | done |
| GW-039 | Global evaluation rejects absolute or out-of-scope scalar artifact refs before writing authority artifacts | `POST /orchestra/runs/{run_id}/global-evaluations`; status/events | P0 | done |
| GW-040 | Global evaluation `block` with Human Approval authority writes evidence and blocks Stage 6 behind a pending decision | `POST /orchestra/runs/{run_id}/global-evaluations`; status/events | P0 | done |
| GW-041 | Global evaluation `fail` blocks Stage 6 with failure evidence when automatic repair cannot proceed | `POST /orchestra/runs/{run_id}/global-evaluations`; status/events | P0 | done |
| GW-042 | Startup recovery continues an in-progress create-run command from a proven checkpoint without duplicating prior side effects | Gateway startup; status/events/command artifact | P0 | done |
| GW-043 | Structured review verdict `reject` writes immutable verdict evidence and blocks for an explicit decision | `POST /orchestra/runs/{run_id}/verdicts`; status/events/tasks | P0 | done |
| GW-044 | Structured QA verdict `block` with Kimi authority writes evidence and blocks for a pending decision | `POST /orchestra/runs/{run_id}/verdicts`; status/events/tasks | P0 | done |
| GW-045 | Structured review verdict `approve` records approval evidence without completing workflow authority by itself | `POST /orchestra/runs/{run_id}/verdicts`; status/events/tasks | P0 | done |
| GW-046 | Explicit coverage proves missing run-create idempotency key returns 400 before mutating side effects | `POST /orchestra/runs` | P0 | done |
| GW-047 | Successful MVP closeout exposes required acceptance artifacts, worker context evidence, CLI worker evidence, stage completion events, and downgrade/audit evidence | Existing `/orchestra/*` run, worker output, global evaluation, decision, closeout APIs | P0 | done |
| GW-048 | Terminal failed run writes `run_failure_report`, `run_failed` Event, immutable Audit evidence, preserved refs, and can seed a lineage run without mutating the source | `POST /orchestra/runs/{run_id}/failures`; `POST /orchestra/runs` with failed `source_run_id` | P0 | done |
| GW-049 | Machine-readable schema bundle covers Schema Summary core definitions, required fields, and critical enums | `config/schemas/orchestra.schema.json`; `make lint-json` | P0 | done |
| GW-050 | Worker and debate registries are project-configurable and capabilities expose config refs plus 16 debate teams and 8 debate modes | `config/workers/*.json`; `config/debate/*.json`; `GET /orchestra/capabilities` | P0 | done |

## TDD Cycles

### GW-001 structured ticket creates a Six-Stage Run

Status: GREEN

Public interface:
- `POST /orchestra/runs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-run-create.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-create.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`
- Broader smoke: `rtk bash scripts/tests/run-all.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-create.sh`
- Expected failure: Gateway entrypoint is not implemented yet.
- Observed failure: `FAIL gateway-run-create: gateway entrypoint missing`.

GREEN:
- Added `scripts/bin/orch-gateway`.
- Added `scripts/lib/orch_gateway.py`.
- `POST /orchestra/runs` accepts a structured ticket and idempotency key.
- Gateway writes run State, command record, task projection, Audit evidence, and Event Store.
- Gateway creates six stage task projections and calls the external `hermes kanban create` boundary.
- `GET /orchestra/runs/{run_id}`, `/events`, and `/tasks` return the created run projection.
- Verification passed for the target test and Python syntax check.

Refactor:
- Kept the implementation inside a small stdlib HTTP adapter.
- Suppressed noisy `git init` hints in the new integration test.

Broader verification:
- Command: `rtk bash scripts/tests/run-all.sh`
- Result: 25 passed, 1 failed.
- Failure: existing `scripts/tests/test-specs.sh` reports `consumer path does not exist: WORKFLOW.md`.
- Assessment: unrelated existing spec/docs metadata drift; GW-001 target test passed inside the same run.

Next:
- GW-002 idempotent run-create replay.

### GW-002 idempotent run-create replay

Status: GREEN

Public interface:
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-run-idempotency-replay.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-idempotency-replay.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-idempotency-replay.sh`
- Expected failure: Gateway does not persist completed idempotency results yet.
- Observed failure: second identical `POST /orchestra/runs` returned a different `run_id` and `command_id`.

GREEN:
- Added Gateway State idempotency records scoped by project, endpoint, resource path, and idempotency key.
- Completed run-create commands store the original response summary and HTTP status.
- Same key plus same canonical payload returns the stored response before any new run, Kanban, Audit, or Event side effects.
- Verification passed for replay and the original GW-001 create/status/events/tasks slice.

Refactor:
- Kept conflict and in-progress replay behavior out of this cycle; those remain separate backlog items.

Next:
- GW-003 idempotency key payload conflict.

### GW-003 idempotency key payload conflict

Status: GREEN

Public interface:
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-run-idempotency-conflict.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-idempotency-conflict.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-idempotency-conflict.sh`
- Expected failure: Gateway does not reject same idempotency key with a different canonical payload.
- Observed failure: conflicting request returned `201` and created a second run instead of `409`.

GREEN:
- Added the idempotency conflict branch before run creation side effects.
- Conflicting reuse now returns `409` with `error.code: idempotency_conflict`.
- Test confirms no second run directory, Audit entry, Event Store, or Kanban create calls are produced.

Refactor:
- None.

Next:
- GW-005 one-active-run enforcement. GW-004 validation branch exists from the initial route validation and still needs explicit coverage before it is marked done.

### GW-005 one-active-run enforcement

Status: GREEN

Public interface:
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-run-active-conflict.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-active-conflict.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-active-conflict.sh`
- Expected failure: Gateway does not enforce one active run per project yet.
- Observed failure: second run-create request with a different idempotency key returned `201` and created a competing queued run.

GREEN:
- Added active run detection for `queued`, `running`, and `blocked` statuses.
- New run-create commands with a different idempotency key now return `409 active_run_conflict` while a run is active.
- The test confirms idempotency replay for the original command is checked before active-run conflict.
- The conflict path creates no second run directory, Audit record, Event, or Kanban tasks.

Refactor:
- None.

Next:
- GW-006 short intent structured PRD gate.

### GW-006 short intent structured PRD gate

Status: GREEN

Public interface:
- `POST /orchestra/runs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-run-short-intent-blocks.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-short-intent-blocks.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-short-intent-blocks.sh`
- Expected failure: intent-only request should create an intake-blocked run.
- Observed failure: create response returned `status: queued` and entered the normal Six-Stage Run path.

GREEN:
- Added an intent-only intake path for run creation.
- Short intent now writes incomplete `structured_prd.json`, blocked run State, empty task projection, Audit evidence, and three ordered Events: `run_created`, `ticket_normalized`, `decision_required`.
- The Six-Stage DAG does not start and no Kanban stage tasks are created until structured PRD requirements are supplied.
- The run remains active as `blocked`, preserving one-active-run semantics.

Refactor:
- None.

Next:
- Expand backlog from PRD after the intake spine is covered.

### GW-007 stop preserves evidence and writes partial closeout

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/stop`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-run-stop.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-stop.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-stop.sh`
- Expected failure: stop route is not implemented yet.
- Observed failure: `POST /orchestra/runs/{run_id}/stop` returned HTTP 404.

GREEN:
- Added `POST /orchestra/runs/{run_id}/stop`.
- Stop writes a command journal, updates run State to terminal `stopped`, preserves task projection, writes `partial_closeout.json`, appends `run_stopped` Audit evidence, and appends a post-commit `run_stopped` Event.
- Active run marker is retained as stopped evidence but no longer counts as active because only `queued`, `running`, and `blocked` are active statuses.

Refactor:
- None.

Next:
- GW-008 stop idempotency replay.

### GW-008 stop idempotency replay

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/stop`

Test:
- `scripts/tests/test-gateway-run-stop-idempotency-replay.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-stop-idempotency-replay.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-stop-idempotency-replay.sh`
- Expected failure: stop does not replay completed command results yet.
- Observed failure: second identical stop request returned `409 run_not_active` because run status was already `stopped`.

GREEN:
- Added stop idempotency records scoped by project, endpoint, resource path, and idempotency key.
- Completed stop commands now replay the original response before terminal-status checks.
- Replaying stop does not create duplicate command records, Audit entries, Events, partial closeout artifacts, or status transitions.

Refactor:
- None.

Next:
- GW-009 stopped run releases active slot.

### GW-009 lineage run from stopped source

Status: GREEN

Public interface:
- `POST /orchestra/runs`
- `GET /orchestra/runs/{run_id}`

Test:
- `scripts/tests/test-gateway-run-lineage-from-stopped.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-lineage-from-stopped.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-lineage-from-stopped.sh`
- Expected failure: lineage creation from stopped source is not implemented.
- Observed failure: new run response returned `source_run_id: null` and `lineage_ref: null`.

GREEN:
- Added source run validation for lineage requests.
- New runs from stopped sources write `lineage.json`, set `source_run_id` and `lineage_ref` in response/status, and append `run_lineage_created` Audit evidence.
- `resume_from_refs` are constrained to `state://runs/{source_run_id}/...` refs for this slice.
- Source run State remains terminal `stopped`.

Refactor:
- None.

Next:
- Lineage rejection from active blocked source.

### GW-010 blocked source lineage rejection

Status: GREEN

Public interface:
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-lineage-from-blocked-rejected.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-lineage-from-blocked-rejected.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-lineage-from-blocked-rejected.sh`
- Expected failure: lineage creation from an active blocked source should return `409 lineage_source_not_terminal` and preserve the blocked source for in-place decision recovery.
- Observed failure: request returned `409 active_run_conflict`, losing the source-run-specific recovery contract.

GREEN:
- Moved lineage source validation ahead of generic active-run conflict when `source_run_id` is present.
- Active blocked sources now return `409 lineage_source_not_terminal` with `source_status: blocked` and `recovery_mode: decision_in_place`.
- The rejection path writes no new command journal, idempotency record, Audit lineage entry, Kanban tasks, or second run directory.

Refactor:
- None.

Next:
- GW-004 explicit idempotency-key validation coverage or projection rebuild.

### GW-011 approve blocked intake decision

Status: GREEN

Public interface:
- `POST /orchestra/decisions/{decision_id}`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-decision-approve-intake.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-decision-approve-intake.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-decision-approve-intake.sh`
- Expected failure: decision route is not implemented yet.
- Observed failure: `POST /orchestra/decisions/{decision_id}` returned HTTP 404.

GREEN:
- Added `POST /orchestra/decisions/{decision_id}` for the first approve path.
- Gateway finds the blocked run by `pending_decision_id`, writes ready `structured_prd.json`, creates six stage tasks, updates the same run back to `queued`, clears blocker fields, appends `decision_resolved` Audit evidence, and emits a post-commit `decision_resolved` Event.
- The source run identity is preserved; this is in-place recovery, not a lineage run.

Refactor:
- None.

Next:
- Decision idempotency replay.

### GW-012 decision approve idempotency replay

Status: GREEN

Public interface:
- `POST /orchestra/decisions/{decision_id}`

Test:
- `scripts/tests/test-gateway-decision-idempotency-replay.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-decision-idempotency-replay.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-decision-idempotency-replay.sh`
- Expected failure: decision approve replay is not implemented yet.
- Observed failure: second identical approve returned `404 decision not found` after the first command cleared `pending_decision_id`.

GREEN:
- Added decision idempotency records scoped by project, endpoint, resource path, and idempotency key.
- Completed approve commands replay before looking up `pending_decision_id`, so clearing the pending decision does not make retries unsafe.
- Replaying approve does not create duplicate command records, Events, Audit entries, or Kanban tasks.

Refactor:
- None.

Next:
- Event `since_seq` and gap-safe polling semantics.

### GW-013 event polling pagination

Status: GREEN

Public interface:
- `GET /orchestra/runs/{run_id}/events?since_seq=&limit=`

Test:
- `scripts/tests/test-gateway-events-pagination.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-events-pagination.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-events-pagination.sh`
- Expected failure: event pagination `next_seq` currently skips unread events when `limit` truncates the page.
- Observed failure: `limit=1` returned only `seq=1` but `next_seq: 4`.

GREEN:
- `next_seq` now advances from the last returned event in the current page.
- `has_more` still reports whether more events remain after the returned page.
- This prevents Kimi/SSE clients from skipping event gaps during paginated polling.

Refactor:
- None.

Next:
- Event privacy redaction or artifact ref resolver.

### GW-014 lineage resume ref traversal rejection

Status: GREEN

Public interface:
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-lineage-ref-scope.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-lineage-ref-scope.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-lineage-ref-scope.sh`
- Expected failure: lineage ref validator only checks prefix and misses traversal.
- Observed failure: `state://runs/{source}/../other-run/run.json` returned `201` and created a lineage run.

GREEN:
- Added scoped state ref validation for lineage `resume_from_refs`.
- Refs must start with `state://runs/{source_run_id}/` and their suffix cannot contain empty path segments, `.`, or `..`.
- Traversal attempts now return `400 invalid_artifact_ref` before command journal or side effects.

Refactor:
- None.

Next:
- Artifact ref cross-run rejection or worker registry capabilities.

### GW-015 worker backend registry and negotiation

Status: GREEN

Public interface:
- `GET /orchestra/capabilities`
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-worker-registry.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-worker-registry.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-worker-registry.sh`
- Expected failure: worker registry/capability negotiation is not implemented.
- Observed failure: `GET /orchestra/capabilities` response lacked `worker_backends`.

GREEN:
- Added static worker backend registry to capabilities.
- Run creation now validates `options.worker_pairing` before idempotency side effects, active-run checks, command journals, or Kanban mutations.
- Unknown backend returns `400 worker_backend_unknown`; role-incompatible backend returns `400 worker_backend_role_incompatible`.
- Valid `codex` implementer + `claude` reviewer pairing creates the run normally.

Refactor:
- None.

Next:
- Worker context envelope or advancement gate schema validation.

### GW-016 upstream `/v1/*` degraded proxy

Status: GREEN

Public interface:
- `GET /health`
- `GET /v1/*`

Test:
- `scripts/tests/test-gateway-v1-proxy-degraded.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-v1-proxy-degraded.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-v1-proxy-degraded.sh`
- Expected failure: upstream API health/proxy degraded behavior is not implemented.
- Observed failure: `/health` returned `upstream_api: not_checked`.

GREEN:
- `/health` now probes the configured upstream API and reports `upstream_api: degraded` when unavailable.
- `GET /v1/*` and `POST /v1/*` stay separate from `/orchestra/*` and return `502 upstream_unavailable` when the official Hermes API upstream is unavailable.
- `/orchestra/*` tests continue to work without requiring the official upstream server.

Refactor:
- None.

Next:
- `/v1/*` successful proxy or privacy boundary.

### GW-017 event SSE resume

Status: GREEN

Public interface:
- `GET /orchestra/runs/{run_id}/events?since_seq=` with `Accept: text/event-stream`

Test:
- `scripts/tests/test-gateway-events-sse.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-events-sse.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-events-sse.sh`
- Expected failure: events endpoint does not support SSE yet.
- Observed failure: request with `Accept: text/event-stream` returned `Content-Type: application/json`.

GREEN:
- Events endpoint now honors `Accept: text/event-stream`.
- SSE output uses the same `seq` as JSON polling via `id: {seq}`, emits `event: {type}`, and serializes each event in `data:`.
- `since_seq` resume works for SSE through the existing `run_events` query path.

Refactor:
- None.

Next:
- Projection inconsistency/degraded response.

### GW-018 projection degraded success on event append failure

Status: GREEN

Public interface:
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-run-event-degraded.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-event-degraded.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-event-degraded.sh`
- Expected failure: Gateway does not surface Event append failure as projection degradation yet.
- Observed failure: run-create response returned `event_projection_degraded: false` and `projection_status: consistent` under event append fault injection.

GREEN:
- Added event append wrapper for run creation.
- Fault-injected Event append failure now writes a scoped projection issue artifact, returns successful authority result with `event_projection_degraded: true`, `projection_status: inconsistent`, and `projection_issue_refs`.
- Idempotency replay returns the same degraded authority result and does not repeat run, Kanban, Audit, command, or Event side effects.

Refactor:
- None.

Next:
- Projection rebuild or advancement gate.

### GW-019 missing Event Store rebuild

Status: GREEN

Public interface:
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-events-rebuild.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-events-rebuild.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-events-rebuild.sh`
- Expected failure: missing Event Store after append degradation should be rebuilt from State/Audit/command authority and returned with `projection_status: rebuilt`.
- Observed failure: events response returned an empty event list with `projection_status: consistent` and no rebuild refs.

GREEN:
- Added missing Event Store rebuild for the run-created projection when State, task projection, command record, and Audit authority are complete.
- `GET /events` now returns `projection_status: rebuilt`, `rebuilt_from_refs`, original projection issue refs, and a reconstructed `run_created` event on first read.
- The rebuilt Event Store is persisted under Gateway State; subsequent reads return the same events as `projection_status: consistent`.
- Rebuild does not append or invent Audit evidence.

Refactor:
- None.

Next:
- Advancement Gate schema/identity/artifact validation for worker outputs.

### GW-020 schema-invalid worker output blocks advancement

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-worker-output-schema-mismatch.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-worker-output-schema-mismatch.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-worker-output-schema-mismatch.sh`
- Expected failure: Gateway should expose a worker-output submission endpoint and block schema-invalid state-advancing output.
- Observed failure: `POST /orchestra/runs/{run_id}/worker-outputs` returned HTTP 404.

GREEN:
- Added `POST /orchestra/runs/{run_id}/worker-outputs` as the Advancement Gate entrypoint.
- Schema-invalid state-advancing worker output now writes a validation report, blocks the run and target task with `worker_output_schema_mismatch`, appends Audit evidence, and emits `worker_output_blocked`.
- The blocked path does not call Kanban lifecycle completion and does not emit `task_completed`.

Refactor:
- None.

Next:
- Advancement Gate identity mismatch validation.

### GW-021 worker output identity mismatch blocks advancement

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-worker-output-identity-mismatch.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-worker-output-identity-mismatch.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-worker-output-identity-mismatch.sh`
- Expected failure: schema-valid but correlation-mismatched worker output should be blocked as `identity_mismatch`.
- Observed failure: request returned HTTP 400 because only schema-mismatch blocking was implemented.

GREEN:
- Added correlation identity validation after worker response schema validation.
- Schema-valid state-advancing output whose `correlation_id` does not match the target task now blocks the run and task with `worker_output_identity_mismatch`.
- The block path writes a validation report, Audit evidence, and `worker_output_blocked` Event without calling Kanban completion.

Refactor:
- Kept successful `complete` advancement out of this cycle; only validation failures are implemented.

Next:
- Advancement Gate artifact ref validation.

### GW-022 worker output artifact ref validation

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-worker-output-artifact-ref-invalid.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-worker-output-artifact-ref-invalid.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-worker-output-artifact-ref-invalid.sh`
- Expected failure: schema-valid, identity-matched worker output with traversal artifact refs should be blocked as `artifact_ref_invalid`.
- Observed failure: request returned HTTP 400 because artifact ref validation was not implemented.

GREEN:
- Added artifact ref validation for state-advancing worker output after schema and identity checks.
- Worker output refs must be scoped to the current run through `state://runs/{run_id}/...` and reject traversal.
- Invalid artifact refs now block the run and task with `worker_output_artifact_ref_invalid`, write a validation report, append Audit, and emit `worker_output_blocked`.

Refactor:
- None.

Next:
- Advancement Gate write-scope and forbidden-path validation.

### GW-023 worker output write-scope validation

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-worker-output-write-scope-violation.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-worker-output-write-scope-violation.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-worker-output-write-scope-violation.sh`
- Expected failure: worker output with `write_scope_result.within_scope=false` or forbidden paths should be blocked as `write_scope_violation`.
- Observed failure: request returned HTTP 400 because write-scope validation was not implemented.

GREEN:
- Added write-scope validation after schema, identity, and artifact-ref checks.
- Worker output with `within_scope=false`, non-empty `violations`, or non-empty `forbidden_paths_touched` now blocks the run and task with `worker_output_write_scope_violation`.
- The blocked path writes a validation report, Audit evidence, and `worker_output_blocked` Event without Kanban completion.

Refactor:
- None.

Next:
- Advancement Gate required evidence validation.

### GW-024 worker output required evidence validation

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-worker-output-evidence-missing.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-worker-output-evidence-missing.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-worker-output-evidence-missing.sh`
- Expected failure: code-changing `task_complete` requests without `test_evidence_refs` should be blocked as `evidence_missing`.
- Observed failure: request returned HTTP 400 because required evidence validation was not implemented.

GREEN:
- Added required evidence validation after schema, identity, artifact-ref, and write-scope checks.
- Code-changing `task_complete` requests now require non-empty `test_evidence_refs`.
- Missing evidence blocks the run and task with `worker_output_evidence_missing`, writes a validation report, appends Audit, and emits `worker_output_blocked`.

Refactor:
- None.

Next:
- First positive Advancement Gate completion path for one task.

### GW-025 valid worker output completes one task

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-worker-output-complete-task.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-worker-output-complete-task.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-worker-output-complete-task.sh`
- Expected failure: valid worker output should pass the Advancement Gate and complete only the target Kanban task.
- Observed failure: request returned HTTP 400 because the positive completion path was not implemented.

GREEN:
- Added the first positive Advancement Gate path for `requested_transition: task_complete`.
- Valid worker output writes a `worker_output_report`, updates only the target task to `completed`, updates run stage progress to the next stage, appends Audit evidence, advances the official Kanban task, and emits `task_completed`.
- The run remains `queued`; no `run_completed` Audit or Event is produced from a single worker completion.

Refactor:
- None.

Next:
- Worker-output idempotency replay or review/QA verdict routing.

### GW-026 review verdict request_changes routes to improvement

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/verdicts`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-review-verdict-request-changes.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh`
- Expected failure: Gateway has no structured review/QA verdict submission route yet.
- Observed failure: `POST /orchestra/runs/{run_id}/verdicts` returned HTTP 404.

GREEN:
- Added `POST /orchestra/runs/{run_id}/verdicts` to capabilities and routing.
- Added the first structured verdict path for in-scope `review_report` with `verdict: request_changes`.
- Gateway writes an immutable review verdict artifact, blocks the implementation task with `review_changes_requested`, queues Stage 4 `improvement`, records Audit evidence, advances the official Kanban task to blocked, and emits post-commit `artifact_written` and `stage_started` Events.
- The run stays active as `queued`; no `run_completed` Audit or Event is produced from review feedback.

Refactor:
- None.

Next:
- Structured review/QA block routing or verdict idempotency replay.

### GW-027 review verdict block requires Human Approval

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/verdicts`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-review-verdict-block-human-approval.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
- Expected failure: high-risk structured review block should route to Human Approval instead of being rejected as unsupported.
- Observed failure: `POST /orchestra/runs/{run_id}/verdicts` returned HTTP 400.

GREEN:
- Added routing for structured `review_report` with `verdict: block` and `authority_required: human`.
- Gateway writes the immutable verdict artifact, blocks the target task and run with `review_blocked_human_approval_required`, creates a pending decision, records Audit evidence for both the verdict and decision requirement, advances the official Kanban task to blocked, and emits post-commit `artifact_written` and `decision_required` Events.
- The run stays active as `blocked`; no Stage 4 start or run completion evidence is produced.

Refactor:
- None.

Next:
- Verdict idempotency replay/conflict or Stage 4 improvement budget enforcement.

### GW-028 improvement budget exhaustion blocks

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/verdicts`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-review-verdict-improvement-budget.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-review-verdict-improvement-budget.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-review-verdict-improvement-budget.sh`
- Expected failure: a second `request_changes` verdict after improvement cycle 1 should block as `improvement_exhausted`.
- Observed failure: the second verdict returned `route_result: improvement_queued` with `improvement_cycle: 2`.

GREEN:
- Added Stage 4 MVP budget enforcement for structured verdict routing.
- `request_changes` with `improvement_cycle >= 1` now writes the immutable re-review verdict, blocks the target task and run as `improvement_exhausted`, creates a pending Kimi decision, records Audit evidence, advances the official Kanban task to blocked, and emits `decision_required`.
- The route no longer starts an unbounded hidden improvement loop.

Refactor:
- Shared the existing verdict-blocking path for Human Approval and improvement exhaustion while preserving distinct `authority_required` and `failure_class` fields.

Next:
- Verdict idempotency replay/conflict or Stage 5 global evaluation routing.

### GW-029 global evaluation warnings require final acceptance

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/global-evaluations`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-global-evaluation-warnings.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh`
- Expected failure: Gateway has no Stage 5 Global Evaluation report submission route yet.
- Observed failure: `POST /orchestra/runs/{run_id}/global-evaluations` returned HTTP 404.

GREEN:
- Added `POST /orchestra/runs/{run_id}/global-evaluations` to capabilities and routing.
- Added the first Stage 5 path for `global_evaluation_report.verdict: pass_with_warnings`.
- Gateway writes `global_evaluation_report.json`, blocks the run at `global_evaluation` with `global_evaluation_acceptance_required`, creates a pending Kimi decision, records Audit evidence, and emits post-commit `artifact_written` and `decision_required` Events.
- Stage 6 is not started and the run is not completed until final acceptance exists.

Refactor:
- None.

Next:
- Kimi final acceptance decision for pass-with-warnings or `pass` routing into Stage 6.

### GW-030 final acceptance queues Stage 6

Status: GREEN

Public interface:
- `POST /orchestra/decisions/{decision_id}`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-global-evaluation-final-acceptance.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-global-evaluation-final-acceptance.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh`
- `rtk bash scripts/tests/test-gateway-decision-approve-intake.sh`
- `rtk bash scripts/tests/test-gateway-decision-idempotency-replay.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-global-evaluation-final-acceptance.sh`
- Expected failure: approving the Global Evaluation final-acceptance decision should resume the same run into Stage 6.
- Observed failure: `POST /orchestra/decisions/{decision_id}` returned HTTP 400 because all approve decisions required an intake `ticket`.

GREEN:
- Moved intake `ticket` validation into the intake decision branch.
- Added approval routing for runs blocked by `global_evaluation_acceptance_required`.
- Gateway writes `final_acceptance.json`, updates `global_evaluation_report.json.final_acceptance_ref`, clears the pending decision, queues `continuous_improvement`, records Audit evidence, and emits `decision_resolved` plus `stage_started`.
- Final acceptance does not mark the run completed; Stage 6 closeout remains required.

Refactor:
- Kept final acceptance separate from intake decision logic to avoid conflating structured PRD approval with global evaluation acceptance.

Next:
- Stage 6 closeout/completion gate or Global Evaluation `pass` direct Stage 6 routing.

### GW-031 closeout summary alone is rejected

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/closeout`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-closeout-summary-alone-rejected.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-closeout-summary-alone-rejected.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-closeout-summary-alone-rejected.sh`
- Expected failure: closeout endpoint should reject text-only completion attempts through the Stage 6 completion gate.
- Observed failure: `POST /orchestra/runs/{run_id}/closeout` returned HTTP 404.

GREEN:
- Added `POST /orchestra/runs/{run_id}/closeout` to capabilities and routing.
- Added validation that rejects requests missing schema-shaped `iteration_closeout_report` and `system_improvement_proposals`.
- Summary-only closeout returns `400 closeout_validation_failed` with explicit `completion_blockers`, writes no closeout artifacts, emits no Events, and records no `run_completed` Audit evidence.

Refactor:
- None.

Next:
- Positive Stage 6 closeout completion gate.

### GW-032 closeout completion gate completes run

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/closeout`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-closeout-completes-run.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-closeout-completes-run.sh`
- `rtk bash scripts/tests/test-gateway-closeout-summary-alone-rejected.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-closeout-completes-run.sh`
- Expected failure: schema-valid Stage 6 closeout with all stage tasks complete should mark the run completed through Gateway authority.
- Observed failure: closeout returned HTTP 400 because completed closeout was not implemented yet.

GREEN:
- Added closeout idempotency and positive completion-gate validation.
- Gateway now requires schema-shaped `iteration_closeout_report`, `system_improvement_proposals`, existing final acceptance, existing global evaluation report, and all projected stage tasks completed before completion.
- On success, Gateway writes `iteration_closeout_report.json` and `system_improvement_proposals.json`, marks State completed, records `run_completed` Audit evidence, and emits a post-commit `run_completed` Event.
- Cache, summaries, and model self-report remain ignored as completion authority.

Refactor:
- Completion validation is isolated in `closeout_completion_blockers`.

Next:
- Closeout idempotency replay/conflict, artifact resolver coverage, or command recovery.

### GW-033 global evaluation pass queues Stage 6

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/global-evaluations`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-global-evaluation-pass.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-global-evaluation-pass.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-final-acceptance.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-global-evaluation-pass.sh`
- Expected failure: `global_evaluation_report.verdict: pass` should queue Stage 6 without a final-acceptance decision.
- Observed failure: Global Evaluation `pass` returned HTTP 400 as unsupported.

GREEN:
- Added Global Evaluation `pass` routing.
- Gateway writes `global_evaluation_report.json`, records `global_evaluation_recorded` Audit evidence, clears pending decision state, queues `continuous_improvement`, and emits post-commit `artifact_written` plus `stage_started`.
- No `decision_required` or `run_completed` evidence is produced for a plain `pass`.

Refactor:
- None.

Next:
- Closeout idempotency replay/conflict, artifact resolver coverage, or command recovery.

### GW-034 capabilities expose authority layers

Status: GREEN

Public interface:
- `GET /orchestra/capabilities`

Test:
- `scripts/tests/test-gateway-capabilities-authority-layers.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-capabilities-authority-layers.sh`
- `rtk bash scripts/tests/test-gateway-worker-registry.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-capabilities-authority-layers.sh`
- Expected failure: capabilities should expose Gateway, official Kanban, local filesystem cache, worker registry, and template debater fallback.
- Observed failure: response lacked `gateway`, `cache`, `kanban`, `workers`, and `debaters`.

GREEN:
- Expanded capabilities with authority-layer projections for Gateway, upstream API, official Hermes Kanban, workers, roles, cache, and debaters.
- Cache reports `local_filesystem` as the MVP backend.
- Debaters report template fallback as available but degraded.
- Preserved the legacy `worker_backends` field used by existing worker registry tests.

Refactor:
- None.

Next:
- Artifact resolver coverage, command recovery, or privacy/knowledge constraints.

### GW-035 event sequence gap marks projection inconsistent

Status: GREEN

Public interface:
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}`

Test:
- `scripts/tests/test-gateway-events-gap-inconsistent.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-events-gap-inconsistent.sh`
- `rtk bash scripts/tests/test-gateway-events-pagination.sh`
- `rtk bash scripts/tests/test-gateway-events-rebuild.sh`
- `rtk bash scripts/tests/test-gateway-events-sse.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-events-gap-inconsistent.sh`
- Expected failure: Event Store sequence gap should return `projection_status: inconsistent`.
- Observed failure: Event Store with seq `1, 3` returned `projection_status: consistent`.

GREEN:
- Added Event Store sequence validation for duplicate, missing, non-integer, and out-of-order `seq`.
- Corrupt projection now returns `projection_status: inconsistent` while preserving authoritative run status and blocker/failure fields.
- Event inconsistency remains observation-layer damage, not workflow authority.

Refactor:
- None.

Next:
- Command recovery, artifact resolver coverage, or privacy/knowledge constraints.

### GW-036 forbidden proposal auto-apply blocks closeout

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/closeout`
- `GET /orchestra/runs/{run_id}`

Test:
- `scripts/tests/test-gateway-closeout-forbidden-proposal.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-closeout-forbidden-proposal.sh`
- `rtk bash scripts/tests/test-gateway-closeout-completes-run.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-closeout-forbidden-proposal.sh`
- Expected failure: closeout completion gate should explicitly block auto-applied root rule proposals.
- Observed failure: closeout blocked for other missing authorities but did not include `system_improvement_proposals.forbidden_auto_apply`.

GREEN:
- Added completion-gate checks for `system_improvement_proposals.auto_applied_refs`, proposal records with `status: auto_applied_low_risk`, and closeout `knowledge_updates.auto_applied_refs`.
- Only `repo://.workflow/knowledge/*` auto-applied refs and `.workflow/knowledge/*` low-risk targets can pass.
- Root `AGENTS.md` and other non-knowledge targets now become explicit completion blockers instead of silent auto-applies.

Refactor:
- None.

Next:
- Command recovery, artifact resolver coverage, or privacy constraints.

### GW-037 create-run command recovery without replay

Status: GREEN

Public interface:
- Gateway startup
- `GET /orchestra/runs/{run_id}`
- command record artifact

Test:
- `scripts/tests/test-gateway-command-recovery-completed.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-command-recovery-completed.sh`
- `rtk bash scripts/tests/test-gateway-run-create.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-command-recovery-completed.sh`
- Expected failure: startup should reconcile an in-progress create-run command when State, Tasks, and Audit already prove the side effects completed.
- Observed failure: command record remained `status: in_progress`.

GREEN:
- Gateway startup now scans in-progress command records.
- A `create_run` command with durable `run.json`, `tasks.json`, and matching `run_created` Audit evidence is marked `completed` with `recovery_action: completed_without_replay`.
- Recovery backfills a response summary and reconciliation step without invoking Hermes Kanban or duplicating side effects.

Refactor:
- None.

Next:
- Ambiguous command recovery, artifact resolver coverage, or privacy constraints.

### GW-038 ambiguous create-run command recovery blocks

Status: GREEN

Public interface:
- Gateway startup
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- command record artifact

Test:
- `scripts/tests/test-gateway-command-recovery-ambiguous.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-command-recovery-ambiguous.sh`
- `rtk bash scripts/tests/test-gateway-command-recovery-completed.sh`
- `rtk python3 -m py_compile scripts/lib/orch_gateway.py`

RED:
- Command: `rtk bash scripts/tests/test-gateway-command-recovery-ambiguous.sh`
- Expected failure: startup should block an ambiguous in-progress create-run command and write reconciliation evidence.
- Observed failure: no `command-reconciliation-reports/{command_id}.json` was written.

GREEN:
- Added ambiguous recovery for in-progress `create_run` command records that have run State but cannot prove all side effects via Tasks and Audit.
- Gateway writes `command_reconciliation_report`, marks the run `blocked` with `command_reconciliation_ambiguous`, creates a pending decision, records Audit evidence, emits `decision_required`, and marks the command `failed` with `recovery_action: blocked_ambiguous`.
- Recovery does not invoke Hermes Kanban or replay side effects.

Refactor:
- None.

Next:
- Artifact resolver coverage or privacy constraints.

### GW-039 global evaluation scalar artifact refs stay scoped

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/global-evaluations`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-global-evaluation-artifact-ref-scope.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-global-evaluation-artifact-ref-scope.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-pass.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-global-evaluation-artifact-ref-scope.sh`
- Expected failure: `development_plan_ref: "/tmp/leaked-development-plan.json"` should be rejected as an invalid artifact ref before any Global Evaluation authority artifact is written.
- Observed failure: Gateway returned `200` with `route_result: stage6_queued` and wrote `global_evaluation_report.json`.

GREEN:
- Added scalar artifact ref validation for `structured_prd_ref` and `development_plan_ref`.
- `final_acceptance_ref` remains nullable, but a non-null value must also be scoped to the current run.
- Invalid scalar refs now return `400 validation_error` with the offending field in `violations`; no global evaluation report, stage-start event, final-acceptance decision, or completion evidence is written.

Refactor:
- None.

Next:
- Continue artifact resolver coverage for cross-run scalar refs, or move to privacy/knowledge constraints.

### GW-040 global evaluation block routes to Human Approval

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/global-evaluations`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-global-evaluation-block-human-approval.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-global-evaluation-block-human-approval.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-pass.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-global-evaluation-block-human-approval.sh`
- Expected failure: `global_evaluation_report.verdict: block` with `authority_required: human` should write the report, keep the run blocked, and emit a pending decision before Stage 6.
- Observed failure: Gateway returned HTTP 400 `unsupported_global_evaluation`.

GREEN:
- Added Stage 5 `block` routing through the same authority-first path used for warning acceptance blockers.
- Gateway writes `global_evaluation_report.json`, records `global_evaluation_recorded` and `decision_required` Audit evidence, keeps the run in `blocked` at `global_evaluation`, and exposes `authority_required: human`.
- Stage 6 is not queued and no completion evidence is written.

Refactor:
- Replaced hardcoded warning-route fields with verdict-specific routing variables while preserving the existing `pass_with_warnings` behavior.

Next:
- Global evaluation `fail` routing, command recovery continue-from-checkpoint, or privacy/knowledge constraints.

### GW-041 global evaluation fail blocks Stage 6

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/global-evaluations`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-global-evaluation-fail-blocks.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-global-evaluation-fail-blocks.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-block-human-approval.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-warnings.sh`
- `rtk bash scripts/tests/test-gateway-global-evaluation-pass.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-global-evaluation-fail-blocks.sh`
- Expected failure: `global_evaluation_report.verdict: fail` should write failure evidence, keep the run blocked at Stage 5, and require a decision instead of entering Stage 6.
- Observed failure: Gateway returned HTTP 400 `unsupported_global_evaluation`.

GREEN:
- Added Stage 5 `fail` routing to the blocked decision path.
- Gateway writes the Global Evaluation report, records `global_evaluation_recorded` with `decision: FAIL`, sets `blocked_reason` and `failure_class` to `global_evaluation_failed`, and emits a pending decision.
- Stage 6 is not queued and run completion evidence is not written.

Refactor:
- Reused the verdict-specific routing variables introduced for `block`.

Next:
- Command recovery continue-from-checkpoint, privacy/knowledge constraints, or explicit validation coverage for missing mutating idempotency keys.

### GW-042 create-run command recovery continues from checkpoint

Status: GREEN

Public interface:
- Gateway startup
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- command record and idempotency artifacts

Test:
- `scripts/tests/test-gateway-command-recovery-continues-checkpoint.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-command-recovery-continues-checkpoint.sh`
- `rtk bash scripts/tests/test-gateway-command-recovery-completed.sh`
- `rtk bash scripts/tests/test-gateway-command-recovery-ambiguous.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-command-recovery-continues-checkpoint.sh`
- Expected failure: startup should continue a create-run command when `run.json` is durable and the command record explicitly proves `create_kanban_stage_tasks` has not started.
- Observed failure: Gateway did not create `tasks.json`; the command was treated as ambiguous.

GREEN:
- Added conservative create-run checkpoint continuation.
- Recovery now continues only when `write_run_state` is completed, `create_kanban_stage_tasks` is explicitly `not_started`, task projection and Events are absent, and `run_created` Audit evidence is absent.
- Gateway creates Kanban stage tasks, writes `tasks.json`, appends `run_created` Audit and Event evidence, backfills the idempotency record, and marks the command `completed` with `recovery_action: continued_from_checkpoint`.
- The ambiguous branch remains intact when the command lacks explicit proof that Kanban creation never started.

Refactor:
- Added small command-step status helpers to keep recovery predicates explicit.

Next:
- Privacy/knowledge constraints or explicit idempotency-key validation coverage.

### GW-043 review verdict reject blocks for decision

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/verdicts`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-review-verdict-reject-blocks.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-review-verdict-reject-blocks.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-improvement-budget.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-review-verdict-reject-blocks.sh`
- Expected failure: `review_report.verdict: reject` should write immutable verdict evidence, block the target task and run, and emit a decision requirement.
- Observed failure: Gateway returned HTTP 400 `unsupported_verdict`.

GREEN:
- Routed `reject` verdicts through the blocked decision path.
- Gateway writes the review verdict artifact, marks the target task blocked with `review_rejected`, records `review_verdict_recorded` with `decision: REJECTED`, emits `decision_required`, and blocks the run without queuing improvement or closeout.

Refactor:
- Extended the existing verdict blocker to set verdict-specific audit decision, blocked reason, authority, and failure class.

Next:
- Review/QA `block` with Kimi authority, review `approve`, privacy/knowledge constraints, or explicit idempotency-key validation coverage.

### GW-044 QA verdict block routes to Kimi decision

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/verdicts`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-qa-verdict-block-kimi.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-qa-verdict-block-kimi.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-block-human-approval.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-reject-blocks.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-qa-verdict-block-kimi.sh`
- Expected failure: `qa_report.verdict: block` with `authority_required: kimi` should write QA verdict evidence, block the task/run, and emit a Kimi decision requirement.
- Observed failure: Gateway returned HTTP 400 `unsupported_verdict`.

GREEN:
- Routed all `block` verdicts through the verdict blocker.
- QA block verdicts now use `blocked_reason` and `failure_class` `qa_blocked`, preserve Kimi authority when requested, record Audit evidence, block the target Kanban task, and emit `decision_required`.

Refactor:
- Kept the existing Human Approval review block behavior while adding a QA-specific branch.

Next:
- Review `approve`, privacy/knowledge constraints, or explicit idempotency-key validation coverage.

### GW-045 review verdict approve records evidence only

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/verdicts`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `GET /orchestra/runs/{run_id}/tasks`

Test:
- `scripts/tests/test-gateway-review-verdict-approve-records.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-review-verdict-approve-records.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-request-changes.sh`
- `rtk bash scripts/tests/test-gateway-review-verdict-reject-blocks.sh`
- `rtk bash scripts/tests/test-gateway-qa-verdict-block-kimi.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-review-verdict-approve-records.sh`
- Expected failure: `review_report.verdict: approve` should be accepted as structured evidence without blocking or completing the run.
- Observed failure: Gateway returned HTTP 400 `unsupported_verdict`.

GREEN:
- Added approval verdict recording.
- Gateway writes the review verdict artifact, attaches it to task and run artifact refs, records `review_verdict_recorded` with `decision: APPROVED`, and emits an `artifact_written` Event.
- Approval evidence does not complete a task, emit `decision_required`, mutate Kanban lifecycle, or complete the run.

Refactor:
- None.

Next:
- Explicit idempotency-key validation coverage, privacy constraints, or final PRD coverage audit.

### GW-046 missing run-create idempotency key coverage

Status: GREEN

Public interface:
- `POST /orchestra/runs`

Test:
- `scripts/tests/test-gateway-run-missing-idempotency-key.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-run-missing-idempotency-key.sh`

RED:
- This was a backlog coverage reconciliation for GW-004. The behavior had already been implemented in the initial route validation, so the new contract test passed after the fixture was corrected to ignore `orch-init` setup artifacts.

GREEN:
- Added explicit contract coverage for missing `idempotency_key`.
- The test confirms Gateway returns `400 validation_error` and does not create a run, active-run pointer, idempotency record, command-linked Audit evidence, or Kanban mutation for the rejected request.

Refactor:
- None.

Next:
- Full gateway verification and final PRD coverage audit.

### GW-047 successful MVP acceptance artifacts

Status: GREEN

Public interface:
- `POST /orchestra/runs`
- `POST /orchestra/runs/{run_id}/worker-outputs`
- `POST /orchestra/runs/{run_id}/global-evaluations`
- `POST /orchestra/decisions/{decision_id}`
- `POST /orchestra/runs/{run_id}/closeout`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`

Test:
- `scripts/tests/test-gateway-mvp-acceptance-artifacts.sh`

Verification:
- `PYTHONPYCACHEPREFIX=/tmp/hermes-pycache rtk python3 -m py_compile scripts/lib/orch_gateway.py`
- `rtk bash scripts/tests/test-gateway-mvp-acceptance-artifacts.sh`
- Regression slices: `test-gateway-run-create.sh`, `test-gateway-worker-output-complete-task.sh`, `test-gateway-closeout-completes-run.sh`, `test-gateway-global-evaluation-pass.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-mvp-acceptance-artifacts.sh`
- Expected failure: completed MVP run should expose `structured_prd.json`, `development_plan.json`, `test_plan.json`, `test_execution_report.json`, fixed stage reports, worker selection evidence, worker context envelope/bundle refs, CLI worker execution evidence, stage completion Events, and Audit evidence.
- Observed failure: `AssertionError: missing required MVP artifact: structured_prd.json`.

GREEN:
- Structured ticket run creation now writes ready `structured_prd.json`, `development_plan.json`, `test_plan.json`, `test_execution_report.json`, template debate reports, fixed Stage 1-4 reports, and `worker_selection_record.json`.
- Each stage task receives a scoped Worker Context Bundle and Worker Context Envelope under Gateway State; raw chat history and absolute paths are not embedded.
- Accepted worker output now records role/stage, command evidence, and CLI backend execution metadata in `worker_output_report`.
- Worker output acceptance emits a post-commit `stage_completed` Event after the target task completes.
- Run creation records `mvp_acceptance_artifacts_recorded` and `worker_context_prepared` Audit evidence.

Refactor:
- Kept the artifact scaffold behind the existing run-create and worker-output public contracts; no new Kimi-facing route was added.

Next:
- Terminal failed run validation and machine-readable schema files.

### GW-048 terminal failed run lineage evidence

Status: GREEN

Public interface:
- `POST /orchestra/runs/{run_id}/failures`
- `GET /orchestra/runs/{run_id}`
- `GET /orchestra/runs/{run_id}/events`
- `POST /orchestra/runs` with failed `source_run_id`

Test:
- `scripts/tests/test-gateway-run-terminal-failure-lineage.sh`

Verification:
- `PYTHONPYCACHEPREFIX=/tmp/hermes-pycache rtk python3 -m py_compile scripts/lib/orch_gateway.py`
- `rtk bash scripts/tests/test-gateway-run-terminal-failure-lineage.sh`
- Regression slices: `test-gateway-run-lineage-from-stopped.sh`, `test-gateway-lineage-from-blocked-rejected.sh`, `test-gateway-capabilities-authority-layers.sh`

RED:
- Command: `rtk bash scripts/tests/test-gateway-run-terminal-failure-lineage.sh`
- Expected failure: terminal authority-chain failure should be recordable as a failed run with `run_failure_report`, `run_failed` Event, Audit evidence, lineage hints, and a new lineage run from the failed source.
- Observed failure: `POST /orchestra/runs/{run_id}/failures` returned HTTP 404.

GREEN:
- Added `POST /orchestra/runs/{run_id}/failures` and listed it in Gateway capabilities.
- The route validates terminal failure reports, writes `run_failure_report.json`, marks the run `failed`, records `failure_report_ref`, `failure_audit_ref`, `last_good_checkpoint_ref`, and `lineage_hint_refs`, appends immutable Audit evidence, and emits `run_failed`.
- Idempotency is scoped to the failure endpoint and replays completed failure results without duplicate side effects.
- Failed runs remain terminal and can seed new lineage runs through existing `POST /orchestra/runs` source-run semantics.

Refactor:
- Reused existing Gateway State/Audit/Event/idempotency patterns rather than adding a separate failure store.

Next:
- Machine-readable schema files and schema conformance checks.

### GW-049 machine-readable schema bundle

Status: GREEN

Public interface:
- `config/schemas/orchestra.schema.json`
- `make lint-json`

Test:
- `scripts/tests/test-gateway-schema-files.sh`

Verification:
- `rtk bash scripts/tests/test-gateway-schema-files.sh`
- `rtk make lint-json`

RED:
- Command: `rtk bash scripts/tests/test-gateway-schema-files.sh`
- Expected failure: Schema Summary requires machine-readable schemas under `config/schemas/*.schema.json`.
- Observed failure: `config/schemas/orchestra.schema.json` was missing.

GREEN:
- Added `config/schemas/orchestra.schema.json` as a JSON Schema 2020-12 bundle.
- The bundle includes `$defs` for the core API responses, run artifacts, worker protocol artifacts, decisions, stop response, capabilities, closeout, failure reports, and validation-related artifact shapes.
- Critical status, event type, terminal failure reason, verdict, and action enums are machine-readable.

Refactor:
- Kept schemas bundled in one file to avoid many weak, duplicated schema fragments.

Next:
- Worker/debate config registry files and capabilities projection.

### GW-050 worker and debate config registries

Status: GREEN

Public interface:
- `config/workers/backends.json`
- `config/workers/roles.json`
- `config/debate/teams.json`
- `config/debate/modes.json`
- `GET /orchestra/capabilities`

Test:
- `scripts/tests/test-gateway-config-registries.sh`

Verification:
- `PYTHONPYCACHEPREFIX=/tmp/hermes-pycache rtk python3 -m py_compile scripts/lib/orch_gateway.py`
- `rtk bash scripts/tests/test-gateway-config-registries.sh`
- `rtk make lint-json`

RED:
- Command: `rtk bash scripts/tests/test-gateway-config-registries.sh`
- Expected failure: MVP Spec requires project-local worker backend/role config and debate team/mode config.
- Observed failure: `config/workers/backends.json` was missing.

GREEN:
- Added worker backend and role registry config files for Codex implementer and Claude reviewer.
- Added debate registry config with 16 teams and 8 modes, including `architecture` and `red_team`.
- Capabilities now exposes worker/debate config refs and debate team/mode counts.
- Role fallback config excludes `schema_mismatch` and security-policy bypasses.

Refactor:
- Added a small config loader for capabilities projection; worker semantics still use the existing built-in defaults for the MVP adapter.

Next:
- Full contract verification and final coverage audit.

## Latest Checkpoint

Last green cycle: post-GW-050 MVP hardening
Current cycle: none
Current status: HERMES-ORCHESTRA-MVP PRD/SPEC/SCHEMAS backlog complete through GW-050 plus final hardening for executable test evidence, Kanban init/link, downgrade events, npm/make entrypoints, and closeout evidence validation.

Hardening cycles completed:
- `scripts/tests/test-gateway-mvp-real-acceptance-boundary.sh`: `orch-init` writes `.workflow/knowledge/*`, run create records project-scoped `run_uri`, initializes Kanban, creates parent workflow plus six stage tasks, links stage dependencies, executes `make test` when `ORCH_GATEWAY_RUN_TESTS=1`, and records `debate_degraded` Audit/Event evidence.
- `scripts/tests/test-npm-test-entrypoint.sh`: `npm test` delegates to `make test` instead of the default placeholder.
- `scripts/tests/test-make-upstream-status-advisory.sh`: upstream pin mismatch remains visible but does not make local `make test` machine-dependent; strict failure remains available through `make upstream-status-strict`.
- `scripts/tests/test-gateway-closeout-rejects-unexecuted-tests.sh`: Stage 6 closeout now rejects claimed completion when `test_execution_refs` point only to planned/unexecuted test evidence.

Latest verification:
- `rtk python3 - <<'PY' ... compile(...) ... PY` passed without writing bytecode.
- `rtk bash scripts/tests/run-all.sh` passed with smoke summary `78 passed, 0 failed`.
- `rtk make test` passed, including smoke, risk tests, JSON lint, shell lint, and advisory upstream-status.

Known environment note:
- Local Hermes runtime still differs from `.planning/upstream/hermes-agent-pin.json`; `make upstream-status` reports `status: mismatch` and exits 0 by default, while `make upstream-status-strict` remains the hard gate for deployment/installation checks.

Next cycle: none
Open questions: none
