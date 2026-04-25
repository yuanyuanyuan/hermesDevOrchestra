# Technology Stack — Hermes Dev Orchestra

**Project:** Hermes Dev Orchestra  
**Research dimension:** Stack/tooling  
**Researched:** 2026-04-25  
**Overall confidence:** MEDIUM-HIGH

## Recommendation in One Sentence

Specify v1 as a Linux-first, single-user orchestration system built around **tmux + Git + structured JSON/JSONL file-bus protocols + XDG state/config layout + capability-probed Claude Code/Codex CLI profiles**, with Markdown kept only for human-readable projections.

## Verified Baseline

Local environment observed on 2026-04-25:

| Tool | Observed | Use in Spec | Confidence |
|------|----------|-------------|------------|
| Codex CLI | `codex-cli 0.125.0` | Executor CLI; non-interactive `codex exec` is the canonical automation surface | HIGH |
| Claude Code | `2.1.120` | Supervisor/reviewer CLI; `--print`, structured output, permissions, hooks | HIGH |
| tmux | `3.4` | Persistent PTY/session wrapper, not the data protocol | HIGH |
| Node.js | `v24.14.0` | Recommended LTS runtime for validators/install helpers | HIGH |
| npm | `11.9.0` | Package installer for CLI/dev tooling | HIGH |
| Git | `2.43.0` | Mandatory repo boundary and rollback/checkpoint mechanism | HIGH |
| Python | `3.12.3` | Optional helper/runtime for future implementation; not required for v1 spec | MEDIUM |
| Hermes Agent | Not installed/verified locally | Treat existing `Hermes Agent >=0.10.0` claim as an implementation-phase assumption | LOW |

## Recommended Runtime Stack

### Host Assumptions

| Technology | Recommended Version/Policy | Purpose | Why |
|------------|----------------------------|---------|-----|
| Ubuntu/Linux | Ubuntu 24.04 LTS preferred; 22.04 acceptable | Primary execution host | Matches target LAN dev box; avoids Windows PTY/process differences |
| SSH | OpenSSH server/client, already provisioned | Primary human entry | Required by project context; reliable with tmux reconnects |
| tmux | Require `>=3.3`; recommend distro `3.4+` | Long-lived Claude/Codex sessions | Stable PTY/session persistence across SSH disconnects |
| Git | Require repo per project; do not use `--skip-git-repo-check` by default | Safety boundary, checkpoints, rollback | Codex automation should only operate in recoverable workspaces |
| Node.js | Recommend 24 LTS; minimum 22 LTS | Install/validate JS-based CLIs and schema tooling | Node 18 is no longer a good 2026 baseline |
| Bash/coreutils | Bash 5+, `flock`, `mktemp`, `mv`, `jq` | Local orchestration glue and safe atomic writes | Available without sudo on most Ubuntu hosts |

### Agent CLI Stack

| Role | Tool | Canonical v1 Usage | Confidence |
|------|------|--------------------|------------|
| Top-level orchestrator | Hermes Agent | Define as an interface contract first: task queue, process/session control, decision routing, audit append | LOW until Hermes docs/API are verified |
| Supervisor/reviewer | Claude Code CLI | Prefer non-interactive `claude -p --output-format json|stream-json --json-schema ...`; use hooks only from official schema | HIGH |
| Executor | Codex CLI | Prefer `codex exec --json --output-schema ... --sandbox workspace-write --ask-for-approval on-request -C <repo>` | HIGH |
| Session layer | tmux | Wrap long-running commands; use `send-keys`/`capture-pane` only for control/debug, never as the source of truth | HIGH |
| Remote decisions | Abstract adapter | `notify`, `request_decision`, `ack`, `timeout`, `cancel`; transport-specific adapters later | HIGH |

## Canonical Invocation Profiles

### Codex Executor Profile

Use explicit flags in the spec instead of hiding behavior behind `--full-auto`:

```bash
codex exec \
  --cd "$PROJECT_DIR" \
  --sandbox workspace-write \
  --ask-for-approval on-request \
  --json \
  --output-schema "$SCHEMA_DIR/codex-result.schema.json" \
  -
```

