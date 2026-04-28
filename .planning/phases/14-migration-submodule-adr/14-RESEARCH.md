# Phase 14: Migration & Submodule ADR - Research

**Researched:** 2026-04-28  
**Domain:** docs path migration, Git move semantics, upstream pin decision record  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied from `.planning/phases/14-migration-submodule-adr/14-CONTEXT.md`. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

### Locked Decisions

### Directory Migration

- **D-14-01:** Execute the directory migration. The target path is `docs/orchestra/`.
- **D-14-02:** Use `git mv docs/hermes-dev-orchestra docs/orchestra` for the physical move.
- **D-14-03:** Do not keep a compatibility shim, duplicate directory, symlink, or supported pointer at `docs/hermes-dev-orchestra/`.
- **D-14-04:** Update references instead of preserving old-path compatibility. The planning target is that `rg -n "docs/hermes-dev-orchestra"` returns zero actionable old-path references after migration. If a historical planning artifact cannot be updated without corrupting audit evidence, the plan must call that out explicitly before execution.

### Upstream Pin ADR

- **D-14-05:** The ADR must compare all four required strategies: installer/probe pin, git submodule, manifest pin, and vendor snapshot.
- **D-14-06:** Select **manifest pin** as the recommended and intended v1.2 strategy.
- **D-14-07:** The manifest pin should be repo-local and machine-readable, recording at minimum upstream repository, pinned commit, observed version/probe evidence, install source or command, and update procedure.
- **D-14-08:** The ADR should explain that git submodule is intentionally not selected for v1.2 because this repository is an adapter layer and does not need to vendor or checkout upstream core source as part of normal development.

### ADR Location and Validation

- **D-14-09:** Write the ADR at `.planning/adr/ADR-001-upstream-pin.md`.
- **D-14-10:** Because submodule is not selected, the `.gitmodules` plus `hermes-agent` gitlink staging check from UPST-02 is not applicable. The ADR must state this explicitly.
- **D-14-11:** Required verification for planning should include: post-migration path reference search, existing smoke tests under the migrated script tree, shell syntax checks for migrated shell scripts, and `git status --short` review.

### Claude's Discretion

- Exact manifest file path and schema, as long as it is repo-local, machine-readable, and easy for Phase 16 `make upstream-status` to consume later.
- Exact ADR section structure and wording.
- Exact verification command list, as long as it covers path references, shell syntax, and existing smoke fixtures.
- Whether to add a short migration note in reader-facing docs after paths are updated.

### Deferred Ideas (OUT OF SCOPE)

