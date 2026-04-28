---
phase: 10
slug: orchestra-package-installer-skills-layout
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-25
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell + jq + grep |
| **Config file** | none — repository shell assets only |
| **Quick run command** | `bash -n docs/hermes-dev-orchestra/scripts/setup.sh && jq empty docs/hermes-dev-orchestra/claude-config/settings.json` |
| **Full suite command** | `bash -n docs/hermes-dev-orchestra/scripts/setup.sh && jq empty docs/hermes-dev-orchestra/claude-config/settings.json && grep -q 'command -v hermes' docs/hermes-dev-orchestra/scripts/setup.sh && grep -q '/tmp/hermes-orchestra/claude-events.jsonl' docs/hermes-dev-orchestra/claude-config/settings.json` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash -n docs/hermes-dev-orchestra/scripts/setup.sh && jq empty docs/hermes-dev-orchestra/claude-config/settings.json`
- **After every plan wave:** Run the full suite command above.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | PKG-01 | T10-01 | Existing upstream SOUL is backed up before overwrite | grep/static | `grep -q 'SOUL.md.bak' docs/hermes-dev-orchestra/scripts/setup.sh` | ✅ | ⬜ pending |
| 10-01-02 | 01 | 1 | PKG-02 | T10-02 | Four skills copy to direct upstream skill directories | grep/static | `grep -q 'dev-orchestra claude-supervisor codex-executor escalation-handler' docs/hermes-dev-orchestra/scripts/setup.sh` | ✅ | ⬜ pending |
| 10-01-03 | 01 | 1 | PKG-03 | T10-03 | Runtime/State/Audit/Cache roots are created with user permissions | grep/static | `grep -q '.local/state/hermes-orchestra' docs/hermes-dev-orchestra/scripts/setup.sh && grep -q '.local/share/hermes-orchestra' docs/hermes-dev-orchestra/scripts/setup.sh && grep -q '.cache/hermes-orchestra' docs/hermes-dev-orchestra/scripts/setup.sh` | ✅ | ⬜ pending |
| 10-01-04 | 01 | 1 | PKG-04 | T10-04 | Helpers use upstream `hermes`, `tmux`, `claude`, and `codex`, not a local runtime | grep/static | `grep -q 'command -v hermes' docs/hermes-dev-orchestra/scripts/setup.sh && grep -q 'command -v tmux' docs/hermes-dev-orchestra/scripts/setup.sh` | ✅ | ⬜ pending |
| 10-01-05 | 01 | 1 | PKG-03 | T10-05 | Claude hooks write to per-project and global event files | jq/grep | `jq empty docs/hermes-dev-orchestra/claude-config/settings.json && grep -q 'HERMES_ORCHESTRA_PROJECT' docs/hermes-dev-orchestra/claude-config/settings.json` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real upstream Hermes package load | PKG-01, PKG-02 | Requires installed user-level `~/.hermes` environment | Run `hermes --version`, then `bash docs/hermes-dev-orchestra/scripts/setup.sh`, then check `~/.hermes/SOUL.md` and all four `~/.hermes/skills/{skill}/SKILL.md` paths. |
| PATH activation for new shell | PKG-04 | Depends on user shell startup files and PATH | Open a fresh shell or run `hash -r`; verify `command -v orch-init orch-start orch-stop orch-status`. |
| Re-run idempotence in real home | PKG-01, PKG-03 | Mutates user-level install state | Run setup twice and confirm no duplicate backups beyond `SOUL.md.bak`, no failing `mkdir`, and all helper links remain executable. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-25
