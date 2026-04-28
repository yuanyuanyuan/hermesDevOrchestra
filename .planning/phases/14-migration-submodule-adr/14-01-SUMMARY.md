---
phase: 14-migration-submodule-adr
plan: "01"
subsystem: docs
tags: [migration, upstream-pin, adr, bash, hermes-agent]
requires:
  - phase: 13-evidence-audit-and-discoverability
    provides: old-path evidence inventory and repository status baseline
provides:
  - migrated Dev Orchestra package path at docs/orchestra
  - repo-local upstream Hermes Agent JSON manifest pin
  - ADR-001 accepted manifest pin decision
  - active-vs-historical old-path audit result
affects: [phase-15-specification-system, phase-16-makefile-dev-workflow, docs, planning]
tech-stack:
  added: []
  patterns:
    - active references use docs/orchestra while historical planning artifacts remain audit-only
    - upstream pins are recorded in repo-local JSON for future workflow tooling
key-files:
  created:
    - docs/orchestra/README.md
    - docs/orchestra/WORKFLOW.md
    - .planning/upstream/hermes-agent-pin.json
    - .planning/adr/ADR-001-upstream-pin.md
  modified:
    - README.md
    - AGENTS.md
    - docs/COVERAGE-MATRIX.md
    - .planning/PROJECT.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/DIRECTION-CORRECTION.md
    - docs/orchestra/scripts/tests/*.sh
key-decisions:
  - "Move the active Dev Orchestra package from docs/hermes-dev-orchestra to docs/orchestra without a compatibility shim."
  - "Use .planning/upstream/hermes-agent-pin.json as the machine-readable upstream pin."
  - "Accept manifest pin and reject git submodule for v1.2 because this repository is an adapter layer."
patterns-established:
  - "Use strict active old-path gates and separate broad historical grep results as audit-only residuals."
  - "Future upstream-status tooling should read /pin/commit and /pin/observed_version from the manifest."
requirements-completed:
  - MIGR-02
  - UPST-01
  - UPST-02
duration: 4 min
completed: 2026-04-28
---

# Phase 14 Plan 01: Migration and Upstream Pin ADR Summary

**Dev Orchestra package moved to `docs/orchestra`, with a JSON upstream pin manifest and accepted ADR rejecting submodule adoption.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-28T10:07:08Z
- **Completed:** 2026-04-28T10:10:45Z
- **Tasks:** 3 completed
- **Files modified:** 44 including renamed package files, active path references, manifest, ADR, and this summary

## Accomplishments

- Moved the tracked package tree from `docs/hermes-dev-orchestra/` to `docs/orchestra/` with the required `git mv -n` dry run and real `git mv`.
- Updated active references in root docs, active planning docs, package docs, coverage matrix, and migrated smoke tests to `docs/orchestra`.
- Created `.planning/upstream/hermes-agent-pin.json` with upstream commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`, observed version `Hermes Agent v0.11.0 (2026.4.23)`, probe commands, update procedure, and Phase 16 JSON pointer contract.
- Created `.planning/adr/ADR-001-upstream-pin.md`, comparing `installer/probe pin`, `git submodule`, `manifest pin`, and `vendor snapshot`, and accepting `manifest pin`.
- Verified `UPST-02 is not applicable because manifest pin is selected and git submodule is not selected.`

## Task Commits

Each task was committed atomically:

1. **Task 1: Move package directory and update active path references** - `0b422e9` (`docs(14-01): migrate orchestra package path`)
2. **Task 2: Create upstream pin manifest and ADR** - `c3ee50e` (`docs(14-01): record upstream manifest pin decision`)
3. **Task 3: Run final verification and write execution summary** - this SUMMARY commit

## Files Created/Modified

- `docs/orchestra/README.md` - Moved reader-facing product behavior baseline.
- `docs/orchestra/WORKFLOW.md` - Moved installation and usage guide with `docs/orchestra/scripts/setup.sh`.
- `docs/orchestra/scripts/tests/*.sh` - Migrated smoke tests now call helpers under `docs/orchestra/scripts`.
- `.planning/upstream/hermes-agent-pin.json` - Machine-readable upstream Hermes Agent pin.
- `.planning/adr/ADR-001-upstream-pin.md` - Accepted upstream pin strategy ADR.
- `README.md`, `AGENTS.md`, `docs/COVERAGE-MATRIX.md`, `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/DIRECTION-CORRECTION.md` - Active path references updated to `docs/orchestra`.

## Decisions Made

- No compatibility shim, duplicate directory, symlink, or supported pointer remains at `docs/hermes-dev-orchestra/`.
- Historical planning artifacts were not rewritten to satisfy the active path gate; they remain audit evidence.
- Manifest pin is the selected v1.2 upstream strategy; git submodule and vendor snapshot are rejected.
- No `.gitmodules` file or gitlink mode `160000` was introduced.

## Verification

```text
git status --short --branch
=> ## main

git mv -n docs/hermes-dev-orchestra docs/orchestra
=> exit 0; dry-run listed 33 tracked files moving to docs/orchestra

git mv docs/hermes-dev-orchestra docs/orchestra
=> exit 0

! rg -n "docs/hermes-dev-orchestra" README.md AGENTS.md CLAUDE.md docs .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/DIRECTION-CORRECTION.md
=> exit 0; no active old-path matches

while IFS= read -r f; do bash -n "$f"; done < <(find docs/orchestra/scripts -type f \( -name "*.sh" -o -path "*/scripts/bin/orch-*" \) -print | sort)
=> exit 0

