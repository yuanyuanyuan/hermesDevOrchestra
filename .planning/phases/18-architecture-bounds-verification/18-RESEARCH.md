# Phase 18 Research: Architecture Bounds & Verification

**Phase:** 18 — Architecture Bounds & Verification
**Date:** 2026-04-29
**Status:** Complete

## Research Questions

1. Where does the current Runtime bus contract define fixed filenames and ownership?
2. Which surfaces must state that those fixed filenames are one active task slot per project?
3. How should future same-project parallelism be bounded without designing v2 in this phase?
4. How should the "10x" claim be limited for v1.2?
5. What verification proves the v1.2 milestone is ready to complete?

## Findings

### Fixed Runtime Bus Evidence

The canonical bus contract already uses fixed file names:

| Source | Evidence | Planning Implication |
|--------|----------|----------------------|
| .planning/SPEC.md BUS-02 | Lists task.md, codex-question.md, claude-decision.md, escalation.md, codex-result.md, review-result.md, and event.jsonl message types. | Add an explicit boundary note near BUS-02/BUS-04. |
| .planning/SPEC.md BUS-04 | Writer/reader table says task.md and result files are overwritten or created/deleted in place. | State these files represent one current active task slot for a project. |
| specs/file-bus.md | Derived contract lists the same ownership map. | Add the same boundary so the derived spec does not overpromise parallelism. |
| docs/orchestra/README.md | Human-facing per-project bus table lists the fixed files. | Add the boundary immediately below the table for user-facing clarity. |
| docs/orchestra/WORKFLOW.md | Workflow tables and examples list the same fixed files. | Add the boundary in the file bus section and workflow setup section. |

Runtime implementation confirms the same shape:

| Source | Evidence | Planning Implication |
|--------|----------|----------------------|
| docs/orchestra/scripts/bin/orch-bus-loop | Dispatches task.md, stores last-task.hash, routes codex-question.md, claude-decision.md, codex-result.md, and review-result.md. | Verification can cite runtime behavior without changing scripts. |
| docs/orchestra/scripts/lib/orch-common.sh | Detects stages by the presence of fixed Runtime files and archives task artifacts as a fixed file set. | The current stage model is single active slot, not per-task namespaces. |
| docs/orchestra/scripts/tests/test-file-bus.sh | Creates one task.md, drives one question/decision/result/review cycle, then verifies archive behavior. | Existing tests cover the single-slot file bus smoke path. |

### Same-Project Parallelism Boundary

Phase 18 must not design or implement same-project multi-task parallel execution. The required boundary is a short future-work note that says same-project parallelism is out of scope for v1.2 and would require a separate design pass covering:

- JSONL/event bus semantics
- per-task file namespaces
- per-task locks
- worktrees or per-task branches
- merge/review arbitration

The current .planning/SPEC.md MULTI-06 already serializes same-repository access with .hermes-lock and mentions future worktree isolation. Phase 18 should expand that note enough to avoid ambiguity while staying out of v2 design.

### 10x Boundary

Current project scope is single-developer, multi-project orchestration. .planning/SPEC.md and .planning/PROJECT.md already exclude team collaboration and AI factory/high-throughput mode. Phase 18 should make the pressure boundary grep-verifiable:

"10x" means lower coordination overhead across multiple projects for one developer; it does not promise same-project parallel Codex execution, team-scale concurrency, or AI-factory throughput.

This sentence should appear in canonical/project/user-facing surfaces where readers may otherwise infer high concurrency from multi-project orchestration.

## Recommended Implementation

Patch only documentation and planning state:

1. Add the fixed Runtime bus boundary to .planning/SPEC.md, specs/file-bus.md, docs/orchestra/README.md, and docs/orchestra/WORKFLOW.md.
2. Add the future same-project parallelism note to .planning/SPEC.md and specs/file-bus.md, and a concise user-facing version to docs/orchestra/README.md and docs/orchestra/WORKFLOW.md.
3. Add the "10x" boundary sentence to .planning/PROJECT.md, .planning/SPEC.md, docs/orchestra/README.md, and docs/orchestra/WORKFLOW.md.
4. After static checks and rtk make test pass, mark ARCH-01 and ARCH-02 complete in .planning/REQUIREMENTS.md, update .planning/ROADMAP.md Phase 18 status, and create Phase 18 verification evidence.

## Validation Architecture

### Quick Static Checks

The executor should run a static drift check that requires the fixed bus boundary phrase in all four core surfaces:

```bash
rtk bash -lc 'set -euo pipefail
for f in .planning/SPEC.md specs/file-bus.md docs/orchestra/README.md docs/orchestra/WORKFLOW.md; do
  grep -Fq "fixed Runtime bus filenames represent one active task slot per project" "$f"
  grep -Fq "not a per-project multi-task parallel execution protocol" "$f"
done
'
```

The executor should also check future-work and 10x boundary phrases:

```bash
rtk bash -lc 'set -euo pipefail
for needle in \
  "Same-project parallelism is out of scope for v1.2." \
  "JSONL/event bus semantics" \
  "per-task file namespaces" \
  "per-task locks" \
  "worktrees or per-task branches" \
  "merge/review arbitration" \
  "\"10x\" means lower coordination overhead across multiple projects for one developer" \
  "does not promise same-project parallel Codex execution"; do
  rg -F "$needle" .planning/SPEC.md specs/file-bus.md docs/orchestra/README.md docs/orchestra/WORKFLOW.md .planning/PROJECT.md >/dev/null
done
'
```

### Full Gate

Run the existing aggregate verification:

```bash
rtk make test
```

### Traceability Gate

After the documentation patches pass, update and verify:

- ARCH-01 and ARCH-02 are checked in .planning/REQUIREMENTS.md.
- v1.2 traceability shows ARCH-01 and ARCH-02 as Complete.
- .planning/ROADMAP.md marks Phase 18 complete with 1/1 plans.
- Phase 18 verification evidence exists and states the milestone is ready for $gsd-complete-milestone.

## Risks

| Risk | Mitigation |
|------|------------|
| Docs imply same-project parallel Codex execution. | Add exact negative wording in canonical, derived, and user-facing docs. |
| v2 design scope leaks into Phase 18. | List future design areas but do not add schemas, commands, locks, or implementation. |
| 10x claim is read as team-scale throughput. | Use a single explicit limiting sentence and grep it. |
| Traceability is marked complete before evidence. | Require static checks and rtk make test before updating ARCH status. |

## Research Complete

Phase 18 can be executed as a single documentation-and-verification plan. No code changes are needed unless existing tests reveal drift.
