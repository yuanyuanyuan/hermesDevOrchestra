# Architecture Research: Hermes CLI Prototype

**Researched:** 2026-04-25

## Target Shape

The prototype should be a thin command shell over durable local files:

Hermes CLI → command handlers → path resolver → registry/state store → runtime bus writer → audit writer.

## Integration Points

- .planning/SPEC.md: canonical source for command, bus, risk, recovery, and acceptance contracts.
- .planning/milestones/v1.0-REQUIREMENTS.md: archived source of the 60 accepted v1 requirements.
- docs/hermes-dev-orchestra/scripts/setup.sh: source input for no-sudo assumptions and older orch-* helper concepts.

## Build Order

1. CLI shell and command result envelope.
2. Path resolver and paths.json manifest.
3. Project registry, task append, status read model.
4. Doctor probes, risk rules, decision fallback.
5. Smoke fixtures, docs, and handoff.
