---
phase: 15
slug: specification-system
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-28
---

# Phase 15 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash smoke tests with repo-local `assert.sh` and optional Python stdlib parsing |
| **Config file** | none |
| **Quick run command** | `bash docs/orchestra/scripts/tests/test-specs.sh` |
| **Full suite command** | `bash docs/orchestra/scripts/tests/run-all.sh` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash docs/orchestra/scripts/tests/test-specs.sh` once the script exists.
- **After every plan wave:** Run `bash docs/orchestra/scripts/tests/run-all.sh`.
- **Before `$gsd-verify-work`:** `docs/orchestra/scripts/bin/orch-verify` or `bash docs/orchestra/scripts/tests/run-all.sh` must pass, and `git status --short -- specs docs/orchestra/scripts/tests/test-specs.sh` must be reviewed.
- **Max feedback latency:** 60 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | SPEC-01 | T-15-01 | `.planning/SPEC.md` remains the only canonical source and every derived spec declares source, consumers, and drift check. | docs/static | `test -f specs/README.md && test -f specs/file-bus.md && test -f specs/risk-decisions.md && test -f specs/commands.md && rg -q --fixed-strings ".planning/SPEC.md" specs/*.md` | no W0 | pending |
| 15-01-02 | 01 | 1 | SPEC-02 | T-15-02 | Every derived spec has a failing conformance check and no unindexed `specs/*.md` file can pass. | smoke | `bash docs/orchestra/scripts/tests/test-specs.sh` | no W0 | pending |
| 15-01-03 | 01 | 1 | SPEC-01, SPEC-02 | T-15-03 | Existing smoke runner reaches spec checks without new Makefile targets. | smoke suite | `bash docs/orchestra/scripts/tests/run-all.sh` | no W0 | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `specs/README.md` - derived spec index and canonical relationship.
- [ ] `specs/file-bus.md` - file-bus derived contract with fixed metadata sections.
- [ ] `specs/risk-decisions.md` - risk and decision derived contract with fixed metadata sections.
- [ ] `specs/commands.md` - command derived contract with fixed metadata sections.
- [ ] `docs/orchestra/scripts/tests/test-specs.sh` - conformance smoke checks for SPEC-01 and SPEC-02.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Derived specs stay intentionally narrow | SPEC-02 | The test can prove files are indexed and consumers exist, but a human should confirm no broad, consumerless spec split slipped in. | Confirm `find specs -maxdepth 1 -type f -name '*.md' | sort` contains only `README.md`, `commands.md`, `file-bus.md`, and `risk-decisions.md`. |
| Phase 15 does not absorb Phase 16 workflow scope | SPEC-02 | Makefile absence is easy to review directly and avoids coupling to the next phase. | Run `git diff --name-only HEAD -- Makefile specs docs/orchestra/scripts/tests/test-specs.sh` and confirm no Makefile was introduced or modified. |

---

## Validation Sign-Off

- [x] All tasks have automated verification or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 60s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-04-28 for planning input
