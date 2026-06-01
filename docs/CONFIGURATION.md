<!-- generated-by: gsd-doc-writer -->

# Configuration

This document covers all configurable aspects of the Hermes Dev Orchestra package.

## Environment Variables

All directory paths and runtime tunables are controlled through environment variables with sensible defaults. No `.env` file is required for the orchestra itself; variables are optional unless noted.

| Name | Required | Description |
|------|----------|-------------|
| `HERMES_HOME` | Optional | Base directory for Hermes Agent integration. Used to locate `SOUL.md` and the canonical skills directory. |
| `HERMES_SKILLS_DIR` | Optional | Directory where orchestra skills (`dev-orchestra`, `claude-supervisor`, `codex-executor`, `escalation-handler`) are installed. Falls back to `$HERMES_HOME/skills`. |
| `ORCHESTRA_HOME` | Optional | Root directory for all orchestra runtime assets: binaries, libraries, hooks, plugins, tests, profile distribution, and the canonical risk policy. |
| `LOCAL_BIN_DIR` | Optional | Directory where `orch-*` helper symlinks are created. Should be on `PATH`. |
| `RUNTIME_ROOT` | Optional | Parent directory for per-project runtime bus files (`task.md`, `codex-question.md`, `claude-decision.md`, etc.). |
| `STATE_ROOT` | Optional | Parent directory for per-project state files (`current-task.json`, `paths.json`, `project.env`, `task-graph.json`, etc.). |
| `AUDIT_ROOT` | Optional | Parent directory for per-project audit artifacts (`audit.jsonl`, `observability_trace.db`, env snapshots, archived task files). |
| `CACHE_ROOT` | Optional | Parent directory for per-project transient caches. |
| `HERMES_AGENT_DIR` | Optional | Path to the upstream Hermes Agent runtime checkout. Used only by `make upstream-status` to verify pin alignment. |
| `HERMES_ORCHESTRA_PROJECT` | Runtime | Injected by `orch-start` into tmux sessions. Identifies the active project for event logging and observability. |
| `HERMES_KANBAN_BOARD` | Runtime | Injected by `orch-start` into tmux sessions. Board slug for Hermes Kanban integration. |
| `HERMES_MEMORY_NAMESPACE` | Runtime | Injected by `orch-start` into tmux sessions. Memory namespace for Hermes project isolation. |
| `HERMES_KANBAN_TASK` | Runtime | Optional. Set when a task is active. Consumed by the observability plugin to attribute traces to a task. |
| `HERMES_PROFILE_ROLE` | Runtime | Optional. Consumed by the `pre_tool_call-risk-gate.sh` hook to apply role-specific guardrails. |
| `HERMES_TOOL_NAME` | Runtime | Optional. Consumed by the `pre_tool_call-risk-gate.sh` hook to know which tool is about to be invoked. |
| `HERMES_TOOL_ARGS` | Runtime | Optional. Consumed by the `pre_tool_call-risk-gate.sh` hook to inspect tool arguments for risk patterns. |
| `OBSERVABILITY_DB_PATH` | Optional | Explicit override for the SQLite trace database path used by the observability plugin. If unset, the plugin derives the path from `AUDIT_ROOT` + `HERMES_ORCHESTRA_PROJECT` or falls back to `$ORCHESTRA_HOME/observability/observability_trace.db`. |
| `CLAUDE_SESSION_NAME` | Runtime | Optional. Set by Claude Code CLI. Consumed by hooks in `.claude/settings.json` for event attribution. |

### External API Keys (Upstream Tools)

The following keys are **not** consumed by this repository directly. They belong to the upstream Hermes Agent, Claude Code CLI, and Codex CLI installations:

| Name | Required By | Description |
|------|-------------|-------------|
| `OPENROUTER_API_KEY` | Hermes Agent | LLM provider key for Hermes chat routing. <!-- VERIFY: key name and provider relationship --> |
| `OPENAI_API_KEY` | Codex CLI | OpenAI API key for Codex code generation. <!-- VERIFY: key name and provider relationship --> |
| `ANTHROPIC_API_KEY` | Claude Code CLI | OAuth token (`sk-ant-oat01-*`) for Claude Code authentication. <!-- VERIFY: token format and OAuth flow --> |

Store these in `~/.hermes/.env` or your shell profile as required by the upstream tools.

