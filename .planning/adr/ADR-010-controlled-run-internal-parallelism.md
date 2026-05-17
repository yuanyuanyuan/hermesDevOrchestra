# ADR-010: One Active Run Per Project With Controlled Run-Internal Parallelism

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Allow one active Six-Stage Run per project, while permitting explicitly justified run-internal parallelism for independent child tasks.

## Context

The Hermes Orchestra premise uses mixed execution: top-level stages are ordered, while some implementation subtasks and global evaluations can run in parallel. Full same-project parallel workflow runs require namespace isolation, worktrees, merge arbitration, and conflict handling that are beyond the MVP acceptance path.

## Decision

MVP keeps one active run per project. Within a run, top-level stages remain serial. `global_evaluation` may parallelize debate teams, and `implementation` may parallelize read-only or non-overlapping child tasks. Code-changing tasks run serially by default unless `development_plan.json.parallelism_policy` declares disjoint write sets and the tasks use Kanban worktree workspaces. Same-project parallel runs and merge arbitration remain deferred.

## Consequences

- The MVP preserves the mixed-execution architecture without pretending to solve merge arbitration.
- The development plan must state what can run in parallel and why.
- Disabled or deferred parallelism is visible in closeout rather than hidden as an implementation accident.
