# Hermes Orchestra Execution Checklist

Source plan: `/home/stark/.claude/plans/plan-sprint-sprint-1-curried-scone.md`

This checklist is derived from the full Hermes Orchestra plan dated 2026-05-18. It is an execution and verification guide only; it does not contain implementation code.

Last updated: 2026-05-18 — Added threat model, Gateway auth, and debate artifact secret leakage verification conditions.

## Global Gates

- [x] Complete Sprint 0 before starting any implementation sprint.
- [x] Use Shell-based tests (`scripts/tests/*.sh`) and `scripts/tests/lib/assert.sh`, matching the existing test strategy.
- [ ] Include negative tests in every sprint: nil/empty input, malformed configuration, and explicit failure paths.
- [x] Every new module must check `enabled` / `package_status`; inactive modules must return no-op or a clear error.
- [x] Verify Python 3.10+ and `jsonschema` availability before relying on schema validation.
- [ ] Do not treat contract fixtures or runtime fake adapters as completion evidence unless the degradation policy explicitly allows it.
- [x] Use sprint-specific unit/integration command pattern: `scripts/tests/test-*.sh`.
- [x] Use contract validation command where schema instances are being checked: `python -m jsonschema config/schemas/orchestra.full.schema.json`.
- [ ] Run final verification after Sprint 10: `scripts/tests/run-all.sh`, `scripts/bin/orch-full-contract-validate`, and `scripts/tests/test-mvp-acceptance.sh`.
- [ ] Verify threat model documents trust boundaries, threats, and mitigations (see plan Threat Model section).

## Sprint 0: Gateway Integration Architecture

Dependencies on previous sprints:

- [x] None. This sprint is the prerequisite for every later sprint.

> **Note:** This checklist treats Sprint 0 as a universal prerequisite for all sprints, intentionally strengthening the dependency declarations beyond the source plan's per-sprint entries. Kimi-to-Gateway authentication relies on localhost binding as the sole trust boundary. If the Gateway is ever exposed to a non-loopback interface, an additional authentication layer will be required.

Exact files to create:

- [x] `docs/gateway-integration-architecture.md`
- [x] `scripts/tests/test-gateway-integration-points.sh`

Verify-only files:

- [x] `scripts/lib/orch_gateway.py` (analyze only; do not modify in this sprint)
- [x] `config/debate/teams.json`
- [x] `config/debate/modes.json`
- [x] `config/workers/backends.json`
- [x] `config/workers/roles.json`
- [x] `config/debate/full/teams.json`
- [x] `config/debate/full/modes.json`
- [x] `config/workers/full/backends.json`
- [x] `config/workers/full/roles.json`
- [x] `config/cutover/full-readiness-gates.json`

Verification commands:

- [x] `scripts/tests/test-gateway-integration-points.sh`

Blocked stop conditions:

- [x] Stop if `scripts/lib/orch_gateway.py` integration points are not documented.
- [x] Stop if the architecture document does not define the integration mode for new modules.
- [x] Stop if Python API interfaces, class names, key methods, or signatures are missing for planned modules.
- [x] Stop if MVP vs full configuration routing is undefined.
- [x] Stop if `enabled` / `package_status` feature-flag behavior is undefined.
- [x] Stop if Gateway bind address policy is undefined (localhost-only default).
- [ ] Stop if Gateway accepts --host values not matching 127.0.0.1 or localhost without explicit --allow-network-binding flag.
- [x] Stop if MVP configuration paths do not exist on disk (`config/debate/teams.json`, `config/debate/modes.json`, `config/workers/backends.json`, `config/workers/roles.json`).
- [x] Stop if Full-target configuration paths do not exist on disk (`config/debate/full/teams.json`, `config/debate/full/modes.json`, `config/workers/full/backends.json`, `config/workers/full/roles.json`).
- [x] Stop if `config/cutover/full-readiness-gates.json` does not exist on disk.
- [x] Stop if the test suite does not include negative tests for feature-flag behavior (`enabled=false` returning `module_disabled`, `package_status="staged"` returning `package_not_active`).
- [x] Stop if API method signatures are validated only at the class-name level (must verify each public method with its signature is present in the architecture document).
- [x] Stop if documented `orch_gateway.py` integration points (`capabilities`, `config_items`, `validate_worker_pairing`) do not match actual method signatures in the source.
- [x] Stop if `scripts/tests/test-gateway-integration-points.sh` fails.

