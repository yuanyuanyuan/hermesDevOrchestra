# ADR-022: Failed Vs Blocked Run Boundary

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Default recoverable workflow problems to `blocked`; reserve terminal `failed` for unrecoverable workflow authority or evidence integrity failures.

## Context

Hermes Orchestra must handle test failures, reviewer rejection, schema mismatch, worker crashes, and missing approvals without losing evidence. The `qnN4o510` premise treats Schema, DAG/Kanban, Gateway State, Harness artifacts, and Audit as the anti-drift backbone. If ordinary work failures become terminal too aggressively, the workflow loses its diagnosis and repair path.

## Decision

MVP defaults to `blocked` when the run can safely preserve evidence and wait for decision, repair, or follow-up. Test failure, review rejection, QA block, schema mismatch, decision expiration, missing approval, and repeated worker failure are blocked states by default.

A run becomes terminal `failed` only when it can no longer be safely continued because workflow authority or evidence integrity is unrecoverable. MVP terminal failure reasons are limited to Gateway/State/Audit/Kanban authority-chain corruption, unrecoverable critical State/Audit/artifact loss, unauthorized or out-of-scope writes that make the current run untrusted, or internal workflow invariant violation that prevents safe recovery.

Failed runs emit `run_failed`, write immutable Audit evidence and `run_failure_report`, preserve State/Audit/Kanban/artifact refs, record `last_good_checkpoint_ref` when available, and include lineage hints for a future run. Failed runs are terminal and continue only through a new run with lineage.

## Consequences

- Ordinary implementation and validation failures remain diagnosable and recoverable.
- Terminal failure means the run itself is no longer trustworthy, not merely that work failed.
- Future continuation starts from auditable lineage rather than mutating failed history.
