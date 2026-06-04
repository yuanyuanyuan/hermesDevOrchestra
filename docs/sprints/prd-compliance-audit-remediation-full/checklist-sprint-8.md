# Sprint 8 Checklist: Worker Evidence And DAG Hardening

## Architecture Redlines

- [ ] Do not reimplement DAG cycle detection; consume `dag_validator`.
- [ ] Worker self-reported evidence is not trusted without Gateway validation.

## Functional Acceptance

- [ ] Write scope is checked before worker output acceptance.
- [ ] DAG validation failure blocks stage advancement.
- [ ] Review evidence required for improvement/global-evaluation boundary.
- [ ] Commit evidence required for implementation completion when files changed.

## Test Coverage

- [ ] `bash scripts/tests/test-gateway-worker-advancement-evidence.sh`
- [ ] Negative: write-scope violation.
- [ ] Negative: cyclic DAG.
- [ ] Negative: missing commit evidence.

## Docs/Schema Sync

- [ ] Worker output report schema includes evidence refs.
- [ ] Audit report notes DAG claim calibration.

