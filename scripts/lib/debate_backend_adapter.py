from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class DebateBackendAdapterError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class DebateBackendAdapterRegistry:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/debate/full",
        allow_staged: bool = False,
        enabled: bool = True,
        adapter_overrides: dict[str, Any] | None = None,
    ) -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root
        self.allow_staged = allow_staged
        self.enabled = enabled
        self.adapter_overrides = adapter_overrides or {}
        self._policy: dict[str, Any] | None = None

    def load_policy(self) -> dict[str, Any]:
        self._require_enabled()
        policy = self._load_json("backend-policy.json")
        self._require_package_active(policy, "backend-policy.json")

        backends = policy.get("backends")
        if not isinstance(backends, list) or not backends:
            raise DebateBackendAdapterError("config_invalid", "backend-policy.json must define backends")
        selection_order = policy.get("backend_selection_order")
        if not isinstance(selection_order, list) or not selection_order:
            raise DebateBackendAdapterError("config_invalid", "backend-policy.json must define backend_selection_order")

        backend_map: dict[str, dict[str, Any]] = {}
        for entry in backends:
            if not isinstance(entry, dict):
                raise DebateBackendAdapterError("config_invalid", "backend entries must be objects")
            backend_id = self._require_string(entry, "id", "backend entry")
            self._require_string(entry, "family", f"backend {backend_id}")
            if not isinstance(entry.get("enabled"), bool):
                raise DebateBackendAdapterError("config_invalid", f"backend {backend_id} is missing enabled")
            allowed_stages = entry.get("allowed_stages")
            if not isinstance(allowed_stages, list) or not all(isinstance(item, str) and item for item in allowed_stages):
                raise DebateBackendAdapterError("config_invalid", f"backend {backend_id} is missing allowed_stages")
            backend_map[backend_id] = entry

        self._policy = {
            **policy,
            "backend_map": backend_map,
        }
        return self._policy

    def select_backend(self, stage: str, preferred_backend_id: str | None = None) -> dict[str, Any]:
        policy = self.load_policy()
        if not isinstance(stage, str) or not stage:
            raise DebateBackendAdapterError("validation_error", "stage must be a non-empty string")
        if preferred_backend_id is not None:
            backend = self._candidate_backend(policy["backend_map"], preferred_backend_id, stage)
            if backend is None:
                raise DebateBackendAdapterError(
                    "backend_unavailable",
                    f"preferred backend {preferred_backend_id} is not enabled for stage {stage}",
                )
            return backend

        for selector in policy["backend_selection_order"]:
            if selector == "project_configured_real_backend":
                backend = self._first_matching_backend(
                    policy["backends"],
                    stage,
                    include_template=False,
                    require_strong_evidence=True,
                )
                if backend is not None:
                    return backend
            elif selector == "package_fallback_backend":
                backend = self._first_matching_backend(
                    policy["backends"],
                    stage,
                    include_template=False,
                    require_strong_evidence=False,
                )
                if backend is not None:
                    return backend
            else:
                backend = self._candidate_backend(policy["backend_map"], selector, stage)
                if backend is not None:
                    return backend

        raise DebateBackendAdapterError("backend_unavailable", f"no debate backend is enabled for stage {stage}")

    def get_adapter(self, backend_entry: dict[str, Any]) -> Any:
        backend_id = self._require_string(backend_entry, "id", "backend entry")
        override = self.adapter_overrides.get(backend_id)
        if override is not None:
            return override

        family = self._require_string(backend_entry, "family", f"backend {backend_id}")
        if family == "template":
            return TemplateFixtureDebateAdapter(backend_entry)
        raise DebateBackendAdapterError("backend_unsupported", f"backend family {family} is not implemented in Sprint 3")

    def _candidate_backend(
        self,
        backend_map: dict[str, dict[str, Any]],
        backend_id: str,
        stage: str,
    ) -> dict[str, Any] | None:
        backend = backend_map.get(backend_id)
        if backend is None:
            return None
        if not backend["enabled"]:
            return None
        if stage not in backend["allowed_stages"]:
            return None
        return backend

    def _first_matching_backend(
        self,
        backends: list[dict[str, Any]],
        stage: str,
        include_template: bool,
        require_strong_evidence: bool,
    ) -> dict[str, Any] | None:
        for backend in backends:
            if not backend["enabled"]:
                continue
            if stage not in backend["allowed_stages"]:
                continue
            if backend["family"] == "template" and not include_template:
                continue
            if require_strong_evidence and not backend.get("counts_as_strong_evidence", False):
                continue
            return backend
        return None

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise DebateBackendAdapterError("module_disabled", "debate backend adapters are disabled")

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise DebateBackendAdapterError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise DebateBackendAdapterError("config_invalid", f"{filename} is missing") from exc
        if not isinstance(data, dict):
            raise DebateBackendAdapterError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _require_package_active(self, data: dict[str, Any], filename: str) -> None:
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise DebateBackendAdapterError("config_invalid", f"{filename} is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise DebateBackendAdapterError(
                "package_not_active",
                f"{filename} package_status={package_status} is not active; allow_staged=True is required",
            )

    def _require_string(self, data: dict[str, Any], key: str, label: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise DebateBackendAdapterError("config_invalid", f"{label} is missing {key}")
        return value


class TemplateFixtureDebateAdapter:
    def __init__(self, backend_entry: dict[str, Any]) -> None:
        self.backend_entry = backend_entry

    def invoke(self, invocation: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
        if invocation.get("backend_id") != self.backend_entry.get("id"):
            raise DebateBackendAdapterError("backend_mismatch", "invocation backend_id does not match adapter backend")

        timestamp = datetime.now(timezone.utc).isoformat()
        opinion_id = f"opinion-{uuid.uuid4().hex}"
        opinion_ref = f"state://runs/{invocation['run_id']}/debate-opinions/{opinion_id}.json"
        warning = "Template fixture backend is degraded and cannot count as strong debate evidence."
        degradation_record = {
            "degradation_status": "degraded",
            "degradation_class": "template_debate_fallback",
            "cause": "template fixture backend selected because no real debate backend is enabled",
            "affected_evidence_refs": [opinion_ref],
            "decision_required": "kimi",
            "recovery_options": ["configure_real_backend", "rerun_with_non_template_backend"],
            "accepted_by_ref": None,
            "completion_evidence_allowed": False,
            "replacement_evidence_ref": None,
            "policy_ref": invocation["package_ref"],
        }
        checklist_refs = list(invocation.get("checklist_refs", []))
        input_refs = [
            *invocation.get("artifact_refs", []),
            *invocation.get("context_refs", []),
            *invocation.get("option_refs", []),
        ]

        opinion = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "debate_member_opinion",
            "opinion_id": opinion_id,
            "debate_id": invocation["debate_id"],
            "run_id": invocation["run_id"],
            "stage": invocation["stage"],
            "invocation_id": invocation["invocation_id"],
            "created_at": timestamp,
            "package_ref": invocation["package_ref"],
            "team_id": invocation["team_id"],
            "member_id": invocation["member_id"],
            "mode": invocation["mode"],
            "backend_id": invocation["backend_id"],
            "question": invocation["question"],
            "input_refs": input_refs,
            "checklist_refs": checklist_refs,
            "position": f"Template fixture opinion for {invocation['member_id']} flags degraded evidence.",
            "findings": [
                {
                    "summary": f"{invocation['member_id']} reviewed the request using template-only evidence.",
                    "evidence_refs": list(invocation.get("artifact_refs", [])),
                }
            ],
            "evidence_refs": list(invocation.get("artifact_refs", [])),
            "risks": [
                {
                    "summary": "Template fallback cannot substitute for a real debate backend in acceptance evidence.",
                    "severity": "medium",
                }
            ],
            "recommendations": [
                {
                    "summary": "Configure a real API or CLI debate backend before treating debate output as strong evidence.",
                    "evidence_refs": [],
                }
            ],
            "confidence": "low",
            "open_questions": ["Which real debate backend should be enabled for full acceptance?"],
            "verdict": "request_changes",
            "blocking": False,
            "requires_kimi_decision": True,
            "degraded": True,
            "degradation_status": "degraded",
            "degradation_record": degradation_record,
            "warnings": [warning],
        }
        receipt = {
            "status": "completed",
            "started_at": timestamp,
            "finished_at": timestamp,
            "retry_count": 0,
            "degraded": True,
            "degradation_status": "degraded",
            "degradation_record": degradation_record,
            "error_class": "none",
            "timing": {"duration_ms": 0},
            "backend_capabilities": list(invocation.get("backend_capabilities", [])),
            "opinion_ref": opinion_ref,
        }
        return opinion, receipt
