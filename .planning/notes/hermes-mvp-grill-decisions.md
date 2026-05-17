# Hermes MVP Grill Decisions

Date: 2026-05-16
Background reference used during discussion: Get笔记 knowledge base `qnN4o510`

## Purpose

Record the agreed design constraints from the grill-me discussion before implementation planning continues.

This note is not the final implementation plan. It captures decisions that future plans must preserve unless explicitly superseded.

## Background Premise

The MVP discussion used `qnN4o510` as temporary background context. It is not part of the runtime architecture unless a later decision explicitly adds an external knowledge-source integration.

The implementation premise remains:

- Kimi is the upper orchestration layer for intent understanding, task decomposition, progress supervision, result acceptance, and experience audit.
- Hermes Gateway on port 8642 is the communication/API entry layer.
- Hermes-Agent plus Kanban is the execution framework layer and canonical task lifecycle substrate.
- Debate teams form the decision engine layer.
- Local project knowledge base plus local filesystem cache form the MVP data support layer. Redis is only a future optional cache adapter.
- The top-level workflow is the six-stage R&D loop: direction debate, solution debate, implementation, improvement, global evaluation, continuous improvement.
- Harness Engineering and AI automated testing are supporting subflows under the six-stage loop, not competing top-level workflows.
- Extensions should avoid forking upstream Hermes-Agent.
- Get笔记 is not a current MVP runtime dependency.

## Agreed Decisions

1. Build a complete vertical MVP, not a production-hardened full system.

2. Every major layer and workflow must exist and run through the happy path:
   Gateway, Kanban, CLI workers, debate, knowledge/cache, six-stage workflow, Harness subflow, AI testing subflow, and audit.

3. Use Hermes Kanban as the canonical task state source.

4. Keep the existing file bus as a compatibility/execution channel for CLI workers, not as the main task store.

5. Treat Kimi as an external upper orchestrator, not as logic embedded into the Hermes execution core.

6. Implement Gateway MVP as a project-local adapter around official Hermes API Server/Gateway capabilities on port 8642. Do not fork upstream Hermes-Agent.

7. Use the six-stage R&D loop as the canonical top-level DAG:
   `direction_debate -> solution_debate -> implementation -> improvement -> global_evaluation -> continuous_improvement`.

8. Treat the existing `pm -> implementer -> reviewer -> qa(optional)` chain as an engineering sub-DAG inside implementation and parts of improvement, not as the top-level workflow.

9. Model CLI worker dispatch by stable role capability, not fixed tool names:
   `planner/reviewer`, `implementer`, and `debater` are roles; `kimi`, `claude`, `codex`, `deepseek`, or API models are replaceable backends.

10. The implementer/reviewer pairing is configurable per workflow run. Valid MVP examples include `codex` implementing with `claude` reviewing, or `claude` implementing with `codex` reviewing.

11. Get笔记 `qnN4o510` is only a planning/reference input for this discussion. The MVP must not depend on Get笔记 APIs at runtime.

12. Gateway MVP exposes workflow-run APIs to Kimi, not low-level Kanban CRUD:
   `POST /orchestra/runs`, `GET /orchestra/runs/{run_id}`, `GET /orchestra/runs/{run_id}/events`, `GET /orchestra/runs/{run_id}/tasks`, `POST /orchestra/runs/{run_id}/stop`, `POST /orchestra/decisions/{decision_id}`, `GET /orchestra/capabilities`, and `GET /health`.

13. `POST /orchestra/runs` accepts a short `intent` and optional structured `ticket`. Internally the Gateway must normalize all input into a structured ticket before the six-stage workflow starts. Kimi should prefer sending the structured ticket.

14. Each six-stage workflow run must emit fixed JSON artifacts:
   `best_choice_report.json`, `implementation_plan_report.json`, `task_feedback_report.json`, `improvement_report.json`, `global_evaluation_report.json`, and `iteration_closeout_report.json`.

15. Artifact storage is layered:
   State stores resumable runtime state; Audit stores immutable stage reports; Cache stores rebuildable high-frequency results; the project repository only stores long-lived engineering knowledge under `.workflow/knowledge/`.

16. Register all 16 debate teams and 8 debate modes in configuration, but route dynamically per task. MVP does not need to invoke every team on every run.

17. Debate output is a strong input, not the final authority. Kimi makes the final call. Low-risk decisions may auto-advance; high-risk, conflicting, irreversible, or over-budget decisions must block for user confirmation.

18. Redis is not required for MVP. The MVP cache implementation is local filesystem cache under `~/.cache/hermes-orchestra/{project}/`. Redis remains only a future optional optimization adapter.

19. The local knowledge base means only `{project_dir}/.workflow/knowledge/`. Get笔记 is not a runtime knowledge source for this MVP.

20. Harness `workflow-init` MVP writes these project knowledge artifacts:
   `.workflow/knowledge/project-summary.json`, `tech-stack.json`, `api-surface.json`, `module-map.json`, `coding-rules.json`, `test-strategy.json`, `risk-notes.json`, and `update-manifest.json`.

21. Harness initialization must not automatically overwrite root `AGENTS.md`, `CLAUDE.md`, or `SOUL.md`. It can generate knowledge artifacts and later propose changes through audit/review.

22. `prd-preprocess` writes a run-scoped `structured_prd.json` artifact containing requirement summary, clarification log, touched modules, decomposed requirements, acceptance criteria, constraints, risks, and input artifact references.

23. `dev-workflow-plan` writes a run-scoped `development_plan.json` artifact containing execution mode (`full`, `layout-only`, or `none`), child task DAG, whether D2C/Dev is enabled, `logic_hints_ref`, worker assignment, test strategy, rollback checkpoints, and acceptance criteria.

24. `development_plan.json` is the bridge from `solution_debate` to `implementation` and must be referenced by `implementation_plan_report.json`.

25. MVP defaults to `mode: none` for standard logic development. `mode: full` is enabled only when UI/design input exists. `layout-only` is supported as a non-default path.

26. Kanban task hierarchy:
   one workflow run creates one top-level parent task bound to `metadata.run_id`; the six canonical stages are child stage tasks; implementation stage tasks may create engineering child tasks such as `prd_preprocess`, `dev_workflow_plan`, `code_task_*`, `review_task_*`, and `qa_task_*`.

27. Kanban stores task state, dependencies, assignee, metadata, and artifact references only. Large reports and JSON artifacts are stored in State/Audit and referenced from Kanban, not embedded in task body.

28. Gateway exposes run/task/event projections to Kimi and maps them internally to Kanban tasks. It does not expose raw Kanban CRUD as the primary Kimi API.

29. Do not extend Hermes Kanban native task statuses for six-stage workflow semantics. Keep native statuses such as `triage`, `todo`, `ready`, `running`, `blocked`, `done`, and `archived`; store six-stage semantics in metadata fields such as `run_id`, `workflow_stage`, `stage_index`, `stage_status`, `artifact_refs`, `approval_required`, and `risk_level`.

