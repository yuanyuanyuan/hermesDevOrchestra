---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Hermes 原生工作流 MVP 实现
status: Awaiting next milestone
stopped_at: Phase 25.1 execution complete
last_updated: "2026-05-12T00:00:00.000Z"
last_activity: 2026-05-12 — Phase 25.1 (docs & DX overhaul) inserted and completed in v1.3
progress:
  total_phases: 7
  completed_phases: 7
  total_plans: 6
  completed_plans: 6
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-11)

**Core value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。
**Current focus:** v1.3 archived — either resolve the inherited aggregate-gate blocker or open v1.4

## Current Position

Phase: Milestone v1.3 complete (Phase 25.1 docs/DX overhaul appended)
Plan: —
Status: Awaiting next milestone
Last activity: 2026-05-12 — Phase 25.1 (docs & DX overhaul) inserted and completed

## Requirements Alignment

v1.3 requirements are archived at `.planning/milestones/v1.3-REQUIREMENTS.md`.
Roadmap archive captured the 6 shipped phases (20-25) and milestone audit evidence.
v1.4 remains the next milestone preview; fresh milestone-scoped requirements have not been created yet.

## Accumulated Context

### Decisions

All v1.1 decisions remain valid.

- Phase 14: Dev Orchestra active package path is the repository root package layout (`README.md`, `WORKFLOW.md`, `scripts/`, `skills/`, `config/`, `hermes/`, `claude-config/`); no old-path compatibility shim is supported.
- Phase 14: Upstream Hermes Agent pin strategy is repo-local manifest pin at `.planning/upstream/hermes-agent-pin.json`; git submodule is not selected.
- [Phase 15]: Used existing smoke runner discovery for spec conformance. — Phase 15 defers Makefile work to Phase 16 and run-all.sh already discovers test-*.sh scripts.
- [Phase 15]: Created only derived specs with current repository consumers. — Phase 15 requires no consumerless derived specs and keeps the inventory limited to file bus, risk decisions, and commands.
- [Phase 16 Plan]: Keep implementation to one root `Makefile`. — `test-unit` delegates to the existing smoke runner, `test-risk` runs the three required risk/approval scripts, JSON lint uses Python stdlib, shell lint skips explicitly without shellcheck, and upstream status compares the repo-local manifest pin with the runtime checkout when present.
- [Phase 16]: Root `Makefile` created as the local developer workflow entrypoint. — `make test` now aggregates smoke tests, risk tests, JSON lint, shell lint, and upstream pin status without adding placeholder targets.
- [Phase 17 Plan]: Use a verification-first agent-rule convergence plan. — `17-01` covers AGNT-01 and AGNT-02 with static checks for all GSD managed markers, Dev Orchestra boundaries, current `orch-*` helper coverage, L3/L4 no-auto-approval wording, pointer-only `CLAUDE.md`, and `rtk make test`.
- [Phase 17]: Agent rule convergence verified without source edits. — `AGENTS.md` already preserves managed sections and the Dev Orchestra boundary block; `CLAUDE.md` remains pointer-only to `AGENTS.md` and `.planning/SPEC.md`; static checks and `rtk make test` passed.
- [Phase 18 Context]: Use explicit architecture-boundary wording across canonical, derived, and user-facing docs. — Fixed Runtime bus filenames represent one active task slot per project; same-project parallelism is future v2 design work; "10x" is limited to single-developer multi-project orchestration, not same-project parallel Codex execution or AI-factory concurrency.
- [Phase 18 Plan]: Execute one documentation and verification plan. — `18-01` covers ARCH-01 and ARCH-02 with fixed Runtime bus boundary wording, future same-project parallelism scope, 10x limitation, static drift checks, `rtk make test`, traceability updates, and Phase 18 verification evidence.
- [Phase 18]: Architecture bounds and v1.2 closeout verified. — Fixed Runtime bus single-slot wording, same-project parallelism future-work boundary, 10x limitation, `rtk make test`, and Phase 13-18 traceability all passed.
- [Milestone v1.3]: Split phase 19 workflow design into two execution milestones. — v1.3 covers the MVP path; v1.4 keeps curator semantics, SRE RCA, and deploy/UAT full-scope items.
- [Milestone v1.3]: Start execution numbering at Phase 20. — `.planning/phases/19-hermes-workflow-design/` remains a stable design-source directory and is not reused as a GSD execution phase.
- [Phase 21]: Normalize runtime reviewer naming to `reviewer` and generate project-scoped Hermes homes under `.hermes/projects/{project_slug}/`. — Canonical profile catalog now lives in `hermes/profile-distribution/`; repo-local overrides compile via `orch-profile-sync`; board/workspace/profile/memory isolation all derive from the same `project_slug`.
- [Phase 19 Design Update]: Adopt “Hermes scheduling + external CLI execution” as the execution baseline. — Commit `3976c42` added `EXTERNAL-CLI-ENGINE.md`, standardized `hermes-role-engine/v1`, and requires Phase 22+ to land engine protocol work before routing/guardrail implementation.
- [Phase 23]: Keep Hermes-native `status + parents` primary and add only four routing metadata fields. — `workflow_state`, `routing_reason`, `resume_target`, and `handoff_ref` now drive stateful routing checkpoints; same-role unblock resumes the original task while cross-role transitions create explicit child/follow-up tasks.
- [Phase 24 Plan]: Keep one canonical risk-policy surface with role branches and four runtime levels. — `L4` is reserved for narrow accident-button actions only; Reviewer / Orchestrator guardrails use allowlists plus `pre_tool_call`; Implementer must emit structured blocks for four fixed trigger categories.
- [Phase 24]: Execute one canonical risk-policy and role-guardrail layer. — `risk-policy.yaml` is now the runtime source of truth, `APPROVE-L4 <approval_id>` is enforced for L4, hook assets block reviewer/orchestrator bypass paths, and Implementer block categories are preserved through the existing Phase 23 routing flow.
- [Phase 25 Plan]: Close v1.3 with lifecycle control, structured handoff hardening, hook-based observability, and one MVP acceptance chain. — `25-CONTEXT.md` and `25-01-PLAN.md` lock task-level timeout/reclaim, untrusted handoff consumption, sidecar trace storage, spawn-time environment snapshots, conservative backpressure, and an end-to-end acceptance proof while deferring v1.4 deadlock/SRE/deploy scope.
- [Phase 25]: Execute one lifecycle/observability closeout layer on top of the Phase 22-24 runtime. — `active-run.json`, `backpressure.json`, structured handoff validation, the observability plugin, env snapshots, and the MVP acceptance path are now landed and verified without modifying Hermes core.
- [Phase 25.1]: Documentation & DX Overhaul inserted after Phase 25 in v1.3. — New `INSTALL.md` (comprehensive install guide with prerequisite checker), rewritten `GETTING-STARTED.md` (Chinese, step-by-step), moved `WORKFLOW.md` to `docs/`, new `scripts/check-prerequisites.sh`, `scripts/install-orchestra.sh`, `scripts/orch-doctor.sh` tooling scripts, terminology normalization (file bus → task exchange).

### Pending Todos

None.

### Blockers/Concerns

- Aggregate repo gate is not fully green: `rtk make test` currently fails `upstream-status` because the local Hermes runtime pin does not match `.planning/upstream/hermes-agent-pin.json`. Phase 20 static checks passed; this mismatch is an external follow-up item.

## Session Continuity

Last session: 2026-05-12T00:00:00Z
Stopped at: Phase 25.1 (docs & DX overhaul) complete
Resume: Start `v1.4` with `/gsd-new-milestone` or resolve the inherited `upstream-status` pin mismatch before treating the repo as globally green

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
