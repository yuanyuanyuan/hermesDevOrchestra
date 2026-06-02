# Full Debate Package Team IDs Follow qnN4o510 Registry

The Full Debate Package uses the concrete sixteen-team registry from Get笔记 knowledge base `qnN4o510` as the canonical team id authority: `security`, `compliance`, `data_engineering`, `devops_sre`, `frontend`, `ai_feature`, `scalability_arch`, `chaos_engineering`, `platform`, `privacy_ethics`, `oss_compliance`, `observability`, `business`, `documentation`, `api_design`, and `i18n_l10n`.

We chose the qnN4o510 registry over the current MVP config ids and earlier full-spec aliases because qnN4o510 explicitly records the registry and warns that documentation and registry names can diverge. Existing ids such as `product`, `integration`, `architecture`, `ux`, `testing`, and `release` are treated as legacy or local aliases, review dimensions, or concerns to map into canonical teams, not canonical full-package ids.

## Sprint 5 Alias And Safety Rules

Legacy ids are resolved through `config/debate/full/alias-mapping.json`; aliases are not inferred from free text. Each mapping records `alias`, `canonical_team`, `deprecated_since`, and `migration_note`, so old project profiles can migrate without silently inventing team ids.

Custom teams may extend the canonical 16-team registry for a single project profile, but their `prompt_injection` field is scanned before selection. The scanner blocks filesystem destruction, data destruction, and code execution patterns such as `rm -rf`, `mkfs.`, `DROP TABLE`, `DELETE FROM`, `eval(`, `exec(`, and `subprocess.call`. Blocked custom teams are marked as security-blocked and are not eligible for debate selection.