30. MVP Kanban task schema is thin and fixed:
   top-level fields are `task_id`, `title`, `body`, `assignee`, `parents`, `priority`, and `tenant`; project workflow semantics live under `metadata` with at least `run_id`, `task_kind`, `workflow_stage`, `stage_index`, `role`, `backend_preference`, `artifact_refs`, `approval_required`, `risk_level`, and `resume_policy`.

31. `body` stores only a short task summary. Detailed context, reports, and recovery data must be referenced through `metadata.artifact_refs`.

32. `correlation_id` is trace-only and must not become recovery authority. Recovery authority comes from Hermes Kanban lifecycle plus Gateway State, State Artifacts, and Audit Artifacts.

33. Gateway run events are append-only and recoverable. Their primary store is Gateway State, for example `STATE_ROOT/{project}/runs/{run_id}/events.jsonl`. `GET /orchestra/runs/{run_id}/events` supports paginated JSON with `since_seq` and `limit`, and SSE streaming when `Accept: text/event-stream` is used.

34. MVP event schema includes `seq`, `timestamp`, `run_id`, `task_id`, `stage`, `type`, `severity`, `status`, `message`, `artifact_refs`, and `decision_id`.

35. MVP event types are fixed to:
   `run_created`, `ticket_normalized`, `stage_started`, `stage_completed`, `task_created`, `task_started`, `task_blocked`, `task_completed`, `artifact_written`, `decision_required`, `decision_resolved`, `cache_degraded`, `debate_degraded`, `run_failed`, `run_stopped`, and `run_completed`.

36. Gateway events may be normalized from Kanban status changes, `audit.jsonl`, and lifecycle traces, but Gateway must not expose internal files directly as its API contract.

37. Gateway decisions support only `approve`, `reject`, and `revise` actions in MVP.

37a. Stopping a run uses `POST /orchestra/runs/{run_id}/stop`, not a fourth decision action. Stop audit may link a pending decision ref but must not mark that decision approved, rejected, or revised.

38. Decision lifecycle is `pending -> approved | rejected | revised | expired`.

39. `decision_required` is triggered by high risk, unresolved debate conflict, irreversible operations, external publishing, budget/time overrun, repeated worker failure, schema validation failure, or missing critical artifacts.

40. Decision effects:
   `approve` resumes the original task from artifact refs; `reject` blocks or fails the current task/stage and writes audit; `revise` creates a revised child task without overwriting original artifacts; `expired` never auto-approves and keeps the workflow blocked.

40a. `approve` and `revise` operate only on active blocked runs. `revise` creates a revised child task or stage attempt with `revision_of` and source artifact refs.

40b. `failed` and `stopped` terminal runs cannot be resumed in place in MVP.

41. Debate teams and debate modes are configuration registries, not hard-coded workflow branches. MVP should include `config/debate/teams.json` and `config/debate/modes.json`.

42. The debate team registry must fully express all 16 teams, including whether a team is enabled, its domains, default modes, and risk weight.

43. The debate mode registry must fully express all 8 modes, including max teams, whether execution is parallel, timeout, and any decision rule.

44. Debate routing defaults:
   `direction_debate` uses `dynamic_assembly` plus `jury_panel`; `solution_debate` uses `sequential_review` plus `risk_priority_matrix`; `improvement` uses `risk_priority_matrix` over feedback-relevant teams; `global_evaluation` uses `parallel_debate`; strong conflicts add `cross_team_conflict_detector` or `meta_review`.

45. MVP may start with a template-driven debater backend, but the registry must be backend-neutral so MiniMax/API-backed debate can replace it without changing workflow semantics.

46. Every debate invocation writes a fixed `debate_report.json` that is referenced by the corresponding stage report.

47. `debate_report.json` includes at least `debate_id`, `run_id`, `stage`, `mode`, `teams`, `question`, `options`, `findings`, `risks`, `conflicts`, `verdict`, `confidence`, `risk_level`, `requires_kimi_decision`, `recommended_next_actions`, and `artifact_refs`.

48. Debate auto-advance threshold:
   `confidence >= 0.75`, `risk_level <= medium`, and no conflicts. Kimi still records acceptance.

49. Debate must block or require follow-up when risk is high/critical, conflicts remain after conflict/meta review, verdict is `reject` or `modify`, schema validation fails, or critical fields are missing.

50. Cache stores only rebuildable results and never stores canonical state.

51. MVP cache objects:
   `debate_result` with 24h TTL, `knowledge_summary` with 6h TTL, `test_plan` with 24h TTL, `capabilities` with 5m TTL, and `gateway_projection` with 30s TTL.

52. Cache keys use `hermes:mvp:{project_slug}:{cache_type}:{sha256}`, where the hash includes the relevant project, input, manifest, team/mode, scope, or backend version dimensions for that cache type.

53. MVP does not require Redis. The default cache backend is local filesystem cache under `~/.cache/hermes-orchestra/{project}/cache-index.json` plus blob files.

54. Cache misses recompute normally. Cache hits are recorded in internal trace but not exposed as default run events.

55. Approval state, Kanban canonical task state, immutable Audit artifacts, and sensitive raw user input must not be cached.

56. Redis remains an optional future cache adapter. If configured later and unavailable, Gateway emits `cache_degraded`, falls back to local filesystem cache, and continues.

57. Worker backend dispatch is registry-driven and must not be hard-coded in workflow logic. MVP should include `config/workers/backends.json` and `config/workers/roles.json`.

58. Backend registry entries include whether the backend is enabled, CLI command, supported modes, capabilities, and health command.

59. Role registry entries include required capabilities, preferred backends, and explicit fallback backends.

60. Each workflow run may override the implementer/reviewer pairing. MVP default pairing is `implementer=codex` and `reviewer=claude` because those CLIs are available in the current environment.

61. `GET /orchestra/capabilities` returns actual backend availability, versions, missing dependencies, and role-to-backend mapping.

62. Backend fallback is allowed only when configured, and every fallback activation must be written to Audit. DeepSeek is disabled or absent in MVP unless detected as installed.

63. MVP worker execution isolation:
   code tasks may modify the current project repository directly, but each task must have a run/task-scoped state artifact directory under `STATE_ROOT/{project}/runs/{run_id}/tasks/{task_id}/`.

64. Before a real CLI worker starts, record baseline `git status --short` and an environment snapshot. After completion, record changed files, diff summary, test commands, and test results.

65. Independent git worktree or container isolation is deferred for MVP. This is an explicit MVP downgrade from the ideal workspace isolation model, accepted to get a real Codex/Claude execution loop working first.

66. Worker input must use the `hermes-role-engine/v1` envelope and worker output must be structured JSON. `schema_mismatch` blocks the task.

67. Reviewer must inspect implementer artifact refs and git diff, not only the implementer natural-language summary.

68. If the repository is dirty before a task starts, the baseline dirty state must be recorded so pre-existing user changes are not attributed to the worker.

69. AI automated testing MVP must produce and execute a minimal test chain, but does not need to integrate an external UI automation platform or modify CI automatically.

