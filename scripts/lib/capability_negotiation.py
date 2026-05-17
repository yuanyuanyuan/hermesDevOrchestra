from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition
from worker_registry import WorkerRegistry, WorkerRegistryError


class CapabilityNegotiationError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class CapabilityNegotiator:
    def __init__(self, registry: WorkerRegistry) -> None:
        self.registry = registry

    def negotiate(
        self,
        role: str,
        requested_backend: str | None = None,
        required_capabilities: list[str] | None = None,
    ) -> dict[str, Any]:
        required_capabilities = required_capabilities or []
        if not isinstance(role, str) or not role:
            raise CapabilityNegotiationError("validation_error", "role must be a non-empty string")
        if not isinstance(required_capabilities, list) or not all(
            isinstance(item, str) and item for item in required_capabilities
        ):
            raise CapabilityNegotiationError("validation_error", "required_capabilities must be a list of non-empty strings")

        try:
            role_entry = self.registry.get_role(role)
            self.registry.load_backends()
        except WorkerRegistryError as exc:
            raise CapabilityNegotiationError(exc.code, exc.message) from exc

        requested = requested_backend or role_entry["preferred_backend"]
        report_id = f"negotiate-{uuid.uuid4().hex}"
        run_id = "capability-negotiation"
        task_id = f"{role}-{report_id}"
        report_ref = f"state://runs/{run_id}/capability-negotiation/{task_id}.json"

        checked_backends: list[str] = [requested] if requested else []
        unavailable_reasons: list[str] = []
        fallback_considered: list[str] = []
        fallback_blocked_reasons: list[str] = []
        missing_capabilities: list[str] = []
        selected_backend: str | None = None
        matched_capabilities: list[str] = []
        adapter_type: str | None = None
        blocked_reason: str | None = None
        negotiation_status = "blocked"

        required = self._combine_required_capabilities(role_entry, required_capabilities)
        backend = self._get_backend(requested)
        if backend is None:
            blocked_reason = "backend_unknown"
        else:
            evaluation = self._evaluate_backend(role_entry, backend, required)
            matched_capabilities = evaluation["matched_capabilities"]
            missing_capabilities = evaluation["missing_capabilities"]
            unavailable_reasons = evaluation["unavailable_reasons"]
            blocked_reason = evaluation["blocked_reason"]
            if blocked_reason is None:
                selected_backend = backend["id"]
                adapter_type = backend["adapter_type"]
                negotiation_status = "selected"

        if negotiation_status == "blocked":
            fallback = self._select_fallback(role_entry, required, blocked_reason)
            fallback_considered = fallback["considered"]
            fallback_blocked_reasons = fallback["blocked_reasons"]
            if fallback["selected_backend"] is not None:
                selected_backend = fallback["selected_backend"]
                adapter_type = fallback["adapter_type"]
                matched_capabilities = fallback["matched_capabilities"]
                blocked_reason = None
                negotiation_status = "fallback_selected"

        decision_required = "none" if negotiation_status != "blocked" else "kimi"
        fallback_used = negotiation_status == "fallback_selected"
        fallback_selected = selected_backend if fallback_used else None

        report = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "capability_negotiation_report",
            "run_id": run_id,
            "task_id": task_id,
            "role": role,
            "requested_backend": requested,
            "negotiation_status": negotiation_status,
            "checked_backends": checked_backends,
            "missing_capabilities": missing_capabilities,
            "unavailable_reasons": unavailable_reasons,
            "fallback_considered": fallback_considered,
            "fallback_selected": fallback_selected,
            "fallback_blocked_reasons": fallback_blocked_reasons,
            "decision_required": decision_required,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        selection_record = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "worker_selection_record",
            "run_id": run_id,
            "task_id": task_id,
            "role": role,
            "requested_backend": requested,
            "selected_backend": selected_backend,
            "matched_capabilities": matched_capabilities,
            "adapter_type": adapter_type,
            "fallback_used": fallback_used,
            "attempt": 1,
            "negotiation_status": negotiation_status,
            "blocked_reason": blocked_reason,
            "capability_negotiation_report_ref": report_ref,
        }

        self._validate_definition("capability_negotiation_report", report)
        self._validate_definition("worker_selection_record", selection_record)

        return {
            "role": role,
            "selected_backend": selected_backend,
            "selection_record": selection_record,
            "negotiation_report": report,
            "negotiation_report_ref": report_ref,
        }

    def _get_backend(self, backend_id: str | None) -> dict[str, Any] | None:
        if not isinstance(backend_id, str) or not backend_id:
            return None
        try:
            return self.registry.get_backend(backend_id)
        except WorkerRegistryError as exc:
            if exc.code == "backend_not_found":
                return None
            raise CapabilityNegotiationError(exc.code, exc.message) from exc

    def _combine_required_capabilities(self, role_entry: dict[str, Any], extras: list[str]) -> list[str]:
        combined: list[str] = []
        for capability in [*role_entry["required_capabilities"], *extras]:
            if capability not in combined:
                combined.append(capability)
        return combined

    def _evaluate_backend(
        self,
        role_entry: dict[str, Any],
        backend: dict[str, Any],
        required_capabilities: list[str],
    ) -> dict[str, Any]:
        matched_capabilities = [capability for capability in required_capabilities if capability in backend["capabilities"]]
        missing_capabilities = [capability for capability in required_capabilities if capability not in backend["capabilities"]]
        unavailable_reasons: list[str] = []
        blocked_reason: str | None = None

        if not backend.get("enabled", False):
            blocked_reason = "backend_disabled"

        try:
            availability = self.registry.backend_availability(backend["id"])
        except WorkerRegistryError as exc:
            raise CapabilityNegotiationError(exc.code, exc.message) from exc
        if not availability["available"]:
            unavailable_reasons = [f"{backend['id']}:{reason}" for reason in availability["reasons"]]
            blocked_reason = blocked_reason or "backend_unavailable"

        if role_entry["role"] not in backend["compatible_roles"]:
            blocked_reason = blocked_reason or "role_incompatible"

        if role_entry["protocol"] not in backend["protocols"]:
            blocked_reason = blocked_reason or "protocol_incompatible"

        if missing_capabilities:
            blocked_reason = blocked_reason or "missing_capabilities"

        return {
            "matched_capabilities": matched_capabilities,
            "missing_capabilities": missing_capabilities,
            "unavailable_reasons": unavailable_reasons,
            "blocked_reason": blocked_reason,
        }

    def _select_fallback(
        self,
        role_entry: dict[str, Any],
        required_capabilities: list[str],
        blocked_reason: str | None,
    ) -> dict[str, Any]:
        considered = list(role_entry.get("explicit_fallback_backends", []))
        blocked_reasons: list[str] = []
        if not considered:
            blocked_reasons.append("no_explicit_fallback_backends")
            return {
                "considered": considered,
                "blocked_reasons": blocked_reasons,
                "selected_backend": None,
                "adapter_type": None,
                "matched_capabilities": [],
            }

        failure_class = self._failure_class(blocked_reason)
        allowed_failure_classes = set(role_entry.get("fallback_allowed_failure_classes", []))
        if failure_class not in allowed_failure_classes:
            blocked_reasons.append(f"failure_class_not_allowed:{failure_class}")
            return {
                "considered": considered,
                "blocked_reasons": blocked_reasons,
                "selected_backend": None,
                "adapter_type": None,
                "matched_capabilities": [],
            }

        forbidden_conditions = role_entry.get("fallback_forbidden_when", [])
        if forbidden_conditions:
            blocked_reasons.append("fallback_forbidden_by_policy")
            return {
                "considered": considered,
                "blocked_reasons": blocked_reasons,
                "selected_backend": None,
                "adapter_type": None,
                "matched_capabilities": [],
            }

        for backend_id in considered:
            backend = self._get_backend(backend_id)
            if backend is None:
                blocked_reasons.append(f"unknown_fallback_backend:{backend_id}")
                continue
            evaluation = self._evaluate_backend(role_entry, backend, required_capabilities)
            if evaluation["blocked_reason"] is None:
                return {
                    "considered": considered,
                    "blocked_reasons": blocked_reasons,
                    "selected_backend": backend["id"],
                    "adapter_type": backend["adapter_type"],
                    "matched_capabilities": evaluation["matched_capabilities"],
                }
            blocked_reasons.append(f"{backend_id}:{evaluation['blocked_reason']}")

        return {
            "considered": considered,
            "blocked_reasons": blocked_reasons,
            "selected_backend": None,
            "adapter_type": None,
            "matched_capabilities": [],
        }

    def _failure_class(self, blocked_reason: str | None) -> str:
        if blocked_reason == "backend_unavailable":
            return "unavailable"
        if blocked_reason == "backend_disabled":
            return "disabled"
        if blocked_reason == "missing_capabilities":
            return "capability_mismatch"
        if blocked_reason == "role_incompatible":
            return "role_incompatible"
        if blocked_reason == "protocol_incompatible":
            return "protocol_incompatible"
        if blocked_reason == "backend_unknown":
            return "unknown_backend"
        return "blocked"

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.registry.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise CapabilityNegotiationError("schema_invalid", exc.message) from exc
