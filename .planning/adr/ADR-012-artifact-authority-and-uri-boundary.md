# ADR-012: Artifact Authority And URI Boundary

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Use scoped artifact URIs and separate State, Audit, Cache, and repository knowledge authority instead of exposing local paths or treating every artifact as equivalent.

## Context

Hermes Orchestra needs to resume runs, prove decisions, accelerate repeated work, and preserve long-lived project knowledge. Those needs overlap in storage shape but not in authority. The Get笔记 `qnN4o510` premise emphasizes Schema, DAG, Harness, and structured evidence as anti-drift controls, so the MVP must not let cache objects or model summaries masquerade as workflow truth.

## Decision

Gateway APIs return only `state://`, `audit://`, `cache://`, and `repo://` artifact references. State stores resumable runtime state, Audit stores immutable evidence, Cache stores rebuildable optimization results, and repository `.workflow/knowledge/*` stores long-lived project knowledge. The URI resolver validates project/run scope and rejects absolute paths, traversal, unknown schemes, and cross-scope references.

Run recovery uses Kanban lifecycle plus Gateway State, State Artifacts, and Audit Artifacts. Run completion uses Kanban lifecycle, Gateway State, Audit, and schema-valid required artifacts. Cache hits and model self-report never count as resume or completion authority.

## Consequences

- API clients can inspect artifacts without learning local filesystem paths.
- Cache can be replaced or cleared without changing workflow truth.
- Missing critical State, Audit, or Repo refs block the stage, while cache misses rebuild or degrade.
- Completion checks stay evidence-driven and aligned with the six-stage anti-drift premise.
