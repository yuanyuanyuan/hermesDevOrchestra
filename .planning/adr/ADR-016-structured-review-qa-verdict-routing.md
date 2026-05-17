# ADR-016: Structured Review And QA Verdict Routing

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Route Review and QA outcomes through structured verdict artifacts, bounded Stage 4 improvement, and decision authority instead of letting Kimi or workers override failed feedback.

## Context

Hermes Orchestra depends on reviewer, QA, and test feedback to stop implementation drift. The `qnN4o510` premise treats review evidence, Schema, DAG, and Harness artifacts as safeguards. If review or QA failure can be overwritten by a later worker summary or Kimi acceptance, the workflow can appear complete while skipping required fixes.

## Decision

Reviewer and QA outputs use structured verdicts: `approve`, `request_changes`, `reject`, or `block`. Verdict artifacts include findings, severity, affected acceptance criteria, required fixes, evidence refs, scope assessment, risk level, and required authority. `approve` still goes through the Gateway Advancement Gate. `request_changes` enters Stage 4 `improvement` for at most one automatic fix cycle when fixes are in scope and below human-risk gates. `reject` blocks or routes to Kimi depending on recoverability. `block` routes to Kimi or Human Approval according to risk and authority rules.

Kimi may decide below human-risk gates, but cannot override high-risk blocks, schema failures, test failures, write-scope violations, or Human Approval boundaries. Improvement and re-review write new artifacts with references to prior verdicts; they do not overwrite original review or QA evidence.

## Consequences

- Review and QA feedback becomes auditable workflow input instead of optional commentary.
- The improvement loop remains bounded and scoped.
- Original failed reviews remain available for re-review and closeout.
- Kimi remains an orchestrator without bypassing evidence or approval gates.
