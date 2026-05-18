#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="worker-registry"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys
assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/workers/full/backends.json
python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/workers/full/roles.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/workers/full/backends.json: worker_backend_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "full worker backend registry contract validation failed" "worker backend registry pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/workers/full/roles.json: worker_role_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "full worker role registry contract validation failed" "worker role registry pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import os
import pathlib
import shutil
import sys
import tempfile

import jsonschema

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from capability_negotiation import CapabilityNegotiationError, CapabilityNegotiator
from worker_registry import WorkerRegistry, WorkerRegistryError


schema = json.loads((repo / "config/schemas/orchestra.full.schema.json").read_text(encoding="utf-8"))


def validate_definition(name, instance):
    jsonschema.validate(
        instance=instance,
        schema={
            "$schema": schema["$schema"],
            "$ref": f"#/$defs/{name}",
            "$defs": schema["$defs"],
        },
    )


def expect_error(error_type, code, func):
    try:
        func()
    except error_type as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected {error_type.__name__}({code})")


def copy_schema(target_repo):
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/schemas/orchestra.full.schema.json", schema_dir / "orchestra.full.schema.json")


registry = WorkerRegistry(repo, allow_staged=True)
backends = registry.load_backends()
roles = registry.load_roles()
assert backends["artifact_type"] == "worker_backend_registry", backends
assert roles["artifact_type"] == "worker_role_registry", roles
assert {backend["id"] for backend in backends["backends"]} == {"codex", "claude"}, backends["backends"]
assert {role["role"] for role in roles["roles"]} == {"implementer", "reviewer"}, roles["roles"]

blocked_registry = WorkerRegistry(repo)
exc = expect_error(WorkerRegistryError, "package_not_active", blocked_registry.load_backends)
assert "staged_target" in exc.message, exc.message

disabled_registry = WorkerRegistry(repo, allow_staged=True, enabled=False)
expect_error(WorkerRegistryError, "module_disabled", disabled_registry.load_backends)

availability = {
    "codex": {"available": True, "reasons": []},
    "claude": {"available": True, "reasons": []},
}
negotiator = CapabilityNegotiator(WorkerRegistry(repo, allow_staged=True, availability_overrides=availability))
selected = negotiator.negotiate("implementer")
validate_definition("worker_selection_record", selected["selection_record"])
validate_definition("capability_negotiation_report", selected["negotiation_report"])
assert selected["selection_record"]["selected_backend"] == "codex", selected
assert selected["selection_record"]["fallback_used"] is False, selected
assert selected["selection_record"]["negotiation_status"] == "selected", selected
assert selected["selection_record"]["run_id"].startswith("negotiate-"), selected
assert selected["negotiation_report"]["negotiation_status"] == "selected", selected
assert selected["negotiation_report"]["decision_required"] == "none", selected
assert selected["negotiation_report"]["checked_backends"] == ["codex"], selected

role_incompatible = negotiator.negotiate("implementer", requested_backend="claude")
validate_definition("worker_selection_record", role_incompatible["selection_record"])
validate_definition("capability_negotiation_report", role_incompatible["negotiation_report"])
assert role_incompatible["selection_record"]["selected_backend"] is None, role_incompatible
assert role_incompatible["selection_record"]["negotiation_status"] == "blocked", role_incompatible
assert role_incompatible["selection_record"]["blocked_reason"] == "role_incompatible", role_incompatible
assert role_incompatible["negotiation_report"]["decision_required"] == "kimi", role_incompatible
assert role_incompatible["negotiation_report"]["fallback_selected"] is None, role_incompatible
assert "no_explicit_fallback_backends" in role_incompatible["negotiation_report"]["fallback_blocked_reasons"], role_incompatible

missing_capability = negotiator.negotiate(
    "implementer",
    required_capabilities=["structured_verdict"],
)
assert missing_capability["selection_record"]["negotiation_status"] == "blocked", missing_capability
assert missing_capability["selection_record"]["blocked_reason"] == "missing_capabilities", missing_capability
assert missing_capability["negotiation_report"]["missing_capabilities"] == ["structured_verdict"], missing_capability

