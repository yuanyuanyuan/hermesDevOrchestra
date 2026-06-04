# Sprint 10 Checklist: Global Evaluation Veto And Residual Risk

## Architecture Redlines

- [ ] Veto logic is policy-backed.
- [ ] Notification formatting remains separate from authority routing.

## Functional Acceptance

- [ ] One-vote veto dimensions block closeout.
- [ ] High residual risk requires explicit authority route approval.
- [ ] Medium/low residual risks sort and notify correctly.
- [ ] `fail` cannot route directly to closeout.

## Test Coverage

- [ ] `bash scripts/tests/test-gateway-global-evaluation-veto-risk-thresholds.sh`
- [ ] Negative: high risk without approval.
- [ ] Negative: unknown severity.
- [ ] Regression: existing notification-level tests.

## Docs/Schema Sync

- [ ] Coverage policy documents veto dimensions.
- [ ] Global evaluation schema includes risk action fields.

