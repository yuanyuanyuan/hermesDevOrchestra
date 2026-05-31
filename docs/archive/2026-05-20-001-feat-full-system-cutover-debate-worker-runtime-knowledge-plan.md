---
title: Full-System Cutover Plan for Debate, Worker Execution, and Runtime Knowledge
type: feat
status: active
date: 2026-05-20
origin: .planning/goals/full-system-cutover/02-goal-debate-worker-knowledge.md
---

# Full-System Cutover Plan for Debate, Worker Execution, and Runtime Knowledge

## Summary

This plan cuts the Debate Engine, Worker Execution, and Runtime Domain Knowledge Base over from staged full-target artifacts to the default active runtime path. The implementation focuses on family activation, Gateway wiring, TDD-first runtime-path tests, and consistency updates across code, config, validation, and coverage documentation.

---

## Problem Frame

The repository already contains full-target debate, worker, and runtime-knowledge artifacts, but the default runtime still depends on legacy paths or explicit `allow_staged=True` for these three capability families. As a result, the current runtime contract, gap analysis, and coverage matrix remain inconsistent with the intended full-system cutover target.

---

## Requirements

- R1. Default runtime must consume `config/debate/full/*` as the active debate authority without requiring caller-side `allow_staged=True`.
- R2. Debate runtime must preserve deterministic assembly, coverage policy, backend policy, audit trail, member invocation evidence, and degraded-evidence handling on the default path.
- R3. Default runtime must consume `config/workers/full/*` for worker backend and role selection, with explicit capability negotiation and no silent fallback.
- R4. Worker runtime must cover session lifecycle, write-scope enforcement, parallel-group planning, conflict handling, and Gateway-owned cleanup on the default path.
- R5. `config/knowledge/runtime-kb.json` and gbrain-backed runtime knowledge retrieval/ingestion must become active runtime behavior rather than staged-only behavior.
- R6. Runtime knowledge results must enforce freshness, provenance, warning-context degradation, and authority boundaries on the default runtime path.
- R7. Gateway runtime tests must prove the three families no longer depend on legacy-only behavior or explicit staged overrides for normal execution.
- R8. `IMPLEMENTATION-GAP-ANALYSIS.md`, `docs/FULL-COVERAGE-MATRIX.md`, and the stage completion report must be updated to reflect the cutover evidence and residual risks.

---

## Scope Boundaries

- This plan does not cut over release pipeline, remote decisions, or other families outside debate, worker execution, and runtime domain knowledge.
- This plan does not redesign full schemas or introduce new public Gateway endpoints unless execution reveals a blocking contract mismatch.
- This plan does not treat template debate, fake backends, or degraded knowledge results as strong completion evidence.

### Deferred to Follow-Up Work

- Release pipeline active-runtime cutover remains separate work under its own family gates.
- Remote decision transport cutover remains separate work under its own family gates.

---

## Context & Research

### Relevant Code and Patterns

- `scripts/lib/runtime_activation.py` already supports family-scoped default activation, but `MODULE_FAMILY_DEFAULTS` only covers gateway-authority and self-evolution modules.
- `config/cutover/full-readiness-gates.json` already defines artifact families for `full_debate_package`, `worker_execution`, and `runtime_domain_knowledge`, including required checks and rollback policy.
- `scripts/lib/debate_engine.py`, `scripts/lib/debate_assembly.py`, `scripts/lib/debate_member_invocation.py`, and `scripts/lib/debate_report.py` already implement full-path debate behavior, but their configs remain staged-only unless `allow_staged=True`.
- `scripts/lib/worker_registry.py`, `scripts/lib/capability_negotiation.py`, `scripts/lib/worker_session.py`, and `scripts/lib/worker_session_sweeper.py` already implement the full worker path and artifact contracts.
- `scripts/lib/runtime_knowledge.py` and `scripts/lib/knowledge_ingestion.py` already implement gbrain-backed retrieval and ingestion, but `config/knowledge/runtime-kb.json` is still disabled by default.
- `scripts/lib/orch_gateway.py` is the runtime integration choke point for module defaults, capability exposure, and real-path consumption tests.
- `scripts/tests/test-runtime-activation.sh`, `test-debate-assembly.sh`, `test-debate-member-invocation.sh`, `test-worker-registry.sh`, `test-worker-session.sh`, `test-runtime-knowledge.sh`, `test-gateway-integration-points.sh`, `test-e2e-ai-debate-flow.sh`, and `test-e2e-ai-worker-flow.sh` provide the closest existing runtime-path coverage.

