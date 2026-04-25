# Phase 6: Risk Rulebook & Remote Decision Contract - Research

**Researched:** 2026-04-25
**Status:** Complete

## Planning Inputs

- Phase goal: Reviewers can verify that risk gates, rule enforcement, high-risk blocking, and local fallback decisions are safe and replay-resistant.
- Requirement IDs: SPEC-04, RISK-01, RISK-02, RISK-05, RISK-03, RISK-04, REMOTE-01, REMOTE-02, REMOTE-03, REMOTE-04, REMOTE-05
- Primary spec coverage: SPEC.md §6 and Appendix A

## Relevant Source Material

- `.planning/SPEC.md`
- `.planning/REQUIREMENTS-REV1.md`
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md`

## Findings

- Risk levels define owners, examples, default actions, timeout behavior, and user-required cases.
- The static rule table has 10 concrete rules and is loaded by Hermes at startup.
- Hermes upgrades any Claude classification below the rulebook floor and records rulebook overrides in audit.
- L3/L4 blocks remain blocked until explicit user approval or rejection; timeouts and ambiguous replies reject safely.
- Remote Decision Channel is transport-neutral and includes a file-based local fallback without external network assumptions.

## Validation Architecture

- Verify requirement coverage by checking .planning/REQUIREMENTS.md traceability, .planning/SPEC.md sections, and this phase VERIFICATION.md.
- Treat missing inline specification text as a blocker, not as tech debt.
- Treat implementation-only details as out of scope unless they are needed to make the contract checkable.

## Planning Recommendation

Create one focused documentation plan that verifies and finalizes the canonical specification coverage for this phase.
