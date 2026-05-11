---
phase: 25-worker-lifecycle-observability-mvp-acceptance
plan: "01"
subsystem: runtime
tags: [worker-lifecycle, observability, structured-handoff, backpressure, acceptance]
requirements-completed: [EXEC-01, EXEC-02, EXEC-03, FLOW-01, OBS-01, OBS-02]
completed: 2026-05-11
---

# Phase 25 Plan 01 Summary

## One-Line Summary

Implemented the Phase 25 v1.3 closeout slice by adding task-level timeout and reclaim control, scoped cleanup, structured handoff validation, conservative backpressure, a hook-based observability plugin, environment snapshots, and one end-to-end MVP acceptance chain.

## Delivered

- Extended `docs/orchestra/scripts/lib/orch-common.sh` with lifecycle helpers for `expected_duration_max`, active-run state, cleanup baselines, and backpressure predicates.
- Updated `docs/orchestra/scripts/bin/orch-bus-loop` and `orch-status` so the runtime can reclaim timed-out runs, validate structured completion handoffs, capture environment snapshots, and expose lifecycle status without mutating the main repo checkout.
- Added `docs/orchestra/hermes/plugins/observability/__init__.py` as a repo-shipped sidecar plugin that records `post_tool_call` and `on_session_end` traces without patching Hermes core.
- Tightened implementer/reviewer handoff requirements around `behaviors`, `regression`, `changed_files`, `decisions`, and `pitfalls`, with downstream consumption treated as untrusted input.
- Added regression coverage for timeout reclaim, structured handoff, observability, environment snapshots, backpressure, routing continuity, and MVP acceptance.
- Wrote `25-VERIFICATION.md` and mirrored the lifecycle/observability contract into the operator-facing docs.

## Verification

- Passed: `bash docs/orchestra/scripts/tests/test-worker-lifecycle-timeout.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-structured-handoff.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-observability-plugin.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-env-snapshot.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-backpressure-basic.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-mvp-acceptance.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-kanban-routing.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-kanban-handoff.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh`
- Passed: `bash docs/orchestra/scripts/tests/test-profile-packaging.sh`
- Pending global green: `rtk make test` still inherits the known `upstream-status` runtime pin mismatch already tracked from earlier phases.

## Next Phase Readiness

Phase 25 is closed out. The milestone is ready for `v1.3` audit and closeout, with the inherited `upstream-status` mismatch still recorded as an external blocker rather than a Phase 25 regression.
