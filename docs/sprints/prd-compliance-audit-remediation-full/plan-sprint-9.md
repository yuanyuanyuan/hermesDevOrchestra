# Sprint 9: Intake Completeness And E-Class Mini-Debate

## Goal

Complete PRD intake bundle fields and connect E-class improvement disputes to real mini-debate.

## Implementation Units

### U9: Intake completeness

- SP: 3
- team_topology: solo
- Depends on: Sprint 8
- Files: `scripts/lib/project_discovery.py`, `scripts/lib/gateway_projection.py`, `config/schemas/orchestra.full.schema.json`, `scripts/tests/test-intake-completion-prd-fields.sh`

Approach:
- Add CI/CD config detection.
- Expand `prompt_envelope` to 8 PRD-required parts.
- Separate verified facts from unverified assumptions.

### U13: E-class mini-debate

- SP: 3
- team_topology: solo
- Depends on: Sprint 6
- Files: `scripts/lib/gateway_improvement.py`, `scripts/lib/debate_engine.py`, `scripts/tests/test-improvement-e-class-mini-debate.sh`

Approach:
- Route E-class disputes into two-round mini-debate.
- Block if consensus score remains below 0.60.

Negative Tests:
- Missing CI/CD discovery fields fail bundle validation.
- E-class dispute without debate refs blocks.

Risk Fallback:
- If E-class debate backend is unavailable, block with `debate_unavailable` instead of selecting one reviewer automatically.

