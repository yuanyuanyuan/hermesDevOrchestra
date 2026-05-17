# ADR-020: Stopped And Blocked Run Evidence Preservation

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Treat `blocked` as an active recoverable run state and `stopped` as a terminal stop-and-archive state that preserves evidence and writes partial closeout.

## Context

Hermes Orchestra needs users and Kimi to interrupt runs, but the `qnN4o510` premise depends on Schema, DAG/Kanban, Gateway State, Harness artifacts, and Audit evidence. If cancel deletes artifacts or if blocked runs are treated as failed completion, later recovery and audit become unreliable.

## Decision

`blocked` remains an active run status. It preserves Gateway State, Audit entries, Kanban task state, artifact refs, blocker reason, pending decision refs, and resume checkpoints. It does not write completed closeout and does not release the one-active-run slot.

`cancel` maps to `POST /orchestra/runs/{run_id}/stop`. Stop moves a queued, running, or blocked run to terminal `stopped`, emits `run_stopped`, writes stop Audit evidence, stops future scheduling, and preserves State, Audit, Cache, repo artifacts, Kanban tasks, and worker evidence. Stop does not approve, reject, revise, or expire pending decisions; unresolved decisions remain recorded.

A stopped-before-completion run writes `iteration_closeout_report.json` with `closeout_kind: stopped_before_completion`. This partial closeout records completed and incomplete stages, preserved artifact refs, unresolved decisions, stop reason, stop event and audit refs, worker cancel markers, and resume checkpoint refs. It is not Stage 6 completion and cannot satisfy the `completed` acceptance path.

## Consequences

- Recovery can use Kanban lifecycle plus Gateway State, State Artifacts, and Audit Artifacts rather than cache or worker summaries.
- Stop remains safe for users because it archives evidence instead of cleaning it up.
- Pending high-risk or Human Approval decisions are not silently resolved by cancellation.
