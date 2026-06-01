---
title: Gateway fallback contract drift and untestable project discovery regressions
date: 2026-06-01
category: integration-issues
module: gateway-seam-extraction
problem_type: integration_issue
component: tooling
symptoms:
  - "Gateway intake fallback returned `503 + gateway_fallback` on some paths, but `stop_run`, `submit_verdict`, `submit_global_evaluation`, `submit_closeout`, and `submit_failure` could still drop back into normal flow."
  - "Fallback logging could raise a second exception while writing `logs/gateway-fallback.jsonl`, turning a degraded path into a new request failure."
  - "`_evidence_gather()` ran during intake projection, but its output was discarded, so successful helper runs left no intake audit trail."
  - "`orch-init` kept project discovery inside a heredoc, which blocked direct unit tests and let dependency-parsing regressions survive until review."
  - "`scripts/tests/test-project-profile-conflict-resolution.sh` masked real failures with `|| true`."
root_cause: logic_error
resolution_type: code_fix
severity: high
related_components:
  - testing_framework
  - development_workflow
tags:
  - gateway-fallback
  - seam-extraction
  - project-discovery
  - orch-init
  - review-driven-fix
---

# Gateway fallback contract drift and untestable project discovery regressions

## Problem
The first Gateway seam extraction introduced helper-based intake, projection, and evidence gathering, but the fallback contract only stayed correct on the main request path. Follow-up review rounds showed that several write endpoints still ignored fallback return values, intake success had no audit trace, and `orch-init` kept discovery logic trapped inside a shell heredoc that could not be imported or tested directly.

## Symptoms
- Fallback mode produced `503 + gateway_fallback` on some endpoints but not all of them.
- Real HTTP fallback responses were expected to emit `x-gateway-fallback: heuristic`, yet tests did not verify the full contract across every affected endpoint.
- A Python project with `pyproject.toml` dependency entries like `fastapi>=0.100` could miss `FastAPI` detection in project discovery.
- A failing `orch-profile-sync` could still leave `test-project-profile-conflict-resolution.sh` green because the test swallowed the error.

## What Didn't Work
- Earlier review-response rounds fixed the contract one layer at a time: first `503` response wiring, then header mapping, then YAML parsing and version extraction. That closed visible symptoms, but it still left downstream fallback endpoints and intake auditing uncovered (session history).
- Keeping project discovery inside `scripts/bin/orch-init` made every regression test go through the full CLI path. That slowed feedback and hid a real parsing bug in `fastapi>=...` normalization because there was no direct helper-level assertion (session history).
- Seam verification used to rely on partial checks and, earlier in the review chain, even a line-count guard. Those checks did not prove that the helper chain, HTTP header, and every fallback endpoint were still wired correctly (session history).

## Solution
The durable fix combined code extraction, contract tightening, and stronger behavior tests.

1. Harden fallback handling in `scripts/lib/orch_gateway.py`.

   ```python
   evidence = _evidence_gather(projected)
   self._record_intake_trace(request_type, projected, evidence)
   ```

   - Intake success now records `projection_status`, `state_refs`, `evidence_refs`, and degradation metadata to `logs/gateway-intake.jsonl`.
   - `_record_fallback()` now treats log-write failure as best-effort, so a broken fallback log cannot break the request path.
   - `stop_run`, `submit_verdict`, `submit_global_evaluation`, `submit_closeout`, and `submit_failure` now return the same degraded response contract as the original create-run path: `503`, `gateway_fallback`, and `x-gateway-fallback: heuristic`.

2. Extract project discovery into an importable helper module.

   ```python
   sys.path.insert(0, str(package / "scripts" / "lib"))
   from project_discovery import run_discovery
   ```

   - `scripts/lib/project_discovery.py` now owns dependency parsing, framework detection, deploy-target detection, and risk flags.
   - `detect_tech_stack()` normalizes dependency specs before framework matching, so strings such as `fastapi>=0.100` resolve to `FastAPI` with the expected version.
   - `orch-init` stays responsible for orchestration and file emission, not for carrying an embedded copy of discovery logic.

3. Replace weak seam checks with direct contract tests.

   - `scripts/tests/test-gateway-seam-extraction.sh` now asserts:
     - helper-level projection and evidence behavior
     - direct importability of `project_discovery`
     - fallback coverage for all affected write endpoints
     - the real HTTP `x-gateway-fallback: heuristic` header
   - `scripts/tests/test-project-profile-conflict-resolution.sh` no longer uses `|| true`, so profile-sync failures are visible immediately.

## Why This Works
The root problem was not one bad branch; it was hidden coupling. Gateway fallback semantics, intake auditing, and discovery parsing all lived close enough to work in the happy path, but not in a shape that forced complete verification.

Extracting `project_discovery` makes the parsing rules directly testable without booting the whole CLI flow. Routing every helper-backed write endpoint through the same degraded response contract removes the partial-fix problem where only the primary endpoint stayed correct. Recording both fallback failures and successful intake evidence makes degraded behavior observable instead of implicit. Finally, stronger behavior tests catch contract drift at the HTTP layer and at the helper seam, which is exactly where earlier review rounds kept finding missed edges.

## Prevention
- When a new Gateway endpoint depends on intake helpers, add it to the fallback endpoint matrix in `scripts/tests/test-gateway-seam-extraction.sh` before merging.
- Keep reusable logic in `scripts/lib/` modules, not inside shell heredocs, whenever the logic needs direct tests or reuse from more than one script.
- Treat ignored helper return values as a review smell. If a helper returns evidence or metadata, either persist it or make the return type explicit as intentionally disposable.
- Do not suppress command failures inside regression tests with `|| true` unless the test is explicitly asserting the failure path.
- If an ADR describes an incremental seam rather than full migration, keep the tests aligned to behavior and contract coverage instead of indirect size or structure heuristics.

## Related Issues
- [ADR 0010: Gateway Seam Extraction](../../../docs/adr/0010-gateway-seam-extraction.md)
- [Gateway Integration Architecture](../../../docs/gateway-integration-architecture.md)
- PR #17 review-response chain, latest fix commit `9c1c81c057c3d0dbaa660ab160a40ff8e05be2f9`