## Config File Format

### `config/rules.json`

A JSON array of risk rule definitions. Each object contains:

- `id` — Stable rule identifier (e.g., `risk-broad-irreversible-delete`).
- `level` — Risk severity (`L3` or `L4`).
- `patterns` — Array of literal string patterns to match against command text.
- `description` — Human-readable explanation of the risk.

Example entry:

```json
{
  "id": "risk-broad-irreversible-delete",
  "level": "L4",
  "patterns": ["rm -rf /", "rm -rf .", "rm -rf *", "find . -delete"],
  "description": "Broad irreversible delete"
}
```

This file is installed to `$ORCHESTRA_HOME/risk-policy.yaml` (not `rules.json`) during setup. The `rules.json` in the repo serves as a compact, machine-readable companion to the YAML policy.

### `config/risk-policy.yaml`

The canonical risk policy in YAML. Structure:

- `version` — Policy version stamp (`YYYY-MM-DD-phaseNN`).
- `approval` — Per-level approval modes:
  - `L3`: `mode: explicit`
  - `L4`: `mode: fixed_phrase` with a `phrase_template`
- `common.rules` — Array of rules with `id`, `level`, `description`, and matchers (`match_regex` or `match_any`).
- `roles` — Role-specific guardrails:
  - `reviewer` and `orchestrator` both deny destructive tools (`terminal`, `Bash`, `file_write`, `Write`, `Edit`, `code_execution`) and restrict CLI tools to read-only (`Read`, `Glob`, `Grep`).

### `claude-config/settings.json`

Claude Code CLI settings template copied into each initialized project as `.claude/settings.json`. Structure:

- `env` — Environment variables injected into Claude Code sessions:
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`: `"0"`
  - `CLAUDE_CODE_CONTEXT_LENGTH`: `"200000"`
- `hooks` — Event hooks (`PermissionRequest`, `Notification`, `SessionStart`, `Stop`) that append structured JSON lines to `/tmp/hermes-orchestra/{project}/claude-events.jsonl`.
- `permissionMode`: `"autoEdit"`
- `allowedTools`: `["Bash", "Edit", "Read", "Write", "Glob", "Grep", "Task"]`
- `memory.enabled`: `true` with `maxItems: 50`
- `subagents.enabled`: `true` with `maxConcurrent: 3`

### Profile Distribution (`hermes/profile-distribution/`)

- `distribution.yaml` — Catalog manifest listing `active_profiles`, `reserved_profiles`, `canonical_reviewer_slug`, and legacy aliases.
- `profiles/{role}/config.yaml` — Per-role engine configuration:
  - `status` — `active` or `reserved`
  - `model` — Model identifier (e.g., `kimi-coding`)
  - `engine` — CLI, mode, flags, and fallback
  - `toolsets.enabled` / `toolsets.disabled` — Allowed and denied tool categories
- `profiles/{role}/SOUL.md` — Role-specific system prompt.

## Required vs Optional Settings

Nothing in this repository causes a hard startup failure if absent, because all tunables have defaults. However, the following commands will fail at runtime if their upstream dependencies are missing:

| Missing Dependency | Failure Point | Impact |
|--------------------|---------------|--------|
| `hermes` CLI | `scripts/setup.sh` | Setup aborts if Hermes Agent is not installed. |
| `tmux` | `scripts/setup.sh`, `orch-start` | Setup aborts; project sessions cannot start. |
| `claude` CLI | `orch-start` | `orch-start` aborts because Claude supervisor session cannot be created. |
| `codex` CLI | `orch-start` | `orch-start` aborts because Codex executor session cannot be created. |
| `git` | `orch-init`, `orch-start` | Project initialization aborts; project directory must be a Git repository. |
| `python3` | `orch-init`, `orch-start`, most `orch-*` helpers | Nearly all JSON manipulation and state transitions require Python 3. |

## Defaults

| Variable | Default Value |
|----------|---------------|
| `HERMES_HOME` | `$HOME/.hermes` |
| `HERMES_SKILLS_DIR` | `$HERMES_HOME/skills` |
| `ORCHESTRA_HOME` | `$HOME/.hermes-orchestra` |
| `LOCAL_BIN_DIR` | `$HOME/.local/bin` |
| `RUNTIME_ROOT` | `/tmp/hermes-orchestra` |
| `STATE_ROOT` | `$HOME/.local/state/hermes-orchestra` |
| `AUDIT_ROOT` | `$HOME/.local/share/hermes-orchestra` |
| `CACHE_ROOT` | `$HOME/.cache/hermes-orchestra` |
| `HERMES_AGENT_DIR` | `$HOME/.hermes/hermes-agent` |
| `OBSERVABILITY_DB_PATH` | Derived from `AUDIT_ROOT` + project, or `$ORCHESTRA_HOME/observability/observability_trace.db` |

## Per-Environment Overrides

This project does **not** use `.env.development`, `.env.production`, or `NODE_ENV` conditionals. There are no Node.js runtime or framework-specific environment profiles.

To adapt the orchestra to different environments (e.g., a shared server, a CI runner, or a container), override the directory-root variables before running `scripts/setup.sh` or any `orch-*` command:

```bash
# Example: isolate everything under /data/shared/orchestra
export ORCHESTRA_HOME=/data/shared/orchestra
export STATE_ROOT=/data/shared/orchestra/state
export AUDIT_ROOT=/data/shared/orchestra/audit
export CACHE_ROOT=/data/shared/orchestra/cache
export LOCAL_BIN_DIR=/data/shared/bin
bash scripts/setup.sh
```

All per-project paths are derived from these roots by appending the `project_id` slug, so changing the roots affects every project uniformly.

For CI or ephemeral environments, you may also override `RUNTIME_ROOT` to a persistent volume instead of `/tmp`:

```bash
export RUNTIME_ROOT=/var/lib/hermes-orchestra/runtime
```

## Gateway Helper Modules

Sprint 1 introduced three helper modules that live alongside `orch_gateway.py` in `scripts/lib/`:

| Module | Responsibility | Key Function |
|--------|---------------|--------------|
| `gateway_intake.py` | Input validation + normalization | `normalize(request) -> NormalizedIntent` |
| `gateway_projection.py` | State projection + mapping tracking | `project(intent, context) -> ProjectedState` |
| `gateway_evidence.py` | Evidence collection + confidence marking | `gather(projected) -> EvidenceBundle` |

Gateway imports these helpers at startup with a soft-fail strategy: if any helper fails to import, Gateway sets `_HELPERS_OK = False` and continues in `FALLBACK_HEURISTIC` mode. Fallback events are logged to `logs/gateway-fallback.jsonl`.

Helper modules have strict单向依赖: `intake -> projection -> evidence`. No circular imports are allowed.

## Atomic Write & Recovery

Gateway state files use `AtomicWriter` for `run.json`, `tasks.json`, and other JSON artifacts:

- Write path: temp file in the same directory, `fsync`, then atomic rename.
- Conflict detection: a changed target `mtime` returns a `conflict` receipt instead of overwriting.
- Recovery: `AtomicWriter.recover(path)` can restore the newest valid `.tmp.*` file when the target is missing or damaged.

## Project Profile Format

`.hermes/project-profile.yaml` is the **source of truth** for project metadata (Sprint 1). If `.hermes/project.json` exists, it is preserved as a read-only fallback with `deprecated: true` and `superseded_by: project-profile.yaml`.

Example `project-profile.yaml`:

```yaml
name: my-project
project_id: my-project
project_dir: /home/user/projects/my-project
profile_version: 2
source_of_truth: yaml
tech_stack:
  - python
test_command: pytest
deploy_target: container/python
risk_flags:
  - protected_target:.env
discovery_status: complete
```

Fields:
- `name` — Human-readable project name.
- `project_id` — Stable project slug.
- `profile_version` — `2` for Sprint 1 format.
- `source_of_truth` — Always `yaml`.
- `tech_stack` — Detected languages/frameworks.
- `test_command` — Primary test entrypoint.
- `deploy_target` — Inferred deployment target.
- `risk_flags` — Protected-target hits.
- `discovery_status` — `complete` or `partial`.

Migration from `project.json`:
- Run `orch-profile-sync` to generate `project-profile.yaml`.
- Existing `project.json` is automatically marked `deprecated`.
- Downstream tools read yaml first and fall back to json only if yaml is absent.

<!-- VERIFY: recommended CI/ephemeral paths are conventions, not enforced by the codebase -->