**Rationale:** current Codex supports `exec`, sandbox modes, approval policies, `--json`, `--output-schema`, `--ignore-user-config`, `--ephemeral`, and `--skip-git-repo-check`. `--full-auto` exists as a convenience alias, but explicit flags make the safety contract reviewable.

### Claude Supervisor Profile

Use Claude Code as a structured reviewer/decision maker:

```bash
claude -p \
  --permission-mode plan \
  --output-format json \
  --json-schema "$SCHEMA_DIR/claude-decision.schema.json" \
  --settings "$PROJECT_DIR/.claude/settings.json" \
  "Review the attached Codex result and emit a decision."
```

**Rationale:** Claude Code’s official CLI surface supports print mode, JSON/stream-JSON output, JSON schema validation, permission modes, settings sources, and hooks. For v1, `plan`/review-style usage is safer than letting the supervisor edit freely.

### tmux Session Profile

Use tmux for resilience and observability:

```bash
tmux new-session -d -s "hermes-${PROJECT_ID}-codex" -c "$PROJECT_DIR" -- "$EXECUTOR_COMMAND"
tmux new-session -d -s "hermes-${PROJECT_ID}-claude" -c "$PROJECT_DIR" -- "$SUPERVISOR_COMMAND"
```

**Rationale:** tmux survives SSH disconnects and keeps a PTY for CLIs that need one. The protocol must still flow through JSON/JSONL files, not terminal scrollback.

## Interface and Protocol Formats

### File Bus: JSON + JSONL, Not Raw Markdown

| Artifact | Format | Purpose | Notes |
|----------|--------|---------|-------|
| `task.json` | JSON, schema-validated | Task envelope from Hermes to executor | Includes task ID, project ID, constraints, risk policy |
| `events.jsonl` | JSON Lines | Append-only project/task event stream | One event per line; easy to tail, replay, and audit |
| `question.json` | JSON | Codex asks Claude/Hermes for clarification | Machine-readable options and blocking state |
| `decision.json` | JSON | Claude or user decision | Must include authority: `claude`, `hermes`, or `user` |
| `escalation.json` | JSON | L1-L4 risk escalation | Must include impact, reversibility, requested approval |
| `result.json` | JSON | Codex execution result | Must include files changed, tests, dependencies, residual risk |
| `review.json` | JSON | Claude review result | Must include approve/reject/modify and confidence |
| `*.md` | Markdown projection | Human-readable summaries only | Never parse Markdown as protocol state |

Required envelope fields:

```json
{
  "schema_version": "1.0",
  "message_id": "uuid",
  "project_id": "api-gateway",
  "task_id": "task-20260425-001",
  "type": "task|question|decision|escalation|result|review|event",
  "status": "pending|running|blocked|approved|rejected|completed|failed",
  "author": "hermes|claude|codex|user",
  "authority": "agent|supervisor|orchestrator|user",
  "risk_level": "L0|L1|L2|L3|L4",
  "created_at": "RFC3339 timestamp",
  "correlation_id": "uuid",
  "payload": {}
}
```

### Protocol Rules

- Use JSON Schema 2020-12 for every protocol document.
- Use JSON Lines for append-only event logs; each line is one complete JSON value.
- Write files atomically: create `*.tmp`, `fsync` if available, then `mv` into place.
- Use `flock` or per-file lock files for concurrent hooks/session writers.
- Treat `events.jsonl` plus durable state DB as source of truth; generated Markdown is disposable.
- Include `schema_version` from day one; v1 roadmap can add migrations instead of rewrites.

## Configuration and State Storage

### Directory Layout

