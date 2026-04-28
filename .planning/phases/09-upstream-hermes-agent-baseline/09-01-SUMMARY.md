---
phase: 09-upstream-hermes-agent-baseline
plan: 01
subsystem: upstream-baseline
tags: [upstream, hermes-agent, baseline]
requirements-completed: [UP-01, UP-02, UP-03, UP-04]
started: 2026-04-25T05:28:08Z
completed: 2026-04-25T05:51:16Z
---

# Phase 9 Plan 01: Upstream Hermes Agent Baseline Summary

Establishes the upstream Hermes Agent baseline, records capability gaps, and removes local standalone Hermes CLI scaffolding.

## Preflight

### Commands

- `command -v hermes || true`
- `hermes --version 2>/dev/null || true`
- `test -d "/home/stark/.hermes" && find "/home/stark/.hermes" -maxdepth 2 -type f | sort | sed -n '1,80p' || true`
- `test -d "/home/stark/.hermes-orchestra" && find "/home/stark/.hermes-orchestra" -maxdepth 2 -type f | sort | sed -n '1,80p' || true`

### Output

```text
command -v hermes: 
hermes --version: 
~/.hermes files:
(directory missing)
~/.hermes-orchestra files:
(directory missing)
```

Preflight result: clean


## Upstream Install

Install command: curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

### Installer Script Snapshot

- Downloaded installer: /tmp/hermes-agent-install.sh
- Installer SHA256: 251c1b97dda5db092d152d34afa315612fe27329e821c5414130f2a7e0c011e2

Actual non-interactive command: bash /tmp/hermes-agent-install.sh --skip-setup

### Installer Output (retry with --skip-setup)

```text

[0;35m[1m
┌─────────────────────────────────────────────────────────┐
│             ⚕ Hermes Agent Installer                    │
├─────────────────────────────────────────────────────────┤
│  An open source AI agent by Nous Research.              │
└─────────────────────────────────────────────────────────┘
[0m
[0;32m✓[0m Detected: linux (ubuntu)
[0;36m→[0m Checking for uv package manager...
[0;32m✓[0m uv found (uv 0.10.7)
[0;36m→[0m Checking Python 3.11...
[0;32m✓[0m Python found: Python 3.11.14
[0;36m→[0m Checking Git...
[0;32m✓[0m Git 2.43.0 found
[0;36m→[0m Checking Node.js (for browser tools)...
[0;32m✓[0m Node.js v24.14.0 found
[0;36m→[0m Checking ripgrep (fast file search)...
[0;32m✓[0m ripgrep 15.1.0 (rev af60c2de9d) found
[0;36m→[0m Checking ffmpeg (TTS voice messages)...
[0;32m✓[0m ffmpeg 6.1.1-3ubuntu5 found
[0;36m→[0m Installing to /home/stark/.hermes/hermes-agent...
[0;36m→[0m Existing installation found, updating...

[stderr]

```

Installer exit code: 124

### Installer Deviation: SSH partial clone cleanup

- Previous retry exit code: 124
- Cause: partial git repository used SSH remote (git@github.com:NousResearch/hermes-agent.git), and upstream update path ran git fetch without SSH timeout/fallback.
- Cleanup: removed /home/stark/.hermes/hermes-agent, then reran the same upstream installer so fresh clone can fall back to HTTPS.

Actual retry command: rm -rf /home/stark/.hermes/hermes-agent && GIT_TERMINAL_PROMPT=0 bash /tmp/hermes-agent-install.sh --skip-setup

### Installer Output (fresh retry after cleanup)

```text

[0;35m[1m
┌─────────────────────────────────────────────────────────┐
│             ⚕ Hermes Agent Installer                    │
├─────────────────────────────────────────────────────────┤
│  An open source AI agent by Nous Research.              │
└─────────────────────────────────────────────────────────┘
[0m
[0;32m✓[0m Detected: linux (ubuntu)
[0;36m→[0m Checking for uv package manager...
[0;32m✓[0m uv found (uv 0.10.7)
[0;36m→[0m Checking Python 3.11...
[0;32m✓[0m Python found: Python 3.11.14
[0;36m→[0m Checking Git...
[0;32m✓[0m Git 2.43.0 found
[0;36m→[0m Checking Node.js (for browser tools)...
[0;32m✓[0m Node.js v24.14.0 found
[0;36m→[0m Checking ripgrep (fast file search)...
[0;32m✓[0m ripgrep 15.1.0 (rev af60c2de9d) found
[0;36m→[0m Checking ffmpeg (TTS voice messages)...
[0;32m✓[0m ffmpeg 6.1.1-3ubuntu5 found
[0;36m→[0m Installing to /home/stark/.hermes/hermes-agent...
[0;36m→[0m Trying SSH clone...

[stderr]

```

