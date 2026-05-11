# `hermes-role-engine/v1` Common Envelope

Phase 22 defines the first executable contract between Hermes workflow profiles and external CLI engines.

## Scope

- Closed roles in Phase 22: `pm`, `implementer`, `reviewer`
- Canonical authority remains Hermes Profile + Kanban metadata
- External CLI engines are stateless executors
- `correlation_id` is trace-only, never a resume or authority key

## Request Fields

All Phase 22 request fixtures must include:

- `protocol`
- `role`
- `task_type`
- `correlation_id`
- `turn`
- `project_workspace`
- `task_id`
- `task_body`
- `task_summary`
- `current_stage`
- `conversation_history`
- `handoff_from_parent`
- `last_engine_error`
- `rollback_count`
- `instructions`

## Response Fields

All Phase 22 response fixtures must include:

- `protocol`
- `role`
- `correlation_id`
- `turn`
- `status`
- `next_action`
- `role_specific_payload`
- `conversation_context`

## Shared `next_action` Enum

The cross-role `next_action` surface is intentionally small:

```text
continue
wait_for_user
create_tasks
create_research_task
block
complete
defer_to_human
```

`status` remains role-specific. Do not invent role-local `next_action` values when a role needs richer semantics; put that meaning inside `role_specific_payload`.

## Role Status Comparison

| Role | Allowed `status` values in Phase 22 |
|------|-------------------------------------|
| `pm` | `question`, `needs_research`, `requirement_ready`, `feasibility_issue` |
| `implementer` | `task_complete`, `needs_decision`, `blocked`, `test_failed` |
| `reviewer` | `approved`, `findings`, `rejected` |

## Canonical Runtime Context

Phase 22 only treats the following runtime fields as canonical carried state:

```text
conversation_history
handoff_from_parent
task_summary
current_stage
last_engine_error
rollback_count
```

`conversation_history` uses a two-layer compaction rule:

```text
summary + recent N raw turns
```

The fixture shape is:

```json
{
  "summary": "Earlier turns compacted into a short summary.",
  "recent_turns": [
    {
      "turn": 3,
      "role": "user",
      "content": "7天免登录",
      "decision_tags": ["approved"]
    }
  ]
}
```

Comments are audit-only. They are never canonical recovery state and may not replace missing metadata.

## Failure Normalization

Normalized failure classes:

```text
timeout
crash
rate_limit
parse_error
schema_mismatch
```

Policy:

- `timeout`, `crash`, and `rate_limit` retry the primary engine once.
- After the retry is exhausted, a single fallback invocation is allowed only if the role profile explicitly declares `engine.fallback`.
- Any fallback use must be auditable with original engine, failure class, and fallback engine.
- A successful fallback applies only to that one invocation; the next invocation starts from the primary engine again.
- `parse_error` and `schema_mismatch` are hard-stop failures: immediate `block`, no auto-fallback, no silent recovery.