## Sprint 1: Debate Engine Foundation

Dependencies on previous sprints:

- [x] Sprint 0 must be complete and verified.
- [x] No additional sprint dependency is listed in the sprint section.

Exact files to create:

- [x] `scripts/lib/debate_engine.py`
- [x] `scripts/tests/test-debate-engine.sh`

Verify-only files:

- [x] `config/debate/full/teams.json`
- [x] `config/debate/full/modes.json`

Verification commands:

- [x] `scripts/tests/test-debate-engine.sh`

Blocked stop conditions:

- [x] Stop if `teams.json` does not contain the 16 canonical teams.
- [x] Stop if any team has fewer than 3 members.
- [x] Stop if `modes.json` does not contain the 8 canonical modes.
- [x] Stop if empty registries or malformed configuration do not return clear errors.
- [x] Stop if feature flags do not block inactive modules.
- [x] Stop if configuration schema validation fails.
- [ ] Stop if debate question or metadata fields have no maximum length constraints.
- [x] Stop if `scripts/tests/test-debate-engine.sh` fails.

## Sprint 2: Debate Coverage and Assembly Policy

Dependencies on previous sprints:

- [x] Sprint 0 must be complete and verified.
- [x] Sprint 1 must be complete and verified.

Exact files to create:

- [x] `scripts/lib/debate_assembly.py`
- [x] `scripts/tests/test-debate-assembly.sh`

Verify-only files:

- [x] `config/debate/full/coverage-policy.json`
- [x] `config/debate/full/assembly-policy.json`

Verification commands:

- [x] `scripts/tests/test-debate-assembly.sh`

Blocked stop conditions:

- [x] Stop if coverage policy minimum requirements are missing or invalid.
- [x] Stop if assembly policy cannot select teams by phase.
- [x] Stop if task-type overlays do not add relevant teams.
- [x] Stop if risk overlays do not add security, compliance, or observability teams.
- [x] Stop if member scoring or selection is not deterministic.
- [x] Stop if the debate audit trail does not record assembly decisions.
- [x] Stop if assembly decisions are not reproducible.
- [x] Stop if `scripts/tests/test-debate-assembly.sh` fails.

## Sprint 3: Debate Member Invocation and Backend Adapter

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 2 must be complete and verified.

Exact files to create:

- [ ] `scripts/lib/debate_member_invocation.py`
- [ ] `scripts/lib/debate_backend_adapter.py`
- [ ] `scripts/lib/debate_report.py`
- [ ] `scripts/tests/test-debate-member-invocation.sh`

Verify-only files:

- [ ] `config/debate/full/backend-policy.json`

Verification commands:

- [ ] `scripts/tests/test-debate-member-invocation.sh`

Blocked stop conditions:

- [ ] Stop if invocation envelopes omit required fields.
- [ ] Stop if the backend adapter protocol cannot accept an invocation envelope and return an opinion.
- [ ] Stop if the template fallback adapter is not marked as degraded.
- [ ] Stop if member opinions do not match the expected schema.
- [ ] Stop if debate reports omit member opinions.
- [ ] Stop if audit tracking does not record all invocations.
- [ ] Stop if debate report schema validation fails.
- [ ] Stop if `raw_prompt_persistence_allowed: false` is not enforced.
- [ ] Stop if `scripts/tests/test-debate-member-invocation.sh` fails.

## Sprint 4: Worker Registry and Capability Negotiation

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 3 must be complete and verified (derived from sequencing diagram).