Installer exit code: 143

### Installer Deviation: force HTTPS via temporary Git config

- Fresh retry also hung at upstream script SSH clone despite BatchMode/ConnectTimeout.
- Workaround: rerun the unmodified downloaded installer with GIT_CONFIG_GLOBAL=/tmp/hermes-agent-gitconfig mapping git@github.com: to https://github.com/.
- Cleanup: removed /home/stark/.hermes/hermes-agent before retry.

Actual retry command: GIT_CONFIG_GLOBAL=/tmp/hermes-agent-gitconfig GIT_TERMINAL_PROMPT=0 bash /tmp/hermes-agent-install.sh --skip-setup

### Installer Output (HTTPS rewrite retry)

```text

[0;35m[1m
┌─────────────────────────────────────────────────────────┐
│             ⚕ Hermes Agent Installer                    │
├─────────────────────────────────────────────────────────┤
│  An open source AI agent by Nous Research.              │
└─────────────────────────────────────────────────────────┘
[0m
[0;32m✓[0m Detected: linux (ubuntu)
[0;36m→[0m Checking for uv package manager...
[0;32m✓[0m uv found (uv 0.10.7)
[0;36m→[0m Checking Python 3.11...
[0;32m✓[0m Python found: Python 3.11.14
[0;36m→[0m Checking Git...
[0;32m✓[0m Git 2.43.0 found
[0;36m→[0m Checking Node.js (for browser tools)...
[0;32m✓[0m Node.js v24.14.0 found
[0;36m→[0m Checking ripgrep (fast file search)...
[0;32m✓[0m ripgrep 15.1.0 (rev af60c2de9d) found
[0;36m→[0m Checking ffmpeg (TTS voice messages)...
[0;32m✓[0m ffmpeg 6.1.1-3ubuntu5 found
[0;36m→[0m Installing to /home/stark/.hermes/hermes-agent...
[0;36m→[0m Trying SSH clone...
[0;32m✓[0m Cloned via SSH
[0;32m✓[0m Repository ready
[0;36m→[0m Creating virtual environment with Python 3.11...
[0;32m✓[0m Virtual environment ready (Python 3.11)
[0;36m→[0m Installing dependencies...
[0;36m→[0m Some build tools may be needed for Python packages...
[0;36m→[0m sudo is needed ONLY to install build tools (build-essential, python3-dev, libffi-dev) via apt.
[0;36m→[0m Hermes Agent itself does not require or retain root access.
[0;32m✓[0m Build tools installed
[0;32m✓[0m Main package installed
[0;32m✓[0m All dependencies installed
[0;36m→[0m Installing Node.js dependencies (browser tools)...
[0;33m⚠[0m npm install failed (browser tools may not work)
[0;32m✓[0m Node.js dependencies installed
[0;36m→[0m Installing browser engine (Playwright Chromium)...
[0;36m→[0m Playwright may request sudo to install browser system dependencies (shared libraries).
[0;36m→[0m This is standard Playwright setup — Hermes itself does not require root access.
[0;33m⚠[0m Playwright browser installation failed — browser tools will not work.
[0;33m⚠[0m Try running manually: cd /home/stark/.hermes/hermes-agent && npx playwright install --with-deps chromium
[0;32m✓[0m Browser engine setup complete
[0;36m→[0m Installing TUI dependencies...
[0;33m⚠[0m TUI npm install failed (hermes --tui may not work)
[0;32m✓[0m TUI dependencies installed
[0;36m→[0m Setting up hermes command...
[0;32m✓[0m Symlinked hermes → ~/.local/bin/hermes
[0;36m→[0m ~/.local/bin already on PATH
[0;32m✓[0m hermes command ready
[0;36m→[0m Setting up configuration files...
[0;32m✓[0m Created ~/.hermes/.env from template
[0;32m✓[0m Created ~/.hermes/config.yaml from template
[0;32m✓[0m Configuration directory ready: ~/.hermes/
[0;36m→[0m Syncing bundled skills to ~/.hermes/skills/ ...
Syncing bundled skills into ~/.hermes/skills/ ...
  + requesting-code-review
  + test-driven-development
  + subagent-driven-development
  + plan
  + systematic-debugging
  + writing-plans
  + godmode
  + claude-code
  + hermes-agent
  + codex
  + opencode
  + minecraft-modpack-server
  + pokemon-player
  + webhook-subscriptions
  + obsidian
  + github-pr-workflow
  + github-auth
  + github-issues
  + codebase-inspection
  + github-code-review
  + github-repo-management
  + ascii-video
  + ascii-art
  + popular-web-designs
  + pixel-art
  + songwriting-and-ai-music
  + excalidraw
  + manim-video
  + p5js
  + baoyu-infographic
  + design-md
  + ideation
  + baoyu-comic
  + architecture-diagram
  + songsee
  + spotify
  + youtube-content
  + heartmula
  + gif-search
  + native-mcp
  + himalaya
  + dogfood
  + huggingface-hub
  + serving-llms-vllm
  + outlines
  + llama-cpp
  + obliteratus
  + fine-tuning-with-trl
  + unsloth
  + axolotl
  + weights-and-biases
  + evaluating-llms-harness
  + dspy
  + audiocraft-audio-generation
  + segment-anything-model
  + openhue
  + jupyter-live-kernel
  + llm-wiki
  + arxiv
  + polymarket
  + blogwatcher
  + research-paper-writing
  + xurl
  + ocr-and-documents
  + notion
  + powerpoint
  + maps
  + google-workspace
  + nano-pdf
  + linear
  + imessage
  + findmy
  + apple-reminders
  + apple-notes

Done: 74 new, 0 updated, 0 unchanged. 74 total bundled.
[0;32m✓[0m Skills synced to ~/.hermes/skills/
[0;36m→[0m Skipping setup wizard (--skip-setup)

[0;32m[1m
┌─────────────────────────────────────────────────────────┐
│              ✓ Installation Complete!                   │
└─────────────────────────────────────────────────────────┘
[0m

[0;36m[1m📁 Your files (all in ~/.hermes/):[0m

   [0;33mConfig:[0m    ~/.hermes/config.yaml
   [0;33mAPI Keys:[0m  ~/.hermes/.env
   [0;33mData:[0m      ~/.hermes/cron/, sessions/, logs/
   [0;33mCode:[0m      ~/.hermes/hermes-agent/

[0;36m─────────────────────────────────────────────────────────[0m

[0;36m[1m🚀 Commands:[0m

   [0;32mhermes[0m              Start chatting
   [0;32mhermes setup[0m        Configure API keys & settings
   [0;32mhermes config[0m       View/edit configuration
   [0;32mhermes config edit[0m  Open config in editor
   [0;32mhermes gateway install[0m Install gateway service (messaging + cron)
   [0;32mhermes update[0m       Update to latest version

[0;36m─────────────────────────────────────────────────────────[0m

[0;33m⚡ Reload your shell to use 'hermes' command:[0m

   source ~/.bashrc


[stderr]
Using CPython 3.11.14
Creating virtual environment at: venv
Activate with: source venv/bin/activate
/tmp/hermes-agent-install.sh: line 140: /dev/tty: No such device or address
/tmp/hermes-agent-install.sh: line 141: /dev/tty: No such device or address
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
Terminated
/tmp/hermes-agent-install.sh: line 1116: 3476758 Killed                  npm install --silent 2> /dev/null

```

