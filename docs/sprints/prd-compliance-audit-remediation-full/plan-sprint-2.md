# Sprint 2: PRD Run Lifecycle State Machine

## Goal

Replace linear-only stage projection with explicit PRD lifecycle states and guarded transitions.

## Implementation Units

### U2: Lifecycle states and transition guard table

- SP: 5
- team_topology: pair
- Depends on: Sprint 1
- Files: `scripts/lib/orch_gateway.py`, `scripts/lib/run_projection.py`, `config/schemas/orchestra.full.schema.json`, `scripts/tests/test-gateway-run-lifecycle-state-machine.sh`

Approach:
- Add `lifecycle_status` while preserving existing `status` for compatibility.
- Implement a single transition guard table for PRD states.
- Map `stop_run()` to `cancelled` semantics and define resume behavior for `paused`/`blocked`.
- Ensure all advancement calls use the guard table before mutating `current_stage`.

Test Matrix:
- Legal transitions from `created` to `closed` are covered one by one.
- Illegal transition from `created` directly to `implementation` is rejected.

Negative Tests:
- `blocked` run cannot advance without resolving blocker refs.
- `cancelled` run cannot resume through normal worker output.

Risk Fallback:
- If replacing `status` is too risky, keep `status` as transport state and add `lifecycle_status` as authoritative workflow state.

