# Gateway Integration Architecture

## Goal

Define how Hermes Orchestra full-system modules integrate with the existing Python Gateway without modifying `scripts/lib/orch_gateway.py` during Sprint 0.

## Integration Mode

- Integration mode: import-and-call Python modules under `scripts/lib/`.
- Runtime owner: `GatewayApp` in `scripts/lib/orch_gateway.py` remains the only HTTP entrypoint.
- Module boundary: new modules expose plain Python classes with small public methods; Gateway owns request validation, persistence, and event emission.
- Execution boundary: no plugin callback system and no separate long-lived sidecar process in Sprint 0.

## Existing Gateway Integration Points

The current Gateway already exposes the seams later sprints need:

1. `GatewayApp.capabilities()` publishes config references and runtime capability metadata.
2. `GatewayApp.config_items(relative_path, key)` is the existing config-loading helper for debate registries.
3. `GatewayApp.validate_worker_pairing(options)` shows the current pattern for availability checks and clear validation errors.

These points imply that new modules should be called from Gateway methods, not from standalone CLIs or background daemons.

## Configuration Routing

- Default runtime path remains MVP until explicit cutover:
  - `config/debate/teams.json`
  - `config/debate/modes.json`
  - `config/workers/backends.json`
  - `config/workers/roles.json`
- Full-target packages are staged under `*/full/` and are opt-in only:
  - `config/debate/full/*.json`
  - `config/workers/full/*.json`
  - `config/release/*.json`
  - `config/knowledge/*.json`
- Routing rule:
  - Gateway default uses MVP registries.
  - Full-family modules may load `*/full/` config only when the caller explicitly selects the full package and the module passes feature-flag checks.
  - `config/cutover/full-readiness-gates.json` remains the source of truth for staged-vs-active policy.
  - `config/cutover/runtime-family-activation.json` may activate specific artifact families for default Gateway module dispatch without permitting a one-shot global cutover.

## Feature-Flag Contract

Every new module must enforce both checks before doing real work:

1. `enabled` check
   - If a module or backend config says `enabled: false`, return a clear error such as `module_disabled` or `backend_disabled`.
2. `package_status` check
   - If a full-target config has `package_status != "active"` and the caller did not explicitly allow staged validation/runtime use, return a clear error such as `package_not_active`.
3. Runtime activation override
   - Gateway may treat a staged family as default-runnable only when `config/cutover/runtime-family-activation.json` proves that family has satisfied the required cutover evidence and checks.
   - This override is family-scoped and must preserve mixed-family cutover; inactive families still require explicit `allow_staged`.

Allowed behavior for inactive modules:

- Return a no-op only when the sprint contract explicitly allows degradation.
- Otherwise fail fast with a clear machine-readable error.

## Public Module Interfaces

The module classes below are the contract for implementation sprints. Method names are intentionally small and concrete.

### Sprint 1

`class DebateEngine`

- `__init__(repo_root: Path, package_root: str = "config/debate/full", allow_staged: bool = False, enabled: bool = True) -> None`
- `load_registries() -> dict[str, Any]`
- `create_run(question: str, mode_id: str, selected_member_ids: list[str] | None = None, metadata: dict[str, Any] | None = None) -> dict[str, Any]`

### Sprint 2

`class DebateAssembly`

- `__init__(repo_root: Path, package_root: str = "config/debate/full", allow_staged: bool = False) -> None`
- `load_policy() -> dict[str, Any]`
- `select_for_stage(stage: str, task_type: str, risk_level: str, project_overrides: dict[str, Any] | None = None) -> dict[str, Any]`

### Sprint 3

`class DebateMemberInvoker`

- `__init__(backend_adapter: "DebateBackendAdapter") -> None`
- `build_invocation(member_id: str, question: str, input_refs: list[str], context: dict[str, Any]) -> dict[str, Any]`
- `invoke(invocation: dict[str, Any]) -> dict[str, Any]`

`class DebateBackendAdapter`

