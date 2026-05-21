# Full-System Cutover Spec for Debate, Worker Execution, and Runtime Knowledge

## Overview

This sprint package delivers the active runtime cutover for three Hermes Orchestra capability families: the Full Debate Package, Worker Execution, and the Runtime Domain Knowledge Base. The target state is that default Gateway runtime behavior consumes the full-path configs, contracts, and runtime integrations without requiring caller-side `allow_staged=True`.

## Functional Requirements

### FR-1: Runtime-family activation for the three target families
- **Description**: The mixed-family cutover substrate must activate `full_debate_package`, `worker_execution`, and `runtime_domain_knowledge`, and expose them as default runtime families for their related modules.
- **Acceptance Criteria**: `runtime-family-activation.json` includes the three families; `RuntimeActivation.summary()` reports them active; Gateway capabilities expose the expanded module defaults.
- **Priority**: P0

### FR-2: Debate full package becomes default runtime authority
- **Description**: Debate runtime must load `config/debate/full/*` on the normal runtime path and treat legacy debate configs as compatibility-only data rather than default authority.
- **Acceptance Criteria**: Debate registry loading, dynamic assembly, backend selection, member invocation, and debate report/audit generation succeed on the default path without explicit staged override.
- **Priority**: P0

### FR-3: Debate degraded evidence remains bounded
- **Description**: Partial member invocation failures or degraded debate backends must remain audit-visible and must not silently satisfy required debate coverage.
- **Acceptance Criteria**: Debate runtime writes degraded or partial evidence markers, preserves failed-member lineage, and blocks strong completion evidence when policy requires complete coverage.
- **Priority**: P0

### FR-4: Full worker registries and capability negotiation become default runtime behavior
- **Description**: Worker backend and role selection must use `config/workers/full/*` and explicit capability negotiation on the normal runtime path.
- **Acceptance Criteria**: Worker registry and capability negotiation work without `allow_staged=True`; negotiation reports preserve checked backends, fallback reasoning, and blocked decisions.
- **Priority**: P0

### FR-5: Worker session lifecycle and parallel integration run through Gateway
- **Description**: Gateway-owned worker session creation, transition, timeout cleanup, write-scope enforcement, and parallel/conflict handling must execute on the full runtime path.
- **Acceptance Criteria**: Real-path worker tests cover session records, output gating, sweeper cleanup, and multi-worker conflict behavior using the default runtime path.
- **Priority**: P0

### FR-6: Runtime knowledge becomes active gbrain-backed runtime behavior
- **Description**: `config/knowledge/runtime-kb.json` and the gbrain-backed ingestion/query path must be enabled as default runtime behavior.
- **Acceptance Criteria**: Runtime knowledge query and ingestion succeed without staged override, use gbrain as the storage authority, and emit schema-valid query/result artifacts.
- **Priority**: P0

### FR-7: Runtime knowledge authority boundaries remain enforced
- **Description**: Freshness, provenance, redaction, degraded-warning-context handling, and human/Kimi authority boundaries must remain intact after activation.
- **Acceptance Criteria**: Expired or candidate-only knowledge stays warning context; degraded gbrain fallback cannot become strong completion evidence; redaction and approval constraints remain enforced in runtime tests.
- **Priority**: P0

### FR-8: Authoritative docs and matrices are re-baselined to active runtime state
- **Description**: The project’s gap analysis, coverage matrix, execution checklist, and a stage completion report must be updated to match the verified active runtime behavior.
- **Acceptance Criteria**: Debate, worker execution, and runtime knowledge are no longer marked staged, disabled, or not-active-runtime in the authoritative docs once tests pass.
- **Priority**: P1

## Non-Functional Requirements

- **Performance**: The cutover must preserve existing runtime-command responsiveness and avoid adding extra blocking orchestration steps beyond the required family activation, debate fan-out, worker negotiation, and runtime-knowledge retrieval calls.
- **Security**: Debate evidence, worker selection, and runtime knowledge retrieval must preserve authority boundaries, explicit fallback rules, write-scope enforcement, and redaction of secrets/tokens/internal sensitive data.
- **Compatibility**: Mixed-family cutover behavior must remain intact; unrelated families such as release pipeline and remote decisions must not become active by accident.
- **Auditability**: Debate reports, debate audit trails, worker selection/session artifacts, and runtime knowledge query/result artifacts must stay schema-valid and traceable on the default runtime path.

