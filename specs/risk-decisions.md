# Risk Decisions Derived Spec

## Source

Primary: `.planning/SPEC.md` §§AUTH-03, RISK-01..RISK-05, REMOTE-05, Appendix A, Appendix B.

If this derived spec conflicts with `.planning/SPEC.md`, update this derived spec to match `.planning/SPEC.md`.

Downstream read order: `.planning/SPEC.md`, then this derived spec, then `docs/orchestra/*` implementation projections.

## Consumers

- `docs/orchestra/scripts/bin/orch-risk-check` - classifies command and file-change risk floors.
- `docs/orchestra/config/rules.json` - stores static rule floor data.
- `docs/orchestra/scripts/bin/orch-decisions` - lists pending local fallback decisions.
- `docs/orchestra/scripts/bin/orch-approve` - writes local approval responses.
- `docs/orchestra/scripts/bin/orch-reject` - writes local rejection responses.
- `docs/orchestra/scripts/tests/test-risk-check.sh` - smoke-tests risk classification.
- `docs/orchestra/scripts/tests/test-risk-decisions.sh` - smoke-tests L3/L4 blocking behavior.
- `docs/orchestra/scripts/tests/test-decision-cli.sh` - smoke-tests local decision CLI behavior.
- `docs/orchestra/scripts/tests/test-decision-replay.sh` - smoke-tests replay prevention.

## Contract

- Hermes enforces static risk rule floors from the rulebook before forwarding decisions.
- Claude may upgrade a risk classification but may not downgrade below the rulebook floor.
- L3 and L4 decisions block the affected project until the user explicitly approves or rejects the proposal.
- L3 and L4 decisions have no timeout-based or fallback auto-approval path. Timeout defaults to rejection.
- Local fallback commands are `orch-decisions`, `orch-approve`, and `orch-reject`.
- File-based local fallback writes decision requests under Runtime decisions as `{decision-id}.request.json` and responses as `{decision-id}.response.json`.
- Every approval response is bound to a one-time `approval_id`, TTL, `project_id`, and `task_id`; reused, expired, or mismatched approvals are rejected.
- Hermes writes the final user decision to Audit after validating one-time use, TTL, and project/task binding.
- Decision envelopes carry the field groups `rulebook`, `assessment`, `execution`, and `history`.

## Drift Check

```bash
bash docs/orchestra/scripts/tests/test-specs.sh && bash docs/orchestra/scripts/tests/test-risk-check.sh && bash docs/orchestra/scripts/tests/test-risk-decisions.sh && bash docs/orchestra/scripts/tests/test-decision-cli.sh && bash docs/orchestra/scripts/tests/test-decision-replay.sh
```

## Conformance Checks

- `bash docs/orchestra/scripts/tests/test-specs.sh`
- `bash docs/orchestra/scripts/tests/test-risk-check.sh`
- `bash docs/orchestra/scripts/tests/test-risk-decisions.sh`
- `bash docs/orchestra/scripts/tests/test-decision-cli.sh`
- `bash docs/orchestra/scripts/tests/test-decision-replay.sh`
