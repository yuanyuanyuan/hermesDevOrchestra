---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Hermes Dev Orchestra 规范化与迁移
status: ready_to_plan
stopped_at: Phase 15 complete; ready to plan Phase 16
last_updated: "2026-04-28T11:32:52Z"
last_activity: 2026-04-28 -- Phase 15 verified complete; ready to plan Phase 16
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 6
  completed_plans: 3
  percent: 50
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-28)

**Core value:** 用户可以通过 SSH/Hermes CLI 随时追加开发任务，让 Hermes 自动调度 Claude 与 Codex 推进多个项目，只在高风险或产品级决策时打断用户。
**Current focus:** Phase 16 — Makefile & Dev Workflow

## Current Position

Phase: 16
Plan: Not started
Status: Ready to plan
Last activity: 2026-04-28 -- Phase 15 verified complete; ready to plan Phase 16

Progress: [█████░░░░░] 50%

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

### Pending Todos

None.

### Blockers/Concerns

None at milestone start.

## Session Continuity

Last session: 2026-04-28T11:32:52Z
Stopped at: Phase 15 complete; ready to plan Phase 16
Resume: Plan Phase 16
