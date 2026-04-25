# Retrospective

## Milestone: v1.0 — Hermes Dev Orchestra Specification Package

**Shipped:** 2026-04-25
**Phases:** 7 | **Plans:** 7 | **Tasks:** 21

### What Was Built

- Scope, Package Coverage & Authority contracts are finalized in SPEC.md §0-§1 and Appendix C with requirement-level verification evidence.
- Runtime, Installation & Command Contracts contracts are finalized in SPEC.md §2 with requirement-level verification evidence.
- File Bus, Decision Envelope, State & Audit contracts are finalized in SPEC.md §3 and Appendix B with requirement-level verification evidence.
- Multi-Project Scheduling & Isolation contracts are finalized in SPEC.md §4 with requirement-level verification evidence.
- Agent Protocol, Challenge & Evidence contracts are finalized in SPEC.md §5 with requirement-level verification evidence.
- Risk Rulebook & Remote Decision Contract contracts are finalized in SPEC.md §6 and Appendix A with requirement-level verification evidence.
- Recovery, Observability, Verification & Handoff contracts are finalized in SPEC.md §7-§8 and Appendix C with requirement-level verification evidence.

### What Worked

- Spec-first GSD phases kept the deliverable focused on contracts instead of premature implementation.
- Requirement IDs stayed traceable from ROADMAP to SPEC, SUMMARY, VERIFICATION, and audit.
- Remote Decision Channel remained abstract while still providing a concrete local fallback contract.

### What Was Inefficient

- Local GSD helper agents were not installed, so phase artifacts were generated inline rather than by registered subagents.
- The SDK `milestone.complete` helper is incomplete in this environment, requiring manual archival orchestration.

### Patterns Established

- Keep JSON/JSONL as canonical protocol and Markdown as projection.
- Archive completed milestone context to keep active ROADMAP/REQUIREMENTS small.
- Treat L3/L4 decisions as explicit-user-only invariants across every phase.

### Key Lessons

- Future implementation work must start with fresh requirements and current CLI capability checks.
- Risk rule floors, state/audit separation, and replay-resistant decisions should be built before any UX or adapter layer.

## Cross-Milestone Trends

| Trend | Evidence | Follow-up |
|-------|----------|-----------|
| Spec-first planning reduces scope creep | v1.0 completed with 60/60 requirements and no audit gaps | Preserve for implementation milestone |
