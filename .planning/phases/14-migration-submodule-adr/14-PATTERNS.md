# Phase 14: Migration & Submodule ADR - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 43
**Analogs found:** 43 / 43

## File Classification

Grouped rows cover files that share the same migration behavior and analog. The physical package move covers the 33 tracked files currently under `docs/hermes-dev-orchestra/`.

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `docs/orchestra/README.md` | documentation | transform | `docs/hermes-dev-orchestra/README.md` | exact rename |
| `docs/orchestra/WORKFLOW.md` | documentation | transform | `docs/hermes-dev-orchestra/WORKFLOW.md` | exact rename |
| `docs/orchestra/hermes/SOUL.md` | provider documentation | transform | `docs/hermes-dev-orchestra/hermes/SOUL.md` | exact rename |
| `docs/orchestra/skills/*/SKILL.md` | provider documentation | transform | `docs/hermes-dev-orchestra/skills/*/SKILL.md` | exact rename |
| `docs/orchestra/scripts/setup.sh` | utility | file-I/O | `docs/hermes-dev-orchestra/scripts/setup.sh` | exact rename |
| `docs/orchestra/scripts/bin/orch-*` | utility | request-response | `docs/hermes-dev-orchestra/scripts/bin/orch-*` | exact rename |
| `docs/orchestra/scripts/lib/orch-common.sh` | utility | file-I/O | `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` | exact rename |
| `docs/orchestra/scripts/tests/run-all.sh` | test | batch | `docs/hermes-dev-orchestra/scripts/tests/run-all.sh` | exact rename |
| `docs/orchestra/scripts/tests/test-*.sh` | test | request-response | `docs/hermes-dev-orchestra/scripts/tests/test-*.sh` | exact rename |
| `docs/orchestra/scripts/tests/lib/assert.sh` | test utility | transform | `docs/hermes-dev-orchestra/scripts/tests/lib/assert.sh` | exact rename |
| `docs/orchestra/config/rules.json` | config | transform | `docs/hermes-dev-orchestra/config/rules.json` | exact rename |
| `docs/orchestra/claude-config/settings.json` | config | event-driven | `docs/hermes-dev-orchestra/claude-config/settings.json` | exact rename |
| `README.md` | documentation | transform | `README.md` lines 13-25 | exact |
| `AGENTS.md` | documentation | transform | `AGENTS.md` lines 92-109 | exact |
| `CLAUDE.md` | documentation | transform | `CLAUDE.md` lines 82-85 | role-match |
| `docs/COVERAGE-MATRIX.md` | documentation | transform | `docs/COVERAGE-MATRIX.md` lines 5-8 | exact |
| `.planning/PROJECT.md` | planning document | transform | `.planning/PROJECT.md` lines 43-50, 86-112 | exact |
| `.planning/REQUIREMENTS.md` | planning document | transform | `.planning/REQUIREMENTS.md` lines 14-22, 58 | exact |
| `.planning/ROADMAP.md` | planning document | transform | `.planning/ROADMAP.md` lines 63-71 | exact |
| `.planning/DIRECTION-CORRECTION.md` | decision document | transform | `.planning/DIRECTION-CORRECTION.md` lines 1-41 | exact |
| `.planning/adr/ADR-001-upstream-pin.md` | documentation | decision record | `.planning/DIRECTION-CORRECTION.md` + Phase 9 summary | role-match |
| `.planning/upstream/hermes-agent-pin.json` | config | transform | `.planning/config.json`, `orch-init` JSON writers | role-match |

## Pattern Assignments

### `docs/orchestra/` package move (documentation/config/utility/test, transform)

**Analog:** `docs/hermes-dev-orchestra/` tree.

**Tracked files to move:** `git ls-files docs/hermes-dev-orchestra` currently reports 33 files: product docs, SOUL, four skills, two JSON configs, setup script, 11 `orch-*` helpers, shared shell library, smoke runner, nine smoke tests, and test assertions.

**Move pattern** from Phase 14 research (lines 194-196):

```bash
git status --short --branch
git mv -n docs/hermes-dev-orchestra docs/orchestra
git mv docs/hermes-dev-orchestra docs/orchestra
```

