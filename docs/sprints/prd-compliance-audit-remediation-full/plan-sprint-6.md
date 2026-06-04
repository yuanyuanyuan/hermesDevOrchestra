# Sprint 6: Quick And Light Mini-Debate

## Goal

Connect channel routing to bounded debate execution for Quick and Light channels.

## Implementation Units

### U6: Mini-debate orchestration

- SP: 5
- team_topology: pair
- Depends on: Sprint 4
- Files: `scripts/lib/debate_engine.py`, `scripts/lib/debate_assembly.py`, `scripts/lib/orch_gateway.py`, `config/performance/slo-policy.json`, `scripts/tests/test-channel-mini-debate.sh`

Approach:
- Set Quick to one bounded confirmation round where PRD requires confirmation; Light uses one minimal debate round.
- Persist mini-debate refs on run state.
- Enforce timeout metadata and degradation behavior.
- Standard keeps existing full debate depth.

Test Matrix:
- Light channel produces one mini-debate report.
- Standard channel produces full-depth requirement refs.

Negative Tests:
- Mini-debate timeout forces Standard or blocked decision according to policy.
- Missing debate report blocks auto-merge.

Risk Fallback:
- If real debate backend is unavailable, mark degraded evidence and block completion rather than treating fixture output as completion evidence.

