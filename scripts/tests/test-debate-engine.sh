#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="debate-engine"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys
assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/debate/full/teams.json
python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/debate/full/modes.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/debate/full/teams.json: debate_team_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "full debate teams contract validation failed" "teams pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/debate/full/modes.json: debate_mode_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "full debate modes contract validation failed" "modes pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import shutil
import sys
import tempfile

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_engine import DebateEngine, DebateEngineError


def expect_error(code, func):
    try:
        func()
    except DebateEngineError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected DebateEngineError({code})")


engine = DebateEngine(repo)
registries = engine.load_registries()
assert len(registries["teams"]) == 16, len(registries["teams"])
assert len(registries["modes"]) == 11, len(registries["modes"])
assert registries["team_ids"][0] == "security", registries["team_ids"][:3]
assert "dynamic_assembly" in registries["mode_ids"], registries["mode_ids"]
assert {"consensus_fast", "standard_debate", "deep_fork"} <= set(registries["mode_ids"]), registries["mode_ids"]
assert registries["package_status"] == "active", registries["package_status"]

run = engine.create_run(
    question="How should Hermes stage full debate package rollout?",
    mode_id="parallel_debate",
    selected_member_ids=["threat_modeler", "legal_reviewer"],
    metadata={"stage": "direction_debate"},
)
assert run["artifact_type"] == "debate_run", run
assert run["status"] == "initialized", run
assert run["mode_id"] == "parallel_debate", run
assert run["selected_team_ids"] == ["compliance", "security"], run["selected_team_ids"]
assert run["metadata"]["stage"] == "direction_debate", run["metadata"]

expect_error("validation_error", lambda: engine.create_run(question="", mode_id="parallel_debate"))
expect_error("validation_error", lambda: engine.create_run(question="x" * 4001, mode_id="parallel_debate"))
expect_error(
    "validation_error",
    lambda: engine.create_run(
        question="valid question",
        mode_id="parallel_debate",
        metadata={"stage": "x" * 4001},
    ),
)
expect_error("mode_not_found", lambda: engine.create_run(question="valid question", mode_id="missing"))
expect_error(
    "member_not_found",
    lambda: engine.create_run(question="valid question", mode_id="parallel_debate", selected_member_ids=["missing_member"]),
)

disabled = DebateEngine(repo, enabled=False)
expect_error("module_disabled", disabled.load_registries)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    shutil.copytree(repo / "config", tmp_repo / "config")
    teams_path = tmp_repo / "config/debate/full/teams.json"
    modes_path = tmp_repo / "config/debate/full/modes.json"
    teams_data = json.loads(teams_path.read_text(encoding="utf-8"))
    modes_data = json.loads(modes_path.read_text(encoding="utf-8"))
    teams_data["package_status"] = "staged_target"
    modes_data["package_status"] = "staged_target"
    teams_path.write_text(json.dumps(teams_data), encoding="utf-8")
    modes_path.write_text(json.dumps(modes_data), encoding="utf-8")
    blocked = DebateEngine(tmp_repo)
    exc = expect_error("package_not_active", blocked.load_registries)
    assert "staged_target" in exc.message, exc.message

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    teams_dir = tmp_repo / "config/debate/full"
    teams_dir.mkdir(parents=True)
    (teams_dir / "teams.json").write_text(json.dumps({
        "schema_version": "orchestra.full.v1",
        "artifact_type": "debate_team_registry",
        "package_kind": "full_debate_package",
        "registry_authority": "qnN4o510",
        "package_status": "active",
        "teams": [],
    }), encoding="utf-8")
    (teams_dir / "modes.json").write_text(json.dumps({
        "schema_version": "orchestra.full.v1",
        "artifact_type": "debate_mode_registry",
        "package_kind": "full_debate_package",
        "registry_authority": "qnN4o510",
        "package_status": "active",
        "modes": [],
    }), encoding="utf-8")
    empty_engine = DebateEngine(tmp_repo)
    expect_error("empty_registry", empty_engine.load_registries)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    config_dir = tmp_repo / "config/debate/full"
    config_dir.mkdir(parents=True)
    (config_dir / "teams.json").write_text(json.dumps({
        "schema_version": "orchestra.full.v1",
        "artifact_type": "debate_team_registry",
        "package_kind": "full_debate_package",
        "registry_authority": "qnN4o510",
        "package_status": "active",
        "teams": [{"id": "security", "name": "Security"}],
    }), encoding="utf-8")
    (config_dir / "modes.json").write_text("{ not valid json }", encoding="utf-8")
    malformed_engine = DebateEngine(tmp_repo)
    expect_error("config_invalid", malformed_engine.load_registries)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    config_dir = tmp_repo / "config/debate/full"
    config_dir.mkdir(parents=True)
    (config_dir / "teams.json").write_text(json.dumps({
        "schema_version": "orchestra.full.v1",
        "artifact_type": "debate_team_registry",
        "package_kind": "full_debate_package",
        "registry_authority": "qnN4o510",
        "package_status": "active",
        "teams": [{
            "id": "security",
            "name": "Security",
            "members": [{"id": "threat_modeler"}, {"id": "secrets_auditor"}],
        }],
    }), encoding="utf-8")
    (config_dir / "modes.json").write_text(json.dumps({
        "schema_version": "orchestra.full.v1",
        "artifact_type": "debate_mode_registry",
        "package_kind": "full_debate_package",
        "registry_authority": "qnN4o510",
        "package_status": "active",
        "modes": [{"id": "parallel_debate", "name": "Parallel Debate"}],
    }), encoding="utf-8")
    short_team_engine = DebateEngine(tmp_repo)
    exc = expect_error("config_invalid", short_team_engine.load_registries)
    assert "at least 3 members" in exc.message, exc.message
PY

test_done