**Reference inventory pattern** from `.planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md` lines 35-62:

```markdown
## Path Reference Summary

- **Search command:** `rg -n "docs/hermes-dev-orchestra" --type md --type sh --type json`
- **Total matches:** 55
...
| `docs/hermes-dev-orchestra/scripts/bin/orch-risk-check` | scripts-bin | 5 |
| `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` | scripts-lib | 2 |
| `docs/hermes-dev-orchestra/scripts/setup.sh` | scripts-setup | 3 |
```

**Planner instruction:** use Phase 13 evidence as the checklist seed, but update active references only. Historical phase records can remain only if the execution plan calls them audit-only exceptions.

---

### Active reader/reference files (documentation, transform)

**Apply to:** `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/COVERAGE-MATRIX.md`, `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/DIRECTION-CORRECTION.md`.

**Root README pattern** from `README.md` lines 13-25:

```markdown
## Documentation

| Document | Description |
|----------|-------------|
| [`docs/hermes-dev-orchestra/README.md`](docs/hermes-dev-orchestra/README.md) | Product behavior baseline and architecture |
| [`docs/hermes-dev-orchestra/WORKFLOW.md`](docs/hermes-dev-orchestra/WORKFLOW.md) | Installation and usage guide |
...
- **Setup**: See `docs/hermes-dev-orchestra/WORKFLOW.md`
```

**Agent navigation pattern** from `AGENTS.md` lines 92-109:

```markdown
### Package Boundary

- This repository is an **adapter layer**, not a standalone runtime.
- Local entrypoints are limited to `orch-*` helpers: `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-audit`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-verify`.
- Spec authority lives in `docs/hermes-dev-orchestra/`; `.planning/SPEC.md` is canonical for planning artifacts.
...
| `docs/hermes-dev-orchestra/` | Product behavior baseline, SOUL, skills, scripts |
```

**Coverage matrix pattern** from `docs/COVERAGE-MATRIX.md` lines 5-8:

```markdown
| Upstream install/probe | Yes | No | No | `hermes --version`; pinned commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3` | Upstream remains the `hermes` entry point. |
| SOUL load | Yes | Yes | No | `docs/hermes-dev-orchestra/hermes/SOUL.md`; `setup.sh` | Adapter installs orchestra SOUL into upstream layout. |
| Four skills load | Yes | Yes | No | `dev-orchestra`, `claude-supervisor`, `codex-executor`, `escalation-handler` | Installed under `~/.hermes/skills/`. |
| `orch-init/start/stop/status` | No | Yes | No | `docs/hermes-dev-orchestra/scripts/bin/` | Local entrypoints remain `orch-*`. |
```

**Planner instruction:** replace active path literals with `docs/orchestra/...`. For `CLAUDE.md`, current lines 82-85 only point to `AGENTS.md` and `.planning/SPEC.md`; verify it has no stale path before changing it.

---

### Package docs self-references (documentation, transform)

**Apply to:** `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md`.

**README install command pattern** from `docs/hermes-dev-orchestra/README.md` lines 140-153:

````markdown
### Step 1: 一键安装

```bash
# 下载本方案包并解压
cd ~/hermes-dev-orchestra

# 运行安装脚本（无需 sudo，全部安装在用户目录）
bash docs/hermes-dev-orchestra/scripts/setup.sh
```

setup.sh 会自动完成：
- 检查上游 `hermes` 和 `tmux` 是否已安装
- 提示 `claude` 和 `codex` CLI 是否可用，但不安装或更新它们
- setup.sh installs Dev Orchestra SOUL、4 个自定义 Skills、4 层目录根、Claude hooks 模板、默认 `rules.json` 和 `orch-*` helper
````

**WORKFLOW install command pattern** from `docs/hermes-dev-orchestra/WORKFLOW.md` lines 72-79:

````markdown
#### 2.0.4 安装 Dev Orchestra 适配包

```bash
cd ~/hermes-dev-orchestra
bash docs/hermes-dev-orchestra/scripts/setup.sh
```

`setup.sh` 会自动完成：
````

