# Sprint 10: Global Evaluation Veto And Residual Risk

## Goal

Add one-vote veto and residual-risk threshold logic to global evaluation routing.

## Implementation Units

### U10: Veto and residual-risk authority routing

- SP: 5
- team_topology: pair
- Depends on: Sprint 2
- Files: `scripts/lib/gateway_evaluation.py`, `scripts/lib/orch_gateway.py`, `config/debate/full/coverage-policy.json`, `scripts/tests/test-gateway-global-evaluation-veto-risk-thresholds.sh`

Approach:
- Define veto dimensions from PRD and policy config.
- Block high residual risks unless explicit authority route approval exists.
- Preserve summary/full/none notification behavior.
- Sort residual risks by severity and attach required action.

Test Matrix:
- Veto dimension score blocks even if average score is high.
- High residual risk with L4 change requires human and Kimi approval.

Negative Tests:
- High residual risk without approval cannot closeout.
- Unknown residual risk severity fails validation.

Risk Fallback:
- If policy config is incomplete, use strict default veto for security/compliance and completion correctness.

