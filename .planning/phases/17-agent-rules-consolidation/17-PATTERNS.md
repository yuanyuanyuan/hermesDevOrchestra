# Phase 17: Agent Rules Consolidation - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| File | Role | Data Flow | Closest Analog | Match Quality |
|------|------|-----------|----------------|---------------|
| `AGENTS.md` | config | transform | `AGENTS.md` managed GSD sections + Dev Orchestra block | exact |
| `CLAUDE.md` | config | transform | `CLAUDE.md` Hermes Dev Orchestra References | exact |
| `docs/orchestra/scripts/tests/test-agent-rules.sh` (optional) | test | batch | `docs/orchestra/scripts/tests/test-docs.sh` | role+flow |
| `docs/orchestra/scripts/tests/test-agent-rules.sh` (optional Python validation) | test | batch/transform | `docs/orchestra/scripts/tests/test-specs.sh` | role+flow |
| `Makefile` | config | batch | existing root `Makefile` test aggregation | exact |
| `specs/commands.md` / `specs/risk-decisions.md` | config | transform | existing derived spec contracts | exact/reference |

## Pattern Assignments

### `AGENTS.md` (config, transform)

**Analog:** `AGENTS.md`

**Managed section preservation pattern** (lines 1, 13, 65, 77, 79, 84):
```markdown
<!-- GSD:project-start source:PROJECT.md -->
...
<!-- GSD:project-end -->

<!-- GSD:workflow-start source:GSD defaults -->
...
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
...
<!-- GSD:profile-end -->
```

**Dev Orchestra delimiter and heading pattern** (lines 86-92):
```markdown
<!-- hermes-dev-orchestra-start -->
## Hermes Dev Orchestra

Project-specific rules for the Hermes Dev Orchestra adaptation layer.
These complement (not replace) the Architecture section above.

### Package Boundary
```

**Package boundary content pattern** (lines 94-96):
```markdown
- This repository is an **adapter layer**, not a standalone runtime.
- Local entrypoints are limited to `orch-*` helpers: `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-audit`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-verify`.
- Spec authority lives in `docs/orchestra/`; `.planning/SPEC.md` is canonical for planning artifacts.
```

**Agent role boundary and risk wording pattern** (lines 98-103):
```markdown
### Agent Role Boundary

- **Hermes** must not auto-approve L3/L4 escalations. Blocking flows through `escalation.md` or high-risk `claude-decision.md`, `orch-bus-loop`, pending decisions, and explicit user action via `orch-decisions`, `orch-approve`, or `orch-reject`.
- **Claude** must not modify upstream `NousResearch/hermes-agent` core code.
- **Codex** must not modify `~/.hermes-orchestra/rules.json`.
- `orch-risk-check` is a risk classifier/helper; it is not a replacement for the L3/L4 blocking and user-decision flow.
```

**Directory navigation pattern** (lines 105-112):
```markdown
### Directory Navigation

| Directory | Purpose |
|-----------|---------|
| `docs/orchestra/` | Product behavior baseline, SOUL, skills, scripts |
| `.planning/SPEC.md` | Canonical specification |
| `.planning/STATE.md` | Project state and decisions |
<!-- hermes-dev-orchestra-end -->
```

**Planner guidance:** Patch only inside the `hermes-dev-orchestra` block if a real gap exists. Do not rewrite or reorder GSD-managed sections.

---

### `CLAUDE.md` (config, transform)

**Analog:** `CLAUDE.md`

**Pointer-only authority pattern** (lines 82-85):
```markdown
## Hermes Dev Orchestra References

- Agent rules and boundaries: See `AGENTS.md` -> `## Hermes Dev Orchestra`
- Canonical specification: See `.planning/SPEC.md`
```

**Planner guidance:** Keep this as a pointer file. Do not copy the Package Boundary, Agent Role Boundary, helper list, or L3/L4 rules into `CLAUDE.md`.

---

### `docs/orchestra/scripts/tests/test-agent-rules.sh` (optional test, batch)

**Analog:** `docs/orchestra/scripts/tests/test-docs.sh`

**Test harness setup pattern** (lines 1-12):
```bash
#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="docs-contract"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
```

**Static content assertion pattern** (lines 14-19):
```bash
assert_contains "orch-decisions" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-decisions"
assert_contains "orch-approve" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-approve"
assert_contains "orch-reject" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-reject"
assert_contains "orch-risk-check" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-risk-check"
assert_contains "orch-audit" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-audit"
assert_contains "orch-verify" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-verify"
```

**Completion pattern** (line 34):
```bash
test_done
```

**Shared assertion helper pattern:** `docs/orchestra/scripts/tests/lib/assert.sh` lines 25-37:
```bash
assert_contains() {
    local needle="$1"
    local file="$2"
    local message="${3:-missing expected content}"

    grep -Fq "$needle" "$file" || fail "$message" "$needle" "$(sed -n '1,40p' "$file" 2>/dev/null || true)"
}

