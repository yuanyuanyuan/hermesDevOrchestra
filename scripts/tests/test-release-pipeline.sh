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
grep -Fq "PASS config/release/pipeline.json: release_pipeline_config" <<<"$FULL_VALIDATE_OUTPUT" || fail "release pipeline config was not validated" "release pipeline pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS config/release/commands.json: release_command_registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "release command registry was not validated" "release command registry pass" "$FULL_VALIDATE_OUTPUT"
grep -Fq "PASS release command refs: pipeline refs resolve through command registry" <<<"$FULL_VALIDATE_OUTPUT" || fail "release command refs did not resolve" "release command refs pass" "$FULL_VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import os
import stat
import sys
import tempfile
import textwrap
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from debate_report import validate_artifact_definition
from release_executor import _CAPTURE_LIMIT_BYTES, ReleaseExecutor, ReleaseExecutorError
from release_pipeline import ReleasePipeline, ReleasePipelineError


def expect_error(error_type, code: str, func):
    try:
        func()
    except error_type as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected {error_type.__name__}({code})")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def copy_schema(target_repo: Path) -> None:
    schema_dir = target_repo / "config/schemas"
    schema_dir.mkdir(parents=True, exist_ok=True)
    schema_dir.joinpath("orchestra.full.schema.json").write_text(
        (repo / "config/schemas/orchestra.full.schema.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )


def prepare_active_repo(tmp_repo: Path, pipeline_mutator=None, registry_mutator=None) -> None:
    copy_schema(tmp_repo)
    pipeline = load_json(repo / "config/release/pipeline.json")
    registry = load_json(repo / "config/release/commands.json")
    pipeline["enabled"] = True
    registry["enabled"] = True
    registry["package_status"] = "active"
    for entry in registry["commands"]:
        entry["enabled"] = True
    if pipeline_mutator is not None:
        pipeline_mutator(pipeline)
    if registry_mutator is not None:
        registry_mutator(registry)
    write_json(tmp_repo / "config/release/pipeline.json", pipeline)
    write_json(tmp_repo / "config/release/commands.json", registry)


def write_script(path: Path, body: str) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(body), encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return str(path)


def patch_command(registry: dict, command_ref: str, argv: list[str], timeout_seconds: int = 5) -> None:
    for entry in registry["commands"]:
        if entry["command_ref"] == command_ref:
            entry["argv"] = argv
            entry["timeout_seconds"] = timeout_seconds
            return
    raise AssertionError(f"command not found: {command_ref}")


def read_output(path: Path) -> str:
    return path.read_text(encoding="utf-8")


blocked = ReleasePipeline(repo)
exc = expect_error(ReleasePipelineError, "module_disabled", lambda: blocked.plan("dev_test"))
assert "allow_staged=True" in exc.message, exc.message

executor_blocked = ReleaseExecutor(repo)
exc = expect_error(ReleaseExecutorError, "module_disabled", lambda: executor_blocked.execute("command://release/dev-test"))
assert "allow_staged=True" in exc.message, exc.message

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    pipeline = ReleasePipeline(tmp_repo, allow_staged=True)
    validation = pipeline.validate_command_refs()
    assert validation["command_registry_ref"] == "config://release/commands", validation
    plan = pipeline.plan("staging")
    assert plan["environment"]["id"] == "staging", plan
    assert plan["deploy_command"]["command_ref"] == "command://release/staging", plan

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(
        tmp_repo,
        pipeline_mutator=lambda payload: payload["commands"].__setitem__("staging", "command://release/missing"),
    )
    pipeline = ReleasePipeline(tmp_repo, allow_staged=True)
    expect_error(ReleasePipelineError, "command_ref_not_found", pipeline.validate_command_refs)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(
        tmp_repo,
        registry_mutator=lambda payload: payload["commands"].append(
            {
                "command_ref": "command://release/dev-shell",
                "enabled": True,
                "description": "unsafe shell launcher",
                "argv": ["bash", "-lc", "echo hacked"],
                "cwd_ref": "project://root",
                "env_allowlist": ["PATH", "HOME"],
                "timeout_seconds": 5,
                "kill_policy": {
                    "graceful_signal": "TERM",
                    "graceful_timeout_seconds": 1,
                    "force_signal": "KILL",
                    "force_timeout_seconds": 1,
                },
                "output_capture_policy": {
                    "store": "cache_artifact",
                    "stdout_ref_required": True,
                    "stderr_ref_required": True,
                    "max_inline_bytes": 0,
                    "raw_output_in_audit_allowed": False,
                },
                "redaction_policy": {
                    "enabled": True,
                    "redact_env_not_in_allowlist": True,
                    "redact_secrets": True,
                    "redact_absolute_paths": True,
                },
                "approval_policy": {
                    "approval_refs_required_before_execution": False,
                    "authority_required": "none",
                    "fixed_phrase_required": False,
                },
            }
        ),
    )
    pipeline = ReleasePipeline(tmp_repo, allow_staged=True)
    expect_error(ReleasePipelineError, "unsafe_command", pipeline.validate_command_refs)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(
        tmp_repo,
        registry_mutator=lambda payload: payload["commands"].append(
            {
                "command_ref": "command://release/dev-shell-abs",
                "enabled": True,
                "description": "unsafe shell launcher absolute path",
                "argv": ["/bin/bash", "-lc", "echo hacked"],
                "cwd_ref": "project://root",
                "env_allowlist": ["PATH", "HOME"],
                "timeout_seconds": 5,
                "kill_policy": {
                    "graceful_signal": "TERM",
                    "graceful_timeout_seconds": 1,
                    "force_signal": "KILL",
                    "force_timeout_seconds": 1,
                },
                "output_capture_policy": {
                    "store": "cache_artifact",
                    "stdout_ref_required": True,
                    "stderr_ref_required": True,
                    "max_inline_bytes": 0,
                    "raw_output_in_audit_allowed": False,
                },
                "redaction_policy": {
                    "enabled": True,
                    "redact_env_not_in_allowlist": True,
                    "redact_secrets": True,
                    "redact_absolute_paths": True,
                },
                "approval_policy": {
                    "approval_refs_required_before_execution": False,
                    "authority_required": "none",
                    "fixed_phrase_required": False,
                },
            }
        ),
    )
    pipeline = ReleasePipeline(tmp_repo, allow_staged=True)
    expect_error(ReleasePipelineError, "unsafe_command", pipeline.validate_command_refs)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    registry = load_json(tmp_repo / "config/release/commands.json")
    for entry in registry["commands"]:
        if entry["command_ref"] == "command://release/dev-test":
            entry["approval_policy"] = {
                "approval_refs_required_before_execution": False,
                "authority_required": "none",
                "fixed_phrase_required": True,
            }
    write_json(tmp_repo / "config/release/commands.json", registry)
    pipeline = ReleasePipeline(tmp_repo, allow_staged=True)
    expect_error(ReleasePipelineError, "config_invalid", pipeline.validate_command_refs)

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    scripts_dir = tmp_repo / "scripts"
    success_script = write_script(
        scripts_dir / "success.py",
        """
        import os
        print("PATH_OK=" + ("yes" if os.environ.get("PATH") else "no"))
        print("HOME_OK=" + ("yes" if os.environ.get("HOME") else "no"))
        print("CI_VALUE=" + os.environ.get("CI", ""))
        print("REL_ENV=" + os.environ.get("HERMES_RELEASE_ENV", ""))
        print("CUSTOM_ENV=" + os.environ.get("CUSTOM_ENV", "<missing>"))
        print("SECRET_TOKEN=" + os.environ.get("SECRET_TOKEN", "<missing>"))
        print("LEAK=super-secret-value")
        print("ABS_PATH=/tmp/release-pipeline/sensitive.txt")
        """,
    )

    def registry_mutator(payload: dict) -> None:
        patch_command(payload, "command://release/dev-test", [sys.executable, success_script])

    prepare_active_repo(tmp_repo, registry_mutator=registry_mutator)
    executor = ReleaseExecutor(
        tmp_repo,
        allow_staged=True,
        runtime_env={
            "PATH": os.environ["PATH"],
            "HOME": str(tmp_repo),
            "CI": "1",
            "HERMES_RELEASE_ENV": "dev",
            "CUSTOM_ENV": "should-not-pass",
            "SECRET_TOKEN": "super-secret-value",
        },
    )
    result = executor.execute(
        "command://release/dev-test",
        approval_ref="state://runs/run-release-success/approvals/manual.json",
        run_id="run-release-success",
        gate_results={"approval_checked": False, "approval_ref_present": False, "custom_gate": "ok"},
        test_execution_report_refs=["state://runs/run-release-success/tests/report.json"],
    )
    validate_artifact_definition(tmp_repo, "deployment_report", result["deployment_report"])
    stdout_text = read_output(Path(result["stdout_path"]))
    stderr_text = read_output(Path(result["stderr_path"]))
    assert "CUSTOM_ENV=<missing>" in stdout_text, stdout_text
    assert "SECRET_TOKEN=<missing>" in stdout_text, stdout_text
    assert "LEAK=[REDACTED_SECRET]" in stdout_text, stdout_text
    assert "ABS_PATH=[REDACTED_PATH]" in stdout_text, stdout_text
    assert "super-secret-value" not in stdout_text, stdout_text
    assert stderr_text == "", stderr_text
    assert result["deployment_report"]["deployment_status"] == "succeeded", result["deployment_report"]
    assert result["deployment_report"]["stdout_ref"].startswith("cache://sha256:"), result["deployment_report"]
    assert result["deployment_report"]["gate_results"]["approval_checked"] is True, result["deployment_report"]
    assert result["deployment_report"]["gate_results"]["approval_ref_present"] is True, result["deployment_report"]
    assert result["deployment_report"]["gate_results"]["custom_gate"] == "ok", result["deployment_report"]
    assert result["allowed_env"] == {
        "PATH": os.environ["PATH"],
        "HOME": str(tmp_repo),
        "CI": "1",
        "HERMES_RELEASE_ENV": "dev",
    }, result["allowed_env"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    scripts_dir = tmp_repo / "scripts"
    binary_script = write_script(
        scripts_dir / "binary.py",
        """
        import sys
        sys.stdout.buffer.write(b"binary:\\xff\\n")
        sys.stdout.flush()
        """,
    )

    def registry_mutator(payload: dict) -> None:
        patch_command(payload, "command://release/dev-test", [sys.executable, binary_script])

    prepare_active_repo(tmp_repo, registry_mutator=registry_mutator)
    executor = ReleaseExecutor(tmp_repo, allow_staged=True)
    result = executor.execute("command://release/dev-test", run_id="run-release-binary")
    stdout_text = read_output(Path(result["stdout_path"]))
    assert "binary:" in stdout_text, stdout_text
    assert "\ufffd" in stdout_text, stdout_text

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    scripts_dir = tmp_repo / "scripts"
    redact_script = write_script(
        scripts_dir / "redact.py",
        """
        print("LEAK=abcdef")
        """,
    )

    def registry_mutator(payload: dict) -> None:
        patch_command(payload, "command://release/dev-test", [sys.executable, redact_script])

    prepare_active_repo(tmp_repo, registry_mutator=registry_mutator)
    executor = ReleaseExecutor(
        tmp_repo,
        allow_staged=True,
        runtime_env={
            "PATH": os.environ["PATH"],
            "HOME": str(tmp_repo),
            "CI": "1",
            "HERMES_RELEASE_ENV": "dev",
            "SHORT_SECRET": "abc",
            "LONG_SECRET": "abcdef",
        },
    )
    result = executor.execute("command://release/dev-test", run_id="run-release-redact")
    stdout_text = read_output(Path(result["stdout_path"]))
    assert "LEAK=[REDACTED_SECRET]" in stdout_text, stdout_text
    assert "def" not in stdout_text, stdout_text

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    scripts_dir = tmp_repo / "scripts"
    big_output_script = write_script(
        scripts_dir / "big-output.py",
        """
        import sys
        payload = ("A" * (1024 * 1024 + 4096)).encode("utf-8")
        sys.stdout.buffer.write(payload)
        sys.stdout.flush()
        """,
    )

    def registry_mutator(payload: dict) -> None:
        patch_command(payload, "command://release/dev-test", [sys.executable, big_output_script])

    prepare_active_repo(tmp_repo, registry_mutator=registry_mutator)
    executor = ReleaseExecutor(tmp_repo, allow_staged=True)
    result = executor.execute("command://release/dev-test", run_id="run-release-big-output")
    stdout_text = read_output(Path(result["stdout_path"]))
    assert stdout_text.endswith("[OUTPUT_TRUNCATED]"), len(stdout_text)
    assert len(stdout_text.encode("utf-8")) <= _CAPTURE_LIMIT_BYTES + 64, len(stdout_text.encode("utf-8"))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    scripts_dir = tmp_repo / "scripts"
    fail_script = write_script(
        scripts_dir / "fail.py",
        """
        import sys
        print("release failed")
        sys.exit(7)
        """,
    )

    def registry_mutator(payload: dict) -> None:
        patch_command(payload, "command://release/dev-test", [sys.executable, fail_script])

    prepare_active_repo(tmp_repo, registry_mutator=registry_mutator)
    executor = ReleaseExecutor(tmp_repo, allow_staged=True)
    result = executor.execute("command://release/dev-test", run_id="run-release-fail")
    assert result["deployment_report"]["deployment_status"] == "failed", result["deployment_report"]
    assert result["deployment_report"]["exit_code"] == 7, result["deployment_report"]
    expect_error(
        ReleaseExecutorError,
        "validation_error",
        lambda: executor.execute("command://release/dev-test", run_id="../run-release-fail"),
    )

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    scripts_dir = tmp_repo / "scripts"
    slow_script = write_script(
        scripts_dir / "slow.py",
        """
        import time
        print("starting", flush=True)
        time.sleep(2)
        print("finished", flush=True)
        """,
    )

    def registry_mutator(payload: dict) -> None:
        patch_command(payload, "command://release/dev-test", [sys.executable, slow_script], timeout_seconds=1)

    prepare_active_repo(tmp_repo, registry_mutator=registry_mutator)
    executor = ReleaseExecutor(tmp_repo, allow_staged=True)
    result = executor.execute("command://release/dev-test", run_id="run-release-timeout")
    validate_artifact_definition(tmp_repo, "deployment_report", result["deployment_report"])
    assert result["deployment_report"]["deployment_status"] == "timed_out", result["deployment_report"]
    assert result["deployment_report"]["timed_out"] is True, result["deployment_report"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    scripts_dir = tmp_repo / "scripts"
    staging_script = write_script(
        scripts_dir / "staging.py",
        """
        print("deploy staging")
        """,
    )

    def registry_mutator(payload: dict) -> None:
        patch_command(payload, "command://release/staging", [sys.executable, staging_script])
        patch_command(payload, "command://release/production", [sys.executable, staging_script])

    prepare_active_repo(tmp_repo, registry_mutator=registry_mutator)
    executor = ReleaseExecutor(tmp_repo, allow_staged=True)
    expect_error(ReleaseExecutorError, "approval_required", lambda: executor.execute("command://release/staging", run_id="run-release-approval"))
    expect_error(
        ReleaseExecutorError,
        "approval_required",
        lambda: executor.execute(
            "command://release/production",
            approval_ref="state://runs/run-release-production/approvals/production.json",
            run_id="run-release-production",
        ),
    )
    production = executor.execute(
        "command://release/production",
        approval_ref="state://runs/run-release-production-ok/approvals/fixed-phrase:APPROVE-PRODUCTION.json",
        run_id="run-release-production-ok",
    )
    assert production["deployment_report"]["approval_checked_before_execution"] is True, production["deployment_report"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(tmp_repo)
    executor = ReleaseExecutor(tmp_repo, allow_staged=True)
    expect_error(ReleaseExecutorError, "command_ref_not_found", lambda: executor.execute("command://release/not-registered"))

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_active_repo(
        tmp_repo,
        registry_mutator=lambda payload: payload.__setitem__("arbitrary_shell_allowed", True),
    )
    pipeline = ReleasePipeline(tmp_repo, allow_staged=True)
    expect_error(ReleasePipelineError, "config_invalid", pipeline.validate_command_refs)
PY

assert_contains 'default="127.0.0.1"' "$REPO_ROOT/scripts/lib/orch_gateway.py" "Gateway default host must remain loopback"

test_done
