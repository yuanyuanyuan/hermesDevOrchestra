# Sprint 11: User Correction And Override Approval

## Goal

Make correction rounds and Override records complete enough for approval workflows and audit.

## Implementation Units

### U11: Correction UX state and override records

- SP: 5
- team_topology: pair
- Depends on: Sprint 10
- Files: `scripts/lib/correction_gate.py`, `scripts/lib/orch_gateway.py`, `config/schemas/orchestra.full.schema.json`, `scripts/tests/test-correction-override-approval.sh`

Approach:
- Record two correction rounds with compact/full evidence modes and timeout metadata.
- Add `override_record` with `correction_rounds[]`, `approver_ref`, `risk_level`, evidence, and status.
- Expose pending Override list/query endpoint.
- Require L3/L4 approval route when correction crosses protected target or high risk.

Test Matrix:
- User insists after two rounds creates pending Override record.
- L3 Override requires approver ref before resolution.

Negative Tests:
- Override without `approver_ref` cannot become approved.
- Objective error with no correction evidence cannot be overridden silently.

Risk Fallback:
- If endpoint surface is too wide, first persist records and expose read-only pending list.