| Data Type | Recommended Path | Why |
|-----------|------------------|-----|
| User config | `${XDG_CONFIG_HOME:-~/.config}/hermes-orchestra/config.toml` | Human-editable, not runtime state |
| Project registry/state DB | `${XDG_STATE_HOME:-~/.local/state}/hermes-orchestra/state.db` | Durable across reboot and `/tmp` cleanup |
| Audit log archive | `${XDG_STATE_HOME:-~/.local/state}/hermes-orchestra/audit/events.jsonl` | Preserves decision history |
| Runtime bus | `${XDG_RUNTIME_DIR:-/tmp}/hermes-orchestra-$UID/projects/<project_id>/` | Runtime IPC; user-scoped to avoid collisions |
| Cache | `${XDG_CACHE_HOME:-~/.cache}/hermes-orchestra/` | Rebuildable derived data |
| Per-project config | `<repo>/.hermes-orchestra/project.toml` | Project-local safe defaults and task policy |
| Claude config | `<repo>/.claude/settings.json` | Native Claude Code settings/hook location |
| Codex config | Use profile or `CODEX_HOME`; avoid mutating user global config in automation | Prevents hidden cross-project coupling |

### Storage Choice

Use **SQLite + JSONL** for durable implementation state:

- SQLite stores projects, tasks, decisions, session IDs, and idempotency keys.
- JSONL stores append-only human/audit-readable events.
- The file bus remains the handoff mechanism between independently running CLI agents.

**Rationale:** single-user local orchestration still has concurrent writers: Hermes, Claude hooks, Codex runs, and Remote Decision adapters. SQLite avoids fragile “latest file wins” state machines; JSONL keeps audit trails inspectable.

## Specification Package Tooling

| Tooling | Recommendation | Why | Confidence |
|---------|----------------|-----|------------|
| Markdown | Keep product/spec docs in Markdown | Easy roadmap/review consumption | HIGH |
| JSON Schema | Put schemas under `schemas/` | Defines protocol contracts before implementation | HIGH |
| Example fixtures | Put valid/invalid examples under `examples/` | Lets roadmap include contract tests early | HIGH |
| `jq` | Required for local inspection | Standard JSON/JSONL debugging | HIGH |
| `ajv-cli` or equivalent | Use for JSON Schema validation in CI/local checks | Fast contract validation in Node runtime | MEDIUM |
| `shellcheck` + `shfmt` | Use for future shell helpers | Prevents brittle setup/session scripts | MEDIUM |
| `markdownlint-cli2` | Optional docs quality gate | Keeps spec package readable | MEDIUM |

## Safety Stack

| Concern | v1 Stack Choice | Why |
|---------|-----------------|-----|
| Unsafe tool execution | Codex `workspace-write` sandbox + approval policy; never bypass sandbox locally | Keeps executor constrained to repo/workspace |
| Supervisor overreach | Claude in `plan`/review mode for decisions; edits require explicit phase decision | Prevents supervisor from becoming second executor |
| Human approvals | L3/L4 require explicit user decision with audit entry | Matches project safety requirement |
| Project isolation | One bus root, tmux namespace, state row, and Git repo per project | Prevents cross-project task/result confusion |
| Intra-project concurrency | Defer parallel tasks in the same repo; later use Git worktrees per task | Avoids merge conflicts and agent races |
| Secret handling | Store only references/redacted values in bus/audit; never write API keys to task/result files | Prevents accidental exfiltration through logs |
| Recovery | Require Git checkpoint before L2+ changes and before dependency/config changes | Makes rollback operationally simple |

## What NOT to Bind in v1

| Avoid Binding To | Why Not | Use Instead |
|------------------|---------|-------------|
| Telegram/Discord as required channel | User explicitly wants an abstract Remote Decision Channel | Adapter interface with SSH/local CLI as first implementation |
| Claude `--channels` | Not present in observed `claude --help`; current portability is uncertain | Official hooks + Remote Decision adapter |
| Claude experimental Agent Teams/subagents | Adds concurrency and permission complexity before core protocol is stable | Single Claude supervisor per project |
| Codex `mcp-server`, `app-server`, or Cloud | Useful later, but not needed for local file-bus orchestration | Local `codex exec` profile |
| `ai-cli-mcp` wrapper | Extra moving part and unverified dependency | Native Claude/Codex CLIs first |
| Parsing tmux scrollback | TUI output is not a stable API | JSON/stream-JSON/JSONL files |
| Raw Markdown as protocol | Ambiguous and hard to validate | JSON Schema + Markdown projections |
| `/tmp/hermes-orchestra/audit.log` as durable audit | `/tmp` can be cleared and is collision-prone | XDG state dir + runtime bus fallback |
| Hard-coded model IDs | Model availability changes quickly | CLI profiles/aliases and capability checks |
| `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--dangerously-skip-permissions` | Defeats the safety premise | Explicit sandbox + user escalation |
| `systemd --user` as mandatory | `linger` may require admin help | tmux-first; systemd user service optional later |
| Specific Claude auth token type | Auth flows change; current docs expose multiple modes | Install guide should run `claude auth`/`doctor` capability checks |

