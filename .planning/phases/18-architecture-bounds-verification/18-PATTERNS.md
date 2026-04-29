# Phase 18 Pattern Map: Architecture Bounds & Verification

**Phase:** 18 — Architecture Bounds & Verification
**Status:** Complete

## Planned Surfaces

| File | Role | Existing Pattern | Phase 18 Use |
|------|------|------------------|--------------|
| .planning/SPEC.md | Canonical architecture specification | Normative sections with requirement IDs and MUST/SHOULD language. | Add concise boundary notes under file bus, same-repository concurrency, and scope language. |
| specs/file-bus.md | Derived contract | Source, Consumers, Contract, Drift Check, Conformance Checks. | Add the same single-slot boundary and future-work note in Contract. |
| docs/orchestra/README.md | Human-facing package overview | Chinese user docs with tables, examples, and short explanatory paragraphs. | Add user-facing boundary paragraphs near the per-project bus and multi-project sections. |
| docs/orchestra/WORKFLOW.md | Operational workflow projection | Chinese step-by-step sections with bus tables and examples. | Add workflow boundary paragraphs near the bus table and startup/task dispatch sections. |
| .planning/PROJECT.md | Project scope and milestone state | Scope, out-of-scope, key decisions, current state. | Add the 10x pressure boundary and update milestone state after verification. |
| .planning/REQUIREMENTS.md | Requirement status and traceability | Checkbox requirements plus traceability table. | Mark ARCH-01 and ARCH-02 complete only after evidence passes. |
| .planning/ROADMAP.md | Phase status | Phase success criteria and progress table. | Mark Phase 18 complete only after evidence passes. |

## Existing Analog Patterns

### Canonical Normative Notes

Use the .planning/SPEC.md style:

- Requirement headings are stable anchors such as BUS-02, BUS-04, and MULTI-06.
- Boundary language belongs close to the section that could otherwise be misread.
- Future-work notes can be one paragraph and must not define new runtime behavior.

Phase 18 should avoid adding new requirement IDs. It is clarifying ARCH-01 and ARCH-02, not expanding the specification model.

### Derived Spec Contract Notes

Use specs/file-bus.md style:

- Keep Source and Consumers unchanged.
- Add contract bullets with exact, checkable wording.
- Keep Drift Check and Conformance Checks as executable commands.

### User-Facing Projection Notes

Use docs/orchestra/README.md and docs/orchestra/WORKFLOW.md style:

- Keep paragraphs short.
- Preserve current Chinese headings and examples.
- Add exact English boundary phrases where static verification needs stable strings.
- Do not rewrite diagrams or large examples.

### Verification Evidence

Use prior phase summaries and verification artifacts as the pattern:

- Record exact commands.
- Record pass/fail status.
- Tie results back to requirement IDs.
- State remaining risks or "None" explicitly.

## Data Flow and Authority

| Layer | Authority | Phase 18 Rule |
|-------|-----------|---------------|
| .planning/SPEC.md | Canonical source | Defines the fixed Runtime bus boundary and future same-project parallelism boundary. |
| specs/file-bus.md | Derived source | Mirrors canonical bus boundary and drift checks. |
| docs/orchestra/* | Human projection | Explains the boundary where users read bus and workflow docs. |
| Runtime scripts/tests | Evidence only | Existing scripts prove current behavior; Phase 18 does not change them. |

## Pattern Constraints

- Do not add same-project multi-task parallelism to v1.2.
- Do not create JSONL task event schemas, per-task namespace specs, or new locks.
- Do not modify docs/orchestra/scripts/bin or docs/orchestra/scripts/lib unless a verification failure proves a real drift bug.
- Do not change gbrain or upstream Hermes Agent core.
- Keep edits focused on documentation and planning evidence.

## Pattern Mapping Complete

The closest existing pattern is Phase 17's verification-first plan: static checks first, minimal patches only when checks reveal a gap, then rtk make test and a phase verification record.
