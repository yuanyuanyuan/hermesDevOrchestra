---
title: Worker advancement evidence gate — Sprint 8 hardening review-fixer blindspot
date: 2026-06-07
category: security
module: worker-evidence-harden
problem_type: defense_in_depth
component: gateway
symptoms:
  - "Dormant gate: `validate_worker_advancement` not invoked from `orch_gateway.submit_worker_output` despite Sprint 8 plan listing it as the consumer of write scope, DAG, review, and commit evidence."
  - "Path traversal via `lstrip('./')` character-set semantics: `lstrip` consumes any combination of `.` and `/` from the left, leaving residual bypasses like `../foo` after normalization."
  - "Sentinel collision: the `__invalid_path__` string itself could be used as a scope value and matched against paths that normalized to the same sentinel."
  - "Stage spoofing via case/whitespace: `current_stage='Implementation'` or `'impl'` or `'implementation '` silently bypasses set-membership gates because canonical form is never applied."
  - "DAG truthiness bypass: `if result_valid is False` rejects only the exact boolean `False`, allowing `valid=0`, `valid=''`, `valid=None`, `valid=[]` to pass."
  - "DAG errors-list ignored when `valid=True`: a result with `passed=True, errors=['cycle_detected']` is accepted because errors are only inspected inside the `not valid` branch."
  - "Empty-scope cascade: when `current_stage` and `expected_scope` are both empty, every validator returns early and 0 errors are emitted, enabling complete unverified stage advancement."
  - "Wire-up I/O race: `read_json(run_path)` inside the new evidence gate chain lacks try/except, so a corrupt run.json turns the new gate into a 500 instead of a `worker_advancement_evidence_invalid` block."
root_cause: review_fixer_blindspot
resolution_type: code_fix
severity: high
related_components:
  - worker-evidence-harden
  - orch_gateway
  - dag_validator
  - run_lifecycle
tags:
  - worker-advancement-evidence
  - sprint-8
  - fail-closed
  - path-traversal
  - sentinel-collision
  - stage-spoofing
  - dag-schema-drift
---

# Worker advancement evidence gate (Sprint 8)

## Problem

PR #41 (`feat/sprint8-evidence-hardening`) added a worker-output advancement
evidence validator, but five rounds of self-review + multi-agent review
surfaced a recurring "review-fixer blindspot" pattern: each round closed the
cited finding, but the surrounding call graph, error envelope, and schema
contracts continued to contain latent bypasses that the next round caught.

The most consequential blindspot was the **dormant gate** — the validator was
authored as a library + CLI, but `orch_gateway.submit_worker_output` never
called it. Sprint 8's success criterion ("Make Gateway consume computed write
scope, actual changes, DAG validation, review evidence, and commit evidence
before stage advancement") was unmet until commit `7d7d431` wired the gate
into the production path. Until then, the validator's "fail-closed" promise
applied only to its test shell, not to real stage advancement.

## Resolution

The Sprint 8 hardening applied the following layered fixes:

1. **Dormant gate wire-up** (commit `7d7d431`):
   `submit_worker_output` in `scripts/lib/orch_gateway.py` now invokes
   `worker_advancement_evidence_violations` after the existing five
   pre-validators, before `open_high_conflict_ids` and `accept_worker_output`.
2. **Wire-up I/O hardening** (this PR round):
   `read_json(run_path)` is wrapped in `try/except (OSError, json.JSONDecodeError)`
   so a corrupt run.json returns `run_artifact_invalid` instead of a 500.
3. **Defensive inner guard**:
   `worker_advancement_evidence_violations` itself wraps
   `validate_worker_advancement` in `try/except (TypeError, AttributeError)` to
   surface unexpected exceptions as `invalid_evidence_input: <ExcType>: <msg>`
   error strings.
4. **Path normalization hardening**: `lstrip('./')` replaced with
   `PurePosixPath`-based pre-normalization traversal checks
   (`scripts/lib/worker_evidence_harden.py:_normalize_relative_path`).
5. **Sentinel collision fix**: `__invalid_path__` is no longer a public
   string sentinel; `_normalize_relative_path` returns `None` for unsafe
   paths, and `_normalize_scope_path` raises
   `InvalidEvidenceInputError` for `..` / absolute / empty scope entries.
6. **Stage canonicalization**: every `validate_*_evidence` function calls
   `_canonical_stage(stage)` (strips + lowercases) before set-membership
   checks; unknown stages now emit `unknown_stage: <value>`.
7. **DAG truthiness fix**: `if result_valid is False` replaced with
   `if not bool(result_valid) or errors:` so `valid=0`, `valid=""`,
   `valid=None`, and `valid=[]` all block correctly.
8. **Errors-list inspection always-on**: `dag_validation_result.get("errors")`
   is read at the top of the function (not inside the `not valid` branch), so
   `{'passed': True, 'errors': ['orphan_task']}` is now correctly blocked.
9. **Single source of truth for stage requirements**: `STAGE_REQUIREMENTS`
   dict drives `DAG_VALIDATION_STAGES`, `REVIEW_EVIDENCE_STAGES`,
   `COMMIT_EVIDENCE_STAGES`, `SCOPE_REQUIRED_STAGES`, and `KNOWN_STAGES`
   via set comprehension.
10. **Mixed-schema DAG acceptance**: `validate_dag_evidence` accepts both the
    local schema (`cycles`/`valid`) and the production `dag_validator`
    schema (`back_edges`/`cycle_detected`/`passed`); Test 25 was updated to
    use the production `list[dict[str, str]]` shape.

## Lesson

A single-pass review on a security hardening PR is not enough. Each fix
introduces new assumptions about the surrounding code; the next review must
trace those assumptions through the call graph, error envelope, and schema
contract. The "review-fixer blindspot" pattern is the natural failure mode
of single-perspective review — multi-agent adversarial + correctness review
panels (as used by `ce-code-review` mode) catch the regressions that single
reviewers miss.

For future hardening PRs:

- Always run at least one **adversarial reviewer** whose prompt is "try to
  break the fix, do not re-validate the cited code."
- Always verify the **caller** path: `grep -rn '<new_module>' scripts/lib/*.py`
  before declaring the fix complete.
- Treat the **error envelope** as part of the contract: any catch/return
  boundary must round-trip structured fields, not just stringify them.
- Treat **schema drift** between caller and callee as a first-class finding,
  not a doc nit.

## Reuse Pattern

Apply the same pattern to any future "evidence gate" or "fail-closed
validator" added to `orch_gateway.py`:

1. Wire-up first, library second.
2. Wrap caller I/O in `try/except (OSError, json.JSONDecodeError)`.
3. Wrap callee entry in `try/except (TypeError, AttributeError)`.
4. Canonicalize all string-keyed enums (stages, statuses) at the entry.
5. Use `bool(...)` for any `if not <result>` check that crosses a
   JSON-decoded boundary (where `False`, `0`, `""`, `None`, `[]` must all
   be treated identically).
6. Inspect structured error lists unconditionally, not inside the
   `not valid` branch.
7. Document the dual-schema acceptance in the docstring and pin it with
   a mixed-shape test.
