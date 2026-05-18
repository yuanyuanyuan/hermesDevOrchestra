#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="release-pipeline"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - <<'PY'
import sys

assert sys.version_info >= (3, 10), sys.version
import jsonschema  # noqa: F401
PY

python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/release/pipeline.json
python3 -m jsonschema config/schemas/orchestra.full.schema.json -i config/release/commands.json

FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS config/release/pipeline.json: release_pipeline_config" <<<"$FULL_VALIDATE_OUTPUT" || fail "full release pipeline contract validation failed" "release pipeline pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/release/commands.json: release_command_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "full release command registry contract validation failed" "release commands pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import os
import pathlib
import stat
import shutil
import sys
import tempfile

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_report import validate_artifact_definition
from orch_gateway import parse_args
from release_executor import ReleaseExecutor, ReleaseExecutorError
from release_pipeline import ReleasePipeline, ReleasePipelineError


def expect_error(code, func):
    try:
        func()
    except ReleasePipelineError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected ReleasePipelineError({code})")


def copy_schema(target_repo):
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / "config/schemas/orchestra.full.schema.json", schema_dir / "orchestra.full.schema.json")


def expect_executor_error(code, func):
    try:
        func()
    except ReleaseExecutorError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected ReleaseExecutorError({code})")


def prepare_active_repo(tmp_repo, pipeline_mutator=None, commands_mutator=None):
    copy_schema(tmp_repo)
    config_dir = tmp_repo / "config/release"
    config_dir.mkdir(parents=True, exist_ok=True)
    pipeline_data = json.loads((repo / "config/release/pipeline.json").read_text(encoding="utf-8"))
    commands_data = json.loads((repo / "config/release/commands.json").read_text(encoding="utf-8"))
    pipeline_data["enabled"] = True
    commands_data["enabled"] = True
    commands_data["package_status"] = "active"
    if pipeline_mutator is not None:
        pipeline_mutator(pipeline_data)
    if commands_mutator is not None:
        commands_mutator(commands_data)
    (config_dir / "pipeline.json").write_text(json.dumps(pipeline_data), encoding="utf-8")
    (config_dir / "commands.json").write_text(json.dumps(commands_data), encoding="utf-8")


def write_executable(path, content):
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


blocked = ReleasePipeline(repo, allow_staged=True)
expect_error("module_disabled", lambda: blocked.plan("dev_test"))

disabled = ReleasePipeline(repo, allow_staged=True, enabled=False)
expect_error("module_disabled", lambda: disabled.plan("dev_test"))

try:
    parse_args(["--project-id", "demo", "--host", "0.0.0.0"])
except SystemExit as exc:
    assert exc.code != 0, exc.code
else:
    raise AssertionError("expected non-loopback host rejection without --allow-network-binding")

localhost_args = parse_args(["--project-id", "demo", "--host", "127.0.0.1"])
assert localhost_args.host == "127.0.0.1", localhost_args

ipv6_loopback_args = parse_args(["--project-id", "demo", "--host", "::1"])
assert ipv6_loopback_args.host == "::1", ipv6_loopback_args

try:
    parse_args(["--project-id", "demo", "--host", "::ffff:127.0.0.1"])
except SystemExit as exc:
    assert exc.code != 0, exc.code
else:
    raise AssertionError("expected ipv6-mapped loopback to remain blocked without explicit override")

