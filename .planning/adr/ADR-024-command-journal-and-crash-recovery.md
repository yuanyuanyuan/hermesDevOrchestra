# ADR-024: Command Journal And Crash Recovery

**Date:** 2026-05-17
**Status:** Accepted
**Decision:** Execute mutating Gateway commands through a write-ahead command journal and recover in-progress commands by reconciling State, Audit, Kanban, and artifact refs instead of blindly replaying.

## Context

Kimi may call Gateway while the Gateway process crashes, restarts, or loses the response path. The `qnN4o510` premise depends on replayable evidence from Gateway State, Audit, Kanban, Schema, and Harness artifacts. If restart blindly replays a mutating command, it can duplicate Kanban tasks, Events, Audit records, or workflow artifacts.

## Decision

After request schema and idempotency validation, Gateway writes a Gateway State `command_record` with `status: in_progress`, `command_id`, canonical payload hash, command intent, and planned side-effect steps. Only then may it apply State, Audit, Kanban, worker, or artifact side effects. Each step records verifiable refs.

Event append steps are projection steps. They run only after the authoritative State, Audit, Kanban, or artifact refs they report are durable. If Event append fails after the authority step succeeds, recovery treats it as projection repair and must not roll back the authority step solely to match the Event Store.

When all authority steps for a command are durable but Event append is failed or ambiguous, Gateway may mark the command `completed` with projection degradation metadata. The response replay path returns the successful authority result plus the projection issue so callers do not retry the command and duplicate side effects.

On startup, Gateway scans in-progress command records. It reconciles each command against Gateway State, Audit, Hermes Kanban, and artifact refs. If the command is proven complete, Gateway backfills missing response refs and marks it `completed`. If a step is proven unexecuted, Gateway may continue from that step. If Gateway cannot prove whether a side effect happened, it blocks the related run or task, emits `decision_required`, records `command_reconciliation_report`, and does not replay blindly.

Cache, worker summaries, stdout, and model text are not reconciliation authority.

## Consequences

- Crash recovery favors evidence preservation over forward progress.
- Mutating commands remain idempotent across process restarts.
- Ambiguous recovery becomes a blocked decision path instead of duplicate workflow state.
- Events never pre-announce authority changes, so SSE clients cannot observe completed work before durable evidence exists.
- Event append failure after authority success becomes projection degradation, not command replay.