assert_file_exists() {
    local file="$1"
    local message="${2:-file missing}"

    [ -f "$file" ] || fail "$message" "$file" "missing"
}
```

**Apply for Phase 17 static checks:** Use `assert_contains` against `$REPO_ROOT/AGENTS.md` and `$REPO_ROOT/CLAUDE.md` for markers, headings, helper names, no-auto-approval wording, and authority pointers.

---

### `docs/orchestra/scripts/tests/test-agent-rules.sh` (optional Python validation, batch/transform)

**Analog:** `docs/orchestra/scripts/tests/test-specs.sh`

**Array-driven expected inventory pattern** (lines 11-21):
```bash
SPECS_DIR="$REPO_ROOT/specs"
SPEC_INDEX="$SPECS_DIR/README.md"
EXPECTED_SPECS=("commands.md" "file-bus.md" "risk-decisions.md")
REQUIRED_SECTIONS=("## Source" "## Consumers" "## Drift Check" "## Conformance Checks")

assert_file_exists "$SPEC_INDEX" "specs index missing"
assert_contains ".planning/SPEC.md" "$SPEC_INDEX" "specs index must state canonical source"

expected_inventory="$(printf '%s\n' "README.md" "${EXPECTED_SPECS[@]}" | sort)"
actual_inventory="$(find "$SPECS_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort)"
[ "$expected_inventory" = "$actual_inventory" ] || fail "unexpected specs inventory" "$expected_inventory" "$actual_inventory"
```

**Looped section/content validation pattern** (lines 23-31):
```bash
for spec in "${EXPECTED_SPECS[@]}"; do
    spec_file="$SPECS_DIR/$spec"
    assert_file_exists "$spec_file" "derived spec missing"
    for section in "${REQUIRED_SECTIONS[@]}"; do
        assert_contains "$section" "$spec_file" "derived spec missing required section"
    done
    assert_contains ".planning/SPEC.md" "$spec_file" "derived spec must cite canonical source"
    assert_contains "$spec" "$SPEC_INDEX" "spec index missing derived spec"
    assert_contains "bash docs/orchestra/scripts/tests/test-specs.sh" "$spec_file" "derived spec missing self conformance check"
done
```

**Inline Python structural validation pattern** (lines 34, 53-67):
```bash
python3 - "$REPO_ROOT" "$SPEC_INDEX" "${EXPECTED_SPECS[@]/#/$SPECS_DIR/}" <<'PY' || fail "spec metadata validation failed"
...
def section_body(text, heading, spec_path):
    match = re.search(rf"^{re.escape(heading)}\s*$", text, re.MULTILINE)
    if not match:
        messages = {
            "## Consumers": "missing Consumers section",
            "## Drift Check": "missing Drift Check section",
            "## Conformance Checks": "missing Conformance Checks section",
        }
        die(f"{messages.get(heading, f'missing {heading} section')}: {spec_path}")
    start = match.end()
    next_match = re.search(r"^##\s+", text[start:], re.MULTILINE)
    end = start + next_match.start() if next_match else len(text)
    return text[start:end]
PY
```

**Apply for Phase 17 static checks:** Prefer simple `assert_contains`. Use inline Python only if the planner wants to validate block-bounded content, for example verifying required text appears inside `<!-- hermes-dev-orchestra-start -->` / `<!-- hermes-dev-orchestra-end -->`.

---

### `Makefile` (config, batch)

**Analog:** `Makefile`

**Aggregate verification target pattern** (lines 3-20):
```make
TEST_RUNNER := docs/orchestra/scripts/tests/run-all.sh
RISK_TESTS := docs/orchestra/scripts/tests/test-risk-check.sh docs/orchestra/scripts/tests/test-risk-decisions.sh docs/orchestra/scripts/tests/test-decision-cli.sh
PIN_MANIFEST := .planning/upstream/hermes-agent-pin.json
HERMES_AGENT_DIR ?= $(HOME)/.hermes/hermes-agent

test: test-unit test-risk lint-json lint-shell upstream-status

test-unit:
	@bash $(TEST_RUNNER)

test-risk:
	@set -e; \
	for script in $(RISK_TESTS); do \
		bash "$$script"; \
	done

