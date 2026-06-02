"""Actor token validation and authority-matrix checks for Gateway routes."""

from __future__ import annotations

import base64
import hmac
import json
import time
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
from typing import Any


ACTOR_TYPES = {"kimi", "gateway", "hermes_agents", "claude_codex", "user"}
DEFAULT_TOKEN_TTL_SECONDS = 300
DEFAULT_CLOCK_SKEW_SECONDS = 30


@dataclass(frozen=True)
class Actor:
    actor_type: str
    actor_id: str
    token_id: str
    approval_level: str | None = None
    protected_target_pattern: str | None = None


class ActorAuthError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ActorAuthError("invalid_actor_config", f"{path} must contain a JSON object")
    return data


def load_authority_matrix(repo_root: Path) -> dict[str, Any]:
    path = repo_root / "config/decisions/authority-matrix.json"
    data = load_json(path)
    capabilities = data.get("capabilities")
    if not isinstance(capabilities, dict) or len(capabilities) != 8:
        raise ActorAuthError("authority_matrix_load_failed", "authority matrix must define exactly 8 capabilities")
    for capability, actor_rules in capabilities.items():
        if not isinstance(capability, str) or not isinstance(actor_rules, dict):
            raise ActorAuthError("authority_matrix_load_failed", "capability rules must be objects")
        for actor_type in ACTOR_TYPES:
            if actor_rules.get(actor_type) not in {"allowed", "blocked", "requires_approval"}:
                raise ActorAuthError("authority_matrix_load_failed", f"{capability} missing rule for {actor_type}")
    return data


def load_actor_secrets(repo_root: Path) -> dict[str, Any]:
    path = repo_root / "config/decisions/actor-secrets.json"
    if not path.exists():
        path = repo_root / "config/decisions/actor-secrets.json.example"
    data = load_json(path)
    secrets = data.get("secrets")
    active_secret_id = data.get("active_secret_id")
    if not isinstance(secrets, dict) or not isinstance(active_secret_id, str):
        raise ActorAuthError("actor_secrets_load_failed", "actor secrets must define active_secret_id and secrets")
    if not isinstance(secrets.get(active_secret_id), str) or not secrets[active_secret_id]:
        raise ActorAuthError("actor_secrets_load_failed", "active actor secret is missing")
    return data


def sign(actor_type: str, actor_id: str, timestamp: int, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), f"{actor_type}{actor_id}{timestamp}".encode("utf-8"), sha256).hexdigest()


def issue_token(
    actor_type: str,
    actor_id: str,
    secret: str,
    timestamp: int | None = None,
    approval_level: str | None = None,
    protected_target_pattern: str | None = None,
) -> str:
    timestamp = int(time.time()) if timestamp is None else timestamp
    parts = [actor_type, actor_id, str(timestamp), sign(actor_type, actor_id, timestamp, secret)]
    if approval_level:
        parts.append(approval_level)
    if protected_target_pattern:
        parts.append(protected_target_pattern)
    return base64.urlsafe_b64encode(":".join(parts).encode("utf-8")).decode("ascii")


