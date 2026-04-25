# Phase 12: Risk Decisions, Verification & Handoff - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 12-risk-decisions-verification-handoff
**Areas discussed:** Decision fallback CLI naming, Audit log format and location, Rulebook enforcement mechanism, Smoke fixture runner and scope

---

## Decision Fallback CLI Naming

| Option | Description | Selected |
|--------|-------------|----------|
| `orch-decide / orch-approve / orch-reject` | Uniform orch- prefix, respects D9 | |
| Probe upstream first, use `hermes` if native, otherwise `orch-*` | Adapter pattern — avoids duplication | ✓ |
| `orch-decisions` (view) + `orch-approve` + `orch-reject` | Most complete with viewing capability | |

**User's choice:** Probe upstream first, use `hermes` if native, otherwise `orch-*`
**Follow-up:** If adapter path taken, update REQUIREMENTS.md DEC-01 to reference `orch-*` commands. User confirmed: yes, update REQUIREMENTS.md.
**Notes:** Resolves the D9-vs-REQUIREMENTS.md conflict by preferring upstream capabilities and creating adapter commands only as fallback.

---

## Audit Log Format and Location

| Option | Description | Selected |
|--------|-------------|----------|
| Global JSONL at `~/.local/share/hermes-orchestra/audit.jsonl` | Single global file | |
| Per-project JSONL at `~/.local/share/hermes-orchestra/{project}/audit.jsonl` | Per-project isolation, matches 4-layer architecture | ✓ |
| Both per-project JSONL + nightly projection to plain text | Most complete | |

**User's choice:** Per-project JSONL
**Follow-up questions:**
- Format: JSON Lines (JSONL) selected over plain text pipe-delimited.
- Schema: Full version selected (timestamp, level, project, type, decision, user_decision, details, approval_id, ttl, task_id, escalation_id, agent_source, session_id).
- Log rotation: Yes, by date or size.
- Skill update: Yes, update escalation-handler/SKILL.md to match new format and location.
- Writers: All `orch-*` commands write audit records.
- Query tool: `orch-audit [project-id]` command to view recent entries.
**Notes:** Replaces the outdated escalation-handler skill's `/tmp/hermes-orchestra/audit.log` plain text format.

---

## Rulebook Enforcement Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| `~/.hermes-orchestra/rules.json` (global adapter config) | Shared across projects | ✓ |
| Per-project `~/.local/state/hermes-orchestra/{project}/rules.json` | Project-specific customization | |
| Global + per-project overlay | Most flexible, most complex | |

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone `orch-risk-check` script | Callable by orch-start and skills | ✓ |
| Embedded only in escalation-handler SKILL.md | Simple but not reusable | |
| Bash function library (`lib/risk.sh`) | Reusable but not standalone command | |

**User's choice:** `~/.hermes-orchestra/rules.json` + standalone `orch-risk-check` script
**Follow-up questions:**
- Timing: Active checking (before execution) selected over passive-only.
- Extensibility: Phase 12 provides 3-5 built-in rules only. User customization deferred to post-v1.1.
**Notes:** `orch-risk-check` returns exit codes: 0=safe, 1=L1-L2, 2=L3, 3=L4.

---

## Smoke Fixture Runner and Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Pure Bash scripts + custom assertions | No external dependencies | ✓ |
| Bats (Bash Automated Testing System) | Mature framework but needs install | |
| Custom lightweight test runner | Simple but adds custom code | |

| Option | Description | Selected |
|--------|-------------|----------|
| `orch-verify` command only | Integrated but not standalone | |
| Standalone scripts only | Independent but no wrapper | |
| Both standalone scripts + `orch-verify` wrapper | Most flexible | ✓ |

**User's choice:** Pure bash scripts + `orch-verify` wrapper
**Follow-up questions:**
- Failure reporting: Detailed (test name, expected, actual, logs).
- Coverage matrix format: Markdown table with 3 columns (upstream native / adapter-provided / deferred) × v1.0 spec items.
**Notes:** Test scripts go in `scripts/tests/`, each self-contained with shared assertion library.

---

## Claude's Discretion

None in this session — user made explicit choices for all questions.

## Deferred Ideas

- User-customizable risk rulebook extension
- Audit log query/filtering by date range
- Remote adapter implementation
- Team collaboration / multi-user approvals
- gbrain integration
- Dashboard for audit visualization
- Automated audit log backup/archival

---

*Discussion completed: 2026-04-25*
