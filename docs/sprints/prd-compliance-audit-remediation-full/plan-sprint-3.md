# Sprint 3: Rollback Strategy

## Goal

Implement PRD rollback behavior for implementation and improvement phases with auditable reports and current-run scope protection.

## Implementation Units

### U3: Rollback request and executor

- SP: 5
- team_topology: pair
- Depends on: Sprint 2
- Files: `scripts/lib/orch_gateway.py`, `scripts/lib/release_executor.py`, `config/release/commands.json`, `scripts/tests/test-gateway-rollback-strategy.sh`

Approach:
- Add rollback request handling for implementation/improvement/global evaluation failure paths.
- Require baseline refs before rollback starts.
- Execute only current-run rollback commands and produce `rollback_report.json`.
- Block rollback touching protected targets without human approval.

Test Matrix:
- Implementation rollback reverts only current-run changed refs.
- Improvement rollback returns to implementation baseline.

Negative Tests:
- Missing baseline ref returns `rollback_prereq_missing`.
- Protected target rollback without approval returns `protected_target_approval_required`.

Risk Fallback:
- If command execution is unsafe in tests, implement dry-run report first and gate real execution behind explicit command registry refs.