- Creating a `specs/` derived documentation system — Phase 15.
- Creating `make upstream-status` to compare repo-local and runtime pins — Phase 16.
- Broad `AGENTS.md` rule consolidation beyond path references — Phase 17.
- Actual git submodule adoption — deferred unless a future phase explicitly reverses the manifest pin decision.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIGR-02 | Directory migration must use `git mv`; after migration, old actionable path references must be resolved and tests must pass. [VERIFIED: .planning/REQUIREMENTS.md; .planning/ROADMAP.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] | Use `git mv docs/hermes-dev-orchestra docs/orchestra`, update active references, preserve or document historical audit-only references, then run shell syntax, JSON validation, smoke tests, and status review. [VERIFIED: local probes 2026-04-28; .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md] |
| UPST-01 | ADR must compare installer/probe pin, git submodule, manifest pin, and vendor snapshot. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] | Write `.planning/adr/ADR-001-upstream-pin.md` with Context, Decision, Options, comparison table, consequences, manifest contract, and update procedure. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; CITED: https://adr.github.io/] |
| UPST-02 | If submodule is selected, staging must contain only `.gitmodules` and the `hermes-agent` gitlink. [VERIFIED: .planning/REQUIREMENTS.md; .planning/ROADMAP.md] | Manifest pin is selected, so the ADR must mark UPST-02 as not applicable and verification should assert that no `.gitmodules` or gitlink was introduced. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; local git probe 2026-04-28] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Respond in Simplified Chinese for user-facing summaries. [VERIFIED: CLAUDE.md; AGENTS.md]
- Prefer retrieval-led reasoning over pre-training-led reasoning. [VERIFIED: CLAUDE.md; AGENTS.md]
- Keep changes minimal, surgical, and directly tied to the request. [VERIFIED: CLAUDE.md; AGENTS.md]
- Define success criteria and verify with concrete checks. [VERIFIED: CLAUDE.md; AGENTS.md]
- Keep this repository as an adapter layer over `NousResearch/hermes-agent`; do not reimplement upstream Hermes Agent runtime. [VERIFIED: AGENTS.md; .planning/DIRECTION-CORRECTION.md]
- Local entrypoints remain limited to `orch-*` helpers. [VERIFIED: AGENTS.md]
- Hermes must not auto-approve L3/L4 decisions, Claude must not modify upstream core, and Codex must not modify `~/.hermes-orchestra/rules.json`. [VERIFIED: AGENTS.md]
- Spec authority is `.planning/SPEC.md`; reader-facing Dev Orchestra package docs currently live under the directory being migrated. [VERIFIED: AGENTS.md; .planning/SPEC.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
- GSD workflow expects file-changing work to stay synchronized with `.planning/` artifacts; this research artifact is the only file changed during research. [VERIFIED: AGENTS.md; gsd init.phase-op 14]

## Summary

Phase 14 should execute the locked migration from `docs/hermes-dev-orchestra/` to `docs/orchestra/` with `git mv`, then update active reader, script-test, and planning references to the new path. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; CITED: https://git-scm.com/docs/git-mv] The current tracked package tree contains 33 files under `docs/hermes-dev-orchestra/`, including README/WORKFLOW, SOUL, four skills, config JSON, installer, 11 `orch-*` helpers, shared shell library, and smoke fixtures. [VERIFIED: `git ls-files docs/hermes-dev-orchestra` 2026-04-28]

The old-path inventory has two scopes that the plan must not conflate: actionable current references and historical audit references. [VERIFIED: `rg --hidden -n "docs/hermes-dev-orchestra" --glob '!/.git/*' --glob '!*.zip' --stats` 2026-04-28; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] Actionable current references are in root discovery docs, active planning docs, coverage matrix, package README/WORKFLOW, and package smoke tests. [VERIFIED: `rg -l "docs/hermes-dev-orchestra" README.md AGENTS.md CLAUDE.md docs .planning/PROJECT.md .planning/DIRECTION-CORRECTION.md .planning/REQUIREMENTS.md .planning/ROADMAP.md` 2026-04-28] Historical references appear in v1.0/v1.1 phase records, Phase 13 evidence, discussion logs, and backlog artifacts; rewriting those can damage audit value, so the execution plan should either exclude them from the actionable zero-residue gate or explicitly document why they remain historical. [VERIFIED: .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md; `.planning/phases/14-migration-submodule-adr/14-CONTEXT.md`; `rg --hidden -l` 2026-04-28]

For upstream pinning, select a JSON manifest pin and document the rejected alternatives in `.planning/adr/ADR-001-upstream-pin.md`. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] The recommended manifest path is `.planning/upstream/hermes-agent-pin.json` because it is repo-local, machine-readable by Python or `jq`, separated from ADR prose, and easy for Phase 16 `make upstream-status` to parse. [VERIFIED: local availability probes for python3/jq 2026-04-28; .planning/ROADMAP.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

**Primary recommendation:** Plan one implementation unit that performs `git mv`, targeted reference updates, manifest creation, ADR creation, and the verification matrix in that order. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; local test probes 2026-04-28]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Directory migration | Git / Repository | Docs package | Git owns tracked path movement; package docs/tests consume the new path. [VERIFIED: git-mv docs; `git ls-files docs/hermes-dev-orchestra` 2026-04-28] |
| Old-path reference cleanup | Docs package | Planning artifacts | Reader docs and smoke tests are actionable consumers; planning artifacts need audit-preserving triage. [VERIFIED: .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md; `rg` probes 2026-04-28] |
| Upstream pin decision | Planning / ADR | Git repository | ADR owns the decision and rationale; the manifest owns machine-readable pin data. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; CITED: https://adr.github.io/] |
| Manifest pin consumption | Dev workflow | Runtime probe | Phase 16 `make upstream-status` should compare repo-local manifest data with runtime upstream state. [VERIFIED: .planning/REQUIREMENTS.md; .planning/ROADMAP.md; local `hermes --version` probe 2026-04-28] |
| Submodule conditional handling | Git / Repository | ADR | Git submodule adoption would create `.gitmodules` plus a gitlink; manifest selection makes that condition not applicable. [VERIFIED: local `.gitmodules`/gitlink probe 2026-04-28; CITED: https://git-scm.com/docs/git-submodule.html; CITED: https://git-scm.com/docs/gitmodules.html] |

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Git | 2.43.0 | `git mv`, status review, optional gitlink/submodule detection. [VERIFIED: local `git --version` 2026-04-28] | The requirement explicitly requires `git mv`, and Git docs define the move and submodule behavior. [VERIFIED: .planning/REQUIREMENTS.md; CITED: https://git-scm.com/docs/git-mv] |
| ripgrep | 15.1.0 | Old-path reference inventory and post-migration residue checks. [VERIFIED: local `rg --version` 2026-04-28] | Phase 13 and Phase 14 both use `rg -n "docs/hermes-dev-orchestra"` as the evidence/check pattern. [VERIFIED: .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| Bash | 5.2.21 | Shell syntax checks and smoke fixture execution. [VERIFIED: local `bash --version` 2026-04-28] | Existing package scripts and tests are Bash files. [VERIFIED: `find docs/hermes-dev-orchestra/scripts` 2026-04-28] |
| Python stdlib | 3.12.3 | JSON validation and future manifest parsing fallback. [VERIFIED: local `python3 --version` 2026-04-28] | Existing shell helpers already use Python stdlib for JSON work, and Python avoids adding a YAML parser. [VERIFIED: docs/hermes-dev-orchestra/scripts/lib/orch-common.sh; local probes 2026-04-28] |
| jq | installed | Optional JSON manifest inspection in Phase 16. [VERIFIED: local `command -v jq` 2026-04-28] | `jq` is available, but manifest validation should still work with Python stdlib if `jq` is absent on another machine. [VERIFIED: local probe 2026-04-28] |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| tmux | 3.4 | Existing smoke fixtures fake tmux, while installed runtime sessions may exist. [VERIFIED: local `tmux -V` 2026-04-28; docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh] | Use only for runtime-state awareness; Phase 14 does not need to start real sessions. [VERIFIED: local tmux session probe 2026-04-28] |
| hermes | v0.11.0, upstream commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3` | Runtime pin evidence source. [VERIFIED: local `hermes --version`; `git -C ~/.hermes/hermes-agent rev-parse HEAD` 2026-04-28] | Use for manifest observed version/probe evidence, not for migration logic. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md] |
| shellcheck | missing | Optional shell lint. [VERIFIED: local `command -v shellcheck` 2026-04-28] | Do not require it in Phase 14; use `bash -n` as the mandatory shell check. [VERIFIED: .planning/REQUIREMENTS.md DEV-03 describes future shellcheck fallback in Phase 16] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSON manifest | YAML manifest | YAML is friendlier to comments but needs an extra parser in this repo; JSON validates with Python stdlib and `jq`. [VERIFIED: local python3/jq probes 2026-04-28] |
| Manifest pin | Git submodule | Submodule pins source in the superproject index but adds `.gitmodules`, gitlink semantics, clone/update workflow, and unnecessary upstream checkout for this adapter layer. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; CITED: https://git-scm.com/docs/git-submodule.html] |
| Manifest pin | Installer/probe docs only | Existing Phase 9 prose records the pin, but Phase 16 needs a machine-readable contract. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md; .planning/REQUIREMENTS.md DEV-04] |
| Manifest pin | Vendor snapshot | Copying upstream source conflicts with the upstream-first adapter boundary and creates local core-code ownership. [VERIFIED: .planning/DIRECTION-CORRECTION.md; AGENTS.md] |

**Installation:** No npm/pip package installation is needed for Phase 14. [VERIFIED: local stack and existing fixtures 2026-04-28]

**Version verification:** There are no npm package versions to verify; recommended tools were verified with local CLI probes instead. [VERIFIED: local probes 2026-04-28]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 13 Evidence + Phase 14 Context
        |
        v
Preflight
  - git status review
  - old-path inventory
  - test baseline
        |
        v
git mv docs/hermes-dev-orchestra -> docs/orchestra
        |
        v
Reference update pass
  |-- active docs: README.md, AGENTS.md, docs/COVERAGE-MATRIX.md
  |-- package docs: docs/orchestra/README.md, WORKFLOW.md
  |-- package tests: docs/orchestra/scripts/tests/*.sh
  |-- active planning: PROJECT, REQUIREMENTS, ROADMAP, DIRECTION-CORRECTION
  `-- historical artifacts: leave only with explicit audit rationale
        |
        v
Upstream pin artifacts
  |-- .planning/upstream/hermes-agent-pin.json
  `-- .planning/adr/ADR-001-upstream-pin.md
        |
        v
Verification gate
  - actionable old-path rg
  - bash -n scripts
  - JSON validation
  - smoke tests
  - no submodule artifacts
  - git status review
```

The diagram traces the locked Phase 14 flow from evidence to move, reference cleanup, ADR/manifest creation, and verification. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; local probes 2026-04-28]

### Recommended Project Structure

```text
docs/
├── orchestra/                    # moved Dev Orchestra package docs, skills, scripts
│   ├── README.md
│   ├── WORKFLOW.md
│   ├── hermes/SOUL.md
│   ├── skills/
│   ├── config/rules.json
│   └── scripts/
└── COVERAGE-MATRIX.md            # update evidence paths to docs/orchestra

.planning/
├── adr/
│   └── ADR-001-upstream-pin.md   # decision record
└── upstream/
    └── hermes-agent-pin.json     # machine-readable Phase 16 input
```

This structure follows the locked `docs/orchestra/` target and `.planning/adr/` ADR location, while adding `.planning/upstream/` for the repo-local manifest. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

### Pattern 1: Safe Git Move

**What:** Use Git to move the tracked directory, then update text references in the moved tree and active docs. [VERIFIED: .planning/REQUIREMENTS.md; CITED: https://git-scm.com/docs/git-mv]  
**When to use:** Use this for the physical directory migration because D-14-02 locks `git mv`. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]  
**Example:**

```bash
git status --short --branch
git mv -n docs/hermes-dev-orchestra docs/orchestra
git mv docs/hermes-dev-orchestra docs/orchestra
```

`git mv` moves or renames a tracked directory and updates the index after success, but the change still needs a commit. [CITED: https://git-scm.com/docs/git-mv]

### Pattern 2: Active-vs-Historical Reference Gate

**What:** Use a strict actionable scope for migration acceptance, and separately report historical old-path references that remain as audit evidence. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; `rg --hidden` probe 2026-04-28]  
**When to use:** Use this because broad hidden grep currently finds old paths in 96 files and 1,527 matches, including historical phase records. [VERIFIED: `rg --hidden -n "docs/hermes-dev-orchestra" --glob '!/.git/*' --glob '!*.zip' --stats` 2026-04-28]  
**Example:**

```bash
# Actionable gate after migration
! rg -n "docs/hermes-dev-orchestra" \
  README.md AGENTS.md CLAUDE.md docs \
  .planning/PROJECT.md .planning/REQUIREMENTS.md \
  .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md

# Audit-only inventory after migration
rg --hidden -n "docs/hermes-dev-orchestra" \
  --glob '!/.git/*' --glob '!*.zip'
```

The first command should return no matches after implementation; the second command may still return historical artifacts only if the plan and summary document that rationale. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

### Pattern 3: JSON Manifest Pin

**What:** Store upstream pin data in `.planning/upstream/hermes-agent-pin.json`. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]  
**When to use:** Use it for Phase 14 because manifest pin is selected for v1.2 and Phase 16 needs a repo-local pin to compare with runtime state. [VERIFIED: .planning/REQUIREMENTS.md DEV-04; .planning/ROADMAP.md]  
**Example:**

```json
{
  "schema_version": "1.0",
  "component": "hermes-agent",
  "upstream": {
    "repository": "https://github.com/NousResearch/hermes-agent",
    "remote": "https://github.com/NousResearch/hermes-agent.git"
  },
  "pin": {
    "commit": "023b1bff11c2a01a435f1956a0e2ac1773a065f3",
    "observed_version": "Hermes Agent v0.11.0 (2026.4.23)",
    "probe_date": "2026-04-28",
    "install_source": "https://github.com/NousResearch/hermes-agent",
    "install_method": "upstream installer with HTTPS-safe Git config when needed",
    "local_install_path": "~/.hermes/hermes-agent"
  },
  "probe_commands": [
    "git -C ~/.hermes/hermes-agent rev-parse HEAD",
    "hermes --version",
    "hermes --help"
  ],
  "update_procedure": [
    "Choose an intentional upstream commit.",
    "Run the upstream installer or update procedure.",
    "Verify hermes --version and hermes --help.",
    "Update this manifest and the coverage/ADR references in the same change."
  ],
  "phase_16_contract": {
    "repo_pin_json_pointer": "/pin/commit",
    "runtime_pin_probe": "git -C ${HERMES_AGENT_DIR:-$HOME/.hermes/hermes-agent} rev-parse HEAD"
  }
}
```

The commit and observed version come from Phase 9 evidence and the current local upstream checkout. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md; local `git -C ~/.hermes/hermes-agent rev-parse HEAD`; local `hermes --version` 2026-04-28]

