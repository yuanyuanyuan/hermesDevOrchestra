# ADR-009: Do Not Expose Raw Kanban CRUD Through Gateway

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Keep Kimi on product-level run, event, task projection, and decision APIs; do not expose raw Kanban CRUD through the Gateway.

## Context

Kimi is the upper orchestrator for intent, progress supervision, acceptance, and audit. If Kimi can directly create, link, complete, or block arbitrary Kanban tasks, it can bypass the structured PRD gate, stage DAG, artifact validation, decision authority chain, and audit requirements that make the workflow reliable.

## Decision

The MVP Gateway exposes `/orchestra/runs`, run status, run events, read-only task projection, stop, decisions, capabilities, health, and optional `/v1/*` proxying. It does not expose raw task create/edit/link/complete/block endpoints. Gateway internals may call official `hermes kanban` commands, but only as consequences of workflow rules and accepted artifacts.

## Consequences

- Kimi stays at the product workflow level instead of becoming a board operator.
- Kanban remains the lifecycle substrate without leaking low-level mutation authority through the public adapter API.
- Future task-level controls must be modeled as constrained workflow actions, not raw board mutation.
