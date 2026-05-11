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

## Milestone: v1.3 — Hermes 原生工作流 MVP 实现

**Shipped:** 2026-05-11
**Phases:** 6 | **Plans:** 6 | **Tasks:** 4

### What Was Built

- Phase 20 locked the official-vs-local Hermes capability boundary with an executable verification matrix and writeback to the phase 19 design package.
- Phase 21 established project-scoped profile compilation, repo-local overrides, and baseline multi-project isolation rooted at `.hermes/projects/{project_slug}/`.
- Phase 22 introduced the first `hermes-role-engine/v1` request/response contract and failure-normalization path for external CLI execution.
- Phase 23 converted the primary orchestration path to Kanban-native routing with parent-linked handoff metadata instead of CLI session resume.
- Phase 24 added one canonical `risk-policy.yaml`, runtime hook guardrails, and the implementer mandatory block contract.
- Phase 25 closed the MVP with timeout/reclaim control, structured handoff hardening, hook-based observability, environment snapshots, conservative backpressure, and one end-to-end acceptance chain.

### What Worked

- The phase 19 design package stayed stable as the source of truth while execution milestones landed in separate numbered phases.
- Profile assembly, engine protocol, routing, and guardrails were added as thin layers on top of the upstream Hermes runtime instead of drifting into a local reimplementation.
- Verification artifacts remained traceable from requirements to plan, summary, verification, milestone audit, and final archive.

### What Was Inefficient

- The aggregate repo gate could not return fully green during closeout because `upstream-status` still depends on an inherited runtime pin mismatch outside the milestone scope.
- `milestone.complete` generated only minimal accomplishment output, so milestone closeout still required manual ROADMAP/PROJECT/retrospective cleanup.
- Nyquist validation coverage did not stay consistent across phases 22-25, leaving partial validation metadata even though verification artifacts were complete.

### Patterns Established

- Treat official Hermes capability claims as matrix-verified inputs before implementation work starts.
- Keep profile/runtime isolation project-scoped and compile repo-local overrides instead of mutating global Hermes homes.
- Use metadata-first routing, risk, and handoff contracts so external CLI workers remain stateless.

### Key Lessons

- Milestone closeout needs SUMMARY plus VERIFICATION for every completed plan; missing summaries create avoidable archive friction.
- Hook-based observability and structured handoff are enough for an MVP orchestration loop without patching Hermes core.
- The next milestone should either normalize the runtime pin workflow early or explicitly keep aggregate-gate health out of milestone completion criteria.

## Cross-Milestone Trends

| Trend | Evidence | Follow-up |
|-------|----------|-----------|
| Spec-first planning reduces scope creep | v1.0 completed with 60/60 requirements and no audit gaps | Preserve for implementation milestone |
