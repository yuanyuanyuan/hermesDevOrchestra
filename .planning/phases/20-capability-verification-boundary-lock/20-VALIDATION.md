---
phase: 20
slug: capability-verification-boundary-lock
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-10
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Shell static checks + targeted Hermes CLI probes + aggregate repo gate |
| Config file | Makefile |
| Quick run command | Phase 20 matrix / writeback grep checks |
| Full suite command | `rtk make test` |
| Estimated runtime | Static checks < 30s; full suite about current repo baseline |

## Sampling Rate

- After every task commit: run that task's static grep or targeted CLI probe.
- After the runtime-evidence wave: rerun matrix coverage checks before any phase 19 writeback.
- After every plan wave: run `rtk make test`.
- Before `$gsd-verify-work`: run all Phase 20 static checks plus `rtk make test`.
- Max feedback latency: 30 seconds for static checks, repo baseline runtime for the full suite.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 1 | VFY-01 | T-20-01 / T-20-02 | Matrix inventory covers roadmap core areas and phase 19 supporting claims before verdicts are assigned. | static | matrix seed coverage grep | yes | pending |
| 20-01-02 | 01 | 1 | VFY-01 | T-20-03 / T-20-04 | Locally runnable capabilities record runtime anchor, exact command, exit code, and key output. | cli + static | runtime evidence probes + matrix field grep | yes | pending |
| 20-01-03 | 01 | 1 | VFY-01, VFY-02 | T-20-05 / T-20-06 | Hybrid/doc-only capabilities are explicitly marked and unsupported claims are not silently treated as official. | static | hybrid/doc-only row coverage grep | yes | pending |
| 20-01-04 | 01 | 1 | VFY-02 | T-20-07 / T-20-08 | Phase 19 writeback and roadmap backlog entries follow the settled matrix verdicts. | static + suite | writeback grep + `rtk make test` | yes | pending |

## Wave 0 Requirements

Existing infrastructure is sufficient for Phase 20:

- Phase 20 context and discussion artifacts already exist.
- `reference/hermes-docs-index/` exists and provides the mandatory Hermes docs retrieval flow.
- Local Hermes CLI is installed and returns `Hermes Agent v0.13.0 (2026.5.7)`.
- Read-only baseline probes (`status`, `profile list`, `curator status`, `memory status`, `hooks list`, `sessions stats`, `tools list`) are already available.

## Manual-Only Verifications

Manual review is limited to:

- Confirming any `unsupported` or `local-extension` row has a corresponding writeback target.
- Confirming every failed official claim has a `.planning/ROADMAP.md` backlog entry.
- Reading `20-VERIFICATION.md` before milestone closeout.

All other Phase 20 checks should be grep- or CLI-verifiable.

## Verification Commands

### Task 20-01-01 — matrix seed coverage

```bash
rtk bash -lc 'set -euo pipefail
f=.planning/phases/20-capability-verification-boundary-lock/20-CAPABILITY-MATRIX.md
for needle in \
  "Kanban" \
  "Profile" \
  "Dispatcher" \
  "Curator" \
  "Memory" \
  "Gateway" \
  "Hooks" \
  "skill_manage" \
  "session_search" \
  "terminal" \
  "clarify" \
  "approvals.mode"; do
  rg -F "$needle" "$f" >/dev/null
done
'
```

### Task 20-01-02 — runtime evidence completeness

```bash
rtk bash -lc 'set -euo pipefail
f=.planning/phases/20-capability-verification-boundary-lock/20-CAPABILITY-MATRIX.md
rg -F "Hermes Agent v0.13.0 (2026.5.7)" "$f" >/dev/null
for needle in \
  "evidence class: runtime" \
  "exit code:" \
  "key output:" \
  "hermes kanban" \
  "hermes profile" \
  "hermes curator" \
  "hermes memory" \
  "hermes tools" \
  "hermes sessions"; do
  rg -F "$needle" "$f" >/dev/null
done
'
```

### Task 20-01-03 — hybrid/doc-only discipline

```bash
rtk bash -lc 'set -euo pipefail
f=.planning/phases/20-capability-verification-boundary-lock/20-CAPABILITY-MATRIX.md
for needle in \
  "evidence class: hybrid" \
  "evidence class: doc-only" \
  "https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks" \
  "https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban" \
  "https://hermes-agent.nousresearch.com/docs/reference/cli-commands" \
  "verdict: unsupported" \
  "verdict: local-extension"; do
  rg -F "$needle" "$f" >/dev/null
done
'
```

### Task 20-01-04 — writeback + closeout gate

```bash
rtk bash -lc 'set -euo pipefail
rg -F "VFY-01" .planning/REQUIREMENTS.md >/dev/null
rg -F "VFY-02" .planning/REQUIREMENTS.md >/dev/null
rg -F "Phase 20" .planning/ROADMAP.md >/dev/null
rg -F "verified" .planning/phases/19-hermes-workflow-design/DESIGN.md >/dev/null
rg -F "local-extension" .planning/phases/19-hermes-workflow-design/DESIGN.md >/dev/null
rg -F "unsupported" .planning/phases/19-hermes-workflow-design/DESIGN.md >/dev/null
test -f .planning/phases/20-capability-verification-boundary-lock/20-VERIFICATION.md
'

rtk make test
```

## Validation Sign-Off

- [x] All tasks have automated verify commands.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency stays short for static checks.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-05-10
