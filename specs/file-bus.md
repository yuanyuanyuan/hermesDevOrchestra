# File Bus Derived Spec

## Source

Primary: `.planning/SPEC.md` §§BUS-01..BUS-06.

`docs/orchestra/README.md` and `docs/orchestra/WORKFLOW.md` are projections only. If either projection conflicts with `.planning/SPEC.md`, update the projection or this derived spec to match `.planning/SPEC.md`.

Downstream read order: `.planning/SPEC.md`, then this derived spec, then `docs/orchestra/*` implementation projections.

## Consumers

- `docs/orchestra/scripts/bin/orch-bus-loop` - routes and validates active Runtime bus messages.
- `docs/orchestra/scripts/tests/test-file-bus.sh` - smoke-tests file-bus routing behavior.
- `docs/orchestra/README.md` - human-facing package projection.
- `docs/orchestra/WORKFLOW.md` - workflow projection.

## Contract

- JSON and JSONL are the canonical file-bus protocols. Markdown is a human-readable projection only and must not be the source of truth for programmatic consumers.
- Structured bus messages must include these envelope fields: `schema_version`, `message_id`, `project_id`, `task_id`, `correlation_id`, `status`, `author`, `authority`, and `timestamp`.
- Bus ownership follows the canonical writer/reader contract:
  - `task.md` is written by Hermes and read by Codex and Claude.
  - `codex-question.md` is written by Codex and read by Hermes and Claude.
  - `claude-decision.md` is written by Claude or User via Hermes and read by Hermes and Codex.
  - `escalation.md` is written by Claude and read by Hermes.
  - `codex-result.md` is written by Codex and read by Hermes and Claude.
  - `review-result.md` is written by Claude and read by Hermes.
  - `*.jsonl` event files are appended by Claude Code hooks and read by Hermes.
- Boundary: fixed Runtime bus filenames represent one active task slot per project. The fixed Runtime bus files are `task.md, codex-question.md, claude-decision.md, escalation.md, codex-result.md, review-result.md`; they are not a per-project multi-task parallel execution protocol. Queued or appended work may exist in State/todo layers, but the Runtime bus does not represent multiple simultaneously active tasks inside the same project.
- Same-project parallelism is out of scope for v1.2. Future support would require a separate design covering JSONL/event bus semantics, per-task file namespaces, per-task locks, worktrees or per-task branches, and merge/review arbitration. This derived spec does not define that future design.
- All bus writes use write-to-temp plus rename, with the temp file on the same filesystem as the target.
- File-level advisory locking uses `flock` on a `{filename}.lock` file.
- Stale messages are rejected when they are older than the configured threshold relative to the current task activity.
- Every message correlation must match the current task or a known sub-task; mismatches are logged and rejected.
- Schema validation failures are logged to Audit and rejected.
- Before a task or decision is considered complete, Runtime bus records are atomically migrated to the Audit layer. Runtime files are not durable evidence.

## Drift Check

```bash
bash docs/orchestra/scripts/tests/test-specs.sh && bash docs/orchestra/scripts/tests/test-file-bus.sh
```

## Conformance Checks

- `bash docs/orchestra/scripts/tests/test-specs.sh`
- `bash docs/orchestra/scripts/tests/test-file-bus.sh`
