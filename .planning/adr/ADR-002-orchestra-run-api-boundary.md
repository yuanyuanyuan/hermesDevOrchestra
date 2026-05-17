# ADR-002: Separate Orchestra Runs From Upstream Hermes Runs

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Keep `/orchestra/runs` as the six-stage workflow API and treat official `/v1/runs` as an upstream Hermes agent-run surface.

## Context

Hermes Orchestra needs a Kimi-facing API for the full six-stage R&D loop: direction debate, solution debate, implementation, improvement, global evaluation, and continuous improvement. Upstream Hermes also exposes OpenAI-compatible HTTP surfaces, including run-like endpoints, but those represent upstream agent execution/session semantics rather than the product-level Orchestra workflow.

## Decision

The Gateway Adapter owns `127.0.0.1:8642` and exposes `/orchestra/*` for Orchestra workflow operations. The official Hermes API Server may run behind the adapter on an internal URL such as `http://127.0.0.1:8643`, and the adapter may reverse-proxy `/v1/*` without changing upstream semantics.

## Consequences

- Kimi receives one stable product workflow API without depending on upstream run semantics.
- Upstream Hermes can still be upgraded or proxied without forking or redefining its API.
- The adapter must clearly separate `/orchestra/runs` workflow state from `/v1/runs` upstream agent-run state in code, docs, tests, and health reporting.
