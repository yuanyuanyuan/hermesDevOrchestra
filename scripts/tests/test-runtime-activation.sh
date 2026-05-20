#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="runtime-activation"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

VALIDATOR="$REPO_ROOT/scripts/bin/orch-full-contract-validate"
VALIDATE_OUTPUT="$("$VALIDATOR" --repo "$REPO_ROOT")"
grep -Fq "PASS runtime family activation: activated families satisfy cutover evidence and checks" <<<"$VALIDATE_OUTPUT" || fail "runtime activation config was not validated" "runtime activation validator pass" "$VALIDATE_OUTPUT"

python3 - "$REPO_ROOT" <<'PY'
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from runtime_activation import RuntimeActivation, RuntimeActivationError


def expect_error(code: str, func):
    try:
        func()
    except RuntimeActivationError as exc:
        assert exc.code == code, (exc.code, code, exc.message)
        return exc
    raise AssertionError(f"expected RuntimeActivationError({code})")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def prepare_repo(tmp_repo: Path, activation_mutator=None) -> None:
    shutil.copytree(repo / "config", tmp_repo / "config")
    shutil.copytree(repo / ".workflow", tmp_repo / ".workflow")
    activation_path = tmp_repo / "config/cutover/runtime-family-activation.json"
    payload = load_json(activation_path)
    if activation_mutator is not None:
        activation_mutator(payload)
    write_json(activation_path, payload)


def mutate_activation(tmp_repo: Path, mutator) -> None:
    activation_path = tmp_repo / "config/cutover/runtime-family-activation.json"
    payload = load_json(activation_path)
    mutator(payload)
    write_json(activation_path, payload)


def invalid_activation_case(expected_code: str, mutator) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_repo = Path(tmp)
        prepare_repo(tmp_repo)
        mutator(tmp_repo)
        expect_error(expected_code, lambda: RuntimeActivation(tmp_repo).summary())


activation = RuntimeActivation(repo)
summary = activation.summary()
assert summary["active_family_ids"] == ["closeout_and_self_evolution", "gateway_authority"], summary
assert activation.default_allow_staged("full-schema-cutover") is True
assert activation.default_allow_staged("self-evolution") is True
assert activation.default_allow_staged("release-pipeline") is False

with tempfile.TemporaryDirectory() as tmp:
    tmp_repo = Path(tmp)
    prepare_repo(tmp_repo, lambda payload: payload["activated_families"][0]["evidence"].remove("explicit_cutover_decision"))
    expect_error("activation_blocked", lambda: RuntimeActivation(tmp_repo).summary())

invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: (tmp_repo / "config/cutover/runtime-family-activation.json").unlink(),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: (tmp_repo / "config/cutover/runtime-family-activation.json").write_text("{bad json", encoding="utf-8"),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(tmp_repo, lambda payload: payload.__setitem__("schema_version", "orchestra.v1")),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(tmp_repo, lambda payload: payload.__setitem__("artifact_type", "wrong_type")),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(tmp_repo, lambda payload: payload.__setitem__("activation_policy_ref", "config://wrong/policy")),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(tmp_repo, lambda payload: payload.__setitem__("default_runtime_mode", "global_cutover")),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(tmp_repo, lambda payload: payload.__setitem__("activated_families", [])),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(
        tmp_repo,
        lambda payload: payload.__setitem__("activated_families", [*payload["activated_families"], payload["activated_families"][0]]),
    ),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(
        tmp_repo,
        lambda payload: payload["activated_families"][0].__setitem__("decision_ref", "repo://AGENTS.md"),
    ),
)
invalid_activation_case(
    "config_invalid",
    lambda tmp_repo: mutate_activation(
        tmp_repo,
        lambda payload: payload["activated_families"][0].__setitem__("decision_ref", "repo://.workflow/knowledge/../../AGENTS.md"),
    ),
)

