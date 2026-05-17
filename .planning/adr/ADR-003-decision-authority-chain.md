# ADR-003: Three-Level Decision Authority Chain

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Use a three-level authority chain: auto-advance for allowed low-risk work, Kimi decisions for workflow-risk decisions below human-risk gates, and explicit human approval for L3/L4 or forbidden automatic modification boundaries.

## Context

Hermes Orchestra uses Kimi as the upper orchestrator for intent, supervision, acceptance, and audit. The system also has risk-policy red lines where no agent should be able to approve dangerous operations, even if a debate report or Kimi recommendation says the work is desirable.

## Decision

Low-risk work may auto-advance when policy allows it and the reason is recorded. Medium-risk workflow decisions, unresolved debate conflicts, repairable schema problems, and repeated worker failures route to Kimi through the Gateway decision API. L3/L4 risk, destructive operations, external publishing, permission or secret changes, CI/CD changes, root rule-file changes, risk-policy changes, and Gateway port/proxy changes require explicit human approval; Kimi may recommend but cannot approve those boundaries alone.

## Consequences

- "Kimi final authority" means final orchestration and acceptance authority below human-risk gates.
- The Gateway decision request must identify whether `kimi` or `human` authority is required.
- Local fallback approval commands remain necessary for human-risk gates.
- No timeout, fallback backend, debate verdict, or agent self-report may auto-approve human-risk gates.
