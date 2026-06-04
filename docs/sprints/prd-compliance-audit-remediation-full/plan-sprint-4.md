# Sprint 4: Channel Routing Propagation

## Goal

Persist Quick/Light/Standard channel decisions and make them affect run creation, required evidence, and stage behavior.

## Implementation Units

### U4: Channel decision in run and stage contracts

- SP: 5
- team_topology: pair
- Depends on: Sprint 2
- Files: `scripts/lib/channel_router.py`, `scripts/lib/rollout_gate.py`, `scripts/lib/orch_gateway.py`, `config/performance/slo-policy.json`, `scripts/tests/test-gateway-channel-routing-propagation.sh`

Approach:
- Call `ChannelRouter.classify()` during run creation or post-intake routing.
- Persist `channel_decision` on run state and events.
- Convert channel to required debate rounds, required evidence, and allowed stage skips.
- Keep Standard as fallback whenever channel confidence/evidence is insufficient.

Test Matrix:
- Quick task persists `channel=quick` and lower evidence/debate requirements.
- Standard task keeps full six-stage requirements.

Negative Tests:
- Missing rollout evidence forces Standard.
- Unknown channel config returns `channel_policy_invalid`.

Risk Fallback:
- If stage skipping is too risky, first persist channel and required depth without skipping stages; Sprint 6 consumes it.