network_args = parse_args(
    ["--project-id", "demo", "--host", "0.0.0.0", "--allow-network-binding"]
)
assert network_args.host == "0.0.0.0", network_args
assert network_args.allow_network_binding is True, network_args

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    active_pipeline = ReleasePipeline(tmp_repo, package_root="config/release")
    plan = active_pipeline.plan("dev_test")
    assert plan["environment"]["id"] == "dev_test", plan
    assert plan["command"]["command_ref"] == "command://release/dev-test", plan
    assert plan["approval_required"] is False, plan
    assert plan["command_registry_ref"] == "config://release/commands", plan

    validated = active_pipeline.validate_command_refs()
    assert validated["command_registry_ref"] == "config://release/commands", validated
    assert validated["resolved_commands"]["command://release/dev-test"]["argv"] == ["project-release", "dev-test"], validated
    assert sorted(validated["environment_command_refs"]) == [
        "command://release/dev-test",
        "command://release/production",
        "command://release/staging",
    ], validated
    resolved = active_pipeline.resolve_command("command://release/dev-test")
    assert resolved["environment"]["id"] == "dev_test", resolved
    assert resolved["command"]["argv"] == ["project-release", "dev-test"], resolved

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)

    def dotted_mutator(data):
        data["commands"]["dev_test"] = "command://release/dev.test"
        data["environments"][0]["deploy_command_ref"] = "command://release/dev.test"

    def dotted_registry_mutator(data):
        data["commands"][0]["command_ref"] = "command://release/dev.test"

    prepare_active_repo(tmp_repo, pipeline_mutator=dotted_mutator, commands_mutator=dotted_registry_mutator)
    dotted = ReleasePipeline(tmp_repo, package_root="config/release")
    resolved = dotted.resolve_command("command://release/dev.test")
    assert resolved["command"]["command_ref"] == "command://release/dev.test", resolved
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
print("dotted")
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    result = executor.execute("command://release/dev.test")
    stdout_text = result["stored_outputs"][result["deployment_report"]["stdout_ref"]]
    assert "dotted" in stdout_text, stdout_text

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    malformed_pipeline = {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "release_pipeline_config",
        "enabled": True,
        "project_target_type": "project_defined",
        "command_registry_ref": "config://release/commands",
        "environments": [],
        "gates": {},
        "commands": {},
        "approval_policy": {},
        "rollback_policy": {},
        "evidence_requirements": {},
    }
    prepare_active_repo(tmp_repo, pipeline_mutator=lambda data: data.update(malformed_pipeline))
    malformed = ReleasePipeline(tmp_repo, package_root="config/release")
    expect_error("config_invalid", lambda: malformed.plan("dev_test"))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(
        tmp_repo,
        pipeline_mutator=lambda data: data["environments"][0].__setitem__("deploy_command_ref", "command://release/missing"),
    )
    unresolved = ReleasePipeline(tmp_repo, package_root="config/release")
    expect_error("command_not_registered", unresolved.validate_command_refs)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
import os
import sys