Installer exit code: 0

### Final Upstream Baseline

- Install location: `/home/stark/.hermes/hermes-agent`
- Binary path: `/home/stark/.local/bin/hermes`
- Pinned commit: `023b1bff11c2a01a435f1956a0e2ac1773a065f3`
- Install source: `https://github.com/NousResearch/hermes-agent`
- Installed remote normalized to HTTPS after install: `https://github.com/NousResearch/hermes-agent.git`
- Installer completed with optional browser/TUI warnings; core Python package, CLI, config templates, SOUL.md, and bundled skills were installed.

#### `hermes --version`

```text
Hermes Agent v0.11.0 (2026.4.23)
Project: /home/stark/.hermes/hermes-agent
Python: 3.11.14
OpenAI SDK: 2.32.0
Up to date
```

#### `hermes --help`

```text
Commands include: chat, model, gateway, setup, whatsapp, login, logout, auth, status, cron, webhook, hooks, doctor, dump, debug, backup, import, config, pairing, skills, plugins, memory, tools, mcp, sessions, insights, claw, version, update, uninstall, acp, profile, completion, dashboard, logs.
Global options include: --resume, --continue, --worktree, --accept-hooks, --skills, --yolo, --pass-session-id, --ignore-user-config, --ignore-rules, --tui, --dev.
```

