<!-- generated-by: gsd-doc-writer -->

# Testing

This project uses a custom Bash-based smoke test suite. All tests are executable shell scripts that exercise CLI binaries, file contracts, and integration behavior.

## Test Framework and Setup

The test harness is pure Bash with a shared assertion library.

| Component | Location | Purpose |
|-----------|----------|---------|
| Test runner | `scripts/tests/run-all.sh` | Discovers and executes every `test-*.sh` script |
| Assertion library | `scripts/tests/lib/assert.sh` | Provides `assert_eq`, `assert_contains`, `assert_file_exists`, `assert_exit_code`, `assert_jsonl_valid`, etc. |
| Test scripts | `scripts/tests/test-*.sh` | Individual smoke tests (25 scripts) |

No external test framework (Jest, Vitest, Mocha, pytest) is used. The only runtime dependency is `bash` and `python3` (used by some tests for JSON/JSONL validation).

### Writing a New Test

Create a file named `scripts/tests/test-<name>.sh` and follow this template:

```bash
#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="<descriptive-name>"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

# …test logic…

test_done
```

Key conventions:
- Set `TEST_NAME` at the top; it appears in pass/fail output.
- Source `lib/assert.sh` for all assertion helpers.
- End every script with `test_done` to emit the PASS line.
- Use `set +e` / `set -e` when capturing exit codes of commands under test.
- Use `mktemp -d` plus `trap 'rm -rf "$TMP_DIR"' EXIT` for temporary files.

Available assertion helpers from `lib/assert.sh`:
- `assert_eq <expected> <actual> [<message>]`
- `assert_contains <needle> <file> [<message>]`
- `assert_file_exists <file> [<message>]`
- `assert_executable <file> [<message>]`
- `assert_exit_code <expected> <actual> [<message>]`
- `assert_jsonl_valid <file>` — validates JSON Lines via Python3
- `make_fake_path <dir>` — prepends a fake bin directory to `PATH`

## Running Tests

### Full Suite

```bash
make test
```

This runs `test-unit`, `test-risk`, `lint-json`, `lint-shell`, and `upstream-status`.

### Unit / Smoke Tests Only

```bash
make test-unit
# or directly:
bash scripts/tests/run-all.sh
```

### Risk Tests Only

```bash
make test-risk
```

### Single Test File

```bash
bash scripts/tests/test-risk-check.sh
bash scripts/tests/test-docs.sh
bash scripts/tests/test-specs.sh
```

### Linting

```bash
make lint-json      # validates all *.json files with python3 -m json.tool
make lint-shell     # runs shellcheck on scripts/*.sh (skipped if shellcheck is missing)
```

### Upstream Pin Check

```bash
make upstream-status
```

Compares the pinned upstream commit in `.planning/upstream/hermes-agent-pin.json` against the local runtime checkout at `~/.hermes/hermes-agent`.

<!-- VERIFY: No watch mode is currently configured for the test suite. -->

## Coverage Requirements

There are no automated coverage thresholds configured for this project. The smoke tests verify behavioral contracts (CLI exit codes, file existence, output content, spec conformance) rather than line coverage.

<!-- VERIFY: No coverage tool (jest, vitest, nyc, c8) or threshold configuration exists in the repository. -->

## CI Integration

<!-- VERIFY: No CI configuration files (.github/workflows, .gitlab-ci.yml, etc.) exist in the repository. -->

Tests are executed locally via `make test`. If adding CI, the recommended pipeline step is:

```bash
make test
```

This ensures the full matrix runs: smoke tests, risk tests, JSON lint, shell lint, and upstream pin verification.
