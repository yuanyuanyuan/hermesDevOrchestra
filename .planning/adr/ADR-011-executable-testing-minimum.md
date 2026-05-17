# ADR-011: Executable Test Chain Minimum

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** A completed MVP run must generate a test plan and execute at least one project-relevant test command, with failures routed through the improvement loop.

## Context

The Hermes Orchestra premise treats process completeness and automated verification as core safeguards against agent drift. A test plan without execution proves only that the workflow can write files; it does not prove the implemented change was checked against acceptance criteria.

## Decision

`test_plan.json` must map back to `development_plan.json` acceptance criteria. `test_execution_report.json` must record actual commands and outcomes. For this project, `make test` is the default test entrypoint and must run first when available. Generated smoke tests are fallback or additive. Playwright is limited to UI/frontend work. If tests fail, the run enters one automatic Stage 4 improvement cycle; continued failure blocks completion.

## Consequences

- The MVP cannot complete on paper-only testing.
- Existing project test entrypoints take priority over generated tests.
- Test failure becomes a workflow state with bounded repair instead of being hidden in closeout.