Upgrade procedure: intentionally choose a new upstream commit SHA, rerun the upstream installer/probe with HTTPS-safe Git config if needed, verify `hermes --version` and `hermes --help`, then update this pinned commit and capability matrix. Do not track floating `main` without recording the resulting commit.

## Capability Matrix

| README assumption | Evidence checked | Classification | Phase owner |
|---|---|---|---|
| SOUL.md loading | `~/.hermes/SOUL.md` exists; `hermes --help` documents `--ignore-rules` skipping SOUL.md; upstream `agent/prompt_builder.py` loads SOUL.md from Hermes home | upstream-native | upstream |
| custom skills loading | Installer synced 74 bundled skills into `~/.hermes/skills`; `hermes skills --help` supports browse/search/install/list/audit/config; `--skills` preloads skills | upstream-native | upstream |
| todo management | `hermes tools list` shows enabled `todo` toolset; upstream display/context code handles `todo` tool calls | upstream-native | upstream |
| memory persistence | `hermes memory --help` documents built-in `MEMORY.md`/`USER.md`; `tools/memory_tool.py` reads/writes persistent memory files | upstream-native | upstream |
| terminal/process management | `hermes tools list` shows enabled `terminal`; `tools/terminal_tool.py` supports foreground/background/PTY; `tools/process_registry.py` tracks background processes | upstream-native | upstream |
| clarify/send_message decision requests | `hermes tools list` shows enabled `clarify` and `messaging`; upstream has `tools/clarify_tool.py` and `tools/send_message_tool.py` | upstream-native | upstream |
| process registry persistence | `tools/process_registry.py` has `CHECKPOINT_PATH = ~/.hermes/processes.json` for crash recovery of managed background processes | upstream-native | upstream |
| notify_on_complete | `tools/terminal_tool.py` exposes `notify_on_complete` for background terminal tasks and queues completion notifications | upstream-native | upstream |
| per-project file bus | No upstream command/schema for `/tmp/hermes-orchestra/{project}` task/decision/result files; README bus remains adapter-specific | adapter-needed | Phase 11 |
| tmux Claude/Codex sessions | Upstream can run terminal commands, but no native `orch-start` tmux lifecycle for Claude/Codex project pairs | adapter-needed | Phase 11 |
| 4-layer Runtime/State/Audit/Cache layout | Upstream owns `~/.hermes`; no native Hermes Dev Orchestra Runtime/State/Audit/Cache layout | adapter-needed | Phase 10 |
| file-based decision fallback | Upstream has interactive `clarify` and messaging, but no v1.1 local decision queue with `approve/reject` file fallback | adapter-needed | Phase 12 |

No adapter gap fillers were implemented in Phase 9.

## Local CLI Cleanup

- Deleted local standalone `hermes` scaffolding files: `package.json`, `bin/hermes.js`, `src/cli.js`, `src/result.js`, `src/version.js`.
- Confirmed stale adapter prototype files are absent: `src/atomic.js`, `src/envelope.js`, `src/paths.js`.
- No replacement `hermes` wrapper was created; future local helpers remain `orch-*`.

No local hermes wrapper remains.

## Next Phase Inputs

- Phase 10: install/package work should copy Dev Orchestra SOUL.md and skills into upstream Hermes locations, create the 4-layer Runtime/State/Audit/Cache directories, and preserve the upstream `hermes` command boundary.
- Phase 11: runtime work should implement the per-project file bus and `orch-*` tmux lifecycle around upstream Hermes terminal/process primitives.
- Phase 12: safety work should implement file-based decision fallback, static risk rule floors, and L3/L4 user-approval enforcement on top of upstream `clarify`/`send_message`.
- handoff: optional browser/TUI dependency completion can be revisited if the orchestra needs upstream browser/TUI features; Phase 9 only required core CLI baseline.

## Deviations from Plan

- Upstream installer repeatedly preferred SSH and left/used a `git@github.com` remote that hung in this environment. I cleaned only the partial install created during Phase 9, reran the unmodified installer with a temporary Git URL rewrite to HTTPS, and normalized the installed remote to HTTPS afterward.
- Optional Node/browser/TUI dependency steps were interrupted after the core CLI was already installed because they stalled or required unavailable interactive sudo/TTY flows. The installer still exited `0`; core Hermes Agent CLI, Python package, config templates, SOUL.md, and skills are present.

**Total deviations:** 2 auto-resolved. **Impact:** Upstream core baseline is usable; browser/TUI extras are not part of Phase 9 acceptance and are recorded for handoff.
