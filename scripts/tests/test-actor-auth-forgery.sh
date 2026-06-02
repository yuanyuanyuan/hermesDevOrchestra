#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="actor-auth-forgery"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import base64
import pathlib
import time
import sys

repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))
from actor_auth import ActorAuthError, issue_token, load_actor_secrets, validate_actor_token

secrets = load_actor_secrets(repo)
secret = secrets["secrets"][secrets["active_secret_id"]]
valid = issue_token("kimi", "kimi-agent", secret, timestamp=int(time.time()))
actor = validate_actor_token(valid, secrets)
assert actor.actor_type == "kimi"
assert actor.actor_id == "kimi-agent"

forged = base64.urlsafe_b64encode(b"kimi:kimi-agent:2000000000:not-a-real-signature").decode("ascii")
try:
    validate_actor_token(forged, secrets, now=2000000000)
except ActorAuthError as exc:
    assert exc.code == "invalid_actor_token", exc.code
else:
    raise AssertionError("forged token was accepted")

expired = issue_token("kimi", "kimi-agent", secret, timestamp=100)
try:
    validate_actor_token(expired, secrets, now=1000)
except ActorAuthError as exc:
    assert exc.code == "actor_token_expired", exc.code
else:
    raise AssertionError("expired token was accepted")

try:
    validate_actor_token(valid, secrets, revoked_tokens={valid})
except ActorAuthError as exc:
    assert exc.code == "actor_token_revoked", exc.code
else:
    raise AssertionError("revoked token was accepted")
PY

test_done
