# Phase 9 Discussion Log: Upstream Hermes Agent Baseline

**Date:** 2026-04-25  
**Mode:** `$gsd-discuss-phase 9` via `$gsd-do`  
**Purpose:** Re-clarify and align v1.1/Phase 9 requirements after milestone requirement updates.

## Routing

User request:

> 我更新了v1.1的milestone的需求,包括更新phase 9的内容,现在重新做需求澄清和对齐

Routed to `$gsd-discuss-phase 9` because the request is about requirements clarification and alignment for a specific phase.

## Gray Areas Selected

User selected `all`, so all identified Phase 9 gray areas were discussed:

1. Upstream probe/install mode
2. Local Node CLI residual handling
3. Upstream version pinning strategy
4. Upstream capability gap boundary
5. Command entrypoint boundary

## Decisions Captured

### 1. Upstream Probe / Install Mode

**Options presented:**
- Read-only analysis
- Isolated install probe
- Real user-environment install
- Custom boundary

**User selected:** Real user-environment install.

**Captured decision:** Phase 9 may install/update upstream `NousResearch/hermes-agent` in the current user environment because no other Hermes system is installed.

**Guardrail:** Stop and report if an unexpected existing `hermes`, populated `~/.hermes`, or conflicting Hermes config is discovered.

### 2. Local Node CLI Residual Handling

**Options presented:**
- Delete independent CLI
- Migrate into `orch-*` helper
- Keep thin shim
- Keep temporarily and decide after Phase 9

**User selected:** Delete independent CLI.

**Captured decision:** Delete local Node CLI scaffolding and avoid any local `hermes` command that shadows upstream.

### 3. Upstream Version Pinning Strategy

**Options presented:**
- Pin commit
- Pin release/tag
- Track `main` plus capability probes
- Probe first, decide later

**User selected:** Pin commit.

**Captured decision:** Lock upstream Hermes Agent to a concrete commit SHA and document the upgrade procedure.

### 4. Upstream Capability Gap Boundary

**Options presented:**
- Minimal v1.1 gap filling
- Complete README experience loop
- Record gaps only
- Risk-first gap filling

**User selected:** Record gaps only.

**Captured decision:** Phase 9 records upstream capability gaps only. Adapter implementation belongs to Phases 10-12.

### 5. Command Entry Boundary

**Options presented:**
- Keep upstream `hermes` unchanged and provide only `orch-*`
- Wrap `hermes` subcommands
- Provide both
- Decide in Phase 10

**User selected:** Keep upstream `hermes` unchanged and provide only `orch-*`.

**Captured decision:** Upstream owns the `hermes` CLI. This repository owns orchestra-specific `orch-*` helpers and adapter glue.

## Files Updated

- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md`
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-PLAN.md`
- `.planning/phases/09-upstream-hermes-agent-baseline/09-DISCUSSION-LOG.md`

## Follow-Up

The existing Phase 9 plan was aligned to the locked decisions, but a fresh `$gsd-plan-phase 9` is still recommended if the user wants a fully regenerated GSD plan from the updated context.
