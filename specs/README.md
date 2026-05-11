# Derived Specifications

`.planning/SPEC.md` is the canonical specification. Files in `specs/` are derived projections for current repository consumers.

If a derived spec conflicts with `.planning/SPEC.md`, update the derived spec to match `.planning/SPEC.md`.

Downstream read order: `.planning/SPEC.md`, then the relevant `specs/*.md`, then the root-package implementation projections (`README.md`, `WORKFLOW.md`, `scripts/`, `config/`, `hermes/`, `skills/`, `claude-config/`).

No current consumer, no derived spec.

## Index

| Spec | Scope | Consumers |
|---|---|---|
| `specs/file-bus.md` | File-bus protocol, envelope, ownership, locking, validation, and audit migration projection. | `scripts/bin/orch-bus-loop`, `scripts/tests/test-file-bus.sh`, `README.md`, `WORKFLOW.md` |
| `specs/risk-decisions.md` | Risk floors, L3/L4 blocking, local decision fallback, approval binding, and decision envelope projection. | `scripts/bin/orch-risk-check`, `config/rules.json`, `scripts/bin/orch-decisions`, `scripts/bin/orch-approve`, `scripts/bin/orch-reject`, `scripts/tests/test-risk-check.sh`, `scripts/tests/test-risk-decisions.sh`, `scripts/tests/test-decision-cli.sh`, `scripts/tests/test-decision-replay.sh` |
| `specs/commands.md` | Local `orch-*` helper surface, command result expectations, idempotency, and package boundary projection. | `scripts/bin/orch-init`, `scripts/bin/orch-start`, `scripts/bin/orch-stop`, `scripts/bin/orch-status`, `scripts/bin/orch-bus-loop`, `scripts/bin/orch-risk-check`, `scripts/bin/orch-decisions`, `scripts/bin/orch-approve`, `scripts/bin/orch-reject`, `scripts/bin/orch-audit`, `scripts/bin/orch-verify`, `README.md`, `WORKFLOW.md`, `scripts/tests/test-docs.sh` |

## Consumers

### `specs/file-bus.md`

- `scripts/bin/orch-bus-loop`
- `scripts/tests/test-file-bus.sh`
- `README.md`
- `WORKFLOW.md`

### `specs/risk-decisions.md`

- `scripts/bin/orch-risk-check`
- `config/rules.json`
- `scripts/bin/orch-decisions`
- `scripts/bin/orch-approve`
- `scripts/bin/orch-reject`
- `scripts/tests/test-risk-check.sh`
- `scripts/tests/test-risk-decisions.sh`
- `scripts/tests/test-decision-cli.sh`
- `scripts/tests/test-decision-replay.sh`

### `specs/commands.md`

- `scripts/bin/orch-init`
- `scripts/bin/orch-start`
- `scripts/bin/orch-stop`
- `scripts/bin/orch-status`
- `scripts/bin/orch-bus-loop`
- `scripts/bin/orch-risk-check`
- `scripts/bin/orch-decisions`
- `scripts/bin/orch-approve`
- `scripts/bin/orch-reject`
- `scripts/bin/orch-audit`
- `scripts/bin/orch-verify`
- `README.md`
- `WORKFLOW.md`
- `scripts/tests/test-docs.sh`