### Institutional Learnings

- `IMPLEMENTATION-GAP-ANALYSIS.md` identifies the current false-positive pattern: full artifacts exist and pass isolated tests, but runtime behavior still depends on staged overrides.
- `docs/FULL-COVERAGE-MATRIX.md` treats active-runtime consumption as the real completion bar, not artifact presence alone.
- `docs/gateway-integration-architecture.md` documents mixed-family cutover as the intended runtime model and highlights Gateway as the family-scoped activation boundary.

### External References

- None. This plan is grounded in repository requirements, schemas, tests, and cutover policy.

---

## Key Technical Decisions

- Family activation remains mixed-family, not global cutover: activate only `full_debate_package`, `worker_execution`, and `runtime_domain_knowledge` while preserving the existing cutover policy model in `config/cutover/full-readiness-gates.json`.
- The activation boundary stays in Gateway/runtime activation rather than scattered per caller: module defaulting and runtime-family summary should be authoritative in `scripts/lib/runtime_activation.py` and `scripts/lib/orch_gateway.py`.
- Debate, worker, and runtime-knowledge configs should become active by configuration and family activation, not by keeping staged configs plus implicit override logic.
- Verification must prioritize default runtime behavior and degraded-boundary tests, because isolated full-path unit tests already exist and are insufficient to prove cutover.
- Documentation and matrix updates are part of the feature, not follow-up cleanup, because the goal explicitly requires consistency across runtime reality and authoritative documents.

---

## Open Questions

### Resolved During Planning

- Should the cutover be global or family-scoped? Family-scoped, because the repository already uses mixed-family activation and the goal is limited to three capability domains.
- Should schema/document updates wait until after runtime verification? No. They should land in the final unit after runtime tests prove the new default path.

### Deferred to Implementation

- Whether `orch_gateway.py` needs additional orchestration helpers for debate and worker parallel integration beyond existing module endpoints should be decided once the failing runtime-path tests identify the concrete gap.
- Whether any legacy config files need alias or compatibility metadata updates should be decided only if cutover tests expose existing callers that still depend on them.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification.*

```text
runtime-family-activation
  -> activate full_debate_package / worker_execution / runtime_domain_knowledge
  -> expose default module allow_staged for these families
  -> gateway/module entrypoints stop requiring explicit staged override

gateway runtime path
  -> debate family: load full registries -> assemble -> invoke -> report/audit -> degraded evidence policy
  -> worker family: load full registries -> negotiate capabilities -> create session -> parallel/conflict flow -> cleanup
  -> knowledge family: load active config -> query/ingest via gbrain -> enforce freshness/provenance -> degraded warning context

verification path
  -> red test on default runtime behavior
  -> minimal implementation
  -> regression/e2e/runtime activation tests
  -> matrix + gap analysis + completion report update
```

---

## Implementation Units

### U1. Extend runtime-family activation to the three target families

**Goal:** Make debate, worker execution, and runtime knowledge eligible for default runtime activation through the existing mixed-family cutover substrate.

**Requirements:** R1, R3, R5, R7

**Dependencies:** None

**Files:**
- Modify: `scripts/lib/runtime_activation.py`
- Modify: `config/cutover/runtime-family-activation.json`
- Modify: `scripts/tests/test-runtime-activation.sh`
- Modify: `scripts/tests/test-gateway-integration-points.sh`

**Approach:**
- Add module-to-family defaults for debate, worker, and runtime-knowledge modules in `runtime_activation.py`.
- Extend `runtime-family-activation.json` with cutover entries for `full_debate_package`, `worker_execution`, and `runtime_domain_knowledge` using the existing readiness-gate contract.
- Update runtime activation and gateway integration tests to assert these families are active on the default path and still blocked when a family is inactive or missing evidence.

