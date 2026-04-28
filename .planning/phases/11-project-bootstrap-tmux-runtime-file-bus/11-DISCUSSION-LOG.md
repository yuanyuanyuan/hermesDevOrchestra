# Phase 11 Discussion Log: Project Bootstrap, tmux Runtime & File Bus

**Date:** 2026-04-25
**Mode:** Requirements alignment via `$gsd-discuss-phase 11` (interactive)
**Purpose:** Align Phase 11 requirements with README.md baseline and research-validated CLI capabilities

## Background

Phase 11 had no prior CONTEXT.md or PLAN.md. Following Phase 10 context completion, the user requested Phase 11 requirements alignment in plain Chinese (大白话). Five gray areas were identified and discussed, followed by research validation of Codex CLI and Claude Code CLI capabilities.

## Gray Areas Discussed

### ① 会话复用策略 — Session Reuse Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| A. 复用现有会话 | 检测到已存在就返回成功，不打断当前任务 | ✓ |
| B. 杀掉重建 | 确保每次 start 都是干净状态，但会丢失正在进行的编码工作 | |
| C. 报错提醒 | 让用户自己决定，安全但增加了操作步骤 | |

**User's choice:** A — 复用现有会话
**Follow-up:** 如果 tmux 会话存在但里面的进程已死？
- A. 复用时检测进程健康（死了重建，活着复用） ← **Selected**
- B. 无条件复用
- C. 交给实现判断

**Notes:** User confirmed health-check approach. Tmux's persistence is the core value; zombie sessions should be prevented.

---

### ② Codex 工作模式 — Codex Work Mode

| Option | Description | Selected |
|--------|-------------|----------|
| A. 持续运行 + 忙信号保护 | Codex 持续运行，通过 .busy 标志避免打断 | |
| B. 一次性执行 | 每次 codex exec 执行完就退出，文件总线是唯一状态 | ✓ |
| C. 先调研再决定 | 调研 Codex CLI 交互协议后再决定 | |

**User's clarification:** "是一次性执行，用的 codex exec。不过恢复上下文可以 codex resume 或者 Codex 官方有提供细节支持这个无头模式，例如 -jsonl 之类来输出和记录上下文。然后再次恢复的话，要么 codex resume，要么插入上下文进去再次执行 codex exec 都可以。"

**Research findings:**
- `codex exec` is the canonical headless mode — confirmed
- `--json` flag provides structured output (not `--jsonl` for exec mode)
- `notification_hook` in `~/.codex/config.toml` can trigger custom commands on completion
- No official `codex resume` CLI subcommand found; context recovery must be via re-execution with injected file content
- Session logs stored as `.jsonl` files under `~/.codex/sessions/` but not directly resumable

**Final decision:** One-shot `codex exec` mode with `notification_hook` acceleration signal.

---

### ③ Claude Code 工作模式 — Claude Code Work Mode

| Option | Description | Selected |
|--------|-------------|----------|
| A. 持续运行（交互模式） | Claude Code 像聊天机器人持续挂在 tmux 里，通过 send-keys 接收问题 | |
| B. 按需启动 | 每次有问题时启动 Claude Code 处理，处理完退出 | ✓ |
| C. 交给实现判断 | 根据 Claude Code CLI 能力决定 | |

**User's clarification:** "claude code 也是类似 codex 的，应该选 B，但是也是基于 claude code cli 官方支持的模式来恢复上下文。claude -p 就是无头模式，可以塞入上下文进去启动 claude，这样就可以将 codex 的内容发给 claude code。每次 hermes 是通过这个方式切换 claude code 和 codex。"

**Research findings:**
- `claude -p` / `--print` is the official headless mode — confirmed
- Supports pipe stdin: `cat file | claude -p "prompt"`
- Supports `--resume <id>` and `--continue` for session recovery
- Supports `--output-format json` and `stream-json`
- No native completion notification mechanism (unlike Codex's `notification_hook`)
- Known bugs: large stdin empty output (#7263), infinite system-reminder accumulation (#27599)

**Final decision:** One-shot `claude -p` mode with pipe stdin context injection.

---

### ④ 文件总线检测机制 — File Bus Detection Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| A. 定时轮询 | 每2-5秒检查一次文件目录，简单可靠 | 保底 |
| B. 文件系统事件监听 | 用 inotifywait 即时感知文件变化 | 次选 |
| C. 混合模式（推荐） | 优先 inotify，不可用则回退轮询 | 次选 |
| D. 交给实现判断 | 根据实现复杂度决定 | |

**User's input:** "本身 codex cli 支持通知模式，claude code 的话应该也有，具体查官方 claude code 文档确认"
**User's follow-up:** "定时轮询是保底行为"

**Research findings:**
- **Codex**: Has `notification_hook` in `~/.codex/config.toml` — can trigger custom command on completion
- **Claude Code**: No native completion notification mechanism found
- Both tools: file bus change detection (inotify/polling) works universally

**Final decision (research-adjusted):**
- Codex: Use `notification_hook` as acceleration signal
- Claude Code: Rely on file bus detection (no native notification)
- Unified fallback: inotify preferred, polling as bottom-line guarantee

---

### ⑤ orch-status 显示范围 — orch-status Display Scope

| Option | Description | Selected |
|--------|-------------|----------|
| A. 轻量版 | 只显示项目名 + 会话状态 + 当前任务名 | |
| B. 详细版 | 会话状态 + 文件总线阶段 + 各文件存在状态 | ✓ |
| C. 交给实现判断 | 根据实现复杂度决定 | |

**User's choice:** B — 详细版
**Notes:** File bus stage information (which files exist) is the most valuable signal for multi-project orchestration.

---

## Research Sources

### Claude Code CLI
- [Claude Code Headless Mode — Official Docs](https://docs.claude.com/en/docs/claude-code/headless)
- [Claude Code Headless Mode Skill — LobeHub](https://lobehub.com/ru/skills/anexileddev-codeforge-claude-code-headless)
- [Claude Code conversation history / resume — kentgigger.com](https://kentgigger.com/posts/claude-code-conversation-history)
- GitHub Issues: [#7263](https://github.com/anthropics/claude-code/issues/7263) (large stdin empty output), [#27599](https://github.com/anthropics/claude-code/issues/27599) (infinite system-reminder)

### Codex CLI
- [Codex CLI Reference — OpenAI](https://developers.openai.com/codex/cli/reference)
- [Codex Changelog — OpenAI](https://developers.openai.com/codex/changelog)
- [Codex CLI Getting Started — DeployHQ](https://www.deployhq.com/blog/getting-started-with-openai-codex-cli-ai-powered-code-generation-from-your-terminal)
- [Codex CLI Mastery Guide (Chinese) — heyuan110.com](https://www.heyuan110.com/zh/posts/ai/2026-02-12-codex-cli-mastery-guide/)
- GitHub Issues: [oh-my-codex #1334](https://github.com/Yeachan-Heo/oh-my-codex/issues/1334) (notify-fallback logs)

## Files Created

- `.planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-CONTEXT.md`
- `.planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-DISCUSSION-LOG.md`

## Follow-Up

- Phase 11 context is ready for planning (`$gsd-plan-phase 11`)
- Phase 12 requirements alignment is next (if user chooses to continue)
