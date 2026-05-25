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
assert_contains "## Authority Trust Boundary" "$DOC" "authority trust boundary section missing"
assert_contains "Phase 1 trust model: localhost-only." "$DOC" "localhost trust model is undocumented"
assert_contains "not standalone remote authentication" "$DOC" "authority field authentication boundary is undocumented"

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

python3 - "$REPO_ROOT" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from orch_gateway import parse_args

try:
    parse_args(["--project-id", "test-project", "--host", "0.0.0.0"])
except SystemExit as exc:
    assert exc.code == 2, exc.code
else:
    raise AssertionError("expected non-loopback host to be rejected without --allow-network-binding")

allowed = parse_args(["--project-id", "test-project", "--host", "0.0.0.0", "--allow-network-binding"])
assert allowed.host == "0.0.0.0", allowed.host
assert allowed.allow_network_binding is True, allowed.allow_network_binding

localhost = parse_args(["--project-id", "test-project", "--host", "localhost"])
assert localhost.host == "localhost", localhost.host
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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
printf '{"status":"ok"}\n'
SH
chmod +x "$FAKE_BIN/hermes"

cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
printf 'codex 0.0.0\n'
SH
chmod +x "$FAKE_BIN/codex"

cat > "$FAKE_BIN/claude" <<'SH'
#!/usr/bin/env bash
printf 'claude 0.0.0\n'
SH
chmod +x "$FAKE_BIN/claude"

cat > "$FAKE_BIN/project-release" <<'SH'
#!/usr/bin/env bash
printf 'release command stub\n'
SH
chmod +x "$FAKE_BIN/project-release"

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/runtime"
export STATE_ROOT="$TMP_DIR/state"
export AUDIT_ROOT="$TMP_DIR/audit"
export CACHE_ROOT="$TMP_DIR/cache"
mkdir -p "$HOME"

PROJECT_ID="gateway-module-integration"
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q >/dev/null
"$REPO_ROOT/scripts/bin/orch-init" "$PROJECT_ID" "$PROJECT_DIR" >/dev/null

PORT="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
BASE_URL="http://127.0.0.1:$PORT"
GATEWAY_LOG="$TMP_DIR/gateway.log"
"$REPO_ROOT/scripts/bin/orch-gateway" --project-id "$PROJECT_ID" --host 127.0.0.1 --port "$PORT" >"$GATEWAY_LOG" 2>&1 &
GATEWAY_PID="$!"
trap 'kill "$GATEWAY_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

python3 - "$BASE_URL/health" "$GATEWAY_LOG" <<'PY'
import sys
import time
import urllib.request

url, log_path = sys.argv[1:]
deadline = time.time() + 5
last_error = None
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=0.5) as response:
            if response.status == 200:
                raise SystemExit(0)
    except Exception as exc:
        last_error = exc
        time.sleep(0.1)

print(open(log_path, encoding="utf-8", errors="replace").read(), file=sys.stderr)
raise SystemExit(f"gateway did not become healthy: {last_error}")
PY

python3 - "$BASE_URL" "$REPO_ROOT" "$TMP_DIR" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

base_url = sys.argv[1]
repo_root = pathlib.Path(sys.argv[2])
tmp_dir = pathlib.Path(sys.argv[3])


def post(path, body, *, expect_status=200):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            body = json.loads(response.read().decode("utf-8"))
            assert response.status == expect_status, (response.status, expect_status, body)
            return response.status, body
    except urllib.error.HTTPError as exc:
        body = json.loads(exc.read().decode("utf-8"))
        assert exc.code == expect_status, (exc.code, expect_status, body)
        return exc.code, body


with urllib.request.urlopen(f"{base_url}/orchestra/capabilities", timeout=5) as response:
    assert response.status == 200, response.status
    capabilities = json.loads(response.read().decode("utf-8"))

authority_model = capabilities["authority_model"]
assert authority_model["phase"] == "phase_1", authority_model
assert authority_model["trust_boundary"] == "localhost_only", authority_model
assert authority_model["authentication"] == "none", authority_model
assert authority_model["authority_field_is_advisory_within_loopback"] is True, authority_model

specs = {(item["module"], item["operation"]): item for item in capabilities["full_module_endpoints"]}
routes = set(capabilities["routes"])