## Interface Contracts

### Gateway module endpoints in scope

| Method | Path | Description |
|------|------|------|
| POST | `/orchestra/modules/debate-engine/load-registries` | Load full debate registries on the default runtime path. |
| POST | `/orchestra/modules/debate-engine/create-run` | Create a debate run using the active full debate package. |
| POST | `/orchestra/modules/debate-assembly/select-for-stage` | Apply deterministic debate assembly policy on the active path. |
| POST | `/orchestra/modules/debate-member-invocation/execute` | Execute member opinions and produce debate report/audit artifacts. |
| POST | `/orchestra/modules/worker-registry/load-backends` | Load active full worker backends. |
| POST | `/orchestra/modules/worker-registry/load-roles` | Load active full worker roles. |
| POST | `/orchestra/modules/capability-negotiation/negotiate` | Select worker backends through explicit negotiation. |
| POST | `/orchestra/modules/worker-session/create-session` | Create a Gateway-owned worker session record. |
| POST | `/orchestra/modules/worker-session/transition` | Transition the session lifecycle on the active runtime path. |
| POST | `/orchestra/modules/worker-session-sweeper/sweep-directory` | Sweep timed-out or stale worker sessions. |
| POST | `/orchestra/modules/runtime-knowledge/query` | Query gbrain-backed runtime knowledge through the active runtime path. |
| POST | `/orchestra/modules/knowledge-ingestion/ingest` | Ingest runtime knowledge entries into the active gbrain-backed path. |

### Data models in scope

| Entity | Fields | Type | Constraints |
|------|------|------|------|
| Runtime family activation | `activated_families`, `decision_ref`, `completed_checks` | JSON config | Must satisfy `full_contract_readiness_gate_policy` and family-scoped evidence rules. |
| Debate package configs | `package_status`, team/mode/policy fields | JSON config | Must move from staged-only consumption to active runtime authority. |
| Worker registries | `package_status`, backend/role entries | JSON config | Must remain schema-valid, explicit-fallback-only, and full-path authoritative. |
| Worker session record | `session_id`, `status`, `workspace_ref`, `write_scope_ref`, cleanup fields | Artifact JSON | Must stay schema-valid and Gateway-owned across lifecycle transitions. |
| Capability negotiation report | `requested_backend`, `checked_backends`, `fallback_selected`, `decision_required` | Artifact JSON | Must record explicit negotiation outcomes with no silent substitution. |
| Runtime knowledge config | `enabled`, `backend`, `retrieval_policy`, `freshness_policy`, `evidence_boundary` | JSON config | Must enable gbrain-backed runtime behavior without relaxing authority boundaries. |
| Runtime knowledge result | `freshness_status`, `degradation_record`, `result_refs`, `source_refs` | Artifact JSON | Must preserve warning-context degradation, provenance, and no-final-authority constraints. |

## Scope Boundaries

### Included
- Debate family activation and default-path runtime wiring.
- Worker registry, negotiation, session lifecycle, and parallel integration default-path wiring.
- Runtime knowledge config activation, gbrain integration, and degraded-boundary enforcement.
- TDD-driven runtime-path tests that prove these families no longer depend on staged overrides.
- Documentation and matrix updates tied to the verified cutover evidence.

### Not Included
- Release pipeline active-runtime cutover.
- Remote decision transport cutover.
- New public Gateway endpoints outside the already-defined module surface.
- Schema redesign beyond what is necessary to honor the current full contract and cutover policy.

## Risks and Dependencies

| Risk | Impact | Mitigation |
|------|------|----------|
| Family activation overreaches into unrelated modules | Unexpected runtime behavior change | Keep module-to-family mapping explicit and assert family-scoped activation in runtime activation tests. |
| Existing tests still pass only because of hidden staged overrides | False-positive cutover confidence | Add or convert tests to default-path behavior first, then remove staged-only assumptions. |
| gbrain degraded fallback gets mistaken for strong runtime evidence | Incorrect completion decisions | Preserve warning-context degradation and assert evidence-boundary behavior in Gateway/runtime-knowledge tests. |
| Documentation is updated ahead of runtime truth | Contract drift | Gate doc updates on passing runtime-path tests and final validation results. |