**Planner instruction:** update the command path to `bash docs/orchestra/scripts/setup.sh`; do not rename project IDs or runtime roots such as `/tmp/hermes-orchestra`.

---

### Smoke tests with repo-root path literals (test, request-response)

**Apply to:** migrated files under `docs/orchestra/scripts/tests/`.

**Runner pattern** from `docs/hermes-dev-orchestra/scripts/tests/run-all.sh` lines 1-20:

```bash
#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0

shopt -s nullglob
for test_script in "$TEST_DIR"/test-*.sh; do
    if bash "$test_script"; then
        echo "PASS $test_script"
...
echo "Smoke summary: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
```

**Repo-root fixture pattern** from `test-docs.sh` lines 4-21:

```bash
TEST_NAME="docs-contract"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"
...
assert_contains "orch-decisions" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-decisions"
...
assert_contains "docs/COVERAGE-MATRIX.md" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must reference docs/COVERAGE-MATRIX.md"
```

**Helper invocation pattern** from `test-init-start-status.sh` lines 49-52:

```bash
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-init-start-init.out
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-start" test-proj "$PROJECT_DIR" >/tmp/orch-init-start-start.out
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-status" test-proj > /tmp/orch-init-start-status.out
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-stop" test-proj >/tmp/orch-init-start-stop.out || true
```

**Source/import pattern** from `test-decision-cli.sh` lines 20-31:

```bash
source "$REPO_ROOT/docs/hermes-dev-orchestra/scripts/lib/orch-common.sh"
orch_project_dirs test-proj
...
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-decisions" test-proj > /tmp/orch-decision-cli-list.out
...
"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_approve" "APPROVED fixture" >/tmp/orch-decision-cli-approve.out
```

**Planner instruction:** keep `REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"`; the depth stays correct after `docs/hermes-dev-orchestra` becomes `docs/orchestra`. Replace only `docs/hermes-dev-orchestra` path literals with `docs/orchestra` in smoke tests.

---

### Path-agnostic package scripts (utility, file-I/O)

**Apply to:** `docs/orchestra/scripts/setup.sh`, `docs/orchestra/scripts/bin/orch-*`, `docs/orchestra/scripts/lib/orch-common.sh`.

**Relative package-root pattern** from `setup.sh` lines 7-18:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_SKILLS_DIR="${HERMES_SKILLS_DIR:-$HERMES_HOME/skills}"
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"
ORCHESTRA_BIN_DIR="$ORCHESTRA_HOME/bin"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
RUNTIME_ROOT="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
STATE_ROOT="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"
AUDIT_ROOT="${AUDIT_ROOT:-$HOME/.local/share/hermes-orchestra}"
CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hermes-orchestra}"
```

**Install source pattern** from `setup.sh` lines 146-172:

```bash
HELPER_SRC_DIR="$PACKAGE_DIR/scripts/bin"
HELPER_LIB_SRC_DIR="$PACKAGE_DIR/scripts/lib"
TEST_SRC_DIR="$PACKAGE_DIR/scripts/tests"
RULES_SRC="$PACKAGE_DIR/config/rules.json"
...
cp "$HELPER_LIB_SRC_DIR/orch-common.sh" "$ORCHESTRA_HOME/lib/orch-common.sh"
...
for helper in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-audit orch-decisions orch-approve orch-reject orch-verify; do
```

**Verification wrapper pattern** from `orch-verify` lines 4-18:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"
...
PACKAGE_RUNNER="$(cd "$SCRIPT_DIR/.." && pwd)/tests/run-all.sh"
if [ -x "$PACKAGE_RUNNER" ]; then
    exec "$PACKAGE_RUNNER"
fi
```

**Planner instruction:** these scripts already compute paths relative to their new location. Do not replace runtime names (`hermes-orchestra`, `ORCHESTRA_HOME`, `RUNTIME_ROOT`) during this path migration.

---

### `.planning/adr/ADR-001-upstream-pin.md` (documentation, decision record)

**Analog:** `.planning/DIRECTION-CORRECTION.md` for local decision-record shape, plus `.planning/phases/09-upstream-hermes-agent-baseline/09-01-SUMMARY.md` for pin evidence.

