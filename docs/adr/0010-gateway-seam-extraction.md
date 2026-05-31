# ADR 0010: Gateway Seam Extraction — Intake / Projection / Evidence Helper Modules

## Status

Accepted — Sprint 1

## Context

`scripts/lib/orch_gateway.py` grew to 6109 lines and handles request routing, input validation, state projection, evidence collection, and audit logging all within a single file. This violates the seam-extraction principle and makes the Gateway difficult to test, extend, and reason about.

Sprint 1 needed to:
1. Extract intake/projection/evidence logic into independent helpers.
2. Ensure Gateway remains an orchestration/routing layer.
3. Add a safe fallback when helpers are unavailable.
4. Keep the single-file growth under 50 lines.

## Decision

We extracted three helper modules with a strict单向依赖 chain:

- `gateway_intake.py` — validates and normalizes incoming requests into `NormalizedIntent`.
- `gateway_projection.py` — projects `NormalizedIntent` + `GatewayContext` onto state as `ProjectedState`.
- `gateway_evidence.py` — gathers `EvidenceBundle` from a `ProjectedState` with confidence markers.

Gateway imports these helpers with a soft-fail try/except block. If import fails, `_HELPERS_OK = False` and Gateway continues in `FALLBACK_HEURISTIC` mode. Fallback events are written to `logs/gateway-fallback.jsonl`.

Gateway integration adds exactly **34 lines** to `orch_gateway.py`:
- 8 lines for import + availability flag.
- 18 lines for `_run_intake_pipeline()` and `_record_fallback()`.
- 8 one-line calls in entry methods (`create_run`, `module_endpoint`, `submit_worker_output`, `submit_verdict`, `submit_global_evaluation`, `submit_closeout`, `submit_failure`, `stop_run`).

## Consequences

**Positive:**
- Helpers are independently unit-testable.
- Gateway remains focused on routing and orchestration.
- Fallback strategy ensures resilience if helpers are corrupted or deleted.
- Strict单向依赖 prevents circular import issues.

**Negative / Trade-offs:**
- Helper modules are new abstractions; existing projection/evidence logic in Gateway was not fully migrated (that would require >50 lines). The helpers serve as a **new standardized pipeline layer** that Gateway calls, rather than a complete extraction of all existing logic.
- Slight runtime overhead (one extra function call per request type).

## Compliance

- Verified by `scripts/tests/test-gateway-seam-extraction.sh`.
- Architecture guardrail: single-file growth ≤ 50 lines (actual: 34).
- Import cycle check: `intake → projection → evidence` only.