lint-json:
	@find . -path './.git' -prune -o -name '*.json' -type f -print0 | xargs -0 -r -n1 python3 -m json.tool >/dev/null
```

**Optional shellcheck pattern** (lines 22-27):
```make
lint-shell:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck docs/orchestra/scripts/setup.sh docs/orchestra/scripts/lib/*.sh docs/orchestra/scripts/bin/orch-* docs/orchestra/scripts/tests/*.sh docs/orchestra/scripts/tests/lib/*.sh; \
	else \
		echo "shellcheck not found; skipping shell lint"; \
	fi
```

**Planner guidance:** Phase 17 requires `make test`. Modify `Makefile` only if a persistent `test-agent-rules.sh` is added and must be wired into the aggregate gate. Otherwise leave it unchanged and run `rtk make test`.

---

### `specs/commands.md` and `specs/risk-decisions.md` (config, transform)

**Analogs:** existing derived specs

**Command surface source pattern:** `specs/commands.md` line 31:
```markdown
- The current local helper surface is `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, and `orch-verify`.
```

**Command drift check pattern:** `specs/commands.md` lines 37-47:
````markdown
## Drift Check

```bash
for cmd in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-decisions orch-approve orch-reject orch-audit orch-verify; do test -x "docs/orchestra/scripts/bin/$cmd"; done && bash docs/orchestra/scripts/tests/test-specs.sh && bash docs/orchestra/scripts/tests/test-docs.sh
```

## Conformance Checks

- `bash docs/orchestra/scripts/tests/test-specs.sh`
- `bash docs/orchestra/scripts/tests/test-docs.sh`
- `for cmd in orch-init orch-start orch-stop orch-status orch-bus-loop orch-risk-check orch-decisions orch-approve orch-reject orch-audit orch-verify; do test -x "docs/orchestra/scripts/bin/$cmd"; done`
````

**Risk no-auto-approval source pattern:** `specs/risk-decisions.md` lines 27-29:
```markdown
- L3 and L4 decisions block the affected project until the user explicitly approves or rejects the proposal.
- L3 and L4 decisions have no timeout-based or fallback auto-approval path. Timeout defaults to rejection.
- Local fallback commands are `orch-decisions`, `orch-approve`, and `orch-reject`.
```

**Planner guidance:** Treat these specs as read-only evidence for Phase 17 unless a static check proves they conflict with `.planning/SPEC.md`.

## Shared Patterns

### Static Agent-Rule Check Shape

**Source:** `docs/orchestra/scripts/tests/test-docs.sh` lines 1-19 and `docs/orchestra/scripts/tests/lib/assert.sh` lines 25-37  
**Apply to:** optional persistent Phase 17 static check script.

Use Bash with `set -euo pipefail`, resolve `REPO_ROOT` from the test script path, source `lib/assert.sh`, then assert fixed strings in `AGENTS.md` and `CLAUDE.md`.

### Managed Marker Preservation

**Source:** `AGENTS.md` lines 1-84  
**Apply to:** any `AGENTS.md` edit.

Static checks should include GSD marker strings such as `<!-- GSD:project-start`, `<!-- GSD:workflow-end -->`, and `<!-- GSD:profile-end -->` before and after the Dev Orchestra block check.

### Dev Orchestra Block Boundary

**Source:** `AGENTS.md` lines 86-112  
**Apply to:** any `AGENTS.md` edit.

Check the delimited block, not the whole file, if using Python. Required content: `### Package Boundary`, `### Agent Role Boundary`, all actual `orch-*` helpers, `.planning/SPEC.md`, and L3/L4 no-auto-approval wording.

### Claude Pointer-Only Rule

**Source:** `CLAUDE.md` lines 82-85  
**Apply to:** any `CLAUDE.md` edit.

Required pointers are `AGENTS.md` and `.planning/SPEC.md`. Avoid adding duplicated Dev Orchestra rules.

### Verification Gate

**Source:** `Makefile` lines 8-31  
**Apply to:** Phase 17 completion.

Run static agent-rule checks first, patch only exact failures if any, then run:
```bash
rtk make test
```

## No Analog Found

None. All reviewed or optional files have direct in-repository analogs.

## Metadata

**Analog search scope:** root instruction files, `Makefile`, `specs/*.md`, `docs/orchestra/scripts/tests/*.sh`, `docs/orchestra/scripts/tests/lib/*.sh`  
**Files scanned:** 49 repository files; 16 files under `specs/` and `docs/orchestra/scripts/tests/`  
**Project-local skills:** none found under `.claude/skills/` or `.agents/skills/`  
**Pattern extraction date:** 2026-04-28
