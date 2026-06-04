# MVP to Full Configuration Migration Plan

**Date:** 2026-06-04
**Status:** Ready for implementation
**Scope:** Migration from MVP debate configuration to Full debate configuration

---

## Overview

This document defines the migration strategy from Hermes Orchestra MVP debate configuration to the Full debate configuration. The migration enables the full 16-team, 8-mode debate system with member-level granularity.

---

## Configuration Differences

### Teams Configuration

| Aspect | MVP (`config/debate/teams.json`) | Full (`config/debate/full/teams.json`) |
|--------|----------------------------------|----------------------------------------|
| Schema Version | `orchestra.v1` | `orchestra.full.v1` |
| Team Count | 16 teams | 16 teams |
| Team Structure | `{id, name, focus}` | `{id, name, focus, dimensions, members}` |
| Member Definition | Not present | Each team has 3+ members with `{id, focus, dimension_refs, checklist_refs, output_requirements}` |
| Package Status | Not present | `package_status: "active"` |
| Registry Authority | Not present | `registry_authority: "qnN4o510"` |

### Modes Configuration

| Aspect | MVP (`config/debate/modes.json`) | Full (`config/debate/full/modes.json`) |
|--------|----------------------------------|----------------------------------------|
| Schema Version | `orchestra.v1` | `orchestra.full.v1` |
| Mode Count | 8 modes | 8 modes |
| Mode Structure | `{id, name, description}` | `{id, name, description, assembly_policy, member_selection, quorum_rules}` |
| Package Status | Not present | `package_status: "active"` |

---

## ID Mapping Table

### Team ID Mapping

| MVP ID | Full ID | Notes |
|--------|---------|-------|
| `architecture` | `scalability_arch` | Renamed for clarity |
| `security` | `security` | Direct match |
| `product` | `business` | Renamed to reflect broader scope |
| `ux` | `frontend` | Renamed to include frontend concerns |
| `data` | `data_engineering` | Renamed for specificity |
| `testing` | `chaos_engineering` | Expanded to include chaos testing |
| `operations` | `devops_sre` | Renamed to reflect SRE practices |
| `reliability` | `platform` | Renamed to reflect platform concerns |
| `performance` | `observability` | Renamed to include monitoring |
| `maintainability` | `ai_feature` | Renamed to reflect AI features |
| `integration` | `api_design` | Renamed for API focus |
| `privacy` | `privacy_ethics` | Expanded to include ethics |
| `compliance` | `compliance` | Direct match |
| `devex` | `oss_compliance` | Renamed for OSS focus |
| `documentation` | `documentation` | Direct match |
| `release` | `i18n_l10n` | Renamed for internationalization |

### Mode ID Mapping

| MVP ID | Full ID | Notes |
|--------|---------|-------|
| `sequential_review` | `sequential_review` | Direct match |
| `parallel_debate` | `parallel_debate` | Direct match |
| `adversarial_debate` | `adversarial_debate` | Direct match |
| `jury_panel` | `jury_panel` | Direct match |
| `dynamic_assembly` | `dynamic_assembly` | Direct match |
| `meta_review` | `meta_review` | Direct match |
| `risk_priority_matrix` | `risk_priority_matrix` | Direct match |
| `cross_team_conflict_detector` | `cross_team_conflict_detector` | Direct match |

---

## Migration Script Interface

### Script: `scripts/bin/orch-migrate-debate-config`

**Usage:**
```bash
orch-migrate-debate-config --repo <path> [--dry-run] [--rollback]
```

**Options:**
- `--repo <path>`: Repository root path
- `--dry-run`: Show what would be migrated without making changes
- `--rollback`: Revert to MVP configuration

**Behavior:**
1. Validate MVP configuration files exist and are valid
2. Validate Full configuration files exist and are valid
3. Generate migration report showing ID mappings
4. Create backup of MVP configuration
5. Update Gateway to use Full configuration
6. Verify migration success

---

## Rollback Strategy

### Automatic Rollback Triggers
- Full configuration validation fails
- Gateway fails to start with Full configuration
- Critical tests fail after migration

### Manual Rollback Steps
1. Restore MVP configuration from backup
2. Restart Gateway
3. Verify MVP functionality
4. Document rollback reason

### Backup Location
```
config/debate/backup/<timestamp>/
  teams.json
  modes.json
  coverage-policy.json
  assembly-policy.json
  backend-policy.json
```

---

## Test Cases

### Migration Validation Tests
1. **ID Mapping Correctness**: Verify all MVP team IDs map to valid Full team IDs
2. **Configuration Integrity**: Verify Full configuration files are valid JSON
3. **Schema Compliance**: Verify Full configuration complies with `orchestra.full.schema.json`
4. **Gateway Startup**: Verify Gateway starts successfully with Full configuration
5. **Debate Execution**: Verify debate execution works with Full configuration

### Rollback Tests
1. **Rollback Capability**: Verify rollback to MVP configuration works
2. **Data Preservation**: Verify debate artifacts are preserved during rollback
3. **Gateway Recovery**: Verify Gateway recovers after rollback

---

## Implementation Steps

### Phase 1: Preparation
1. Create backup of current MVP configuration
2. Validate Full configuration files
3. Generate migration report

### Phase 2: Migration
1. Update Gateway configuration to use Full debate package
2. Restart Gateway
3. Verify Gateway health

### Phase 3: Validation
1. Run debate engine tests
2. Run integration tests
3. Verify debate execution with Full configuration

### Phase 4: Documentation
1. Update configuration documentation
2. Document migration process
3. Update troubleshooting guides

---

## Risk Mitigation

### High Risk: Configuration Incompatibility
- **Mitigation**: Validate Full configuration against schema before migration
- **Fallback**: Automatic rollback to MVP configuration

### Medium Risk: Gateway Startup Failure
- **Mitigation**: Test Gateway startup in isolated environment first
- **Fallback**: Restore MVP configuration and restart

### Low Risk: Debate Execution Issues
- **Mitigation**: Run comprehensive debate tests after migration
- **Fallback**: Rollback to MVP configuration

---

## Success Criteria

1. All 16 teams are properly mapped from MVP to Full
2. All 8 modes are properly mapped from MVP to Full
3. Gateway starts successfully with Full configuration
4. Debate execution works with Full configuration
5. Rollback capability is verified
6. All tests pass after migration

---

**Plan created:** 2026-06-04
**Next review:** After Sprint 1 completion
