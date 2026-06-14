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
| **Cross-Sprint Contract 1: conflict_ledger** | `state://runs/{run_id}/conflict-ledger.json` (full schema `conflict_record`) | ready | partially implemented (Sprint 1) | Producer: Sprint 1 (`plan-sprint-1.md` U1, 5 SP). Consumers: Sprints 2, 10, 13. Schema: 4 top-level + 11 conflict item fields; enums: `type` (intent_vs_inference/fact_vs_assumption/cross_team_conflict/dependency_conflict/user_override), `severity` (high/medium/low), `resolution` (open/auto_resolved/accepted_risk/manual_resolved/superseded). Closeout must read every conflict record before marking run closed (FR-1). See `gateway-integration-architecture.md ## Cross-Sprint Contract Surfaces ## Contract 1`. |
| **Cross-Sprint Contract 2: run.lifecycle_status + transition guard** | Full schema `run.lifecycle_status` + `transition_guard` API | ready | partially implemented (Sprint 2) | Producer: Sprint 2 (`plan-sprint-2.md`, 5 SP). Consumers: Sprints 3, 4, 7, 8, 10. 13 allowed values: `created, intake_complete, direction_debate, solution_debate, implementation, improvement, global_evaluation, continuous_improvement, closed, paused, blocked, cancelled, rollback_requested`. Illegal transitions fail-closed via transition guard. See `gateway-integration-architecture.md ## Contract 2`. |
| **Cross-Sprint Contract 3: run.channel_decision** | Full schema `channel_decision` (9 required fields) | ready | partially implemented (Sprint 4) | Producer: Sprint 4 (`plan-sprint-4.md`, 5 SP). Consumers: Sprints 5, 6. Fields: `channel, reason, project_age_weeks, files_count, required_debate_rounds, required_evidence[], forced_standard, forced_standard_reasons[], decision_ref`. Persisted on run state; alters required debate/evidence depth (FR-4/FR-5). See `gateway-integration-architecture.md ## Contract 3`. |
| **Cross-Sprint Contract 4: authority_route + override_record** | Full schema `authority_route` + `override_record` (5 + 5 fields) | ready | partially implemented (Sprint 10/11) | Producer: Sprint 10 (`plan-sprint-10.md` U10, 5 SP). Consumer: Sprint 11 (Override approval). Fields: `authority_route, veto_dimensions[], residual_risks[], approver_ref, notification_mode`. `override_record` includes `correction_rounds[], approver_ref, status, risk_level`. list/query endpoints for pending approvals (FR-10/FR-11). See `gateway-integration-architecture.md ## Contract 4`. |
| **Cross-Sprint Contract 5: mini-debate consensus_score** | `scripts/lib/gateway_debate.py` mini-debate report | ready | partially implemented (Sprint 6/9) | Producer: Sprint 6 (`plan-sprint-6.md`, 5 SP). Consumer: Sprint 9 (E-class disputes). Threshold: `consensus_score >= 0.60` required to pass; below threshold blocks E-class improvement (FR-13). Fields: `debate_refs[], consensus_score, degraded`. See `gateway-integration-architecture.md ## Contract 5`. |
| **Cross-Sprint Contract 6: Sprint 12 → Sprint 13 gate scripts** | `scripts/tests/test-prd-remediation-schema-doc-sync.sh` + Sprint 13 final audit gate | ready | test harness (Sprint 12) | Producer: Sprint 12 (`plan-sprint-12.md` U14, 3 SP). Consumer: Sprint 13 (`plan-sprint-13.md` final audit gate). All three strict gate scripts (schema-doc-sync, success-metrics-pipeline, e2e-strict-six-stage-flow) must pass together before Sprint 13 release (FR-14). |
| Full schema contract | `.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md` | ready | not implemented | Human-readable full schema package. |
| Full machine schema | `config/schemas/orchestra.full.schema.json` | ready | not active runtime | Runs parallel to MVP schema until cutover. |
| Full contract validation tool | `scripts/bin/orch-full-contract-validate` | ready | not runtime | Validates full schema, staged full configs, release command refs, and disabled formal config state before runtime cutover. |
| Full contract readiness gate policy | `config/cutover/full-readiness-gates.json` | staged | not runtime | Artifact-family staged cutover, required evidence, historical preservation, and rollback or disable rules. |
| Runtime family activation manifest | `config/cutover/runtime-family-activation.json` | ready | mixed-family runtime active | Activates `gateway_authority` and `closeout_and_self_evolution` defaults without a global schema switch. |
| Performance SLO policy | `config/performance/slo-policy.json` | staged | not runtime | Component target budgets, measurement policy, and budget-miss degradation actions without fixed Six-Stage completion SLA. |
| PRD §11 success metrics | `config/performance/slo-policy.json` `success_metrics`, `scripts/lib/success_metrics.py` | ready | CLI gate | Fourteen success metrics map source events to aggregation rules, thresholds, and `test-success-metrics-pipeline.sh`; `orch-audit` writes `metrics_summary.json`, `orch-verify` blocks below-threshold release gates. |
| Schema/doc/Gateway sync gate | `scripts/bin/orch-schema-doc-sync`, `scripts/tests/test-schema-doc-sync.sh` | ready | CI gate | Validates Sprint 13 release gate docs against `orchestra.full.schema.json` defs and catches known Gateway field drift such as `legacy_run_status`. |
| Strict 0→6 staging regression | `scripts/lib/staging Harness.sh`, `scripts/lib/staging inject-data.sh`, `scripts/tests/test-e2e-strict-six-stage-flow.sh` | ready | test harness | Replays intake, direction, solution, implementation, improvement, global evaluation, and closeout in `.hermes/staging/`, then verifies artifacts and metrics gate output. |
| Full fixture policy | `config/testing/full-fixture-policy.json` | staged | not runtime | Separates contract fixtures from runtime fake adapters and forbids fixture evidence from satisfying authority gates. |
| Self evolution review queue policy | `config/evolution/self-evolution-review-queue.json` | staged | not runtime | Explicit queue, priority, batching, protected target, backlog, evidence, and retention policy for proposals. |
| Gateway runtime contract | `.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md` | ready | partially implemented | Baseline is current Python local HTTP Gateway with JSON Run Projection API, optional `/v1/*` proxying, and filesystem State/Audit. |
| Gateway full runtime implementation | `scripts/lib/orch_gateway.py` plus `scripts/lib/actor_auth.py` and `scripts/lib/run_projection.py` | ready | partially implemented | Sprint 7 lands Run Projection API, actor-token auth, and PRD §2.2 authority enforcement for the 8 required capabilities; run-level full artifact cutover is still incomplete. |
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
| PRD §2.2 authority matrix | `config/decisions/authority-matrix.json` | ready | active/current | Covers `create_run`, `hydrate_requirements`, `mutate_kanban_raw_state`, `advance_stage`, `select_debate_teams`, `code_or_review`, `approve_l3_l4`, and `apply_self_evolution`. |
| Runtime Domain Knowledge Base config | `config/knowledge/runtime-kb.json` | ready | deferred / not runtime | Deferred during Sprint 14 supplement; active runtime does not connect gbrain. |
| Runtime knowledge entry contract | Full schema + `config/knowledge/runtime-kb.json` | ready | partially implemented | State-store entry pages use YAML frontmatter and required sections. |
| Runtime knowledge ingestion audit | Full schema `knowledge_ingestion_record` | ready | partially implemented | Promotion, overwrite, supersession, deprecation, and failed re-verification require records. |
| Runtime knowledge retrieval audit | Full schema `runtime_knowledge_query/result` | ready | partially implemented | Retrieval results are context, not final authority. |
| Full worker backend registry | `config/workers/full/backends.json` | staged | mixed-family default path | Explicit backend capabilities, checks, workspace/session support, risk ceiling, and fallback eligibility. |
| Worker advancement evidence gate | `scripts/lib/worker_evidence_harden.py`, `scripts/lib/orch_gateway.py:worker_advancement_evidence_violations`, `scripts/bin/orch-validate-worker-advancement` | ready | active/current (Sprint 8) | Fail-closed gate that blocks `submit_worker_output` from advancing stage when write scope, DAG, review, or commit evidence is missing. CLI exposes JSON envelope; 1MB stdin cap; exit codes 0/1/2. Wired into `orch_gateway.py:4459-4471` (P1-NEW-1 hardening wraps `read_json` in try/except). Solution notes: `docs/solutions/security/worker-advancement-evidence-gate.md`. |
| Full worker role registry | `config/workers/full/roles.json` | staged | mixed-family default path | Required capabilities, preferred backend, explicit fallbacks, allowed failure classes, and fallback-forbidden conditions. |
| Capability negotiation report | Full schema `capability_negotiation_report` | ready | partially implemented | Default Gateway worker negotiation now uses the mixed-family worker path and still records blocked-selection evidence. |
| Worker session lifecycle | Full schema `worker_session_record` | ready | partially implemented | Gateway now persists run-scoped worker session records and exercises transition plus sweeper cleanup on the default runtime path. |
| Worker parallel integration | Full schema `parallel_group_plan`, `conflict_scan`, `merge_conflict_report` | ready | partially implemented | Gateway now writes mechanical parallel-plan/conflict artifacts on the worker-output path; semantic compatibility still relies on serial integration tests and review gates. |
| Stage 4 improvement classification | `scripts/lib/gateway_improvement.py`, run `improvement_report.json`, run `decisions.json` | ready | partially implemented | A-E classification, D-class 3-cycle regression budget, E-class 2-round mini-debate escalation, and scope-violation blocking are covered by `test-gateway-review-verdict-improvement-budget.sh`, `test-gateway-review-verdict-request-changes.sh`, and `test-gateway-review-verdict-block-human-approval.sh`. |
| Stage 5 global evaluation | `scripts/lib/gateway_evaluation.py`, `config/debate/full/coverage-policy.json`, run `global_evaluation_report.json` | ready | partially implemented | Eight-dimension scoring, configurable `pass_with_warnings`, mode trigger events, notification levels, and authority routing are covered by `test-gateway-global-evaluation-pass.sh`, `test-gateway-global-evaluation-warnings.sh`, `test-gateway-global-evaluation-fail-blocks.sh`, `test-gateway-global-evaluation-block-human-approval.sh`, `test-gateway-global-evaluation-final-acceptance.sh`, and `test-gateway-global-evaluation-notification-levels.sh`. |
| Stage 6 closeout audit and self evolution | `scripts/lib/gateway_closeout.py`, `scripts/lib/self_evolution.py`, run `closeout_audit_checklist.json`, `.hermes/evolution-queue/` | ready | partially implemented | Closeout now validates complete logs, intake package, worker invocation logs, error stack, review records, and closeout artifacts before completion; protected target proposals require L3/L4 approval refs; queue records persist and recover by `run_id`, `proposal_id`, and `status`. Covered by `test-gateway-closeout-completes-run.sh`, `test-gateway-closeout-forbidden-proposal.sh`, `test-gateway-closeout-summary-alone-rejected.sh`, `test-self-evolution.sh`, and `test-full-contract-validation.sh`. |
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

## Sprint 13 Gate Coverage

Producer note: Sprint 12 (`plan-sprint-12.md` U14, 3 SP) is the producer of the 3 strict gate scripts below. Sprint 13 (`plan-sprint-13.md`) consumes their evidence in the final audit gate (Contract 6 producer→consumer handoff, FR-14). All three must pass together before Sprint 13 release decision.

| Gate | Test | Release artifact |
|---|---|---|
| Success metrics pipeline | `scripts/tests/test-success-metrics-pipeline.sh` | `metrics_summary.json` with 14 `success_metrics_summary` entries |
| Schema three-way sync | `scripts/tests/test-schema-doc-sync.sh` | `release_gate_report.schema_sync_passed` |
| Strict six-stage staging run | `scripts/tests/test-e2e-strict-six-stage-flow.sh` | `run.json`, `tasks.json`, `events.jsonl`, `audit.jsonl`, `metrics_summary.json` |
| Final release decision | `scripts/tests/test-prd-compliance-remediation-e2e.sh` (per `spec.md` FR-14 + `plan-sprint-13.md`) | `release_gate_report.release_approved` |