required_specs = [
    ("debate-engine", "create-run"),
    ("debate-assembly", "select-for-stage"),
    ("debate-backend-adapter", "select-backend"),
    ("debate-member-invocation", "execute"),
    ("debate-report", "build"),
    ("worker-registry", "load-backends"),
    ("capability-negotiation", "negotiate"),
    ("worker-session", "create-session"),
    ("worker-session-sweeper", "sweep-directory"),
    ("release-pipeline", "validate-command-refs"),
    ("release-executor", "execute"),
    ("runtime-knowledge", "query"),
    ("knowledge-ingestion", "ingest"),
    ("self-evolution", "generate-stage6-sweep"),
    ("performance-slo", "evaluate"),
    ("fixture-policy", "validate-contract-fixture"),
    ("degradation-policy", "build-record"),
    ("full-schema-validation", "validate-all"),
    ("full-schema-cutover", "plan-artifact-write"),
]
for key in required_specs:
    assert key in specs, key
    assert specs[key]["route"] in routes, specs[key]
    assert "authority" in specs[key], specs[key]
    assert "request_shape" in specs[key], specs[key]
    assert "response_shape" in specs[key], specs[key]

assert "session_record_ref" in specs[("worker-session", "create-session")]["response_shape"]["result_keys"], specs[("worker-session", "create-session")]
assert "session_record_ref" in specs[("worker-session", "transition")]["response_shape"]["result_keys"], specs[("worker-session", "transition")]


def authority(module, operation):
    return specs[(module, operation)]["authority"]


backend_policy = json.loads((repo_root / "config/debate/full/backend-policy.json").read_text(encoding="utf-8"))

status, registries = post(
    "/orchestra/modules/debate-engine/load-registries",
    {"authority": authority("debate-engine", "load-registries")},
)
assert status == 200, registries
assert len(registries["result"]["team_ids"]) == 16, registries

status, run_response = post(
    "/orchestra/modules/debate-engine/create-run",
    {
        "authority": authority("debate-engine", "create-run"),
        "question": "Should Hermes enable deterministic debate coverage for gateway integration?",
        "mode_id": "dynamic_assembly",
    },
)
assert status == 200, run_response
run = run_response["result"]

status, assembly_response = post(
    "/orchestra/modules/debate-assembly/select-for-stage",
    {
        "authority": authority("debate-assembly", "select-for-stage"),
        "stage": "direction_debate",
        "task_type": "api_contract",
        "risk_level": "L2",
    },
)
assert status == 200, assembly_response
assembly = assembly_response["result"]
assert assembly["selected_member_ids"], assembly

status, backend_response = post(
    "/orchestra/modules/debate-backend-adapter/select-backend",
    {
        "authority": authority("debate-backend-adapter", "select-backend"),
        "stage": "direction_debate",
    },
)
assert status == 200, backend_response

input_refs = ["state://runs/demo-run/spec.md"]
status, invocation_response = post(
    "/orchestra/modules/debate-member-invocation/build-invocation",
    {
        "authority": authority("debate-member-invocation", "build-invocation"),
        "run": run,
        "assembly": assembly,
        "member_id": assembly["selected_member_ids"][0],
        "input_refs": input_refs,
        "affected_scopes": ["scripts/lib/orch_gateway.py"],
    },
)
assert status == 200, invocation_response

status, execution_response = post(
    "/orchestra/modules/debate-member-invocation/execute",
    {
        "authority": authority("debate-member-invocation", "execute"),
        "run": run,
        "assembly": assembly,
        "input_refs": input_refs,
        "affected_scopes": ["scripts/lib/orch_gateway.py"],
    },
)
assert status == 200, execution_response
execution = execution_response["result"]
assert execution["opinions"], execution

status, report_response = post(
    "/orchestra/modules/debate-report/build",
    {
        "authority": authority("debate-report", "build"),
        "run": run,
        "assembly": assembly,
        "backend_policy": backend_policy,
        "invocations": execution["invocations"],
        "opinions": execution["opinions"],
        "invocation_receipts": [
            {
                "opinion_ref": opinion["artifact_ref"],
                "status": "completed",
                "started_at": opinion["created_at"],
                "finished_at": opinion["created_at"],
                "retry_count": 0,
                "degraded": opinion["degraded"],
                "degradation_status": opinion["degradation_status"],
                "degradation_record": opinion["degradation_record"],
                "error_class": None,
                "timing": {"duration_ms": 1},
            }
            for opinion in execution["opinions"]
        ],
        "input_refs": input_refs,
        "affected_scopes": ["scripts/lib/orch_gateway.py"],
    },
)
assert status == 200, report_response
assert report_response["result"]["report"]["artifact_type"] == "debate_report", report_response

