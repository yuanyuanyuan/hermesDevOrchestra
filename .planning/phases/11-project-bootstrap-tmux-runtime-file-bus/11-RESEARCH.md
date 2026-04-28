# Phase 11: Project Bootstrap, tmux Runtime & File Bus - Research

**Researched:** 2026-04-25
**Status:** Complete
**Mode:** inline fallback — GSD subagents are unavailable/timeout-prone in this runtime; research was performed from local CLI help, official docs, and repository artifacts.

## RESEARCH COMPLETE

## Objective

Answer: what do we need to know to plan Phase 11 well?

Phase 11 must turn the Phase 10 package helpers into a usable local runtime loop:

- register a Git project with durable State/Audit metadata and a Runtime bus
- start/reuse Claude and Codex tmux shells
- dispatch `task.md` to Codex
- route `codex-question.md` to Claude
- route `claude-decision.md` back to Codex
- collect `codex-result.md`, `review-result.md`, and project-prefixed status

The phase must not implement Phase 12's risk-rule enforcement or L3/L4 approval logic.

## Source Artifacts

- `.planning/REQUIREMENTS.md` — RUN-01 through RUN-05.
- `.planning/ROADMAP.md` — Phase 11 success criteria and dependency on Phase 10.
- `.planning/SPEC.md` — runtime, bus, state, multi-project, and recovery contracts.
- `.planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-CONTEXT.md` — locked decisions D-11-01 through D-11-13.
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-01-SUMMARY.md` — Phase 10 installed helper names and package boundaries.
- `docs/hermes-dev-orchestra/scripts/setup.sh` — current generated `orch-*` helper implementation.
- `docs/hermes-dev-orchestra/skills/{dev-orchestra,claude-supervisor,codex-executor}/SKILL.md` — protocol docs that must be aligned with current CLI behavior.
- Official docs checked:
  - OpenAI Codex CLI reference: https://developers.openai.com/codex/cli/reference
  - OpenAI Codex hooks page: https://developers.openai.com/codex/hooks
  - Anthropic Claude Code headless mode: https://docs.anthropic.com/en/docs/claude-code/headless

## Confirmed CLI Facts

### Codex CLI

Local command: `codex-cli 0.125.0`.

`codex exec --help` confirms:

- `codex exec` is the non-interactive mode.
- Prompt can be passed as an argument, as `-`, or via stdin.
- `--json` prints newline-delimited JSON events.
- `-o, --output-last-message <FILE>` writes the assistant's final message to a file.
- The local CLI help includes a session continuation subcommand, but Phase 11 does not require it because `11-CONTEXT.md` locked fresh context injection as the recovery strategy.
- `--full-auto` exists as the low-friction sandboxed automatic execution mode.
- `--dangerously-bypass-approvals-and-sandbox` exists and must remain forbidden by this project.

Planning implication: use fresh one-shot `codex exec` commands sent into a tmux shell, not a permanently interactive Codex process and not session continuation. Capture final output with `--output-last-message` and stream JSON events into State logs.

### Codex notification/hook correction

The Phase 11 context says `notification_hook` should be used as an acceleration signal. Current local config uses top-level `notify = [...]`, and the official CLI reference does not document `notification_hook` as an `exec` flag.

Planning implication: do not make Phase 11 correctness depend on a global `~/.codex/config.toml` hook. The durable completion signal should be the `codex-result.md` file written by `--output-last-message` plus process exit/file polling. To honor D-11-05, the watcher should support optional `.codex-done` / `.codex-signal` files that a `notification_hook` or current Codex `notify` command can touch as acceleration only.

### Claude Code CLI

Local command: `2.1.120 (Claude Code)`.

`claude --help` confirms:

- `-p, --print` prints a response and exits.
- `--output-format` supports `text`, `json`, and `stream-json` with `--print`.
- `--input-format` supports `text` and `stream-json` with `--print`.
- `-r, --resume [value]` and `-c, --continue` are available.
- `--permission-mode auto` is available.
- `--dangerously-skip-permissions` exists and must remain forbidden by this project.

Planning implication: use `claude -p --output-format json --permission-mode auto` for decision/review jobs sent into the Claude tmux shell. Persist any returned `session_id` in State for later resume, but the phase can work with fresh print invocations.

## Architectural Findings

### Helper layout

Phase 10 currently generates all helper scripts from `setup.sh` heredocs. Phase 11 behavior is large enough that continuing to embed all logic in one installer file would make execution and review fragile.

Recommendation: create package helper templates under `docs/hermes-dev-orchestra/scripts/bin/` and shared shell functions under `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh`; update `setup.sh` to install/copy those templates. This keeps the user-facing commands unchanged: `orch-init`, `orch-start`, `orch-stop`, `orch-status`.

### Runtime bus format

Project conventions say JSON/JSONL is canonical and Markdown is human-readable projection only. Existing requirement names are `task.md`, `codex-question.md`, `claude-decision.md`, `codex-result.md`, and `review-result.md`.

Recommendation: preserve the `.md` filenames for compatibility, but write canonical JSON envelopes into them with a Markdown-safe `body` field when human text is needed. Every runtime message should include:

- `schema_version`
- `message_id`
- `project_id`
- `task_id`
- `correlation_id`
- `status`
- `author`
- `authority`
- `timestamp`
- `body`

### tmux lifecycle

Use tmux for persistent PTY envelopes, but run Claude/Codex as one-shot jobs inside shells:

- `hermes-{project}-claude`: starts as a shell in `PROJECT_DIR`.
- `hermes-{project}-codex`: starts as a shell in `PROJECT_DIR`.
- Internal watcher process: polls or uses `inotifywait` and sends commands to the two tmux shells.

Session reuse should:

- keep healthy sessions
- recreate missing/dead sessions
- avoid killing sessions with active work unless pane health proves the shell/agent process is dead

### Watcher behavior

`orch-start` should start an internal per-project watcher if it is not already running. The watcher should:

1. detect `task.md` and send a Codex execution command
2. detect `codex-question.md` and send a Claude decision command
3. detect `claude-decision.md` and resume/re-run Codex with injected context
4. detect `codex-result.md` and send a Claude review command
5. detect `review-result.md` and mark the task completed
6. detect `escalation.md` and mark the project blocked without auto-approving

Use `inotifywait` when present; otherwise poll every 2 seconds.

### Testing strategy

Do not require real Claude/Codex authentication for phase validation. Use temporary fake `claude`, `codex`, `hermes`, and `tmux` commands in a temporary `PATH` to verify helper behavior and file-bus state transitions. Real CLI integration remains a manual smoke check because authenticated external CLIs may not be available in CI or agent sandboxes.

## Phase Risks

- **Global Codex config mutation:** per-project `notification_hook` edits would be unsafe and brittle. Avoid in Phase 11.
- **Markdown vs JSON drift:** skills currently describe Markdown prose files. Update protocol docs to canonical JSON envelopes in compatibility `.md` filenames.
- **Blocking single project stalls all projects:** watcher must record project state and return to the poll loop when one project is waiting.
- **Risk enforcement leak:** `escalation.md` is detected and blocks routing, but L3/L4 rulebook enforcement is Phase 12.
- **Same repository concurrency:** implement repository lock detection or at least write a lock stub; full worktree isolation is out of scope.

## Validation Architecture

### Framework

- Shell syntax checks: `bash -n`.
- JSON checks: `jq empty`.
- Fixture smoke checks: temporary directory with fake `hermes`, `tmux`, `claude`, `codex`, and a Git project.

### Automated commands

- `bash -n docs/hermes-dev-orchestra/scripts/setup.sh`
- `find docs/hermes-dev-orchestra/scripts -type f -name 'orch-*' -o -name 'orch-common.sh' | xargs -r -n1 bash -n`
- `jq empty docs/hermes-dev-orchestra/claude-config/settings.json`
- temporary HOME smoke test:
  - run `setup.sh`
  - run `orch-init demo <tmp-git-project>`
  - run `orch-start demo <tmp-git-project>`
  - write `task.md`
  - trigger watcher once or run its single-iteration mode
  - verify `codex-result.md`, `claude-decision.md`, `review-result.md`, `project.env`, `paths.json`, and status output

### Manual verification

- With real authenticated CLIs, run `orch-init`, `orch-start`, write a small `task.md`, and confirm `codex-result.md` and `review-result.md` appear with `[project-id]` status output.
