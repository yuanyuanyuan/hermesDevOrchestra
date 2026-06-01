#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="runtime-knowledge"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/knowledge/runtime-kb.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS runtime knowledge deferred state: runtime knowledge backend is deferred and disabled before adapter selection" <<<"$FULL_VALIDATE_OUTPUT" || fail "full runtime knowledge deferred validation failed" "runtime knowledge deferred pass" "$FULL_VALIDATE_OUTPUT"

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
    except (KnowledgeIngestionError, RuntimeKnowledgeError) as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected error({code})")


def copy_schema(target_repo):
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/schemas/orchestra.full.schema.json", schema_dir / "orchestra.full.schema.json")


def prepare_state_store_repo(tmp_repo, config_mutator=None):
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/knowledge"
    config_dir.mkdir(parents=True, exist_ok=True)
    config = json.loads((repo / "config/knowledge/runtime-kb.json").read_text(encoding="utf-8"))
    config["enabled"] = True
    config["backend"] = {
        "id": "state_store",
        "enabled": True,
        "storage_authority": "state",
        "default_engine": "json_state_store",
        "adapter_required_before_enable": False,
    }
    if config_mutator is not None:
        config_mutator(config)
    (config_dir / "runtime-kb.json").write_text(json.dumps(config), encoding="utf-8")


def runtime_env(home_dir):
    return {
        "PATH": os.environ["PATH"],
        "HOME": str(home_dir),
        "XDG_CONFIG_HOME": str(home_dir / ".config"),
        "XDG_DATA_HOME": str(home_dir / ".local" / "share"),
        "XDG_STATE_HOME": str(home_dir / ".local" / "state"),
    }


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


default_ingestor = KnowledgeIngestion(repo)
expect_error("module_disabled", lambda: default_ingestor.ingest(runtime_entry()))

default_kb = RuntimeKnowledgeBase(repo)
expect_error("module_disabled", lambda: default_kb.query(runtime_request("navigateTo routing")))

disabled = KnowledgeIngestion(repo, enabled=False)
expect_error("module_disabled", lambda: disabled.ingest(runtime_entry()))

disabled_kb = RuntimeKnowledgeBase(repo, enabled=False)
expect_error("module_disabled", lambda: disabled_kb.query(runtime_request("navigateTo routing")))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_state_store_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    env = runtime_env(home_dir)

    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, runtime_env=env)
    result = ingestor.ingest(runtime_entry())
    validate_artifact_definition(tmp_repo, "runtime_knowledge_entry", result["entry"])
    validate_artifact_definition(tmp_repo, "knowledge_ingestion_record", result["ingestion_record"])
    assert result["storage_ref"] == "state://knowledge/entries/wechat/routing/navigate-to.json", result
    assert result["runtime_put_result"]["status"] == "stored_in_state", result
    assert result["runtime_report_ref"].startswith("state://knowledge/ingestion/"), result["runtime_report_ref"]
    assert result["degraded"] is False, result

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_state_store_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, runtime_env=runtime_env(home_dir))
    expect_error("verification_required", lambda: ingestor.ingest(runtime_entry(entry_type="domain_knowledge")))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_state_store_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, runtime_env=runtime_env(home_dir))
    malformed = runtime_entry()
    malformed["body_sections"].pop("Review Checklist")
    expect_error("schema_invalid", lambda: ingestor.ingest(malformed))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_state_store_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    env = runtime_env(home_dir)

    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, runtime_env=env)
    result = ingestor.ingest(runtime_entry(entry_type="domain_knowledge", verification_method="official_doc_review"))
    validate_artifact_definition(tmp_repo, "knowledge_ingestion_record", result["ingestion_record"])
    assert result["ingestion_record"]["backend"] == "state_store", result["ingestion_record"]
    assert result["ingestion_record"]["resulting_status"] == "domain_knowledge", result["ingestion_record"]

    kb = RuntimeKnowledgeBase(tmp_repo, allow_staged=True, runtime_env=env)
    queried = kb.query(runtime_request("wx.navigateTo non-tabBar pages"))
    validate_artifact_definition(tmp_repo, "runtime_knowledge_query", queried["query_artifact"])
    validate_artifact_definition(tmp_repo, "runtime_knowledge_result", queried["result_artifact"])
    assert queried["result_artifact"]["backend"] == "state_store", queried["result_artifact"]
    assert queried["result_artifact"]["slugs"] == ["domain/wechat/routing/navigate-to"], queried["result_artifact"]
    assert queried["result_artifact"]["freshness_status"] == "current", queried["result_artifact"]
    assert queried["result_artifact"]["degradation_status"] == "normal", queried["result_artifact"]
    assert queried["result_artifact"]["warnings"] == [], queried["result_artifact"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_state_store_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    env = runtime_env(home_dir)

    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, runtime_env=env)
    ingestor.ingest(runtime_entry())
    kb = RuntimeKnowledgeBase(tmp_repo, allow_staged=True, runtime_env=env)
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
    prepare_state_store_repo(tmp_repo)
    home_dir = tmp_repo / "home"
    home_dir.mkdir(parents=True, exist_ok=True)
    env = runtime_env(home_dir)

    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, runtime_env=env)
    expired = runtime_entry(entry_type="domain_knowledge", verification_method="official_doc_review")
    expired["last_verified_at"] = "2026-01-01T00:00:00Z"
    expired["valid_from"] = "2026-01-01T00:00:00Z"
    ingestor.ingest(expired)
    kb = RuntimeKnowledgeBase(tmp_repo, allow_staged=True, runtime_env=env)
    queried = kb.query(runtime_request("wx.navigateTo non-tabBar pages"))
    validate_artifact_definition(tmp_repo, "runtime_knowledge_result", queried["result_artifact"])
    assert queried["result_artifact"]["slugs"] == ["domain/wechat/routing/navigate-to"], queried["result_artifact"]
    assert queried["result_artifact"]["freshness_status"] == "warning_context", queried["result_artifact"]
    assert queried["result_artifact"]["degradation_status"] == "degraded", queried["result_artifact"]
    assert "expired_entry_warning_context" in queried["result_artifact"]["warnings"], queried["result_artifact"]["warnings"]
PY

test_done