mode = sys.argv[1]
print(f"mode={mode}")
print(f"HERMES_RELEASE_ENV={os.environ.get('HERMES_RELEASE_ENV', '')}")
print(f"SECRET_TOKEN={os.environ.get('SECRET_TOKEN', '')}")
print("API_TOKEN=raw-secret-value")
print('{"token":"json-secret"}')
print("Authorization: Bearer bearer-secret")
print("https://example.com/releases/health")
print(f"cwd={os.getcwd()}")
print("PASSWORD=stderr-secret", file=sys.stderr)
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
        "SECRET_TOKEN": "top-secret-token",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    result = executor.execute("command://release/dev-test")
    validate_artifact_definition(tmp_repo, "deployment_report", result["deployment_report"])
    report = result["deployment_report"]
    assert report["deployment_status"] == "succeeded", report
    assert report["timed_out"] is False, report
    assert report["exit_code"] == 0, report
    assert report["environment"] == "dev_test", report
    assert report["executor"] == "gateway_release_executor", report
    assert report["approval_refs"] == [], report
    assert result["shell_used"] is False, result
    assert result["secret_scan_status"] == "findings_redacted", result
    stdout_text = result["stored_outputs"][report["stdout_ref"]]
    stderr_text = result["stored_outputs"][report["stderr_ref"]]
    assert "top-secret-token" not in stdout_text, stdout_text
    assert "raw-secret-value" not in stdout_text, stdout_text
    assert "json-secret" not in stdout_text, stdout_text
    assert "bearer-secret" not in stdout_text, stdout_text
    assert "stderr-secret" not in stderr_text, stderr_text
    assert str(tmp_repo) not in stdout_text, stdout_text
    assert "HERMES_RELEASE_ENV=stage" in stdout_text, stdout_text
    assert "SECRET_TOKEN=" in stdout_text, stdout_text
    assert "https://example.com/releases/health" in stdout_text, stdout_text

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    safe_dir = tmp_repo / "safe-bin"
    unsafe_dir = tmp_repo / "unsafe-bin"
    safe_dir.mkdir(parents=True, exist_ok=True)
    unsafe_dir.mkdir(parents=True, exist_ok=True)
    unsafe_dir.chmod(0o777)
    assert stat.S_IMODE(unsafe_dir.stat().st_mode) == 0o777
    write_executable(
        unsafe_dir / "project-release",
        """#!/usr/bin/env python3
print("unsafe-path")
""",
    )
    write_executable(
        safe_dir / "project-release",
        """#!/usr/bin/env python3
print("safe-path")
""",
    )
    env = {
        "PATH": f"{unsafe_dir}:{safe_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    result = executor.execute("command://release/dev-test")
    stdout_text = result["stored_outputs"][result["deployment_report"]["stdout_ref"]]
    assert "safe-path" in stdout_text, stdout_text
    assert "unsafe-path" not in stdout_text, stdout_text

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
import pathlib
import sys

marker = pathlib.Path("staging-ran")
if len(sys.argv) > 1 and sys.argv[1] == "staging":
    marker.write_text("ran", encoding="utf-8")
print("should-not-run")
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    expect_executor_error("approval_required", lambda: executor.execute("command://release/staging"))
    expect_executor_error("approval_required", lambda: executor.execute("command://release/staging", approval_ref="   "))
    assert not (tmp_repo / "staging-ran").exists(), "staging command ran before approval"

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    def env_requires_approval_only(data):
        data["commands"][1]["approval_policy"]["approval_refs_required_before_execution"] = False

    prepare_active_repo(tmp_repo, commands_mutator=env_requires_approval_only)
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
print("staging")
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    expect_executor_error("approval_required", lambda: executor.execute("command://release/staging"))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
import sys

print("failing release", file=sys.stderr)
sys.exit(7)
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    result = executor.execute("command://release/dev-test")
    assert result["deployment_report"]["deployment_status"] == "failed", result
    assert result["deployment_report"]["exit_code"] == 7, result

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)

    def timeout_mutator(data):
        for command in data["commands"]:
            if command["command_ref"] == "command://release/dev-test":
                command["timeout_seconds"] = 1
                command["kill_policy"]["graceful_signal"] = "INT"
                command["kill_policy"]["graceful_timeout_seconds"] = 0
                command["kill_policy"]["force_timeout_seconds"] = 0

    prepare_active_repo(tmp_repo, commands_mutator=timeout_mutator)
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
import signal
import time

def ignore_int(signum, frame):
    while True:
        time.sleep(0.1)

signal.signal(signal.SIGINT, ignore_int)
while True:
    time.sleep(0.1)
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    result = executor.execute("command://release/dev-test")
    report = result["deployment_report"]
    assert report["deployment_status"] == "timed_out", report
    assert report["timed_out"] is True, report
    assert result["termination_sequence"] == ["INT", "KILL"], result

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    outside_dir = pathlib.Path(tempfile.mkdtemp())

    def cwd_symlink_mutator(data):
        data["commands"][0]["cwd_ref"] = "project://root/linked-outside"

    prepare_active_repo(tmp_repo, commands_mutator=cwd_symlink_mutator)
    linked_dir = tmp_repo / "linked-outside"
    linked_dir.symlink_to(outside_dir, target_is_directory=True)
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
print("ok")
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    expect_executor_error("cwd_ref_invalid", lambda: executor.execute("command://release/dev-test"))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = pathlib.Path(tmp)
    prepare_active_repo(tmp_repo)
    bin_dir = tmp_repo / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    write_executable(
        bin_dir / "project-release",
        """#!/usr/bin/env python3
print("ok")
""",
    )
    env = {
        "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "stage",
    }
    executor = ReleaseExecutor(tmp_repo, project_root=tmp_repo, env=env)
    expect_executor_error("command_not_registered", lambda: executor.execute("command://release/missing"))
    expect_executor_error("command_ref_invalid", lambda: executor.execute("command://release/../dev-test"))
    expect_executor_error("command_ref_invalid", lambda: executor.execute("command://release/dev-test;echo-pwned"))
PY

test_done
