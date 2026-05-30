<!-- generated-by: gsd-doc-writer -->

# Hermes Dev Orchestra

English | [简体中文](README.zh-CN.md)

Multi-project AI development orchestration system — coordinating Claude Code CLI (supervisor) and Codex CLI (executor) through the Hermes Agent to enable single-developer, multi-project parallel development.

<!-- VERIFY: Requires Hermes Agent v0.11.0+, Claude Code CLI v2.1.110+, Codex CLI v0.122.0+ -->

---

## Problem → Solution → Result

### Problem

Developers managing multiple projects face fragmented workflows when working with AI coding assistants:

- **Context loss**: Manually switching between Claude Code and Codex CLI means task context is constantly lost — you re-explain the same requirements in different sessions.
- **No audit trail**: Without centralized logging, you cannot trace which AI made what change, when, and why.
- **High-risk commands go unchecked**: Dangerous operations (e.g., `docker system prune`, `rm -rf`, schema migrations) run without review or approval.
- **Manual coordination**: You open two terminals, log into Claude and Codex separately, copy-paste task descriptions, and manually review code — repeating this for every project.

### Solution

Hermes Dev Orchestra automates the entire Claude↔Codex collaboration pipeline with one-command project initialization and isolated session management:

- **One-command setup**: `orch-init` scaffolds the project configuration, directory structure, and risk policies.
- **Isolated tmux session pairs**: `orch-start` automatically creates paired tmux sessions (`hermes-{project}-claude` / `hermes-{project}-codex`) for each project.
- **File-exchange task flow**: Structured files in `/tmp/hermes-orchestra/{project}/` automatically dispatch tasks, questions, decisions, and results between agents.
- **L1–L4 risk interception**: `orch-risk-check` evaluates commands against `config/risk-policy.yaml`; L3/L4 operations block and await human approval via `orch-approve` / `orch-reject`.
- **Built-in audit**: Every operation is written to `~/.local/share/hermes-orchestra/{project}/audit.jsonl` for full traceability.

### Result

Describe your task in natural language, and the orchestrator handles the rest:

- **Before**: Open two terminals → log into Claude and Codex separately → copy-paste task descriptions → manually review every code change → no logs, no rollback, no oversight.
- **After**: `orch-init my-app ~/projects/my-app` → `orch-start my-app ~/projects/my-app` → type `/dev-orchestra` in `hermes chat` and describe your task → the watcher auto-dispatches → Claude decides → Codex executes → results are auto-reviewed → `orch-audit my-app --limit 20` shows the complete audit chain.

All projects are isolated, all actions are logged, and dangerous commands are blocked until you approve them.

---

## Installation

Prerequisites (must be installed beforehand):

```bash
git --version       # >= 2.30
node --version      # >= 18
tmux -V             # >= 3.0
python3 --version   # >= 3.10
hermes --version    # >= 0.11.0
claude --version    # >= 2.1.110
codex --version     # >= 0.122.0
```

One-line installation (no sudo required, all user-local):

```bash
bash scripts/setup.sh
```

The installer automatically sets up SOUL.md, Skills, CLI helpers (`orch-*`), directory structure, and configuration templates.

## Quick Start

1. **Installation** (see above)
   ```bash
   # Guided installation / configuration / startup / MVP acceptance
   orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway
   ```
   After acceptance, the following artifacts are generated:
   - `~/.local/state/hermes-orchestra/{project}/mvp-acceptance-report.json`
   - `~/.local/state/hermes-orchestra/{project}/mvp-demo-flow.json`
   - `~/.local/state/hermes-orchestra/{project}/mvp-demo-log.jsonl`

   `mvp-demo-log.jsonl` incrementally records participants, inputs, outputs, API endpoints, artifact refs, and local evidence files for the demo case — ready for full MVP process retrospectives.

   To include real Codex / Claude CLI workers in the acceptance run:
   ```bash
   orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway --real-worker-demo
   ```
   This invokes `codex exec` to modify `.workflow/knowledge/orchestra-real-worker-demo.md`, invokes `claude -p` to review the low-risk change, and generates `mvp-real-worker-flow.json` / `mvp-real-worker-log.jsonl`.
2. **Initialize project** (project directory must be a git repository):
   ```bash
   orch-init api-gateway ~/projects/api-gateway
   ```
3. **Start orchestration sessions** (auto-creates Claude + Codex tmux process pair):
   ```bash
   orch-start api-gateway ~/projects/api-gateway
   ```
4. **Check status**:
   ```bash
   orch-status
   ```

## Usage

### Initialize and Start Multiple Projects

```bash
# Project A: Backend API
orch-init api-gateway ~/projects/api-gateway
orch-start api-gateway ~/projects/api-gateway

# Project B: Frontend
orch-init web-frontend ~/projects/web-frontend
orch-start web-frontend ~/projects/web-frontend

# View all running projects
orch-status
```

### Daily Management Commands

```bash
# View detailed status of a single project
orch-status api-gateway

# Stop project orchestration sessions
orch-stop api-gateway

# View pending approval decisions
orch-decisions

# Approve or reject
orch-approve <approval_id>
orch-reject <approval_id>

# Risk pre-check
orch-risk-check "docker system prune"

# View audit log
orch-audit api-gateway --limit 20

# Verify installation
orch-verify

# Guided configuration, startup, and MVP acceptance
orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway

# Configuration / startup only, skip tests and demo run
orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway --skip-tests

# Additional acceptance with real Codex / Claude CLI workers
orch-mvp-wizard --project-id api-gateway --project-dir ~/projects/api-gateway --real-worker-demo
```

### Run Tests

```bash
# Full test suite (unit tests + risk tests + JSON validation + shell validation + upstream version check)
make test

# Unit tests only
make test-unit

# Risk-related tests only
make test-risk
```

## Project Structure

| Directory | Description |
|-----------|-------------|
| `scripts/bin/orch-*` | CLI toolkit: init, start, stop, status, approval, risk control, etc. |
| `scripts/lib/` | Common Bash function library |
| `scripts/tests/` | Automated test suite |
| `skills/` | 4 Hermes Skills: dev-orchestra, claude-supervisor, codex-executor, escalation-handler |
| `hermes/` | SOUL.md, role engine protocol, profile distribution directory |
| `config/` | risk-policy.yaml, rules.json |
| `specs/` | Derived specifications: command set, task exchange protocol, risk decision mechanism |

## Core Concepts

- **Three-layer agent collaboration**: Hermes (orchestrator) → Claude (supervision / decision) → Codex (execution / coding)
- **File-exchange mechanism**: Each project exchanges tasks, questions, decisions, and results through structured files under `/tmp/hermes-orchestra/{project}/`
- **Audit logging**: Each project's operational audit is recorded in `~/.local/share/hermes-orchestra/{project}/audit.jsonl`
- **Three-tier decision flow**: Technical decisions (Claude auto-approves in seconds) → Risk escalation (Hermes evaluates L1–L4) → Dangerous operations (L3/L4 block awaiting human approval)
- **Multi-project isolation**: Each project has independent tmux sessions (`hermes-{project}-claude` / `hermes-{project}-codex`) and independent task directories

## Related Docs

- [`WORKFLOW.md`](docs/WORKFLOW.md) — Detailed guide for the single-developer full-cycle workflow
- [`specs/`](specs/) — Derived specifications (command set, task exchange protocol, risk decisions)
- [`docs/COVERAGE-MATRIX.md`](docs/COVERAGE-MATRIX.md) — Feature coverage matrix
