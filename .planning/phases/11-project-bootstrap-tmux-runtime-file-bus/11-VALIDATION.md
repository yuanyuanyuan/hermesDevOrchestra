---
phase: 11
slug: project-bootstrap-tmux-runtime-file-bus
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-25
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell smoke fixtures |
| **Config file** | none — use temporary HOME/PATH fixtures |
| **Quick run command** | `bash -n docs/hermes-dev-orchestra/scripts/setup.sh && find docs/hermes-dev-orchestra/scripts -type f \\( -name 'orch-*' -o -name 'orch-common.sh' \\) -print0 \| xargs -0 -r -n1 bash -n` |
| **Full suite command** | `bash docs/hermes-dev-orchestra/scripts/smoke-phase11.sh` if created; otherwise run the inline temporary HOME smoke steps from each PLAN.md |
| **Estimated runtime** | ~30 seconds with fake CLIs |

## Sampling Rate

- **After every task commit:** Run the quick shell syntax command.
- **After every plan wave:** Run the full temporary HOME smoke flow for the wave.
- **Before `$gsd-verify-work`:** Full fixture smoke must be green, or missing real CLI auth must be documented as manual-only.
- **Max feedback latency:** 30 seconds for fake-CLI checks.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | RUN-01 | T-11-01 | rejects invalid project IDs and non-Git dirs | shell | `bash -n docs/hermes-dev-orchestra/scripts/bin/orch-init` | ❌ W0 | ⬜ pending |
| 11-01-02 | 01 | 1 | RUN-01 | T-11-02 | writes State/Audit/Runtime to separated roots | smoke | `orch-init demo <tmp-git-project>` | ❌ W0 | ⬜ pending |
| 11-02-01 | 02 | 2 | RUN-02/RUN-03 | T-11-04 | reuses healthy tmux sessions and dispatches task through `task.md` | smoke | `orch-start demo <tmp-git-project>` | ❌ W0 | ⬜ pending |
| 11-02-02 | 02 | 2 | RUN-02/RUN-03 | T-11-05 | never uses dangerous CLI bypass flags | grep | `! rg 'dangerously-(skip|bypass)' docs/hermes-dev-orchestra/scripts` | ❌ W0 | ⬜ pending |
| 11-03-01 | 03 | 3 | RUN-04/RUN-05 | T-11-08 | routes question/decision/result/review with project prefix | smoke | fake `claude` + fake `codex` bus loop smoke | ❌ W0 | ⬜ pending |
| 11-03-02 | 03 | 3 | RUN-05 | T-11-09 | blocks on escalation and never auto-approves L3/L4 | grep/smoke | `orch-status demo` shows `blocked` after `escalation.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` — shared fixtureable helper functions.
- [ ] `docs/hermes-dev-orchestra/scripts/bin/orch-init` — extracted helper script.
- [ ] `docs/hermes-dev-orchestra/scripts/bin/orch-start` — extracted helper script.
- [ ] `docs/hermes-dev-orchestra/scripts/bin/orch-stop` — extracted helper script.
- [ ] `docs/hermes-dev-orchestra/scripts/bin/orch-status` — extracted helper script.
- [ ] `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` — internal watcher script.
- [ ] Optional `docs/hermes-dev-orchestra/scripts/smoke-phase11.sh` — fake-CLI smoke fixture if executor chooses a reusable test script over inline commands.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real Codex execution | RUN-03 | Requires authenticated Codex CLI and may spend model quota | In a temp Git repo, run `orch-init`, `orch-start`, write a small `task.md`, and confirm `codex-result.md` appears. |
| Real Claude decision/review | RUN-04/RUN-05 | Requires authenticated Claude Code CLI and may spend model quota | Create `codex-question.md` and `codex-result.md`, then confirm `claude-decision.md` and `review-result.md` appear. |
| tmux reattach experience over SSH | RUN-02/RUN-05 | Requires live SSH/tmux session behavior | Disconnect/reconnect SSH, run `tmux ls`, `orch-status`, and verify project-prefixed state survives. |

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing helper-script references.
- [x] No watch-mode flags.
- [x] Feedback latency target < 30s with fake CLIs.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
