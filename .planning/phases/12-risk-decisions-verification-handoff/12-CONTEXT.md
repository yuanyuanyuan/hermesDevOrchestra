# Phase 12: Risk Decisions, Verification & Handoff - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Interactive discuss-phase with 4 gray areas explored

<domain>
## Phase Boundary

This phase implements the safety enforcement layer and verification suite for the upstream-based Hermes Dev Orchestra:

- **L3/L4 risk blocking**: Static rulebook + active enforcement that prevents auto-approval of dangerous operations
- **Local decision fallback**: File-based `orch-decisions/approve/reject` commands when no remote channel is configured
- **Audit records**: JSONL per-project audit trail with full fields and rotation
- **Smoke fixtures**: Bash-based verification covering 6 VER-01 areas
- **Coverage matrix**: Markdown table separating upstream-native, adapter-provided, and deferred v1.0 capabilities
- **Handoff**: Document for remote adapter, production hardening, and future milestones

It does NOT implement the runtime orchestration loop (Phase 11), the installer (Phase 10), or remote adapters (deferred). It assumes Phase 11 has implemented `orch-init`, `orch-start`, `orch-stop`, `orch-status`, and the file bus watcher.

</domain>

<decisions>
## Implementation Decisions

### Decision Fallback CLI Naming (D-12-01)
- **Probe-first approach**: Before creating any adapter commands, check if upstream `hermes` has native `decisions`, `approve`, `reject` commands.
- **If upstream has them**: Use upstream commands directly. Do not create `orch-*` equivalents.
- **If upstream does NOT have them**: Create adapter commands `orch-decisions` (view pending), `orch-approve <id>`, `orch-reject <id>`.
- **REQUIREMENTS.md update**: If the adapter path is taken, update DEC-01 to reference `orch-*` commands instead of `hermes` subcommands.
- **Rationale**: Respects D9 (local entrypoints are `orch-*` only) while avoiding unnecessary duplication if upstream already provides the capability.

### Audit Log Format and Location (D-12-02)
- **Format**: JSON Lines (JSONL) — canonical per PROJECT.md.
- **Location**: Per-project at `~/.local/share/hermes-orchestra/{project}/audit.jsonl`.
- **Schema** (full fields):
  ```json
  {
    "timestamp": "2026-04-25T10:30:00+08:00",
    "level": "L3",
    "project": "project-a",
    "type": "SECURITY",
    "decision": "APPROVED",
    "user_decision": "用户批准执行",
    "details": "需要修改 JWT 密钥轮换策略",
    "approval_id": "uuid-v4",
    "ttl": 3600,
    "task_id": "task-123",
    "escalation_id": "esc-456",
    "agent_source": "escalation-handler",
    "session_id": "sess-789"
  }
  ```
- **Rotation**: Yes, by date or size (daily rotation, or >10MB per file).
- **Writers**: ALL `orch-*` commands write audit records (project init, session start/stop, decisions, escalations).
- **Query**: Provide `orch-audit [project-id]` command to view recent audit records (time-descending, last N entries).
- **SKILL.md update**: Update `escalation-handler/SKILL.md` to use JSONL format and `~/.local/share/hermes-orchestra/{project}/audit.jsonl` location (was `/tmp/hermes-orchestra/audit.log` plain text).

### Rulebook Enforcement Mechanism (D-12-03)
- **Rules file**: `~/.hermes-orchestra/rules.json` (global adapter config, shared across projects).
- **Enforcement form**: Standalone `orch-risk-check` script that reads `rules.json` and evaluates an operation against rules.
- **Timing**: Active checking — `orch-start` and other commands call `orch-risk-check` proactively before executing dangerous operations.
- **Rule schema** (Phase 12):
  ```json
  [
    {"id": "rule-001", "level": "L3", "patterns": ["rm -rf /", "DROP TABLE", "DELETE FROM", "TRUNCATE"], "description": "Destructive data operations"},
    {"id": "rule-002", "level": "L3", "patterns": ["sudo", "chmod 777"], "description": "System privilege escalation"},
    {"id": "rule-003", "level": "L4", "patterns": ["ALTER TABLE DROP", "docker system prune", "kubectl delete"], "description": "System-level destructive commands"},
    {"id": "rule-004", "level": "L3", "patterns": ["ALTER TABLE", "CREATE TABLE", "DROP TABLE"], "description": "Database schema changes"},
    {"id": "rule-005", "level": "L4", "patterns": ["修改 .env", "修改密钥", "修改认证", "修改 JWT"], "description": "Authentication and secret modifications"}
  ]
  ```
- **Extensibility**: Phase 12 provides 3-5 built-in rules only. User customization is deferred to post-v1.1.
- **Integration**: `orch-risk-check` returns exit code 0 (safe), 1 (L1-L2), 2 (L3), 3 (L4). Callers decide how to handle each level.

### Smoke Fixture Runner and Scope (D-12-04)
- **Runner**: Pure bash scripts with custom assertion functions (no external test framework dependency).
- **Structure**:
  - Individual test scripts in `scripts/tests/` directory (e.g., `scripts/tests/test-install-probe.sh`, `scripts/tests/test-skills-load.sh`, etc.)
  - Each script is self-contained, sources a shared assertion library, reports pass/fail
- **Integration**: `orch-verify` command runs all tests in `scripts/tests/`, aggregates results, and prints a summary.
- **Failure reporting**: Detailed — shows test name, expected value, actual value, and relevant log excerpts.
- **Scope** (VER-01, 6 areas):
  1. Upstream install/probe (`hermes --version`, commit pin verification)
  2. Skills load (`hermes skills list` contains our 4 skills)
  3. `orch-init` (Git validation, directory creation, settings.json copy)
  4. `orch-start` (tmux session creation/reuse, process health)
  5. File bus routing (write `task.md` → Codex reads; write `codex-question.md` → Claude reads; write `claude-decision.md` → Codex reads)
  6. Risk block (`orch-risk-check` detects L3/L4 operations; escalation blocks until user decision)
  7. Status (`orch-status` shows project states and file bus stages) — *bonus, if time permits*
