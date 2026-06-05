# PRD Compliance Audit Remediation Schema Notes

## Artifact Changes

### `conflict_ledger`

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `schema_version` | string | `orchestra.full.v1`. |
| `artifact_type` | string | `conflict_ledger` |
| `run_id` | string | Owner run. |
| `conflicts[]` | array | Items use PRD §3.5 fields. |

Conflict item required fields: `conflict_id`, `run_id`, `stage`, `type`, `sources`, `severity`, `resolution`, `resolver`, `resolution_evidence`, `created_at`, `resolved_at`.

Enums:
- `type`: `intent_vs_inference`, `fact_vs_assumption`, `cross_team_conflict`, `dependency_conflict`, `user_override`
- `severity`: `high`, `medium`, `low`
- `resolution`: `open`, `auto_resolved`, `accepted_risk`, `manual_resolved`, `superseded`

### `run.lifecycle_status`

Allowed values: `created`, `intake_complete`, `direction_debate`, `solution_debate`, `implementation`, `improvement`, `global_evaluation`, `continuous_improvement`, `closed`, `paused`, `blocked`, `cancelled`, `rollback_requested`.

Transition Guard Table:
- `created` → `intake_complete`, `cancelled`
- `intake_complete` → `direction_debate`, `cancelled`, `blocked`
- `direction_debate` → `solution_debate`, `cancelled`, `blocked`, `rollback_requested`
- `solution_debate` → `implementation`, `cancelled`, `blocked`, `rollback_requested`
- `implementation` → `improvement`, `cancelled`, `blocked`, `rollback_requested`
- `improvement` → `global_evaluation`, `cancelled`, `blocked`, `rollback_requested`
- `global_evaluation` → `continuous_improvement`, `closed`, `cancelled`, `blocked`, `rollback_requested`
- `continuous_improvement` → `closed`, `cancelled`, `blocked`, `rollback_requested`
- `closed` → (terminal)
- `paused` → `cancelled`; resume requires an explicit `resume_lifecycle_status` or `previous_lifecycle_status` active target
- `blocked` → `cancelled`; resume requires resolved blockers and an explicit `resume_lifecycle_status` or `previous_lifecycle_status` active target
- `cancelled` → (terminal)
- `rollback_requested` → `implementation`, `cancelled`, `blocked`

### `rollback_report`

Required fields: `run_id`, `request_id`, `requested_stage`, `baseline_ref`, `rollback_strategy`, `affected_refs[]`, `protected_target_check`, `result`, `created_at`, `completed_at`.

### `channel_decision`

Required fields: `channel`, `reason`, `project_age_weeks`, `files_count`, `required_debate_rounds`, `required_evidence[]`, `forced_standard`, `forced_standard_reasons[]`, `decision_ref`.

### `worker_session_record`

Additive fields:
- `model_source`: `kimi`, `claude`, `codex`, `human`, `openai`, `anthropic`, `other`
- `source_isolation_status`: `passed`, `rejected`, `degraded`
- `source_isolation_reason`

### `override_record`

Required fields: `override_id`, `run_id`, `correction_rounds[]`, `override_category`, `risk_level`, `approver_ref`, `evidence_refs[]`, `status`, `created_at`, `resolved_at`.

## Persistence

All new artifacts are written under `state://runs/{run_id}/` and referenced from `run.artifact_refs` or `pending_decision_refs`. Any blocker must also append one event to `events.jsonl` and one audit record to project audit JSONL.

## Consistency Checks

- `scripts/bin/orch-full-contract-validate` validates all new artifact definitions.
- `scripts/tests/test-schema-doc-sync.sh` verifies schema docs stay synchronized.
- Final sprint must run strict e2e replay and success metrics validation together.
