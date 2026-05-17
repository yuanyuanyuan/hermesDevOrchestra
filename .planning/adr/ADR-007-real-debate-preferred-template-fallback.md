# ADR-007: Prefer Real Debate Backend And Treat Template Debate As Fallback

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Keep the debate registry backend-neutral, prefer a real debate backend for MVP acceptance when available, and treat template debate as a degraded scaffold fallback.

## Context

The Hermes Orchestra premise depends on 16 debate teams and 8 debate modes to provide real decision pressure. A template-only backend can validate schemas and run offline fixtures, but it does not provide the same multi-perspective reasoning value and can make the workflow look complete while skipping the core decision-engine benefit.

## Decision

All 16 teams and 8 modes remain expressible in configuration. Template debate is allowed for offline tests, schema fixtures, or unavailable API-key environments. If a real debate backend such as MiniMax/API-backed debate is available, an MVP acceptance run must use it for at least one core debate stage, either `direction_debate` or `solution_debate`. If no real backend is available, the run may continue with template fallback, but it must emit `debate_degraded` or write an Audit downgrade, mark the debate report as degraded, and record the downgrade in closeout.

## Consequences

- The MVP can still run in constrained local environments.
- Acceptance evidence is stronger when a real debate backend exists.
- Template verdicts remain scaffold input and must not be treated as strong evidence for auto-advance.