**Execution note:** Follow TDD: first add failing assertions that default module routing stays blocked today, then wire the new family activation until the runtime activation tests pass.

**Test scenarios:**
- Happy path: runtime activation summary includes the three new family ids and maps their modules to default activation.
- Edge case: activation config missing required evidence or checks blocks only the affected family.
- Integration: Gateway capabilities report the expanded family defaults without regressing existing activated families.

**Verification:**
- Default runtime activation reports `full_debate_package`, `worker_execution`, and `runtime_domain_knowledge` as active families.
- Gateway module defaulting no longer requires explicit `allow_staged=True` for the three target families.

### U2. Cut over the Debate Engine default runtime path

**Goal:** Switch debate runtime behavior from staged-only full package consumption to active default-path consumption while preserving full debate evidence and audit behavior.

**Requirements:** R1, R2, R7

**Dependencies:** U1

**Files:**
- Modify: `config/debate/full/teams.json`
- Modify: `config/debate/full/modes.json`
- Modify: `config/debate/full/coverage-policy.json`
- Modify: `config/debate/full/assembly-policy.json`
- Modify: `config/debate/full/backend-policy.json`
- Modify: `scripts/lib/debate_engine.py`
- Modify: `scripts/lib/debate_assembly.py`
- Modify: `scripts/lib/debate_member_invocation.py`
- Modify: `scripts/lib/debate_report.py`
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/tests/test-debate-assembly.sh`
- Modify: `scripts/tests/test-debate-member-invocation.sh`
- Modify: `scripts/tests/test-debate-engine-ai.sh`
- Modify: `scripts/tests/test-e2e-ai-debate-flow.sh`

**Approach:**
- Promote the full debate package config from staged to active status and keep legacy config as compatibility data rather than runtime authority.
- Remove default-path dependence on explicit staged overrides for registry loading, dynamic assembly, backend selection, member invocation, report generation, and audit writing.
- Add runtime-path tests that prove degraded member failures remain warning/degraded evidence rather than silently satisfying required coverage.

**Execution note:** Start with a failing end-to-end/default-runtime debate test, then make the minimal config/runtime changes needed to pass before expanding degraded-evidence coverage.

**Test scenarios:**
- Happy path: default runtime creates a debate run, selects members through full assembly policy, executes opinions, and builds report plus audit trail without staged override.
- Edge case: partial member failure still records degradation and missing evidence while preserving audit lineage.
- Error path: inactive or malformed debate config still blocks runtime when activation or config validity is broken.
- Integration: Gateway debate module endpoints and e2e debate flow use active full debate config on the normal path.

**Verification:**
- Debate runtime tests pass with default runtime behavior and without explicit `allow_staged=True` for normal success cases.
- Debate report and audit artifacts preserve member/opinion/backend/degradation evidence on the default path.

### U3. Cut over worker registry and capability negotiation to the default runtime

**Goal:** Make the full worker backend/role registries and explicit capability negotiation the default runtime path for worker selection.

**Requirements:** R3, R4, R7

**Dependencies:** U1

**Files:**
- Modify: `config/workers/full/backends.json`
- Modify: `config/workers/full/roles.json`
- Modify: `scripts/lib/worker_registry.py`
- Modify: `scripts/lib/capability_negotiation.py`
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/tests/test-worker-registry.sh`
- Modify: `scripts/tests/test-gateway-worker-registry.sh`
- Modify: `scripts/tests/test-gateway-integration-points.sh`

**Approach:**
- Promote the full worker registries from staged to active and keep silent backend substitution blocked by the existing capability negotiation contract.
- Shift default Gateway worker selection to the full registry and negotiation path while preserving explicit fallback rules and negotiation reports.
- Add default-runtime regression tests that fail if worker selection can still bypass the full registry or silently substitute a backend.

**Execution note:** Use a red test that calls the default worker-selection path without staged override and expects a schema-valid negotiation report plus selection record.

**Test scenarios:**
- Happy path: worker registry loads active full backends and roles, then selects the preferred backend through explicit negotiation.
- Edge case: requested backend unavailable triggers only explicit fallback candidates allowed by policy.
- Error path: missing capabilities or forbidden fallback conditions block selection and emit a blocked negotiation report.
- Integration: Gateway worker registry and negotiation endpoints use the active full path by default.

