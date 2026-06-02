# Dynamic Debate Assembly Uses Deterministic Policy

Dynamic Debate Assembly will use `config/debate/full/assembly-policy.json` instead of allowing a model or backend adapter to freely choose debate teams. The selector starts from stage floor coverage, adds task-type overlays, adds L1-L4 risk overlays, applies only coverage-increasing project overrides, and then selects members through stable scoring and registry-order tie breaking. This makes debate coverage reproducible, testable, and auditable: Debate Audit Trails must record the assembly input, matched rules, overlays, selected and skipped teams, selected members, and member scoring summaries.

## Sprint 5 Direction Gate And Team Limits

Direction debate tickets distinguish hard constraints from soft preferences. A conclusion that attempts to override a hard constraint returns `verdict: blocked` with `reason: hard_constraint_violation`; soft constraints may be overridden only when an `override_reason` is recorded.

The selector reads `project_profile.max_teams` for the total team cap. The default is 16, the minimum is 1, and the hard limit is 64. Values above 64 are rejected with `config_error: max_teams exceeds hard limit 64`; they are not silently truncated. High-confidence direction conclusions advance to phase 2 only when confidence is at least 0.8, risk is low, and no conflicts are present.
