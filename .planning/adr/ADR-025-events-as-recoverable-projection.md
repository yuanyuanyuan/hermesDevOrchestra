# ADR-025: Events As Recoverable Projection

**Date:** 2026-05-17
**Status:** Accepted
**Decision:** Treat Gateway Events as a recoverable per-run projection for Kimi/SSE/UI, while Audit remains the immutable evidence authority.

## Context

Kimi needs a low-latency progress stream to supervise runs, resume SSE subscriptions, and update UI state. The `qnN4o510` premise also depends on durable truth from Gateway State, Audit, Hermes Kanban, Schema-valid artifacts, and Harness evidence. If Events become evidence authority, a missing or corrupt event log can make completion, recovery, or audit depend on a lossy UI stream.

## Decision

Gateway Events are append-only within one run and ordered by a per-run monotonic `seq`. `GET /orchestra/runs/{run_id}/events` supports `since_seq` JSON polling and SSE resume using the same sequence.

The primary Event Store is Gateway State, for example `STATE_ROOT/{project}/runs/{run_id}/events.jsonl`, and is referenced through `state://` refs. Audit may reference Event refs for correlation, but the Event Store is not an Audit Artifact.

MVP retains the complete Event Store with run State. It does not apply TTL, truncation, log rotation, prefix deletion, middle deletion, or lossy per-event compression to active or terminal run Events. Future archival must preserve `seq` continuity and a complete sequence manifest.

Events contain `command_id` when caused by a mutating command, summary messages, and scoped artifact refs. They must not contain raw prompts, secrets, full worker stdout/stderr, large report bodies, or absolute local paths.

Event emission is post-commit. Gateway appends an Event only after the State, Audit, Hermes Kanban, or artifact change it reports is durable and can be referenced or re-read. Events must not pre-announce stage completion, task completion, decision resolution, stop, failure, artifact write, or run completion.

If Event append fails after the authoritative refs are durable, Gateway treats that as Projection Inconsistency and rebuilds or repairs the projection. It must not roll back durable State, Audit, Kanban, or artifact changes solely because the Event append failed.

For mutating commands, authority success plus Event append failure returns a successful command result with `event_projection_degraded: true`, `projection_status: inconsistent`, and projection issue refs. Idempotency replay returns the same authority result and must not repeat side effects.

Missing or corrupt Event Projection data may be rebuilt from Gateway State, Audit, Hermes Kanban, and artifact refs. Rebuild must not invent Audit evidence. Audit cannot be reconstructed from Events.

Event-only projection damage does not change a run to `blocked`, `failed`, or `stopped` when Gateway State, Audit, Hermes Kanban, and required artifact refs are complete and mutually consistent. Gateway marks the projection `inconsistent` or rebuilds it, and Kimi resyncs before acting on Events.

If Events cannot be rebuilt because the underlying authority chain is missing or inconsistent, the run follows the normal blocked-vs-failed boundary.

If Kimi observes a sequence gap, duplicate sequence, stale projection, or projection inconsistency, it must resync current run status, task projection, and events before further decisions. Kimi must not advance workflow state from stale Events.

## Consequences

- SSE and UI state can be rebuilt without weakening the evidence chain.
- Audit storage remains mandatory even when Events are complete.
- Event persistence can support idempotency response replay and SSE resume without polluting immutable Audit evidence.
- Complete Event retention keeps `since_seq`, SSE resume, and projection rebuild simple in MVP.
- Kimi progress supervision stays responsive but cannot bypass State, Audit, Kanban, and artifact authority.
- Event projection defects degrade observation first; they block or fail a run only when they expose authority-chain damage.
- SSE never reports a state transition before the durable authority write exists.
- Kimi retries do not duplicate workflow mutations when only the Event Projection is degraded.
