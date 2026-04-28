# Phase 11: Project Bootstrap, tmux Runtime & File Bus - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Research:** Codex CLI notification_hook and Claude Code headless mode confirmed via official docs

<domain>
## Phase Boundary

This phase implements the runtime orchestration loop: project initialization (`orch-init`), tmux session lifecycle (`orch-start`, `orch-stop`), and the per-project file bus message routing that connects Hermes Agent, Claude Code, and Codex CLI.

It does NOT implement the safety/risk decision enforcement (Phase 12), the installer/setup script (Phase 10), or remote adapters (deferred). It assumes Phase 10 has installed SOUL.md, skills, Claude hooks, `orch-*` scripts, and the 4-layer directory structure.

Key runtime primitives:
- `orch-init <project-id> <project-dir>`: validates Git repo, creates per-project bus files, copies Claude settings.json
- `orch-start <project-id> <project-dir>`: creates or reuses tmux sessions, starts the file bus watcher
- `orch-stop <project-id>`: stops tmux sessions for a project
- `orch-status`: displays project states and file bus stages
- File bus files: `task.md`, `codex-question.md`, `claude-decision.md`, `codex-result.md`, `review-result.md`, `escalation.md`

</domain>

<decisions>
## Implementation Decisions

### Session Reuse Strategy (Gray Area ①)
- **D-11-01:** `orch-start` **reuses existing tmux sessions** when they already exist. It does not kill and recreate them, to avoid interrupting in-progress work.
- **D-11-02:** Before reusing, `orch-start` **checks process health** (via `ps` or `tmux list-panes`). If the Claude Code or Codex process inside the tmux session has died, the session is killed and recreated.
- **Rationale:** Tmux's core value is session persistence. Killing sessions would destroy ongoing work. Health checks prevent "zombie" sessions from accumulating.

### Codex CLI Work Mode (Gray Area ②)
- **D-11-03:** Codex runs in **one-shot execution mode** (`codex exec`). The command executes and exits. The tmux session remains alive because a bash shell continues running after the command completes.
- **D-11-04:** Context recovery between Codex invocations is achieved by **re-executing `codex exec` with injected context** from file bus files (`task.md`, `claude-decision.md`, etc.). There is no official `codex resume` CLI subcommand; session logs exist as `.jsonl` files but are not directly resumable.
- **D-11-05:** Codex's **`notification_hook`** (configured in `~/.codex/config.toml`) is used as an **acceleration signal**. When Codex completes a task, the hook writes a signal file (e.g., `.codex-signal`) that prompts Hermes to immediately check the file bus, reducing latency compared to pure polling.
- **Rationale:** `codex exec` is the canonical headless mode. The `notification_hook` provides a clean completion signal without requiring Hermes to guess when Codex is done.

### Claude Code CLI Work Mode (Gray Area ③)
- **D-11-06:** Claude Code runs in **one-shot execution mode** (`claude -p` headless mode). The command executes the prompt, completes all agentic turns, prints the result, and exits. The tmux session remains alive because a bash shell continues running.
- **D-11-07:** Context is injected via **pipe stdin**: `cat context.md | claude -p "prompt"`. This allows Hermes to pass file bus content directly into Claude Code's input.
- **D-11-08:** Session recovery is supported via **`--resume <id>`** or **`--continue`** flags. Hermes can capture `session_id` from `--output-format json` and resume later if needed.
- **Rationale:** `claude -p` is the official headless mode. Unlike Codex, Claude Code has no `notification_hook`, so completion detection relies on file bus or process monitoring.

