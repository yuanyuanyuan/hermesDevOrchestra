#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="runtime-knowledge"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

which gbrain >/dev/null 2>&1 || fail "gbrain must be available on PATH"
gbrain --version >/dev/null 2>&1 || fail "gbrain --version must exit 0"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/knowledge/runtime-kb.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS runtime knowledge backend: gbrain target without separate Hermes SQLite" <<<"$FULL_VALIDATE_OUTPUT" || fail "full runtime knowledge contract validation failed" "runtime knowledge backend pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import os
import pathlib
import shutil
import sys
import tempfile

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_report import validate_artifact_definition
from knowledge_ingestion import KnowledgeIngestion, KnowledgeIngestionError
from runtime_knowledge import RuntimeKnowledgeBase, RuntimeKnowledgeError


def expect_error(code, func):
    try:
        func()
    except KnowledgeIngestionError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected KnowledgeIngestionError({code})")


def copy_schema(target_repo):
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/schemas/orchestra.full.schema.json", schema_dir / "orchestra.full.schema.json")


def prepare_active_repo(tmp_repo, config_mutator=None):
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/knowledge"
    config_dir.mkdir(parents=True, exist_ok=True)
    config = json.loads((repo / "config/knowledge/runtime-kb.json").read_text(encoding="utf-8"))
    config["enabled"] = True
    config["backend"]["enabled"] = True
    if config_mutator is not None:
        config_mutator(config)
    (config_dir / "runtime-kb.json").write_text(json.dumps(config), encoding="utf-8")


