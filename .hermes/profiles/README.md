# Project Override Contract

Phase 21 defines repo-local profile overrides in this directory.

Files:

- `{role}.override.yaml` — project-local overrides for `model`, `engine`, and `toolsets.enabled/disabled`
- `{role}.project.md` — project-local SOUL fragment for the role

These files are source inputs only. Generated project-scoped Hermes runtime output is written to:

`{repo}/.hermes/projects/{project_slug}/`

Merge rules:

- `model`: project value replaces base
- `engine.cli/mode/flags/fallback`: field-level deep-merge; project values replace only the declared keys
- `toolsets.enabled/disabled`: merged sets, project value wins on conflict
- `SOUL.md`: assembled in `global -> project -> role` order
