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


blocked = KnowledgeIngestion(repo)
exc = expect_error("module_disabled", lambda: blocked.ingest(runtime_entry()))
assert "allow_staged=True" in exc.message, exc.message

disabled = KnowledgeIngestion(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", lambda: disabled.ingest(runtime_entry()))

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
    ingestor = KnowledgeIngestion(tmp_repo, allow_staged=True, gbrain_env=runtime_env(home_dir))
    result = ingestor.ingest(runtime_entry(entry_type="domain_knowledge", verification_method="official_doc_review"))
    validate_artifact_definition(tmp_repo, "runtime_knowledge_entry", result["entry"])
    validate_artifact_definition(tmp_repo, "knowledge_ingestion_record", result["ingestion_record"])
    assert result["ingestion_record"]["resulting_status"] == "domain_knowledge", result["ingestion_record"]
    assert result["ingestion_record"]["verification_method"] == "official_doc_review", result["ingestion_record"]
PY

test_done
