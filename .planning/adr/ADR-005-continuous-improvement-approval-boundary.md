# ADR-005: Continuous Improvement Produces Proposals Before Root Rule Changes

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Stage 6 keeps the Kimi audit loop but writes system improvement proposals and patch references instead of automatically modifying root rule files.

## Context

The Hermes Orchestra premise includes external audit-driven system evolution: Kimi reviews completed runs, identifies durable lessons, and Hermes can later apply improvements. Root rule files such as `AGENTS.md`, `CLAUDE.md`, and `hermes/SOUL.md` shape future agent behavior, so mistaken or noisy updates can create persistent workflow drift.

## Decision

`continuous_improvement` always writes `iteration_closeout_report.json` and `system_improvement_proposals.json`. It may auto-update low-risk `.workflow/knowledge/*` artifacts, but root rule files, CI/CD, install scripts, permission/risk policy, worker backend config, debate routing config, and Gateway/runtime configuration changes are proposal-only in MVP. Applying those changes requires the normal decision authority chain, including explicit human approval for root rule-file and high-risk boundaries.

## Consequences

- The MVP preserves the audit-driven learning loop without allowing automatic memory or rule pollution.
- Future implementation must distinguish proposals from applied changes.
- A later milestone can automate more of this path only after approval, rollback, and drift controls are stronger.
