# Sprint 7: Worker Source Isolation

## Goal

Enforce that review, audit, and cross_check workers are not sourced from the same model/source as the upper-level adjudicator.

## Implementation Units

### U7: `model_source` and source isolation violation

- SP: 5
- team_topology: pair
- Depends on: Sprint 2
- Files: `scripts/lib/worker_session.py`, `scripts/lib/dag_validator.py`, `scripts/lib/orch_gateway.py`, `config/schemas/orchestra.full.schema.json`, `scripts/tests/test-worker-source-isolation.sh`

Approach:
- Add `model_source` to worker session creation and schema.
- Define upper adjudicator source in run/task context.
- Reject review/audit/cross_check sessions with same source.
- Preserve existing fingerprint collision checks as a separate mechanism.

Test Matrix:
- Same-source review worker returns `source_isolation_violation`.
- Different-source review worker creates session normally.

Negative Tests:
- Missing `model_source` for review/audit/cross_check fails.
- Unknown source fails closed unless explicitly configured as `other` with policy.

Risk Fallback:
- If existing callers cannot provide source immediately, gate only review/audit/cross_check and keep implementer sessions backward compatible for one sprint.

