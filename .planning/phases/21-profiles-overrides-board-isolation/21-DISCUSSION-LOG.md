# Phase 21: Profiles, Overrides & Board Isolation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 21-profiles-overrides-board-isolation
**Areas discussed:** override merge semantics, multi-project isolation naming, memory promotion boundary

---

## Override Merge Semantics

| Option | Description | Selected |
|--------|-------------|----------|
| `model` direct override | Project-level `model` replaces the global profile model | ✓ |
| `model` layered merge | Try to combine project/global model config | |
| `toolsets` dual-set merge | Keep `enabled/disabled` and merge with project-level priority | ✓ |
| `toolsets` replace-whole-block | Project override replaces the full toolsets block | |
| `SOUL.md` layered assembly | `extends: global`, then global → project → role concatenation | ✓ |
| `SOUL.md` full replacement | Project SOUL fully replaces the inherited one | |

**User's choice:** 同意 the recommended merge model.
**Notes:** The locked semantics are: `model` direct override, `toolsets.enabled/disabled` merged with project-level priority, and `SOUL.md` assembled in `global → project → role` order.

---

## Multi-Project Isolation Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Single primary-key slug | One `project_slug` derives board, workspace, override, memory, and prefixes | ✓ |
| Independent naming per surface | Board/profile/workspace/memory may each use different names | |
| Partial shared naming | Some surfaces share a slug, others choose their own mapping | |

**User's choice:** 同意 the single-primary-key rule.
**Notes:** Locked mapping: board=`{project_slug}`, workspace root=`.hermes/projects/{project_slug}/`, override dir=`{repo}/.hermes/profiles/`, memory namespace=`project:{project_slug}`, and any prefix should also derive from the same slug.

---

## Memory Promotion Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Project-default + explicit promotion | Default to project namespace; only orchestrator or explicit user mark may promote globally | ✓ |
| Curator auto-promotes | Curator may silently elevate project learnings into global memory | |
| Global-first memory | New learnings can land directly in global memory by default | |
| Silent conflict preference | Query path may choose one side of project/global conflicts without surfacing the mismatch | |

**User's choice:** 同意 the recommended boundary.
**Notes:** Locked semantics are: default write to `project:{project_slug}`, only `orchestrator` or an explicit user `cross-project` mark can promote globally, curator may only suggest or queue review, and conflicting project/global entries must emit `conflict_warning`.

---

## the agent's Discretion

- Profile delivery shape remains open to research/planning.
- Final role naming normalization remains open to research/planning.

## Deferred Ideas

- Decide whether Phase 21 should materialize profiles as repo templates, installer-generated outputs, or another packaging strategy.
- Decide whether naming should normalize to `reviewer` or retain `tech-reviewer`, and whether reserved role names need a Phase 21 lock.
