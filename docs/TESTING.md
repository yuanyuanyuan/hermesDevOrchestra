<!-- generated-by: gsd-doc-writer -->

# Testing

This project uses a custom Bash-based smoke test suite. All tests are executable shell scripts that exercise CLI binaries, file contracts, and integration behavior.

## Test Framework and Setup

The test harness is pure Bash with a shared assertion library.

| Component | Location | Purpose |
|-----------|----------|---------|
| Test runner | `scripts/tests/run-all.sh` | Discovers and executes every `test-*.sh` script |
| Assertion library | `scripts/tests/lib/assert.sh` | Provides `assert_eq`, `assert_contains`, `assert_file_exists`, `assert_exit_code`, `assert_jsonl_valid`, etc. |
| Test scripts | `scripts/tests/test-*.sh` | Individual smoke tests; current repository has 164 scripts (including 3 Sprint 12 strict gates) |

No external JavaScript test framework (Jest, Vitest, Mocha) is used. The smoke suite is mostly Bash plus Python helpers; `run-all.sh` dispatches Python shebang tests with `python3`.

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

This runs `test-unit`, `test-risk`, `lint-json`, `lint-shell`, and `upstream-status`. `npm test` delegates to this target.

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
make lint-json      # validates source *.json files with python3 -m json.tool; ignores local .tmp/ cache
make lint-shell     # runs shellcheck on scripts/*.sh when shellcheck is installed; otherwise skipped
```

### Upstream Pin Check

```bash
make upstream-status
```

Compares the pinned upstream commit in `.planning/upstream/hermes-agent-pin.json` against the local runtime checkout at `~/.hermes/hermes-agent`.

<!-- VERIFY: No watch mode is currently configured for the test suite. -->

## Sprint 12 Strict Gates

`spec.md` FR-14 requires that schema validation, docs sync, success metric pipeline, and strict e2e audit gate pass together before Sprint 12 deliverable closure. The 3 scripts below are the operational realisation of that requirement, and serve as the producer (Sprint 12) → consumer (Sprint 13) handoff for the final audit gate.

| Script | Role | Producer | Consumer |
|---|---|---|---|
| `scripts/tests/test-schema-doc-sync.sh` | schema ↔ docs reconciliation | Sprint 12 U14 (3 SP) | Sprint 13 final audit gate |
| `scripts/tests/test-success-metrics-pipeline.sh` | success metrics end-to-end | Sprint 12 U14 | Sprint 13 final audit gate |
| `scripts/tests/test-e2e-strict-six-stage-flow.sh` | 0→6 strict staging regression | Sprint 12 U14 | Sprint 13 final audit gate |

> All three must pass together before Sprint 13 release decision (per `spec.md` FR-14). See also [`docs/WORKFLOW.md`](WORKFLOW.md) `## 当前正在执行的修复计划`.

### Related Cross-Sprint Contract Surfaces

These 3 strict gates validate the 6 Cross-Sprint Contracts surfaced in [`docs/gateway-integration-architecture.md`](gateway-integration-architecture.md) `## Cross-Sprint Contract Surfaces`:

- `conflict_ledger` (Contract 1) — closeout audit must read every conflict record before marking a run closed (FR-1)
- `run.lifecycle_status` + transition guard (Contract 2) — 13 allowed values, illegal transitions fail-closed (FR-2)
- `run.channel_decision` (Contract 3) — 9 required fields, alters required debate/evidence depth (FR-4/FR-5)
- `authority_route` + `override_record` (Contract 4) — residual-risk approval (FR-10/FR-11)
- mini-debate `consensus_score ≥ 0.60` (Contract 5) — E-class improvement dispute (FR-13)
- Sprint 12 → Sprint 13 gate scripts (Contract 6) — producer/consumer handoff (FR-14)

Full field shapes per contract: see [`docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`](sprints/prd-compliance-audit-remediation-full/sprint-overview.md) `## Cross-Sprint Contracts` table.

## Coverage Requirements

There are no automated coverage thresholds configured for this project. The smoke tests verify behavioral contracts (CLI exit codes, file existence, output content, spec conformance) rather than line coverage.

<!-- VERIFY: No coverage tool (jest, vitest, nyc, c8) or threshold configuration exists in the repository. -->

## CI Integration

<!-- VERIFY: No CI configuration files (.github/workflows, .gitlab-ci.yml, etc.) exist in the repository. -->

Tests are executed locally via `make test`. If adding CI, the recommended pipeline step is:

```bash
make test
```

This ensures the full matrix runs: smoke tests, risk tests, JSON lint, shell lint when available, and upstream pin advisory verification.
