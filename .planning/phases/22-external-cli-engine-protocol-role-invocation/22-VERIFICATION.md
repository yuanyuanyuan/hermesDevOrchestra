---
phase: 22-external-cli-engine-protocol-role-invocation
status: passed-with-external-blocker
verified: 2026-05-11
requirements:
  - ENG-01
  - ENG-02
---

# Phase 22 Verification

## Result

Phase 22 scope passed, with the same inherited aggregate-gate blocker already recorded in Phases 20 and 21.

Phase 22 deliverables are complete: the repo now compiles per-role `engine` config into project-scoped Hermes homes, ships a canonical `hermes-role-engine/v1` contract package for `pm` / `implementer` / `reviewer`, and covers failure normalization with fixture-driven smoke tests. Repo-wide `rtk make test` still fails only because of the unrelated `upstream-status` pin mismatch in the local Hermes runtime.

## Requirement Mapping

| Requirement | Result | Evidence |
|-------------|--------|----------|
| ENG-01 | Passed | `docs/orchestra/hermes/profile-distribution/profiles/{pm,implementer,reviewer}/config.yaml` now declare checked-in `engine` defaults, `.hermes/profiles/README.md` documents project override semantics, and `orch-profile-sync` deep-merges `cli/mode/flags/fallback` into `.hermes/projects/{project_slug}/profiles/*/config.yaml` without polluting `~/.hermes/profiles/`. |
| ENG-02 | Passed | `docs/orchestra/hermes/role-engine-protocol/v1/` now contains the shared envelope, role-specific contracts, golden JSON fixtures, and failure-policy fixtures; `test-role-engine-protocol.sh` and `test-role-engine-failure-policy.sh` prove the shared enum, role-specific statuses, compaction rule, and hard-stop parse/schema mismatch behavior. |

## Delivered Artifacts

- `docs/orchestra/hermes/profile-distribution/distribution.yaml`
- `docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml`
- `docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml`
- `docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml`
- `.hermes/profiles/README.md`
- `docs/orchestra/scripts/bin/orch-profile-sync`
- `docs/orchestra/hermes/role-engine-protocol/v1/`
- `docs/orchestra/scripts/tests/test-profile-packaging.sh`
- `docs/orchestra/scripts/tests/test-project-isolation.sh`
- `docs/orchestra/scripts/tests/test-role-engine-protocol.sh`
- `docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh`
- `docs/orchestra/README.md`

## Automated Checks

### Targeted Phase 22 Tests

Commands:

```bash
rtk docs/orchestra/scripts/tests/test-profile-packaging.sh
rtk docs/orchestra/scripts/tests/test-project-isolation.sh
rtk docs/orchestra/scripts/tests/test-role-engine-protocol.sh
rtk docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh
```

Result: Passed.

### Static Contract Checks

Command:

```bash
rtk bash -lc 'set -euo pipefail
rg -F "engine:" docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml >/dev/null
rg -F "engine.cli/mode/flags/fallback" docs/orchestra/README.md .hermes/profiles/README.md >/dev/null
rg -F "hermes-role-engine/v1" docs/orchestra/README.md docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md >/dev/null
rg -F "summary + recent N raw turns" docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md >/dev/null
rg -F "parse_error" docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh >/dev/null
for fixture in pm.request.json pm.response.question.json implementer.request.json implementer.response.complete.json reviewer.request.json reviewer.response.findings.json timeout.retry.json crash.block.json rate_limit.fallback.json parse_error.block.json schema_mismatch.block.json; do
  test -f "docs/orchestra/hermes/role-engine-protocol/v1/examples/$fixture"
done
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
Smoke summary: 14 passed, 0 failed
PASS risk-check
PASS risk-decisions
PASS decision-cli
shellcheck not found; skipping shell lint
repo pin: 023b1bff11c2a01a435f1956a0e2ac1773a065f3
runtime pin: 93e25ceb1326770b369b8c4151cd3b9c3cdc0688
status: mismatch
```

## Scope Confirmation

- Phase 22 extended the existing Phase 21 compiler instead of introducing a second profile assembly path.
- Phase 22 closed the protocol loop only for `pm`, `implementer`, and `reviewer`.
- Phase 22 did not implement Kanban state-machine routing, Orchestrator LLM logic, risk hook enforcement, worker cleanup, or observability persistence.
- The only failing aggregate gate at verification time remains the pre-existing local Hermes runtime pin mismatch surfaced by `upstream-status`.

## Follow-Up

- Resolve the `upstream-status` mismatch before treating `rtk make test` as globally green again.
- The next execution concern is Phase 23: stateful routing and Kanban handoff.

Ready for $gsd-execute-phase closeout.