## Corrections to Existing Proposal

- Replace `Node >=18` with **Node 24 LTS recommended / Node 22 minimum** for 2026.
- Replace raw Markdown bus files as canonical state with **JSON/JSONL + Markdown projections**.
- Treat `Hermes Agent >=0.10.0`, `notify_on_complete`, and process registry claims as **unverified assumptions** until Hermes official docs are checked.
- Regenerate `.claude/settings.json` from current Claude Code hook docs; the existing template should be treated as illustrative, not authoritative.
- Do not require `claude --channels`; use the Remote Decision Channel abstraction.
- Keep `--full-auto` as shorthand only; specifications should state the explicit Codex sandbox and approval policy.
- Store durable audit/state under XDG state paths, not only under `/tmp`.

## Roadmap Implications

1. **Phase 1 should define contracts before scripts**: schemas, state machine, risk levels, and path layout.
2. **Phase 2 should validate CLI capability probes**: `claude --help`, `codex exec --help`, `tmux -V`, Git repo checks.
3. **Phase 3 should implement a minimal file-bus simulator**: write/read JSON fixtures and validate state transitions without invoking agents.
4. **Phase 4 should add agent runners**: wrap Claude/Codex non-interactive profiles in tmux with structured outputs.
5. **Phase 5 should add Remote Decision adapters**: SSH/local first; Telegram/Discord/webhook only as optional adapters.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Codex CLI automation surface | HIGH | Verified locally and against official OpenAI Codex docs |
| Claude Code structured CLI surface | HIGH | Verified locally and against official Claude Code docs |
| tmux as session layer | HIGH | Stable local tool; official releases current |
| JSON Schema/JSONL protocol | HIGH | Standard fit for machine-readable contracts and append-only events |
| XDG path layout | HIGH | Official desktop/base-dir convention; better than durable `/tmp` |
| SQLite durable state | MEDIUM | Strong local choice, but exact schema should be designed in implementation phase |
| Hermes Agent runtime/API | LOW | Existing docs mention it, but no local/official verification completed |
| Remote Decision Channel adapters | MEDIUM-HIGH | Interface is clear; concrete transports should be researched per adapter |

## Sources

- OpenAI Codex CLI docs: https://developers.openai.com/codex/cli
- OpenAI Codex non-interactive mode: https://developers.openai.com/codex/noninteractive
- OpenAI Codex approvals and sandboxing: https://developers.openai.com/codex/agent-approvals-security
- OpenAI Codex config reference: https://developers.openai.com/codex/config-reference
- OpenAI Codex GitHub README: https://github.com/openai/codex/blob/main/codex-rs/README.md
- Anthropic Claude Code CLI reference: https://docs.anthropic.com/en/docs/claude-code/cli-reference
- Anthropic Claude Code hooks: https://docs.anthropic.com/en/docs/claude-code/hooks
- Anthropic Claude Code settings: https://docs.anthropic.com/en/docs/claude-code/settings
- Node.js release schedule / previous releases: https://nodejs.org/en/about/previous-releases
- tmux releases: https://github.com/tmux/tmux/releases
- XDG Base Directory Specification: https://specifications.freedesktop.org/basedir-spec/latest/
- JSON Schema 2020-12: https://json-schema.org/draft/2020-12
- JSON Lines format: https://jsonlines.org/
- Model Context Protocol introduction: https://modelcontextprotocol.io/docs/getting-started/intro