70. Testing artifacts:
   `test_plan.json`, `test_execution_report.json`, optional `generated_test_script_ref`, conditional `test_fix_report.json`, and `ci_recommendation.json`.

71. If the project has an existing test entrypoint, run it first. For this project, the existing entrypoint is `make test`. If no test entrypoint exists, generate and run a minimal smoke test script.

72. Playwright is enabled only for UI/frontend tasks. Non-UI tasks must not pull in Playwright just to satisfy the testing workflow.

73. AI Mock MVP supports only static mock/spec fixtures. MCP dynamic injection, UI automation platform verification, and automatic CI wiring are outside MVP.

74. Test plans are human-reviewable artifacts. Low-risk happy-path test plans may be auto-approved by Kimi in MVP.

75. The MVP Gateway adapter owns `127.0.0.1:8642` as the single external entrypoint.

76. The official Hermes API Server should run behind the adapter on an internal configurable URL, for example `http://127.0.0.1:8643`, exposed through `HERMES_UPSTREAM_API_URL`.

77. Gateway adapter handles `/orchestra/*` itself, exposes adapter `/health`, and reverse-proxies `/v1/*` to the official Hermes API Server.

78. This preserves the no-fork boundary while allowing the project to add six-stage workflow APIs beside OpenAI-compatible Hermes APIs.

79. Gateway adapter MVP uses Python standard library `http.server` with a small project-local router, not FastAPI/Flask.

80. Gateway entrypoint is `scripts/bin/orch-gateway`; implementation lives in `scripts/lib/orch_gateway.py`; tests live in `scripts/tests/test-gateway-api.sh`.

81. Gateway listens on `ORCHESTRA_GATEWAY_HOST` default `127.0.0.1` and `ORCHESTRA_GATEWAY_PORT` default `8642`.

82. Framework migration such as FastAPI is deferred until the API surface becomes too large for the standard-library adapter.

83. Run artifact directories are fixed:
   `STATE_ROOT/{project}/runs/{run_id}/` for resumable state and events, `AUDIT_ROOT/{project}/runs/{run_id}/` for immutable reports, `CACHE_ROOT/{project}/` for local cache index and blobs, and `{project_dir}/.workflow/knowledge/` for long-lived project knowledge.

84. Gateway returns artifact URIs instead of raw absolute paths:
   `state://{project}/{run_id}/...`, `audit://{project}/{run_id}/...`, `cache://{project}/{sha256}`, and `repo://.workflow/knowledge/...`.

85. Artifact URI resolver must validate project/run scope and prevent path traversal.

86. Audit artifacts are immutable. Revisions write new versions or child artifacts instead of overwriting previous reports.

87. Harness `workflow-init` scans only engineering-relevant project files and generates `.workflow/knowledge/*`; it does not modify root `AGENTS.md`, `CLAUDE.md`, or `SOUL.md`.

88. `workflow-init` included inputs:
   root engineering files such as `README.md`, `Makefile`, `package.json`, `AGENTS.md`, `CLAUDE.md`, `hermes/SOUL.md`; key directories `scripts/`, `hermes/`, `skills/`, `specs/`, `docs/`; read-only summaries from `reference/hermes-docs-index/`; and CodeMap summaries such as `.mycodemap/AI_MAP.md` and `.mycodemap/env-contract.json`.

89. `workflow-init` excluded inputs:
   `.git/`, `.planning/`, `.tmp_index_work/`, State/Audit/Cache roots, zip files, large logs, generated batch files, historical archives, and secrets such as keys, tokens, and `.env`.

90. `knowledge-update` is explicitly triggered in MVP and uses `update-manifest.json` hash/mtime differences to update only affected `.workflow/knowledge/*` JSON files.

91. Changes to root `AGENTS.md`, `CLAUDE.md`, or `hermes/SOUL.md` cause rules to be re-extracted, but `knowledge-update` must not modify those files.

92. Secrets, `.env`, and oversized files are skipped during knowledge update and recorded as warnings in `risk-notes.json`.

93. Each knowledge update writes a new `update-manifest.json` and records a `knowledge_updated` audit event.

94. If Gateway detects stale knowledge during run creation, it may emit a `knowledge_stale` warning but must not block the MVP happy path.

95. Stage 4 `improvement` may fix code issues raised by reviewer/QA/test feedback, add or fix tests, repair artifact gaps, and correct implementation drift within the approved `development_plan.json` scope.

95a. Stage 4 automatic improvement is limited to one cycle per run by default.

95b. Automatic improvement may fix only review, QA, or test findings inside the approved `development_plan.json` scope. It must not expand requirements, change architecture direction, change risk policy, modify worker backend config, modify debate routing config, modify Gateway/runtime configuration, or touch Human Approval targets.

95c. Each automatic improvement writes `improvement_report.json` with source feedback refs, failure class, scope assessment, changed files, diff summary, tests run, test results, and re-review/re-test refs.

95d. Improvement output must trigger re-review and/or re-test for the original failing criteria before advancement.

95e. If re-review, QA, or tests still fail after one automatic improvement cycle, the run becomes `blocked` and emits a decision requirement. Kimi or Human Approval then chooses `revise`, chooses `reject`, or requests stop through the run stop endpoint according to authority routing.

95f. Stage 5 `global_evaluation` is an independent audit stage before Stage 6 closeout.

95g. Global evaluation must read structured PRD, development plan, debate reports, implementation evidence, review/QA verdicts, test execution reports, improvement reports, downgrade records, unresolved decision records, and relevant Audit entries.

95h. Global evaluation writes `global_evaluation_report.json` with verdict enum `pass | pass_with_warnings | fail | block`.

95i. `pass` may proceed to Stage 6 after Gateway Advancement Gate validation. `pass_with_warnings` requires Kimi Final Acceptance and recorded warning rationale before Stage 6.

95j. `fail` may return to bounded Stage 4 improvement only if automatic improvement budget remains, findings are inside approved `development_plan.json` scope, and no human-risk gate is hit. Otherwise it blocks and emits a decision requirement.

95k. `block` routes to Kimi or Human Approval according to the decision authority chain.

95l. Kimi is final acceptance authority only for low/medium risk. Kimi must not override L3/L4, schema failure, test failure, write-scope violation, security boundary, forbidden target, or Human Approval boundary.

95m. Stage 6 `continuous_improvement` must not start until global evaluation is `pass` or Kimi-accepted `pass_with_warnings`.

96. Stage 6 `continuous_improvement` MVP is intentionally constrained:
   it always writes `iteration_closeout_report.json`; may auto-update low-risk `.workflow/knowledge/*`; may generate suggested patches for worker config, debate routing config, or workflow configuration; but must not automatically modify root `AGENTS.md`, `CLAUDE.md`, `SOUL.md`, CI/CD, install scripts, or permission/risk policy.

97. High-risk configuration changes from continuous improvement must trigger `decision_required`.

