# Commands Derived Spec

## Source

Primary: `.planning/SPEC.md` §§CMD-01..CMD-02.

`docs/orchestra/README.md` and `docs/orchestra/WORKFLOW.md` are projections only. If either projection conflicts with `.planning/SPEC.md`, update the projection or this derived spec to match `.planning/SPEC.md`.

Downstream read order: `.planning/SPEC.md`, then this derived spec, then `docs/orchestra/*` implementation projections.

## Consumers

- `docs/orchestra/scripts/bin/orch-init` - initializes project state and bus paths.
- `docs/orchestra/scripts/bin/orch-start` - starts or reuses project sessions.
- `docs/orchestra/scripts/bin/orch-stop` - stops project sessions.
- `docs/orchestra/scripts/bin/orch-status` - reports project state.
- `docs/orchestra/scripts/bin/orch-bus-loop` - runs local bus dispatch.
- `docs/orchestra/scripts/bin/orch-risk-check` - exposes risk classification.
- `docs/orchestra/scripts/bin/orch-decisions` - lists pending local fallback decisions.
- `docs/orchestra/scripts/bin/orch-approve` - approves a pending local fallback decision.
- `docs/orchestra/scripts/bin/orch-reject` - rejects a pending local fallback decision.
- `docs/orchestra/scripts/bin/orch-audit` - reads durable audit records.
- `docs/orchestra/scripts/bin/orch-verify` - runs smoke verification.
- `docs/orchestra/README.md` - human-facing command projection.
- `docs/orchestra/WORKFLOW.md` - workflow command projection.
- `docs/orchestra/scripts/tests/test-docs.sh` - smoke-tests documented command coverage.

## Contract

- This repository is an adapter layer with local entrypoints limited to `orch-*` helpers.
- The current local helper surface is `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, and `orch-verify`.
- Command success output follows `.planning/SPEC.md` CMD-02: structured result with `success: true`, `command`, `timestamp`, `data`, and `error: null`.
- Command failure output follows `.planning/SPEC.md` CMD-02: structured result with `success: false`, `command`, `timestamp`, `data: null`, and an `error` object containing `code`, `message`, and `suggestion`.
- Idempotent commands must be safe to repeat where documented by `.planning/SPEC.md` CMD-01; one-time approval commands are not idempotent because approval IDs are single use.
- Phase 15 does not add Makefile targets or command implementations.

## Drift Check

```bash
for cmd in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-decisions orch-approve orch-reject orch-audit orch-verify; do test -x "docs/orchestra/scripts/bin/$cmd"; done && bash docs/orchestra/scripts/tests/test-specs.sh && bash docs/orchestra/scripts/tests/test-docs.sh
```

## Conformance Checks

- `bash docs/orchestra/scripts/tests/test-specs.sh`
- `bash docs/orchestra/scripts/tests/test-docs.sh`
- `for cmd in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-decisions orch-approve orch-reject orch-audit orch-verify; do test -x "docs/orchestra/scripts/bin/$cmd"; done`