unavailable_negotiator = CapabilityNegotiator(
    WorkerRegistry(
        repo,
        allow_staged=True,
        availability_overrides={
            "codex": {"available": False, "reasons": ["install_check_failed"]},
            "claude": {"available": True, "reasons": []},
        },
    )
)
unavailable = unavailable_negotiator.negotiate("implementer")
assert unavailable["selection_record"]["negotiation_status"] == "blocked", unavailable
assert unavailable["selection_record"]["blocked_reason"] == "backend_unavailable", unavailable
assert unavailable["negotiation_report"]["unavailable_reasons"] == ["codex:install_check_failed"], unavailable
assert unavailable["negotiation_report"]["fallback_selected"] is None, unavailable

expect_error(
    CapabilityNegotiationError,
    "role_not_found",
    lambda: negotiator.negotiate("missing-role"),
)

disabled_negotiator = CapabilityNegotiator(disabled_registry)
expect_error(
    CapabilityNegotiationError,
    "module_disabled",
    lambda: disabled_negotiator.negotiate("implementer"),
)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/workers/full"
    config_dir.mkdir(parents=True, exist_ok=True)
    malformed_backends = {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "worker_backend_registry",
        "package_status": "active",
        "registry_authority": "project",
        "implicit_backend_fallback_allowed": False,
        "backends": [
            {
                "id": "codex",
                "enabled": True,
                "install_check": {"kind": "executable_on_path", "executable": "codex"},
                "health_check": {"kind": "command_probe", "timeout_seconds": 1, "degraded_on_failure": True},
                "compatible_roles": ["implementer"],
                "protocols": ["hermes-role-engine/v1"],
                "capabilities": ["structured_envelope"],
                "workspace_support": {"task_workspace": True},
                "session_support": {"tmux": True},
                "risk_ceiling": "L4",
                "risk_policy": {"max_without_human_approval": "L2"},
                "fallback_allowed": False,
            }
        ],
    }
    (config_dir / "backends.json").write_text(json.dumps(malformed_backends), encoding="utf-8")
    (config_dir / "roles.json").write_text((repo / "config/workers/full/roles.json").read_text(encoding="utf-8"), encoding="utf-8")
    malformed_registry = WorkerRegistry(tmp_repo, allow_staged=True)
    expect_error(WorkerRegistryError, "config_invalid", malformed_registry.load_backends)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/workers/full"
    config_dir.mkdir(parents=True, exist_ok=True)
    fallback_backends = {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "worker_backend_registry",
        "package_status": "active",
        "registry_authority": "project",
        "implicit_backend_fallback_allowed": False,
        "backends": [
            {
                "id": "primary",
                "name": "Primary Worker",
                "enabled": True,
                "adapter_type": "cli",
                "transport": "local_process",
                "install_check": {"kind": "executable_on_path", "executable": "primary-worker"},
                "health_check": {"kind": "command_probe", "timeout_seconds": 1, "degraded_on_failure": True},
                "compatible_roles": ["implementer"],
                "protocols": ["hermes-role-engine/v1"],
                "capabilities": ["structured_envelope"],
                "workspace_support": {"task_workspace": True},
                "session_support": {"tmux": True},
                "risk_ceiling": "L4",
                "risk_policy": {"max_without_human_approval": "L2"},
                "fallback_allowed": False,
            },
            {
                "id": "fallback",
                "name": "Fallback Worker",
                "enabled": True,
                "adapter_type": "cli",
                "transport": "local_process",
                "install_check": {"kind": "executable_on_path", "executable": "fallback-worker"},
                "health_check": {"kind": "command_probe", "timeout_seconds": 1, "degraded_on_failure": True},
                "compatible_roles": ["implementer"],
                "protocols": ["hermes-role-engine/v1"],
                "capabilities": ["structured_envelope"],
                "workspace_support": {"task_workspace": True},
                "session_support": {"tmux": True},
                "risk_ceiling": "L4",
                "risk_policy": {"max_without_human_approval": "L2"},
                "fallback_allowed": False,
            },
        ],
    }
    fallback_roles = {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "worker_role_registry",
        "package_status": "active",
        "registry_authority": "project",
        "implicit_backend_fallback_allowed": False,
        "roles": [
            {
                "role": "implementer",
                "protocol": "hermes-role-engine/v1",
                "required_capabilities": ["structured_envelope"],
                "preferred_backend": "primary",
                "explicit_fallback_backends": ["fallback"],
                "fallback_allowed_failure_classes": ["unavailable"],
                "fallback_forbidden_when": ["risk_level:L3", "parallel_worker_task"],
                "selection_record_required": True,
                "capability_negotiation_report_required_on_block": True,
            }
        ],
    }
    (config_dir / "backends.json").write_text(json.dumps(fallback_backends), encoding="utf-8")
    (config_dir / "roles.json").write_text(json.dumps(fallback_roles), encoding="utf-8")

    fallback_negotiator = CapabilityNegotiator(
        WorkerRegistry(
            tmp_repo,
            allow_staged=True,
            availability_overrides={
                "primary": {"available": False, "reasons": ["install_check_failed"]},
                "fallback": {"available": True, "reasons": []},
            },
        )
    )
    fallback_selected = fallback_negotiator.negotiate("implementer")
    assert fallback_selected["selection_record"]["negotiation_status"] == "fallback_selected", fallback_selected
    assert fallback_selected["selection_record"]["selected_backend"] == "fallback", fallback_selected
    assert fallback_selected["selection_record"]["fallback_used"] is True, fallback_selected
    assert fallback_selected["negotiation_report"]["checked_backends"] == ["primary", "fallback"], fallback_selected
    assert fallback_selected["negotiation_report"]["fallback_selected"] == "fallback", fallback_selected

    fallback_blocked = fallback_negotiator.negotiate(
        "implementer",
        negotiation_context={"risk_level": "L3"},
    )
    assert fallback_blocked["selection_record"]["negotiation_status"] == "blocked", fallback_blocked
    assert fallback_blocked["selection_record"]["blocked_reason"] == "backend_unavailable", fallback_blocked
    assert "fallback_forbidden_by_policy:risk_level:L3" in fallback_blocked["negotiation_report"]["fallback_blocked_reasons"], fallback_blocked

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/workers/full"
    config_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/workers/full/backends.json", config_dir / "backends.json")
    shutil.copy2(repo / "config/workers/full/roles.json", config_dir / "roles.json")
    cached_registry = WorkerRegistry(tmp_repo, allow_staged=True)
    first_backends = cached_registry.load_backends()
    second_backends = cached_registry.load_backends()
    assert first_backends is second_backends

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/workers/full"
    config_dir.mkdir(parents=True, exist_ok=True)
    fake_bin = tmp_repo / "bin"
    fake_bin.mkdir()
    ok_script = fake_bin / "worker-ok"
    ok_script.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
    ok_script.chmod(0o755)
    bad_script = fake_bin / "worker-bad"
    bad_script.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
    bad_script.chmod(0o755)
    os.environ["PATH"] = f"{fake_bin}:{os.environ['PATH']}"

    availability_backends = {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "worker_backend_registry",
        "package_status": "active",
        "registry_authority": "project",
        "implicit_backend_fallback_allowed": False,
        "backends": [
            {
                "id": "ok",
                "name": "OK Worker",
                "enabled": True,
                "adapter_type": "cli",
                "transport": "local_process",
                "install_check": {"kind": "executable_on_path", "executable": "worker-ok"},
                "health_check": {"kind": "command_probe", "timeout_seconds": 1, "degraded_on_failure": True},
                "compatible_roles": ["implementer"],
                "protocols": ["hermes-role-engine/v1"],
                "capabilities": ["structured_envelope"],
                "workspace_support": {"task_workspace": True},
                "session_support": {"tmux": True},
                "risk_ceiling": "L4",
                "risk_policy": {"max_without_human_approval": "L2"},
                "fallback_allowed": False,
            },
            {
                "id": "missing",
                "name": "Missing Worker",
                "enabled": True,
                "adapter_type": "cli",
                "transport": "local_process",
                "install_check": {"kind": "executable_on_path", "executable": "worker-missing"},
                "health_check": {"kind": "command_probe", "timeout_seconds": 1, "degraded_on_failure": True},
                "compatible_roles": ["implementer"],
                "protocols": ["hermes-role-engine/v1"],
                "capabilities": ["structured_envelope"],
                "workspace_support": {"task_workspace": True},
                "session_support": {"tmux": True},
                "risk_ceiling": "L4",
                "risk_policy": {"max_without_human_approval": "L2"},
                "fallback_allowed": False,
            },
            {
                "id": "bad",
                "name": "Bad Worker",
                "enabled": True,
                "adapter_type": "cli",
                "transport": "local_process",
                "install_check": {"kind": "executable_on_path", "executable": "worker-bad"},
                "health_check": {"kind": "command_probe", "timeout_seconds": 1, "degraded_on_failure": True},
                "compatible_roles": ["implementer"],
                "protocols": ["hermes-role-engine/v1"],
                "capabilities": ["structured_envelope"],
                "workspace_support": {"task_workspace": True},
                "session_support": {"tmux": True},
                "risk_ceiling": "L4",
                "risk_policy": {"max_without_human_approval": "L2"},
                "fallback_allowed": False,
            },
        ],
    }
    (config_dir / "backends.json").write_text(json.dumps(availability_backends), encoding="utf-8")
    (config_dir / "roles.json").write_text((repo / "config/workers/full/roles.json").read_text(encoding="utf-8"), encoding="utf-8")

    availability_registry = WorkerRegistry(tmp_repo, allow_staged=True)
    assert availability_registry.backend_availability("ok") == {"available": True, "reasons": []}
    assert availability_registry.backend_availability("missing") == {"available": False, "reasons": ["install_check_failed"]}
    assert availability_registry.backend_availability("bad") == {"available": False, "reasons": ["health_check_failed"]}

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    config_dir = tmp_repo / "config/workers/full"
    config_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/workers/full/backends.json", config_dir / "backends.json")
    shutil.copy2(repo / "config/workers/full/roles.json", config_dir / "roles.json")
    schema_missing_registry = WorkerRegistry(tmp_repo, allow_staged=True)
    expect_error(WorkerRegistryError, "config_invalid", schema_missing_registry.load_backends)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/workers/full"
    config_dir.mkdir(parents=True, exist_ok=True)
    malformed_roles = {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "worker_role_registry",
        "package_status": "active",
        "registry_authority": "project",
        "implicit_backend_fallback_allowed": False,
        "roles": [
            {
                "role": "implementer",
                "protocol": "hermes-role-engine/v1",
                "required_capabilities": ["structured_envelope"],
                "explicit_fallback_backends": [],
                "fallback_allowed_failure_classes": ["timeout"],
                "fallback_forbidden_when": ["risk_level:L3"],
                "selection_record_required": True,
                "capability_negotiation_report_required_on_block": True,
            }
        ],
    }
    (config_dir / "backends.json").write_text((repo / "config/workers/full/backends.json").read_text(encoding="utf-8"), encoding="utf-8")
    (config_dir / "roles.json").write_text(json.dumps(malformed_roles), encoding="utf-8")
    malformed_registry = WorkerRegistry(tmp_repo, allow_staged=True)
    expect_error(WorkerRegistryError, "config_invalid", malformed_registry.load_roles)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/workers/full"
    config_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/workers/full/backends.json", config_dir / "backends.json")
    shutil.copy2(repo / "config/workers/full/roles.json", config_dir / "roles.json")
    (config_dir / "backends.json").chmod(0)
    unreadable_registry = WorkerRegistry(tmp_repo, allow_staged=True)
    expect_error(WorkerRegistryError, "config_invalid", unreadable_registry.load_backends)
PY

test_done
