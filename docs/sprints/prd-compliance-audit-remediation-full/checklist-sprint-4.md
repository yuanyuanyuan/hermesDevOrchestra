# Sprint 4 Checklist: Channel Routing Propagation

## Architecture Redlines

- [ ] Channel decision is persisted once and reused.
- [ ] Standard fallback is fail-closed.
- [ ] Existing module endpoint for `channel-router` remains compatible.

## Functional Acceptance

- [ ] Run state contains `channel_decision`.
- [ ] Channel decision controls required evidence and debate depth.
- [ ] Rollout Gate forced Standard is recorded with reason.
- [ ] Quick disabled kill switch downgrades and logs.

## Test Coverage

- [ ] `bash scripts/tests/test-gateway-channel-routing-propagation.sh`
- [ ] Negative: insufficient rollout evidence.
- [ ] Negative: invalid channel policy.
- [ ] Regression: existing `test-quick-channel-rollout-gate.sh`.

## Docs/Schema Sync

- [ ] `channel_decision` schema documented.
- [ ] Configuration docs reflect runtime propagation behavior.

