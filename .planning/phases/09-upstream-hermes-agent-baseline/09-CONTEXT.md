# Phase 9: Upstream Hermes Agent Baseline - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Direction correction from independent local CLI to upstream-first implementation

<domain>
## Phase Boundary

This phase establishes the required foundation: Hermes Dev Orchestra must build on the community `NousResearch/hermes-agent` project, not reimplement a separate Hermes Agent runtime in this repository.

The phase should install/probe upstream Hermes Agent in the current user environment, record the exact commit SHA to target, identify capability gaps against `docs/hermes-dev-orchestra/README.md`, and delete the existing local Node CLI scaffolding from Phase 8/partial Phase 9 work.

It does not yet implement the full orchestra package installer, tmux runtime, Claude/Codex routing loop, or risk decision fallback. Those move to Phases 10-12 after the upstream baseline is clear.

</domain>

<decisions>
## Direction Decisions

### Upstream Foundation
- `https://github.com/NousResearch/hermes-agent` is the required Hermes Agent foundation.
- This repository provides an orchestra adapter package: SOUL.md, skills, setup helpers, tmux/file-bus glue, safety policies, and verification.
- The local implementation must not become an independent replacement for Hermes Agent.

### Local Code Boundary
- Local code may bootstrap upstream `hermes`, but should not duplicate upstream terminal/process/todo/memory runtime behavior.
- Existing Node CLI scaffolding is provisional and must be deleted, not migrated or retained as a shim.
- Future path/state/file-bus helpers must use `orch-*` entrypoints and should be written only where upstream Hermes Agent does not already provide the needed primitive.

### Source of Truth
- `docs/hermes-dev-orchestra/README.md` is the product intent source for this correction.
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, and `.planning/ROADMAP.md` now define the upstream-first implementation track.
- Upstream Hermes Agent behavior must be retrieved from the live repository or installed CLI before relying on assumptions.

## Requirements Alignment Decisions (Locked 2026-04-25)

Based on user review of README.md as the baseline, the following conflicts between README.md and REQUIREMENTS.md/REQUIREMENTS-REV1.md are resolved:

### D1 — Path Structure: 4-Layer (REQUIREMENTS-REV1.md wins)
- **Decision:** Use the 4-layer directory layout (Runtime/State/Audit/Cache) from REQUIREMENTS-REV1.md §2.3.1, not README.md's 2-layer structure.
- **Rationale:** README.md places audit records and state snapshots under `/tmp/`, which is volatile (reboot clears it, systemd-tmpfiles purges ≥10 days). The core value proposition requires durable audit trails and recoverable state.
- **User-visible path:** `/tmp/hermes-orchestra/{project}/` remains the Runtime bus (per README.md), but State snapshots go to `~/.local/state/hermes-orchestra/`, Audit records to `~/.local/share/hermes-orchestra/`, and Cache to `~/.cache/hermes-orchestra/`.
- **Impact:** Phase 10 (PKG-03) and Phase 11 (RUN-01) must create all 4 layers, not just 2.

### D2 — Risk Rulebook: Minimal Viable Set (hybrid approach)
- **Decision:** Implement a static JSON rulebook with 3-5 core rules covering: database schema changes, authentication changes, destructive file operations, system-level commands, and secret/credential handling.
- **Rationale:** README.md describes behavior-level risk handling (Claude judges → Hermes escalates). REQUIREMENTS.md SAFE-01 and REQUIREMENTS-REV1.md §4.3.2 require a static rule table with Hermes enforcement. The minimal set satisfies safety requirements without over-engineering v1.1.
- **Impact:** Phase 12 (SAFE-01, RISK-05) creates `rules.json` with 3-5 rules. The rule table is extensible — more rules can be added without code changes.

### D3 — Remote Decision Fallback: File-based first (REQUIREMENTS.md wins)
- **Decision:** Implement the file-based local fallback channel (REMOTE-05 from REQUIREMENTS-REV1.md §3.3.1) as the primary decision mechanism for v1.1. Telegram integration remains documented and supported but is treated as an optional adapter, not a hard dependency.
- **Rationale:** README.md assumes Telegram is configured (Step 3 "强烈推荐"). REQUIREMENTS.md DEC-01 mandates a working fallback when no remote adapter is configured. v1.1 must be testable and usable without Telegram.
- **Impact:** Phase 12 (DEC-01, DEC-02) implements `hermes decisions`, `hermes approve <id>`, and `hermes reject <id>` CLI subcommands. The file-based channel satisfies the REMOTE-02 interface.

### D4 — Upstream Capability Gaps: Local Adapter Completes (README.md behavior preserved)
- **Decision:** If upstream `NousResearch/hermes-agent` lacks capabilities that README.md assumes (todo/memory, process registry, clarify/send_message, notify_on_complete), the local adapter must provide lightweight implementations to ensure README.md-described functionality works.
- **Rationale:** README.md describes a specific user experience (todo lists, process polling, clarify(), multi-project switching). If upstream gaps cause these to fail, the v1.1 slice is incomplete and untestable. The adapter fills gaps; it does not replace upstream.
- **Impact:** Phase 9 (UP-02) must explicitly catalog which README.md-assumed capabilities are native vs gap. Phases 10-11 implement adapter-layer supplements where needed.

## Phase 9 Clarification Decisions (Locked 2026-04-25)

### D5 — Upstream Probe: Real Current-User Install
- **Decision:** Phase 9 may install or update upstream `NousResearch/hermes-agent` in the current user environment.
- **Rationale:** The current environment has not installed another Hermes system, so a real install gives the most accurate no-sudo verification signal.
- **Guardrail:** If an unexpected existing `hermes`, populated `~/.hermes`, or conflicting Hermes config is discovered, stop and report before overwriting anything.
- **Impact:** Phase 9 should run the real upstream install/probe path, not only a `/tmp` clone or dry-run.

