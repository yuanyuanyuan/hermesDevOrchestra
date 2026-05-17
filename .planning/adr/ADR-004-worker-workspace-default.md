# ADR-004: Default Code Workers To Kanban Worktree Workspaces

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Code worker tasks use official Kanban `worktree` workspaces by default, with direct project checkout execution only as an audited MVP downgrade fallback.

## Context

The Hermes Orchestra premise relies on task isolation to reduce context bleed, dirty-checkout ambiguity, and worker conflict risk. Earlier MVP notes allowed workers to modify the current repository directly to keep the first loop easy to land, but the installed Hermes Kanban CLI supports `--workspace worktree`, so direct execution should not remain the default.

## Decision

Implementation tasks should be created with Kanban `--workspace worktree` by default. Direct project checkout execution is allowed only when worktree creation fails, the selected CLI worker cannot operate correctly from the worktree, or the demo needs the shortest viable end-to-end loop. Any fallback must record the workspace strategy, fallback reason, baseline dirty state, changed files, diff summary, test commands, and test results, and it must appear in `iteration_closeout_report.json`.

## Consequences

- The MVP better matches the Kimi + Hermes layered architecture and keeps worker changes easier to attribute.
- Same-project parallel runs and merge arbitration remain deferred even though per-task worktrees are available.
- Direct project checkout execution stays possible for MVP practicality, but it is no longer the default or invisible behavior.