### Pattern 4: ADR with Explicit Conditional

**What:** The ADR should compare four options and state that UPST-02 is not applicable because submodule is not selected. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]  
**When to use:** Use it in `.planning/adr/ADR-001-upstream-pin.md`. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]  
**Example sections:**

```markdown
# ADR-001: Upstream Hermes Agent Pin Strategy

## Status
Accepted

## Context
...

## Decision
Use a repo-local JSON manifest pin at `.planning/upstream/hermes-agent-pin.json`.

## Options Considered
| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Installer/probe pin | ... | ... | Rejected |
| Git submodule | ... | ... | Rejected |
| Manifest pin | ... | ... | Accepted |
| Vendor snapshot | ... | ... | Rejected |

## UPST-02 Applicability
Not applicable for v1.2 because no submodule is selected.

## Consequences
...
```

ADR guidance supports documenting the decision, rationale, trade-offs, and consequences. [CITED: https://adr.github.io/]

### Anti-Patterns to Avoid

- **Global blind replacement of `hermes-dev-orchestra`:** The project id, tmux session names, and runtime directories use `hermes-dev-orchestra` as a project name, not the old docs path. [VERIFIED: runtime state probes 2026-04-28]
- **Treating all `.planning/` matches as actionable:** Phase summaries, old research, and evidence files are audit artifacts; rewriting them can corrupt historical evidence. [VERIFIED: `.planning/phases/14-migration-submodule-adr/14-CONTEXT.md`; `rg --hidden` probe 2026-04-28]
- **Adding `.gitmodules` despite manifest selection:** D-14-06 rejects submodule for v1.2, so introducing `.gitmodules` would contradict the locked decision. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
- **Choosing YAML without adding tooling:** This repo has Python and `jq` available for JSON; YAML would add an unplanned parser dependency. [VERIFIED: local probes 2026-04-28]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tracked directory move | Manual `mv` plus `git add/rm` choreography | `git mv docs/hermes-dev-orchestra docs/orchestra` | Requirement locks `git mv`, and Git documents directory rename/index behavior. [VERIFIED: .planning/REQUIREMENTS.md; CITED: https://git-scm.com/docs/git-mv] |
| Submodule metadata detection | Custom parsing of `.git` internals | `test ! -f .gitmodules` and `git ls-files --stage` mode `160000` check | Git records submodules through `.gitmodules` and gitlink index entries; use Git plumbing output. [CITED: https://git-scm.com/docs/gitmodules.html; local git probe 2026-04-28] |
| JSON validation | Regex validation | `python3 -m json.tool` or `jq .` | JSON syntax should be parsed by a JSON parser, and both tools are locally available. [VERIFIED: local probes 2026-04-28] |
| Smoke verification | New test framework | Existing Bash smoke runner at migrated `docs/orchestra/scripts/tests/run-all.sh` | Current suite has 9 Bash tests and passed pre-migration. [VERIFIED: `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` 2026-04-28] |
| Upstream pin state | Prose-only pin in ADR | Machine-readable JSON manifest plus ADR rationale | Phase 16 needs `make upstream-status` to compare repo-local and runtime pins. [VERIFIED: .planning/REQUIREMENTS.md DEV-04; .planning/ROADMAP.md] |

**Key insight:** Phase 14 is mostly about preserving ownership boundaries: Git owns file movement, JSON owns machine-readable pin state, ADR owns rationale, and historical planning artifacts should not be rewritten just to satisfy an overbroad grep. [VERIFIED: AGENTS.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; local probes 2026-04-28]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `~/.hermes-orchestra/tests/*.sh` contains installed copies of smoke tests with `docs/hermes-dev-orchestra` paths. [VERIFIED: runtime `rg` under `~/.hermes-orchestra` 2026-04-28] `~/.local/state/hermes-orchestra/*` contains `hermes-dev-orchestra` project ids and runtime dirs, but not `docs/hermes-dev-orchestra` source paths except old execution logs. [VERIFIED: runtime `rg` under XDG state 2026-04-28] | Update source tests during migration; after migration, rerun `bash docs/orchestra/scripts/setup.sh` when refreshing installed package tests. Do not rename project ids for this path-only migration. [VERIFIED: docs/hermes-dev-orchestra/scripts/setup.sh; AGENTS.md] |
| Live service config | tmux sessions `hermes-hermes-dev-orchestra-claude` and `hermes-hermes-dev-orchestra-codex` are running; these encode the project id, not the docs path. [VERIFIED: `tmux list-sessions` 2026-04-28] | No migration action for directory move; avoid global rename of project id/session names. [VERIFIED: runtime probe 2026-04-28] |
| OS-registered state | No matching user systemd units, crontab entries, or pm2 process config were found. [VERIFIED: `systemctl --user list-unit-files`, `crontab -l`, `pm2 jlist` probes 2026-04-28] | None. [VERIFIED: local probes 2026-04-28] |
| Secrets/env vars | No environment variables or repo `.env` files with `docs/hermes-dev-orchestra` were found. [VERIFIED: `env` and repo `.env` probes 2026-04-28] | None. [VERIFIED: local probes 2026-04-28] |
| Build artifacts | No repo-local `node_modules`, `dist`, `build`, `.pytest_cache`, `__pycache__`, or `*.egg-info` artifacts were found at shallow audit depth. [VERIFIED: build artifact probe 2026-04-28] Installed package tests under `~/.hermes-orchestra/tests` are copied runtime artifacts. [VERIFIED: runtime `rg` 2026-04-28] | No repo cleanup needed; optional post-migration reinstall refreshes copied tests. [VERIFIED: docs/hermes-dev-orchestra/scripts/setup.sh] |

**Nothing found in category:** OS-registered state and secrets/env vars have no old docs-path action items. [VERIFIED: local probes 2026-04-28]

## Common Pitfalls

### Pitfall 1: Overbroad Zero-Residue Gate

**What goes wrong:** A broad hidden `rg` fails because historical planning artifacts still contain old paths. [VERIFIED: `rg --hidden` probe 2026-04-28]  
**Why it happens:** Phase history and evidence intentionally record previous paths. [VERIFIED: .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md]  
**How to avoid:** Define an actionable gate and a historical-residual report before implementation. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]  
**Warning signs:** The plan proposes editing v1.0 milestone archives or Phase 13 evidence without explaining audit impact. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

### Pitfall 2: Breaking Smoke Tests After Move

**What goes wrong:** Tests still call `$REPO_ROOT/docs/hermes-dev-orchestra/...` after the tree moves. [VERIFIED: current test files under docs/hermes-dev-orchestra/scripts/tests 2026-04-28]  
**Why it happens:** Most executable helpers use relative `SCRIPT_DIR`, but the tests embed repo-root paths. [VERIFIED: `rg` probe 2026-04-28]  
**How to avoid:** Update test path literals to `docs/orchestra` and run the full smoke runner. [VERIFIED: local pre-migration smoke run 2026-04-28]  
**Warning signs:** `bash docs/orchestra/scripts/tests/run-all.sh` reports missing helper paths. [VERIFIED: current test runner behavior 2026-04-28]

### Pitfall 3: Submodule Check Applied to Manifest Decision

**What goes wrong:** The plan tries to stage `.gitmodules` or add an upstream checkout even though manifest pin is selected. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]  
**Why it happens:** UPST-02 is conditional and only applies if submodule is selected. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]  
**How to avoid:** ADR must state UPST-02 is not applicable and verification must assert no `.gitmodules` or gitlink exists. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; local `.gitmodules` probe 2026-04-28]  
**Warning signs:** `git status --short` shows `.gitmodules` or a `hermes-agent` path. [VERIFIED: local git probe 2026-04-28]