Exact files to create:

- [ ] `scripts/lib/worker_registry.py`
- [ ] `scripts/lib/capability_negotiation.py`
- [ ] `scripts/tests/test-worker-registry.sh`

Verify-only files:

- [ ] `config/workers/full/backends.json`
- [ ] `config/workers/full/roles.json`

Verification commands:

- [ ] `scripts/tests/test-worker-registry.sh`

Blocked stop conditions:

- [ ] Stop if backend registry required fields are missing.
- [ ] Stop if role registry required fields are missing.
- [ ] Stop if backend availability, role compatibility, or capability requirements are not checked.
- [ ] Stop if capability negotiation can silently substitute another backend.
- [ ] Stop if the negotiation report does not record the decision process.
- [ ] Stop if the negotiation report schema validation fails.
- [ ] Stop if `scripts/tests/test-worker-registry.sh` fails.

## Sprint 5: Worker Session Lifecycle

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 4 must be complete and verified.

Exact files to create:

- [ ] `scripts/lib/worker_session.py`
- [ ] `scripts/lib/worker_session_sweeper.py`
- [ ] `scripts/tests/test-worker-session.sh`

Verify-only files:

- [ ] None listed in the sprint plan.

Verification commands:

- [ ] `scripts/tests/test-worker-session.sh`

Blocked stop conditions:

- [ ] Stop if lifecycle state transitions are incomplete or invalid.
- [ ] Stop if session records omit required fields.
- [ ] Stop if cleanup ownership is not Gateway.
- [ ] Stop if timeout handling is missing or unclear.
- [ ] Stop if the sweeper cannot detect and clean timed-out sessions.
- [ ] Stop if the sweeper cannot detect and clean missing sessions.
- [ ] Stop if session isolation is missing: unique unpredictable names, per-session tmux socket or `-L`, and 0700 workspace permissions.
- [ ] Stop if session record schema validation fails.
- [ ] Stop if `scripts/tests/test-worker-session.sh` fails.

## Sprint 6: Release Pipeline

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 5 must be complete and verified (derived from sequencing diagram). Sprint 6 and Sprint 7 may run in parallel.

Exact files to create:

- [ ] `scripts/lib/release_pipeline.py`
- [ ] `scripts/lib/release_executor.py`
- [ ] `scripts/tests/test-release-pipeline.sh`

Verify-only files:

- [ ] `config/release/pipeline.json`
- [ ] `config/release/commands.json`

Verification commands:

- [ ] `scripts/tests/test-release-pipeline.sh`

Blocked stop conditions:

- [ ] Stop if release pipeline or command registry required fields are missing.
- [ ] Stop if command references are not resolved through the trusted registry.
- [ ] Stop if unregistered commands can execute.
- [ ] Stop if command reference validation does not block injection or path traversal.
- [ ] Stop if environment variables are not filtered to `PATH`, `HOME`, `CI`, and `HERMES_RELEASE_ENV`.
- [ ] Stop if output redaction does not remove sensitive data before storage.
- [ ] Stop if release pipeline output is not scanned for secrets before storage.
- [ ] Stop if `arbitrary_shell_allowed: false` is not enforced without `shell=True`.
- [ ] Stop if approval references are not checked before process start.
- [ ] Stop if timeout or termination behavior is missing.
- [ ] Stop if deployment report schema validation fails.
- [ ] Stop if Gateway does not reject non-loopback connections by default.
- [ ] Stop if `scripts/tests/test-release-pipeline.sh` fails.

## Sprint 7: Runtime Domain Knowledge Base

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 5 must be complete and verified (derived from sequencing diagram). Sprint 6 and Sprint 7 may run in parallel.

Exact files to create:

- [ ] `scripts/lib/runtime_knowledge.py`
- [ ] `scripts/lib/knowledge_ingestion.py`
- [ ] `scripts/tests/test-runtime-knowledge.sh`

Verify-only files:

- [ ] `config/knowledge/runtime-kb.json`

Verification commands:

- [ ] `which gbrain`
- [ ] `gbrain --version`
- [ ] `scripts/tests/test-runtime-knowledge.sh`

Blocked stop conditions:

- [ ] Stop and delay Sprint 7 if `which gbrain` or `gbrain --version` fails.
- [ ] Stop if `runtime-kb.json` does not conform to the expected runtime knowledge configuration.
- [ ] Stop if gbrain CLI/MCP integration cannot create entries.
- [ ] Stop if knowledge entries or ingestion records do not match schema.
- [ ] Stop if knowledge ingestion entries are not validated against a defined schema before passing to gbrain.
- [ ] Stop if retrieval does not return contract-shaped results.
- [ ] Stop if expired entries are not marked as warning context.
- [ ] Stop if candidate knowledge can be promoted without verification.
- [ ] Stop if the gbrain-unavailable path does not write JSON under `state://knowledge/` and return degraded query results.
- [ ] Stop if `scripts/tests/test-runtime-knowledge.sh` fails.

## Sprint 8: Self Evolution Review Queue and Performance SLO

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 6 must be complete and verified (derived from sequencing diagram). Sprint 8 and Sprint 9 may run in parallel.

Exact files to create:

- [ ] `scripts/lib/self_evolution.py`
- [ ] `scripts/lib/performance_slo.py`
- [ ] `scripts/tests/test-self-evolution.sh`
- [ ] `scripts/tests/test-performance-slo.sh`

Verify-only files:

- [ ] `config/evolution/self-evolution-review-queue.json`
- [ ] `config/performance/slo-policy.json`

Verification commands:

- [ ] `scripts/tests/test-self-evolution.sh`
- [ ] `scripts/tests/test-performance-slo.sh`

Blocked stop conditions:

- [ ] Stop if self-evolution review queue configuration is invalid.
- [ ] Stop if performance SLO policy configuration is invalid.
- [ ] Stop if proposal generation does not match trigger conditions.
- [ ] Stop if review queue state transitions are incorrect.
- [ ] Stop if protected goals can be auto-applied or bypass the queue.
- [ ] Stop if protected goals do not require Kimi review and human approval.
- [ ] Stop if self-evolution proposal content is not validated against a per-target-class schema.
- [ ] Stop if component budget monitoring is missing or incorrect.
- [ ] Stop if missed budgets do not produce explicit degradation behavior.
- [ ] Stop if either Sprint 8 test command fails.

## Sprint 9: Fixture Policy and Degradation Policy

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 7 must be complete and verified (derived from sequencing diagram). Sprint 8 and Sprint 9 may run in parallel.

Exact files to create:

- [ ] `scripts/lib/fixture_policy.py`
- [ ] `scripts/lib/degradation_policy.py`
- [ ] `scripts/tests/test-fixture-policy.sh`
- [ ] `scripts/tests/test-degradation-policy.sh`

Verify-only files:

- [ ] `config/testing/full-fixture-policy.json`
- [ ] `config/degradation/policy.json`

Verification commands:

- [ ] `scripts/tests/test-fixture-policy.sh`
- [ ] `scripts/tests/test-degradation-policy.sh`

Blocked stop conditions:

- [ ] Stop if fixture policy or degradation policy configuration is invalid.
- [ ] Stop if contract fixtures can become completion evidence.
- [ ] Stop if runtime fake adapters are not marked as degraded.
- [ ] Stop if degradation state-machine transitions are incorrect.
- [ ] Stop if degradation records omit required fields.
- [ ] Stop if degraded evidence can satisfy completion evidence when policy does not allow it.
- [ ] Stop if either Sprint 9 test command fails.

## Sprint 10: Full Schema Validation and Staged Cutover

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 1 through Sprint 9 must be complete and verified.

Exact files to create:

- [ ] `scripts/lib/full_schema_validation.py`
- [ ] `scripts/lib/staged_cutover.py`
- [ ] `scripts/tests/test-full-schema-validation.sh`
- [ ] `scripts/tests/test-staged-cutover.sh`

Verify-only files:

- [ ] `config/schemas/orchestra.full.schema.json`
- [ ] `config/cutover/full-readiness-gates.json`
- [ ] `scripts/bin/orch-full-contract-validate`

Verification commands:

> **Note:** `test-full-schema-validation.sh`, `test-staged-cutover.sh`, and `run-all.sh` are sourced from the origin plan's Final Verification section. `orch-full-contract-validate` and `test-mvp-acceptance.sh` are from the origin plan's Sprint 10 Verification section.

- [ ] `scripts/tests/test-full-schema-validation.sh`
- [ ] `scripts/tests/test-staged-cutover.sh`
- [ ] `scripts/bin/orch-full-contract-validate`
- [ ] `scripts/tests/run-all.sh`
- [ ] `scripts/tests/test-mvp-acceptance.sh`

Blocked stop conditions:

- [ ] Stop if `orchestra.full.schema.json` is not a valid Draft 2020-12 schema.
- [ ] Stop if full debate package configuration does not validate.
- [ ] Stop if full worker registry configuration does not validate.
- [ ] Stop if cutover readiness gates are incomplete or invalid.
- [ ] Stop if artifact-family cutover gate requirements are incomplete.
- [ ] Stop if historical runs do not preserve their original schema version.
- [ ] Stop if new runs can write full artifacts before their artifact family passes gates.
- [ ] Stop if rollback or disable plans are missing.
- [ ] Stop if either Sprint 10 test command fails.
- [ ] Stop if `scripts/bin/orch-full-contract-validate` fails.
- [ ] Stop if final integration or MVP acceptance tests fail.

## Sprint 11: Gateway Integration

Dependencies on previous sprints:

- [ ] Sprint 0 must be complete and verified.
- [ ] Sprint 1 through Sprint 10 must be complete and verified.

Exact files to create:

- [ ] None. This sprint modifies existing files only.

Files to modify:

- [ ] `scripts/lib/orch_gateway.py`

Objective:

Wire the 18+ new module classes from Sprint 1-10 into Gateway HTTP endpoints so they are callable from the JSON Run Projection API.

Blocked stop conditions:

- [ ] Stop if any Sprint 1-10 module class is not accessible via a Gateway endpoint.
- [ ] Stop if endpoint routes are not defined for new module methods.
- [ ] Stop if request/response shapes are not specified for new endpoints.
- [ ] Stop if authority rules for new endpoints are not defined.
- [ ] Stop if `scripts/tests/test-gateway-integration-points.sh` does not cover new endpoints.
- [ ] Stop if Gateway rejects requests to new endpoints.

## Plan Validation Checklist

- [x] The checklist covers 12 sprints: Sprint 0 plus Sprint 1 through Sprint 11.
- [x] Every file marked `(新建)` in the source plan appears under an "Exact files to create" section: 34 files checked.
- [x] Every file marked `(已存在，需要验证)` or `(分析，不修改)` in the source plan appears under a "Verify-only files" section: 18 files checked.
- [x] Every exact verification command named in the source plan appears under "Verification commands" or "Global Gates": 21 commands checked.
- [x] Dependencies reflect per-sprint entries and note sequencing-diagram ordering as advisory where the plan's sprint section does not declare a direct dependency. Sprint 0 is treated as a universal prerequisite in this checklist, overriding the origin plan's per-sprint dependency declarations.
- [x] Blocked stop conditions include plan-specific gates, negative/security tests, schema/config validation, and failed verification commands.
- [x] Blocked stop conditions include threat model verification (trust boundaries, threats, mitigations).
- [x] Blocked stop conditions include Gateway auth verification (localhost-only default).
- [x] Blocked stop conditions include debate artifact secret leakage verification.
- [x] This document does not add implementation code or create implementation files.
