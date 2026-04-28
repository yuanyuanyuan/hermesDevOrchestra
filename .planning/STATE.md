---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Hermes Dev Orchestra 规范化与迁移
status: ready_to_execute
stopped_at: Phase 17 planned; ready to execute Phase 17
last_updated: "2026-04-28T15:56:35Z"
last_activity: 2026-04-28 -- Phase 17 planned; 1 plan verified and ready to execute
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 6
  completed_plans: 4
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-28)

**Core value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。
**Current focus:** Phase 17 — Agent Rules Consolidation

## Current Position

Phase: 17
Plan: 17-01 ready to execute
Status: Ready to execute
Last activity: 2026-04-28 -- Phase 17 planned; 1 plan verified and ready to execute

Progress: [███████░░░] 67%

## Requirements Alignment

v1.2 requirements defined: 15 requirements across 6 categories.
Roadmap created: 6 phases (13-18) with success criteria and traceability.

## Accumulated Context

### Decisions

All v1.1 decisions remain valid.

- Phase 14: Dev Orchestra active package path is `docs/orchestra/`; no old-path compatibility shim is supported.
- Phase 14: Upstream Hermes Agent pin strategy is repo-local manifest pin at `.planning/upstream/hermes-agent-pin.json`; git submodule is not selected.
- [Phase 15]: Used existing smoke runner discovery for spec conformance. — Phase 15 defers Makefile work to Phase 16 and run-all.sh already discovers test-*.sh scripts.
- [Phase 15]: Created only derived specs with current repository consumers. — Phase 15 requires no consumerless derived specs and keeps the inventory limited to file bus, risk decisions, and commands.
- [Phase 16 Plan]: Keep implementation to one root `Makefile`. — `test-unit` delegates to the existing smoke runner, `test-risk` runs the three required risk/approval scripts, JSON lint uses Python stdlib, shell lint skips explicitly without shellcheck, and upstream status compares the repo-local manifest pin with the runtime checkout when present.
- [Phase 16]: Root `Makefile` created as the local developer workflow entrypoint. — `make test` now aggregates smoke tests, risk tests, JSON lint, shell lint, and upstream pin status without adding placeholder targets.
- [Phase 17 Plan]: Use a verification-first agent-rule convergence plan. — `17-01` covers AGNT-01 and AGNT-02 with static checks for all GSD managed markers, Dev Orchestra boundaries, current `orch-*` helper coverage, L3/L4 no-auto-approval wording, pointer-only `CLAUDE.md`, and `rtk make test`.

### Pending Todos

None.

### Blockers/Concerns

None at milestone start.

## Session Continuity

Last session: 2026-04-28T15:56:35Z
Stopped at: Phase 17 planned; ready to execute Phase 17
Resume: Execute Phase 17
