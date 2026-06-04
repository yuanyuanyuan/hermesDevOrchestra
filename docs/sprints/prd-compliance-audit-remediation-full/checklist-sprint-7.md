# Sprint 7 Checklist: Worker Source Isolation

## Architecture Redlines

- [ ] Keep fingerprint collision checks separate from model-source isolation.
- [ ] Review/audit/cross_check fail closed.

## Functional Acceptance

- [ ] `worker_session_record.model_source` exists and validates.
- [ ] Same-source review/audit/cross_check returns `source_isolation_violation`.
- [ ] Different-source session is accepted.
- [ ] Audit event records rejected source and required alternative.

## Test Coverage

- [ ] `bash scripts/tests/test-worker-source-isolation.sh`
- [ ] Negative: missing model_source.
- [ ] Negative: same source as adjudicator.
- [ ] Regression: existing worker session tests.

## Docs/Schema Sync

- [ ] Full schema and `schema.md` include model source fields.
- [ ] Architecture docs clarify source isolation vs fingerprint collision.