### Pitfall 4: Manifest Cannot Be Consumed by Phase 16

**What goes wrong:** ADR prose records the pin but `make upstream-status` has no stable machine-readable file to parse. [VERIFIED: .planning/REQUIREMENTS.md DEV-04; .planning/ROADMAP.md]  
**Why it happens:** Phase 9 evidence is Markdown prose, not a manifest. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md]  
**How to avoid:** Create `.planning/upstream/hermes-agent-pin.json` with a stable schema and JSON validation. [VERIFIED: local python3/jq probes 2026-04-28]  
**Warning signs:** The ADR says "see Phase 9 summary" but no JSON file exists. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

## Code Examples

### Migration Verification Commands

```bash
git status --short --branch
git mv -n docs/hermes-dev-orchestra docs/orchestra
git mv docs/hermes-dev-orchestra docs/orchestra

! rg -n "docs/hermes-dev-orchestra" \
  README.md AGENTS.md CLAUDE.md docs \
  .planning/PROJECT.md .planning/REQUIREMENTS.md \
  .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md

while IFS= read -r f; do
  bash -n "$f"
done < <(find docs/orchestra/scripts -type f \( -name "*.sh" -o -path "*/scripts/bin/orch-*" \) -print | sort)

find . -name "*.json" -not -path "./.git/*" -not -path "./.claude/*" -print -0 |
  xargs -0 -r -n1 python3 -m json.tool >/dev/null

bash docs/orchestra/scripts/tests/run-all.sh
git status --short
```

