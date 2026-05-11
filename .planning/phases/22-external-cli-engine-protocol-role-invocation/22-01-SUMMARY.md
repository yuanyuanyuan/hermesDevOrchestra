# Phase 22 Plan 01 Summary

## One-Line Summary

Implemented the Phase 22 external CLI engine contract by compiling per-role `engine` settings into project-scoped Hermes profiles, shipping the canonical `hermes-role-engine/v1` protocol package, and proving failure normalization with fixture-driven tests.

## Delivered

- Extended the Phase 21 profile assembly path so checked-in role configs can declare `engine.cli/mode/flags/fallback` and project overrides deep-merge those fields without polluting `~/.hermes/profiles/`.
- Added the `docs/orchestra/hermes/role-engine-protocol/v1/` contract package with one shared envelope plus role-specific contracts and JSON fixtures for `pm`, `implementer`, and `reviewer`.
- Added smoke coverage for profile packaging, project isolation, protocol conformance, and failure-policy normalization.
- Wrote `22-VERIFICATION.md` and updated docs/traceability for ENG-01 and ENG-02.

## Verification

- Passed: `rtk docs/orchestra/scripts/tests/test-profile-packaging.sh`
- Passed: `rtk docs/orchestra/scripts/tests/test-project-isolation.sh`
- Passed: `rtk docs/orchestra/scripts/tests/test-role-engine-protocol.sh`
- Passed: `rtk docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh`
- Passed: Phase 22 static contract checks recorded in `22-VERIFICATION.md`
- Pending global green: `rtk make test` still inherits the known `upstream-status` runtime pin mismatch already carried from earlier phases

## Next Phase Readiness

Phase 22 is closed out. The next workflow step is Phase 23 context gathering for stateful routing and Kanban handoff, while keeping the inherited `upstream-status` mismatch tracked as an external blocker rather than a Phase 22 regression.
