# Full-System Cutover Report

Date: 2026-05-21

Scope: debate, worker, runtime-knowledge cutover evidence for `full-system-cutover-debate-worker-runtime-knowledge`

## Summary

The repo now has mixed-family default-runtime evidence for debate, worker, and runtime-knowledge module paths on representative Gateway flows. This closes Sprint 14 scope for `U4` and `U6`, and also brings Sprint 2 `U5` onto the active default path.

What changed in practical terms:

- Debate representative flow still passes on the mixed-family default path.
- Worker negotiation no longer needs caller-side `allow_staged`, and Gateway now persists run-scoped worker session records.
- Worker output handling now emits mechanical parallel artifacts and blocks mechanical merge conflicts.
- Runtime knowledge is now explicitly deferred; default runtime no longer treats it as an active family.

## Debate Evidence

- `scripts/tests/test-runtime-activation.sh`: PASS
  - Confirms `full_debate_package` is present in `runtime_activation.active_family_ids`.
  - Confirms `runtime_activation.module_defaults["debate-engine"] == "full_debate_package"`.
- `scripts/tests/test-e2e-ai-debate-flow.sh`: PASS
  - Provides representative Gateway run evidence that debate flow works on the current default path.

## Worker Evidence

- `scripts/tests/test-runtime-activation.sh`: PASS
  - Confirms `worker_execution` is present in `runtime_activation.active_family_ids`.
  - Confirms `runtime_activation.module_defaults["worker-registry"] == "worker_execution"`.
- `scripts/tests/test-worker-session.sh`: PASS
  - Validates `worker_session_record` creation, transitions, and sweeper behavior.
- `scripts/tests/test-worker-lifecycle-timeout.sh`: PASS
  - Confirms timeout reclaim and cleanup behavior on the worker lifecycle path.
- `scripts/tests/test-e2e-ai-worker-flow.sh`: PASS
  - Removes caller-side `allow_staged` from capability negotiation.
  - Verifies Gateway persists run-scoped worker session records under `state://runs/<run_id>/worker-sessions/...`.
  - Verifies Gateway emits `parallel_group_plan` and `conflict_scan` on the success path.
  - Verifies Gateway emits `merge_conflict_report` and blocks the worker output on a same-run mechanical conflict path.
- `scripts/tests/test-gateway-worker-output-complete-task.sh`: PASS
- `scripts/tests/test-gateway-worker-output-write-scope-violation.sh`: PASS
- `scripts/tests/test-gateway-capabilities-authority-layers.sh`: PASS
- `scripts/tests/test-worker-registry.sh`: PASS
- `scripts/tests/test-gateway-worker-registry.sh`: PASS

## Runtime-Knowledge Evidence

- `config/knowledge/runtime-kb.json`
  - Repo truth is now `enabled: false`.
  - `backend.id` is `deferred`, so the runtime does not connect gbrain.
- `scripts/tests/test-runtime-activation.sh`: PASS
  - Confirms `runtime_domain_knowledge` is not listed in `runtime_activation.active_family_ids`.
  - Confirms `runtime_activation.module_defaults` does not include `runtime-knowledge`.
- `scripts/tests/test-runtime-knowledge.sh`: PASS
  - Confirms default-path runtime-knowledge ingestion/query return `module_disabled`.
  - Confirms explicit state-store repo config still supports schema-valid ingest/query behavior for future adapter work.
- `scripts/tests/test-gateway-config-registries.sh`: PASS
  - Confirms the runtime-knowledge config registry is present and deferred.

## Residual Risks

- Mixed-family module defaults still do not equal run-level full artifact authority cutover.
- Worker parallel integration is only mechanically implemented today:
  - `parallel_group_plan`
  - `conflict_scan`
  - `merge_conflict_report`
  - Deeper serial merge orchestration and semantic compatibility enforcement are still outside this sprint.
- Runtime knowledge remains deferred; it is not final authority for release, remote decision, or closeout actions.
- Release pipeline and remote decision transport remain disabled / unimplemented on the active runtime.

## Conclusion

This cutover slice is now best reported as: debate default-path evidence stable, worker default-path session and mechanical parallel evidence implemented, and runtime knowledge activated on the default repo path. The remaining work is not activation plumbing for these families, but broader run-level full artifact authority cutover across release, remote decision, closeout, and deeper parallel merge behavior.
