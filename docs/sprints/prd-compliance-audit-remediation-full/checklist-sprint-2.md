# Sprint 2 Checklist: PRD Run Lifecycle State Machine

## Architecture Redlines

- [ ] One transition guard implementation, no duplicated transition checks across handlers.
- [ ] Backward-compatible `status` response remains available.

## Functional Acceptance

- [ ] Run creation sets `lifecycle_status=created` then reaches `intake_complete` only after completion bundle validation.
- [ ] `paused`, `blocked`, `cancelled`, and `rollback_requested` exist as explicit lifecycle states.
- [ ] Illegal transitions return deterministic error code `invalid_run_transition`.
- [ ] Projection responses include lifecycle state.

## Test Coverage

- [ ] `bash scripts/tests/test-gateway-run-lifecycle-state-machine.sh`
- [ ] At least 8 illegal transition cases.
- [ ] At least one resume-from-blocked case.

## Docs/Schema Sync

- [ ] `schema.md` lifecycle enum updated.
- [ ] User-flow docs mention `cancelled` instead of `stopped` if behavior changes.

