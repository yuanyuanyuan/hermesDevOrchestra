# Sprint 1 Foundation Checklist

## Task 1.1: Full Contract Validation Harness

- [x] `validate_against_full_schema()` function added to `orch-common.sh`
- [x] `validate_artifact_identity()` function added to `orch-common.sh`
- [x] `validate_guardrail_fields()` function added to `orch-common.sh`
- [x] `validate_safe_durable_artifact()` function added to `orch-common.sh`
- [x] Test cases for all validation functions pass

## Task 1.2: Full Contract Readiness Gate Mechanism

- [x] `config/readiness-gates.json` created with 7 artifact families
- [x] `scripts/bin/orch-readiness-gate` script created with check/activate/deactivate/status commands
- [x] Script is executable and tested
- [x] Integration with existing `full-readiness-gates.json` policy

## Task 1.3: Gateway Command Coordination Enhancement (ADR-0007)

- [x] `detect_authority_chain_divergence()` method added to `GatewayApp` class
- [x] Method compares four sources: Kanban, Audit, State refs, Artifact files
- [x] Divergence detection logic implemented
- [x] Repair options generation implemented

## Task 1.4: MVP to Full Configuration Migration Plan

- [x] `docs/migration/mvp-to-full-migration-plan.md` created
- [x] Team ID mapping table defined (16 teams)
- [x] Mode ID mapping table defined (8 modes)
- [x] Migration script interface designed
- [x] Rollback strategy documented
- [x] Test cases defined

## Task 1.5: Sprint 1 Integration Test

- [x] `scripts/tests/test-sprint1-integration.sh` created
- [x] Test 1: Full Contract Validation Harness passes
- [x] Test 2: Readiness Gate Status passes
- [x] Test 3: Readiness Gate Check passes
- [x] Test 4: Readiness Gate Activate/Deactivate passes
- [x] Test 5: Validation Functions pass
- [x] Test 6: Gateway Authority Chain Divergence Detection passes
- [x] Test 7: Migration Plan Document exists and has required sections
- [x] Test 8: Existing Tests Still Pass

## Verification Commands

```bash
rtk bash scripts/tests/test-sprint1-integration.sh
rtk bash scripts/tests/test-full-schema-validation.sh
rtk bash scripts/tests/test-debate-engine.sh
rtk python3 scripts/bin/orch-readiness-gate --repo . status
```

## Sign-off

- [x] Development complete
- [x] All tests pass
- [ ] Code Review complete
- [ ] Merged to main