def validate_actor_token(token: str | None, secrets_config: dict[str, Any], revoked_tokens: set[str] | None = None, now: int | None = None) -> Actor:
    if not token:
        raise ActorAuthError("missing_actor_token", "X-Actor-Token is required")
    if revoked_tokens and token in revoked_tokens:
        raise ActorAuthError("actor_token_revoked", "actor token was revoked")
    try:
        raw = base64.urlsafe_b64decode(token.encode("ascii")).decode("utf-8")
    except Exception as exc:
        raise ActorAuthError("invalid_actor_token", "actor token is not valid base64") from exc
    parts = raw.split(":")
    if len(parts) < 4:
        raise ActorAuthError("invalid_actor_token", "actor token has invalid shape")
    actor_type, actor_id, timestamp_text, signature = parts[:4]
    if actor_type not in ACTOR_TYPES:
        raise ActorAuthError("invalid_actor_token", "actor type is unknown")
    if not actor_id or len(actor_id) < 3:
        raise ActorAuthError("invalid_actor_token", "actor id is invalid")
    try:
        timestamp = int(timestamp_text)
    except ValueError as exc:
        raise ActorAuthError("invalid_actor_token", "actor token timestamp is invalid") from exc

    now = int(time.time()) if now is None else now
    ttl = int(secrets_config.get("token_ttl_seconds") or DEFAULT_TOKEN_TTL_SECONDS)
    skew = int(secrets_config.get("clock_skew_seconds") or DEFAULT_CLOCK_SKEW_SECONDS)
    if abs(now - timestamp) > ttl + skew:
        raise ActorAuthError("actor_token_expired", "actor token expired")

    secrets = secrets_config.get("secrets") if isinstance(secrets_config.get("secrets"), dict) else {}
    secret = secrets.get(secrets_config.get("active_secret_id"))
    if not isinstance(secret, str):
        raise ActorAuthError("actor_secrets_load_failed", "active actor secret is missing")
    expected = sign(actor_type, actor_id, timestamp, secret)
    if not hmac.compare_digest(signature, expected):
        raise ActorAuthError("invalid_actor_token", "actor token signature is invalid")
    return Actor(
        actor_type=actor_type,
        actor_id=actor_id,
        token_id=sha256(token.encode("utf-8")).hexdigest(),
        approval_level=parts[4] if len(parts) > 4 and parts[4] else None,
        protected_target_pattern=parts[5] if len(parts) > 5 and parts[5] else None,
    )


def capability_status(matrix: dict[str, Any], actor_type: str, capability: str) -> str:
    capabilities = matrix.get("capabilities") if isinstance(matrix.get("capabilities"), dict) else {}
    actor_rules = capabilities.get(capability)
    if not isinstance(actor_rules, dict):
        return "not_defined"
    value = actor_rules.get(actor_type)
    return value if value in {"allowed", "blocked", "requires_approval"} else "blocked"


def authority_matrix_view(matrix: dict[str, Any], actor_type: str) -> dict[str, str]:
    capabilities = matrix.get("capabilities") if isinstance(matrix.get("capabilities"), dict) else {}
    return {capability: capability_status(matrix, actor_type, capability) for capability in sorted(capabilities)}


def authenticate_actor(app: Any, token: str | None) -> Actor | tuple[int, dict[str, Any]]:
    try:
        return validate_actor_token(token, app.actor_secrets, app.revoked_actor_tokens)
    except ActorAuthError as exc:
        status = 403 if exc.code == "actor_token_revoked" else 401
        return status, app.error(exc.code, exc.message)


def require_actor_capability(app: Any, actor: Actor, capability: str) -> tuple[int, dict[str, Any]] | None:
    status = capability_status(app.authority_matrix, actor.actor_type, capability)
    if status == "not_defined":
        body = app.error("capability_not_defined", "capability is not defined in authority matrix")
        body["capability"] = capability
        return 403, body
    if status == "blocked":
        error_code = "mutate_kanban_raw_state_blocked" if capability == "mutate_kanban_raw_state" else "actor_capability_denied"
        body = app.error(error_code, "actor capability denied")
        body.update({"actor": actor.actor_type, "required_capability": capability})
        return 403, body
    return None


def mutate_raw_kanban_state(app: Any, payload: dict[str, Any], token: str | None) -> tuple[int, dict[str, Any]]:
    actor = authenticate_actor(app, token)
    if isinstance(actor, tuple):
        return actor
    denied = require_actor_capability(app, actor, "mutate_kanban_raw_state")
    if denied is not None:
        return denied
    return 200, {"schema_version": "orchestra.v1", "status": "accepted", "operation": payload.get("operation")}


def worker_advance_denied(app: Any, actor_token: Any, task: dict[str, Any], assignment_token: Any) -> tuple[int, dict[str, Any]] | None:
    if not isinstance(actor_token, str):
        return None
    actor = authenticate_actor(app, actor_token)
    if isinstance(actor, tuple):
        return actor
    denied = require_actor_capability(app, actor, "advance_stage")
    if denied is not None:
        return denied
    if actor.actor_type == "claude_codex" and assignment_token != task.get("assignment_token"):
        return 403, app.error("actor_capability_denied", "assignment token is required for claude_codex stage advancement")
    return None
