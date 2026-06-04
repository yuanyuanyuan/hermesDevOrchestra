# Sprint 5 Checklist: Security Escape And Heartbeat Recovery

## Architecture Redlines

- [ ] Sensitive pattern list is config-backed, not hardcoded in multiple modules.
- [ ] Heartbeat snapshot endpoint is read-only.

## Functional Acceptance

- [ ] At least six sensitive/security classes force Standard.
- [ ] Forced Standard includes `forced_standard_reasons[]`.
- [ ] Reconnect within 5 seconds returns exactly latest 3 heartbeat events when at least 3 exist.
- [ ] Snapshot includes run, current task, worker sessions, blockers, and latest heartbeat timestamp.

## Test Coverage

- [ ] `bash scripts/tests/test-channel-security-escape.sh`
- [ ] `bash scripts/tests/test-gateway-heartbeat-reconnect-snapshot.sh`
- [ ] Negative: secret diff cannot auto-merge.
- [ ] Negative: unknown run snapshot returns 404.

## Docs/Schema Sync

- [ ] `config/performance/slo-policy.json` docs updated for security escape patterns.
- [ ] Heartbeat response schema documented.

