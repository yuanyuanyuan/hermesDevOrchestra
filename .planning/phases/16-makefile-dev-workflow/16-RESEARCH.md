# Phase 16: Makefile & Dev Workflow - Research

**Researched:** 2026-04-28
**Phase:** 16 - Makefile & Dev Workflow
**Goal:** Create a Makefile that references only real tests and provides local verification entrypoints.

## Research Summary

Phase 16 should be implemented as a narrow developer-workflow layer: add one root `Makefile` that delegates to existing Bash smoke tests, validates JSON with Python stdlib, skips shell lint cleanly when `shellcheck` is unavailable, and reports upstream Hermes Agent pin status from the repo-local manifest plus the runtime checkout.

No new test scripts are required to satisfy the phase. The existing smoke runner already passed locally, and the Makefile can use exact existing script paths.

## Evidence Collected

| Probe | Result |
|---|---|
| Root `Makefile` | Not present before Phase 16. |
| Existing smoke runner | `docs/orchestra/scripts/tests/run-all.sh` exists and discovers `test-*.sh`. |
| Existing tests | 10 scripts exist under `docs/orchestra/scripts/tests/`. |
| Smoke suite baseline | `bash docs/orchestra/scripts/tests/run-all.sh` passed: 10 passed, 0 failed. |
| `shellcheck` | Not found in current PATH. |
| `python3` | Present at `/usr/bin/python3`. |
| `jq` | Present at `/usr/bin/jq`. |
| `make` | Present at `/usr/bin/make`. |
| Repo-local upstream pin | `.planning/upstream/hermes-agent-pin.json` contains commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`. |
| Runtime upstream pin | `git -C ${HERMES_AGENT_DIR:-$HOME/.hermes/hermes-agent} rev-parse HEAD` returned the same commit locally. |
| Hermes version probe | `hermes --version` returned `Hermes Agent v0.11.0 (2026.4.23)`. |

## Requirement Mapping

| Requirement | Planning Implication |
|---|---|
| DEV-01 | The Makefile must reference only existing files. Do not add placeholder targets such as `test-integration` or `test-e2e`. |
| DEV-02 | `test-unit` should run the existing smoke/unit fixture surface; `test-risk` should run exactly the three risk/approval tests called out by the roadmap. |
| DEV-03 | `lint-json` should parse every `*.json` outside `.git`; `lint-shell` should print an explicit skip message and exit 0 when `shellcheck` is absent. |
| DEV-04 | `upstream-status` should print the repo-local expected pin and runtime observed pin, compare them when both exist, and avoid failing only because the runtime checkout is absent. |

## Existing Test Inventory

Current executable smoke tests:

```text
docs/orchestra/scripts/tests/test-decision-cli.sh
docs/orchestra/scripts/tests/test-decision-replay.sh
docs/orchestra/scripts/tests/test-docs.sh
docs/orchestra/scripts/tests/test-file-bus.sh
docs/orchestra/scripts/tests/test-init-start-status.sh
docs/orchestra/scripts/tests/test-install-probe.sh
docs/orchestra/scripts/tests/test-risk-check.sh
docs/orchestra/scripts/tests/test-risk-decisions.sh
docs/orchestra/scripts/tests/test-skills-load.sh
docs/orchestra/scripts/tests/test-specs.sh
```

Recommended target mapping:

| Make target | Delegation |
|---|---|
| `test-unit` | `bash docs/orchestra/scripts/tests/run-all.sh` |
| `test-risk` | `test-risk-check.sh`, `test-risk-decisions.sh`, `test-decision-cli.sh` |
| `lint-json` | `find . -path './.git' -prune -o -name '*.json' -type f -print0 \| xargs -0 -r -n1 python3 -m json.tool >/dev/null` |
| `lint-shell` | If `shellcheck` exists, run it over real shell scripts; otherwise echo `shellcheck not found; skipping shell lint` and exit 0. |
| `upstream-status` | Read `.planning/upstream/hermes-agent-pin.json`; probe `${HERMES_AGENT_DIR:-$HOME/.hermes/hermes-agent}` if it is a Git checkout; print match/mismatch/missing status. |

## Implementation Guidance

- Keep the Makefile at repository root.
- Use `.PHONY` only for real implemented targets.
- Use variables for exact script paths so each referenced test can be checked in one place.
- Do not create placeholder integration, e2e, coverage, install, or release targets.
- Prefer Python stdlib JSON parsing over requiring `jq` for `lint-json`, even though `jq` is present locally.
- For `upstream-status`, parse `.planning/upstream/hermes-agent-pin.json` with Python to avoid depending on `jq`.
- If runtime checkout is missing, `upstream-status` should report it and exit 0 because DEV-04 says compare when both repo-local and runtime pins exist.
- If runtime checkout exists and the commit differs from the manifest pin, `upstream-status` should exit non-zero.

## Risks and Pitfalls

| Risk | Mitigation |
|---|---|
| False target drift | Acceptance checks must reject `test-integration`, `test-e2e`, `coverage`, or other unimplemented target names in `Makefile`. |
| Silent shell lint skip | `lint-shell` must print an explicit skip message when `shellcheck` is missing. |
| JSON lint misses hidden config | `lint-json` must scan all repo JSON files outside `.git`, including `.claude/*.json`, `.planning/*.json`, and `docs/orchestra/**/*.json`. |
| Runtime pin status becomes too brittle | Missing runtime checkout is a reportable status, not a failure. Existing but mismatched checkout is a failure. |
| Shellcheck target references non-files | Shell lint input list must include only existing shell script paths/globs under `docs/orchestra/scripts/`. |

## Validation Architecture

Use existing Bash smoke tests plus Make targets as the validation layer.

Required verification commands after implementation:

```bash
make test-unit
make test-risk
make lint-json
make lint-shell
make upstream-status
bash docs/orchestra/scripts/tests/run-all.sh
! rg -n "test-integration|test-e2e|coverage|release" Makefile
```

The `lint-shell` check must be validated in the current environment where `shellcheck` is absent; expected behavior is an explicit skip message and exit 0.

## Research Complete

Phase 16 can be planned as a single Makefile-focused plan with direct verification against DEV-01 through DEV-04.
