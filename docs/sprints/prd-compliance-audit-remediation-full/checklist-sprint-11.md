# Sprint 11 Checklist: User Correction And Override Approval

## Architecture Redlines

- [ ] Override approval uses authority matrix.
- [ ] Correction records do not replace Conflict Ledger records; they may link to them.

## Functional Acceptance

- [ ] `override_record` includes all PRD-required fields.
- [ ] Two correction rounds are recorded with evidence refs.
- [ ] Pending Override list filters by `risk_level` and `status`.
- [ ] L3/L4 Override cannot approve without approver ref.

## Test Coverage

- [ ] `bash scripts/tests/test-correction-override-approval.sh`
- [ ] Negative: missing approver.
- [ ] Negative: no correction evidence.
- [ ] Regression: existing correction gate CLI test.

## Docs/Schema Sync

- [ ] Override schema documented.
- [ ] User-flow correction section matches runtime statuses.