98. Failure classes are normalized as:
   `timeout`, `crash`, `rate_limit`, `parse_error`, `schema_mismatch`, `test_failed`, `review_changes_requested`, `review_rejected`, `qa_blocked`, `improvement_exhausted`, `global_evaluation_failed`, `global_evaluation_blocked`, and `decision_expired`.

99. `timeout`, `crash`, and `rate_limit` retry the primary backend once. If retry fails, a single fallback backend invocation is allowed only when explicitly configured for the role.

100. `parse_error` and `schema_mismatch` are hard blocks: block the task without fallback.

101. `test_failed` and `review_changes_requested` enter the stage 4 improvement loop with at most one automatic fix cycle in MVP. If still failing or rejected, block. `review_rejected` and `qa_blocked` block or require decision routing according to risk and recoverability.

101a. `improvement_exhausted` stays blocked until Kimi or Human Approval chooses `revise`, chooses `reject`, or requests stop through the run stop endpoint.

101b. `global_evaluation_failed` returns to bounded improvement only when budget and scope allow it; otherwise it blocks for decision routing. `global_evaluation_blocked` routes to Kimi or Human Approval according to authority requirements.

102. `decision_expired` remains blocked and must not auto-approve.

103. Every retry, fallback, block, and failure recovery action must write both Gateway event and Audit records including original backend, failure class, attempt number, and fallback backend if used.

104. MVP run completion is accepted only through artifact existence/schema validity, Kanban task states, Gateway State consistency, and Audit records. Gateway Events may be checked for observation completeness, but they are not completion authority. Model self-report alone is never sufficient.

105. A successful MVP run requires:
   Gateway run status `completed`; all six stage tasks done in DAG order; all six fixed stage reports schema-valid; `structured_prd.json`, `development_plan.json`, `test_plan.json`, and `test_execution_report.json`; at least one real CLI implementer task; a reviewer task that inspected artifact refs and git diff; required run/stage/task Event Projection coverage or a rebuildable projection; and traceable Audit entries for stage inputs/outputs/failures.

106. Any MVP downgrade used in a run, such as no Redis, no independent worktree, or no Playwright, must be documented in `iteration_closeout_report.json`.

107. MVP worker safety policy uses existing `config/risk-policy.yaml` and adds file-write red lines.

108. Default forbidden auto-modification targets:
   `.git/`, `.gitignore`, `.env`, secret/key/token files, CI/CD config such as `.github/workflows/*`, `config/risk-policy.yaml`, `config/rules.json`, root `AGENTS.md`, root `CLAUDE.md`, `hermes/SOUL.md`, `scripts/setup.sh`, `scripts/install-orchestra.sh`, and upstream Hermes runtime directories.

109. Default `decision_required` triggers include L3/L4 risk-policy hits, destructive delete, database schema change, auth/secret/JWT change, `sudo`, `chmod 777`, docker/kubectl prune/delete, worker backend config changes, debate routing changes, Gateway proxy port changes, publish/push/deploy operations, and external API writes.

110. Allowed automatic write targets include the new Gateway adapter files, initial debate/worker MVP config, `.workflow/knowledge/*`, State/Audit/Cache run artifacts, and task-relevant code files with baseline and diff summary.

111. MVP implementation order is five vertical slices:
   Gateway shell; Run/artifacts/events; Harness plus debate; Implementation worker loop; Testing plus closeout.

112. Gateway shell implements `orch-gateway`, `/health`, `/orchestra/capabilities`, and `/v1/*` proxy.

113. Run/artifacts/events implements `POST /orchestra/runs`, run directories, `events.jsonl`, six-stage task scaffold, and artifact URI resolver.

114. Harness plus debate implements `workflow-init`, `knowledge-update`, debate registries, template debater, and fixed stage report schemas.

115. Implementation worker loop implements registry-driven Codex implementer plus Claude reviewer, baseline/diff/test artifacts, and file bus compatibility.

116. Testing plus closeout implements `test_plan.json`, test execution, `test_execution_report.json`, and `iteration_closeout_report.json`.

117. First end-to-end MVP demo task:
   add or verify Gateway adapter `/orchestra/capabilities` backend health reporting and a curl/shell smoke test.

118. The demo task must be low-risk, real code-changing work that can run through structured PRD, development plan, debate report, real CLI implementer, reviewer, test plan, test execution report, events, audit, and closeout.

119. If `/orchestra/capabilities` is already complete by the time demo execution starts, use `/orchestra/runs/{run_id}/tasks` projection as the substitute demo task.

120. `POST /orchestra/runs` request accepts `intent`, optional structured `ticket`, and `options`.

121. `intent` and `ticket` cannot both be absent. If only `intent` is provided, Gateway must normalize it into `structured_prd.json` and emit `ticket_normalized`.

122. `ticket` fields include at least:
   `background`, `goal`, `deliverables`, `acceptance_criteria`, `hard_constraints`, `soft_constraints`, `related_tasks`, and `failure_strategy`.

123. `options.worker_pairing` selects implementer/reviewer backends from available capabilities. `options.auto_approve_low_risk` controls low-risk auto-advance. MVP `mode` supports only `mvp_full`.

124. `POST /orchestra/runs` response includes `run_id`, `status`, `run_uri`, `events_url`, and `tasks_url`.

125. `GET /orchestra/runs/{run_id}` status enum is:
   `queued`, `running`, `blocked`, `failed`, `completed`, and `stopped`.

126. Run status response includes at least:
   `run_id`, `status`, `project`, `created_at`, `updated_at`, `current_stage`, `progress`, `stages`, `blocked_reason`, `pending_decision_id`, and `artifact_refs`.

127. Run status mapping:
   pending required decision maps to `blocked`; ordinary task/test/review/schema failures map to `blocked`; unrecoverable workflow authority or evidence integrity failure maps to `failed`; all six stages completed plus Closeout Completion Gate passing maps to `completed`; user stop maps to `stopped`.

128. `GET /orchestra/runs/{run_id}/tasks` returns a Gateway projection, not raw Kanban internals.

129. Task projection includes at least:
   `task_id`, `title`, `kind`, `stage`, `role`, `backend`, `status`, `parents`, `children`, `started_at`, `completed_at`, `artifact_refs`, `risk_level`, and `blocked_reason`.

130. Task projection must not expose worker raw prompts, secret environment, or absolute local paths.

131. MVP task projection supports simple filters such as `stage` and `role`.

132. `POST /orchestra/runs/{run_id}/stop` requests stop-and-archive behavior, not destructive cleanup.

133. Stop sets run status to `stopped`, emits `run_stopped`, writes audit, stops future scheduling, and preserves existing State/Audit/Cache artifacts.

134. MVP stop writes a cancel marker for running workers. `force=true` may only kill this run's bound runner process/session and must not kill global tmux sessions or unrelated runs.

135. Stop does not approve, reject, revise, or expire pending L3/L4 decisions. If stopped before completion, closeout records `stopped_before_completion`.

135a. `blocked` is an active, recoverable run status. It does not write completed closeout and does not release the one-active-run slot.

