# Phase 15: Specification System - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `15-CONTEXT.md`; this log preserves alternatives considered.

**Date:** 2026-04-28
**Phase:** 15 - Specification System
**Areas discussed:** Derived spec inventory and consumers; Spec file shape and metadata; Conformance check location and runner; Canonical conflict handling

---

## Derived Spec Inventory and Consumers

| Option | Description | Selected |
|---|---|---|
| Minimum effective set | Create only specs with current consumers. | yes |
| Future phase consumers | Include v1.2 future phase consumers too. | |
| Full split | Split major `.planning/SPEC.md` sections. | |

**User's choice:** Agreed with the recommended minimum effective set.
**Notes:** Create `specs/file-bus.md`, `specs/risk-decisions.md`, `specs/commands.md`, and `specs/README.md`.

---

## Spec File Shape and Metadata

| Option | Description | Selected |
|---|---|---|
| Fixed Markdown sections | Use `Source`, `Consumers`, `Drift Check`, and `Conformance Checks` sections. | yes |
| YAML frontmatter | Store metadata in frontmatter and explain in prose. | |
| Central table | Use a table-based metadata block. | |

**User's choice:** Agreed with the recommended fixed Markdown sections.
**Notes:** `.planning/SPEC.md` is the primary source; `docs/orchestra/*` can be cited only as implementation projections. Consumer paths must be concrete.

---

## Conformance Check Location and Runner

| Option | Description | Selected |
|---|---|---|
| New `test-specs.sh` | Add `docs/orchestra/scripts/tests/test-specs.sh` and rely on `run-all.sh`. | yes |
| Merge into `test-docs.sh` | Put all checks into the existing docs test. | |
| `specs/check.sh` | Put a checker under the specs directory. | |

**User's choice:** Agreed with the recommended new smoke test.
**Notes:** Checks must fail on missing required sections, missing canonical source, missing consumer paths, missing drift checks, missing conformance checks, or specs missing from `specs/README.md`.

---

## Canonical Conflict Handling

| Option | Description | Selected |
|---|---|---|
| Canonical wins | `.planning/SPEC.md` always wins; derived specs must align. | yes |
| Spec backfill | Let derived specs lead, then backfill canonical. | |
| Planner decides | Leave conflict handling to downstream planner judgment. | |

**User's choice:** Agreed with the recommended canonical-wins rule.
**Notes:** Implementation/spec conflicts should fail fast. Broad canonical rewrites are out of Phase 15 unless explicitly scoped later.

---

## the agent's Discretion

- Exact prose wording in derived specs.
- Exact Bash/Python implementation details for `test-specs.sh`.
- Exact drift check command text, as long as it is concrete and can fail.

## Deferred Ideas

- Full split of all `.planning/SPEC.md` sections.
- Phase 15 Makefile targets; Phase 16 owns Makefile work.
- Broad canonical spec rewrites for v1.2 detail gaps.
