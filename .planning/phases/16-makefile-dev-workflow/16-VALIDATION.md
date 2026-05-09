---
phase: 16
slug: makefile-dev-workflow
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-28
---

# Phase 16 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GNU Make delegating to existing Bash smoke tests, Python stdlib JSON parsing, optional shellcheck |
| **Config file** | `Makefile` |
| **Quick run command** | `make lint-json && make lint-shell && make test-risk` |
| **Full suite command** | `make test-unit && make test-risk && make lint-json && make lint-shell && make upstream-status` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `make lint-json && make lint-shell && make test-risk`.
- **After every plan wave:** Run `make test-unit && make test-risk && make lint-json && make lint-shell && make upstream-status`.
- **Before `$gsd-verify-work`:** The full suite command above must pass, and `git diff --name-only -- Makefile` must show only the intended Makefile change for implementation scope.
- **Max feedback latency:** 90 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | DEV-01 | T-16-01 | Makefile references only real scripts and contains no placeholder integration/e2e targets. | static | `test -f Makefile && ! rg -n "test-integration|test-e2e" Makefile && for script in docs/orchestra/scripts/tests/run-all.sh docs/orchestra/scripts/tests/test-risk-check.sh docs/orchestra/scripts/tests/test-risk-decisions.sh docs/orchestra/scripts/tests/test-decision-cli.sh; do test -f "$script"; done` | no W0 | pending |
| 16-01-02 | 01 | 1 | DEV-02 | T-16-02 | Unit and risk targets run existing smoke/risk fixtures successfully. | make/smoke | `make test-unit && make test-risk` | no W0 | pending |
| 16-01-03 | 01 | 1 | DEV-03 | T-16-03 | JSON lint parses all repo JSON files and shell lint skips cleanly without shellcheck. | make/lint | `make lint-json && make lint-shell` | no W0 | pending |
| 16-01-04 | 01 | 1 | DEV-04 | T-16-04 | Upstream status reports repo-local pin and runtime pin, and compares when runtime checkout exists. | make/status | `make upstream-status` | no W0 | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `Makefile` - root local developer workflow entrypoint.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Makefile target surface stays intentionally small | DEV-01 | Static checks can reject known false targets, but a human should confirm no speculative workflow target slipped in. | Inspect `.PHONY` in `Makefile` and confirm every target has an implemented recipe and maps to Phase 16 success criteria or a direct aggregate of those criteria. |
| `upstream-status` output is understandable | DEV-04 | The command output is user-facing status text, not just exit code behavior. | Run `make upstream-status` and confirm it prints repo pin, runtime path, runtime pin or missing status, and match/mismatch result. |

---

## Validation Sign-Off

- [x] All tasks have automated verification or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 90s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-04-28 for planning input