These commands cover the locked migration, old-path check, shell syntax, JSON validation, smoke fixtures, and status review. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; local verification probes 2026-04-28]

### Manifest Validation Commands

```bash
python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null
jq -r '.pin.commit' .planning/upstream/hermes-agent-pin.json
git -C "${HERMES_AGENT_DIR:-$HOME/.hermes/hermes-agent}" rev-parse HEAD
hermes --version
```

These commands validate JSON syntax and expose the repo-local pin/runtime pin values Phase 16 can compare. [VERIFIED: local python3/jq/hermes/git probes 2026-04-28; .planning/REQUIREMENTS.md DEV-04]

### UPST-02 Not-Applicable Verification

```bash
test ! -f .gitmodules
! git ls-files --stage | grep -q '^160000 '
! git status --short -- .gitmodules hermes-agent | grep -q .
```

These commands verify that the manifest-pin path did not accidentally introduce submodule artifacts. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; local git probe 2026-04-28]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Dev Orchestra package under `docs/hermes-dev-orchestra/` | Move package to `docs/orchestra/` | Locked for Phase 14 on 2026-04-28 | Plans must update active links/tests and remove compatibility expectations. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| Upstream pin only in Phase 9 Markdown evidence | Add JSON manifest plus ADR | Phase 14 target | Phase 16 can parse repo-local pin without scraping prose. [VERIFIED: .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md; .planning/REQUIREMENTS.md DEV-04] |
| Potential submodule adoption | Manifest pin selected for v1.2 | Locked for Phase 14 on 2026-04-28 | UPST-02 staging check is documented as not applicable. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| Upstream appeared up to date in Phase 9 evidence | Current local `hermes --version` reports v0.11.0 and update availability | Verified 2026-04-28 | Do not silently update the pin; record observed version/probe evidence in the manifest and ADR. [VERIFIED: local `hermes --version` 2026-04-28; .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md] |

