# Sprint 3 Plan

**总故事点**: 7 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U4 | Integrate worker session lifecycle and parallel execution on the default runtime path | 5 | U3 | ⬜ |
| 2 | U6 | Re-baseline validation, matrices, and completion reporting | 2 | U2, U4, U5 | ⬜ |

## 详细说明

### Task 1 (U4): Integrate worker session lifecycle and parallel execution on the default runtime path

- **目标**: Route worker session records, cleanup, parallel planning, and conflict handling through the default runtime path and prove the Gateway consumes them in real runs.
- **验收标准**: Worker session lifecycle and output gating tests pass through default runtime behavior.; Parallel integration and cleanup behavior are covered by real-path Gateway tests instead of staged-only fixtures.
- **涉及文件**: Modify: `scripts/lib/worker_session.py`, Modify: `scripts/lib/worker_session_sweeper.py`, Modify: `scripts/lib/orch_gateway.py`, Modify: `scripts/tests/test-worker-session.sh`, Modify: `scripts/tests/test-worker-lifecycle-timeout.sh`, Modify: `scripts/tests/test-e2e-ai-worker-flow.sh`, Modify: `scripts/tests/test-gateway-worker-output-write-scope-violation.sh`, Modify: `scripts/tests/test-gateway-worker-output-complete-task.sh`, Modify: `scripts/tests/test-gateway-capabilities-authority-layers.sh`

### Task 2 (U6): Re-baseline validation, matrices, and completion reporting

- **目标**: Update the project’s authoritative validation and documentation artifacts so they match the new active runtime reality and capture remaining risk.
- **验收标准**: Gap analysis and full coverage matrix align with runtime activation, config status, and passing real-path tests.; A completion report exists with debate, worker, runtime-knowledge evidence and residual-risk sections.
- **涉及文件**: Modify: `IMPLEMENTATION-GAP-ANALYSIS.md`, Modify: `docs/FULL-COVERAGE-MATRIX.md`, Modify: `docs/execution-checklist.md`, Create: `docs/full-system-cutover-debate-worker-runtime-knowledge-report.md`, Modify: `scripts/tests/test-gateway-config-registries.sh`, Modify: `scripts/tests/test-runtime-activation.sh`

