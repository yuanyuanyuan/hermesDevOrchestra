# Phase 17: Agent Rules Consolidation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `17-CONTEXT.md` - this log preserves the alternatives considered.

**Date:** 2026-04-28T22:16:25+08:00
**Phase:** 17-agent-rules-consolidation
**Areas discussed:** Phase scope handling, `AGENTS.md` Dev Orchestra block granularity, `CLAUDE.md` handling, merge verification standard

---

## Phase Scope Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal verification / necessary small fixes | Do not rewrite existing content; check success criteria and patch only real gaps. | yes |
| Lightly reorganize existing block | Reorder or simplify the Dev Orchestra block while preserving managed sections. | |
| Fully rewrite Dev Orchestra rules section | Recreate the whole Dev Orchestra section in Phase 17. | |
| Other | User-provided alternative. | |

**User's choice:** Minimal verification / necessary small fixes.
**Notes:** Current repository evidence shows `AGENTS.md` and `CLAUDE.md` already mostly satisfy Phase 17 success criteria.

---

## `AGENTS.md` Dev Orchestra Block Granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Keep the concise block and patch only real gaps | Preserve the current block shape; patch only stale or missing content. | yes |
| Add more role-boundary detail | Add more Hermes/Claude/Codex responsibilities to the block. | |
| Rewrite as a stricter MUST/MUST NOT checklist | Make `AGENTS.md` heavier but more explicit for agents. | |
| Other | User-provided alternative. | |

**User's choice:** Keep the concise block and patch only real gaps.
**Notes:** Avoid duplicating `.planning/SPEC.md` in `AGENTS.md`.

---

## `CLAUDE.md` Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Keep pointer-only and patch only missing authority references | Keep `CLAUDE.md` as an authority pointer to `AGENTS.md` and `.planning/SPEC.md`. | yes |
| Add a short authority precedence paragraph | Clarify precedence directly in `CLAUDE.md`. | |
| Copy key Dev Orchestra rules into `CLAUDE.md` | Improve single-file readability but increase drift risk. | |
| Other | User-provided alternative. | |

**User's choice:** Keep pointer-only and patch only missing authority references.
**Notes:** This aligns with AGNT-02: if `CLAUDE.md` exists, it should point to authorities without repeating all rules.

---

## Merge Verification Standard

| Option | Description | Selected |
|--------|-------------|----------|
| Static agent-rule checks plus `make test` | Verify managed markers, delimiters, sections, helper list, L3/L4 wording, `CLAUDE.md` pointers, then run full local test target. | yes |
| Static agent-rule checks only | Faster, but does not exercise Phase 16 verification workflow. | |
| Static checks plus targeted Make targets | Lighter than `make test`; runs selected Make targets. | |
| Other | User-provided alternative. | |

**User's choice:** Static agent-rule checks plus `make test`.
**Notes:** Phase 16 created the root `Makefile`; Phase 17 should use it as the selected verification gate.

---

## the agent's Discretion

- Exact static-check command implementation.
- Exact wording for any small source fix if verification exposes a real gap.
- Whether no source edit is required if the current files already pass.

## Deferred Ideas

None.
