# Phase 16: Makefile & Dev Workflow - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 1 planned file plus existing test and pin inputs
**Analogs found:** 1 / 1

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Makefile` | dev workflow entrypoint | command delegation, file validation, status reporting | `docs/orchestra/scripts/tests/run-all.sh` plus `.planning/upstream/hermes-agent-pin.json` | role-match |

## Pattern Assignments

### `Makefile` (dev workflow entrypoint)

**Analog 1:** `docs/orchestra/scripts/tests/run-all.sh`

**Existing fail-fast runner pattern:**

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
        PASSED=$((PASSED + 1))
    else
        echo "FAIL $test_script"
        FAILED=$((FAILED + 1))
    fi
done
```

**Apply to new file:**

- `test-unit` should delegate to the existing runner rather than duplicating discovery logic.
- `test-risk` should call a fixed list of existing risk/approval scripts because the roadmap requires exactly three risk approval tests.
- Recipes should fail on test failure through normal shell exit status.

**Analog 2:** `.planning/upstream/hermes-agent-pin.json`

**Machine-readable pin contract:**

```json
{
  "phase_16_contract": {
    "repo_pin_json_pointer": "/pin/commit",
    "observed_version_json_pointer": "/pin/observed_version",
    "runtime_pin_probe": "git -C ${HERMES_AGENT_DIR:-$HOME/.hermes/hermes-agent} rev-parse HEAD"
  }
}
```

**Apply to new file:**

- `upstream-status` must read `/pin/commit` from `.planning/upstream/hermes-agent-pin.json`.
- Runtime path must default to `${HERMES_AGENT_DIR:-$HOME/.hermes/hermes-agent}`.
- If runtime path is a Git checkout, compare `git rev-parse HEAD` to the repo pin.
- If runtime path is missing, print a missing-runtime status and exit 0.
- If runtime path exists and commit mismatches, print mismatch and exit non-zero.

**Analog 3:** Existing Bash test prologue

Existing tests consistently use strict shell mode:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Apply to new file:**

- Each non-trivial Make recipe should run under `bash -lc 'set -euo pipefail; ...'` or use Make variables and simple commands with clear exit behavior.
- Avoid silently ignoring failures except for the explicit `lint-shell` no-shellcheck skip.

## Planned Target Surface

| Target | Role | Existing Inputs |
|---|---|---|
| `test` | Full local verification aggregate | `test-unit`, `test-risk`, `lint-json`, `lint-shell`, `upstream-status` |
| `test-unit` | Existing smoke/unit fixture entrypoint | `docs/orchestra/scripts/tests/run-all.sh` |
| `test-risk` | Required risk approval smoke subset | `test-risk-check.sh`, `test-risk-decisions.sh`, `test-decision-cli.sh` |
| `lint-json` | JSON syntax validation | all `*.json` files outside `.git` |
| `lint-shell` | Optional shell lint | existing shell scripts under `docs/orchestra/scripts/` |
| `upstream-status` | Repo/runtime upstream pin status | `.planning/upstream/hermes-agent-pin.json`, runtime Hermes checkout |

## Anti-Patterns to Avoid

- Do not add `test-integration`, `test-e2e`, `coverage`, `release`, or other placeholder targets.
- Do not hardcode `/home/stark`; use `$HOME` and `HERMES_AGENT_DIR`.
- Do not require `shellcheck` for a passing local workflow when it is absent.
- Do not require `jq` for `upstream-status`; Python stdlib is enough and already used by tests.
- Do not modify `docs/orchestra/scripts/tests/run-all.sh` just to wire Makefile targets.

## Pattern Map Complete

The phase can be implemented with one Makefile plan and direct verification commands.
