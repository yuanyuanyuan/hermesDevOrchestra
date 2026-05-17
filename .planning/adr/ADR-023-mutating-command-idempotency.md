# ADR-023: Mutating Command Idempotency

**Date:** 2026-05-17
**Status:** Accepted
**Decision:** Require idempotency keys for mutating Gateway commands and record one command ID across State, Audit, and Events.

## Context

Kimi may retry Gateway calls after timeouts, network failures, or uncertain responses. The `qnN4o510` premise depends on State, Audit, Kanban, Schema, and Harness evidence remaining replayable and non-duplicated. If a retry can create a second run, decision resolution, stop marker, Event, or Audit record, the workflow evidence becomes ambiguous.

## Decision

`POST /orchestra/runs`, `POST /orchestra/decisions/{decision_id}`, and `POST /orchestra/runs/{run_id}/stop` require `idempotency_key`. Gateway scopes idempotency by project, endpoint, resource path, and key.

Idempotency replay is checked before active-run conflict checks, so a retry of the original run-create command returns the original result instead of `409 active run`. On first accepted command, Gateway stores a `command_id`, canonical payload hash, resulting resource refs, response summary, Event refs, and Audit refs. Repeating the same scoped key with the same canonical payload returns the original command result and creates no duplicate side effects. Reusing the same scoped key with a different payload returns `409 conflict`.

If authoritative State, Audit, Kanban, and artifact side effects succeed but Event append fails, the command result is still successful and replayable with `event_projection_degraded: true`, `projection_status: inconsistent`, and projection issue refs. Retrying the same `idempotency_key` returns that stored authority result and must not repeat side effects just to repair Events.

Decision resolution is one-shot but idempotent for the same action payload. Stop is idempotent and returns the same `stopped` status, stop Audit ref, partial closeout ref, and `run_stopped` event ref. `command_id` is evidence correlation only, not run identity, task identity, resume authority, or completion authority.

## Consequences

- Kimi retries are safe under timeout or uncertain response conditions.
- Audit and Events remain one evidence trail per accepted command.
- Cache cannot become command dedupe authority; idempotency records live in Gateway State.
- Projection failure after authority success does not turn retries into duplicate workflow mutations.
