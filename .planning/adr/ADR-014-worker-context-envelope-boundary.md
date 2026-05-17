# ADR-014: Worker Context Envelope Boundary

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Feed workers scoped `hermes-role-engine/v1` context envelopes and read-only context bundles instead of raw chat history, full project dumps, or unbounded prompts.

## Context

Hermes Orchestra needs real CLI/API workers, but the `qnN4o510` premise depends on structured tickets, schemas, DAGs, Harness artifacts, and audit evidence to prevent drift. Passing the whole chat or repository into a worker would hide what context was used, increase privacy risk, and make replay or review difficult.

## Decision

Gateway assembles a Worker Context Envelope containing structured task data, role, selected backend, stage, risk and approval state, allowed write scope, workspace strategy, artifact refs, context bundle refs, and test requirements. Context Bundles are read-only, scoped, and artifact-ref based. They may include relevant structured PRD, development plan, debate/stage reports, selected `.workflow/knowledge/*` summaries, task projection data, baseline diff/status artifacts, and selected source-file excerpts or summaries.

Worker input must not include secrets, secret environment values, absolute local paths, full raw chat history, unrelated prior conversation, full project dumps, or unredacted temporary raw tickets. If a worker needs more context, it must return `next_action: request_context` with a structured request; the Gateway may add only validated artifact refs or a new scoped Context Bundle and must record that addition in Audit. Workflow state advances only from schema-valid structured worker output, not natural-language summaries.

## Consequences

- Worker execution remains replayable and auditable.
- Context size and privacy exposure stay bounded.
- Workers can still request more information, but only through validated artifact refs.
- Structured output remains the state transition authority.
