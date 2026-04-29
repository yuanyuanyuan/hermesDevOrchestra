# Phase 18: Architecture Bounds & Verification - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 18 closes the v1.2 milestone by making the architecture bounds explicit and verifiable. It does not add same-project parallel execution or new runtime capabilities. It clarifies that the current fixed-file Runtime bus represents one active task slot per project, limits the "10x" claim to single-developer multi-project orchestration with one active task per project, and verifies the milestone evidence before completion.

</domain>

<decisions>
## Implementation Decisions

### Fixed Filename Bus Boundary
- **D-18-01:** State the fixed-file Runtime bus limitation in all relevant surfaces: `.planning/SPEC.md`, `specs/file-bus.md`, `docs/orchestra/README.md`, and `docs/orchestra/WORKFLOW.md`.
- **D-18-02:** The wording must say that fixed bus filenames such as `task.md`, `codex-question.md`, `claude-decision.md`, `codex-result.md`, and `review-result.md` represent the current active task slot for a project.
- **D-18-03:** Queued or appended work can exist in todo/state layers, but the current Runtime bus does not represent multiple simultaneously active tasks inside the same project.

### Future Same-Project Parallelism
- **D-18-04:** Same-project multi-task parallelism is out of scope for v1.2 and must be described as v2 or future work.
- **D-18-05:** If future parallelism is mentioned, name the design areas that require a separate design pass: JSONL/event bus, per-task file namespaces, per-task locks, worktrees or per-task branches, and merge/review arbitration.
- **D-18-06:** Do not implement or spec a full v2 parallel execution design in Phase 18. The task is to make the boundary explicit, not to expand scope.

### 10x Claim Boundary
- **D-18-07:** Use direct limiting language: "10x" means a single developer can reduce coordination overhead and manage multiple projects through Hermes orchestration.
- **D-18-08:** Explicitly state that v1.2 does not promise multiple Codex tasks executing in parallel within the same project.
- **D-18-09:** Explicitly state that v1.2 does not promise team-scale or AI-factory-style high concurrency.

### Milestone Verification Scope
- **D-18-10:** Phase 18 planning must include a complete closeout gate: update ARCH-01/ARCH-02 documents, run static drift checks, run `rtk make test`, verify Phase 13-18 requirements traceability, create Phase 18 verification, and confirm the milestone is ready for `$gsd-complete-milestone`.
- **D-18-11:** Verification should check both canonical and projection surfaces so the architecture boundary does not drift between `.planning/SPEC.md`, `specs/file-bus.md`, and `docs/orchestra/*`.

### the agent's Discretion
- Exact wording may be concise, but it must preserve the decisions above.
- Exact static drift-check implementation is discretionary, provided it proves the fixed-file bus limitation, future-work boundary, 10x limitation, and milestone traceability.
- Exact document section placement is discretionary, provided downstream readers can find the boundary before relying on parallelism assumptions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture and Requirements
- `.planning/ROADMAP.md` — Phase 18 goal, success criteria, and milestone position.
- `.planning/REQUIREMENTS.md` — ARCH-01 and ARCH-02 requirements and v1.2 traceability.
- `.planning/PROJECT.md` — Single-developer, multi-project scope and out-of-scope team/AI-factory boundaries.
- `.planning/SPEC.md` §§BUS-01..BUS-06 — Canonical file bus protocol and writer/reader ownership.
- `.planning/SPEC.md` §MULTI-06 — Same-repository concurrency serialization and future worktree note.
- `.planning/SPEC.md` §VERIFY-01 — Acceptance scenarios for task execution, blocked projects, append-while-running, and multi-project yielding.

### Derived Specs and Projections
- `specs/file-bus.md` — Derived file-bus contract and drift/conformance checks.
- `docs/orchestra/README.md` — Human-facing projection of file bus files, multi-project orchestration, and current user-facing promises.
- `docs/orchestra/WORKFLOW.md` — Workflow projection of task dispatch, file bus state, and multi-project scheduling.
- `docs/COVERAGE-MATRIX.md` — v1.1 coverage and handoff evidence; useful for milestone closeout checks.

### Runtime and Tests
- `docs/orchestra/scripts/bin/orch-bus-loop` — Current Runtime bus routing behavior.
- `docs/orchestra/scripts/lib/orch-common.sh` — Shared stage detection, project state, and archive behavior.
- `docs/orchestra/scripts/tests/test-file-bus.sh` — Existing smoke coverage for file-bus routing and stale review handling.
- `Makefile` — `rtk make test` aggregate verification entrypoint.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Makefile`: Existing aggregate local verification target; Phase 18 should use `rtk make test`.
- `docs/orchestra/scripts/tests/test-specs.sh`: Existing derived-spec conformance coverage.
- `docs/orchestra/scripts/tests/test-file-bus.sh`: Existing file-bus smoke fixture that can support drift checks.
- `docs/orchestra/scripts/bin/orch-bus-loop`: Runtime evidence for current fixed-file bus behavior.
- `docs/orchestra/scripts/lib/orch-common.sh`: Contains stage detection around fixed Runtime files and task archival.

### Established Patterns
- `.planning/SPEC.md` is canonical; `specs/*.md` and `docs/orchestra/*` are projections.
- Derived specs must list concrete current consumers and include drift/conformance checks.
- Phase 17 used verification-first execution and only patched real gaps. Phase 18 should follow the same minimal, evidence-led style.
- Runtime bus files keep `.md` names for compatibility, but their contents are canonical JSON envelopes.

### Integration Points
- ARCH-01 likely touches `.planning/SPEC.md`, `specs/file-bus.md`, `docs/orchestra/README.md`, and `docs/orchestra/WORKFLOW.md`.
- ARCH-02 likely touches user-facing promise language in docs and may also update `.planning/PROJECT.md` if current state or milestone summary needs the clarified 10x boundary.
- Final verification should update `.planning/phases/18-architecture-bounds-verification/18-VERIFICATION.md` and prepare milestone completion.

</code_context>

<specifics>
## Specific Ideas

- Suggested phrase: "The fixed Runtime bus filenames represent one active task slot per project. They are not a per-project multi-task parallel execution protocol."
- Suggested phrase: "10x means lower coordination overhead across multiple projects for one developer, not same-project multi-agent parallel execution or team-scale throughput."
- Suggested future-work note: "Same-project parallelism would require a separate design covering JSONL/event bus semantics, per-task namespaces, locks, worktrees/branches, and merge/review arbitration."
- Suggested verification checks:
  - `rg -n "one active task slot|single active task|same-project parallelism|10x" .planning/SPEC.md specs/file-bus.md docs/orchestra/README.md docs/orchestra/WORKFLOW.md`
  - `rtk make test`
  - Phase 13-18 requirement traceability review in `.planning/REQUIREMENTS.md`

</specifics>

<deferred>
## Deferred Ideas

- Full same-project multi-task parallel execution design — future v2 or a separate milestone, not Phase 18.
- Team-scale or AI-factory high-concurrency orchestration — outside current single-developer v1.2 scope.

</deferred>

---
*Phase: 18-architecture-bounds-verification*
*Context gathered: 2026-04-29*
