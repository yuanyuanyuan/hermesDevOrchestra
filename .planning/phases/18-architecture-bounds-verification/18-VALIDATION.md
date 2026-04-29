---
phase: 18
slug: architecture-bounds-verification
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-29
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Shell static checks plus existing Makefile aggregate gate |
| Config file | Makefile |
| Quick run command | Phase 18 static drift grep commands |
| Full suite command | rtk make test |
| Estimated runtime | ~20 seconds |

## Sampling Rate

- After every task commit: run the task's static grep check.
- After every plan wave: run rtk make test.
- Before $gsd-verify-work: run all static checks plus rtk make test.
- Max feedback latency: 30 seconds for static checks, ~20 seconds for full suite.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | ARCH-01 | T-18-01 / T-18-02 | Fixed bus cannot be mistaken for same-project multi-task protocol. | static | fixed Runtime bus phrase grep | yes | pending |
| 18-01-02 | 01 | 1 | ARCH-01, ARCH-02 | T-18-03 / T-18-04 | Future parallelism and 10x boundaries are explicit and limited. | static | future-work and 10x phrase grep | yes | pending |
| 18-01-03 | 01 | 1 | ARCH-01, ARCH-02 | T-18-05 / T-18-06 | Milestone evidence exists before requirements are marked complete. | static + suite | rtk make test and traceability grep | yes | pending |

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:

- Makefile exists and provides rtk make test.
- docs/orchestra/scripts/tests/test-file-bus.sh exists.
- docs/orchestra/scripts/tests/test-specs.sh exists.
- Phase 18 context exists.

## Manual-Only Verifications

All Phase 18 behaviors have automated static or suite verification. Manual review is limited to reading Phase 18 verification evidence before running $gsd-complete-milestone.

## Validation Sign-Off

- [x] All tasks have automated verify commands.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 30s for static checks.
- [x] nyquist_compliant: true set in frontmatter.

**Approval:** approved 2026-04-29
