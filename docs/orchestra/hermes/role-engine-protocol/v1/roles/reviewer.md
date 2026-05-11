# Reviewer Contract

## Status Enum

```text
approved
findings
rejected
```

## Required Request Semantics

- `task_type` is a review-stage task such as `review`
- Review requests must describe changed files and review focus
- Reviewer remains read-oriented; Phase 22 only defines the contract surface, not tool enforcement

## Response Rules

- `approved` must use `next_action = complete`
- `findings` must use `next_action = block`
- `rejected` must use `next_action = defer_to_human` or `block`

## `role_specific_payload`

When `status = findings`, the payload must include:

- `summary`
- `findings`
- `required_follow_up`

Each finding item should include:

- `severity`
- `path`
- `line`
- `issue`
- `recommended_fix`
