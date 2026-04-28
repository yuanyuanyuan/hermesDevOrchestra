# Derived Specifications

`.planning/SPEC.md` is the canonical specification. Files in `specs/` are derived projections for current repository consumers.

If a derived spec conflicts with `.planning/SPEC.md`, update the derived spec to match `.planning/SPEC.md`.

Downstream read order: `.planning/SPEC.md`, then the relevant `specs/*.md`, then `docs/orchestra/*` implementation projections.

No current consumer, no derived spec.

## Index

| Spec | Scope | Consumers |
|---|---|---|
| `specs/file-bus.md` | File-bus protocol, envelope, ownership, locking, validation, and audit migration projection. | `docs/orchestra/scripts/bin/orch-bus-loop`, `docs/orchestra/scripts/tests/test-file-bus.sh`, `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md` |
| `specs/risk-decisions.md` | Risk floors, L3/L4 blocking, local decision fallback, approval binding, and decision envelope projection. | `docs/orchestra/scripts/bin/orch-risk-check`, `docs/orchestra/config/rules.json`, `docs/orchestra/scripts/bin/orch-decisions`, `docs/orchestra/scripts/bin/orch-approve`, `docs/orchestra/scripts/bin/orch-reject`, `docs/orchestra/scripts/tests/test-risk-check.sh`, `docs/orchestra/scripts/tests/test-risk-decisions.sh`, `docs/orchestra/scripts/tests/test-decision-cli.sh`, `docs/orchestra/scripts/tests/test-decision-replay.sh` |
| `specs/commands.md` | Local `orch-*` helper surface, command result expectations, idempotency, and package boundary projection. | `docs/orchestra/scripts/bin/orch-init`, `docs/orchestra/scripts/bin/orch-start`, `docs/orchestra/scripts/bin/orch-stop`, `docs/orchestra/scripts/bin/orch-status`, `docs/orchestra/scripts/bin/orch-bus-loop`, `docs/orchestra/scripts/bin/orch-risk-check`, `docs/orchestra/scripts/bin/orch-decisions`, `docs/orchestra/scripts/bin/orch-approve`, `docs/orchestra/scripts/bin/orch-reject`, `docs/orchestra/scripts/bin/orch-audit`, `docs/orchestra/scripts/bin/orch-verify`, `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md`, `docs/orchestra/scripts/tests/test-docs.sh` |

## Consumers

### `specs/file-bus.md`

- `docs/orchestra/scripts/bin/orch-bus-loop`
- `docs/orchestra/scripts/tests/test-file-bus.sh`
- `docs/orchestra/README.md`
- `docs/orchestra/WORKFLOW.md`

### `specs/risk-decisions.md`

- `docs/orchestra/scripts/bin/orch-risk-check`
- `docs/orchestra/config/rules.json`
- `docs/orchestra/scripts/bin/orch-decisions`
- `docs/orchestra/scripts/bin/orch-approve`
- `docs/orchestra/scripts/bin/orch-reject`
- `docs/orchestra/scripts/tests/test-risk-check.sh`
- `docs/orchestra/scripts/tests/test-risk-decisions.sh`
- `docs/orchestra/scripts/tests/test-decision-cli.sh`
- `docs/orchestra/scripts/tests/test-decision-replay.sh`

### `specs/commands.md`

- `docs/orchestra/scripts/bin/orch-init`
- `docs/orchestra/scripts/bin/orch-start`
- `docs/orchestra/scripts/bin/orch-stop`
- `docs/orchestra/scripts/bin/orch-status`
- `docs/orchestra/scripts/bin/orch-bus-loop`
- `docs/orchestra/scripts/bin/orch-risk-check`
- `docs/orchestra/scripts/bin/orch-decisions`
- `docs/orchestra/scripts/bin/orch-approve`
- `docs/orchestra/scripts/bin/orch-reject`
- `docs/orchestra/scripts/bin/orch-audit`
- `docs/orchestra/scripts/bin/orch-verify`
- `docs/orchestra/README.md`
- `docs/orchestra/WORKFLOW.md`
- `docs/orchestra/scripts/tests/test-docs.sh`