for operation in ("load-backends", "load-roles"):
    status, body = post(
        f"/orchestra/modules/worker-registry/{operation}",
        {"authority": authority("worker-registry", operation)},
    )
    assert status == 200, body

status, negotiation_response = post(
    "/orchestra/modules/capability-negotiation/negotiate",
    {
        "authority": authority("capability-negotiation", "negotiate"),
        "role": "implementer",
        "requested_backend": "codex",
        "required_capabilities": ["structured_envelope"],
    },
)
assert status == 200, negotiation_response
assert negotiation_response["result"]["selected_backend"] == "codex", negotiation_response

workspace_root = tmp_dir / "workspaces"
workspace_root.mkdir(parents=True, exist_ok=True)
status, session_response = post(
    "/orchestra/modules/worker-session/create-session",
    {
        "authority": authority("worker-session", "create-session"),
        "run_id": "run-session-1",
        "task_id": "task-session-1",
        "role": "implementer",
        "backend_id": "codex",
        "workspace_root": str(workspace_root),
        "write_scope_ref": "state://runs/run-session-1/write-scopes/task-session-1.json",
        "context_bundle_ref": "state://runs/run-session-1/context/task-session-1.json",
        "timeout_seconds": 30,
    },
)
assert status == 200, session_response
session_record = session_response["result"]
assert session_record["session_record_ref"].startswith("state://runs/run-session-1/worker-sessions/"), session_record

status, transition_response = post(
    "/orchestra/modules/worker-session/transition",
    {
        "authority": authority("worker-session", "transition"),
        "record": session_record,
        "next_status": "starting",
    },
)
assert status == 200, transition_response
starting_record = transition_response["result"]
assert starting_record["session_record_ref"].startswith("state://runs/run-session-1/worker-sessions/"), starting_record

records_root = tmp_dir / "worker-records"
records_root.mkdir(parents=True, exist_ok=True)
(records_root / f"{starting_record['session_id']}.json").write_text(json.dumps(starting_record), encoding="utf-8")
status, sweep_response = post(
    "/orchestra/modules/worker-session-sweeper/sweep-directory",
    {
        "authority": authority("worker-session-sweeper", "sweep-directory"),
        "records_root": str(records_root),
    },
)
assert status == 200, sweep_response
assert sweep_response["result"]["updated_records"] >= 1, sweep_response

status, load_pipeline_response = post(
    "/orchestra/modules/release-pipeline/load-pipeline",
    {"authority": authority("release-pipeline", "load-pipeline"), "allow_staged": True},
)
assert status == 200, load_pipeline_response

status, load_registry_response = post(
    "/orchestra/modules/release-pipeline/load-registry",
    {"authority": authority("release-pipeline", "load-registry"), "allow_staged": True},
)
assert status == 200, load_registry_response

for path, body in (
    (
        "/orchestra/modules/release-pipeline/validate-command-refs",
        {"authority": authority("release-pipeline", "validate-command-refs"), "allow_staged": True},
    ),
    (
        "/orchestra/modules/release-pipeline/plan",
        {"authority": authority("release-pipeline", "plan"), "allow_staged": True, "environment": "dev_test"},
    ),
    (
        "/orchestra/modules/release-executor/execute",
        {
            "authority": authority("release-executor", "execute"),
            "allow_staged": True,
            "command_ref": "command://release/dev-test",
        },
    ),
):
    status, error_body = post(path, body, expect_status=400)
    assert error_body["error"]["code"] == "command_disabled", (path, error_body)

knowledge_entry = {
    "slug": "domain/wechat/routing/navigate-to",
    "type": "candidate_knowledge",
    "domain": "wechat",
    "topic": "routing",
    "source_type": "official_documentation",
    "source_refs": [
        "https://developers.weixin.qq.com/miniprogram/en/dev/framework/app-service/route.html"
    ],
    "confidence": "medium",
    "freshness": "current",
    "valid_from": "2026-05-18T00:00:00Z",
    "last_verified_at": None,
    "tags": ["runtime", "wechat"],
    "owner": "hermes",
    "body_sections": {
        "Claim": "Use wx.navigateTo for non-tabBar pages.",
        "Context": "Runtime routing guidance for WeChat Mini Program pages.",
        "Applies When": "Navigating to a standard page route.",
        "Does Not Apply When": "Switching to a tabBar page.",
        "Evidence": "Official routing documentation.",
        "Operational Guidance": "Prefer direct route paths and validate route existence.",
        "Failure Modes": "Using wx.navigateTo for tabBar pages fails.",
        "Review Checklist": "Verify against current official docs before promotion.",
    },
}
status, ingest_response = post(
    "/orchestra/modules/knowledge-ingestion/ingest",
    {
        "authority": authority("knowledge-ingestion", "ingest"),
        "entry": knowledge_entry,
    },
    expect_status=400,
)
assert ingest_response["error"]["code"] == "module_disabled", ingest_response

