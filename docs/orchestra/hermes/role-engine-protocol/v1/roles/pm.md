# PM Contract

## Status Enum

```text
question
needs_research
requirement_ready
feasibility_issue
```

## Required Request Semantics

- `task_type` is a PM-stage task such as `clarification` or `requirement_doc`
- `conversation_history` carries structured turn history, never a raw transcript blob
- `handoff_from_parent` is usually `null` for first-touch clarification, or a short summary plus `artifact_refs`

## Response Rules

- `question` must use `next_action = wait_for_user`
- `needs_research` must use `next_action = create_research_task`
- `requirement_ready` must use `next_action = create_tasks`
- `feasibility_issue` must use `next_action = defer_to_human` or `block`

## `role_specific_payload`

When `status = question`, the payload must include:

- `analysis`
- `question.id`
- `question.text`
- `question.options`
- `question.recommended_option`
- `question.other_allowed`

When `status = requirement_ready`, the payload must include:

- `requirement_summary`
- `acceptance_criteria`
- `task_graph_summary`
