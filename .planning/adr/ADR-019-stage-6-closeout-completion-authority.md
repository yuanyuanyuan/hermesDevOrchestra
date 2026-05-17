# ADR-019: Stage 6 Closeout Completion Authority

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Stage 6 closeout produces required evidence, but Gateway marks a run completed only after validating closeout artifacts, Audit, Kanban lifecycle, and Gateway State together.

## Context

Hermes Orchestra needs a final continuous-improvement stage, but the `qnN4o510` premise depends on Schema, DAG/Kanban, Harness artifacts, and Audit evidence rather than model summaries or worker self-report. If Stage 6 can declare completion by writing a narrative closeout, the workflow can hide unresolved warnings, downgrades, fallbacks, or forbidden config changes behind a final summary.

## Decision

Stage 6 `continuous_improvement` starts only after `global_evaluation_report.json` has verdict `pass` or Kimi-accepted `pass_with_warnings`. It must write `iteration_closeout_report.json` and `system_improvement_proposals.json`.

`iteration_closeout_report.json` records final acceptance, accepted warnings, downgraded capabilities, unresolved or deferred decisions, executed tests and reviews, worker fallbacks, knowledge updates, and future proposal refs. Only low-risk `.workflow/knowledge/*` updates may be auto-applied. Root rule files, CI/CD, permission/risk policy, worker/debate config, and Gateway/runtime config remain proposal-only targets until approved through the decision authority chain.

Gateway may set run status to `completed` only when closeout artifacts are schema-valid, Audit records closeout evidence, required Kanban stage tasks are done, and Gateway State is consistent with artifact and decision refs.

## Consequences

- Closeout artifacts are evidence, not completion authority by themselves.
- Continuous improvement can preserve future learning without silently rewriting high-impact rules or runtime configuration.
- Run completion remains aligned with Schema, DAG/Kanban, Gateway State, Audit, and Harness evidence.
