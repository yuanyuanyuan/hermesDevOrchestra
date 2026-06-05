export const meta = {
    name: 'pr33-review',
    description: 'Review PR #33 Conflict Ledger with specialist fan-out and adversarial verification',
    phases: [
        { title: 'Phase 1: Evidence Extraction', detail: 'Extract claims from PR, schema, runtime, tests, docs' },
        { title: 'Phase 2: Specialist Review', detail: 'Fan-out specialist reviewers across 7 dimensions' },
        { title: 'Phase 3: Adversarial Verification', detail: 'Verify findings with skeptical reviewers' },
        { title: 'Phase 4: Test Execution', detail: 'Run and verify tests' },
        { title: 'Phase 5: Final Synthesis', detail: 'Produce maintainer review' },
    ],
}

// ===== PHASE 1: Evidence Extraction (parallel) =====

phase('Phase 1: Evidence Extraction')

const evidence = await parallel([
    // Subagent 1: PR/Sprint intent extractor
    () => agent(
        `You are extracting acceptance claims from PR #33 for the hermesDevOrchestra repository.
Branch: feat/sprint1-conflict-ledger (PR #33)
Base: main

Read these files and extract ALL acceptance claims and requirements:
1. Read the PR description from git: run "git log --format='%B' main..HEAD" to get commit messages
2. Read docs/sprints/prd-compliance-audit-remediation-full/checklist-sprint-1.md
3. Read docs/sprints/prd-compliance-audit-remediation-full/schema.md

Extract specifically:
- Conflict Ledger schema requirements (what fields, what types)
- Severity enum values (exact list)
- Resolution enum values (exact list)
- Closeout blocker semantics (which conflicts block closeout and why)
- accepted_risk requirements (what is required for an accepted_risk record)
- Closeout report requirements (what conflict counts are included)
- Test expectations (what must tests prove)

Return a structured JSON with categories and claims.`,
        {
            label: 'intent-extractor', phase: 'Phase 1: Evidence Extraction', schema: {
                type: 'object',
                properties: {
                    schema_requirements: { type: 'string', description: 'Conflict ledger schema field requirements' },
                    severity_enum: { type: 'array', items: { type: 'string' }, description: 'Allowed severity values' },
                    resolution_enum: { type: 'array', items: { type: 'string' }, description: 'Allowed resolution values' },
                    closeout_blockers: { type: 'string', description: 'Which conflicts block closeout' },
                    accepted_risk_requirements: { type: 'string', description: 'Requirements for accepted_risk records' },
                    report_requirements: { type: 'string', description: 'Closeout report conflict count requirements' },
                    test_expectations: { type: 'string', description: 'What tests must prove' },
                }
            }
        }
    ),

    // Subagent 2: Schema contract extractor
    () => agent(
        `You are extracting the JSON Schema contract from config/schemas/orchestra.full.schema.json.

Read the file config/schemas/orchestra.full.schema.json.

Extract:
1. The root schema dispatch mechanism - how does artifact_type=conflict_ledger get validated?
2. The conflict_ledger definition - all required fields, types, nested schemas
3. The conflict_record definition - all required fields, types, enums
4. The conflict_severity enum - exact values
5. The conflict_resolution enum - exact values
6. The artifact_reference definition
7. The timestamp definition
8. The stage definition (if used)
9. additionalProperties settings throughout
10. schema_version requirement

Also check: Does the root schema correctly dispatch to conflict_ledger when artifact_type is "conflict_ledger"?

Return structured JSON with the actual schema definitions.`,
        {
            label: 'schema-extractor', phase: 'Phase 1: Evidence Extraction', schema: {
                type: 'object',
                properties: {
                    root_dispatch: { type: 'string', description: 'How root schema dispatches by artifact_type' },
                    conflict_ledger_fields: { type: 'string', description: 'Conflict ledger required fields and types' },
                    conflict_record_fields: { type: 'string', description: 'Conflict record required fields and types' },
                    severity_enum: { type: 'array', items: { type: 'string' } },
                    resolution_enum: { type: 'array', items: { type: 'string' } },
                    artifact_reference_def: { type: 'string' },
                    timestamp_def: { type: 'string' },
                    schema_version: { type: 'string' },
                    additional_properties_notes: { type: 'string' },
                }
            }
        }
    ),

    // Subagent 3: Runtime behavior extractor
    () => agent(
        `You are extracting runtime behavior from the conflict ledger implementation.

Read these files:
1. scripts/lib/gateway_closeout.py
2. scripts/lib/orch_gateway.py

For gateway_closeout.py, extract the exact behavior of each function:
- load_conflict_ledger: what happens when file missing? corrupt JSON? empty file?
- validate_conflict_record: what fields are checked? what error messages?
- append_conflict: what preconditions? what happens on duplicate ID? run_id mismatch?
- resolve_conflict: what fields are required? what validation?
- query_open_conflicts: what criteria?
- query_open_high_conflicts: what criteria?
- query_unjustified_accepted_risk: what criteria?
- closeout_conflict_blockers: what blockers are generated?
- conflict_counts: what does it return?
- enrich_closeout_report_conflict_counts: what does it add to the report?

For orch_gateway.py, extract:
- How closeout_completion_blockers calls the conflict ledger check
- What the closeout_audit_checklist looks like
- What blocker IDs are generated

Return structured JSON with exact function behaviors.`,
        {
            label: 'runtime-extractor', phase: 'Phase 1: Evidence Extraction', schema: {
                type: 'object',
                properties: {
                    load_conflict_ledger: { type: 'string', description: 'Behavior when file missing/corrupt/empty' },
                    validate_conflict_record: { type: 'string', description: 'Fields checked and error messages' },
                    append_conflict: { type: 'string', description: 'Preconditions and edge cases' },
                    resolve_conflict: { type: 'string', description: 'Required fields and validation' },
                    query_open_high_conflicts: { type: 'string', description: 'Criteria for open high conflicts' },
                    query_unjustified_accepted_risk: { type: 'string', description: 'Criteria for unjustified accepted_risk' },
                    closeout_conflict_blockers: { type: 'string', description: 'What blockers are generated' },
                    conflict_counts: { type: 'string', description: 'What counts are returned' },
                    enrich_closeout_report: { type: 'string', description: 'What the report enrichment adds' },
                    closeout_integration: { type: 'string', description: 'How closeout_completion_blockers integrates' },
                }
            }
        }
    ),

    // Subagent 4: Test contract extractor
    () => agent(
        `You are extracting what the tests actually prove for PR #33.

Read these files:
1. scripts/tests/test-gateway-conflict-ledger-closeout.sh
2. Search for any other test files that might be related: "grep -rl 'conflict' scripts/tests/ 2>/dev/null" and "grep -rl 'gateway' scripts/tests/ 2>/dev/null"

Extract:
1. Positive tests - what valid inputs are tested and expected to pass?
2. Negative tests - what invalid inputs are tested and expected to fail?
3. Closeout blocker tests - what scenarios block closeout?
4. Schema validation tests - is root schema validation tested?
5. Edge case tests - empty ledger, missing ledger, corrupt ledger, non-list conflicts
6. Conflict count tests - are conflict counts verified?
7. Shell test setup/cleanup behavior - temp dirs, cleanup, determinism
8. What tests are missing that should exist based on the PR intent?

Return structured JSON with test categories and what each test proves.`,
        {
            label: 'test-extractor', phase: 'Phase 1: Evidence Extraction', schema: {
                type: 'object',
                properties: {
                    positive_tests: { type: 'string', description: 'Valid input tests that pass' },
                    negative_tests: { type: 'string', description: 'Invalid input tests that fail' },
                    closeout_blocker_tests: { type: 'string', description: 'Tests for closeout blocking behavior' },
                    schema_validation_tests: { type: 'string', description: 'Tests for root schema validation' },
                    edge_case_tests: { type: 'string', description: 'Tests for edge cases' },
                    conflict_count_tests: { type: 'string', description: 'Tests for conflict count enrichment' },
                    shell_robustness: { type: 'string', description: 'Shell test setup/cleanup quality' },
                    missing_tests: { type: 'string', description: 'Tests that should exist but are missing' },
                }
            }
        }
    ),

    // Subagent 5: Docs consistency extractor
    () => agent(
        `You are extracting documented behavior and checking consistency.

Read these files:
1. docs/sprints/prd-compliance-audit-remediation-full/schema.md
2. docs/sprints/prd-compliance-audit-remediation-full/checklist-sprint-1.md
3. git log --format='%B' main..HEAD (for commit messages / PR body)

Extract:
1. What does schema.md say about conflict_ledger, conflict_record, severity, resolution?
2. What does the checklist say about Sprint 1 requirements?
3. Are there any wording differences between:
   - PR description vs checklist
   - Checklist vs schema.md
   - Schema.md vs actual schema
4. Specifically watch for:
   - "open high conflicts block closeout" vs "open conflicts block closeout"
   - Resolution enum values
   - accepted_risk requirements
   - schema_version string
   - blocker reason string formats

Return structured JSON with consistency findings.`,
        {
            label: 'docs-consistency', phase: 'Phase 1: Evidence Extraction', schema: {
                type: 'object',
                properties: {
                    schema_md_claims: { type: 'string', description: 'What schema.md documents' },
                    checklist_claims: { type: 'string', description: 'What checklist documents' },
                    pr_description_claims: { type: 'string', description: 'What PR description says' },
                    consistency_issues: { type: 'string', description: 'Wording or contract drift found' },
                    severity_resolution_alignment: { type: 'string', description: 'Whether enums are consistent across sources' },
                }
            }
        }
    ),
])

log('Phase 1 complete: Evidence extracted from ' + evidence.filter(Boolean).length + '/5 sources')
