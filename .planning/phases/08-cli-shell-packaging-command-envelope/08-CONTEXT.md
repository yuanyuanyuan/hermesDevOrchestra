# Phase 8: CLI Shell, Packaging & Command Envelope - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Smart discuss defaults accepted in autonomous mode

<domain>
## Phase Boundary

This phase creates the runnable local `hermes` command shell only: help, version, no-sudo development invocation, command dispatch, and stable success/error result envelopes. It does not implement durable state, project registration, tasks, doctor, risk, or decisions yet; those are owned by later phases.

</domain>

<decisions>
## Implementation Decisions

### Runtime Shape
- Use Node.js with only built-in modules so the prototype runs without dependency installation.
- Expose `bin/hermes.js` through `package.json` `bin` for local no-sudo execution.
- Keep command parsing small and explicit instead of adding a CLI framework dependency.
- Treat unknown commands and invalid arguments as structured errors.

### Output Contract
- Print human-readable text for `--help` and `--version` by default.
- Support `--json` for help/version and emit structured JSON envelopes for command-style operations.
- Use stable envelope fields: `success`, `command`, `timestamp`, `data`, and `error`.
- Include clear error `code`, `message`, and `suggestion` fields.

### Scope Control
- Stub later commands through the dispatcher only where needed to prove structured error behavior.
- Defer all filesystem state and bus writes to Phase 9.
- Do not introduce live Claude/Codex/tmux orchestration.
- Do not bind any remote adapter.

### the agent's Discretion
All implementation choices may favor the smallest maintainable prototype that satisfies Phase 8 and keeps later phases easy to extend.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.planning/SPEC.md` provides command contracts and envelope examples.
- `docs/hermes-dev-orchestra/scripts/setup.sh` shows the no-sudo Ubuntu assumptions.

### Established Patterns
- This repository is currently spec-first with no existing application code.
- Markdown planning artifacts are authoritative for scope; JSON/JSONL will become canonical runtime protocol in later phases.

### Integration Points
- New implementation code can live under `bin/`, `src/`, `scripts/`, `test/`, and `docs/`.
- Future phases will extend the command registry created here.

</code_context>

<specifics>
## Specific Ideas

Use `node bin/hermes.js ...` as the guaranteed local development entry; users may optionally run `npm link` later, but this milestone must not require it.

</specifics>

<deferred>
## Deferred Ideas

- Durable paths, state store, file bus, audit, project/task/status, doctor, risk, decisions, and verification coverage are deferred to Phases 9–12.

</deferred>