**Existing ADR directory:** `.planning/adr/` exists but is empty. No exact ADR file pattern exists.

**Decision-record shape** from `.planning/DIRECTION-CORRECTION.md` lines 1-12:

```markdown
# Direction Correction: Upstream Hermes Agent Foundation

**Date:** 2026-04-25  
**Decision:** Hermes Dev Orchestra v1.1 must be implemented on top of community `NousResearch/hermes-agent`, not as an independent new Hermes Agent runtime.

## Trigger
...
## Corrected Direction

- Use community `NousResearch/hermes-agent` as the top-level Hermes Agent.
```

**Pin evidence source** from Phase 9 summary lines 319-341:

````markdown
- Pinned commit: `023b1bff11c2a01a435f1956a0e2ac1773a065f3`
- Install source: `https://github.com/NousResearch/hermes-agent`
- Installed remote normalized to HTTPS after install: `https://github.com/NousResearch/hermes-agent.git`
...
#### `hermes --version`

```text
Hermes Agent v0.11.0 (2026.4.23)
...
Upgrade procedure: intentionally choose a new upstream commit SHA, rerun the upstream installer/probe with HTTPS-safe Git config if needed, verify `hermes --version` and `hermes --help`, then update this pinned commit and capability matrix.
```
````

**Recommended ADR structure:**

```markdown
# ADR-001: Upstream Hermes Agent Pin Strategy

**Date:** 2026-04-28
**Status:** Accepted
**Decision:** Use a repo-local JSON manifest pin for v1.2.

## Context
## Decision
## Options Considered
| Option | How it works | Pros | Cons | Decision |
| installer/probe pin | ... | ... | ... | Rejected |
| git submodule | ... | ... | ... | Rejected |
| manifest pin | ... | ... | ... | Accepted |
| vendor snapshot | ... | ... | ... | Rejected |
## Consequences
## UPST-02 Applicability
## Verification
```

**Planner instruction:** explicitly state that UPST-02 is not applicable because git submodule is not selected, and that the phase must not introduce `.gitmodules` or a `hermes-agent` gitlink.

---

### `.planning/upstream/hermes-agent-pin.json` (config, transform)

**Analog:** `.planning/config.json` for repo-local JSON style, `docs/hermes-dev-orchestra/config/rules.json` for two-space JSON, and `orch-init` for Python JSON write/validation conventions.

**No existing upstream manifest directory:** `.planning/upstream/` does not exist yet.

**Repo JSON style** from `.planning/config.json` lines 1-8:

```json
{
  "model_profile": "balanced",
  "commit_docs": true,
  "parallelization": true,
  "search_gitignored": false,
  "brave_search": false,
  "firecrawl": false,
```

**JSON writer pattern** from `docs/hermes-dev-orchestra/scripts/bin/orch-init` lines 71-84:

```bash
python3 - "$STATE_DIR/paths.json" "$PROJECT_ID" "$PROJECT_DIR" "$RUNTIME_DIR" "$STATE_DIR" "$AUDIT_DIR" "$CACHE_DIR" <<'PY'
import json, sys
path, project_id, project_dir, runtime_dir, state_dir, audit_dir, cache_dir = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "project_id": project_id,
        "project_dir": project_dir,
        "runtime_dir": runtime_dir,
        "state_dir": state_dir,
        "audit_dir": audit_dir,
        "cache_dir": cache_dir,
    }, handle, indent=2)
    handle.write("\n")
PY
```

**JSON read/validate pattern** from `orch-risk-check` lines 24-31:

```bash
python3 - "$RULES_FILE" "$OPERATION" <<'PY'
import json
import sys

rules_path, operation = sys.argv[1:]
with open(rules_path, encoding="utf-8") as handle:
    rules = json.load(handle)
```

