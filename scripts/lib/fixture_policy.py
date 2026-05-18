from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


class FixturePolicyError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class FixturePolicy:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/testing",
        allow_staged: bool = False,
        enabled: bool = True,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self._policy: dict[str, Any] | None = None

    def load_policy(self) -> dict[str, Any]:
        self._require_enabled()
        if self._policy is not None:
            return self._policy

        data = self._load_json("full-fixture-policy.json")
        self._validate_definition("full_fixture_policy", data)
        self._require_package_active(data, "full-fixture-policy.json")

        families = data.get("fixture_families")
        if not isinstance(families, list) or not families:
            raise FixturePolicyError("config_invalid", "full-fixture-policy.json fixture_families must be a non-empty list")

        family_index: dict[str, dict[str, Any]] = {}
        for family in families:
            if not isinstance(family, dict):
                raise FixturePolicyError("config_invalid", "fixture family entries must be objects")
            family_id = family.get("family_id")
            if not isinstance(family_id, str) or not family_id:
                raise FixturePolicyError("config_invalid", "fixture family is missing family_id")
            if family_id in family_index:
                raise FixturePolicyError("config_invalid", f"fixture family {family_id} is defined more than once")
            family_index[family_id] = family

        required_markers = data.get("required_markers")
        if not isinstance(required_markers, list) or not all(isinstance(item, str) and item for item in required_markers):
            raise FixturePolicyError("config_invalid", "full-fixture-policy.json required_markers must be a non-empty string list")

        self._policy = {**data, "family_index": family_index}
        return self._policy

    def validate_contract_fixture(self, family_id: str, fixture: dict[str, Any]) -> dict[str, Any]:
        policy = self.load_policy()
        family = self._require_family(policy, family_id)
        normalized = self._normalize_fixture(policy, fixture)

        if normalized["fixture_kind"] != "contract_fixture":
            raise FixturePolicyError("fixture_kind_invalid", "contract fixtures must use fixture_kind=contract_fixture")
        if normalized["fixture_name"] not in family["contract_fixture_examples"]:
            raise FixturePolicyError(
                "fixture_unknown",
                f"{normalized['fixture_name']} is not a declared contract fixture for family {family_id}",
            )
        if normalized["fixture_backend"] != "none":
            raise FixturePolicyError("fixture_backend_invalid", "contract fixtures must use fixture_backend=none")
        if normalized["degraded_fixture_only"] is not False:
            raise FixturePolicyError("fixture_marker_invalid", "contract fixtures must set degraded_fixture_only=false")
        self._require_evidence_blocked(normalized)

        return {
            "family_id": family_id,
            **normalized,
        }

    def validate_runtime_fake_adapter(self, family_id: str, fixture: dict[str, Any]) -> dict[str, Any]:
        policy = self.load_policy()
        family = self._require_family(policy, family_id)
        normalized = self._normalize_fixture(policy, fixture)

        if normalized["fixture_kind"] != "runtime_fake_adapter":
            raise FixturePolicyError("fixture_kind_invalid", "runtime fake adapters must use fixture_kind=runtime_fake_adapter")
        if normalized["fixture_name"] != normalized["fixture_backend"]:
            raise FixturePolicyError("fixture_backend_invalid", "runtime fake adapters must keep fixture_name and fixture_backend aligned")
        if normalized["fixture_backend"] not in family["runtime_fake_adapters"]:
            raise FixturePolicyError(
                "fixture_backend_unknown",
                f"{normalized['fixture_backend']} is not a declared runtime fake adapter for family {family_id}",
            )
        if normalized["degraded_fixture_only"] is not True:
            raise FixturePolicyError("runtime_fake_not_degraded", "runtime fake adapters must set degraded_fixture_only=true")
        self._require_evidence_blocked(normalized)

        return {
            "family_id": family_id,
            **normalized,
            "degraded": True,
            "required_degradation_class": family["required_degradation_class"],
            "must_emit_degradation_record": True,
        }

    def _normalize_fixture(self, policy: dict[str, Any], fixture: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(fixture, dict):
            raise FixturePolicyError("validation_error", "fixture must be an object")

        for marker in policy["required_markers"]:
            if marker not in fixture:
                raise FixturePolicyError("fixture_marker_missing", f"fixture is missing required marker {marker}")

        normalized = {
            "fixture_name": fixture.get("fixture_name"),
            "fixture_kind": fixture.get("fixture_kind"),
            "fixture_backend": fixture.get("fixture_backend"),
            "degraded_fixture_only": fixture.get("degraded_fixture_only"),
            "completion_evidence_allowed": fixture.get("completion_evidence_allowed"),
            "release_evidence_allowed": fixture.get("release_evidence_allowed"),
            "test_scope": fixture.get("test_scope"),
        }

        for key in ("fixture_name", "fixture_kind", "fixture_backend", "test_scope"):
            value = normalized[key]
            if not isinstance(value, str) or not value:
                raise FixturePolicyError("validation_error", f"{key} must be a non-empty string")
        for key in ("degraded_fixture_only", "completion_evidence_allowed", "release_evidence_allowed"):
            value = normalized[key]
            if not isinstance(value, bool):
                raise FixturePolicyError("validation_error", f"{key} must be a boolean")
        return normalized

    def _require_evidence_blocked(self, normalized: dict[str, Any]) -> None:
        if normalized["completion_evidence_allowed"] is not False:
            raise FixturePolicyError("completion_evidence_forbidden", "fixtures cannot satisfy completion evidence")
        if normalized["release_evidence_allowed"] is not False:
            raise FixturePolicyError("release_evidence_forbidden", "fixtures cannot satisfy release evidence")

    def _require_family(self, policy: dict[str, Any], family_id: str) -> dict[str, Any]:
        if not isinstance(family_id, str) or not family_id:
            raise FixturePolicyError("validation_error", "family_id must be a non-empty string")
        family = policy["family_index"].get(family_id)
        if family is None:
            raise FixturePolicyError("fixture_family_unknown", f"unknown fixture family: {family_id}")
        return family

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise FixturePolicyError("module_disabled", "fixture policy is disabled")

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise FixturePolicyError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise FixturePolicyError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise FixturePolicyError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise FixturePolicyError("config_invalid", f"{filename} is missing") from exc
        if not isinstance(data, dict):
            raise FixturePolicyError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise FixturePolicyError("config_invalid", exc.message) from exc
