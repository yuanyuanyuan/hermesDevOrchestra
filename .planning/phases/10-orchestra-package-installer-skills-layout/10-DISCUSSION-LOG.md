# Phase 10 Discussion Log: Orchestra Package Installer & Skills Layout

**Date:** 2026-04-25  
**Mode:** Requirements alignment via `$gsd-discuss-phase` (interactive)  
**Purpose:** Align Phase 10 requirements with Phase 9 upstream baseline discoveries

## Background

Phase 10 had no prior CONTEXT.md or PLAN.md. The user requested a fresh requirements alignment in "plain Chinese" (大白话) after Phase 9 execution revealed upstream Hermes Agent capabilities.

## Gray Areas Discussed

### ① Setup.sh Scope: Should it install Claude Code / Codex CLI?

| Option | Description | Selected |
|--------|-------------|----------|
| A. Don't manage | setup.sh only installs SOUL/skills/directories/orch-* | ✓ |
| B. Check + prompt | Check if Claude/Codex exist, prompt manual install if missing | |
| C. Auto-install | Follow README.md: auto-install/update Claude Code and Codex | |

**User's choice:** A — Don't manage.  
**Rationale:** User wants minimal scope. Claude/Codex are user's responsibility.

---

### ② Claude Hooks Events Path: Global vs per-project?

| Option | Description | Selected |
|--------|-------------|----------|
| A. Global only | `/tmp/hermes-orchestra/claude-events.jsonl` (README default) | |
| B. Per-project only | `/tmp/hermes-orchestra/{project}/claude-events.jsonl` | |
| C. Both | Per-project for isolation + global for orch-status aggregation | ✓ |

**User's choice:** C — Both.  
**Rationale:** Per-project isolation matches 4-layer design; global file provides single read point for status.

---

### ③ orch-* Helper Form: Bash scripts, Hermes skills, or hybrid?

| Option | Description | Selected |
|--------|-------------|----------|
| A. Bash scripts | Place scripts on PATH, lightweight, no dependencies | |
| B. Hermes skills | Implement via upstream skill system | |
| C. Hybrid | Bash scripts as core, optionally wrap as Hermes skills later | ✓ |

**User's choice:** C — Hybrid.  
**Rationale:** Bash is reliable now; Hermes skill wrapping is a future enhancement.

---

### ④ SOUL and Skills Installation: Direct copy, backup-then-copy, or upstream skills command?

| Option | Description | Selected |
|--------|-------------|----------|
| A. Direct overwrite | Copy SOUL/skills directly to `~/.hermes/` paths | |
| B. Backup then copy | Backup upstream's original SOUL.md, then overwrite | ✓ |
| C. Use upstream command | `hermes skills install` for skills, direct for SOUL | |

**User's choice:** B — Backup then copy.  
**Rationale:** Phase 9 discovered upstream has its own SOUL.md and 74 bundled skills. Backup preserves upstream defaults for rollback. Direct copy to `~/.hermes/skills/` is more reliable than `hermes skills install` for local paths.

---

### ⑤ Setup.sh Positioning: Should it also install upstream Hermes Agent?

| Option | Description | Selected |
|--------|-------------|----------|
| A. Orchestra only | Assume upstream already installed by Phase 9 | |
| B. Check + error | Check `hermes --version`, error if missing | ✓ |
| C. Idempotent full | Include upstream install step, skip if already installed | |

**User's choice:** B — Check upstream + install orchestra only.  
**Rationale:** Clear separation: Phase 9 installs upstream, Phase 10 installs orchestra package. Avoids duplicating SSH/HTTPS workaround from Phase 9.

## Phase 9 Discoveries Applied

The following Phase 9 findings directly shaped Phase 10 decisions:

| Finding | Impact on Phase 10 |
|---------|-------------------|
| Upstream SOUL.md at `~/.hermes/SOUL.md` | Confirmed install path; decision to backup before overwrite |
| Skills at `~/.hermes/skills/`, 74 bundled | Confirmed install path; no naming conflicts with our 4 skills |
| `hermes skills` command exists | Considered but rejected for local path installation (unverified support) |
| 4-layer layout nonexistent upstream | Phase 10 must create Runtime/State/Audit/Cache directories |
| Installer SSH/HTTPS workaround | Phase 10 setup.sh does NOT replicate upstream installation |
| Browser/TUI deps failed (optional) | Not in Phase 10 scope; recorded for handoff |

## Files Created

- `.planning/phases/10-orchestra-package-installer-skills-layout/10-CONTEXT.md`
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-DISCUSSION-LOG.md`

## Follow-Up

- Phase 11 requirements alignment is next (user paused after Phase 10 to await Phase 9 execution; now ready to continue).
