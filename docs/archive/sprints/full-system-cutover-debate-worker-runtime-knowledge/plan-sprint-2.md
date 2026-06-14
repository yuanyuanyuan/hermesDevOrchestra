# Sprint 2 Plan

**总故事点**: 7 SP / 7 SP 容量
**任务数**: 2 项

## 任务清单

| # | U-ID | 任务 | SP | 依赖 | 状态 |
|---|------|------|----|------|------|
| 1 | U3 | Cut over worker registry and capability negotiation to the default runtime | 2 | U1 | ⬜ |
| 2 | U5 | Activate gbrain-backed runtime knowledge on the default runtime path | 5 | U1 | ⬜ |

## 详细说明

### Task 1 (U3): Cut over worker registry and capability negotiation to the default runtime

- **目标**: Make the full worker backend/role registries and explicit capability negotiation the default runtime path for worker selection.
- **验收标准**: Default runtime worker selection no longer depends on legacy worker registries or caller-side staged overrides.; Capability negotiation still records checked backends, fallback reasoning, and blocked decisions on the default path.
- **涉及文件**: Modify: `config/workers/full/backends.json`, Modify: `config/workers/full/roles.json`, Modify: `scripts/lib/worker_registry.py`, Modify: `scripts/lib/capability_negotiation.py`, Modify: `scripts/lib/orch_gateway.py`, Modify: `scripts/tests/test-worker-registry.sh`, Modify: `scripts/tests/test-gateway-worker-registry.sh`, Modify: `scripts/tests/test-gateway-integration-points.sh`

### Task 2 (U5): Activate gbrain-backed runtime knowledge on the default runtime path

- **目标**: Enable runtime knowledge retrieval and ingestion as active runtime behavior with enforced freshness, provenance, redaction, and degraded warning-context boundaries.
- **验收标准**: Runtime knowledge and ingestion tests pass on the default runtime path without staged override.; Freshness, provenance, redaction, and human-approval boundaries remain enforced after activation.
- **涉及文件**: Modify: `config/knowledge/runtime-kb.json`, Modify: `scripts/lib/runtime_knowledge.py`, Modify: `scripts/lib/knowledge_ingestion.py`, Modify: `scripts/lib/orch_gateway.py`, Modify: `scripts/tests/test-runtime-knowledge.sh`, Modify: `scripts/tests/test-gateway-integration-points.sh`, Modify: `scripts/tests/test-gateway-global-evaluation-warnings.sh`, Modify: `scripts/tests/test-gateway-mvp-real-acceptance-boundary.sh`

