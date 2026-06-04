# Sprint 9 Checklist: Intake Completeness And E-Class Mini-Debate

## Architecture Redlines

- [ ] Intake additions remain in projection/discovery helpers.
- [ ] E-class debate uses debate engine path, not hardcoded reviewer choice.

## Functional Acceptance

- [ ] CI/CD detection covers `.github/workflows/`, `ci/`, common deploy config files.
- [ ] `prompt_envelope` has 8 non-empty PRD sections.
- [ ] Bundle has `verified_facts[]` and `unverified_assumptions[]`.
- [ ] E-class consensus below 0.60 blocks.

## Test Coverage

- [ ] `bash scripts/tests/test-intake-completion-prd-fields.sh`
- [ ] `bash scripts/tests/test-improvement-e-class-mini-debate.sh`
- [ ] Negative: missing prompt section.
- [ ] Negative: no E debate refs.

## Docs/Schema Sync

- [ ] Completion bundle schema updated.
- [ ] User flow docs reflect fact/assumption split.

