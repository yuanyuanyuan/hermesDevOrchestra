# Feature Research: Hermes CLI Prototype

**Researched:** 2026-04-25

## Table Stakes

- hermes --help, hermes --version, and structured command errors.
- hermes init for project registry creation.
- hermes task for append-anytime queue entries.
- hermes status for project/task/next-action visibility.
- hermes doctor for CLI and host capability checks.
- hermes decisions, approve, and reject for local decision fallback.

## Differentiators

- Spec-derived command contracts, not ad-hoc scripts.
- Four-layer path manifest and physical bus/state/audit separation from the beginning.
- Risk rulebook floor and L3/L4 no-auto-approval invariant in the prototype.

## Anti-Features

- No full unattended mode.
- No concrete remote adapter.
- No live multi-agent execution loop until CLI/state/bus safety is proven.
