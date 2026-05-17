# ADR-021: Resume, Revise, And Terminal Run Lineage

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Resume blocked runs in place, but continue failed or stopped runs only by creating a new run with explicit lineage to source evidence.

## Context

Hermes Orchestra needs recovery after blocked, stopped, and failed states. The `qnN4o510` premise depends on Schema, DAG/Kanban, Gateway State, Harness artifacts, and Audit evidence. If a terminal run can be switched back to running, the system can rewrite history and blur which evidence belongs to which attempt.

## Decision

`blocked` is the only recoverable in-place run state. `approve` resumes the original blocked task or stage attempt from validated artifact refs. `revise` creates a revised child task or revised stage attempt inside the same run, links `revision_of` and source artifact refs, and writes new artifacts without overwriting the original evidence.

`failed` and `stopped` are terminal in MVP. They must not transition back to `queued`, `running`, or `blocked`. Continuing after `failed` or `stopped` requires a new `POST /orchestra/runs` request with `source_run_id` and `resume_from_refs`. The new run receives a new `run_id`, records lineage in Gateway State and Audit, and may read source Gateway State, State Artifacts, Audit Artifacts, Kanban projection, and scoped artifacts. The source run remains read-only for workflow continuation.

`resume_from_refs` must be scoped refs from the source run. Cache refs and worker summaries may be used only as rebuildable background, never as resume authority.

## Consequences

- Active blocked work can continue without losing its decision and blocker context.
- Terminal run history remains immutable and auditable.
- Follow-up attempts have explicit lineage instead of silently mutating failed or stopped evidence.
