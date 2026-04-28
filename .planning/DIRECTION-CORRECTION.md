# Direction Correction: Upstream Hermes Agent Foundation

**Date:** 2026-04-25  
**Decision:** Hermes Dev Orchestra v1.1 must be implemented on top of community `NousResearch/hermes-agent`, not as an independent new Hermes Agent runtime.

## Trigger

The user clarified that the original方案 was to build from `https://github.com/NousResearch/hermes-agent`. The current v1.1 path had drifted into a standalone local Node CLI prototype with path/state/file-bus primitives.

## Corrected Direction

- Use community `NousResearch/hermes-agent` as the top-level Hermes Agent.
- Treat this repository as an orchestra adapter package:
  - SOUL.md
  - custom skills
  - setup/install helpers
  - `orch-*` wrapper commands
  - tmux and file-bus glue
  - risk rulebook and local decision fallback
  - verification fixtures and documentation
- Do not continue reimplementing Hermes Agent core runtime locally.

## Source Evidence

- `docs/hermes-dev-orchestra/README.md` describes Hermes Agent as the Ubuntu top-level orchestrator.
- `docs/hermes-dev-orchestra/scripts/setup.sh` installs Hermes Agent from `https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh`.
- `.planning/SPEC.md` already named Hermes Agent as a reference implementation; this correction makes it the implementation foundation for v1.1.

## Impact

- Phase 8 local Node CLI shell is now provisional scaffolding, not the product runtime.
- Phase 9 path/state/file-bus plan is superseded by an upstream Hermes Agent baseline phase.
- Live Claude/Codex tmux orchestration returns to v1.1 scope once upstream capabilities are verified.
- Remote adapter implementation remains deferred; local SSH/file fallback still satisfies the abstract decision channel requirement.

## Next Action

Execute Phase 9 Plan 01 to:
1. Probe upstream Hermes Agent.
2. Map README assumptions to observed upstream capabilities.
3. Decide whether existing Node CLI scaffolding should be deleted, migrated into helpers, or retained only as a thin compatibility shim.
