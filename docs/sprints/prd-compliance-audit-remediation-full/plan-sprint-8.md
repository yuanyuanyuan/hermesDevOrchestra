# Sprint 8: Worker Evidence And DAG Hardening

## Goal

Make Gateway consume computed write scope, actual changes, DAG validation, review evidence, and commit evidence before stage advancement.

## Implementation Units

### U8: Worker advancement evidence hardening

- SP: 5
- team_topology: pair
- Depends on: Sprint 2
- Files: `scripts/lib/orch_gateway.py`, `scripts/lib/write_scope_validator.py`, `scripts/lib/dag_validator.py`, `scripts/lib/gateway_evidence.py`, `scripts/tests/test-gateway-worker-advancement-evidence.sh`

Approach:
- Compare expected write scope against reported changed files.
- Require DAG validation result for solution/implementation stages.
- Require review evidence and commit evidence where stage contract requires them.
- Treat existing `dag_validator.validate_dag()` as source of cycle truth and integrate its result.

Test Matrix:
- Valid worker output with DAG/review/commit evidence advances.
- Cyclic DAG validation result blocks advancement.

Negative Tests:
- Changed file outside expected write scope blocks.
- Missing commit evidence blocks implementation completion.

Risk Fallback:
- If actual file diff cannot be computed in Gateway, require signed evidence refs first and add actual diff computation in a follow-up.

