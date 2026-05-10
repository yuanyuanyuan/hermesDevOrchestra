---
phase: 21
slug: profiles-overrides-board-isolation
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-10
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Shell static checks + targeted Hermes profile assembly tests + aggregate repo gate |
| Config file | `Makefile` + `docs/orchestra/scripts/tests/*` |
| Quick run command | Phase 21 static greps + targeted `test-profile-packaging.sh` / `test-project-isolation.sh` |
| Full suite command | `rtk make test` |
| Estimated runtime | Static checks < 30s; targeted shell tests about 1-2 min; full suite depends on current repo baseline |

## Sampling Rate

- After every task commit: run that task's static grep or targeted shell test.
- After Task 2 merge/helper work: rerun `test-profile-packaging.sh` before touching docs/traceability.
- After Task 3 isolation wiring: rerun `test-project-isolation.sh`.
- Before `$gsd-verify-work`: run both targeted Phase 21 tests plus `rtk make test`.
- Max feedback latency: 30 seconds for static checks; 2 minutes for targeted shell tests.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | PROF-02 | T-21-01 / T-21-02 | Canonical catalog contains 8 active + 3 reserved profiles, and runtime naming is normalized to `reviewer`. | static | catalog coverage grep | yes | pending |
| 21-01-02 | 01 | 1 | PROF-01, PROF-02 | T-21-03 / T-21-04 | Project override merge compiles to project-scoped runtime output and does not write project customizations into `~/.hermes/profiles/`. | shell + static | `test-profile-packaging.sh` | yes | pending |
| 21-01-03 | 01 | 1 | FLOW-02, MEM-01 | T-21-05 / T-21-06 | `project_slug` drives board/workspace/override/memory naming, and two projects do not share generated runtime state. | shell + static | `test-project-isolation.sh` | yes | pending |
| 21-01-04 | 01 | 1 | PROF-01, PROF-02, FLOW-02, MEM-01 | T-21-07 / T-21-08 | Docs, traceability, and verification evidence match the implemented contract; inherited upstream pin mismatch is not misclassified as a Phase 21 regression. | static + suite | traceability grep + `rtk make test` | yes | pending |

## Wave 0 Requirements

Existing infrastructure is sufficient for Phase 21:

- `21-CONTEXT.md` and `21-DISCUSSION-LOG.md` already exist.
- Phase 20 has already verified Hermes official `profile`, `kanban`, `memory`, `hooks`, and `toolsets` surfaces.
- `reference/hermes-docs-index/` exists and provides the mandatory index-first retrieval flow.
- Current orchestra installer/helpers already exist under `docs/orchestra/scripts/`, so Phase 21 can extend them rather than inventing a second runtime.

Additional Wave 0 assumptions for this phase:

- `reviewer` is the canonical runtime slug; `tech-reviewer` is legacy wording only.
- `.hermes/projects/{project_slug}/` is the generated project runtime root.
- `.hermes/profiles/` is the project override source directory, not the generated runtime directory.

## Manual-Only Verifications

Manual review is limited to:

- Confirming `reviewer` naming is now canonical across runtime artifacts and no longer ambiguous in user-facing docs.
- Confirming reserved profiles cannot be mistaken for active dispatcher targets.
- Confirming `21-VERIFICATION.md` clearly separates inherited `upstream-status` pin mismatch from actual Phase 21 failures.

All other Phase 21 checks should be grep- or shell-test-verifiable.

## Verification Commands

### Task 21-01-01 — canonical catalog coverage

```bash
rtk bash -lc 'set -euo pipefail
root=docs/orchestra/hermes/profile-distribution
test -f "$root/distribution.yaml"
for role in \
  pm \
  orchestrator \
  researcher \
  implementer \
  reviewer \
  qa-tester \
  devops-engineer \
  sre-observer \
  pm-researcher \
  product-designer \
  growth-marketer; do
  test -f "$root/profiles/$role/config.yaml"
  test -f "$root/profiles/$role/SOUL.md"
done
test ! -e "$root/profiles/tech-reviewer"
rg -F "reviewer" "$root/distribution.yaml" >/dev/null
for reserved in pm-researcher product-designer growth-marketer; do
  rg -F "enabled: []" "$root/profiles/$reserved/config.yaml" >/dev/null
  rg -F "model: none" "$root/profiles/$reserved/config.yaml" >/dev/null
done
'
```

### Task 21-01-02 — override merge + no global pollution

```bash
rtk docs/orchestra/scripts/tests/test-profile-packaging.sh
```

This test must, at minimum, prove:

- canonical base + `.hermes/profiles/{role}.override.yaml` merge into project runtime output
- SOUL assembly order is `global -> project -> role`
- no project-specific customization is written into `~/.hermes/profiles/`

### Task 21-01-03 — dual-project isolation

```bash
rtk docs/orchestra/scripts/tests/test-project-isolation.sh
```

This test must, at minimum, prove:

- `alpha` and `beta` generate distinct `.hermes/projects/{slug}/` trees
- `board_slug` is exactly the slug for each project
- `memory_namespace` is exactly `project:{slug}` for each project
- one project's override/SOUL output does not overwrite the other project's generated runtime

### Task 21-01-04 — docs/traceability closeout

```bash
rtk bash -lc 'set -euo pipefail
rg -F "PROF-01" .planning/REQUIREMENTS.md >/dev/null
rg -F "PROF-02" .planning/REQUIREMENTS.md >/dev/null
rg -F "FLOW-02" .planning/REQUIREMENTS.md >/dev/null
rg -F "MEM-01" .planning/REQUIREMENTS.md >/dev/null
rg -F "Phase 21" .planning/ROADMAP.md >/dev/null
rg -F "reviewer" docs/orchestra/README.md docs/orchestra/WORKFLOW.md >/dev/null
test -f .planning/phases/21-profiles-overrides-board-isolation/21-VERIFICATION.md
'

rtk make test
```

If `rtk make test` still fails, `21-VERIFICATION.md` must show whether the failure is:

- a new Phase 21 regression, or
- the inherited `upstream-status` pin mismatch already documented by Phase 20

## Validation Sign-Off

- [x] All tasks have automated verify commands.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency stays short for static checks and targeted shell tests.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-05-10