### File Bus Detection Mechanism (Gray Area ④)
- **D-11-09:** **Codex completion detection**: Primary signal is the `notification_hook` callback. When triggered, Hermes immediately reads the file bus to confirm state.
- **D-11-10:** **Claude Code completion detection**: No native notification mechanism exists. Hermes detects completion by monitoring the file bus (file changes) or checking if the `claude` process has exited in the tmux session.
- **D-11-11:** **Unified fallback**: File bus change detection via **`inotifywait`** (preferred on Linux) with **polling fallback** (2-5 second interval) if inotify is unavailable. Polling is the guaranteed bottom-line mechanism.
- **D-11-12:** Hermes acts as the **central scheduler**. It decides when to send the next command (to Claude or Codex) based on file bus state, not by real-time event streaming.
- **Rationale:** Different tools have different native capabilities. A unified file bus + tool-specific acceleration signals provides the best balance of responsiveness and reliability.

### orch-status Display Scope (Gray Area ⑤)
- **D-11-13:** `orch-status` uses the **detailed format**, showing:
  - Project name and tmux session state (running / stopped)
  - Current active task name
  - File bus stage (Codex working / waiting for Claude decision / completed / idle)
  - Per-file existence markers: `task.md`, `codex-question.md`, `claude-decision.md`, `codex-result.md`, `review-result.md`, `escalation.md`
- **Rationale:** File bus stage is the most valuable information — it directly shows where the project is in the workflow. A lightweight "running/stopped" display would be insufficient for multi-project orchestration.

