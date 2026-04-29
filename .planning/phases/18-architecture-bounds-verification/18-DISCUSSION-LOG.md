# Phase 18: Architecture Bounds & Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `18-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-29T00:00:04Z
**Phase:** 18-Architecture Bounds & Verification
**Areas discussed:** Fixed filename bus boundary, Future same-project parallelism, 10x claim boundary, Milestone verification scope

---

## Fixed Filename Bus Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Strict and visible | Update `.planning/SPEC.md`, `specs/file-bus.md`, `docs/orchestra/README.md`, and `docs/orchestra/WORKFLOW.md` to state that fixed Runtime bus filenames are the current active task slot. | yes |
| Canonical only | Only update `.planning/SPEC.md` and `specs/file-bus.md`. | |
| User docs only | Only update README/WORKFLOW projections. | |
| Other | User specifies another file scope. | |

**User's choice:** Strict and visible.
**Notes:** This is the core ARCH-01 evidence, so downstream planning should include canonical, derived, and projection surfaces.

---

## Future Same-Project Parallelism

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit v2 directions | Mark same-project parallelism as out of scope for v1.2 and list design areas: JSONL/event bus, per-task namespaces, per-task locks, worktrees/branches, merge/review arbitration. | yes |
| One-line future work | Mention future worktrees only, without expanded design areas. | |
| Deferred ADR | Add a future ADR/backlog item and keep current docs brief. | |
| Other | User specifies future design directions to include or avoid. | |

**User's choice:** Explicit v2 directions.
**Notes:** The plan should not implement v2 parallelism; it should make the design boundary explicit.

---

## 10x Claim Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Direct limitation | State that 10x means single-developer multi-project orchestration, not same-project parallel Codex execution or team/AI-factory high concurrency. | yes |
| Softer limitation | Focus on current scope without strong negative claims. | |
| Product wording | Emphasize less context switching and safer single-line project execution. | |
| Other | User provides preferred wording. | |

**User's choice:** Direct limitation.
**Notes:** Downstream planning should use direct wording in docs so the claim cannot be misread as high-concurrency execution.

---

## Milestone Verification Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Complete closeout | Update ARCH-01/ARCH-02 docs, run static drift checks, run `rtk make test`, verify Phase 13-18 traceability, generate Phase 18 verification, and confirm readiness for `$gsd-complete-milestone`. | yes |
| Phase 18 only | Verify ARCH-01/ARCH-02 and `rtk make test` only. | |
| Document audit first | Prioritize doc consistency, with tests as a secondary gate. | |
| Other | User specifies required or excluded validation items. | |

**User's choice:** Complete closeout.
**Notes:** This is the final v1.2 phase, so planning should treat milestone readiness as part of the phase output.

---

## the agent's Discretion

- Exact wording of the architecture bound.
- Exact section placement in canonical and projection documents.
- Exact static drift-check implementation.

## Deferred Ideas

- Same-project multi-task parallel execution design belongs to v2 or a separate milestone.
- Team-scale or AI-factory concurrency remains outside v1.2.