def runtime_entry(entry_type="candidate_knowledge", verification_method=None):
    entry = {
        "slug": "domain/wechat/routing/navigate-to",
        "type": entry_type,
        "domain": "wechat",
        "topic": "routing",
        "source_type": "official_documentation",
        "source_refs": [
            "https://developers.weixin.qq.com/miniprogram/en/dev/framework/app-service/route.html"
        ],
        "confidence": "high" if entry_type == "domain_knowledge" else "medium",
        "freshness": "current",
        "valid_from": "2026-05-18T00:00:00Z",
        "last_verified_at": "2026-05-18T00:00:00Z" if entry_type == "domain_knowledge" else None,
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
    if verification_method is not None:
        entry["verification_method"] = verification_method
    return entry


def runtime_env(home_dir):
    return {
        "PATH": os.environ["PATH"],
        "HOME": str(home_dir),
        "XDG_CONFIG_HOME": str(home_dir / ".config"),
        "XDG_DATA_HOME": str(home_dir / ".local" / "share"),
        "XDG_STATE_HOME": str(home_dir / ".local" / "state"),
    }


def fake_runtime_env(home_dir, slug):
    bin_dir = home_dir / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    script = bin_dir / "gbrain"
    script.write_text(
        """#!/usr/bin/env python3
import json
import os
import sys

slug = os.environ["FAKE_GBRAIN_SLUG"]
args = sys.argv[1:]
if not args:
    sys.exit(1)
if args == ["--version"]:
    print("gbrain fake 0.0.0")
    sys.exit(0)
if args[0] == "init":
    sys.exit(0)
if args[0] == "put":
    print(json.dumps({"slug": slug, "status": "created_or_updated", "chunks": 1}))
    sys.exit(0)
if args[0] == "report":
    print("reports/knowledge-ingestion/fake.md")
    sys.exit(0)
if args[0] == "query":
    print(f"[0.9999] {slug} -- fake query snippet")
    sys.exit(0)
sys.exit(1)
""",
        encoding="utf-8",
    )
    script.chmod(0o755)
    env = runtime_env(home_dir)
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["FAKE_GBRAIN_SLUG"] = slug
    return env


def runtime_request(question, allowed_types=None, evidence_scope="implementation"):
    return {
        "run_id": "run-runtime-knowledge",
        "task_id": "task-runtime-knowledge",
        "domain": "wechat",
        "question": question,
        "allowed_types": allowed_types or ["domain_knowledge"],
        "required_freshness": "current",
        "max_results": 3,
        "evidence_scope": evidence_scope,
    }


blocked = KnowledgeIngestion(repo)
exc = expect_error("module_disabled", lambda: blocked.ingest(runtime_entry()))
assert "allow_staged=True" in exc.message, exc.message

disabled = KnowledgeIngestion(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", lambda: disabled.ingest(runtime_entry()))

blocked_kb = RuntimeKnowledgeBase(repo)
kb_exc = None
try:
    blocked_kb.query(runtime_request("navigateTo routing"))
except RuntimeKnowledgeError as exc:
    kb_exc = exc
assert kb_exc is not None, "expected RuntimeKnowledgeError(module_disabled)"
assert kb_exc.code == "module_disabled", kb_exc.code
assert "allow_staged=True" in kb_exc.message, kb_exc.message

disabled_kb = RuntimeKnowledgeBase(repo, allow_staged=True, enabled=False)
try:
    disabled_kb.query(runtime_request("navigateTo routing"))
except RuntimeKnowledgeError as exc:
    assert exc.code == "module_disabled", exc.code
else:
    raise AssertionError("expected RuntimeKnowledgeError(module_disabled)")

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, gbrain_env=runtime_env(home_dir))
    result = ingestor.ingest(runtime_entry())
    validate_artifact_definition(tmp_repo, "runtime_knowledge_entry", result["entry"])
    validate_artifact_definition(tmp_repo, "knowledge_ingestion_record", result["ingestion_record"])
    assert result["storage_ref"] == "knowledge://gbrain/domain/wechat/routing/navigate-to", result
    assert result["gbrain_put_result"]["status"] == "created_or_updated", result
    assert result["ingestion_record"]["operation"] == "import", result["ingestion_record"]
    assert result["ingestion_record"]["resulting_status"] == "candidate_knowledge", result["ingestion_record"]
    assert result["gbrain_report_ref"].startswith("gbrain://reports/knowledge-ingestion/"), result["gbrain_report_ref"]
    assert "# Claim" in result["page_markdown"], result["page_markdown"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, gbrain_env=runtime_env(home_dir))
    expect_error("verification_required", lambda: ingestor.ingest(runtime_entry(entry_type="domain_knowledge")))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, gbrain_env=runtime_env(home_dir))
    malformed = runtime_entry()
    malformed["body_sections"].pop("Review Checklist")
    expect_error("schema_invalid", lambda: ingestor.ingest(malformed))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    ingestor = KnowledgeIngestion(
        tmp_repo,
        allow_staged=True,
        gbrain_env=fake_runtime_env(home_dir, "domain/wechat/routing/navigate-to"),
    )
    result = ingestor.ingest(runtime_entry(entry_type="domain_knowledge", verification_method="official_doc_review"))
    validate_artifact_definition(tmp_repo, "runtime_knowledge_entry", result["entry"])
    validate_artifact_definition(tmp_repo, "knowledge_ingestion_record", result["ingestion_record"])
    assert result["ingestion_record"]["resulting_status"] == "domain_knowledge", result["ingestion_record"]
    assert result["ingestion_record"]["verification_method"] == "official_doc_review", result["ingestion_record"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    env = fake_runtime_env(home_dir, "domain/wechat/routing/navigate-to")
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, gbrain_env=env)
    ingestor.ingest(runtime_entry(entry_type="domain_knowledge", verification_method="official_doc_review"))
    kb = RuntimeKnowledgeBase(tmp_repo, allow_staged=True, gbrain_env=env)
    queried = kb.query(runtime_request("wx.navigateTo non-tabBar pages"))
    validate_artifact_definition(tmp_repo, "runtime_knowledge_query", queried["query_artifact"])
    validate_artifact_definition(tmp_repo, "runtime_knowledge_result", queried["result_artifact"])
    assert queried["result_artifact"]["slugs"] == ["domain/wechat/routing/navigate-to"], queried["result_artifact"]
    assert queried["result_artifact"]["freshness_status"] == "current", queried["result_artifact"]
    assert queried["result_artifact"]["degradation_status"] == "normal", queried["result_artifact"]
    assert queried["result_artifact"]["warnings"] == [], queried["result_artifact"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    env = fake_runtime_env(home_dir, "domain/wechat/routing/navigate-to")
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, gbrain_env=env)
    ingestor.ingest(runtime_entry())
    kb = RuntimeKnowledgeBase(tmp_repo, allow_staged=True, gbrain_env=env)
    queried = kb.query(
        runtime_request(
            "wx.navigateTo non-tabBar pages",
            allowed_types=["domain_knowledge", "candidate_knowledge"],
            evidence_scope="research",
        )
    )
    validate_artifact_definition(tmp_repo, "runtime_knowledge_result", queried["result_artifact"])
    assert queried["result_artifact"]["slugs"] == ["domain/wechat/routing/navigate-to"], queried["result_artifact"]
    assert queried["result_artifact"]["freshness_status"] == "warning_context", queried["result_artifact"]
    assert queried["result_artifact"]["degradation_status"] == "degraded", queried["result_artifact"]
    assert "candidate_knowledge_requires_verification" in queried["result_artifact"]["warnings"], queried["result_artifact"]["warnings"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    env = fake_runtime_env(home_dir, "domain/wechat/routing/navigate-to")
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, gbrain_env=env)
    expired = runtime_entry(entry_type="domain_knowledge", verification_method="official_doc_review")
    expired["last_verified_at"] = "2026-01-01T00:00:00Z"
    expired["valid_from"] = "2026-01-01T00:00:00Z"
    ingestor.ingest(expired)
    kb = RuntimeKnowledgeBase(tmp_repo, allow_staged=True, gbrain_env=env)
    queried = kb.query(runtime_request("wx.navigateTo non-tabBar pages"))
    validate_artifact_definition(tmp_repo, "runtime_knowledge_result", queried["result_artifact"])
    assert queried["result_artifact"]["slugs"] == ["domain/wechat/routing/navigate-to"], queried["result_artifact"]
    assert queried["result_artifact"]["freshness_status"] == "warning_context", queried["result_artifact"]
    assert queried["result_artifact"]["degradation_status"] == "degraded", queried["result_artifact"]
    assert "expired_entry_warning_context" in queried["result_artifact"]["warnings"], queried["result_artifact"]["warnings"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    state_root = tmp_repo / "state-root"
    degraded_env = runtime_env(home_dir)
    degraded_env["PATH"] = str(tmp_repo / "missing-bin")
    ingestor = KnowledgeIngestion(
        tmp_repo,
        allow_staged=True,
        gbrain_env=degraded_env,
        state_root=state_root,
    )
    degraded_ingest = ingestor.ingest(runtime_entry(entry_type="domain_knowledge", verification_method="official_doc_review"))
    assert degraded_ingest["degraded"] is True, degraded_ingest
    assert degraded_ingest["storage_ref"].startswith("state://knowledge/entries/"), degraded_ingest["storage_ref"]

    kb = RuntimeKnowledgeBase(
        tmp_repo,
        allow_staged=True,
        gbrain_env=degraded_env,
        state_root=state_root,
    )
    queried = kb.query(runtime_request("wx.navigateTo non-tabBar pages"))
    validate_artifact_definition(tmp_repo, "runtime_knowledge_result", queried["result_artifact"])
    assert queried["result_artifact"]["slugs"] == ["domain/wechat/routing/navigate-to"], queried["result_artifact"]
    assert queried["result_artifact"]["degradation_status"] == "degraded", queried["result_artifact"]
    assert queried["result_artifact"]["freshness_status"] == "warning_context", queried["result_artifact"]
    assert "backend_unavailable_state_store" in queried["result_artifact"]["warnings"], queried["result_artifact"]["warnings"]
    assert queried["degraded_storage_refs"][0].startswith("state://knowledge/entries/"), queried["degraded_storage_refs"]
    degraded_entry_path = state_root / "knowledge" / "entries" / "wechat" / "routing" / "navigate-to.json"
    assert degraded_entry_path.exists(), degraded_entry_path
PY

test_done
