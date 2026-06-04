# Sprint 12 Checklist: Schema, Docs, And Success Metrics Sync

## Architecture Redlines

- [ ] Docs do not claim behavior that tests cannot prove.
- [ ] Full schema and schema notes stay consistent.

## Functional Acceptance

- [ ] New artifacts validate with `orchestra.full.schema.json`.
- [ ] Success metrics include remediation-specific metrics.
- [ ] Configuration docs include new policy fields.
- [ ] User-flow docs reflect implemented lifecycle/rollback/channel behavior.

## Test Coverage

- [ ] `bash scripts/tests/test-prd-remediation-schema-doc-sync.sh`
- [ ] `bash scripts/tests/test-success-metrics-pipeline.sh`
- [ ] Negative: missing schema section.
- [ ] Negative: missing success metric field.

## Docs/Schema Sync

- [ ] `spec.md`, `schema.md`, config docs, and user-flow docs cross-reference the same field names.

