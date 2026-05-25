# Hermes Orchestra Full Target Coverage Matrix

This matrix tracks full-system target readiness. It is separate from `docs/COVERAGE-MATRIX.md`, which tracks MVP/current runtime implementation coverage.

Status vocabulary:

- `ready`: target contract or config exists and is aligned with the full spec.
- `staged`: target file exists but is intentionally not the active runtime path.
- `disabled`: formal config exists but `enabled: false`.
- `pending`: target still needs authoring.
- `not implemented`: runtime capability is not yet implemented.

| Capability | Target artifact | Readiness | Runtime status | Notes |
|---|---|---:|---:|---|
| Full spec | `.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md` | ready | not implemented | Canonical full-system design entry point. |
| Full PRD | `.planning/specs/HERMES-ORCHESTRA-FULL-PRD.md` | ready | not implemented | Product requirements for implementation triage. |
| Capability authority matrix | `docs/FULL-CAPABILITY-AUTHORITY-MATRIX.md` | ready | not runtime | Actor-level request, decision, approval, execution, and state-advancement boundaries. |
| qnN4o510 synthesis | `docs/knowledge/qnN4o510-synthesis.md` | ready | not runtime | External design-source synthesis only. |
| Full schema contract | `.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md` | ready | not implemented | Human-readable full schema package. |
| Full machine schema | `config/schemas/orchestra.full.schema.json` | ready | not active runtime | Runs parallel to MVP schema until cutover. |
| Full contract validation tool | `scripts/bin/orch-full-contract-validate` | ready | not runtime | Validates full schema, staged full configs, release command refs, and disabled formal config state before runtime cutover. |
| Full contract readiness gate policy | `config/cutover/full-readiness-gates.json` | staged | not runtime | Artifact-family staged cutover, required evidence, historical preservation, and rollback or disable rules. |
| Runtime family activation manifest | `config/cutover/runtime-family-activation.json` | ready | mixed-family runtime active | Activates `gateway_authority`, `full_debate_package`, `worker_execution`, `runtime_domain_knowledge`, and `closeout_and_self_evolution` module defaults without a global schema switch. |
| Performance SLO policy | `config/performance/slo-policy.json` | staged | not runtime | Component target budgets, measurement policy, and budget-miss degradation actions without fixed Six-Stage completion SLA. |
| Full fixture policy | `config/testing/full-fixture-policy.json` | staged | not runtime | Separates contract fixtures from runtime fake adapters and forbids fixture evidence from satisfying authority gates. |
| Self evolution review queue policy | `config/evolution/self-evolution-review-queue.json` | staged | not runtime | Explicit queue, priority, batching, protected target, backlog, evidence, and retention policy for proposals. |
| Gateway runtime contract | `.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md` | ready | partially implemented | Baseline is current Python local HTTP Gateway with JSON Run Projection API, optional `/v1/*` proxying, and filesystem State/Audit. |
| Gateway full runtime implementation | `scripts/lib/orch_gateway.py` plus future full runtime work | pending | MVP/current runtime active | Current executable Gateway now has mixed-family activation substrate for debate, worker, runtime-knowledge, gateway-authority, and closeout module defaults; representative Gateway flows consume those module paths, but run-level full artifact cutover is still incomplete. |
| Idempotency record contract | Full schema `idempotency_record` | ready | partially implemented | Retained with Gateway State, no independent TTL, same payload replays original result, different payload conflicts. |
| Degradation policy | `config/degradation/policy.json` | staged | not active runtime | Defines degradation state machine, default completion-evidence denial, artifact-family exceptions, and recovery rule. |
| MVP runtime schema | `config/schemas/orchestra.schema.json` | ready | active/current | Remains MVP/current runtime schema. |
| Full debate team registry | `config/debate/full/teams.json` | staged | mixed-family default path | Sixteen qnN4o510 canonical teams with at least three members each. |
| Full debate mode registry | `config/debate/full/modes.json` | staged | mixed-family default path | Eight qnN4o510 canonical debate modes. |
| Debate coverage policy | `config/debate/full/coverage-policy.json` | staged | mixed-family default path | Required stage coverage and partial-report policy. |
| Debate assembly policy | `config/debate/full/assembly-policy.json` | staged | mixed-family default path | Deterministic stage, task-type, risk, override, and member-scoring selector. |
| Debate backend policy | `config/debate/full/backend-policy.json` | staged | mixed-family default path | Template fallback is degraded fixture only. |
| Current debate runtime config | `config/debate/teams.json`, `config/debate/modes.json` | ready | legacy-compatible | Legacy MVP runtime registries remain on disk, but representative Gateway debate flows now default through the mixed-family full package. |
| Release pipeline config | `config/release/pipeline.json` | disabled | not implemented | Formal path exists with `enabled: false`. |
| Release command registry | `config/release/commands.json` | disabled | not implemented | Trusted deploy/rollback command refs, Gateway Release Executor, approval, timeout, kill, output capture, and redaction policy. |
| Remote decision config | `config/decisions/remote-channel.json` | disabled | not implemented | Transport-only config; local CLI/SSH remains default. |
| Runtime Domain Knowledge Base config | `config/knowledge/runtime-kb.json` | ready | deferred / not runtime | Deferred during Sprint 14 supplement; active runtime does not connect gbrain. |
| Runtime knowledge entry contract | Full schema + `config/knowledge/runtime-kb.json` | ready | partially implemented | State-store entry pages use YAML frontmatter and required sections. |
| Runtime knowledge ingestion audit | Full schema `knowledge_ingestion_record` | ready | partially implemented | Promotion, overwrite, supersession, deprecation, and failed re-verification require records. |
| Runtime knowledge retrieval audit | Full schema `runtime_knowledge_query/result` | ready | partially implemented | Retrieval results are context, not final authority. |
| Full worker backend registry | `config/workers/full/backends.json` | staged | mixed-family default path | Explicit backend capabilities, checks, workspace/session support, risk ceiling, and fallback eligibility. |
| Full worker role registry | `config/workers/full/roles.json` | staged | mixed-family default path | Required capabilities, preferred backend, explicit fallbacks, allowed failure classes, and fallback-forbidden conditions. |
| Capability negotiation report | Full schema `capability_negotiation_report` | ready | partially implemented | Default Gateway worker negotiation now uses the mixed-family worker path and still records blocked-selection evidence. |
| Worker session lifecycle | Full schema `worker_session_record` | ready | partially implemented | Gateway now persists run-scoped worker session records and exercises transition plus sweeper cleanup on the default runtime path. |
| Worker parallel integration | Full schema `parallel_group_plan`, `conflict_scan`, `merge_conflict_report` | ready | partially implemented | Gateway now writes mechanical parallel-plan/conflict artifacts on the worker-output path; semantic compatibility still relies on serial integration tests and review gates. |
| Release evidence | Full schema `deployment_report` | ready | not implemented | Deployment gates, UAT, approval, command execution metadata, timeout/kill status, output refs, health checks, and rollback/recovery evidence. |
| Remote decision evidence | Full schema `decision_request/decision_response` | ready | not implemented | Gateway validates and advances; transport does not mutate state. |
| ADR: debate team ids | `docs/adr/0001-full-debate-package-team-registry.md` | ready | not runtime | qnN4o510 is canonical team id authority. |
| ADR: debate mode ids | `docs/adr/0002-full-debate-package-mode-registry.md` | ready | not runtime | qnN4o510 is canonical mode id authority. |
| ADR: full schema packaging | `docs/adr/0003-full-schema-package-parallel-to-mvp-schema.md` | ready | not runtime | Full schema runs parallel to MVP schema. |
| ADR: schema strictness | `docs/adr/0004-full-schema-guardrail-strictness.md` | ready | not runtime | Guardrail fields strict, deep content structurally typed. |
| ADR: staged debate config | `docs/adr/0005-full-debate-config-staged-beside-legacy-runtime-config.md` | ready | not runtime | Full debate config staged beside legacy runtime config. |
| ADR: disabled formal configs | `docs/adr/0006-full-optional-configs-use-disabled-formal-paths.md` | ready | not runtime | Formal optional configs exist but are disabled. |
| ADR: Gateway runtime contract | `docs/adr/0008-gateway-runtime-contract-python-local-http.md` | ready | not runtime | Full system extends current Python local HTTP Gateway instead of a stack rewrite. |
| ADR: debate assembly policy | `docs/adr/0009-dynamic-debate-assembly-policy.md` | ready | not runtime | Dynamic assembly is deterministic and auditable rather than model-selected. |
| ADR: worker capability negotiation | `docs/adr/0010-worker-capability-negotiation-explicit-fallback.md` | ready | not runtime | Worker fallback is explicit only; blocked selection records a negotiation report. |
| ADR: idempotency retention | `docs/adr/0011-idempotency-records-retained-with-gateway-state.md` | ready | not runtime | Idempotency records are Gateway State, not expiring cache entries. |
| ADR: degradation model | `docs/adr/0012-degradation-is-evidence-state-not-run-status.md` | ready | not runtime | Degradation is evidence quality state, not Run status. |
| ADR: release command execution | `docs/adr/0013-release-commands-use-gateway-executor.md` | ready | not runtime | Deploy and rollback commands resolve through a trusted registry and execute through Gateway. |
| ADR: staged full cutover | `docs/adr/0014-artifact-family-staged-cutover.md` | ready | not runtime | Full schema activation happens per artifact family, never as one global switch. |
| ADR: performance target budgets | `docs/adr/0015-performance-target-budgets-not-fixed-run-sla.md` | ready | not runtime | Full system records component budgets and degradation behavior instead of fixed run-duration SLA. |
| ADR: fixture layers | `docs/adr/0016-fixtures-split-contract-and-runtime-fakes.md` | ready | not runtime | Contract fixtures and runtime fake adapters are separate layers with strict evidence boundaries. |
| ADR: self evolution review queue | `docs/adr/0017-self-evolution-uses-explicit-review-queue.md` | ready | not runtime | Proposals enter an explicit queue with priority, batching, protected target, and retention rules. |

## Gaps Before Full Implementation Planning

- Expand mixed-family activation from module defaults to run-level full artifact consumption and validation.
- Implement the remaining run-level full runtime consumption gaps: remote decisions, release execution, deeper closeout integration, and stronger parallel merge orchestration beyond mechanical conflict artifacts.
- Add adapter implementation plans for runtime knowledge state-store adapter, release pipeline, and remote decision transport.
- Keep `qnN4o510` as design-source traceability only; do not introduce it as runtime retrieval.
