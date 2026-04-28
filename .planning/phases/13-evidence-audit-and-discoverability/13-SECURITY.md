---
phase: 13
slug: evidence-audit-and-discoverability
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-28
verified: 2026-04-28T09:05:00Z
---

# Phase 13 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| GSD managed content vs project appendices | `AGENTS.md` contains GSD-managed blocks and project-specific Dev Orchestra rules. | Markdown agent instructions and authority rules |
| Planning evidence vs current worktree | Phase 13 evidence records dirty worktree state without treating unrelated files as deliverables. | Git status, path inventory, planning metadata |
| Documentation phase vs runtime package | Phase 13 may update documentation/planning artifacts but must not migrate paths or edit runtime helper scripts. | Repository docs, runtime helper paths |
| Risk classifier wording vs approval authority | Documentation must distinguish `orch-risk-check` classification from the L3/L4 user-decision blocking path. | Safety rules, user approval flow, helper names |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-13-01 | Tampering | `AGENTS.md` managed blocks | mitigate | Dev Orchestra content is delimited by `<!-- hermes-dev-orchestra-start -->` / `<!-- hermes-dev-orchestra-end -->` and appears after `<!-- GSD:profile-end -->`; verification confirms existing `<!-- GSD:* -->` markers remain present. | closed |
| T-13-02 | Integrity | L3/L4 safety documentation | mitigate | `AGENTS.md` names the actual blocking flow through `escalation.md` or high-risk `claude-decision.md`, `orch-bus-loop`, pending decisions, and explicit `orch-decisions` / `orch-approve` / `orch-reject`; it states `orch-risk-check` is only a risk classifier/helper. | closed |
| T-13-03 | Repudiation | Worktree evidence attribution | mitigate | `13-EVIDENCE.md` records `git status --short --branch` at audit start and includes `## Pre-existing Worktree Attribution` for unrelated staged/untracked files. | closed |
| T-13-04 | Tampering | Runtime helper and path migration boundary | mitigate | Phase 13 did not edit `docs/hermes-dev-orchestra/scripts`, `docs/hermes-dev-orchestra/config`, or `docs/hermes-dev-orchestra/skills`; path migration is deferred to Phase 14 and the smoke suite still passes. | closed |

*Status: open · closed*  
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

No accepted risks.

---

## Evidence

| Threat ID | Evidence |
|-----------|----------|
| T-13-01 | `AGENTS.md` lines 84-112; `13-VERIFICATION.md` check 4. |
| T-13-02 | `AGENTS.md` lines 100-103; `13-VERIFICATION.md` checks 6-7. |
| T-13-03 | `13-EVIDENCE.md` lines 9-31; `13-VERIFICATION.md` check 1. |
| T-13-04 | `git diff --name-only 36bca38..HEAD -- docs/hermes-dev-orchestra/scripts docs/hermes-dev-orchestra/config docs/hermes-dev-orchestra/skills` returned no files; `13-VERIFICATION.md` check 11 records `Smoke summary: 9 passed, 0 failed`. |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-28 | 4 | 4 | 0 | Codex inline security audit |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-28
