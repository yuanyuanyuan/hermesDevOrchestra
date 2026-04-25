# Phase 2: Runtime, Installation & Command Contracts - Research

**Researched:** 2026-04-25
**Status:** Complete

## Planning Inputs

- Phase goal: Reviewers can validate safe host, installation, invocation, path, and command assumptions for a no-sudo SSH-based Hermes environment.
- Requirement IDs: RUNT-01, RUNT-02, RUNT-03, CMD-01, CMD-02, CMD-03
- Primary spec coverage: SPEC.md §2

## Relevant Source Material

- `.planning/SPEC.md`
- `.planning/research/STACK.md`
- `docs/hermes-dev-orchestra/scripts/setup.sh`

## Findings

- Ubuntu/Linux, SSH, tmux, Git, Node, Claude Code CLI, Codex CLI, and Hermes Agent are declared as host assumptions.
- No-sudo installation must resolve through user-owned XDG-style paths with deterministic fallbacks.
- Runtime Bus, State, Audit, and Cache are physically separated and recorded in a startup paths.json manifest.
- Claude/Codex invocation profiles forbid permission or sandbox bypass flags.
- Doctor/preflight probes are required before agent sessions are trusted.

## Validation Architecture

- Verify requirement coverage by checking .planning/REQUIREMENTS.md traceability, .planning/SPEC.md sections, and this phase VERIFICATION.md.
- Treat missing inline specification text as a blocker, not as tech debt.
- Treat implementation-only details as out of scope unless they are needed to make the contract checkable.

## Planning Recommendation

Create one focused documentation plan that verifies and finalizes the canonical specification coverage for this phase.