- **Coverage matrix** (VER-03): Markdown table with 3 columns (upstream native / adapter-provided / still deferred) × v1.0 specification items. Written to `docs/COVERAGE-MATRIX.md`.

### Claude's Discretion
- Exact `orch-risk-check` implementation details (regex vs keyword matching, output format) are left to implementation discretion.
- Exact `orch-audit` output formatting (table, JSON, plain text) is left to implementation discretion.
- Exact smoke test assertion library design is left to implementation discretion.
- Coverage matrix row granularity (per-requirement or per-feature) is left to implementation discretion.
- Handoff document (VER-04) structure and depth is left to implementation discretion.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — v1.1 requirement list (SAFE-01..SAFE-02, DEC-01..DEC-02, VER-01..VER-04)
- `.planning/ROADMAP.md` — Phase 12 goals, success criteria, execution order
- `.planning/PROJECT.md` — Vision, constraints, key decisions, current state
- `.planning/STATE.md` — Current progress and locked decisions

### Product Intent
- `docs/hermes-dev-orchestra/README.md` — Product behavior baseline: §5 safety rules, §6.3 escalation flow, §7.2 risk levels, §8 audit log
- `docs/hermes-dev-orchestra/hermes/SOUL.md` — Hermes orchestrator personality (safety constraints section)

### Skills (to be updated in Phase 12)
- `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` — Must be updated: audit log format (JSONL), audit log location (`~/.local/share/`), L3/L4 blocking details
- `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` — May need update for `orch-decisions/approve/reject` references

### Prior Phase Context
- `.planning/phases/09-upstream-hermes-agent-baseline/09-CONTEXT.md` — Phase 9 locked decisions (D1-D9, including D9 command boundary)
- `.planning/phases/10-orchestra-package-installer-skills-layout/10-CONTEXT.md` — Phase 10 locked decisions (D-01..D-12)
- `.planning/phases/11-project-bootstrap-tmux-runtime-file-bus/11-CONTEXT.md` — Phase 11 locked decisions (D-11-01..D-11-13)

### Upstream Baseline
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md` — Upstream capability matrix, pinned commit SHA

</canonical_refs>

<code_context>
## Existing Code Insights

### Phase 10-11 Assets (to be used/enforced in Phase 12)
- `orch-init`, `orch-start`, `orch-stop`, `orch-status` bash scripts in `~/.hermes-orchestra/bin/`
- 4-layer directory structure: Runtime (`/tmp/`), State (`~/.local/state/`), Audit (`~/.local/share/`), Cache (`~/.cache/`)
- Per-project file bus: `task.md`, `codex-question.md`, `claude-decision.md`, `codex-result.md`, `review-result.md`, `escalation.md`
- SOUL.md and 4 skills installed at `~/.hermes/SOUL.md` and `~/.hermes/skills/{name}/`

### Existing Risk References
- `escalation-handler/SKILL.md` — Defines L1-L4 levels, risk keywords, user decision flow, audit log format (outdated: plain text /tmp)
- `README.md` §5-§8 — Describes risk levels, escalation flow, audit log, safety best practices

### Upstream Environment (from Phase 9)
- Hermes Agent v0.11.0 at `~/.local/bin/hermes`, pinned commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`
- Upstream does NOT natively provide: static risk rulebook, per-project audit, `orch-*` helpers, file bus routing

</code_context>

<specifics>
## Specific Ideas

1. **`orch-decisions` display format**: Should list pending decisions with approval_id, project, task, level, timestamp, and a one-line summary. Example:
   ```
   ID          Project    Level  Task      Age
   esc-456     project-a  L3     auth-fix  2m
   ```

2. **`orch-audit` output format**: TSV-like or simple table showing timestamp, level, type, decision, details. Default shows last 20 entries. `--project <id>` filters. `--level L4` filters by level.

3. **`orch-risk-check` input**: Accepts an operation string via stdin or argument. Example:
   ```bash
   echo "rm -rf /data" | orch-risk-check  # Returns exit code 3 (L4)
   orch-risk-check "npm install lodash"   # Returns exit code 0 (safe)
   ```

4. **Smoke test structure**: Each test script in `scripts/tests/` should:
   - Source `scripts/tests/lib/assert.sh` for `assert_eq`, `assert_file_exists`, `assert_cmd_output`
   - Start with a `TEST_NAME` variable
   - End with a `test_done` call that prints pass/fail
   - Be independently runnable

5. **Coverage matrix rows**: Should map each v1.0 specification item (from README.md sections) to one of three columns:
   - **Upstream native**: Hermes Agent provides this out of the box
   - **Adapter-provided**: Our `orch-*`, skills, or setup provides this
   - **Deferred**: Not yet implemented, planned for future milestone

</specifics>

<deferred>
## Deferred Ideas

- User-customizable risk rulebook extension (post-v1.1)
- Audit log query/filtering by date range, agent, or escalation type (post-v1.1)
- Remote adapter implementation (deferred to v2+ adapter milestone)
- Team collaboration or multi-user approvals (deferred)
- gbrain integration (deferred)
- Dashboard for audit visualization (deferred)
- Automated audit log backup/archival (deferred)
- Production deployment or package publishing (deferred)

### Reviewed Todos (not folded)
None — Phase 12 scope is self-contained.

</deferred>

---

*Phase: 12-risk-decisions-verification-handoff*
*Context gathered: 2026-04-25*
*Decisions locked: D-12-01 through D-12-04*
