# Sprint 1 Plan

**总故事点**: 7 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U1 | Extend runtime-family activation to the three target families | 2 | - | ⬜ |
| 2 | U2 | Cut over the Debate Engine default runtime path | 5 | U1 | ⬜ |

## 详细说明

### Task 1 (U1): Extend runtime-family activation to the three target families

- **目标**: Make debate, worker execution, and runtime knowledge eligible for default runtime activation through the existing mixed-family cutover substrate.
- **验收标准**: Default runtime activation reports `full_debate_package`, `worker_execution`, and `runtime_domain_knowledge` as active families.; Gateway module defaulting no longer requires explicit `allow_staged=True` for the three target families.
- **涉及文件**: Modify: `scripts/lib/runtime_activation.py`, Modify: `config/cutover/runtime-family-activation.json`, Modify: `scripts/tests/test-runtime-activation.sh`, Modify: `scripts/tests/test-gateway-integration-points.sh`

### Task 2 (U2): Cut over the Debate Engine default runtime path

- **目标**: Switch debate runtime behavior from staged-only full package consumption to active default-path consumption while preserving full debate evidence and audit behavior.
- **验收标准**: Debate runtime tests pass with default runtime behavior and without explicit `allow_staged=True` for normal success cases.; Debate report and audit artifacts preserve member/opinion/backend/degradation evidence on the default path.
- **涉及文件**: Modify: `config/debate/full/teams.json`, Modify: `config/debate/full/modes.json`, Modify: `config/debate/full/coverage-policy.json`, Modify: `config/debate/full/assembly-policy.json`, Modify: `config/debate/full/backend-policy.json`, Modify: `scripts/lib/debate_engine.py`, Modify: `scripts/lib/debate_assembly.py`, Modify: `scripts/lib/debate_member_invocation.py`, Modify: `scripts/lib/debate_report.py`, Modify: `scripts/lib/orch_gateway.py`, Modify: `scripts/tests/test-debate-assembly.sh`, Modify: `scripts/tests/test-debate-member-invocation.sh`, Modify: `scripts/tests/test-debate-engine-ai.sh`, Modify: `scripts/tests/test-e2e-ai-debate-flow.sh`