### D6 — Local Node CLI: Delete, Do Not Migrate or Shim
- **Decision:** Delete the independent Node CLI scaffolding created before direction correction.
- **Rationale:** A local `bin/hermes.js` or package-level `hermes` command can shadow/confuse upstream Hermes Agent and reintroduce standalone-runtime drift.
- **Impact:** Phase 9 must remove or revert `bin/hermes.js`, `src/cli.js`, `src/result.js`, `src/version.js`, `src/paths.js`, `src/atomic.js`, `src/envelope.js`, and any package metadata that exists only to expose the local `hermes` binary.

### D7 — Upstream Versioning: Pin Commit SHA
- **Decision:** Lock upstream Hermes Agent to a concrete commit SHA.
- **Rationale:** The integration must be reproducible. Tracking `main` would let upstream behavior drift under the adapter.
- **Impact:** Phase 9 summary must record the commit SHA, install source, install command, observed version/help output, and a later upgrade procedure.

### D8 — Capability Gaps: Report Only in Phase 9
- **Decision:** Phase 9 only records upstream capability gaps. It does not implement adapter supplements.
- **Rationale:** This phase is for baseline alignment. Implementing gap fillers during probing would blur discovery with implementation and expand scope.
- **Impact:** Gap filling remains in Phases 10-12 according to the roadmap. Phase 9 output should be a capability table and backlog/handoff items.

### D9 — Command Entry Boundary: Upstream `hermes` + Local `orch-*`
- **Decision:** Keep upstream `hermes` commands untouched. This repository provides `orch-init`, `orch-start`, `orch-stop`, `orch-status`, and related `orch-*` helpers only.
- **Rationale:** The user needs a clear boundary: upstream owns the Hermes Agent CLI; this repo owns orchestra-specific wrappers and glue.
- **Impact:** Do not wrap, override, or add local `hermes` subcommands in v1.1 unless a future explicit decision changes this boundary.

</decisions>

<code_context>
## Existing Code Insights

### Provisional Assets
- Phase 8 created `package.json`, `bin/hermes.js`, `src/cli.js`, `src/result.js`, and `src/version.js` as a standalone Node CLI shell.
- Partial Phase 9 work introduced `src/paths.js`, `src/atomic.js`, `src/envelope.js`, and `src/cli.js` path initialization changes. These are stale unless retained as adapter-only utilities.

### Upstream Integration Inputs
- `docs/hermes-dev-orchestra/scripts/setup.sh` already installs Hermes Agent from `https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh`.
- `docs/hermes-dev-orchestra/README.md` expects Hermes Agent to own SOUL, todo/memory, terminal/process management, clarify/send_message, and the top-level orchestration loop.
- The local repo should verify those assumptions against the actual upstream CLI/API before building wrappers.

</code_context>

<specifics>
## Specific Ideas

Start by producing a small upstream capability report:
- real current-user install command and no-sudo behavior
- upstream commit SHA pin
- `hermes --version` and `hermes --help`
- expected config/skill/SOUL locations
- available terminal/process/todo/memory/clarify/send_message capabilities
- gaps against the README's orchestration flow
- deletion list for existing Node CLI files
- confirmation that no local `hermes` wrapper remains

</specifics>

<deferred>
## Deferred Ideas

Actual `orch-*` helper implementation, tmux session lifecycle, file bus runtime loop, Claude/Codex routing, adapter gap filling, and risk decision fallback are deferred to Phases 10-12.

</deferred>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Specifications
- `.planning/REQUIREMENTS.md` — v1.1 requirement list (UP-01..VER-04)
- `.planning/REQUIREMENTS-REV1.md` — Path layering, remote fallback, risk authority revisions (§2-§4)
- `.planning/ROADMAP.md` — Phase goals, success criteria, and execution order
- `.planning/PROJECT.md` — Vision, constraints, key decisions, current state

### Product Intent
- `docs/hermes-dev-orchestra/README.md` — Product behavior baseline: architecture, file bus, decision flow, deployment steps, daily usage
- `docs/hermes-dev-orchestra/hermes/SOUL.md` — Hermes orchestrator personality definition

### Skills & Setup
- `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` — Main orchestration skill
- `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md` — Claude supervisor role
- `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md` — Codex executor role
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` — Risk gatekeeper role
- `docs/hermes-dev-orchestra/scripts/setup.sh` — Installation script draft

### Provisional Local Code (to delete in Phase 9)
- `bin/hermes.js` — Standalone local `hermes` entrypoint; delete to avoid shadowing upstream.
- `src/cli.js` — Standalone Node CLI shell; delete.
- `src/result.js` — Standalone CLI envelope helper; delete if only used by local CLI.
- `src/version.js` — Standalone prototype version; delete if only used by local CLI.
- `src/atomic.js` — Standalone atomic write utilities; delete and reintroduce later only under `orch-*` adapter code if needed.
- `src/envelope.js` — Standalone bus envelope formatting; delete and reintroduce later only under `orch-*` adapter code if needed.
- `src/paths.js` — Standalone path resolution; delete and reintroduce later only under `orch-*` adapter code if needed.
- `package.json` — Remove or rewrite if its only purpose is exposing the local `hermes` binary.
</canonical_refs>

---
*Phase: 09-upstream-hermes-agent-baseline*
*Context gathered: 2026-04-25*
*Requirements alignment: 2026-04-25 (D1-D9 locked)*
