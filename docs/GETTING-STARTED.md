<!-- generated-by: gsd-doc-writer -->

# Getting Started

This guide walks you through installing the Hermes Dev Orchestra package, verifying your environment, and running your first orchestrated project.

## Prerequisites

The following tools must be installed and available on your `PATH` before running the setup script:

| Tool | Minimum Version | Purpose |
|------|-----------------|---------|
| `git` | >= 2.30 | Project initialization and repository checks |
| `node` | >= 18 | Runtime dependency for upstream CLIs |
| `tmux` | >= 3.0 | Session isolation for per-project agent pairs |
| `python3` | >= 3.10 | JSON envelope handling and policy loading |
| `hermes` | >= 0.11.0 | Upstream Hermes Agent orchestrator |
| `claude` | >= 2.1.110 | Claude Code CLI (supervisor role) |
| `codex` | >= 0.122.0 | Codex CLI (implementer role) |

<!-- VERIFY: Hermes Agent v0.11.0+, Claude Code CLI v2.1.110+, and Codex CLI v0.122.0+ are required upstream boundaries. -->

Check your current versions:

```bash
git --version
node --version
tmux -V
python3 --version
hermes --version
claude --version
codex --version
```

### API Keys

The upstream CLIs require their own API credentials. Store these in `~/.hermes/.env` or your shell profile:

- `OPENROUTER_API_KEY` — Hermes Agent LLM routing
- `OPENAI_API_KEY` — Codex CLI
- `ANTHROPIC_API_KEY` — Claude Code CLI (OAuth token, `sk-ant-oat01-*` format)

<!-- VERIFY: Claude Code CLI requires an OAuth token (sk-ant-oat01-*) rather than a raw API key. -->

### Authenticate the CLIs

If you have not used `claude` or `codex` on this machine before, run their authentication flows once:

```bash
claude auth
codex login
```

## Installation

1. **Clone the repository** to your local machine:

   ```bash
   git clone git@github.com:yuanyuanyuan/hermesDevOrchestra.git
   cd hermesDevOrchestra
   ```

2. **Run the setup script** (no `sudo` required; everything installs under your home directory):

   ```bash
   bash scripts/setup.sh
   ```

   The script will:
   - Verify that `hermes` and `tmux` are present
   - Install the orchestrator `SOUL.md` to `~/.hermes/SOUL.md`
   - Install four skills (`dev-orchestra`, `claude-supervisor`, `codex-executor`, `escalation-handler`) to `~/.hermes/skills/`
   - Install `orch-*` helper commands to `~/.local/bin/`
   - Create runtime directories under `/tmp/hermes-orchestra/`, `~/.local/state/hermes-orchestra/`, `~/.local/share/hermes-orchestra/`, and `~/.cache/hermes-orchestra/`

3. **Ensure `~/.local/bin` is on your `PATH`**:

   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

   Add the line above to your shell profile (e.g. `~/.bashrc`, `~/.zshrc`) so it persists across new shells.

4. **Verify the installation**:

   ```bash
   orch-verify
   ```

   This runs the built-in smoke test suite. You can also run the full validation matrix with:

   ```bash
   make test
   ```

## First Run

The orchestra operates on **already-initialized Git repositories**. Pick an existing project or create a new one and initialize it with `git init`.

1. **Initialize the project** in the orchestra:

   ```bash
   orch-init my-app ~/projects/my-app
   ```

2. **Start the orchestrated session pair** (Claude + Codex tmux sessions):

   ```bash
   orch-start my-app ~/projects/my-app
   ```

3. **Check that everything is running**:

   ```bash
   orch-status
   ```

   You should see two healthy tmux sessions: `hermes-my-app-claude` and `hermes-my-app-codex`.

At this point the file bus is active under `/tmp/hermes-orchestra/my-app/`, and the agents can begin exchanging task envelopes.

## Common Setup Issues

### `orch-init` fails with "Project directory must already be a Git repository"

**Cause**: The target directory is not inside a Git work tree.  
**Fix**: Initialize Git in the project directory before running `orch-init`:

```bash
cd ~/projects/my-app
git init
orch-init my-app ~/projects/my-app
```

### `orch-start` fails with "Required command not found: claude" (or `codex`)

**Cause**: The setup script checks for `hermes` and `tmux` but only *warns* about missing `claude` or `codex`; it does not fail. Starting a session, however, requires both CLIs to be present.  
**Fix**: Install and authenticate Claude Code CLI and Codex CLI separately, then confirm they are on your `PATH`:

```bash
claude --version
codex --version
```

### `orch-*` commands not found after setup

**Cause**: `~/.local/bin` is not on your `PATH`.  
**Fix**: Add it to your shell profile and reload:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Claude Code CLI authentication errors

**Cause**: Claude Code CLI no longer accepts raw Anthropic API keys; it requires an OAuth token.  
**Fix**: Ensure your `ANTHROPIC_API_KEY` uses the `sk-ant-oat01-*` OAuth token format and that you have run `claude auth` at least once.

<!-- VERIFY: Claude Code CLI authentication requires OAuth token format sk-ant-oat01-*. -->

## Next Steps

- **[`docs/ARCHITECTURE.md`](ARCHITECTURE.md)** — Understand the system components, data flow, and key abstractions.
- **[`docs/CONFIGURATION.md`](CONFIGURATION.md)** — Learn how to tune environment variables, risk policies, and profile distribution.
- **[`docs/DEVELOPMENT.md`](DEVELOPMENT.md)** — Contribution and local development guidelines.
- **[`docs/TESTING.md`](TESTING.md)** — Testing strategy and test-writing conventions.
- **[`WORKFLOW.md`](./WORKFLOW.md)** — Step-by-step guide to the full single-developer lifecycle.
- **[`specs/`](../specs/)** — Derived specifications for commands, the file bus protocol, and risk decisions.