status, query_response = post(
    "/orchestra/modules/runtime-knowledge/query",
    {
        "authority": authority("runtime-knowledge", "query"),
        "request": {
            "run_id": "run-runtime",
            "task_id": "task-runtime",
            "domain": "wechat",
            "question": "wx.navigateTo non-tabBar pages",
            "allowed_types": ["candidate_knowledge"],
            "required_freshness": "current",
            "max_results": 3,
            "evidence_scope": "debate",
        },
    },
    expect_status=400,
)
assert query_response["error"]["code"] == "module_disabled", query_response

non_protected_proposal = {
    "proposal_id": "P-knowledge-001",
    "target_class": "knowledge_asset",
    "target": ".workflow/knowledge/release-checklist.md",
    "target_area": "workflow_docs",
    "summary": "Clarify release checklist after repeated review comments.",
    "rationale": "The same review class repeated twice across successful closeouts.",
    "severity": "medium",
    "evidence_quality": "high",
    "source_run_ids": ["run-self-1"],
    "artifact_refs": ["state://runs/run-self-1/reviews/release-gap.json"],
    "repeated_failure_count": 2,
    "source_run_count": 1,
}
protected_proposal = {
    "proposal_id": "P-rules-001",
    "target_class": "root_rules",
    "target": "AGENTS.md",
    "target_area": "root_rules",
    "summary": "Tighten root rule wording after a decision-exposed gap.",
    "rationale": "A closeout decision exposed an authority gap in the root rules.",
    "severity": "high",
    "evidence_quality": "high",
    "source_run_ids": ["run-self-1"],
    "artifact_refs": ["state://runs/run-self-1/decisions/rules-gap.json"],
    "repeated_failure_count": 1,
    "source_run_count": 1,
    "proposed_patch_ref": "state://runs/run-self-1/patches/root-rules.diff",
    "approval_impact": "authority_boundary",
}
status, proposal_response = post(
    "/orchestra/modules/self-evolution/generate-stage6-sweep",
    {
        "authority": authority("self-evolution", "generate-stage6-sweep"),
        "allow_staged": True,
        "run_id": "run-self-1",
        "source_refs": [
            "state://runs/run-self-1/closeout.json",
            "state://runs/run-self-1/reviews/release-gap.json",
        ],
        "proposals": [non_protected_proposal, protected_proposal],
        "trigger_matches": ["review_or_qa_same_class_repeated", "decision_exposed_rule_or_doc_gap"],
    },
)
assert status == 200, proposal_response

status, enqueue_response = post(
    "/orchestra/modules/self-evolution/enqueue",
    {
        "authority": authority("self-evolution", "enqueue"),
        "allow_staged": True,
        "proposal": proposal_response["result"],
    },
)
assert status == 200, enqueue_response
queue_items = enqueue_response["result"]["queue_items"]

status, pending_response = post(
    "/orchestra/modules/self-evolution/list-pending",
    {
        "authority": authority("self-evolution", "list-pending"),
        "allow_staged": True,
        "queue_items": queue_items,
    },
)
assert status == 200, pending_response
assert len(pending_response["result"]["items"]) == 2, pending_response

status, transition_queue_response = post(
    "/orchestra/modules/self-evolution/transition",
    {
        "authority": authority("self-evolution", "transition"),
        "allow_staged": True,
        "queue_item": next(item for item in queue_items if item["protected_target_class"] == "none"),
        "next_status": "under_review",
    },
)
assert status == 200, transition_queue_response
assert transition_queue_response["result"]["status"] == "under_review", transition_queue_response

status, performance_response = post(
    "/orchestra/modules/performance-slo/evaluate",
    {
        "authority": authority("performance-slo", "evaluate"),
        "allow_staged": True,
        "component_id": "gateway_api",
        "observed": {
            "health_p95_ms": 120,
            "capabilities_p95_ms": 180,
            "status_projection_p95_ms": 220,
            "tasks_projection_p95_ms": 300,
            "event_poll_p95_ms": 280,
            "mutating_command_ack_p95_ms": 450,
        },
    },
)
assert status == 200, performance_response
assert performance_response["result"]["budget_status"] == "on_budget", performance_response

