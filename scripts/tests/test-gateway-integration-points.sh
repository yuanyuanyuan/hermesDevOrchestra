#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gateway-integration-points"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

DOC="$REPO_ROOT/docs/gateway-integration-architecture.md"
GATEWAY="$REPO_ROOT/scripts/lib/orch_gateway.py"

assert_file_exists "$DOC" "gateway integration architecture document missing"
assert_file_exists "$GATEWAY" "orch_gateway.py missing"
assert_file_exists "$REPO_ROOT/config/debate/teams.json" "MVP debate teams config missing"
assert_file_exists "$REPO_ROOT/config/debate/modes.json" "MVP debate modes config missing"
assert_file_exists "$REPO_ROOT/config/workers/backends.json" "MVP worker backends config missing"
assert_file_exists "$REPO_ROOT/config/workers/roles.json" "MVP worker roles config missing"
assert_file_exists "$REPO_ROOT/config/debate/full/teams.json" "full debate teams config missing"
assert_file_exists "$REPO_ROOT/config/debate/full/modes.json" "full debate modes config missing"
assert_file_exists "$REPO_ROOT/config/workers/full/backends.json" "full worker backends config missing"
assert_file_exists "$REPO_ROOT/config/workers/full/roles.json" "full worker roles config missing"
assert_file_exists "$REPO_ROOT/config/cutover/full-readiness-gates.json" "full cutover gates config missing"

assert_contains "## Integration Mode" "$DOC" "integration mode section missing"
assert_contains "import-and-call Python modules" "$DOC" "integration mode is undefined"
assert_contains "no plugin callback system" "$DOC" "plugin callback exclusion is undefined"
assert_contains "no separate long-lived sidecar process" "$DOC" "process separation decision is undefined"
assert_contains "GatewayApp.capabilities()" "$DOC" "capabilities integration point missing"
assert_contains "GatewayApp.config_items(relative_path, key)" "$DOC" "config_items integration point missing"
assert_contains "GatewayApp.validate_worker_pairing(options)" "$DOC" "validation integration point missing"
assert_contains "Gateway methods" "$DOC" "module call pattern is undefined"
assert_contains "Gateway default uses MVP registries." "$DOC" "default MVP routing is undefined"
assert_contains "Full-family modules may load" "$DOC" "full package routing rule is undefined"
assert_contains "config/cutover/full-readiness-gates.json" "$DOC" "cutover routing source missing"
assert_contains "enabled" "$DOC" "enabled flag contract missing"
assert_contains "package_status" "$DOC" "package_status contract missing"
assert_contains "module_disabled" "$DOC" "module disabled failure contract missing"
assert_contains "backend_disabled" "$DOC" "backend disabled failure contract missing"
assert_contains "package_not_active" "$DOC" "package status failure contract missing"

assert_contains "class DebateEngine" "$DOC" "Sprint 1 API contract missing"
assert_contains "class DebateAssembly" "$DOC" "Sprint 2 API contract missing"
assert_contains "class DebateMemberInvoker" "$DOC" "Sprint 3 invoker API contract missing"
assert_contains "class DebateBackendAdapter" "$DOC" "Sprint 3 backend API contract missing"
assert_contains "class DebateReportBuilder" "$DOC" "Sprint 3 report API contract missing"
assert_contains "class WorkerRegistry" "$DOC" "Sprint 4 registry API contract missing"
assert_contains "class CapabilityNegotiator" "$DOC" "Sprint 4 negotiation API contract missing"
assert_contains "class WorkerSessionManager" "$DOC" "Sprint 5 session API contract missing"
assert_contains "class WorkerSessionSweeper" "$DOC" "Sprint 5 sweeper API contract missing"
assert_contains "class ReleasePipeline" "$DOC" "Sprint 6 release pipeline API contract missing"
assert_contains "class ReleaseExecutor" "$DOC" "Sprint 6 release executor API contract missing"
assert_contains "class RuntimeKnowledgeBase" "$DOC" "Sprint 7 runtime knowledge API contract missing"
assert_contains "class KnowledgeIngestion" "$DOC" "Sprint 7 ingestion API contract missing"
assert_contains "class SelfEvolutionQueue" "$DOC" "Sprint 8 self-evolution API contract missing"
assert_contains "class PerformanceBudgetPolicy" "$DOC" "Sprint 8 performance API contract missing"
assert_contains "class FixturePolicy" "$DOC" "Sprint 9 fixture API contract missing"
assert_contains "class DegradationPolicy" "$DOC" "Sprint 9 degradation API contract missing"
assert_contains "class IdempotencyArchive" "$DOC" "Sprint 10 idempotency API contract missing"
assert_contains "class FullSchemaCutover" "$DOC" "Sprint 10 cutover API contract missing"

