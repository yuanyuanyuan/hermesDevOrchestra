---
phase: 14
slug: migration-submodule-adr
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-28
---

# Phase 14 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash smoke fixtures plus grep/JSON/Git checks |
| **Config file** | none |
| **Quick run command** | `! rg -n "docs/hermes-dev-orchestra" README.md AGENTS.md CLAUDE.md docs .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md && python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null` |
| **Full suite command** | `bash docs/orchestra/scripts/tests/run-all.sh` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command for actionable old-path residue and manifest JSON validity.
- **After every plan wave:** Run `bash docs/orchestra/scripts/tests/run-all.sh` plus shell syntax checks for `docs/orchestra/scripts`.
- **Before `$gsd-verify-work`:** Full suite must be green, ADR/manifest checks must pass, and `git status --short` must be reviewed.
- **Max feedback latency:** 60 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | MIGR-02 | T-14-01 | N/A | git/grep | `git status --short -- docs/hermes-dev-orchestra docs/orchestra && ! rg -n "docs/hermes-dev-orchestra" README.md AGENTS.md CLAUDE.md docs .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md` | no W0 | pending |
| 14-01-02 | 01 | 1 | MIGR-02 | T-14-02 | N/A | shell/smoke | `while IFS= read -r f; do bash -n "$f"; done < <(find docs/orchestra/scripts -type f \( -name "*.sh" -o -path "*/scripts/bin/orch-*" \) -print \| sort) && bash docs/orchestra/scripts/tests/run-all.sh` | no W0 | pending |
| 14-01-03 | 01 | 1 | UPST-01 | T-14-03 | Manifest is parseable and repo-local | doc/json | `python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null && rg -q --fixed-strings "installer/probe pin" .planning/adr/ADR-001-upstream-pin.md && rg -q --fixed-strings "git submodule" .planning/adr/ADR-001-upstream-pin.md && rg -q --fixed-strings "manifest pin" .planning/adr/ADR-001-upstream-pin.md && rg -q --fixed-strings "vendor snapshot" .planning/adr/ADR-001-upstream-pin.md` | no W0 | pending |
| 14-01-04 | 01 | 1 | UPST-02 | T-14-04 | No accidental submodule artifacts | git/doc | `rg -q --fixed-strings "UPST-02" .planning/adr/ADR-001-upstream-pin.md && rg -q --fixed-strings "not applicable" .planning/adr/ADR-001-upstream-pin.md && rg -q --fixed-strings "manifest pin" .planning/adr/ADR-001-upstream-pin.md && test ! -f .gitmodules && ! git ls-files --stage \| grep -q '^160000 '` | no W0 | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `docs/orchestra/scripts/tests/run-all.sh` - exists only after `git mv docs/hermes-dev-orchestra docs/orchestra`.
- [ ] `.planning/upstream/hermes-agent-pin.json` - created before manifest JSON validation can pass.
- [ ] `.planning/adr/ADR-001-upstream-pin.md` - created before UPST-01 and UPST-02 documentation checks can pass.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Historical old-path residuals are audit-only | MIGR-02 | A broad hidden grep may include historical phase evidence that should not be rewritten blindly. | Run `rg --hidden -n "docs/hermes-dev-orchestra" --glob '!/.git/*' --glob '!*.zip'` and confirm remaining matches are historical records or intentionally documented exceptions. |
| Worktree contains unrelated backlog changes | MIGR-02 | Existing unrelated changes must not be mixed into Phase 14 execution commits. | Run `git status --short --branch` and confirm Phase 14 changes are distinguishable from pre-existing backlog paths. |

---

## Validation Sign-Off

- [x] All tasks have automated verification or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 60s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-04-28 for planning input
