# Sprint 5: Security Escape And Heartbeat Recovery

## Goal

Force sensitive diffs to Standard channel and complete heartbeat reconnect/snapshot behavior.

## Implementation Units

### U5: Security escape rules

- SP: 3
- team_topology: solo
- Depends on: Sprint 4
- Files: `scripts/lib/channel_router.py`, `scripts/lib/evidence_scanner.py`, `scripts/lib/security_gate.py`, `config/performance/slo-policy.json`, `scripts/tests/test-channel-security-escape.sh`

Approach:
- Expand sensitive/security pattern set to at least six PRD-aligned classes.
- Let router accept diff/evidence context and force Standard on escape hits.
- Record `forced_standard_reasons[]`.

### U12: Heartbeat reconnect and snapshot

- SP: 3
- team_topology: solo
- Depends on: Sprint 2
- Files: `scripts/lib/heartbeat_handler.py`, `scripts/lib/orch_gateway.py`, `scripts/tests/test-gateway-heartbeat-reconnect-snapshot.sh`

Approach:
- Implement snapshot response containing run/task/worker state.
- Reconnect query returns latest 3 heartbeat events when requested within 5 seconds.

Negative Tests:
- Diff containing secret pattern cannot remain Quick.
- Snapshot for unknown run returns 404 without creating state.

Risk Fallback:
- If diff context is unavailable at classify time, persist provisional channel and force Standard before auto-merge.