### Known Constraints from Research
- **Claude Code headless stdin limit**: Large stdin input (~7000+ characters) may return empty output in headless mode (bug #7263). Context injection via file should stay under this limit or use chunked injection.
- **Claude Code `<system-reminder>` accumulation**: In headless mode, repeated file edits can cause infinitely growing `<system-reminder>` blocks that consume the context window (bug #27599). Mitigation: start a new session periodically or after heavy file operations.
- **Codex `--json` vs `--jsonl`**: The official CLI flag is `--json` (structured JSON output). `--jsonl` exists in `app-server` mode and session transcripts but not as a direct `exec` flag.

### Claude's Discretion
- Exact `tmux send-keys` command formatting and quoting rules are left to implementation discretion.
- The specific `inotifywait` command and fallback polling interval are left to implementation discretion.
- The exact `notification_hook` command in `~/.codex/config.toml` is left to implementation discretion (should write a per-project signal file).
- Whether to use `--resume` vs fresh `claude -p` for Claude Code context recovery is left to implementation discretion.
- Error handling for dead tmux sessions, crashed processes, or hung commands is left to implementation discretion (should include timeout and cleanup).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — v1.1 requirement list (RUN-01..RUN-05)
- `.planning/ROADMAP.md` — Phase 11 goals, success criteria, execution order
- `.planning/PROJECT.md` — Vision, constraints, key decisions, current state
- `.planning/STATE.md` — Current progress and locked decisions

### Product Intent
- `docs/hermes-dev-orchestra/README.md` — Product behavior baseline: Step 4 (orch-init), Step 5 (orch-start), §6 daily usage examples, §7.2 Claude Code settings.json, §8 process management cheat sheet
- `docs/hermes-dev-orchestra/hermes/SOUL.md` — Hermes orchestrator personality definition

### Skills
- `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` — Main orchestration skill
- `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md` — Claude supervisor role
- `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md` — Codex executor role
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` — Risk gatekeeper role

### Prior Phase Context
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md` — Upstream capability matrix, pinned commit SHA, gap analysis
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-CONTEXT.md` — Phase 10 locked decisions (D-01 through D-12)

### CLI Documentation (research-validated)
- [Claude Code Headless Mode Docs](https://docs.claude.com/en/docs/claude-code/headless) — `-p`, `--print`, `--output-format`, `--resume`, `--continue`, `--permission-mode`
- [Codex CLI Reference](https://developers.openai.com/codex/cli/reference) — `codex exec`, `--json`, `notification_hook`, `app-server`
- [Codex Changelog](https://developers.openai.com/codex/changelog) — v0.118.0 stdin support, v0.125.0 `--json` enhancements

</canonical_refs>

<code_context>
## Existing Code Insights

### Phase 10 Assets (to be installed before Phase 11 runs)
- SOUL.md at `~/.hermes/SOUL.md` — orchestrator personality
- 4 skills at `~/.hermes/skills/{name}/` — dev-orchestra, claude-supervisor, codex-executor, escalation-handler
- Claude hooks template at per-project `.claude/settings.json` — writes to per-project and global claude-events.jsonl
- `orch-*` bash scripts — core helpers installed on PATH
- 4-layer directory structure — Runtime (`/tmp/`), State (`~/.local/state/`), Audit (`~/.local/share/`), Cache (`~/.cache/`)

### Upstream Environment (from Phase 9)
- Hermes Agent v0.11.0 at `/home/stark/.hermes/hermes-agent`, binary at `~/.local/bin/hermes`
- Pinned commit: `023b1bff11c2a01a435f1956a0e2ac1773a065f3`
- Upstream-native capabilities: terminal/process management, todo, memory, clarify/send_message, notify_on_complete
- Upstream does NOT provide: per-project file bus, tmux lifecycle for Claude/Codex pairs, 4-layer layout

### Local Code Status
- Standalone Node CLI scaffolding was deleted in Phase 9 (package.json, bin/hermes.js, src/cli.js, etc.)
- No local `hermes` wrapper remains; all local entrypoints are `orch-*`
- `src/atomic.js`, `src/envelope.js`, `src/paths.js` are stale unless retained as adapter utilities

### Reusable Patterns
- Phase 10's `setup.sh` contains Git validation and directory creation logic that `orch-init` can reuse or reference
- Phase 10's Claude hooks template already defines the event file paths (per-project + global)
- Upstream Hermes Agent's `terminal` and `process_registry` tools can be used by the adapter for process management

</code_context>

<specifics>
## Specific Ideas

1. **Tmux session naming**: `hermes-{project}-claude` and `hermes-{project}-codex` per README.md §4. This must be consistent across `orch-start`, `orch-stop`, `orch-status`, and the file bus watcher.

2. **File bus stage detection**: The presence/absence of specific files indicates workflow stage:
   - `task.md` exists → task dispatched to Codex
   - `codex-question.md` exists → Codex waiting for Claude decision
   - `claude-decision.md` exists → Claude has decided, Codex can resume
   - `codex-result.md` exists → Codex finished, ready for review
   - `review-result.md` exists → Claude reviewed, task complete
   - `escalation.md` exists → L3/L4 risk detected, block and escalate (Phase 12)

3. **Codex notification_hook configuration**: In `~/.codex/config.toml`:
   ```toml
   [notification_hook]
   command = "bash"
   args = ["-c", "touch /tmp/hermes-orchestra/{project}/.codex-done"]
   ```
   The `{project}` placeholder must be resolved at runtime by `orch-start` when configuring the hook.

4. **Claude Code output capture**: Since `claude -p` outputs to stdout (captured by the tmux pane), Hermes can use `tmux capture-pane` to read the result after detecting process completion.

5. **Multi-project non-blocking**: Per README.md §4, when project A's Codex waits for a Claude decision, Hermes should continue processing project B. This requires the file bus watcher to handle multiple projects concurrently.

6. **Context injection size limit**: Due to Claude Code bug #7263 (large stdin returns empty output), context files injected via pipe should be chunked if they exceed ~5000 characters.

</specifics>

<deferred>
## Deferred Ideas

- Safety/risk decision enforcement (L3/L4 blocking) — Phase 12
- File-based decision fallback channel (`hermes decisions/approve/reject`) — Phase 12
- Static risk rulebook creation — Phase 12
- Smoke fixture verification — Phase 12
- Coverage matrix documentation — Phase 12
- Remote adapter implementation — deferred to v2+
- Team workflows, dashboards, gbrain integration — deferred to v2+

</deferred>

---

*Phase: 11-project-bootstrap-tmux-runtime-file-bus*
*Context gathered: 2026-04-25*
*Research validated: 2026-04-25 (Codex notification_hook, Claude Code headless mode)*
*Decisions locked: D-11-01 through D-11-13*
