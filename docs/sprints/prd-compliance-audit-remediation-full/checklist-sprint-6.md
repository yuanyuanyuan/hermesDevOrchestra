# Sprint 6 Checklist: Quick And Light Mini-Debate

## Architecture Redlines

- [ ] No fixture-only mini-debate may count as completion evidence.
- [ ] Channel policy drives debate depth.

## Functional Acceptance

- [ ] Quick/Light channels create bounded debate artifacts.
- [ ] Debate artifact refs are attached to run state.
- [ ] Timeout/degraded debate cannot silently advance.
- [ ] `quick.debate_rounds` is no longer contradictory to runtime behavior.

## Test Coverage

- [ ] `bash scripts/tests/test-channel-mini-debate.sh`
- [ ] Negative: timeout.
- [ ] Negative: missing report.
- [ ] Regression: existing debate assembly tests.

## Docs/Schema Sync

- [ ] `slo-policy.json` and docs agree on debate round counts.
- [ ] Mini-debate artifact refs documented.

