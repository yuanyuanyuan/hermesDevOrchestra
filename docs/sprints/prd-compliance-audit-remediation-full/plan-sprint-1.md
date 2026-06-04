# Sprint 1: Conflict Ledger Completion

## Goal

Finish the remaining Conflict Ledger work not covered by the prior gate slice: schema alignment, severity normalization, conflict write helpers, and closeout audit consumption.

## Implementation Units

### U1: Conflict Ledger schema and closeout integration

- SP: 5
- team_topology: pair
- Depends on: prior `docs/sprints/prd-compliance-audit-remediation/` Sprint 1
- Files: `scripts/lib/orch_gateway.py`, `scripts/lib/gateway_closeout.py`, `config/schemas/orchestra.full.schema.json`, `docs/sprints/prd-compliance-audit-remediation-full/schema.md`, `scripts/tests/test-gateway-conflict-ledger-closeout.sh`

Approach:
- Promote `conflict-ledger.json` from ad hoc artifact to schema-backed artifact.
- Normalize conflict severities to PRD `high|medium|low`.
- Add helper methods for append/query/resolve conflict records.
- Make closeout audit read every conflict and block unresolved `open` or unjustified `accepted_risk`.

Test Matrix:
- `test-gateway-conflict-ledger-closeout.sh`: closeout blocks on open/high conflict.
- `test-gateway-conflict-ledger-closeout.sh`: closeout passes when high conflict is `auto_resolved` with evidence.

Negative Tests:
- Missing `conflict_id` fails schema validation.
- `resolution=accepted_risk` without `resolver` or `resolution_evidence` blocks closeout.

Risk Fallback:
- If full schema migration is too wide, keep runtime artifact additive and gate final schema synchronization in Sprint 12.

