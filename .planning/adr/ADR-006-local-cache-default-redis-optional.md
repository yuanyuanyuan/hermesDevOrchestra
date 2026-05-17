# ADR-006: Local Filesystem Cache Default With Optional Redis Adapter

**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Use local filesystem cache as the MVP default and keep Redis as a future optional adapter.

## Context

The production architecture premise pairs local project knowledge with Redis cache to reduce cost and latency. The MVP goal is a complete vertical workflow loop, and adding Redis as a required dependency would expand setup, health checking, and failure handling before the workflow contract is proven.

## Decision

The MVP cache backend is `local_filesystem` under the local cache root. Redis is a future optional adapter exposed through the same cache contract. Cache keys, TTLs, object types, and invalidation semantics must be backend-neutral, and cache entries may only store rebuildable results. If Redis is configured later and unavailable, the Gateway emits `cache_degraded`, falls back to local filesystem cache, and continues.

## Consequences

- The MVP can run locally without Redis setup.
- The design still preserves a Redis migration path.
- Cache cannot become a hidden state authority; approval state, Kanban lifecycle state, immutable Audit artifacts, and sensitive raw user input stay out of cache.
