# Full Debate Config Is Staged Beside Legacy Runtime Config

The Full Debate Package target configuration will be added under `config/debate/full/` instead of immediately replacing the current root `config/debate/teams.json` and `config/debate/modes.json`. This keeps the MVP/current runtime registry stable while giving the full implementation a concrete target package for schema validation, cutover planning, and future replacement of the legacy runtime files.
