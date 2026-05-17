# ADR-018: Global Evaluation Final Acceptance Gate

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Require Stage 5 global evaluation to audit all run evidence and gate Stage 6 closeout through `pass` or Kimi-accepted `pass_with_warnings`.

## Context

Hermes Orchestra uses a six-stage loop, and the `qnN4o510` premise depends on structured evidence, Schema, DAGs, Harness artifacts, and auditability. If closeout can start as soon as implementation, review, and tests appear done, the workflow can miss unresolved decisions, downgrades, warnings, or cross-stage inconsistencies.

## Decision

Stage 5 `global_evaluation` is an independent audit stage. It reads structured PRD, development plan, debate reports, implementation evidence, review and QA verdicts, test execution reports, improvement reports, downgrade records, unresolved decisions, and Audit entries. It writes `global_evaluation_report.json` with verdict `pass`, `pass_with_warnings`, `fail`, or `block`.

Only `pass` or Kimi-accepted `pass_with_warnings` may proceed to Stage 6. `fail` can return to bounded Stage 4 improvement only when improvement budget remains, findings are in approved scope, and no human-risk gate is hit; otherwise it blocks. `block` routes to Kimi or Human Approval according to the decision authority chain. Kimi remains final acceptance authority only below human-risk gates and cannot override L3/L4, schema failure, test failure, write-scope violation, security boundary, forbidden target, or Human Approval boundary.

## Consequences

- Closeout cannot bypass unresolved evidence or downgrades.
- Warnings are explicit and require Kimi acceptance before closeout.
- Global failures reuse the bounded improvement path only when scope and budget allow it.
- Final acceptance remains aligned with the Kimi/Human authority split.
