# ADR-013: Worker Backend Registry And Capability Negotiation

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Select worker backends through role capability negotiation against registered backend and role configs, not by hard-coding CLI names or letting Kimi choose arbitrary tools.

## Context

Hermes Orchestra treats Kimi as the upper orchestrator while Hermes/Gateway owns structured execution. The MVP needs real Codex/Claude workers, but the `qnN4o510` premise also expects replaceable execution agents and auditable workflow state. If workflow logic depends directly on tool names, future backend replacement, fallback auditing, and role safety become brittle.

## Decision

`config/workers/backends.json` declares enabled backend adapters, invocation details, health checks, modes, and capabilities. `config/workers/roles.json` maps workflow roles to required capabilities, preferred backends, explicit fallback backends, and fallback-allowed failure classes. Kimi may request `options.worker_pairing`, but the Gateway accepts it only when the backend is registered, enabled, role-compatible, and available in `/orchestra/capabilities`.

Before dispatch, Gateway records the selected backend, version, matched capabilities, adapter type, fallback status, and any fallback rationale in Gateway State and Audit. Fallback is allowed only for configured retryable backend failures. `parse_error`, `schema_mismatch`, security policy hits, Human Approval boundaries, forbidden automatic modification targets, and unvalidated worker output block instead of falling back. All workers speak `hermes-role-engine/v1`; CLI/API differences stay inside Worker Adapters.

## Consequences

- Codex/Claude can be MVP defaults without becoming workflow semantics.
- Kimi remains an orchestrator, not a raw tool dispatcher.
- Backend failure handling is auditable and cannot bypass schema, safety, or approval boundaries.
- Future API workers can replace CLI workers behind the same role protocol.
