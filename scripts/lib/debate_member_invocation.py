from __future__ import annotations

import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from debate_backend_adapter import DebateBackendAdapterError, DebateBackendAdapterRegistry
from debate_engine import DebateEngine, DebateEngineError
from debate_report import DebateReportBuilder, DebateReportError, validate_artifact_definition


class DebateMemberInvocationError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class DebateMemberInvocationService:
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
        self.adapter_registry = DebateBackendAdapterRegistry(
            self.repo_root,
            package_root=package_root,
            allow_staged=allow_staged,
            enabled=enabled,
            adapter_overrides=adapter_overrides,
        )
        self.report_builder = DebateReportBuilder(self.repo_root, package_root=package_root)

    def load_backend_policy(self) -> dict[str, Any]:
        self._require_enabled()
        try:
            return self.adapter_registry.load_policy()
        except DebateBackendAdapterError as exc:
            raise DebateMemberInvocationError(exc.code, exc.message) from exc

    def build_invocation(
        self,
        run: dict[str, Any],
        assembly: dict[str, Any],
        member_id: str,
        input_refs: list[str],
        context_refs: list[str] | None = None,
        option_refs: list[str] | None = None,
        affected_scopes: list[str] | None = None,
        preferred_backend_id: str | None = None,
    ) -> dict[str, Any]:
        self._require_enabled()
        context_refs = context_refs or []
        option_refs = option_refs or []
        affected_scopes = affected_scopes or []
        if not isinstance(member_id, str) or not member_id:
            raise DebateMemberInvocationError("validation_error", "member_id must be a non-empty string")
        if not isinstance(input_refs, list) or not input_refs:
            raise DebateMemberInvocationError("validation_error", "input_refs must be a non-empty list")
        if not all(isinstance(item, str) and item for item in input_refs):
            raise DebateMemberInvocationError("validation_error", "input_refs must contain non-empty strings")
        if not isinstance(context_refs, list) or not all(isinstance(item, str) and item for item in context_refs):
            raise DebateMemberInvocationError("validation_error", "context_refs must be a list of non-empty strings")
        if not isinstance(option_refs, list) or not all(isinstance(item, str) and item for item in option_refs):
            raise DebateMemberInvocationError("validation_error", "option_refs must be a list of non-empty strings")
        if not isinstance(affected_scopes, list) or not all(isinstance(item, str) and item for item in affected_scopes):
            raise DebateMemberInvocationError("validation_error", "affected_scopes must be a list of non-empty strings")

        run_id = self._run_id(run)
        team, member = self._member_entry(member_id)
        stage = self._require_string(assembly, "stage", "assembly")
        backend = self._select_backend(stage, preferred_backend_id=preferred_backend_id)
        invocation_id = f"invoke-{uuid.uuid4().hex}"

        invocation = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "debate_member_invocation",
            "invocation_id": invocation_id,
            "debate_id": self._require_string(run, "debate_id", "run"),
            "run_id": run_id,
            "stage": stage,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "package_ref": f"state://runs/{run_id}/debate-package/full-package.json",
            "team_id": team["id"],
            "member_id": member["id"],
            "mode": self._require_string(run, "mode_id", "run"),
            "backend_id": backend["id"],
            "backend_family": backend["family"],
            "backend_capabilities": self._backend_capabilities(backend),
            "transport": self._backend_transport(backend),
            "timeout_seconds": 5,
            "retry_policy": {"max_attempts": 1, "retryable_error_classes": []},
            "question": self._require_string(run, "question", "run"),
            "context_refs": list(context_refs),
            "artifact_refs": list(input_refs),
            "option_refs": list(option_refs),
            "evidence_scope": {
                "allowed_ref_prefixes": [f"state://runs/{run_id}/"],
                "affected_scopes": list(affected_scopes),
            },
            "member_focus": member["focus"],
            "dimension_refs": list(member.get("dimension_refs", [])),
            "checklist_refs": list(member.get("checklist_refs", [])),
            "output_requirements": list(member.get("output_requirements", [])),
            "redaction_required": True,
            "secret_scan_required": True,
            "raw_prompt_persistence_allowed": False,
            "raw_stdout_persistence_allowed": False,
            "expected_artifact_type": "debate_member_opinion",
            "opinion_schema_ref": f"state://runs/{run_id}/schemas/debate-member-opinion.json",
        }

        self._validate_definition("debate_member_invocation", invocation)
        return invocation

    def execute(
        self,
        run: dict[str, Any],
        assembly: dict[str, Any],
        input_refs: list[str],
        context_refs: list[str] | None = None,
        option_refs: list[str] | None = None,
        affected_scopes: list[str] | None = None,
        preferred_backend_id: str | None = None,
        candidate_solutions: list[dict[str, Any]] | None = None,
        implementation_report: dict[str, Any] | None = None,
        event_log_path: str | Path | None = None,
        audit_log_path: str | Path | None = None,
    ) -> dict[str, Any]:
        self._require_enabled()
        context_refs = context_refs or []
        option_refs = option_refs or []
        affected_scopes = affected_scopes or []
        if not isinstance(assembly.get("selected_member_ids"), list) or not assembly["selected_member_ids"]:
            raise DebateMemberInvocationError("validation_error", "assembly must define selected_member_ids")

        invocations: list[dict[str, Any]] = []
        opinions: list[dict[str, Any]] = []
        receipts: list[dict[str, Any]] = []

        for member_id in assembly["selected_member_ids"]:
            invocation = self.build_invocation(
                run=run,
                assembly=assembly,
                member_id=member_id,
                input_refs=input_refs,
                context_refs=context_refs,
                option_refs=option_refs,
                affected_scopes=affected_scopes,
                preferred_backend_id=preferred_backend_id,
            )
            invocation["artifact_ref"] = f"state://runs/{invocation['run_id']}/debate-invocations/{invocation['invocation_id']}.json"
            try:
                backend = self.adapter_registry.get_adapter(
                    self._select_backend(invocation["stage"], preferred_backend_id=preferred_backend_id)
                )
                opinion, receipt = backend.invoke(invocation)
            except DebateBackendAdapterError as exc:
                raise DebateMemberInvocationError(exc.code, exc.message) from exc

            self._enforce_no_raw_persistence(opinion)
            self._scan_for_secrets(opinion)
            if "opinion_ref" not in receipt:
                receipt["opinion_ref"] = (
                    f"state://runs/{invocation['run_id']}/debate-opinions/{opinion['opinion_id']}.json"
                )
            opinion["artifact_ref"] = receipt["opinion_ref"]
            self._validate_definition("debate_member_opinion", opinion)

            invocations.append(invocation)
            opinions.append(opinion)
            receipts.append(receipt)

        backend_policy = self.load_backend_policy()
        try:
            built = self.report_builder.build(
                run=run,
                assembly=assembly,
                backend_policy=backend_policy,
                invocations=invocations,
                opinions=opinions,
                invocation_receipts=receipts,
                input_refs=input_refs,
                affected_scopes=affected_scopes,
                candidate_solutions=candidate_solutions,
                implementation_report=implementation_report,
                event_log_path=event_log_path,
                audit_log_path=audit_log_path,
            )
        except DebateReportError as exc:
            raise DebateMemberInvocationError(exc.code, exc.message) from exc

        return {
            "invocations": invocations,
            "opinions": opinions,
            "report": built["report"],
            "report_ref": built["report_ref"],
            "audit_trail": built["audit_trail"],
            "audit_ref": built["audit_ref"],
        }

    def _member_entry(self, member_id: str) -> tuple[dict[str, Any], dict[str, Any]]:
        try:
            registries = DebateEngine(
                self.repo_root,
                package_root=self.package_root,
                allow_staged=self.allow_staged,
                enabled=self.enabled,
            ).load_registries()
        except DebateEngineError as exc:
            raise DebateMemberInvocationError(exc.code, exc.message) from exc

        for team in registries["teams"]:
            for member in team["members"]:
                if member["id"] == member_id:
                    return team, member
        raise DebateMemberInvocationError("member_not_found", f"unknown debate member: {member_id}")

    def _select_backend(self, stage: str, preferred_backend_id: str | None = None) -> dict[str, Any]:
        try:
            return self.adapter_registry.select_backend(stage, preferred_backend_id=preferred_backend_id)
        except DebateBackendAdapterError as exc:
            raise DebateMemberInvocationError(exc.code, exc.message) from exc

    def _backend_capabilities(self, backend: dict[str, Any]) -> list[str]:
        capabilities = ["schema_valid_opinion", "secret_scan_required"]
        if backend.get("degraded_fixture_only"):
            capabilities.append("degraded_fixture")
        return capabilities

    def _backend_transport(self, backend: dict[str, Any]) -> str:
        family = backend["family"]
        if family == "template":
            return "in_process_template"
        return f"{family}_adapter"

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            raise DebateMemberInvocationError(exc.code, exc.message) from exc

    def _scan_for_secrets(self, artifact: Any) -> None:
        patterns = [
            re.compile(r"sk-[A-Za-z0-9_-]{8,}"),
            re.compile(r"ghp_[A-Za-z0-9]{8,}"),
            re.compile(r"AIza[0-9A-Za-z_-]{10,}"),
            re.compile(r"-----BEGIN [A-Z ]+PRIVATE KEY-----"),
        ]
        for value in self._string_values(artifact):
            for pattern in patterns:
                if pattern.search(value):
                    raise DebateMemberInvocationError("secret_scan_failed", "secret-like material detected in debate output")

    def _enforce_no_raw_persistence(self, artifact: Any) -> None:
        forbidden_fields = {"raw_prompt", "raw_stdout"}
        for key in self._keys(artifact):
            if key in forbidden_fields:
                raise DebateMemberInvocationError(
                    "persistence_forbidden",
                    f"{key} cannot be persisted in debate member outputs",
                )

    def _keys(self, artifact: Any) -> list[str]:
        if isinstance(artifact, dict):
            keys = list(artifact.keys())
            for value in artifact.values():
                keys.extend(self._keys(value))
            return keys
        if isinstance(artifact, list):
            keys: list[str] = []
            for item in artifact:
                keys.extend(self._keys(item))
            return keys
        return []

    def _string_values(self, artifact: Any) -> list[str]:
        if isinstance(artifact, str):
            return [artifact]
        if isinstance(artifact, dict):
            values: list[str] = []
            for item in artifact.values():
                values.extend(self._string_values(item))
            return values
        if isinstance(artifact, list):
            values: list[str] = []
            for item in artifact:
                values.extend(self._string_values(item))
            return values
        return []

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise DebateMemberInvocationError("module_disabled", "debate member invocation is disabled")

    def _run_id(self, run: dict[str, Any]) -> str:
        run_id = run.get("run_id", run.get("debate_id"))
        if not isinstance(run_id, str) or not run_id:
            raise DebateMemberInvocationError("validation_error", "run must provide run_id or debate_id")
        return run_id

    def _require_string(self, data: dict[str, Any], key: str, label: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise DebateMemberInvocationError("validation_error", f"{label} is missing {key}")
        return value