with tempfile.TemporaryDirectory() as tmp:
    tmp_root = Path(tmp)
    broken_repo = tmp_root / "repo"
    prepare_repo(broken_repo, lambda payload: payload.__setitem__("schema_version", "orchestra.v0"))
    env_backup = {key: os.environ.get(key) for key in ("HOME", "STATE_ROOT", "AUDIT_ROOT")}
    os.environ["HOME"] = str(tmp_root / "home")
    os.environ["STATE_ROOT"] = str(tmp_root / "state")
    os.environ["AUDIT_ROOT"] = str(tmp_root / "audit")
    from orch_gateway import GatewayApp
    try:
        app = GatewayApp("runtime-activation-unit", "http://127.0.0.1:9")
        app.repo_root = broken_repo
        app.runtime_activation = RuntimeActivation(broken_repo)
        capabilities = app.capabilities()
        assert "error" in capabilities["runtime_activation"], capabilities
        assert app.module_allow_staged("full-schema-cutover", {}) is False
        assert app.module_allow_staged("release-pipeline", {}) is False
    finally:
        for key, value in env_backup.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
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

PROJECT_ID="runtime-activation-gateway"
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

python3 - "$BASE_URL" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url = sys.argv[1]


def post(path: str, payload: dict, *, expect_status: int = 200) -> dict:
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            body = json.loads(response.read().decode("utf-8"))
            assert response.status == expect_status, (response.status, body)
            return body
    except urllib.error.HTTPError as exc:
        body = json.loads(exc.read().decode("utf-8"))
        assert exc.code == expect_status, (exc.code, expect_status, body)
        return body


with urllib.request.urlopen(f"{base_url}/orchestra/capabilities", timeout=5) as response:
    capabilities = json.loads(response.read().decode("utf-8"))

runtime_activation = capabilities["runtime_activation"]
assert runtime_activation["active_family_ids"] == ["closeout_and_self_evolution", "gateway_authority"], runtime_activation
assert runtime_activation["module_defaults"]["full-schema-cutover"] == "gateway_authority", runtime_activation
assert runtime_activation["module_defaults"]["self-evolution"] == "closeout_and_self_evolution", runtime_activation

validation = post(
    "/orchestra/modules/full-schema-validation/validate-all",
    {"authority": "gateway_local_runtime"},
)
assert validation["result"]["ok"] is True, validation

cutover = post(
    "/orchestra/modules/full-schema-cutover/evaluate-family",
    {"authority": "gateway_local_runtime", "family_id": "gateway_authority"},
)
assert cutover["result"]["family_id"] == "gateway_authority", cutover

performance = post(
    "/orchestra/modules/performance-slo/evaluate",
    {
        "authority": "gateway_local_runtime",
        "component_id": "gateway_api",
        "observed": {
            "health_p95_ms": 10,
            "capabilities_p95_ms": 10,
            "status_projection_p95_ms": 10,
            "tasks_projection_p95_ms": 10,
            "event_poll_p95_ms": 10,
            "mutating_command_ack_p95_ms": 10,
        },
    },
)
assert performance["result"]["budget_status"] == "on_budget", performance

fixture = post(
    "/orchestra/modules/fixture-policy/validate-contract-fixture",
    {
        "authority": "gateway_local_runtime",
        "family_id": "debate",
        "fixture": {
            "fixture_name": "valid_debate_member_opinion",
            "fixture_kind": "contract_fixture",
            "fixture_backend": "none",
            "degraded_fixture_only": False,
            "completion_evidence_allowed": False,
            "release_evidence_allowed": False,
            "test_scope": "integration",
        },
    },
)
assert fixture["result"]["family_id"] == "debate", fixture

degradation = post(
    "/orchestra/modules/degradation-policy/build-record",
    {
        "authority": "gateway_local_runtime",
        "degradation_status": "degraded",
        "degradation_class": "required_evidence_degraded",
        "cause": "focused activation test",
        "affected_evidence_refs": ["state://runs/run-1/test_execution_report.json"],
        "recovery_options": ["rerun-tests"],
    },
)
assert degradation["result"]["degradation_status"] == "degraded", degradation

self_evolution = post(
    "/orchestra/modules/self-evolution/list-pending",
    {"authority": "gateway_local_review", "queue_items": []},
)
assert self_evolution["result"]["items"] == [], self_evolution

inactive_default = post(
    "/orchestra/modules/release-pipeline/load-pipeline",
    {"authority": "gateway_local_runtime"},
    expect_status=400,
)
assert inactive_default["error"]["code"] == "module_disabled", inactive_default

inactive_override = post(
    "/orchestra/modules/release-pipeline/load-pipeline",
    {"authority": "gateway_local_runtime", "allow_staged": True},
)
assert inactive_override["result"]["command_registry_ref"] == "config://release/commands", inactive_override
PY

test_done
