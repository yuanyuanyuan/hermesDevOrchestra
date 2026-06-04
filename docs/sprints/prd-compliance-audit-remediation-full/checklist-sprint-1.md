# Sprint 1 Checklist: Conflict Ledger Completion

## Architecture Redlines

- [ ] No broad rewrite of `orch_gateway.py`; helper methods are narrow and reusable.
- [ ] Severity enum is PRD-aligned: `high`, `medium`, `low`.
- [ ] Closeout consumes Conflict Ledger through a helper, not direct ad hoc file parsing in multiple places.

## Functional Acceptance

- [ ] `conflict-ledger.json` validates with `orchestra.full.schema.json`.
- [ ] Open high conflicts block closeout with `blocked_reason=open_high_conflict`.
- [ ] Resolved conflicts require non-empty `resolution_evidence`.
- [ ] Closeout report includes conflict counts by severity and resolution.

## Test Coverage

- [ ] `bash scripts/tests/test-gateway-conflict-ledger-closeout.sh`
- [ ] Negative: missing `conflict_id` fails.
- [ ] Negative: accepted risk without evidence blocks.
- [ ] Regression: existing worker-output conflict gate still passes.

## Docs/Schema Sync

- [ ] `schema.md` updated if runtime schema changes.
- [ ] `docs/PRD-COMPLIANCE-AUDIT-REPORT.md` notes this item as partially/fully remediated only after tests pass.

