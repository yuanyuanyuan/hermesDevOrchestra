# ADR-017: Bounded Stage 4 Improvement

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Limit automatic Stage 4 improvement to one scoped repair cycle tied to existing review, QA, or test findings.

## Context

Stage 4 exists to repair implementation drift, but the `qnN4o510` premise depends on structured tickets, DAG boundaries, Schema, Audit, and explicit decision authority. If improvement can keep retrying or expand scope, it becomes a hidden replanning loop that bypasses Kimi and Human Approval gates.

## Decision

MVP allows at most one automatic Stage 4 improvement cycle per run. It may fix only review, QA, or test findings inside the approved `development_plan.json` scope. It may repair code defects, tests, artifact gaps, or implementation drift against approved acceptance criteria, but it must not expand requirements, redirect architecture, change risk policy, modify worker/debate/Gateway config, or touch Human Approval targets.

Each automatic improvement writes `improvement_report.json` linking source verdict or test failure refs, failure class, scope assessment, changed files, diff summary, tests run, test results, and re-review or re-test refs. If re-review, QA, or tests still fail after that cycle, the run becomes blocked with `improvement_exhausted`; Kimi or Human Approval must choose `revise`, choose `reject`, or request stop through the run stop endpoint.

## Consequences

- Stage 4 can repair real defects without becoming an unbounded retry loop.
- Scope expansion goes through decision routing instead of being smuggled into automatic repair.
- Re-review and re-test evidence remains explicit and traceable.
- Failed repair remains a first-class blocked state rather than a hidden continuation.