- `__init__(repo_root: Path, package_root: str = "config/debate/full", allow_staged: bool = False) -> None`
- `resolve_backend(backend_id: str) -> dict[str, Any]`
- `invoke(invocation: dict[str, Any]) -> dict[str, Any]`

`class DebateReportBuilder`

- `create_report(run_id: str, mode_id: str, opinions: list[dict[str, Any]], degraded: bool = False) -> dict[str, Any]`

### Sprint 4

`class WorkerRegistry`

- `__init__(repo_root: Path, package_root: str = "config/workers/full", allow_staged: bool = False) -> None`
- `load_backends() -> dict[str, Any]`
- `load_roles() -> dict[str, Any]`

`class CapabilityNegotiator`

- `__init__(registry: WorkerRegistry) -> None`
- `negotiate(role: str, requested_backend: str | None = None, required_capabilities: list[str] | None = None) -> dict[str, Any]`

### Sprint 5

`class WorkerSessionManager`

- `create_session(run_id: str, task_id: str, backend_id: str) -> dict[str, Any]`
- `transition(session_id: str, next_state: str, details: dict[str, Any] | None = None) -> dict[str, Any]`

`class WorkerSessionSweeper`

- `sweep(now: datetime | None = None) -> dict[str, Any]`

### Sprint 6

`class ReleasePipeline`

- `__init__(repo_root: Path, allow_staged: bool = False) -> None`
- `plan(environment: str) -> dict[str, Any]`
- `validate_command_refs() -> dict[str, Any]`

`class ReleaseExecutor`

- `execute(command_ref: str, approval_ref: str | None = None) -> dict[str, Any]`

### Sprint 7

`class RuntimeKnowledgeBase`

- `__init__(repo_root: Path, allow_staged: bool = False) -> None`
- `query(request: dict[str, Any]) -> dict[str, Any]`

`class KnowledgeIngestion`

- `ingest(entry: dict[str, Any]) -> dict[str, Any]`

### Sprint 8

`class SelfEvolutionQueue`

- `enqueue(proposal: dict[str, Any]) -> dict[str, Any]`
- `list_pending() -> list[dict[str, Any]]`

`class PerformanceBudgetPolicy`

- `evaluate(component_id: str, observed: dict[str, Any]) -> dict[str, Any]`

### Sprint 9

`class FixturePolicy`

- `classify(source_ref: str) -> dict[str, Any]`

`class DegradationPolicy`

- `evaluate(evidence: dict[str, Any]) -> dict[str, Any]`

### Sprint 10

`class IdempotencyArchive`

- `record(command_id: str, payload: dict[str, Any]) -> dict[str, Any]`
- `fetch(idempotency_key: str) -> dict[str, Any] | None`

`class FullSchemaCutover`

- `evaluate_family(family_id: str) -> dict[str, Any]`
- `can_activate(family_id: str) -> dict[str, Any]`

## Call Pattern

- Gateway receives HTTP request.
- Gateway validates request shape and authority rules.
- Gateway instantiates the module class with `repo_root`.
- Module loads config through repository paths and enforces `enabled` / `package_status`.
- Module returns structured Python dictionaries.
- Gateway persists artifacts and events.

## Authority Trust Boundary

- Phase 1 trust model: localhost-only.
- The default Gateway deployment binds to `127.0.0.1`, and the local loopback boundary is the only trust boundary assumed for Sprint 11 module endpoints.
- Non-loopback `--host` values are rejected unless the operator also passes `--allow-network-binding`.
- The `authority` field on `/orchestra/modules/*` requests is an intent selector within that loopback boundary, not standalone remote authentication.
- If Gateway is ever exposed beyond localhost, the module endpoints must gain an additional authentication layer such as a token check, Unix socket permission boundary, or mTLS before the `authority` field can be trusted.

## Non-Goals for Sprint 0

- No Gateway refactor.
- No automatic full-package activation.
- No separate process supervisor for debate, worker, release, or knowledge modules.
