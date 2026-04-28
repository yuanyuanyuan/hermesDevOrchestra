---
phase: 17
slug: agent-rules-consolidation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
---

# Phase 17 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash static checks plus root Makefile aggregate |
| **Config file** | `Makefile` |
| **Quick run command** | `rtk bash -lc '<static agent-rule checks>'` |
| **Full suite command** | `rtk make test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run the static agent-rule checks.
- **After every plan wave:** Run `rtk make test`.
- **Before `$gsd-verify-work`:** Static checks and `rtk make test` must both be green.
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 1 | AGNT-01 | T-17-01 / T-17-03 / T-17-04 | `AGENTS.md` preserves managed sections, Dev Orchestra boundaries, helper list, and L3/L4 no-auto-approval wording | static | `rtk bash -lc '<AGENTS.md marker/heading/helper/L3-L4 checks>'` | yes | pending |
| 17-01-02 | 01 | 1 | AGNT-02 | T-17-02 | `CLAUDE.md` remains pointer-only and references `AGENTS.md` plus `.planning/SPEC.md` | static | `rtk bash -lc '<CLAUDE.md authority pointer checks>'` | yes | pending |
| 17-01-03 | 01 | 1 | AGNT-01, AGNT-02 | T-17-01..T-17-04 | Existing smoke/spec/risk/tooling gates still pass after any exact patch | full-suite | `rtk make test` | yes | pending |

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

- `AGENTS.md` exists.
- `CLAUDE.md` exists.
- `Makefile` exists.
- `specs/commands.md` exists.
- `specs/risk-decisions.md` exists.
- `docs/orchestra/scripts/tests/run-all.sh` exists.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 30 seconds.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-04-28 for planning.
