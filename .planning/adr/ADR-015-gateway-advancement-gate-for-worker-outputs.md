# ADR-015: Gateway Advancement Gate For Worker Outputs

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Treat worker output as a structured request for advancement, with Gateway as the only authority that validates evidence and advances State, Audit, or Kanban lifecycle.

## Context

Hermes Orchestra uses real workers to implement, review, and test work, but the `qnN4o510` premise relies on Schema, DAG, Audit, and structured evidence to prevent drift. If a worker can directly mark a task or run complete, it can bypass artifact validation, test evidence, write-scope checks, and approval boundaries.

## Decision

Worker Backends must return schema-valid `hermes-role-engine/v1` JSON. `next_action: complete` is a completion request, not a lifecycle command. Workers must not directly complete Kanban tasks, mutate Gateway State, mark stages complete, or mark a run complete.

The Gateway Advancement Gate validates protocol/schema, correlation and task identity, artifact refs, required artifact schemas, allowed write scope, forbidden path violations, risk and approval boundaries, and required test or review evidence. When validation passes, Gateway writes State and Audit first, then advances official Hermes Kanban lifecycle through workflow-controlled commands. Natural-language summaries and stdout/stderr are evidence only, never state transition authority.

## Consequences

- Worker self-report cannot complete workflow state.
- Kanban remains lifecycle authority, but only Gateway workflow rules invoke lifecycle changes.
- Missing artifacts, failed tests, write-scope violations, or approval-boundary hits route to block, decision, or improvement paths.
- Completion remains replayable from State, Audit, Kanban lifecycle, and schema-valid artifacts.