contract_fixture = {
    "fixture_name": "valid_debate_member_opinion",
    "fixture_kind": "contract_fixture",
    "fixture_backend": "none",
    "degraded_fixture_only": False,
    "completion_evidence_allowed": False,
    "release_evidence_allowed": False,
    "test_scope": "unit",
}
status, contract_fixture_response = post(
    "/orchestra/modules/fixture-policy/validate-contract-fixture",
    {
        "authority": authority("fixture-policy", "validate-contract-fixture"),
        "allow_staged": True,
        "family_id": "debate",
        "fixture": contract_fixture,
    },
)
assert status == 200, contract_fixture_response

runtime_fake_fixture = {
    "fixture_name": "template_fixture_backend",
    "fixture_kind": "runtime_fake_adapter",
    "fixture_backend": "template_fixture_backend",
    "degraded_fixture_only": True,
    "completion_evidence_allowed": False,
    "release_evidence_allowed": False,
    "test_scope": "integration",
}
status, runtime_fixture_response = post(
    "/orchestra/modules/fixture-policy/validate-runtime-fake-adapter",
    {
        "authority": authority("fixture-policy", "validate-runtime-fake-adapter"),
        "allow_staged": True,
        "family_id": "debate",
        "fixture": runtime_fake_fixture,
    },
)
assert status == 200, runtime_fixture_response

status, degradation_transition = post(
    "/orchestra/modules/degradation-policy/transition",
    {
        "authority": authority("degradation-policy", "transition"),
        "allow_staged": True,
        "current_status": "normal",
        "next_status": "degraded",
    },
)
assert status == 200, degradation_transition
assert degradation_transition["result"]["next_status"] == "degraded", degradation_transition

status, degradation_record = post(
    "/orchestra/modules/degradation-policy/build-record",
    {
        "authority": authority("degradation-policy", "build-record"),
        "allow_staged": True,
        "degradation_status": "degraded",
        "degradation_class": "runtime_knowledge_warning_context",
        "cause": "warning_context_returned",
        "affected_evidence_refs": ["state://runs/run-runtime/result.json"],
        "recovery_options": ["refresh_or_verify_entries"],
    },
)
assert status == 200, degradation_record

status, evidence_response = post(
    "/orchestra/modules/degradation-policy/allows-completion-evidence",
    {
        "authority": authority("degradation-policy", "allows-completion-evidence"),
        "allow_staged": True,
        "record": degradation_record["result"],
    },
)
assert status == 200, evidence_response
assert evidence_response["result"]["allowed"] is False, evidence_response

status, schema_response = post(
    "/orchestra/modules/full-schema-validation/validate-schema",
    {
        "authority": authority("full-schema-validation", "validate-schema"),
        "allow_staged": True,
    },
)
assert status == 200, schema_response

status, contract_response = post(
    "/orchestra/modules/full-schema-validation/validate-contract",
    {
        "authority": authority("full-schema-validation", "validate-contract"),
        "allow_staged": True,
        "rel_path": "config/debate/full/teams.json",
        "definition_name": "debate_team_registry",
    },
)
assert status == 200, contract_response

status, validate_all_response = post(
    "/orchestra/modules/full-schema-validation/validate-all",
    {
        "authority": authority("full-schema-validation", "validate-all"),
        "allow_staged": True,
    },
)
assert status == 200, validate_all_response

status, evaluate_family_response = post(
    "/orchestra/modules/full-schema-cutover/evaluate-family",
    {
        "authority": authority("full-schema-cutover", "evaluate-family"),
        "allow_staged": True,
        "family_id": "full_debate_package",
    },
)
assert status == 200, evaluate_family_response

status, can_activate_response = post(
    "/orchestra/modules/full-schema-cutover/can-activate",
    {
        "authority": authority("full-schema-cutover", "can-activate"),
        "allow_staged": True,
        "family_id": "full_debate_package",
        "evidence": [],
        "completed_checks": [],
    },
)
assert status == 200, can_activate_response
assert can_activate_response["result"]["allowed"] is False, can_activate_response

status, plan_write_response = post(
    "/orchestra/modules/full-schema-cutover/plan-artifact-write",
    {
        "authority": authority("full-schema-cutover", "plan-artifact-write"),
        "allow_staged": True,
        "family_id": "full_debate_package",
        "family_activated": True,
    },
)
assert status == 200, plan_write_response
assert plan_write_response["result"]["write_full_artifacts"] is True, plan_write_response
PY

test_done
