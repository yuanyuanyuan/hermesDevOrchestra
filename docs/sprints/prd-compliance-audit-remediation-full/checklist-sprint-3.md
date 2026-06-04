# Sprint 3 Checklist: Rollback Strategy

## Architecture Redlines

- [ ] No `git reset --hard` against shared branches.
- [ ] Rollback only targets current-run refs.
- [ ] Protected targets fail closed without approval.

## Functional Acceptance

- [ ] `rollback_requested` lifecycle state is set when rollback starts.
- [ ] `rollback_report.json` records baseline, strategy, affected refs, result, and timestamps.
- [ ] Failed global evaluation can route to rollback instead of closeout.

## Test Coverage

- [ ] `bash scripts/tests/test-gateway-rollback-strategy.sh`
- [ ] Negative: missing baseline.
- [ ] Negative: protected target without approval.
- [ ] Regression: normal fail path remains blocked.

## Docs/Schema Sync

- [ ] `rollback_report` added to schema notes and full schema.
- [ ] Config docs mention rollback command registry behavior.

