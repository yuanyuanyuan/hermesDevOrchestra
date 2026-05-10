---
phase: 21-profiles-overrides-board-isolation
status: passed-with-external-blocker
verified: 2026-05-10
requirements:
  - PROF-01
  - PROF-02
  - FLOW-02
  - MEM-01
---

# Phase 21 Verification

## Result

Phase 21 scope passed, with the same inherited aggregate-gate blocker already recorded in Phase 20.

Phase 21 deliverables are complete: the repo now contains a canonical workflow profile catalog, a repo-local override contract, an assembly helper that generates project-scoped Hermes homes, and targeted smoke tests proving no cross-project bleed. Repo-wide `rtk make test` is still blocked by the unrelated `upstream-status` pin mismatch in the local Hermes runtime.

## Requirement Mapping

| Requirement | Result | Evidence |
|-------------|--------|----------|
| PROF-01 | Passed | `.hermes/profiles/README.md` defines the override contract, `orch-profile-sync` merges `model` and `toolsets`, and `test-profile-packaging.sh` proves the output lands in `.hermes/projects/{project_slug}/` without leaking into `~/.hermes/profiles/`. |
| PROF-02 | Passed | `docs/orchestra/hermes/profile-distribution/` contains 8 active profiles and 3 reserved profiles, all with checked-in `config.yaml` and `SOUL.md`. Reserved profiles remain disabled via `enabled: []` and `model: none`. |
| FLOW-02 | Passed | `orch-init`, `orch-start`, `orch-status`, and `project.json` all derive board/workspace/profile paths from the same `project_slug`; `test-project-isolation.sh` proves two repos generate isolated runtime trees. |
| MEM-01 | Passed | `project.json` records `memory_namespace = project:{project_slug}`, `orch-start` injects `HERMES_MEMORY_NAMESPACE`, and the Phase 21 contract keeps project memory default local while reserving global promotion to orchestrator/user-driven flows. |

## Delivered Artifacts

- `docs/orchestra/hermes/profile-distribution/`
- `.hermes/profiles/README.md`
- `docs/orchestra/scripts/bin/orch-profile-sync`
- `docs/orchestra/scripts/tests/test-profile-packaging.sh`
- `docs/orchestra/scripts/tests/test-project-isolation.sh`
- updated `orch-init`, `orch-start`, `orch-status`, `orch-common.sh`, `setup.sh`

## Automated Checks

### Targeted Phase 21 Tests

Commands:

```bash
rtk docs/orchestra/scripts/tests/test-profile-packaging.sh
rtk docs/orchestra/scripts/tests/test-project-isolation.sh
rtk docs/orchestra/scripts/tests/test-init-start-status.sh
```

Result: Passed.

### Static Contract Checks

Command:

```bash
rtk bash -lc 'set -euo pipefail
root=docs/orchestra/hermes/profile-distribution
test -f "$root/distribution.yaml"
for role in \
  pm orchestrator researcher implementer reviewer qa-tester devops-engineer sre-observer \
  pm-researcher product-designer growth-marketer; do
  test -f "$root/profiles/$role/config.yaml"
  test -f "$root/profiles/$role/SOUL.md"
done
test ! -e "$root/profiles/tech-reviewer"
rg -F ".override.yaml" .hermes/profiles/README.md >/dev/null
'
```

Result: Passed.

### Full Suite

Command:

```bash
rtk make test
```

Result: Failed for an inherited external reason.

Observed output summary:

```text
Smoke summary: 12 passed, 0 failed
PASS risk-check
PASS risk-decisions
PASS decision-cli
shellcheck not found; skipping shell lint
repo pin: 023b1bff11c2a01a435f1956a0e2ac1773a065f3
runtime pin: 93e25ceb1326770b369b8c4151cd3b9c3cdc0688
status: mismatch
```

## Scope Confirmation

- Phase 21 normalized the runtime reviewer slug to `reviewer`.
- Phase 21 did not implement routing logic, risk enforcement, worker cleanup, or observability logic.
- The project-scoped Hermes home is generated inside each repo at `.hermes/projects/{project_slug}/`.
- Two-project isolation is covered by an explicit smoke test, not inferred from naming alone.
- The only aggregate-gate failure remains the previously documented runtime pin mismatch from Phase 20.

## Follow-Up

- Resolve the `upstream-status` mismatch before treating `rtk make test` as globally green again.
- The next execution-phase concern after Phase 21 is Phase 22 routing and Kanban handoff.

Ready for $gsd-execute-phase closeout.