**Deprecated/outdated:**

- Treating `docs/hermes-dev-orchestra/` as reader-facing authority is outdated after the locked migration; use `docs/orchestra/` in active docs. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
- Treating submodule as the default pin strategy is outdated for v1.2; manifest pin is selected. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | No unverified assumptions recorded. | — | — |

All claims in this research were verified locally, cited from official docs, or copied from locked Phase 14 context. [VERIFIED: local probes 2026-04-28; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

## Open Questions

1. **Should historical `.planning/` artifacts be rewritten to satisfy a literal global grep?**
   - What we know: D-14-04 targets zero actionable old-path references and explicitly allows calling out historical artifacts that cannot be updated without corrupting audit evidence. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
   - What's unclear: Whether final acceptance will require literal zero matches across hidden historical archives. [VERIFIED: .planning/REQUIREMENTS.md; `.planning/phases/14-migration-submodule-adr/14-CONTEXT.md`]
   - Recommendation: Plan an actionable zero gate plus a historical residual report; do not rewrite Phase 13 evidence or old milestone archives unless the user explicitly accepts audit-history rewriting. [VERIFIED: .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| git | `git mv`, status, gitlink detection | yes | 2.43.0 | none; required by MIGR-02. [VERIFIED: local probe 2026-04-28] |
| rg | path inventory | yes | 15.1.0 | `grep -R`, but use `rg` per project practice. [VERIFIED: local probe 2026-04-28; AGENTS.md] |
| bash | syntax and smoke tests | yes | 5.2.21 | none for existing fixtures. [VERIFIED: local probe 2026-04-28] |
| python3 | JSON validation | yes | 3.12.3 | `jq` for syntax/field checks if Python unavailable. [VERIFIED: local probe 2026-04-28] |
| jq | manifest field checks | yes | installed | Python stdlib parser. [VERIFIED: local probe 2026-04-28] |
| tmux | runtime awareness, existing helper context | yes | 3.4 | Smoke tests fake tmux; no live tmux needed for Phase 14. [VERIFIED: local probe 2026-04-28; docs/hermes-dev-orchestra/scripts/tests] |
| hermes | observed upstream pin/version evidence | yes | Hermes Agent v0.11.0 (2026.4.23) | Use Phase 9 evidence if runtime command is unavailable. [VERIFIED: local probe 2026-04-28; .planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md] |
| claude | not required by Phase 14 tests | yes | 2.1.121 | Existing smoke tests use fake CLI where needed. [VERIFIED: local probe 2026-04-28; docs/hermes-dev-orchestra/scripts/tests] |
| codex | not required by Phase 14 tests | yes | 0.125.0 | Existing smoke tests use fake CLI where needed. [VERIFIED: local probe 2026-04-28; docs/hermes-dev-orchestra/scripts/tests] |
| shellcheck | optional shell lint | no | — | `bash -n` is the required check. [VERIFIED: local probe 2026-04-28; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| make | future Phase 16 workflow | yes | GNU Make 4.3 | Not used in Phase 14 because Makefile target is not present. [VERIFIED: local probe 2026-04-28; .planning/ROADMAP.md] |

**Missing dependencies with no fallback:** none for Phase 14. [VERIFIED: local probes 2026-04-28]  
**Missing dependencies with fallback:** `shellcheck` is missing; use `bash -n`. [VERIFIED: local probe 2026-04-28]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Pure Bash smoke fixtures. [VERIFIED: docs/hermes-dev-orchestra/scripts/tests/run-all.sh] |
| Config file | none. [VERIFIED: repo file inventory 2026-04-28] |
| Quick run command | `while IFS= read -r f; do bash -n "$f"; done < <(find docs/orchestra/scripts -type f \( -name "*.sh" -o -path "*/scripts/bin/orch-*" \) -print \| sort)` |
| Full suite command | `bash docs/orchestra/scripts/tests/run-all.sh` |

The pre-migration suite passed with 9 tests and 0 failures. [VERIFIED: `bash docs/hermes-dev-orchestra/scripts/tests/run-all.sh` 2026-04-28]

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| MIGR-02 | Moved package path has no actionable old-path references and existing smoke behavior still passes. [VERIFIED: .planning/REQUIREMENTS.md] | grep + smoke | `! rg -n "docs/hermes-dev-orchestra" README.md AGENTS.md CLAUDE.md docs .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md && bash docs/orchestra/scripts/tests/run-all.sh` | Current equivalent exists under old path; `docs/orchestra` appears after `git mv`. [VERIFIED: repo inventory 2026-04-28] |
| UPST-01 | ADR compares four upstream pin strategies and selects manifest pin. [VERIFIED: .planning/REQUIREMENTS.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] | doc/grep + JSON parse | `rg -n "installer/probe pin|git submodule|manifest pin|vendor snapshot" .planning/adr/ADR-001-upstream-pin.md && python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null` | Files to create in Phase 14. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| UPST-02 | Submodule-only staging check is marked not applicable when manifest pin is selected. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] | doc/grep + git status | `rg -n "UPST-02|not applicable|manifest pin" .planning/adr/ADR-001-upstream-pin.md && test ! -f .gitmodules && ! git ls-files --stage \| grep -q '^160000 '` | ADR to create; repo currently has no `.gitmodules`. [VERIFIED: local probe 2026-04-28] |

### Sampling Rate

- **Per task commit:** shell syntax check plus actionable old-path grep. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
- **Per wave merge:** full Bash smoke suite and JSON validation. [VERIFIED: local pre-migration test run 2026-04-28]
- **Phase gate:** full suite green, ADR/manifest present, no accidental submodule artifacts, and `git status --short` reviewed. [VERIFIED: .planning/ROADMAP.md; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]

### Wave 0 Gaps

- [ ] `.planning/upstream/hermes-agent-pin.json` — create in implementation before manifest validation can pass. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
- [ ] `.planning/adr/ADR-001-upstream-pin.md` — create in implementation for UPST-01/UPST-02 documentation. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
- [ ] `docs/orchestra/scripts/tests/run-all.sh` — exists only after `git mv`; current equivalent is `docs/hermes-dev-orchestra/scripts/tests/run-all.sh`. [VERIFIED: repo inventory 2026-04-28]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 14 does not change auth flows. [VERIFIED: phase scope in .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| V3 Session Management | no | Phase 14 does not change sessions; tmux session names are runtime state only. [VERIFIED: runtime probe 2026-04-28] |
| V4 Access Control | no | Phase 14 does not change authorization logic. [VERIFIED: phase scope in .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| V5 Input Validation | yes | Validate JSON manifest with Python/jq and avoid regex parsing. [VERIFIED: local probes 2026-04-28] |
| V6 Cryptography | no | Phase 14 does not implement cryptography. [VERIFIED: phase scope in .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Manifest drift from runtime upstream checkout | Tampering / Repudiation | Record repo-local commit, observed version, probe date, and update procedure; Phase 16 compares with runtime checkout. [VERIFIED: .planning/REQUIREMENTS.md DEV-04; local upstream probes 2026-04-28] |
| Accidental vendoring or submodule checkout | Tampering / Supply chain confusion | Verify no `.gitmodules`, no gitlink mode `160000`, and no `hermes-agent` checkout introduced. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md; CITED: https://git-scm.com/docs/gitmodules.html] |
| Broken path references in tests | Reliability / Integrity | Update literals and run smoke suite after migration. [VERIFIED: current tests and pre-migration run 2026-04-28] |

## Planning Risks and Dependency Ordering

| Order | Work Item | Why First/Next |
|-------|-----------|----------------|
| 1 | Review dirty worktree and unrelated staged backlog files. | Current worktree has unrelated staged backlog additions that must not be included accidentally. [VERIFIED: `git status --short --branch` 2026-04-28] |
| 2 | Run preflight inventory and optional pre-migration smoke baseline. | Establishes whether failures are caused by migration or pre-existing state. [VERIFIED: local pre-migration smoke run 2026-04-28] |
| 3 | `git mv docs/hermes-dev-orchestra docs/orchestra`. | Physical move must happen before path literals can be validated against the new tree. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| 4 | Update active references and tests. | Smoke tests currently embed old repo-root paths. [VERIFIED: `rg` probe 2026-04-28] |
| 5 | Add JSON manifest. | ADR should point at the concrete manifest path and schema. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| 6 | Add ADR. | ADR needs final manifest path and UPST-02 applicability statement. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md] |
| 7 | Run full verification and status review. | Confirms migration, manifest, ADR, and no-submodule conditions together. [VERIFIED: .planning/ROADMAP.md; local probes 2026-04-28] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/14-migration-submodule-adr/14-CONTEXT.md` - locked decisions D-14-01 through D-14-11, discretion, and deferred scope.
- `.planning/REQUIREMENTS.md` - MIGR-02, UPST-01, UPST-02, DEV-04.
- `.planning/ROADMAP.md` - Phase 14 goal and success criteria.
- `.planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md` - old-path inventory and repository snapshot.
- `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md` - upstream commit, version/probe evidence, install source, update guidance.
- `.planning/DIRECTION-CORRECTION.md` - upstream-first adapter boundary.
- `AGENTS.md` and `CLAUDE.md` - project constraints and agent role boundaries.
- Git official docs: `https://git-scm.com/docs/git-mv`, `https://git-scm.com/docs/git-submodule.html`, `https://git-scm.com/docs/gitmodules.html`.
- ADR overview: `https://adr.github.io/`.

### Secondary (MEDIUM confidence)

- Local runtime probes under `~/.hermes-orchestra`, XDG state/share/cache, tmux, systemd user units, crontab, env, and build artifact search from 2026-04-28. [VERIFIED: local probes 2026-04-28]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - all tools and versions were locally probed. [VERIFIED: local probes 2026-04-28]
- Architecture: HIGH - migration target, ADR target, and manifest decision are locked in CONTEXT.md. [VERIFIED: .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
- Pitfalls: HIGH - old-path and runtime-state risks were verified with repository and runtime grep probes. [VERIFIED: local probes 2026-04-28]

**Research date:** 2026-04-28  
**Valid until:** 2026-05-05 for runtime probe details; Phase 14 locked decisions remain valid until CONTEXT.md changes. [VERIFIED: current date 2026-04-28; .planning/phases/14-migration-submodule-adr/14-CONTEXT.md]