python3 - "$GATEWAY" <<'PY'
import pathlib
import sys

gateway = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
required_snippets = [
    "def capabilities(self) -> dict[str, Any]:",
    "def config_items(self, relative_path: str, key: str) -> list[Any]:",
    "def validate_worker_pairing(self, options: Any) -> tuple[int, dict[str, Any]] | None:",
    '"teams_config_ref": "config/debate/teams.json"',
    '"modes_config_ref": "config/debate/modes.json"',
]
for snippet in required_snippets:
    assert snippet in gateway, snippet
PY

python3 - "$DOC" <<'PY'
import pathlib
import sys

doc = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
required_signatures = [
    "`__init__(repo_root: Path, package_root: str = \"config/debate/full\", allow_staged: bool = False, enabled: bool = True) -> None`",
    "`load_registries() -> dict[str, Any]`",
    "`create_run(question: str, mode_id: str, selected_member_ids: list[str] | None = None, metadata: dict[str, Any] | None = None) -> dict[str, Any]`",
    "`__init__(repo_root: Path, package_root: str = \"config/debate/full\", allow_staged: bool = False) -> None`",
    "`load_policy() -> dict[str, Any]`",
    "`select_for_stage(stage: str, task_type: str, risk_level: str, project_overrides: dict[str, Any] | None = None) -> dict[str, Any]`",
    "`build_invocation(member_id: str, question: str, input_refs: list[str], context: dict[str, Any]) -> dict[str, Any]`",
    "`invoke(invocation: dict[str, Any]) -> dict[str, Any]`",
    "`resolve_backend(backend_id: str) -> dict[str, Any]`",
    "`create_report(run_id: str, mode_id: str, opinions: list[dict[str, Any]], degraded: bool = False) -> dict[str, Any]`",
    "`load_backends() -> dict[str, Any]`",
    "`load_roles() -> dict[str, Any]`",
    "`negotiate(role: str, requested_backend: str | None = None, required_capabilities: list[str] | None = None) -> dict[str, Any]`",
    "`create_session(run_id: str, task_id: str, backend_id: str) -> dict[str, Any]`",
    "`transition(session_id: str, next_state: str, details: dict[str, Any] | None = None) -> dict[str, Any]`",
    "`sweep(now: datetime | None = None) -> dict[str, Any]`",
    "`plan(environment: str) -> dict[str, Any]`",
    "`validate_command_refs() -> dict[str, Any]`",
    "`execute(command_ref: str, approval_ref: str | None = None) -> dict[str, Any]`",
    "`query(request: dict[str, Any]) -> dict[str, Any]`",
    "`ingest(entry: dict[str, Any]) -> dict[str, Any]`",
    "`enqueue(proposal: dict[str, Any]) -> dict[str, Any]`",
    "`list_pending() -> list[dict[str, Any]]`",
    "`evaluate(component_id: str, observed: dict[str, Any]) -> dict[str, Any]`",
    "`classify(source_ref: str) -> dict[str, Any]`",
    "`evaluate(evidence: dict[str, Any]) -> dict[str, Any]`",
    "`record(command_id: str, payload: dict[str, Any]) -> dict[str, Any]`",
    "`fetch(idempotency_key: str) -> dict[str, Any] | None`",
    "`evaluate_family(family_id: str) -> dict[str, Any]`",
    "`can_activate(family_id: str) -> dict[str, Any]`",
]
for snippet in required_signatures:
    assert snippet in doc, snippet
PY

test_done