135b. A blocked run preserves Gateway State, Audit entries, Kanban task states, artifact refs, blocker reason, pending decision refs, and resume checkpoints.

135c. UI or conversational `cancel` maps to Gateway `stop`; it means stop-and-archive, not destructive cleanup.

136. MVP must integrate with real official Hermes Kanban through `hermes kanban` CLI commands, not a local simulated Kanban.

137. On startup, Gateway runs `hermes kanban init` and ensures the project board exists.

138. Run creation creates the parent workflow task and six stage tasks in Hermes Kanban, links dependencies with `hermes kanban link`, and advances task state with official `complete`, `block`, and `unblock` commands.

139. Gateway task projection is synthesized from `hermes kanban list/show` plus local artifact refs. Local `STATE_ROOT/.../task-graph.json` is only a compatibility/projection aid for the existing file bus, not canonical task state.

140. Gateway adapter does not automatically start or reconfigure the official Hermes API Server in MVP.

141. Official Hermes API Server is an optional upstream for `/v1/*` proxying. If unavailable, `/health` reports `upstream_api: degraded`, `/v1/*` returns 502, and `/orchestra/*` continues to work.

142. Adapter reads `HERMES_UPSTREAM_API_URL`, defaulting to the planned internal URL such as `http://127.0.0.1:8643`.

143. `/orchestra/capabilities` reports upstream API availability but run creation must not require upstream API availability in MVP.

144. MVP configuration files are project-local repo files:
   `config/orchestra-gateway.json`, `config/workers/backends.json`, `config/workers/roles.json`, `config/debate/teams.json`, `config/debate/modes.json`, and `config/schemas/*.schema.json`.

145. Runtime override priority is:
   environment variables, then project-local config JSON, then built-in defaults.

146. Default MVP config:
   Gateway `127.0.0.1:8642`, upstream API `http://127.0.0.1:8643`, project board slug derived from project id, default pairing `codex` implementer plus `claude` reviewer, local filesystem cache, template debate backend, `auto_approve_low_risk=true`, max improvement auto cycles `1`, and run mode `mvp_full`.

147. MVP must not write `~/.hermes/config.yaml`, root `AGENTS.md`, root `CLAUDE.md`, `SOUL.md`, or Get笔记 knowledge-base IDs into runtime configuration.

148. MVP schema validation uses a lightweight Python standard-library validator rather than adding a `jsonschema` dependency.

149. MVP schemas live under `config/schemas/` and include:
   run create request, structured PRD, development plan, debate report, stage report, test plan, test execution report, and worker response schemas.

150. Schema validation happens on Gateway request intake, before State/Audit artifact writes, before worker output advances workflow, and before run completion.

151. Schema failure behavior:
   request schema failure returns HTTP 400 without creating a run; stage artifact schema failure blocks the current stage and triggers decision or repair; worker response schema failure becomes `schema_mismatch` and hard-blocks without fallback; closeout validation failure prevents run status from becoming `completed`.

152. As of this discussion checkpoint, implementation is explicitly deferred. The next step is still design/spec clarification, not code changes for the Gateway or workflow runtime.

153. Gateway authentication is out of MVP scope because the system is single-user local-only. `/orchestra/*` does not require authentication in MVP.

154. This is an explicit MVP security downgrade. The Gateway must bind to `127.0.0.1` by default and must not be exposed publicly without adding authentication.

155. MVP allows only one active run per project. Active statuses are `queued`, `running`, and `blocked`; terminal statuses are `completed`, `failed`, and `stopped`.

156. If a project already has an active run, `POST /orchestra/runs` returns `409 conflict` with the active run summary.

157. Multi-project concurrency may run one active run per project. Same-project parallel runs are deferred until per-task namespace/worktree and merge arbitration are designed.

158. MVP API, events, and artifacts must be versioned. API/artifact schema version is `orchestra.v1`; event schema version is `orchestra.event.v1`; worker protocol remains `hermes-role-engine/v1`.

159. Gateway accepts only compatible major versions. Unknown major versions return HTTP 400 or block the workflow, depending on whether the invalid object is an API request or runtime artifact.

160. Minor-compatible evolution may only add optional fields and must not change existing field meaning.

161. User raw tickets may be stored in State/Audit but must not be written into the project repository.

162. `.workflow/knowledge/*` stores long-lived project knowledge only and must not store full temporary user requirements.

163. Get笔记 `qnN4o510` is discussion background only. Runtime config must not include it, and future specs may mention it as background without copying its full content.

164. Gateway event messages are summaries and must not include full prompts, tokens, secrets, or absolute local paths.

165. Worker stdout/stderr may be retained in State/Audit, while closeout references only summaries.

