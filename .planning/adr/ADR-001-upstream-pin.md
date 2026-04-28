# ADR-001: Upstream Hermes Agent Pin Strategy

**Date:** 2026-04-28
**Status:** Accepted
**Decision:** Use a repo-local JSON manifest pin for v1.2.

## Context

Hermes Dev Orchestra is an adapter layer over the community `NousResearch/hermes-agent` project. Phase 9 installed and probed upstream Hermes Agent at commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`, with observed version `Hermes Agent v0.11.0 (2026.4.23)`.

The v1.2 workflow needs a stable, machine-readable upstream pin for future developer workflow checks, especially Phase 16 `make upstream-status`. The repository does not need to vendor or checkout upstream Hermes Agent source for normal adapter development.

## Decision

Use a repo-local JSON manifest pin at `.planning/upstream/hermes-agent-pin.json`.

The manifest records the upstream repository, remote URL, pinned commit, observed version, probe date, install source and method, local install path, probe commands, update procedure, and Phase 16 JSON pointer contract.

## Options Considered

| Option | How it works | Pros | Cons | Decision |
|--------|--------------|------|------|----------|
| installer/probe pin | Keep the pin only in installer/probe evidence and prose summaries. | Simple and matches Phase 9 evidence. | Not machine-readable enough for Phase 16 workflow checks. | Rejected |
| git submodule | Add upstream Hermes Agent as a Git submodule pinned by the superproject index. | Git-native source pin with explicit commit. | Adds `.gitmodules`, gitlink semantics, clone/update workflow, and an upstream checkout this adapter-layer repo does not need. | Rejected |
| manifest pin | Store the selected upstream commit and probe evidence in a repo-local JSON file. | Machine-readable, small, reviewable, and compatible with future `upstream-status` checks. | Does not fetch upstream source by itself; runtime probes must compare against the local install. | Accepted |
| vendor snapshot | Copy upstream source into this repository. | Fully local source snapshot. | Conflicts with the upstream-first adapter boundary and creates local ownership of upstream core code. | Rejected |

## Consequences

- Future tooling should read `.planning/upstream/hermes-agent-pin.json` for the repo-local expected upstream commit.
- Updating upstream requires an intentional commit selection, installer/probe rerun, and manifest/documentation update in the same change.
- The adapter repository remains focused on SOUL, skills, `orch-*` helpers, docs, and verification fixtures.
- No upstream core source is vendored into this repository.

## UPST-02 Applicability

UPST-02 is not applicable because manifest pin is selected and git submodule is not selected.

This phase must not introduce `.gitmodules` or any gitlink mode `160000`.

## Verification

- `python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null`
- `rg -q --fixed-strings "installer/probe pin" .planning/adr/ADR-001-upstream-pin.md`
- `rg -q --fixed-strings "git submodule" .planning/adr/ADR-001-upstream-pin.md`
- `rg -q --fixed-strings "manifest pin" .planning/adr/ADR-001-upstream-pin.md`
- `rg -q --fixed-strings "vendor snapshot" .planning/adr/ADR-001-upstream-pin.md`
- `test ! -f .gitmodules`
- `! git ls-files --stage | grep -q '^160000 '`