python3 -m json.tool .planning/upstream/hermes-agent-pin.json >/dev/null
=> exit 0

bash docs/orchestra/scripts/tests/run-all.sh
=> Smoke summary: 9 passed, 0 failed

ADR option and UPST-02 grep checks
=> exit 0 for installer/probe pin, git submodule, manifest pin, vendor snapshot, UPST-02, not applicable

test ! -f .gitmodules
=> exit 0

! git ls-files --stage | grep -q '^160000 '
=> exit 0

git status --short --branch
=> ## main
```

## Old Path Residual Review

The broad audit command was run exactly as an audit-only residual review:

```bash
rg --hidden -n "docs/hermes-dev-orchestra" --glob '!/.git/*' --glob '!*.zip' || true
```

Result summary:

- `1596 matches`
- `1290 matched lines`
- `82 files contained matches`
- `185 files searched`

Residual categories are historical or planning-only:

- `task_phase13_hermes_chat.md` transcript.
- v1.0 milestone archives under `.planning/milestones/`.
- v1.1 and earlier phase plans, research, summaries, reviews, validations, and verification artifacts under `.planning/phases/08-*` through `.planning/phases/13-*`.
- Phase 14 planning inputs (`14-01-PLAN.md`, `14-CONTEXT.md`, `14-RESEARCH.md`, `14-VALIDATION.md`, `14-PATTERNS.md`, `14-DISCUSSION-LOG.md`) that intentionally describe the migration from the old path.
- backlog artifacts under `.planning/phases/999.*`.

The strict active gate excludes these historical artifacts by design and returned no matches.

## Worktree Status and Backlog Changes

The plan warned to preserve possible unrelated `999.x` backlog changes. At actual execution start, `git status --short --branch` returned only:

```text
## main
```

No unrelated `.planning/phases/999.*` changes were present to stage during this run, and no `999.x` files appear in the Phase 14 commits.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `gsd-sdk query` was unavailable in this environment, so execute-phase bookkeeping commands were performed manually from `.planning/` artifacts while preserving the same gates and checks.
- `git diff --cached` represented `test-risk-check.sh` as delete plus add instead of a high-similarity rename because the path literal changes were dense in that short file. The final tracked file exists at `docs/orchestra/scripts/tests/test-risk-check.sh`, has executable mode, and the smoke runner passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 15 can build the specification system against `docs/orchestra/` as the active package path. Phase 16 can consume `.planning/upstream/hermes-agent-pin.json` for `make upstream-status` using `/pin/commit` and `/pin/observed_version`.

## Self-Check: PASSED

- `docs/orchestra/README.md` exists.
- `docs/hermes-dev-orchestra/README.md` does not exist as a tracked working-tree path.
- Strict active old-path gate passed.
- Migrated shell syntax checks passed.
- Smoke runner passed with `9 passed, 0 failed`.
- Manifest JSON validation passed and contains commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3`.
- ADR compares all four required strategies and states UPST-02 is not applicable.
- `.gitmodules` is absent and no gitlink mode `160000` is tracked.

---
*Phase: 14-migration-submodule-adr*
*Completed: 2026-04-28*
