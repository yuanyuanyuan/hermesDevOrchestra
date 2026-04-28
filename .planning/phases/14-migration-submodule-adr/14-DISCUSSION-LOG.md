# Phase 14: Migration & Submodule ADR - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 14 - Migration & Submodule ADR
**Areas discussed:** Directory migration, compatibility strategy, upstream pin ADR, ADR location and validation

---

## Directory Migration

| Option | Description | Selected |
|--------|-------------|----------|
| Migrate directory | Execute Phase 14 migration based on Phase 13 evidence. | yes |
| Do not migrate | Keep `docs/hermes-dev-orchestra/` and record the reason. |  |

**User's choice:** Migrate.
**Notes:** The migration should move the Dev Orchestra directory rather than only documenting why it stays.

---

## Compatibility Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| No compatibility path | Update references and do not keep a shim, symlink, or supported old-path pointer. | yes |
| Keep compatibility pointer | Preserve an old-path entrypoint for readers or scripts. |  |

**User's choice:** No compatibility path.
**Notes:** Old references should be updated rather than supported through compatibility indirection.

---

## Migration Target Path

| Option | Description | Selected |
|--------|-------------|----------|
| `docs/orchestra/` | Shorter path while keeping the content in the docs tree. | yes |
| `orchestra/` | Top-level adapter package path. |  |
| `packages/hermes-dev-orchestra/` | Package-style layout for a future publishable unit. |  |

**User's choice:** `docs/orchestra/`.
**Notes:** This keeps the material in a documentation/adapter area without the long nested name.

---

## Upstream Pin Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Manifest pin | Repo-local manifest records upstream repo, commit, probe evidence, and update procedure. | yes |
| Git submodule | Add upstream source as a git submodule. |  |
| Installer/probe pin | Continue relying only on install/probe records and documentation. |  |
| Vendor snapshot | Copy upstream source into this repository. |  |

**User's choice:** Manifest pin.
**Notes:** ADR still must compare all four required options, but manifest pin is the intended recommendation.

---

## ADR Location and Validation

| Option | Description | Selected |
|--------|-------------|----------|
| `.planning/adr/ADR-001-upstream-pin.md` | Planning authority location. | yes |
| `docs/adr/ADR-001-upstream-pin.md` | Reader-facing docs location. |  |
| `docs/orchestra/ADR-upstream-pin.md` | Co-locate inside migrated Dev Orchestra docs. |  |

**User's choice:** `.planning/adr/ADR-001-upstream-pin.md`.
**Notes:** Since manifest pin is selected, submodule staging validation is not applicable except as an ADR explanation.

---

## the agent's Discretion

- Exact manifest path and schema.
- Exact ADR wording and comparison-table structure.
- Exact verification command list, provided it checks references, shell syntax, and existing smoke fixtures.

## Deferred Ideas

- Git submodule adoption is deferred unless a future phase reverses the manifest pin decision.
- Phase 15 specification system and Phase 16 Makefile workflow remain separate phases.