**Verification:**
- Default runtime worker selection no longer depends on legacy worker registries or caller-side staged overrides.
- Capability negotiation still records checked backends, fallback reasoning, and blocked decisions on the default path.

### U4. Integrate worker session lifecycle and parallel execution on the default runtime path

**Goal:** Route worker session records, cleanup, parallel planning, and conflict handling through the default runtime path and prove the Gateway consumes them in real runs.

**Requirements:** R4, R7

**Dependencies:** U3

**Files:**
- Modify: `scripts/lib/worker_session.py`
- Modify: `scripts/lib/worker_session_sweeper.py`
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/tests/test-worker-session.sh`
- Modify: `scripts/tests/test-worker-lifecycle-timeout.sh`
- Modify: `scripts/tests/test-e2e-ai-worker-flow.sh`
- Modify: `scripts/tests/test-gateway-worker-output-write-scope-violation.sh`
- Modify: `scripts/tests/test-gateway-worker-output-complete-task.sh`
- Modify: `scripts/tests/test-gateway-capabilities-authority-layers.sh`

**Approach:**
- Connect the active worker-selection path to session creation, session transition, cleanup ownership, and worker-output gating inside real Gateway run flows.
- Add or extend tests for parallel-group planning, conflict handling, timeout cleanup, and write-scope enforcement so the runtime path proves lifecycle correctness rather than isolated artifact validity.
- Keep Gateway as the owner of cleanup and integration sequencing to preserve authority boundaries and serial merge behavior.

**Execution note:** Drive implementation from failing run-level tests that create worker sessions through the Gateway path, not just isolated library tests.

**Test scenarios:**
- Happy path: Gateway creates a worker session, records lifecycle transitions, and accepts a valid worker output on the default path.
- Edge case: timed-out or abandoned sessions are swept and cleaned up without leaving active-session ambiguity.
- Error path: write-scope or artifact-ref violations block worker output acceptance.
- Integration: parallel or multi-worker flow produces conflict/merge evidence and keeps cleanup ownership in Gateway.

**Verification:**
- Worker session lifecycle and output gating tests pass through default runtime behavior.
- Parallel integration and cleanup behavior are covered by real-path Gateway tests instead of staged-only fixtures.

### U5. Activate gbrain-backed runtime knowledge on the default runtime path

**Goal:** Enable runtime knowledge retrieval and ingestion as active runtime behavior with enforced freshness, provenance, redaction, and degraded warning-context boundaries.

**Requirements:** R5, R6, R7

**Dependencies:** U1

**Files:**
- Modify: `config/knowledge/runtime-kb.json`
- Modify: `scripts/lib/runtime_knowledge.py`
- Modify: `scripts/lib/knowledge_ingestion.py`
- Modify: `scripts/lib/orch_gateway.py`
- Modify: `scripts/tests/test-runtime-knowledge.sh`
- Modify: `scripts/tests/test-gateway-integration-points.sh`
- Modify: `scripts/tests/test-gateway-global-evaluation-warnings.sh`
- Modify: `scripts/tests/test-gateway-mvp-real-acceptance-boundary.sh`

**Approach:**
- Flip runtime knowledge config and backend enablement from staged/disabled to active while keeping the existing evidence-boundary contract intact.
- Make Gateway runtime flows consume runtime knowledge query/ingestion on the default path and continue to mark expired, candidate-only, or backend-degraded results as warning context rather than strong evidence.
- Extend tests to cover real gbrain-available and degraded-state fallback behavior without treating degraded retrieval as completion evidence.

**Execution note:** Begin with a failing default-path runtime-knowledge query test, then activate config and wiring incrementally while preserving degraded-boundary assertions.

**Test scenarios:**
- Happy path: default runtime query returns gbrain-backed result artifacts with freshness/provenance metadata.
- Edge case: expired or candidate-only knowledge remains warning context and is excluded from strong implementation evidence.
- Error path: gbrain unavailable falls back to degraded state storage and emits degraded refs plus recovery options.
- Integration: Gateway runtime flow and closeout/global-evaluation boundaries refuse to over-credit runtime knowledge when policy disallows it.

**Verification:**
- Runtime knowledge and ingestion tests pass on the default runtime path without staged override.
- Freshness, provenance, redaction, and human-approval boundaries remain enforced after activation.

### U6. Re-baseline validation, matrices, and completion reporting

**Goal:** Update the project’s authoritative validation and documentation artifacts so they match the new active runtime reality and capture remaining risk.

**Requirements:** R7, R8

**Dependencies:** U2, U4, U5

**Files:**
- Modify: `IMPLEMENTATION-GAP-ANALYSIS.md`
- Modify: `docs/FULL-COVERAGE-MATRIX.md`
- Modify: `docs/execution-checklist.md`
- Create: `docs/full-system-cutover-debate-worker-runtime-knowledge-report.md`
- Modify: `scripts/tests/test-gateway-config-registries.sh`
- Modify: `scripts/tests/test-runtime-activation.sh`

**Approach:**
- Re-run the contract/runtime activation validation perspective and update matrices so the three target families are no longer marked staged, disabled, or not active runtime.
- Write a stage completion report that records debate, worker, and runtime-knowledge cutover evidence plus explicit residual risks.
- Keep documentation updates tied to the final verified runtime behavior, not speculative target state.

**Execution note:** Treat docs and matrix updates as the last green step after runtime-path tests pass; do not pre-mark coverage as complete.

**Test scenarios:**
- Happy path: validation and matrix tests reflect the active runtime state and reference the correct authoritative config paths.
- Edge case: documentation assertions fail if any target family is still described as staged/disabled after cutover.
- Integration: completion report cites the same evidence family names and runtime behavior proved by tests.

**Verification:**
- Gap analysis and full coverage matrix align with runtime activation, config status, and passing real-path tests.
- A completion report exists with debate, worker, runtime-knowledge evidence and residual-risk sections.

---

## System-Wide Impact

- **Interaction graph:** Runtime activation, Gateway module defaulting, debate orchestration, worker negotiation/session flow, and runtime-knowledge retrieval all converge in `scripts/lib/orch_gateway.py`.
- **Error propagation:** Activation or config-invalid failures must remain explicit and family-scoped rather than silently falling back to legacy paths.
- **State lifecycle risks:** New active runtime paths write more authoritative debate, worker, and knowledge artifacts, so degraded and rollback signals must stay auditable.
- **API surface parity:** Existing Gateway module endpoints should keep their current request/response contract; the change is default runtime behavior, not endpoint proliferation.
- **Integration coverage:** Run-level tests are required to prove cutover, because unit tests alone cannot establish default-path consumption.
- **Unchanged invariants:** Debate output is still decision input, worker fallback remains explicit-only, runtime knowledge is not final authority, and human/Kimi approval boundaries remain intact.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Family activation may accidentally over-activate unrelated modules | Keep activation mapping explicit in `runtime_activation.py` and assert family-scoped behavior in `test-runtime-activation.sh`. |
| Debate/worker/runtime-knowledge tests may still implicitly rely on staged flags | Add failing default-path tests first and remove unnecessary staged overrides only after green coverage exists. |
| Runtime knowledge activation may create false confidence from degraded backend fallback | Preserve warning-context degradation and assert that degraded knowledge cannot satisfy strong completion evidence. |
| Documentation could drift from actual runtime behavior again | Make matrix, gap-analysis, and completion-report updates the final unit gated by passing runtime-path tests. |

---

## Documentation / Operational Notes

- The implementation must follow the goal’s required execution posture: red -> green -> refactor with one vertical slice at a time.
- Activation decisions added to `runtime-family-activation.json` should point to repository knowledge records under `.workflow/knowledge/decisions/`.
- The completion report should be usable as the handoff artifact for the next cutover stage.

---

## Sources & References

- **Origin document:** `.planning/goals/full-system-cutover/02-goal-debate-worker-knowledge.md`
- Related docs: `IMPLEMENTATION-GAP-ANALYSIS.md`
- Related docs: `docs/FULL-COVERAGE-MATRIX.md`
- Related docs: `docs/gateway-integration-architecture.md`
- Related specs: `.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md`
- Related schemas: `.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md`
