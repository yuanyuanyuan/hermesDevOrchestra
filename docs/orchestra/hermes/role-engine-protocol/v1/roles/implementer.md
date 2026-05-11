# Implementer Contract

## Status Enum

```text
task_complete
needs_decision
blocked
test_failed
```

## Required Request Semantics

- `task_type` is an implementation-stage task such as `implementation`
- `handoff_from_parent` must stay summary-first and may reference richer artifacts via `artifact_refs`
- `current_stage` reflects the active execution stage such as `implementation` or `verification`

## Response Rules

- `task_complete` must use `next_action = complete`
- `needs_decision` must use `next_action = wait_for_user` or `defer_to_human`
- `blocked` must use `next_action = block`
- `test_failed` must use `next_action = block` unless the upstream workflow explicitly requeues the task

## `role_specific_payload`

When `status = task_complete`, the payload must include:

- `summary`
- `behaviors`
- `regression`
- `changed_files`
- `decisions`
- `pitfalls`

`behaviors`, `changed_files`, `decisions`, and `pitfalls` must be arrays.

`regression` must be an object summarizing the regression run and is consumed as untrusted handoff metadata downstream.

When `status = blocked`, the payload must include:

- `block_category`
- `block_reason`
- `suggested_unblock_action`

`block_category` must be one of:

```text
architecture-decision
external-dependency-unavailable
risk-policy-intercepted
critical-test-failure
```

When `status = test_failed`, the payload should use `critical-test-failure` unless the upstream workflow adds a stricter category later.
