---
phase: 12
slug: risk-decisions-verification-handoff
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-25
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pure Bash custom fixture runner; no external framework. |
| **Config file** | none — tests live under `docs/hermes-dev-orchestra/scripts/tests/`. |
| **Quick run command** | `bash -n docs/hermes-dev-orchestra/scripts/setup.sh && find docs/hermes-dev-orchestra/scripts -type f \( -name 'orch-*' -o -name 'orch-common.sh' \) -print0 \| xargs -0 -r -n1 bash -n` |
| **Full suite command** | `docs/hermes-dev-orchestra/scripts/bin/orch-verify` after setup installation, or `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` before installation. |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick syntax command plus the specific test script for the touched helper or doc.
- **After every plan wave:** Run `docs/hermes-dev-orchestra/scripts/bin/orch-verify` or `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` with fake `PATH` and temporary `HOME`.
- **Before `$gsd-verify-work`:** Full suite must be green and manual live-probe instructions must be documented.
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | SAFE-01 | T-12-01 | Static rulebook floors classify sample operations and cannot be downgraded below L3/L4. | unit/smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | ❌ W0 | ⬜ pending |
| 12-02-01 | 02 | 1 | SAFE-02 | T-12-02 | L3/L4 escalation blocks project continuation until an explicit approve/reject decision exists. | integration smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | ❌ W0 | ⬜ pending |
| 12-02-02 | 02 | 1 | DEC-01 | T-12-03 | Local fallback lists pending decisions and writes approve/reject responses through `orch-*` commands. | integration smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | ❌ W0 | ⬜ pending |
| 12-02-03 | 02 | 1 | DEC-02 | T-12-04 | Approval IDs are one-time, TTL-bound, project-bound, task-bound, and audited. | integration smoke | `bash docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | ❌ W0 | ⬜ pending |
| 12-03-01 | 03 | 3 | VER-01 | T-12-10 | Runner infrastructure and docs fixture verify `orch-verify`, docs, coverage matrix, and handoff linkage. | smoke suite | `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` | ❌ W0 | ⬜ pending |
| 12-04-01 | 04 | 2 | VER-02 | — | README/SOUL/skills document version, install, layout, helpers, scope, and manual checks. | grep/doc check | `bash docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | ❌ W0 | ⬜ pending |
| 12-04-02 | 04 | 2 | VER-03 | — | Coverage matrix separates upstream-native, adapter-provided, and deferred capabilities. | doc check | `test -f docs/COVERAGE-MATRIX.md && rg 'Upstream native|Adapter-provided|Deferred' docs/COVERAGE-MATRIX.md` | ❌ W0 | ⬜ pending |
| 12-04-03 | 04 | 2 | VER-04 | — | Handoff orders remote adapter, audit hardening, isolation, and optional extensions. | doc check | `rg 'remote adapter|audit hardening|isolation|gbrain|dashboard' docs/hermes-dev-orchestra/README.md docs/COVERAGE-MATRIX.md` | ❌ W0 | ⬜ pending |
| 12-05-01 | 05 | 4 | VER-01 | T-12-19 | Functional fixtures cover install/probe, skill load, init/start/status, and file bus routing. | smoke suite | `bash docs/hermes-dev-orchestra/scripts/tests/test-install-probe.sh && bash docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` | ❌ W0 | ⬜ pending |
| 12-05-02 | 05 | 4 | VER-01 | T-12-21 | Risk and decision fixtures cover rule floors, under-classified Claude decisions, approve/reject CLI, and replay protection. | smoke suite | `bash docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh && bash docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `docs/hermes-dev-orchestra/scripts/tests/lib/assert.sh` — shared custom assertions for D-12-04.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/run-all.sh` — package-tree runner used by `orch-verify`.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-install-probe.sh` — covers upstream install/probe and pinned commit evidence.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-skills-load.sh` — covers four custom skills load.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` — covers helper install, init/start/status behavior with fake CLIs.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` — covers task/question/decision routing.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` — covers built-in L3/L4 rule classification and exit codes.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` — covers L3/L4 block and approval/rejection path.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` — covers `orch-decisions`, `orch-approve`, and `orch-reject`.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` — covers one-time, TTL-bound, project/task-bound approval IDs.
- [ ] `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` — covers documentation/handoff grep checks.
- [ ] `docs/hermes-dev-orchestra/scripts/bin/orch-verify` — public aggregate runner installed by setup.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live upstream Hermes/Codex/Claude availability | VER-01 | Local smoke fixtures use fake CLIs to stay deterministic and avoid authenticated agent sessions. | Run `hermes --version`, `codex --version`, and the documented manual probe commands from `docs/hermes-dev-orchestra/README.md` on a real workstation. |
| Remote Decision Channel adapter | DEC-01, DEC-02 | Concrete remote transport is explicitly deferred from v1.1. | Confirm `docs/COVERAGE-MATRIX.md` marks remote adapter work as deferred and `docs/hermes-dev-orchestra/README.md` points to local SSH/CLI fallback. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Feedback latency < 30s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