**Recommended manifest schema:**

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
    "Update this manifest and related documentation in the same change."
  ]
}
```

**Planner instruction:** use JSON only, two-space indentation, final newline, and validate with `python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null`.

## Shared Patterns

### Active-vs-Historical Reference Gate

**Source:** `.planning/phases/14-migration-submodule-adr/14-VALIDATION.md` lines 20-23 and 41.

**Apply to:** all path-reference updates.

```markdown
| **Framework** | Bash smoke fixtures plus grep/JSON/Git checks |
| **Quick run command** | `! rg -n "docs/hermes-dev-orchestra" README.md AGENTS.md CLAUDE.md docs .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md && python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null` |
| **Full suite command** | `bash docs/orchestra/scripts/tests/run-all.sh` |
...
`git status --short -- docs/hermes-dev-orchestra docs/orchestra && ! rg -n "docs/hermes-dev-orchestra" README.md AGENTS.md CLAUDE.md docs .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md`
```

Do not use a repository-wide zero-match gate against `.planning/phases/**`; Phase 13 and Phase 14 artifacts intentionally contain historical evidence.

### Bash Smoke Fixture Style

**Source:** `docs/hermes-dev-orchestra/scripts/tests/lib/assert.sh` lines 1-31, 47-57, 75-77.

**Apply to:** migrated tests and any new validation fixture.

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${TEST_NAME:=unnamed-test}"
...
assert_contains() {
    local needle="$1"
    local file="$2"
    local message="${3:-missing expected content}"

    grep -Fq "$needle" "$file" || fail "$message" "$needle" "$(sed -n '1,40p' "$file" 2>/dev/null || true)"
}
...
assert_jsonl_valid() {
    local file="$1"

    python3 - "$file" <<'PY' || fail "invalid JSONL" "$file" "parse failed"
```

### Shell Syntax Verification

**Source:** `.planning/phases/14-migration-submodule-adr/14-VALIDATION.md` lines 30-32 and 42.

**Apply to:** all migrated shell scripts under `docs/orchestra/scripts`.

```bash
while IFS= read -r f; do
  bash -n "$f"
done < <(find docs/orchestra/scripts -type f \( -name "*.sh" -o -path "*/scripts/bin/orch-*" \) -print | sort)

bash docs/orchestra/scripts/tests/run-all.sh
```

### No Submodule Artifacts

**Source:** `.planning/phases/14-migration-submodule-adr/14-VALIDATION.md` lines 43-44.

**Apply to:** ADR and final git review.

```bash
rg -n "UPST-02|not applicable|manifest pin" .planning/adr/ADR-001-upstream-pin.md
test ! -f .gitmodules
! git ls-files --stage | grep -q '^160000 '
```

### Dirty Worktree Awareness

**Source:** current `git status --short --branch`.

**Apply to:** execution planning.

```text
## main
M  .planning/phases/999.1-backlog-hermes-supervisor-execution-audit-gap/BACKLOG.md
D  ".planning/phases/999.2-backlog-collaborative-planning copy/.gitkeep"
D  ".planning/phases/999.2-backlog-collaborative-planning copy/999.1-backlog-hermes-supervisor-execution-audit-gap/.gitkeep"
D  ".planning/phases/999.2-backlog-collaborative-planning copy/999.1-backlog-hermes-supervisor-execution-audit-gap/BACKLOG.md"
D  ".planning/phases/999.2-backlog-collaborative-planning copy/BACKLOG.md"
?? .planning/phases/14-migration-submodule-adr/14-PATTERNS.md
```

Preserve unrelated backlog modifications/deletions; do not include them in Phase 14 migration changes.

## No Exact Analog Found

These files have no exact local precedent, but have close role-match analogs above:

| File | Role | Data Flow | Fallback Pattern |
|------|------|-----------|------------------|
| `.planning/adr/ADR-001-upstream-pin.md` | documentation | decision record | Use `.planning/DIRECTION-CORRECTION.md` decision shape plus Phase 9 pin evidence. |
| `.planning/upstream/hermes-agent-pin.json` | config | transform | Use repo JSON style and `orch-init` Python JSON writer conventions. |

## Metadata

**Analog search scope:** `docs/hermes-dev-orchestra/`, root docs, `.planning/`, smoke tests, config JSON.
**Files scanned:** 60+ via `rg --files`, targeted `rg -n`, `nl -ba`, and `wc -l`.
**Pattern extraction date:** 2026-04-28.
**Project-local skills:** none found under `.claude/skills/` or `.agents/skills/`.

## PATTERN MAPPING COMPLETE
