# Sprint 13: Final PRD Compliance Audit Gate

## Goal

Add one final strict e2e gate proving the remediated PRD compliance issues are closed together.

## Implementation Units

### U15: Full remediation e2e gate

- SP: 5
- team_topology: pair
- Depends on: Sprint 12
- Files: `scripts/tests/test-prd-compliance-remediation-e2e.sh`, `scripts/tests/run-all.sh`, `docs/PRD-COMPLIANCE-AUDIT-REPORT.md`, `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`

Approach:
- Build a fixture run that exercises intake, channel routing, conflict ledger, worker source isolation, rollback-ready state, global evaluation risk routing, correction Override, closeout, and continuous improvement audit.
- Add release gate report proving required tests passed together.
- Update audit report with exact remediated/unremediated status only after tests pass.

Test Matrix:
- Full fixture run reaches closeout only after all blockers are resolved.
- Fixture with unresolved high conflict or high residual risk blocks.

Negative Tests:
- Removing one required gate makes release report fail.
- Closeout without schema/doc sync evidence fails.

Risk Fallback:
- If full e2e is too slow for default `run-all.sh`, keep it as named strict gate and document when it must run before PRD compliance claims.