166. MVP secret redaction replaces likely secrets matching patterns such as `API_KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `sk-*`, and `gk_live_*` with `[REDACTED]`.

167. Audit remains local by default and must not be automatically uploaded or committed to Git.

168. Future `MVP-SPEC.md` is the single product/technical contract for execution. This grill decision note is source material, not the execution contract.

169. If `MVP-SPEC.md` conflicts with this note, `MVP-SPEC.md` wins only when it explicitly marks the older decision as superseded.

170. If execution discovers a spec problem, update the spec or write an ADR before changing code.

171. `MVP-SPEC.md` contains contracts, schema summaries, acceptance standards, and implementation slices, but no implementation code.

172. Chat history is not a runtime dependency and should not be used wholesale as worker prompt input.

173. Grill results have been consolidated into `.planning/specs/HERMES-MVP-SPEC.md` as the future execution contract.

174. Schema field summaries have been consolidated into `.planning/specs/HERMES-MVP-SCHEMAS.md`.

175. These spec documents are documentation deliverables only. No Gateway/runtime implementation has started.

176. Artifact authority is layered and explicit: State restores runs, Audit proves what happened, Cache stores only rebuildable results, and repository `.workflow/knowledge/*` stores long-lived project knowledge.

177. Artifact URI resolver rules are security and correctness boundaries: APIs return `state://`, `audit://`, `cache://`, or `repo://` references only, and the resolver must reject absolute paths, traversal, unknown schemes, and cross-project/cross-run references.

178. Run recovery and completion must not depend on cache or model self-report. Recovery comes from Kanban lifecycle plus Gateway State, State Artifacts, and Audit Artifacts. Completion comes from Kanban lifecycle, Gateway State, Audit, and schema-valid required artifacts.

179. Worker backend authority is split: `config/workers/backends.json` declares enabled backend adapters and capabilities, while `config/workers/roles.json` maps roles to required capabilities, preferred backends, and explicit fallback backends.

180. `options.worker_pairing` is a request, not authority. Gateway accepts it only when the requested backend is registered, enabled, role-compatible, and currently available in `/orchestra/capabilities`.

181. Worker selection and fallback must be audited. Gateway records selected backend, version, matched capabilities, adapter type, fallback status, failure class, attempt, and rationale in Gateway State and Audit.

182. Worker fallback cannot bypass Schema, security, or approval boundaries. `parse_error`, `schema_mismatch`, security policy hits, Human Approval boundaries, forbidden automatic modification targets, and unvalidated worker output hard-block instead of silently switching backends.

183. Worker adapters hide CLI/API differences behind `hermes-role-engine/v1`; workflow semantics depend on role capabilities and structured worker output, not tool-specific command names.

184. Worker input context uses a `hermes-role-engine/v1` Worker Context Envelope, not raw chat history or a whole-project prompt dump.

185. Worker Context Envelopes include structured task data, role, selected backend, stage, risk level, approval state, allowed write scope, workspace strategy, artifact refs, context bundle refs, and test requirements.

186. Worker Context Bundles are read-only, scoped, and artifact-ref based. They may include relevant structured PRD, development plan, debate/stage reports, selected `.workflow/knowledge/*` summaries, task projection data, baseline diff/status artifacts, and selected source-file excerpts or summaries.

187. Worker input must not include secrets, secret environment values, absolute local paths, full raw chat history, unrelated prior conversation, full project dumps, or unredacted temporary raw tickets.

188. If a worker needs more context, it must return `next_action: request_context` with a structured context request. Gateway may satisfy it only through validated artifact refs or a new scoped Context Bundle, and must record that addition in Audit.

189. Worker natural-language summary is explanatory only. Workflow state advances only from schema-valid structured worker output.

190. Worker output can request state advancement, but it is not state authority. `next_action: complete` means "request completion", not "complete the Kanban task".

191. Worker Backends must not directly mark Kanban tasks complete, mutate Gateway State, mark stages complete, or mark a run complete.

192. Gateway Advancement Gate validates worker output before any State, Audit, or Kanban lifecycle change. Validation covers protocol/schema, correlation and task identity, artifact refs, required artifact schemas, allowed write scope, forbidden paths, risk/approval boundaries, and required test or review evidence.

193. For code-changing tasks, Gateway compares changed files and diff summary against the allowed write scope and recorded baseline state before accepting completion.

194. Missing or invalid critical artifacts blocks or requests revision. Test failure enters the bounded improvement path. Write-scope, forbidden-target, or approval-boundary violations block for Human Approval or fail according to policy.

195. When worker output passes validation, Gateway writes State and Audit first, then advances official Hermes Kanban lifecycle through workflow-controlled `complete`, `block`, or `unblock`.

196. Worker stdout/stderr and natural-language summaries may be stored as evidence, but they are never state transition authority.

197. Reviewer and QA outputs must be structured verdict artifacts, not free-form summaries. Verdict enum is `approve | request_changes | reject | block`.

198. Review/QA verdicts must include findings, severity, affected acceptance criteria, required fixes, evidence refs, and whether the issue is inside the approved `development_plan.json` scope.

199. `approve` still passes through Gateway Advancement Gate before task, stage, or run advancement.

200. `request_changes` enters Stage 4 `improvement` for at most one automatic fix cycle when fixes are within approved scope and below human-risk gates.

201. `reject` blocks the task or requires Kimi decision depending on whether the reviewer describes a recoverable revision path.

202. `block` requires Kimi decision or Human Approval according to the decision authority chain. L3/L4, forbidden targets, security boundaries, write-scope violations, schema failures, and test failures cannot be bypassed by Kimi acceptance.

203. Kimi may accept, reject, or request revision below human-risk gates, but it must not override high-risk blocks, schema failures, test failures, write-scope violations, or Human Approval boundaries.

204. Improvement output must create new review/QA artifacts for re-review and must not overwrite the original review or QA verdict.

205. Re-review must inspect the improvement diff, original findings, acceptance criteria, artifact refs, and test evidence before allowing advancement.

206. Stage 4 automatic improvement cannot expand requirements, redirect architecture, change risk policy, modify worker/debate/Gateway config, or touch Human Approval targets.

207. Stage 4 automatic improvement must write `improvement_report.json`, link original verdict/test failure refs, record changed files/diff/tests, and trigger re-review or re-test.

208. After one automatic improvement cycle, remaining review/QA/test failure changes the run to blocked with `improvement_exhausted`.

209. Kimi or Human Approval may then choose `revise`, choose `reject`, or request stop through the run stop endpoint; automatic repair must not continue.

210. Stage 5 global evaluation must produce `global_evaluation_report.json` before Stage 6 can start.

211. `global_evaluation_report.json` must inspect structured PRD, development plan, debate reports, implementation evidence, review/QA verdicts, test execution, improvement reports, downgrade records, unresolved decisions, and Audit entries.

212. Global evaluation verdict is `pass | pass_with_warnings | fail | block`.

213. Stage 6 may start only after `pass` or Kimi-accepted `pass_with_warnings`.

214. `fail` can return to bounded improvement only when improvement budget remains, findings are in scope, and no human-risk gate is hit; otherwise it blocks.

215. `block` routes to Kimi or Human Approval. Kimi must not override L3/L4, schema failure, test failure, write-scope violation, security boundary, forbidden target, or Human Approval boundary.

216. Stage 6 closeout is not a completion self-report.

217. Stage 6 must write `iteration_closeout_report.json` and `system_improvement_proposals.json` after `global_evaluation_report.json` is `pass` or Kimi-accepted `pass_with_warnings`.

218. `iteration_closeout_report.json` records final acceptance, accepted warnings, downgraded capabilities, unresolved or deferred decisions, executed tests and reviews, worker fallbacks, knowledge updates, and future proposal refs.

219. Only low-risk `.workflow/knowledge/*` updates may be auto-applied during Stage 6.

220. Root `AGENTS.md`, root `CLAUDE.md`, `hermes/SOUL.md`, CI/CD, install scripts, permission/risk policy, worker backend config, debate routing config, and Gateway/runtime configuration are proposal-only targets in MVP.

221. A run can become `completed` only after closeout artifacts are schema-valid, Audit records closeout evidence, all required Kanban stage tasks are done, and Gateway State is consistent with artifact and decision refs.

222. `iteration_closeout_report.json` and `system_improvement_proposals.json` are evidence, not completion authority by themselves.

223. This aligns with `qnN4o510`: completion must come from Schema, DAG/Kanban, Gateway State, Audit, and Harness evidence rather than model summaries, cache hits, or worker self-report.

224. Stop/cancel and blocked-state handling:
   `blocked` is active and recoverable; `stop`/`cancel` is terminal `stopped`.

225. A blocked run must preserve State, Audit, Kanban task state, artifact refs, blocker reason, pending decision refs, and resume checkpoints. It must not write completed closeout or release the one-active-run slot.

226. `cancel` is a UX alias for `POST /orchestra/runs/{run_id}/stop`; it means stop-and-archive, not destructive cleanup.

227. Stop can apply to queued/running/blocked runs, emits `run_stopped`, writes stop Audit evidence, stops future scheduling, and writes cancel markers for this run's bound workers.

228. `force=true` may only terminate this run's bound runner process/session. It must not kill global tmux sessions, unrelated workers, or unrelated runs.

229. Stop does not approve, reject, revise, or expire pending decisions, including L3/L4 or Human Approval items. Pending decisions remain recorded as unresolved.

230. A stopped-before-completion run writes partial closeout evidence as `iteration_closeout_report.json` with `closeout_kind: stopped_before_completion`.

231. Partial closeout must record completed stages, incomplete stages, preserved artifact refs, unresolved decisions, stop reason, stop event/audit refs, worker cancel markers, and resume checkpoint refs where available.

232. Partial closeout is not Stage 6 completion and must not satisfy the `completed` acceptance path.

233. Later resume or revise must restore from Hermes Kanban lifecycle plus Gateway State, State Artifacts, and Audit Artifacts. Cache objects, worker summaries, and partial closeout text are not resume authority.

234. This stays aligned with `qnN4o510`: failures, stops, and recovery are evidence-preserving workflow states, not opportunities to discard Harness/Audit/Schema evidence.

235. Resume/revise and lineage:
   `blocked` resumes in place; `failed` and `stopped` continue only through a new run with lineage.

236. `approve` on a blocked decision resumes the original task or stage attempt from validated artifact refs, writes `decision_resolved`, and preserves blocker evidence in Audit.

237. `revise` on a blocked decision creates a revised child task or revised stage attempt inside the same run. It must set `revision_of`, link source artifact refs, and write new artifacts instead of overwriting original artifacts.

238. `reject` keeps rejected evidence immutable and routes the current task, stage, or run to blocked or failed according to recoverability and authority routing.

239. `failed` and `stopped` are terminal run statuses in MVP. They must not transition back to `queued`, `running`, or `blocked`.

240. Continuing after `failed` or `stopped` requires a new `POST /orchestra/runs` request with `source_run_id` and `resume_from_refs`.

241. A lineage run receives a new `run_id`, emits a new `run_created` event, and records `source_run_id`, source terminal status, and validated `resume_from_refs` in Gateway State and Audit.

242. The source run remains read-only for workflow continuation. The new run may read source Gateway State, State Artifacts, Audit Artifacts, Kanban task projection, and scoped artifacts, but must not mutate the source run.

243. `resume_from_refs` must be scoped artifact refs from the source run. Cache refs and worker summaries may be included as background only when rebuildable, but they are never resume authority.

244. Creating a new run from a `blocked` source run is rejected in MVP because the blocked run is still active and holds the one-active-run slot.

245. This aligns with `qnN4o510`: recovery and continuation preserve lineage through State/Audit/Kanban/artifact refs instead of rewriting terminal history.

246. Failed-vs-blocked boundary:
   MVP defaults to `blocked` whenever evidence can be preserved and the run can wait for decision, repair, or follow-up.

247. Test failure, review rejection, QA block, schema mismatch, decision expiration, missing approval, and repeated worker failure are blocked states by default, not terminal run failures.

248. Missing or invalid artifacts block when the artifact can be regenerated, repaired, superseded, or routed through a decision.

249. A run becomes terminal `failed` only when the current run can no longer be safely continued because workflow authority or evidence integrity is unrecoverable.

250. Terminal `failed` reasons are limited in MVP to Gateway/State/Audit/Kanban authority-chain corruption, critical State/Audit/artifact loss that cannot be rebuilt or superseded, unauthorized or out-of-scope writes that make the current run evidence untrusted, or internal workflow invariant violation that prevents safe recovery.

251. If Gateway cannot prove the failure crosses the terminal failure boundary, it must keep the run `blocked` and emit `decision_required`.

252. A failed run must emit `run_failed`, write immutable Audit evidence, write `run_failure_report`, preserve State/Audit/Kanban/artifact refs, record `last_good_checkpoint_ref` when available, and include lineage hints for a future run.

253. Marking a run `failed` must not delete State, Audit, Cache, repo artifacts, Kanban tasks, worker evidence, or partial outputs.

254. `failed` is terminal and cannot resume in place. Continuation follows lineage rules with a new run.

255. This aligns with `qnN4o510`: aggressive worker or task failure should block for diagnosis, while terminal failure is reserved for unrecoverable workflow evidence or authority-chain corruption.

256. Mutating Gateway endpoints must be idempotent for Kimi retries:
   `POST /orchestra/runs`, `POST /orchestra/decisions/{decision_id}`, and `POST /orchestra/runs/{run_id}/stop` require `idempotency_key`.

257. Gateway scopes idempotency by project, endpoint, resource path, and `idempotency_key`.

258. Idempotency replay is checked before active-run conflict checks, so a retry of the original run-create command returns the original result instead of `409 active run`.

259. On first accepted command, Gateway stores `command_id`, canonical request payload hash, resulting resource refs, response summary, Event refs, and Audit refs.

260. Same scope plus same `idempotency_key` plus same canonical payload returns the original command result and must not create a second run, decision resolution, stop marker, Kanban task, Event, or Audit evidence record.

261. Same scope plus same `idempotency_key` plus different canonical payload returns `409 conflict`.

262. If the original command is still in progress, retry returns the existing command status and resource refs without creating duplicate side effects.

263. Decision resolution is one-shot but idempotent. Repeating the same decision command returns the prior `decision_resolved` result; a conflicting action or revision payload is rejected.

264. Stop is idempotent. Repeating the same stop command returns the same `stopped` status, `run_stopped` event ref, stop Audit ref, and partial closeout ref without writing another stop record.

265. Audit and Events caused by mutating commands must record `command_id`.

266. `command_id` is evidence correlation only. It is not run identity, task identity, resume authority, or completion authority.

267. Idempotency records are Gateway State. Cache must not be used as command dedupe authority.

268. This aligns with `qnN4o510`: retries must not fabricate duplicate workflow evidence or bypass State/Audit/Kanban authority.

269. Mutating Gateway commands use command journal / write-ahead execution.

270. After request schema and idempotency validation, Gateway writes Gateway State `command_record` with `status: in_progress`, `command_id`, canonical payload hash, command intent, and planned side-effect steps before applying State, Audit, Kanban, worker, or artifact side effects.

271. Command side effects execute as journaled steps. Each step records `step_id`, `target_authority`, `operation`, `status`, and verifiable refs such as State refs, Audit refs, Kanban task ids, artifact refs, or response refs.

272. Gateway must not issue a workflow side effect that is not represented in the command journal.

273. For run creation, command journal is written before creating the parent Kanban task, six stage tasks, run State, run-created Event, or Audit entries.

274. For decision commands, command journal is written before decision resolution, revised child task creation, State/Audit writes, or Kanban lifecycle changes.

275. For stop commands, command journal is written before cancel markers, `run_stopped`, stop Audit, partial closeout, or scheduling changes.

276. Gateway marks a command `completed` only after all required side-effect refs are durable and the response summary is stored.

277. If a command step fails, Gateway records the failed step and routes through the existing blocked/failed boundary. It must not erase the command journal.

278. On startup, Gateway scans Gateway State for `command_record.status: in_progress`.

279. For each in-progress command, Gateway reconciles recorded steps against Gateway State, Audit, Hermes Kanban, and artifact refs.

280. If reconciliation proves the command completed, Gateway backfills missing response refs and marks the command `completed` without re-executing side effects.

281. If reconciliation proves a step has not executed, Gateway may continue from the next unexecuted journaled step.

282. If reconciliation cannot prove whether a side effect happened, Gateway marks the related run or task `blocked`, emits `decision_required`, records `command_reconciliation_report`, and does not blindly replay the command.

283. Recovery decisions must prefer preserving evidence over progress. Cache, worker summaries, and stdout are not reconciliation authority.

284. This aligns with `qnN4o510`: crash recovery reconstructs truth from State/Audit/Kanban/artifact refs rather than guessing or duplicating workflow side effects.

285. Gateway Events are a recoverable Event Projection for Kimi progress supervision, SSE, JSON polling, and UI replay.

286. Audit is immutable evidence authority. Audit cannot be reconstructed from Events, and Events must not replace Audit records.

287. Events are append-only within one run and ordered by a per-run monotonic `seq`. `timestamp` is informational and must not be used as the ordering authority.

288. Event payloads include `command_id` when caused by mutating commands, summary messages, and scoped artifact refs. They must not include raw prompts, secrets, full worker stdout/stderr, large report bodies, or absolute local paths.

289. Missing or corrupt Event Projection data may be rebuilt from Gateway State, Audit, Hermes Kanban, and artifact refs. Rebuild must not invent Audit evidence.

290. `GET /orchestra/runs/{run_id}/events` uses `since_seq` for JSON polling and SSE resume. Returned events must be strictly increasing by `seq` for that run.

291. If Kimi observes a sequence gap, duplicate sequence, stale projection, or projection inconsistency, it must resync through `GET /orchestra/runs/{run_id}`, `GET /orchestra/runs/{run_id}/tasks`, and `GET /orchestra/runs/{run_id}/events`.

292. Kimi must not advance workflow state from stale Events. Decisions and stop requests must use current run status, task projection, decision refs, and authoritative artifact refs.

293. This aligns with `qnN4o510`: Events serve supervision and UX, while workflow truth remains in Gateway State, Audit, Hermes Kanban, Schema-valid artifacts, and Harness evidence.

294. Event Projection inconsistency by itself must not change a run to `blocked`, `failed`, or `stopped` when Gateway State, Audit, Hermes Kanban, and required artifact refs are complete and mutually consistent.

295. Gateway handles event-only projection damage by returning `projection_status: inconsistent` or rebuilding the projection from authoritative refs. Kimi must resync before using Events for supervision or decisions.

296. If Events cannot be rebuilt because Gateway State, Audit, Hermes Kanban, or required artifact refs are themselves missing or inconsistent, the run follows the normal blocked-vs-failed authority boundary.

297. This aligns with `qnN4o510`: SSE/event streams are monitoring surfaces around Gateway, while Kanban lifecycle and durable State/Audit evidence remain the workflow authority.

298. Event Store persistence belongs to Gateway State, not Audit. MVP stores the primary event log under the run State directory, for example `STATE_ROOT/{project}/runs/{run_id}/events.jsonl`.

299. Event Store refs are `state://` refs. Audit records may reference Event refs for correlation, but Audit must not treat the Event Store as an Audit Artifact.

300. Command records may keep Event refs as part of Gateway State response replay and idempotency, while Audit records remain independent immutable evidence.

301. This aligns with `qnN4o510`: Gateway provides HTTP/SSE monitoring state, while Audit remains durable evidence and Kanban remains lifecycle authority.

302. MVP Event Store retention has no TTL, no truncation, and no per-event compression for active or terminal runs.

303. `events.jsonl` is retained with the run State so `since_seq`, SSE resume, command response refs, idempotency replay, and projection rebuild remain stable.

304. Cache TTLs do not apply to Event Store retention. Event Store must not use log rotation or lossy compaction.

305. Future archival, if needed, must archive the whole run State or preserve a complete sequence manifest. It must not delete prefix or middle ranges that create `seq` gaps.

306. This aligns with `qnN4o510`: Gateway progress monitoring remains reliable, and the system avoids the observed failure mode where log rotation loses early diagnostic evidence.

307. Event emission is post-commit. Gateway must append a Gateway Event only after the State, Audit, Hermes Kanban, or artifact change the Event reports is durable and re-readable.

308. Events must not pre-announce stage completion, task completion, decision resolution, stop, failure, artifact write, or run completion. If the authoritative write fails, the Event must not be emitted.

309. Event append steps in the command journal are projection steps that run after the authority steps they summarize.

310. If Event append fails after authoritative refs are durable, Gateway treats that as Projection Inconsistency and recovers or rebuilds Events from State/Audit/Kanban/artifact refs. It must not roll back durable authority writes solely because Event append failed.

311. This aligns with `qnN4o510`: Kimi/SSE progress must reflect Gateway/Kanban/Audit truth, not create truth ahead of the durable execution framework.

312. If a mutating command's authoritative State, Audit, Kanban, and artifact side effects succeed but Event append fails, Gateway returns a successful authority result with projection degradation metadata instead of a generic command failure.

313. Such responses include `event_projection_degraded: true`, `projection_status: inconsistent`, and `projection_issue_refs`.

314. The command record remains `status: completed` because the authority result is durable. The response summary stores the projection degradation fields for idempotency replay.

315. Retrying the same `idempotency_key` returns the same successful authority result and degradation metadata. It must not repeat State, Audit, Kanban, artifact, or Event side effects.

316. This aligns with `qnN4o510`: Gateway/Kanban/Audit durable execution truth must not be re-run because the SSE/Event observation layer failed.

## MVP Real-vs-Minimal Boundary

Must be real in MVP:

- Gateway accepts tasks, returns status, and exposes event/status flow.
- Kanban creates and advances the six-stage workflow and child tasks.
- At least one real CLI worker can execute code tasks.
- A reviewer backend can review execution output.
- The six-stage workflow runs end to end.
- Harness generates project knowledge, structured PRD, development plan, and archive artifacts.
- AI testing generates a test plan, runs at least one test, and writes a report.
- Audit records stage inputs, outputs, statuses, and failure reasons.

Can be minimal in MVP:

- Debate teams may start as template-driven multi-role invocations rather than all 16 teams at production quality.
- Local filesystem cache can initially cache only high-value artifacts such as debate results, local project knowledge retrieval, and test plans. Redis is not part of MVP.
- DeepSeek can remain optional if not available.
- AI Mock can start with static Swagger/mock handler support.
- Playwright generation can cover happy path without full CI or external UI automation platform integration.

## Open Questions To Continue

- Kanban board/task schema for six-stage workflow tasks and child engineering tasks.
- Debate team registry fields, routing rules, and approval thresholds.
- Local cache key, TTL, and invalidation policy.
- AI testing artifact schema and minimum executable test contract.
