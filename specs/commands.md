# Commands Derived Spec

## Source

Primary: `.planning/SPEC.md` §§CMD-01..CMD-02.

`README.md` and `WORKFLOW.md` are projections only. If either projection conflicts with `.planning/SPEC.md`, update the projection or this derived spec to match `.planning/SPEC.md`.

Downstream read order: `.planning/SPEC.md`, then this derived spec, then the root-package implementation projections (`README.md`, `WORKFLOW.md`, `scripts/`, `config/`, `hermes/`, `skills/`, `claude-config/`).

## Consumers

- `scripts/bin/orch-init` - initializes project state and bus paths.
- `scripts/bin/orch-start` - starts or reuses project sessions.
- `scripts/bin/orch-stop` - stops project sessions.
- `scripts/bin/orch-status` - reports project state.
- `scripts/bin/orch-bus-loop` - runs local bus dispatch.
- `scripts/bin/orch-risk-check` - exposes risk classification.
- `scripts/bin/orch-decisions` - lists pending local fallback decisions.
- `scripts/bin/orch-approve` - approves a pending local fallback decision.
- `scripts/bin/orch-reject` - rejects a pending local fallback decision.
- `scripts/bin/orch-audit` - reads durable audit records.
- `scripts/bin/orch-verify` - runs smoke verification.
- `README.md` - human-facing command projection.
- `WORKFLOW.md` - workflow command projection.
- `scripts/tests/test-docs.sh` - smoke-tests documented command coverage.

## Contract

- This repository is an adapter layer with local entrypoints limited to `orch-*` helpers.
- The current local helper surface is `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, and `orch-verify`.
- Command success output follows `.planning/SPEC.md` CMD-02: structured result with `success: true`, `command`, `timestamp`, `data`, and `error: null`.
- Command failure output follows `.planning/SPEC.md` CMD-02: structured result with `success: false`, `command`, `timestamp`, `data: null`, and an `error` object containing `code`, `message`, and `suggestion`.
- Idempotent commands must be safe to repeat where documented by `.planning/SPEC.md` CMD-01; one-time approval commands are not idempotent because approval IDs are single use.
- Phase 15 does not add Makefile targets or command implementations.

## Drift Check

```bash
for cmd in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-decisions orch-approve orch-reject orch-audit orch-verify; do test -x "scripts/bin/$cmd"; done && bash scripts/tests/test-specs.sh && bash scripts/tests/test-docs.sh
```

## Conformance Checks

- `bash scripts/tests/test-specs.sh`
- `bash scripts/tests/test-docs.sh`
- `for cmd in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-decisions orch-approve orch-reject orch-audit orch-verify; do test -x "scripts/bin/$cmd"; done`
