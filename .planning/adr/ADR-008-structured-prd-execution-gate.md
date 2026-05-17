# ADR-008: Structured PRD Gates Six-Stage Execution

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Accept short intent for intake, but require a structured ticket or schema-valid structured PRD before starting the six-stage workflow.

## Context

The Hermes Orchestra premise depends on structured work orders with background, goals, constraints, acceptance criteria, and failure strategy. Letting short natural-language intent directly enter a long multi-agent workflow increases target drift and weakens Kimi's ability to accept or reject the outcome against a concrete checklist.

## Decision

`POST /orchestra/runs` may accept either `intent` or `ticket`, but short intent only starts intake and normalization. The Gateway must produce or receive a schema-valid `structured_prd.json` before entering `direction_debate`. If acceptance criteria, constraints, risks, or failure strategy are missing, the run remains blocked and emits a Kimi-authority decision requirement.

## Consequences

- Kimi can still send concise requests, but execution does not begin until the request has enough structure.
- The six-stage workflow has a stable acceptance contract before work starts.
- Demo and smoke flows can exercise normalization, but they must still satisfy the structured PRD gate before completion.
