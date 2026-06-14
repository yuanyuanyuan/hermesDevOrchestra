# PRD Compliance Audit Remediation Full Spec

## Source And Scope

Origin: `docs/PRD-COMPLIANCE-AUDIT-REPORT.md`, calibrated with the already executed `docs/archive/sprints/prd-compliance-audit-remediation/` Sprint 1.

This plan covers remaining gaps after the first Conflict Ledger gate slice. The prior slice already added a per-run `conflict-ledger.json` and blocks worker output advancement when `resolution=open` and `severity=high`; this full plan finishes schema, closeout, state, rollback, channel, worker, evaluation, correction, heartbeat, and audit closeout work.

Known audit calibration: the report's claim that DAG cycle detection returns `None` is not fully correct; `scripts/lib/dag_validator.py` already detects cycles. The remaining DAG work is to make Gateway consume DAG validation results as blocking advancement evidence.

## Functional Requirements

| ID | Requirement | Quantified Acceptance |
|----|-------------|-----------------------|
| FR-1 | Conflict Ledger is a first-class run artifact. | `conflict-ledger.json` validates against full schema, supports all PRD conflict fields, and closeout reads every conflict record before marking a run closed. |
| FR-2 | Run lifecycle state machine matches PRD state and transition rules. | Illegal transition tests cover at least 8 disallowed paths; all legal PRD §3.6 transitions have one positive test. |
| FR-3 | Rollback requests are executable and auditable. | Implementation and improvement rollback create `rollback_report.json`, leave unrelated commits untouched, and fail closed when baseline refs are missing. |
| FR-4 | Channel routing affects run creation and stage behavior. | Quick/Light/Standard decisions are persisted on run state and alter required debate/evidence depth in tests. |
| FR-5 | Security escape rules force Standard channel. | At least 6 sensitive/security patterns, PII patterns, and protected-target patterns route to Standard with an audit record. |
| FR-6 | Quick/Light mini-debate integrates with debate engine. | Quick/Light tasks produce bounded debate artifacts with configured round/team counts and timeout metadata. |
| FR-7 | Worker review/audit/cross_check source isolation is enforced. | `model_source` is required for relevant worker sessions; same-source sessions return `source_isolation_violation`. |
| FR-8 | Worker execution evidence is hardened. | Gateway compares computed write scope, actual changed files, DAG validation, review evidence, and commit evidence before advancement. |
| FR-9 | Intake output completeness matches PRD. | Completion bundle includes CI/CD discovery, 8-part `prompt_envelope`, verified facts, and unverified assumptions. |
| FR-10 | Global evaluation has veto and residual-risk thresholds. | Any veto dimension or high residual risk blocks closeout unless explicit authority route approval is recorded. |
| FR-11 | User correction and Override records are approval-ready. | Override records include `correction_rounds[]`, `approver_ref`, status, risk level, and list/query endpoints for pending approvals. |
| FR-12 | Heartbeat reconnect and snapshot behavior is deterministic. | Reconnect within 5 seconds returns the latest 3 heartbeat events; snapshot endpoint returns current run/task/worker state. |
| FR-13 | E-class improvement disputes use real mini-debate. | Two-round E dispute flow blocks when consensus is below 0.60 and records debate refs. |
| FR-14 | Schema/docs/success metrics remain synchronized. | Schema validation, docs sync, success metric pipeline, and strict e2e audit gate pass together before final closeout. |

## Non-Functional Requirements

- Safety: every high-risk or authority-bound path must fail closed.
- Compatibility: existing MVP endpoints remain backward compatible; new fields are additive unless the sprint plan explicitly says otherwise.
- Test posture: each implementation unit must add at least two negative tests.
- Auditability: every blocked decision must write state, event, audit, and response evidence.

## Interface Contracts

- `state://runs/{run_id}/conflict-ledger.json`: canonical conflict records.
- `state://runs/{run_id}/rollback-report.json`: rollback result and baseline/commit refs.
- `run.channel_decision`: persisted channel, reason, confidence, evidence refs, and forced-standard reasons.
- `worker_session_record.model_source`: provider/family identity for source isolation.
- `override_record`: correction rounds, risk, approver, evidence, and status.
- `global_evaluation_report.residual_risks[]`: sorted high/medium/low records with action and authority route.

## Success Metrics

| Metric | Event Source | Rule | Threshold | Verification |
|--------|--------------|------|-----------|--------------|
| conflict_gate_block_rate | `worker_output_blocked` | open high conflicts block advancement | 100% in tests | `test-gateway-conflict-ledger-closeout.sh` |
| rollback_traceability | `rollback.completed` | rollback reports include baseline and changed refs | 100% in tests | `test-gateway-rollback-strategy.sh` |
| channel_escape_accuracy | `channel_routing.standard_forced` | sensitive diffs force Standard | 100% for fixture set | `test-channel-security-escape.sh` |
| source_isolation_enforced | `worker_session.rejected` | same-source review/audit/cross_check rejected | 100% in tests | `test-worker-source-isolation.sh` |
| strict_audit_green | release gate | all required gates pass together | 100% for final fixture | `test-prd-compliance-remediation-e2e.sh` |

