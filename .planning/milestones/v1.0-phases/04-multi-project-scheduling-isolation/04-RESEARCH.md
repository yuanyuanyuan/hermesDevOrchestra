# Phase 4: Multi-Project Scheduling & Isolation - Research

**Researched:** 2026-04-25
**Status:** Complete

## Planning Inputs

- Phase goal: Users can append tasks at any time while Hermes routes work across isolated projects and keeps unblocked projects moving.
- Requirement IDs: MULTI-01, MULTI-02, MULTI-03, MULTI-04, MULTI-05, MULTI-06
- Primary spec coverage: SPEC.md §4

## Relevant Source Material

- `.planning/SPEC.md`
- `.planning/research/FEATURES.md`
- `.planning/research/ARCHITECTURE.md`

## Findings

- Each project has an immutable ID, canonical path, sanitized runtime name, and per-project policy.
- Append-anytime intake accepts, queues, rejects, or deduplicates tasks based on current project state.
- Blocked projects yield; Hermes continues polling and progressing unblocked projects.
- Per-project tmux sessions, bus roots, logs, environment filtering, state rows, and archives prevent collisions.
- Same-repository concurrency is serialized in v1; future worktree concurrency is deferred.

## Validation Architecture

- Verify requirement coverage by checking .planning/REQUIREMENTS.md traceability, .planning/SPEC.md sections, and this phase VERIFICATION.md.
- Treat missing inline specification text as a blocker, not as tech debt.
- Treat implementation-only details as out of scope unless they are needed to make the contract checkable.

## Planning Recommendation

Create one focused documentation plan that verifies and finalizes the canonical specification coverage for this phase.
