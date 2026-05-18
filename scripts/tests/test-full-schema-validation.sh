#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="full-schema-validation"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/cutover/full-readiness-gates.json
python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/debate/full/teams.json
python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/workers/full/roles.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS schema: config/schemas/orchestra.full.schema.json" <<<"$FULL_VALIDATE_OUTPUT" || fail "full schema was not validated" "schema pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/debate/full/teams.json: debate_team_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "full debate team registry was not validated" "teams pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/workers/full/roles.json: worker_role_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "full worker role registry was not validated" "worker roles pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/cutover/full-readiness-gates.json: full_contract_readiness_gate_policy" <<<"$FULL_VALIDATE_OUTPUT" || fail "full readiness gate policy was not validated" "cutover pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import shutil
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from full_schema_validation import FullSchemaValidation, FullSchemaValidationError


FULL_TARGET_FILES = [
    "config/debate/full/teams.json",
    "config/debate/full/modes.json",
    "config/debate/full/coverage-policy.json",
    "config/debate/full/assembly-policy.json",
    "config/debate/full/backend-policy.json",
    "config/workers/full/backends.json",
    "config/workers/full/roles.json",
    "config/cutover/full-readiness-gates.json",
]


def expect_error(code: str, func):
    try:
        func()
    except FullSchemaValidationError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected FullSchemaValidationError({code})")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def copy_schema(target_repo: Path) -> None:
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/schemas/orchestra.full.schema.json", schema_dir / "orchestra.full.schema.json")


def prepare_active_repo(tmp_repo: Path, config_mutator=None, schema_mutator=None) -> None:
    copy_schema(tmp_repo)
    if schema_mutator is not None:
        schema_path = tmp_repo / "config/schemas/orchestra.full.schema.json"
        schema = load_json(schema_path)
        schema_mutator(schema)
        write_json(schema_path, schema)

    for rel_path in FULL_TARGET_FILES:
        target_path = tmp_repo / rel_path
        target_path.parent.mkdir(parents=True, exist_ok=True)
        payload = load_json(repo / rel_path)
        payload["package_status"] = "active"
        if config_mutator is not None:
            config_mutator(rel_path, payload)
        write_json(target_path, payload)


blocked = FullSchemaValidation(repo)
exc = expect_error(
    "package_not_active",
    lambda: blocked.validate_contract("config/cutover/full-readiness-gates.json", "full_contract_readiness_gate_policy"),
)
assert "allow_staged=True" in exc.message, exc.message

disabled = FullSchemaValidation(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", disabled.validate_all)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    validator = FullSchemaValidation(tmp_repo, allow_staged=True)
    report = validator.validate_all()
    assert report["ok"] is True, report
    assert report["schema"]["ok"] is True, report
    validated_paths = {entry["path"] for entry in report["contracts"]}
    assert set(FULL_TARGET_FILES) == validated_paths, validated_paths

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(
        tmp_repo,
        config_mutator=lambda rel_path, payload: payload.__setitem__("artifact_type", "broken_registry")
        if rel_path == "config/workers/full/roles.json"
        else None,
    )
    validator = FullSchemaValidation(tmp_repo, allow_staged=True)
    expect_error(
        "schema_invalid",
        lambda: validator.validate_contract("config/workers/full/roles.json", "worker_role_registry"),
    )

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo, schema_mutator=lambda payload: payload.pop("$defs"))
    validator = FullSchemaValidation(tmp_repo, allow_staged=True)
    expect_error("schema_invalid", validator.validate_schema)
PY

test_done
