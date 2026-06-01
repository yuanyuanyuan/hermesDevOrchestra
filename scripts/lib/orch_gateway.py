#!/usr/bin/env python3
"""Local Hermes Orchestra Gateway adapter."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import re
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest
from urllib.parse import parse_qs, urlparse

from atomic_writer import AtomicWriter
from blocker_validator import validate as _completion_bundle_validate
from debate_report import validate_artifact_definition
from runtime_activation import RuntimeActivation, RuntimeActivationError

try:
    from gateway_evidence import gather as _evidence_gather
    from gateway_intake import normalize as _intake_normalize
    from gateway_projection import project as _projection_project
    _HELPERS_OK = True
    _HELPERS_IMPORT_ERROR: str | None = None
except ImportError as exc:
    _HELPERS_OK = False
    _HELPERS_IMPORT_ERROR = f"{type(exc).__name__}: {exc}"


SCHEMA_VERSION = "orchestra.v1"
EVENT_SCHEMA_VERSION = "orchestra.event.v1"
STAGES = [
    "direction_debate",
    "solution_debate",
    "implementation",
    "improvement",
    "global_evaluation",
    "continuous_improvement",
]
FIXED_STAGE_REPORTS = {
    "direction_debate": "best_choice_report.json",
    "solution_debate": "implementation_plan_report.json",
    "implementation": "task_feedback_report.json",
    "improvement": "improvement_report.json",
}
ACTIVE_RUN_STATUSES = {"queued", "running", "blocked"}
WORKER_BACKENDS = {
    "codex": {"roles": ["implementer"], "enabled": True, "available": True, "kind": "cli"},
    "claude": {"roles": ["reviewer"], "enabled": True, "available": True, "kind": "cli"},
}
SAFE_PATH_COMPONENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
_ATOMIC_WRITER = AtomicWriter()


def module_endpoint(
    module: str,
    operation: str,
    class_name: str,
    authority: str,
    required_fields: list[str],
    optional_fields: list[str],
    response_keys: list[str],
) -> dict[str, Any]:
    path = f"/orchestra/modules/{module}/{operation}"
    return {
        "module": module,
        "operation": operation,
        "class_name": class_name,
        "method": "POST",
        "path": path,
        "route": f"POST {path}",
        "authority": authority,
        "request_shape": {
            "type": "object",
            "required_fields": ["authority", *required_fields],
            "optional_fields": optional_fields,
        },
        "response_shape": {
            "type": "object",
            "top_level_keys": ["schema_version", "module", "operation", "authority", "result"],
            "result_keys": response_keys,
        },
    }


FULL_MODULE_ENDPOINTS = [
    module_endpoint("debate-engine", "load-registries", "DebateEngine", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["teams", "modes", "team_ids", "mode_ids"]),
    module_endpoint("debate-engine", "create-run", "DebateEngine", "gateway_local_operator", ["question", "mode_id"], ["selected_member_ids", "metadata", "allow_staged", "enabled"], ["debate_id", "status", "mode_id", "question"]),
    module_endpoint("debate-assembly", "select-for-stage", "DebateAssembly", "gateway_local_operator", ["stage", "task_type", "risk_level"], ["project_overrides", "allow_staged", "enabled"], ["audit_id", "stage", "selected_team_ids", "selected_member_ids", "required_modes"]),
    module_endpoint("debate-backend-adapter", "select-backend", "DebateBackendAdapterRegistry", "gateway_local_runtime", ["stage"], ["preferred_backend_id", "allow_staged", "enabled"], ["id", "family", "degraded_fixture_only", "allowed_stages"]),
    module_endpoint("debate-member-invocation", "build-invocation", "DebateMemberInvocationService", "gateway_local_operator", ["run", "assembly", "member_id", "input_refs"], ["context_refs", "option_refs", "affected_scopes", "preferred_backend_id", "allow_staged", "enabled"], ["invocation_id", "member_id", "backend_id", "artifact_refs"]),
    module_endpoint("debate-member-invocation", "execute", "DebateMemberInvocationService", "gateway_local_operator", ["run", "assembly", "input_refs"], ["context_refs", "option_refs", "affected_scopes", "preferred_backend_id", "allow_staged", "enabled"], ["invocations", "opinions", "report", "audit_trail"]),
    module_endpoint("debate-report", "build", "DebateReportBuilder", "gateway_local_operator", ["run", "assembly", "backend_policy", "invocations", "opinions", "invocation_receipts", "input_refs", "affected_scopes"], [], ["report", "report_ref", "audit_trail", "audit_ref"]),
    module_endpoint("worker-registry", "load-backends", "WorkerRegistry", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["backends", "package_status"]),
    module_endpoint("worker-registry", "load-roles", "WorkerRegistry", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["roles", "package_status"]),
    module_endpoint("capability-negotiation", "negotiate", "CapabilityNegotiator", "gateway_local_operator", ["role"], ["requested_backend", "required_capabilities", "negotiation_context", "allow_staged", "enabled"], ["role", "selected_backend", "selection_record", "negotiation_report"]),
    module_endpoint("worker-session", "create-session", "WorkerSessionManager", "gateway_local_operator", ["run_id", "task_id", "role", "backend_id", "workspace_root", "write_scope_ref", "context_bundle_ref", "timeout_seconds"], ["transcript_ref", "output_envelope_ref"], ["session_id", "status", "workspace_path", "tmux_session_name", "session_record_ref"]),
    module_endpoint("worker-session", "transition", "WorkerSessionManager", "gateway_local_operator", ["record", "next_status"], ["exit_signal", "output_envelope_ref", "cleanup_status", "termination_reason"], ["session_id", "status", "cleanup_status", "termination_reason", "session_record_ref"]),
    module_endpoint("worker-session-sweeper", "sweep-directory", "WorkerSessionSweeper", "gateway_local_operator", ["records_root"], [], ["updated_records", "timed_out_records", "missing_records", "invalid_records"]),
    module_endpoint("release-pipeline", "load-pipeline", "ReleasePipeline", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["command_registry_ref", "environments", "gates"]),
    module_endpoint("release-pipeline", "load-registry", "ReleasePipeline", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["commands", "package_status", "command_index"]),
    module_endpoint("release-pipeline", "validate-command-refs", "ReleasePipeline", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["command_registry_ref", "validated_command_refs", "environment_ids"]),
    module_endpoint("release-pipeline", "plan", "ReleasePipeline", "gateway_local_runtime", ["environment"], ["allow_staged", "enabled"], ["environment", "deploy_command", "rollback_command", "gates"]),
    module_endpoint("release-executor", "execute", "ReleaseExecutor", "gateway_local_release_operator", ["command_ref"], ["approval_ref", "run_id", "environment", "test_execution_report_refs", "health_check_refs", "rollback_or_recovery_refs", "gate_results", "allow_staged", "enabled"], ["deployment_report", "stdout_path", "stderr_path", "allowed_env"]),
    module_endpoint("runtime-knowledge", "query", "RuntimeKnowledgeBase", "gateway_local_operator", ["request"], ["allow_staged", "enabled"], ["query_artifact", "result_artifact", "degraded_storage_refs"]),
    module_endpoint("knowledge-ingestion", "ingest", "KnowledgeIngestion", "gateway_local_operator", ["entry"], ["allow_staged", "enabled"], ["entry", "storage_ref", "ingestion_record", "degraded"]),
    module_endpoint("self-evolution", "generate-stage6-sweep", "SelfEvolutionQueue", "gateway_local_review", ["run_id", "source_refs", "proposals", "trigger_matches"], ["allow_staged", "enabled"], ["schema_version", "artifact_type", "run_id", "proposals", "queued_item_refs"]),
    module_endpoint("self-evolution", "enqueue", "SelfEvolutionQueue", "gateway_local_review", ["proposal"], ["allow_staged", "enabled"], ["proposals_artifact", "queue_items"]),
    module_endpoint("self-evolution", "transition", "SelfEvolutionQueue", "gateway_local_review", ["queue_item", "next_status"], ["decision_ref", "rejection_reason", "kimi_review_ref", "human_approval_ref", "allow_staged", "enabled"], ["queue_item_id", "status", "decision_ref", "rejection_reason"]),
    module_endpoint("self-evolution", "list-pending", "SelfEvolutionQueue", "gateway_local_review", [], ["queue_items", "allow_staged", "enabled"], ["items"]),
    module_endpoint("performance-slo", "evaluate", "PerformanceBudgetPolicy", "gateway_local_runtime", ["component_id", "observed"], ["allow_staged", "enabled"], ["component_id", "budget_status", "budget_misses", "degradation_status"]),
    module_endpoint("channel-router", "classify", "ChannelRouter", "gateway_local_runtime", ["intent", "project_age_weeks"], ["profile"], ["channel", "reason", "project_age_weeks"]),
    module_endpoint("rollout-gate", "allow", "RolloutGate", "gateway_local_runtime", ["channel", "project_age_weeks", "calibration_evidence"], [], ["allowed", "channel", "forced_standard", "reason"]),
    module_endpoint("evidence-scanner", "scan", "EvidenceScanner", "gateway_local_runtime", ["diff", "files"], [], ["lint_pass", "syntax_pass", "i18n_pass", "sensitive_keywords", "pii_detected"]),
    module_endpoint("security-gate", "evaluate", "SecurityGate", "gateway_local_runtime", ["scan"], [], ["verdict", "security_pass", "block_reason"]),
    module_endpoint("auto-merge", "merge", "AutoMergeController", "gateway_local_release_operator", ["target_branch", "pr_number", "audit_context"], [], ["status", "target_branch", "pr_number", "audit_ref"]),
    module_endpoint("notification", "send", "NotificationDispatcher", "gateway_local_runtime", ["level", "scan_result"], [], ["level", "sent", "message"]),
    module_endpoint("fixture-policy", "validate-contract-fixture", "FixturePolicy", "gateway_local_runtime", ["family_id", "fixture"], ["allow_staged", "enabled"], ["family_id", "fixture_name", "fixture_kind", "completion_evidence_allowed"]),
    module_endpoint("fixture-policy", "validate-runtime-fake-adapter", "FixturePolicy", "gateway_local_runtime", ["family_id", "fixture"], ["allow_staged", "enabled"], ["family_id", "fixture_name", "fixture_kind", "degraded", "required_degradation_class"]),
    module_endpoint("degradation-policy", "transition", "DegradationPolicy", "gateway_local_runtime", ["current_status", "next_status"], ["allow_staged", "enabled"], ["next_status"]),
    module_endpoint("degradation-policy", "build-record", "DegradationPolicy", "gateway_local_runtime", ["degradation_status", "degradation_class", "cause", "affected_evidence_refs", "recovery_options"], ["policy_key", "decision_required", "accepted_by_ref", "completion_evidence_allowed", "replacement_evidence_ref", "policy_ref", "allow_staged", "enabled"], ["degradation_status", "degradation_class", "decision_required", "completion_evidence_allowed"]),
    module_endpoint("degradation-policy", "allows-completion-evidence", "DegradationPolicy", "gateway_local_runtime", ["record"], ["allow_staged", "enabled"], ["allowed"]),
    module_endpoint("full-schema-validation", "validate-schema", "FullSchemaValidation", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["ok", "path", "draft"]),
    module_endpoint("full-schema-validation", "validate-contract", "FullSchemaValidation", "gateway_local_runtime", ["rel_path", "definition_name"], ["allow_staged", "enabled"], ["ok", "path", "definition", "artifact_type"]),
    module_endpoint("full-schema-validation", "validate-all", "FullSchemaValidation", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["ok", "schema", "contracts"]),
    module_endpoint("full-schema-cutover", "evaluate-family", "FullSchemaCutover", "gateway_local_runtime", ["family_id"], ["allow_staged", "enabled"], ["family_id", "gate_ready", "required_gate_evidence", "required_checks"]),
    module_endpoint("full-schema-cutover", "can-activate", "FullSchemaCutover", "gateway_local_runtime", ["family_id"], ["evidence", "completed_checks", "allow_staged", "enabled"], ["family_id", "allowed", "missing_evidence", "missing_checks"]),
    module_endpoint("full-schema-cutover", "plan-artifact-write", "FullSchemaCutover", "gateway_local_runtime", ["family_id", "family_activated"], ["historical_run", "existing_schema_version", "allow_staged", "enabled"], ["family_id", "historical_run", "schema_ref", "write_full_artifacts"]),
]
FULL_MODULE_ENDPOINT_INDEX = {(spec["module"], spec["operation"]): spec for spec in FULL_MODULE_ENDPOINTS}


def module_endpoint(
    module: str,
    operation: str,
    class_name: str,
    authority: str,
    required_fields: list[str],
    optional_fields: list[str],
    response_keys: list[str],
) -> dict[str, Any]:
    path = f"/orchestra/modules/{module}/{operation}"
    return {
        "module": module,
        "operation": operation,
        "class_name": class_name,
        "method": "POST",
        "path": path,
        "route": f"POST {path}",
        "authority": authority,
        "request_shape": {
            "type": "object",
            "required_fields": ["authority", *required_fields],
            "optional_fields": optional_fields,
        },
        "response_shape": {
            "type": "object",
            "top_level_keys": ["schema_version", "module", "operation", "authority", "result"],
            "result_keys": response_keys,
        },
    }


FULL_MODULE_ENDPOINTS = [
    module_endpoint("debate-engine", "load-registries", "DebateEngine", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["teams", "modes", "team_ids", "mode_ids"]),
    module_endpoint("debate-engine", "create-run", "DebateEngine", "gateway_local_operator", ["question", "mode_id"], ["selected_member_ids", "metadata", "allow_staged", "enabled"], ["debate_id", "status", "mode_id", "question"]),
    module_endpoint("debate-assembly", "select-for-stage", "DebateAssembly", "gateway_local_operator", ["stage", "task_type", "risk_level"], ["project_overrides", "allow_staged", "enabled"], ["audit_id", "stage", "selected_team_ids", "selected_member_ids", "required_modes"]),
    module_endpoint("debate-backend-adapter", "select-backend", "DebateBackendAdapterRegistry", "gateway_local_runtime", ["stage"], ["preferred_backend_id", "allow_staged", "enabled"], ["id", "family", "degraded_fixture_only", "allowed_stages"]),
    module_endpoint("debate-member-invocation", "build-invocation", "DebateMemberInvocationService", "gateway_local_operator", ["run", "assembly", "member_id", "input_refs"], ["context_refs", "option_refs", "affected_scopes", "preferred_backend_id", "allow_staged", "enabled"], ["invocation_id", "member_id", "backend_id", "artifact_refs"]),
    module_endpoint("debate-member-invocation", "execute", "DebateMemberInvocationService", "gateway_local_operator", ["run", "assembly", "input_refs"], ["context_refs", "option_refs", "affected_scopes", "preferred_backend_id", "allow_staged", "enabled"], ["invocations", "opinions", "report", "audit_trail"]),
    module_endpoint("debate-report", "build", "DebateReportBuilder", "gateway_local_operator", ["run", "assembly", "backend_policy", "invocations", "opinions", "invocation_receipts", "input_refs", "affected_scopes"], [], ["report", "report_ref", "audit_trail", "audit_ref"]),
    module_endpoint("worker-registry", "load-backends", "WorkerRegistry", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["backends", "package_status"]),
    module_endpoint("worker-registry", "load-roles", "WorkerRegistry", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["roles", "package_status"]),
    module_endpoint("capability-negotiation", "negotiate", "CapabilityNegotiator", "gateway_local_operator", ["role"], ["requested_backend", "required_capabilities", "negotiation_context", "allow_staged", "enabled"], ["role", "selected_backend", "selection_record", "negotiation_report"]),
    module_endpoint("worker-session", "create-session", "WorkerSessionManager", "gateway_local_operator", ["run_id", "task_id", "role", "backend_id", "workspace_root", "write_scope_ref", "context_bundle_ref", "timeout_seconds"], ["transcript_ref", "output_envelope_ref"], ["session_id", "status", "workspace_path", "tmux_session_name"]),
    module_endpoint("worker-session", "transition", "WorkerSessionManager", "gateway_local_operator", ["record", "next_status"], ["exit_signal", "output_envelope_ref", "cleanup_status", "termination_reason"], ["session_id", "status", "cleanup_status", "termination_reason"]),
    module_endpoint("worker-session-sweeper", "sweep-directory", "WorkerSessionSweeper", "gateway_local_operator", ["records_root"], [], ["updated_records", "timed_out_records", "missing_records", "invalid_records"]),
    module_endpoint("release-pipeline", "load-pipeline", "ReleasePipeline", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["command_registry_ref", "environments", "gates"]),
    module_endpoint("release-pipeline", "load-registry", "ReleasePipeline", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["commands", "package_status", "command_index"]),
    module_endpoint("release-pipeline", "validate-command-refs", "ReleasePipeline", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["command_registry_ref", "validated_command_refs", "environment_ids"]),
    module_endpoint("release-pipeline", "plan", "ReleasePipeline", "gateway_local_runtime", ["environment"], ["allow_staged", "enabled"], ["environment", "deploy_command", "rollback_command", "gates"]),
    module_endpoint("release-executor", "execute", "ReleaseExecutor", "gateway_local_release_operator", ["command_ref"], ["approval_ref", "run_id", "environment", "test_execution_report_refs", "health_check_refs", "rollback_or_recovery_refs", "gate_results", "allow_staged", "enabled"], ["deployment_report", "stdout_path", "stderr_path", "allowed_env"]),
    module_endpoint("runtime-knowledge", "query", "RuntimeKnowledgeBase", "gateway_local_operator", ["request"], ["allow_staged", "enabled"], ["query_artifact", "result_artifact", "degraded_storage_refs"]),
    module_endpoint("knowledge-ingestion", "ingest", "KnowledgeIngestion", "gateway_local_operator", ["entry"], ["allow_staged", "enabled"], ["entry", "storage_ref", "ingestion_record", "degraded"]),
    module_endpoint("self-evolution", "generate-stage6-sweep", "SelfEvolutionQueue", "gateway_local_review", ["run_id", "source_refs", "proposals", "trigger_matches"], ["allow_staged", "enabled"], ["schema_version", "artifact_type", "run_id", "proposals", "queued_item_refs"]),
    module_endpoint("self-evolution", "enqueue", "SelfEvolutionQueue", "gateway_local_review", ["proposal"], ["allow_staged", "enabled"], ["proposals_artifact", "queue_items"]),
    module_endpoint("self-evolution", "transition", "SelfEvolutionQueue", "gateway_local_review", ["queue_item", "next_status"], ["decision_ref", "rejection_reason", "kimi_review_ref", "human_approval_ref", "allow_staged", "enabled"], ["queue_item_id", "status", "decision_ref", "rejection_reason"]),
    module_endpoint("self-evolution", "list-pending", "SelfEvolutionQueue", "gateway_local_review", [], ["queue_items", "allow_staged", "enabled"], ["items"]),
    module_endpoint("performance-slo", "evaluate", "PerformanceBudgetPolicy", "gateway_local_runtime", ["component_id", "observed"], ["allow_staged", "enabled"], ["component_id", "budget_status", "budget_misses", "degradation_status"]),
    module_endpoint("channel-router", "classify", "ChannelRouter", "gateway_local_runtime", ["intent", "project_age_weeks"], ["profile"], ["channel", "reason", "project_age_weeks"]),
    module_endpoint("rollout-gate", "allow", "RolloutGate", "gateway_local_runtime", ["channel", "project_age_weeks", "calibration_evidence"], [], ["allowed", "channel", "forced_standard", "reason"]),
    module_endpoint("evidence-scanner", "scan", "EvidenceScanner", "gateway_local_runtime", ["diff", "files"], [], ["lint_pass", "syntax_pass", "i18n_pass", "sensitive_keywords", "pii_detected"]),
    module_endpoint("security-gate", "evaluate", "SecurityGate", "gateway_local_runtime", ["scan"], [], ["verdict", "security_pass", "block_reason"]),
    module_endpoint("auto-merge", "merge", "AutoMergeController", "gateway_local_release_operator", ["target_branch", "pr_number", "audit_context"], [], ["status", "target_branch", "pr_number", "audit_ref"]),
    module_endpoint("notification", "send", "NotificationDispatcher", "gateway_local_runtime", ["level", "scan_result"], [], ["level", "sent", "message"]),
    module_endpoint("fixture-policy", "validate-contract-fixture", "FixturePolicy", "gateway_local_runtime", ["family_id", "fixture"], ["allow_staged", "enabled"], ["family_id", "fixture_name", "fixture_kind", "completion_evidence_allowed"]),
    module_endpoint("fixture-policy", "validate-runtime-fake-adapter", "FixturePolicy", "gateway_local_runtime", ["family_id", "fixture"], ["allow_staged", "enabled"], ["family_id", "fixture_name", "fixture_kind", "degraded", "required_degradation_class"]),
    module_endpoint("degradation-policy", "transition", "DegradationPolicy", "gateway_local_runtime", ["current_status", "next_status"], ["allow_staged", "enabled"], ["next_status"]),
    module_endpoint("degradation-policy", "build-record", "DegradationPolicy", "gateway_local_runtime", ["degradation_status", "degradation_class", "cause", "affected_evidence_refs", "recovery_options"], ["policy_key", "decision_required", "accepted_by_ref", "completion_evidence_allowed", "replacement_evidence_ref", "policy_ref", "allow_staged", "enabled"], ["degradation_status", "degradation_class", "decision_required", "completion_evidence_allowed"]),
    module_endpoint("degradation-policy", "allows-completion-evidence", "DegradationPolicy", "gateway_local_runtime", ["record"], ["allow_staged", "enabled"], ["allowed"]),
    module_endpoint("full-schema-validation", "validate-schema", "FullSchemaValidation", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["ok", "path", "draft"]),
    module_endpoint("full-schema-validation", "validate-contract", "FullSchemaValidation", "gateway_local_runtime", ["rel_path", "definition_name"], ["allow_staged", "enabled"], ["ok", "path", "definition", "artifact_type"]),
    module_endpoint("full-schema-validation", "validate-all", "FullSchemaValidation", "gateway_local_runtime", [], ["allow_staged", "enabled"], ["ok", "schema", "contracts"]),
    module_endpoint("full-schema-cutover", "evaluate-family", "FullSchemaCutover", "gateway_local_runtime", ["family_id"], ["allow_staged", "enabled"], ["family_id", "gate_ready", "required_gate_evidence", "required_checks"]),
    module_endpoint("full-schema-cutover", "can-activate", "FullSchemaCutover", "gateway_local_runtime", ["family_id"], ["evidence", "completed_checks", "allow_staged", "enabled"], ["family_id", "allowed", "missing_evidence", "missing_checks"]),
    module_endpoint("full-schema-cutover", "plan-artifact-write", "FullSchemaCutover", "gateway_local_runtime", ["family_id", "family_activated"], ["historical_run", "existing_schema_version", "allow_staged", "enabled"], ["family_id", "historical_run", "schema_ref", "write_full_artifacts"]),
]
FULL_MODULE_ENDPOINT_INDEX = {(spec["module"], spec["operation"]): spec for spec in FULL_MODULE_ENDPOINTS}


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def json_bytes(data: dict[str, Any]) -> bytes:
    return json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"


def write_json(path: Path, data: dict[str, Any]) -> None:
    receipt = _ATOMIC_WRITER.write(path, data)
    if receipt.get("status") == "conflict":
        raise RuntimeError(f"atomic write conflict: {path}")


def append_jsonl(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        json.dump(record, handle, ensure_ascii=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def canonical_payload_hash(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


class GatewayStore:
    def __init__(self, project_id: str) -> None:
        home = Path(os.environ.get("HOME", str(Path.home())))
        self.project_id = project_id
        self.state_root = Path(os.environ.get("STATE_ROOT", str(home / ".local/state/hermes-orchestra")))
        self.audit_root = Path(os.environ.get("AUDIT_ROOT", str(home / ".local/share/hermes-orchestra")))
        self.state_dir = self.state_root / project_id
        self.audit_dir = self.audit_root / project_id

    def run_dir(self, run_id: str) -> Path:
        return self.state_dir / "runs" / run_id

    def run_path(self, run_id: str) -> Path:
        return self.run_dir(run_id) / "run.json"

    def command_path(self, run_id: str, command_id: str) -> Path:
        return self.run_dir(run_id) / "commands" / f"{command_id}.json"

    def events_path(self, run_id: str) -> Path:
        return self.run_dir(run_id) / "events.jsonl"

    def tasks_path(self, run_id: str) -> Path:
        return self.run_dir(run_id) / "tasks.json"

    def worker_session_path(self, run_id: str, session_id: str) -> Path:
        return self.run_dir(run_id) / "worker-sessions" / f"{session_id}.json"

    def audit_path(self) -> Path:
        return self.audit_dir / "audit.jsonl"

    def active_run_path(self) -> Path:
        return self.state_dir / "orchestra-active-run.json"

    def idempotency_path(self, endpoint: str, resource_path: str, idempotency_key: str) -> Path:
        scope = "\0".join([self.project_id, endpoint, resource_path, idempotency_key])
        digest = hashlib.sha256(scope.encode("utf-8")).hexdigest()
        return self.state_dir / "idempotency" / f"{digest}.json"

    def state_ref(self, run_id: str, name: str) -> str:
        return f"state://runs/{run_id}/{name}"

    def audit_ref(self, command_id: str) -> str:
        return f"audit://audit.jsonl#command_id={command_id}"


class GatewayApp:
    def __init__(self, project_id: str, upstream_api_url: str) -> None:
        self.store = GatewayStore(project_id)
        self.upstream_api_url = upstream_api_url
        self.repo_root = Path(__file__).resolve().parents[2]
        self.runtime_activation = RuntimeActivation(self.repo_root)
        self.recover_in_progress_commands()

    def _intake_pipeline_fallback_reason(self, payload: dict[str, Any], request_type: str, run_id: str | None = None) -> str | None:
        if not _HELPERS_OK:
            detail = _HELPERS_IMPORT_ERROR or "helper imports unavailable"
            self._record_fallback("FALLBACK_HEURISTIC", request_type, detail)
            return detail
        try:
            intent = _intake_normalize(payload, expected_intent_type=request_type)
            ctx = {"project_id": self.store.project_id, "request_type": request_type, "run_id": run_id, "timestamp": utc_now()}
            projected = _projection_project(intent, ctx)
            evidence = _evidence_gather(projected)
            self._record_intake_trace(request_type, projected, evidence)
            return None
        except Exception as exc:
            detail = f"{type(exc).__name__}: {exc}"
            self._record_fallback("FALLBACK_HEURISTIC", request_type, detail)
            return detail

    def _run_intake_pipeline(self, payload: dict[str, Any], request_type: str, run_id: str | None = None) -> bool:
        return self._intake_pipeline_fallback_reason(payload, request_type, run_id) is not None

    def _record_fallback(self, reason: str, request_type: str, detail: str | None = None) -> None:
        record = {"timestamp": utc_now(), "reason": reason, "request_type": request_type, "project": self.store.project_id}
        if detail:
            record["detail"] = detail
        try:
            append_jsonl(self.repo_root / "logs" / "gateway-fallback.jsonl", record)
        except Exception as exc:
            try:
                sys.stderr.write(f"[orch_gateway] fallback log failed: {type(exc).__name__}: {exc}\n")
            except Exception:
                pass

    def _record_intake_trace(self, request_type: str, projected: dict[str, Any], evidence: dict[str, Any]) -> None:
        record = {
            "timestamp": utc_now(),
            "request_type": request_type,
            "project": self.store.project_id,
            "intent_type": projected.get("intent_type"),
            "confidence": projected.get("confidence"),
            "projection_status": projected.get("projection_status"),
            "projection_issues": projected.get("projection_issues", []),
            "state_refs": projected.get("state_refs", []),
            "evidence_refs": evidence.get("evidence_refs", []),
            "degraded": bool(evidence.get("degraded")),
            "degradation_reason": evidence.get("degradation_reason"),
        }
        try:
            append_jsonl(self.repo_root / "logs" / "gateway-intake.jsonl", record)
        except Exception:
            pass

    def _gateway_fallback_body(self, detail: str) -> dict[str, Any]:
        body = self.error("gateway_fallback", "Gateway degraded to heuristic mode")
        body.update({"fallback": "FALLBACK_HEURISTIC", "fallback_reason": detail})
        return body

    def _fallback_response(self) -> tuple[int, dict[str, Any]]:
        body = self.error("gateway_fallback", "Gateway degraded to heuristic mode")
        body["fallback"] = "FALLBACK_HEURISTIC"
        return 503, body

    def _requirement_completion_bundle(self, payload: dict[str, Any], request_type: str, run_id: str) -> dict[str, Any]:
        intent = _intake_normalize(payload, expected_intent_type=request_type)
        ctx = {"project_id": self.store.project_id, "request_type": request_type, "run_id": run_id, "timestamp": utc_now()}
        projected = _projection_project(intent, ctx)
        bundle = projected.get("requirement_completion_bundle")
        if not isinstance(bundle, dict):
            raise RuntimeError("requirement completion bundle missing")
        if isinstance(projected.get("confirmation_nodes"), list):
            bundle["confirmation_nodes"] = projected["confirmation_nodes"]
        return bundle

    def health(self) -> dict[str, Any]:
        return {
            "schema_version": SCHEMA_VERSION,
            "status": "ok",
            "project": self.store.project_id,
            "upstream_api": self.upstream_status(),
        }

    def upstream_status(self) -> str:
        try:
            with urlrequest.urlopen(f"{self.upstream_api_url.rstrip('/')}/health", timeout=0.3) as response:
                return "ok" if response.status < 500 else "degraded"
        except (OSError, urlerror.URLError):
            return "degraded"

    def ensure_kanban_board(self) -> bool:
        try:
            completed = subprocess.run(
                ["hermes", "kanban", "init", "--board", self.store.project_id],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except FileNotFoundError:
            return False
        return completed.returncode == 0

    def proxy_v1(self, path_with_query: str, method: str, body: bytes | None = None) -> tuple[int, dict[str, Any]]:
        url = f"{self.upstream_api_url.rstrip('/')}{path_with_query}"
        request = urlrequest.Request(url, data=body, method=method)
        try:
            with urlrequest.urlopen(request, timeout=2) as response:
                raw = response.read().decode("utf-8")
                if not raw:
                    return response.status, {"schema_version": SCHEMA_VERSION}
                try:
                    data = json.loads(raw)
                except json.JSONDecodeError:
                    data = {"schema_version": SCHEMA_VERSION, "upstream_body": raw}
                return response.status, data
        except (OSError, urlerror.URLError):
            return 502, self.error("upstream_unavailable", "official Hermes API upstream is unavailable")

    def capabilities(self) -> dict[str, Any]:
        cache_root = os.environ.get("CACHE_ROOT", str(Path(os.environ.get("HOME", str(Path.home()))) / ".cache/hermes-orchestra"))
        debate_teams = self.config_items("config/debate/teams.json", "teams")
        debate_modes = self.config_items("config/debate/modes.json", "modes")
        try:
            runtime_activation = self.runtime_activation.summary()
        except RuntimeActivationError as exc:
            runtime_activation = {
                "config_ref": self.runtime_activation.config_path,
                "error": getattr(exc, "message", str(exc) or "runtime activation unavailable"),
            }
        routes = [
            "GET /health",
            "GET /orchestra/capabilities",
            "POST /orchestra/runs",
            "GET /orchestra/runs/{run_id}",
            "GET /orchestra/runs/{run_id}/events",
            "GET /orchestra/runs/{run_id}/tasks",
            "POST /orchestra/runs/{run_id}/stop",
            "POST /orchestra/runs/{run_id}/worker-outputs",
            "POST /orchestra/runs/{run_id}/verdicts",
            "POST /orchestra/runs/{run_id}/global-evaluations",
            "POST /orchestra/runs/{run_id}/closeout",
            "POST /orchestra/runs/{run_id}/failures",
            "POST /orchestra/decisions/{decision_id}",
            *[spec["route"] for spec in FULL_MODULE_ENDPOINTS],
        ]
        worker_registry = {
            name: {
                "name": name,
                "enabled": bool(config.get("enabled")),
                "available": bool(config.get("available")),
                "adapter_type": config.get("kind"),
                "compatible_roles": config.get("roles", []),
                "modes": ["mvp_full"],
                "capabilities": ["structured_envelope"],
                "missing_dependency": None,
                "health_checked_at": utc_now(),
                "selection_blocked_reason": None,
            }
            for name, config in WORKER_BACKENDS.items()
        }
        return {
            "schema_version": SCHEMA_VERSION,
            "project": self.store.project_id,
            "gateway": {
                "project": self.store.project_id,
                "host": "127.0.0.1",
                "schema_version": SCHEMA_VERSION,
            },
            "authority_model": {
                "phase": "phase_1",
                "trust_boundary": "localhost_only",
                "authentication": "none",
                "authority_field_is_advisory_within_loopback": True,
            },
            "upstream_api": {
                "url": self.upstream_api_url,
                "status": self.upstream_status(),
            },
            "kanban": {
                "backend": "official_hermes_kanban",
                "project": self.store.project_id,
                "kimi_mutation_api": False,
            },
            "routes": routes,
            "modes": ["mvp_full"],
            "workers": {
                "config_ref": "config/workers/backends.json",
                "default_pairing": {"implementer": "codex", "reviewer": "claude"},
                "registry": worker_registry,
            },
            "roles": {
                "config_ref": "config/workers/roles.json",
                "implementer": {"preferred_backend": "codex", "required_capabilities": ["structured_envelope"]},
                "reviewer": {"preferred_backend": "claude", "required_capabilities": ["structured_verdict"]},
            },
            "cache": {
                "backend": "local_filesystem",
                "available": True,
                "root": cache_root,
                "degraded": False,
                "fallback_backend": None,
            },
            "runtime_activation": runtime_activation,
            "debaters": {
                "default_backend": "template",
                "teams_config_ref": "config/debate/teams.json",
                "modes_config_ref": "config/debate/modes.json",
                "team_count": len(debate_teams),
                "mode_count": len(debate_modes),
                "registry": {
                    "template": {
                        "name": "template",
                        "enabled": True,
                        "available": True,
                        "backend_type": "template",
                        "degraded": True,
                        "missing_dependency": None,
                    }
                },
            },
            "worker_backends": WORKER_BACKENDS,
            "full_module_endpoints": FULL_MODULE_ENDPOINTS,
        }

    def config_items(self, relative_path: str, key: str) -> list[Any]:
        path = self.repo_root / relative_path
        try:
            data = read_json(path)
        except (OSError, json.JSONDecodeError):
            return []
        items = data.get(key)
        return items if isinstance(items, list) else []

    def module_endpoint(self, module: str, operation: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if self._run_intake_pipeline(payload, f"module:{module}:{operation}"):
            return self._fallback_response()
        spec = FULL_MODULE_ENDPOINT_INDEX.get((module, operation))
        if spec is None:
            return 404, self.error("not_found", "module endpoint not found")
        authority_error = self.require_module_authority(payload, spec["authority"])
        if authority_error is not None:
            return authority_error
        try:
            result = self.dispatch_module_operation(module, operation, payload)
        except Exception as exc:  # noqa: BLE001
            code = getattr(exc, "code", "module_execution_failed")
            message = getattr(exc, "message", str(exc) or f"{module}/{operation} failed")
            return 400, self.error(code, message)
        return 200, {
            "schema_version": SCHEMA_VERSION,
            "module": module,
            "operation": operation,
            "authority": spec["authority"],
            "result": result,
        }

    def require_module_authority(self, payload: dict[str, Any], expected_authority: str) -> tuple[int, dict[str, Any]] | None:
        authority = payload.get("authority")
        if authority == expected_authority:
            return None
        return 403, self.error("authority_required", f"authority must be {expected_authority}")

    def dispatch_module_operation(self, module: str, operation: str, payload: dict[str, Any]) -> Any:
        allow_staged = self.module_allow_staged(module, payload)
        enabled = self.bool_payload(payload, "enabled", True)

        if module == "debate-engine":
            from debate_engine import DebateEngine

            engine = DebateEngine(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "load-registries":
                return engine.load_registries()
            if operation == "create-run":
                return engine.create_run(
                    question=self.require_string(payload, "question"),
                    mode_id=self.require_string(payload, "mode_id"),
                    selected_member_ids=self.list_value(payload, "selected_member_ids", []),
                    metadata=self.dict_value(payload, "metadata", {}),
                )

        if module == "debate-assembly":
            from debate_assembly import DebateAssembly

            assembly = DebateAssembly(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "select-for-stage":
                return assembly.select_for_stage(
                    stage=self.require_string(payload, "stage"),
                    task_type=self.require_string(payload, "task_type"),
                    risk_level=self.require_string(payload, "risk_level"),
                    project_overrides=self.dict_value(payload, "project_overrides", {}),
                )

        if module == "debate-backend-adapter":
            from debate_backend_adapter import DebateBackendAdapterRegistry

            adapter = DebateBackendAdapterRegistry(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "select-backend":
                return adapter.select_backend(
                    stage=self.require_string(payload, "stage"),
                    preferred_backend_id=self.optional_string(payload, "preferred_backend_id"),
                )

        if module == "debate-member-invocation":
            from debate_member_invocation import DebateMemberInvocationService

            service = DebateMemberInvocationService(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "build-invocation":
                return service.build_invocation(
                    run=self.require_dict(payload, "run"),
                    assembly=self.require_dict(payload, "assembly"),
                    member_id=self.require_string(payload, "member_id"),
                    input_refs=self.require_string_list(payload, "input_refs"),
                    context_refs=self.list_value(payload, "context_refs", []),
                    option_refs=self.list_value(payload, "option_refs", []),
                    affected_scopes=self.list_value(payload, "affected_scopes", []),
                    preferred_backend_id=self.optional_string(payload, "preferred_backend_id"),
                )
            if operation == "execute":
                return service.execute(
                    run=self.require_dict(payload, "run"),
                    assembly=self.require_dict(payload, "assembly"),
                    input_refs=self.require_string_list(payload, "input_refs"),
                    context_refs=self.list_value(payload, "context_refs", []),
                    option_refs=self.list_value(payload, "option_refs", []),
                    affected_scopes=self.list_value(payload, "affected_scopes", []),
                    preferred_backend_id=self.optional_string(payload, "preferred_backend_id"),
                )

        if module == "debate-report":
            from debate_report import DebateReportBuilder

            builder = DebateReportBuilder(self.repo_root)
            if operation == "build":
                return builder.build(
                    run=self.require_dict(payload, "run"),
                    assembly=self.require_dict(payload, "assembly"),
                    backend_policy=self.require_dict(payload, "backend_policy"),
                    invocations=self.require_list(payload, "invocations"),
                    opinions=self.require_list(payload, "opinions"),
                    invocation_receipts=self.require_list(payload, "invocation_receipts"),
                    input_refs=self.require_string_list(payload, "input_refs"),
                    affected_scopes=self.require_string_list(payload, "affected_scopes"),
                )

        if module == "worker-registry":
            from worker_registry import WorkerRegistry

            registry = WorkerRegistry(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "load-backends":
                return registry.load_backends()
            if operation == "load-roles":
                return registry.load_roles()

        if module == "capability-negotiation":
            from capability_negotiation import CapabilityNegotiator
            from worker_registry import WorkerRegistry

            registry = WorkerRegistry(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            negotiator = CapabilityNegotiator(registry)
            if operation == "negotiate":
                return negotiator.negotiate(
                    role=self.require_string(payload, "role"),
                    requested_backend=self.optional_string(payload, "requested_backend"),
                    required_capabilities=self.list_value(payload, "required_capabilities", []),
                    negotiation_context=self.dict_value(payload, "negotiation_context", {}),
                )

        if module == "worker-session":
            from worker_session import WorkerSessionManager

            manager = WorkerSessionManager(self.repo_root)
            if operation == "create-session":
                return manager.create_session(
                    run_id=self.require_string(payload, "run_id"),
                    task_id=self.require_string(payload, "task_id"),
                    role=self.require_string(payload, "role"),
                    backend_id=self.require_string(payload, "backend_id"),
                    workspace_root=self.require_string(payload, "workspace_root"),
                    write_scope_ref=self.require_string(payload, "write_scope_ref"),
                    context_bundle_ref=self.require_string(payload, "context_bundle_ref"),
                    timeout_seconds=self.require_int(payload, "timeout_seconds"),
                    transcript_ref=self.optional_string(payload, "transcript_ref"),
                    output_envelope_ref=self.optional_string(payload, "output_envelope_ref"),
                )
            if operation == "transition":
                return manager.transition(
                    record=self.require_dict(payload, "record"),
                    next_status=self.require_string(payload, "next_status"),
                    exit_signal=self.optional_string(payload, "exit_signal"),
                    output_envelope_ref=self.optional_string(payload, "output_envelope_ref"),
                    cleanup_status=self.optional_string(payload, "cleanup_status"),
                    termination_reason=self.optional_string(payload, "termination_reason"),
                )

        if module == "worker-session-sweeper":
            from worker_session_sweeper import WorkerSessionSweeper

            sweeper = WorkerSessionSweeper(self.repo_root)
            if operation == "sweep-directory":
                return sweeper.sweep_directory(self.require_string(payload, "records_root"))

        if module == "release-pipeline":
            from release_pipeline import ReleasePipeline

            pipeline = ReleasePipeline(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "load-pipeline":
                return pipeline.load_pipeline()
            if operation == "load-registry":
                return pipeline.load_registry()
            if operation == "validate-command-refs":
                return pipeline.validate_command_refs()
            if operation == "plan":
                return pipeline.plan(self.require_string(payload, "environment"))

        if module == "release-executor":
            from release_executor import ReleaseExecutor

            executor = ReleaseExecutor(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "execute":
                return executor.execute(
                    command_ref=self.require_string(payload, "command_ref"),
                    approval_ref=self.optional_string(payload, "approval_ref"),
                    run_id=self.string_value(payload, "run_id", "gateway-release-executor"),
                    environment=self.optional_string(payload, "environment"),
                    test_execution_report_refs=self.list_value(payload, "test_execution_report_refs", []),
                    health_check_refs=self.list_value(payload, "health_check_refs", []),
                    rollback_or_recovery_refs=self.list_value(payload, "rollback_or_recovery_refs", []),
                    gate_results=self.dict_value(payload, "gate_results", {}),
                )

        if module == "runtime-knowledge":
            from runtime_knowledge import RuntimeKnowledgeBase

            knowledge = RuntimeKnowledgeBase(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "query":
                return knowledge.query(self.require_dict(payload, "request"))

        if module == "knowledge-ingestion":
            from knowledge_ingestion import KnowledgeIngestion

            ingestion = KnowledgeIngestion(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "ingest":
                return ingestion.ingest(self.require_dict(payload, "entry"))

        if module == "self-evolution":
            from self_evolution import SelfEvolutionQueue

            queue = SelfEvolutionQueue(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "generate-stage6-sweep":
                return queue.generate_stage6_sweep(
                    run_id=self.require_string(payload, "run_id"),
                    source_refs=self.require_string_list(payload, "source_refs"),
                    proposals=self.require_list(payload, "proposals"),
                    trigger_matches=self.require_string_list(payload, "trigger_matches"),
                )
            if operation == "enqueue":
                return queue.enqueue(self.require_dict(payload, "proposal"))
            if operation == "transition":
                return queue.transition(
                    queue_item=self.require_dict(payload, "queue_item"),
                    next_status=self.require_string(payload, "next_status"),
                    decision_ref=self.optional_string(payload, "decision_ref"),
                    rejection_reason=self.optional_string(payload, "rejection_reason"),
                    kimi_review_ref=self.optional_string(payload, "kimi_review_ref"),
                    human_approval_ref=self.optional_string(payload, "human_approval_ref"),
                )
            if operation == "list-pending":
                pending = queue.list_pending(self.list_value(payload, "queue_items", []))
                return {"items": pending}

        if module == "performance-slo":
            from performance_slo import PerformanceBudgetPolicy

            slo = PerformanceBudgetPolicy(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "evaluate":
                return slo.evaluate(
                    component_id=self.require_string(payload, "component_id"),
                    observed=self.require_dict(payload, "observed"),
                )

        if module == "channel-router":
            from channel_router import ChannelRouter

            router = ChannelRouter(self.repo_root)
            if operation == "classify":
                return router.classify(
                    intent=self.require_dict(payload, "intent"),
                    project_age_weeks=self.require_int(payload, "project_age_weeks"),
                    profile=self.dict_value(payload, "profile", {}),
                )

        if module == "rollout-gate":
            from rollout_gate import RolloutGate

            gate = RolloutGate(self.repo_root)
            if operation == "allow":
                return gate.allow(
                    channel=self.require_string(payload, "channel"),
                    project_age_weeks=self.require_int(payload, "project_age_weeks"),
                    calibration_evidence=self.require_dict(payload, "calibration_evidence"),
                )

        if module == "evidence-scanner":
            from evidence_scanner import EvidenceScanner

            scanner = EvidenceScanner()
            if operation == "scan":
                return scanner.scan(
                    diff=self.require_string(payload, "diff"),
                    files=self.require_string_list(payload, "files"),
                )

        if module == "security-gate":
            from security_gate import SecurityGate

            gate = SecurityGate()
            if operation == "evaluate":
                return gate.evaluate(self.require_dict(payload, "scan"))

        if module == "auto-merge":
            from auto_merge_controller import AutoMergeController

            controller = AutoMergeController(self.repo_root)
            if operation == "merge":
                return controller.merge(
                    target_branch=self.require_string(payload, "target_branch"),
                    pr_number=self.require_int(payload, "pr_number"),
                    audit_context=self.require_dict(payload, "audit_context"),
                )

        if module == "notification":
            from auto_merge_controller import NotificationDispatcher

            dispatcher = NotificationDispatcher(self.repo_root)
            if operation == "send":
                return dispatcher.send(
                    level=self.require_string(payload, "level"),
                    scan_result=self.require_dict(payload, "scan_result"),
                )

        if module == "fixture-policy":
            from fixture_policy import FixturePolicy

            fixture_policy = FixturePolicy(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "validate-contract-fixture":
                return fixture_policy.validate_contract_fixture(
                    family_id=self.require_string(payload, "family_id"),
                    fixture=self.require_dict(payload, "fixture"),
                )
            if operation == "validate-runtime-fake-adapter":
                return fixture_policy.validate_runtime_fake_adapter(
                    family_id=self.require_string(payload, "family_id"),
                    fixture=self.require_dict(payload, "fixture"),
                )

        if module == "degradation-policy":
            from degradation_policy import DegradationPolicy

            policy = DegradationPolicy(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "transition":
                next_status = policy.transition(
                    current_status=self.require_string(payload, "current_status"),
                    next_status=self.require_string(payload, "next_status"),
                )
                return {"next_status": next_status}
            if operation == "build-record":
                return policy.build_record(
                    degradation_status=self.require_string(payload, "degradation_status"),
                    degradation_class=self.require_string(payload, "degradation_class"),
                    cause=self.require_string(payload, "cause"),
                    affected_evidence_refs=self.require_string_list(payload, "affected_evidence_refs"),
                    recovery_options=self.require_string_list(payload, "recovery_options"),
                    policy_key=self.optional_string(payload, "policy_key"),
                    decision_required=self.optional_string(payload, "decision_required"),
                    accepted_by_ref=self.optional_string(payload, "accepted_by_ref"),
                    completion_evidence_allowed=payload.get("completion_evidence_allowed"),
                    replacement_evidence_ref=self.optional_string(payload, "replacement_evidence_ref"),
                    policy_ref=self.string_value(payload, "policy_ref", "config://degradation/policy"),
                )
            if operation == "allows-completion-evidence":
                return {"allowed": policy.allows_completion_evidence(self.require_dict(payload, "record"))}

        if module == "full-schema-validation":
            from full_schema_validation import FullSchemaValidation

            validation = FullSchemaValidation(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "validate-schema":
                return validation.validate_schema()
            if operation == "validate-contract":
                return validation.validate_contract(
                    rel_path=self.require_string(payload, "rel_path"),
                    definition_name=self.require_string(payload, "definition_name"),
                )
            if operation == "validate-all":
                return validation.validate_all()

        if module == "full-schema-cutover":
            from staged_cutover import FullSchemaCutover

            cutover = FullSchemaCutover(self.repo_root, allow_staged=allow_staged, enabled=enabled)
            if operation == "evaluate-family":
                return cutover.evaluate_family(self.require_string(payload, "family_id"))
            if operation == "can-activate":
                return cutover.can_activate(
                    self.require_string(payload, "family_id"),
                    evidence=self.list_value(payload, "evidence", []),
                    completed_checks=self.list_value(payload, "completed_checks", []),
                )
            if operation == "plan-artifact-write":
                return cutover.plan_artifact_write(
                    family_id=self.require_string(payload, "family_id"),
                    family_activated=self.bool_payload(payload, "family_activated", False),
                    historical_run=self.bool_payload(payload, "historical_run", False),
                    existing_schema_version=self.optional_string(payload, "existing_schema_version"),
                )

        raise ValueError(f"unsupported module operation: {module}/{operation}")

    def module_allow_staged(self, module: str, payload: dict[str, Any]) -> bool:
        if "allow_staged" in payload:
            return self.bool_payload(payload, "allow_staged", False)
        try:
            return self.runtime_activation.default_allow_staged(module)
        except RuntimeActivationError:
            return False

    def bool_payload(self, payload: dict[str, Any], key: str, default: bool) -> bool:
        value = payload.get(key, default)
        if not isinstance(value, bool):
            raise ValueError(f"{key} must be a boolean")
        return value

    def string_value(self, payload: dict[str, Any], key: str, default: str) -> str:
        value = payload.get(key, default)
        if not isinstance(value, str) or not value:
            raise ValueError(f"{key} must be a non-empty string")
        return value

    def optional_string(self, payload: dict[str, Any], key: str) -> str | None:
        value = payload.get(key)
        if value is None:
            return None
        if not isinstance(value, str) or not value:
            raise ValueError(f"{key} must be a non-empty string when provided")
        return value

    def require_string(self, payload: dict[str, Any], key: str) -> str:
        return self.string_value(payload, key, "")

    def require_int(self, payload: dict[str, Any], key: str) -> int:
        value = payload.get(key)
        if not isinstance(value, int):
            raise ValueError(f"{key} must be an integer")
        return value

    def require_dict(self, payload: dict[str, Any], key: str) -> dict[str, Any]:
        value = payload.get(key)
        if not isinstance(value, dict):
            raise ValueError(f"{key} must be an object")
        return value

    def dict_value(self, payload: dict[str, Any], key: str, default: dict[str, Any]) -> dict[str, Any]:
        value = payload.get(key, default)
        if not isinstance(value, dict):
            raise ValueError(f"{key} must be an object")
        return value

    def require_list(self, payload: dict[str, Any], key: str) -> list[Any]:
        value = payload.get(key)
        if not isinstance(value, list):
            raise ValueError(f"{key} must be a list")
        return value

    def list_value(self, payload: dict[str, Any], key: str, default: list[Any]) -> list[Any]:
        value = payload.get(key, default)
        if not isinstance(value, list):
            raise ValueError(f"{key} must be a list")
        return value

    def require_string_list(self, payload: dict[str, Any], key: str) -> list[str]:
        values = self.require_list(payload, key)
        if not all(isinstance(item, str) and item for item in values):
            raise ValueError(f"{key} must contain only non-empty strings")
        return list(values)

    def recover_in_progress_commands(self) -> None:
        runs_dir = self.store.state_dir / "runs"
        if not runs_dir.exists():
            return
        for command_path in sorted(runs_dir.glob("*/commands/*.json")):
            try:
                command = read_json(command_path)
            except (OSError, json.JSONDecodeError):
                continue
            if command.get("status") != "in_progress":
                continue
            run_id = command_path.parent.parent.name
            if command.get("intent") == "create_run" and self.create_run_command_completed(run_id, command):
                command_id = command.get("command_id")
                if not isinstance(command_id, str):
                    continue
                idempotency_key = command.get("idempotency_key")
                if not isinstance(idempotency_key, str):
                    idempotency_key = ""
                run = read_json(self.store.run_path(run_id))
                command["status"] = "completed"
                command["recovery_action"] = "completed_without_replay"
                command["updated_at"] = utc_now()
                command["response_summary"] = self.run_response(
                    run_id,
                    command_id,
                    idempotency_key,
                    str(run.get("status") or "queued"),
                    run.get("source_run_id") if isinstance(run.get("source_run_id"), str) else None,
                    run.get("lineage_ref") if isinstance(run.get("lineage_ref"), str) else None,
                )
                command["steps"] = command.get("steps") if isinstance(command.get("steps"), list) else []
                command["steps"].append(
                    {
                        "step_id": "reconcile_command",
                        "target_authority": "state",
                        "operation": "reconcile",
                        "status": "completed",
                        "refs": [
                            self.store.state_ref(run_id, "run.json"),
                            self.store.state_ref(run_id, "tasks.json"),
                            self.store.audit_ref(command_id),
                        ],
                    }
                )
                write_json(command_path, command)
            elif command.get("intent") == "create_run" and self.create_run_command_can_continue(run_id, command):
                self.continue_create_run_command(run_id, command_path, command)
            elif command.get("intent") == "create_run" and self.store.run_path(run_id).exists():
                self.block_ambiguous_command(run_id, command_path, command)

    def create_run_command_completed(self, run_id: str, command: dict[str, Any]) -> bool:
        command_id = command.get("command_id")
        if not isinstance(command_id, str):
            return False
        return (
            self.store.run_path(run_id).exists()
            and self.store.tasks_path(run_id).exists()
            and self.find_audit_record(command_id, "run_created") is not None
        )

    def command_step_completed(self, command: dict[str, Any], step_id: str) -> bool:
        return self.command_step_status(command, step_id) == "completed"

    def command_step_status(self, command: dict[str, Any], step_id: str) -> str | None:
        steps = command.get("steps")
        if not isinstance(steps, list):
            return None
        for step in steps:
            if isinstance(step, dict) and step.get("step_id") == step_id:
                status = step.get("status")
                return status if isinstance(status, str) else None
        return None

    def create_run_command_can_continue(self, run_id: str, command: dict[str, Any]) -> bool:
        command_id = command.get("command_id")
        if not isinstance(command_id, str):
            return False
        return (
            self.store.run_path(run_id).exists()
            and self.command_step_completed(command, "write_run_state")
            and self.command_step_status(command, "create_kanban_stage_tasks") == "not_started"
            and not self.store.tasks_path(run_id).exists()
            and not self.store.events_path(run_id).exists()
            and self.find_audit_record(command_id, "run_created") is None
        )

    def continue_create_run_command(self, run_id: str, command_path: Path, command: dict[str, Any]) -> None:
        command_id = command.get("command_id")
        if not isinstance(command_id, str):
            return
        idempotency_key = command.get("idempotency_key")
        if not isinstance(idempotency_key, str):
            idempotency_key = ""
        endpoint = str(command.get("endpoint") or "POST /orchestra/runs")
        resource_path = str(command.get("resource_path") or "/orchestra/runs")
        payload_hash = str(command.get("payload_hash") or "")
        now = utc_now()
        run_ref = self.store.state_ref(run_id, "run.json")
        tasks_ref = self.store.state_ref(run_id, "tasks.json")
        audit_ref = self.store.audit_ref(command_id)

        stage_tasks = self.create_kanban_stage_tasks(run_id)
        tasks = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "project": self.store.project_id,
            "projection_status": "consistent",
            "authority_refs_checked": [run_ref],
            "tasks": stage_tasks,
            "updated_at": now,
        }
        write_json(self.store.tasks_path(run_id), tasks)

        run = read_json(self.store.run_path(run_id))
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["command_record"] = self.store.state_ref(run_id, f"commands/{command_id}.json")
        artifact_refs["task_projection"] = tasks_ref
        run.update(
            {
                "status": run.get("status") or "queued",
                "last_command_id": command_id,
                "updated_at": now,
                "blocked_reason": None,
                "pending_decision_id": None,
                "pending_decision_refs": [],
                "artifact_refs": artifact_refs,
            }
        )
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": run.get("status"), "updated_at": now})

        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "run_created",
                "decision": "RECORDED",
                "user_decision": "",
                "details": f"Six-Stage Run recovered from checkpoint: {run_id}",
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
            },
        )

        projection_issue_refs = []
        projection_issue_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": None,
                "type": "run_created",
                "severity": "info",
                "status": run.get("status") or "queued",
                "message": "Six-Stage Run recovered from checkpoint",
                "artifact_refs": [run_ref, tasks_ref, audit_ref],
                "decision_id": None,
            },
        )
        if projection_issue_ref:
            projection_issue_refs.append(projection_issue_ref)
        response = self.run_response(
            run_id,
            command_id,
            idempotency_key,
            str(run.get("status") or "queued"),
            run.get("source_run_id") if isinstance(run.get("source_run_id"), str) else None,
            run.get("lineage_ref") if isinstance(run.get("lineage_ref"), str) else None,
            bool(projection_issue_refs),
            projection_issue_refs,
        )
        steps = command.get("steps") if isinstance(command.get("steps"), list) else []
        steps.extend(
            [
                {"step_id": "create_kanban_stage_tasks", "target_authority": "hermes_kanban", "operation": "create", "status": "completed", "refs": [task.get("kanban_ref") for task in stage_tasks]},
                {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [tasks_ref]},
                {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
                {
                    "step_id": "append_event_projection",
                    "target_authority": "state",
                    "operation": "append",
                    "status": "failed" if projection_issue_refs else "completed",
                    "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl#seq=1")],
                },
                {"step_id": "reconcile_command", "target_authority": "state", "operation": "reconcile", "status": "continued_from_checkpoint", "refs": [run_ref, tasks_ref, audit_ref]},
            ]
        )
        command["status"] = "completed"
        command["recovery_action"] = "continued_from_checkpoint"
        command["updated_at"] = utc_now()
        command["steps"] = steps
        command["response_summary"] = response
        write_json(command_path, command)
        write_json(
            self.store.idempotency_path(endpoint, resource_path, idempotency_key),
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 201,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )

    def block_ambiguous_command(self, run_id: str, command_path: Path, command: dict[str, Any]) -> None:
        command_id = command.get("command_id")
        if not isinstance(command_id, str):
            return
        now = utc_now()
        decision_id = f"decision-{uuid.uuid4().hex[:16]}"
        report_ref = self.store.state_ref(run_id, f"command-reconciliation-reports/{command_id}.json")
        run_ref = self.store.state_ref(run_id, "run.json")
        report = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_reconciliation_report",
            "run_id": run_id,
            "command_id": command_id,
            "original_intent": command.get("intent"),
            "recovery_result": "blocked_ambiguous",
            "reason": "Gateway could not prove whether all create_run side effects completed",
            "checked_refs": [run_ref, self.store.state_ref(run_id, "tasks.json"), self.store.audit_ref(command_id)],
            "missing_or_unproven_refs": [
                ref
                for ref, exists in (
                    (self.store.state_ref(run_id, "tasks.json"), self.store.tasks_path(run_id).exists()),
                    (self.store.audit_ref(command_id), self.find_audit_record(command_id, "run_created") is not None),
                )
                if not exists
            ],
            "decision_id": decision_id,
            "created_at": now,
        }
        write_json(self.store.run_dir(run_id) / "command-reconciliation-reports" / f"{command_id}.json", report)

        run = read_json(self.store.run_path(run_id))
        pending_refs = run.get("pending_decision_refs") if isinstance(run.get("pending_decision_refs"), list) else []
        if report_ref not in pending_refs:
            pending_refs.append(report_ref)
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["command_reconciliation_report"] = report_ref
        run.update(
            {
                "status": "blocked",
                "last_command_id": command_id,
                "updated_at": now,
                "blocked_reason": "command_reconciliation_ambiguous",
                "pending_decision_id": decision_id,
                "pending_decision_refs": pending_refs,
                "artifact_refs": artifact_refs,
            }
        )
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "blocked", "updated_at": now})

        command["status"] = "failed"
        command["recovery_action"] = "blocked_ambiguous"
        command["updated_at"] = now
        steps = command.get("steps") if isinstance(command.get("steps"), list) else []
        steps.append(
            {
                "step_id": "reconcile_command",
                "target_authority": "state",
                "operation": "reconcile",
                "status": "ambiguous",
                "refs": [report_ref, run_ref],
            }
        )
        command["steps"] = steps
        command["reconciliation_report_ref"] = report_ref
        write_json(command_path, command)

        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L2",
                "project": self.store.project_id,
                "type": "decision_required",
                "decision": "PENDING",
                "user_decision": "",
                "details": "Command recovery is ambiguous; Gateway blocked instead of replaying side effects",
                "approval_id": decision_id,
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "reconciliation_report_ref": report_ref,
            },
        )
        self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": command.get("idempotency_key"),
                "run_id": run_id,
                "task_id": None,
                "stage": run.get("current_stage"),
                "type": "decision_required",
                "severity": "error",
                "status": "blocked",
                "message": "Command recovery requires decision before continuing",
                "artifact_refs": [report_ref, run_ref],
                "decision_id": decision_id,
            },
        )

    def create_run(self, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if self._run_intake_pipeline(payload, "create_run"):
            return self._fallback_response()
        idempotency_key = payload.get("idempotency_key")
        ticket = payload.get("ticket")
        intent = payload.get("intent")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")
        if not isinstance(ticket, dict) and not isinstance(intent, str):
            return 400, self.error("validation_error", "ticket or intent is required")
        worker_error = self.validate_worker_pairing(payload.get("options"))
        if worker_error is not None:
            return worker_error

        endpoint = "POST /orchestra/runs"
        resource_path = "/orchestra/runs"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 201), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        lineage_input = self.validate_lineage_input(payload)
        if isinstance(lineage_input, tuple):
            return lineage_input

        active_run = self.active_run()
        if active_run is not None:
            body = self.error("active_run_conflict", "project already has an active Six-Stage Run")
            body["active_run_id"] = active_run.get("run_id")
            body["active_status"] = active_run.get("status")
            return 409, body

        if not isinstance(ticket, dict):
            return self.create_intent_blocked_run(payload, idempotency_key, endpoint, resource_path, payload_hash, idempotency_path)

        now = utc_now()
        run_id = f"run-{uuid.uuid4().hex[:16]}"
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        lineage_ref = self.store.state_ref(run_id, "lineage.json") if lineage_input else None
        source_run_id = lineage_input.get("source_run_id") if lineage_input else None
        completion_bundle_ref = self.store.state_ref(run_id, "requirement-completion-bundle.json")
        completion_bundle = self._requirement_completion_bundle(payload, "create_run", run_id)
        bundle_validation = _completion_bundle_validate(completion_bundle)
        if bundle_validation.get("status") == "blocked":
            body = self.error("completion_bundle_blocked", "requirement completion bundle is incomplete")
            body.update(bundle_validation)
            return 409, body

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "create_run",
            "planned_side_effects": [
                "write_requirement_completion_bundle",
                "write_run_state",
                "create_kanban_stage_tasks",
                "write_task_projection",
                "write_mvp_acceptance_artifacts",
                "write_lineage" if lineage_input else None,
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        command_record["planned_side_effects"] = [step for step in command_record["planned_side_effects"] if step]
        write_json(command_path, command_record)

        write_json(self.store.run_dir(run_id) / "requirement-completion-bundle.json", completion_bundle)
        stage_tasks = self.create_kanban_stage_tasks(run_id)
        mvp_artifact_refs = self.write_initial_mvp_artifacts(run_id, ticket, stage_tasks, command_id, now, completion_bundle_ref)
        tasks = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "project": self.store.project_id,
            "projection_status": "consistent",
            "authority_refs_checked": [self.store.state_ref(run_id, "run.json"), completion_bundle_ref],
            "tasks": stage_tasks,
            "updated_at": now,
        }
        write_json(self.store.tasks_path(run_id), tasks)

        if lineage_input:
            lineage = {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "run_lineage",
                "lineage_id": f"lineage-{uuid.uuid4().hex[:16]}",
                "run_id": run_id,
                "source_run_id": lineage_input["source_run_id"],
                "source_status": lineage_input["source_status"],
                "resume_from_refs": lineage_input["resume_from_refs"],
                "source_state_refs": [self.store.state_ref(lineage_input["source_run_id"], "run.json")],
                "source_audit_refs": [],
                "source_kanban_refs": [],
                "source_closeout_ref": lineage_input.get("source_closeout_ref"),
                "source_failure_refs": [],
                "rationale": "Continue from terminal source run evidence",
                "created_at": now,
            }
            write_json(self.store.run_dir(run_id) / "lineage.json", lineage)

        run = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "status": "queued",
            "project": self.store.project_id,
            "last_command_id": command_id,
            "source_run_id": source_run_id,
            "lineage_ref": lineage_ref,
            "created_at": now,
            "updated_at": now,
            "current_stage": "direction_debate",
            "progress": {"completed_stages": 0, "total_stages": len(STAGES)},
            "stages": [{"stage": stage, "status": "queued"} for stage in STAGES],
            "blocked_reason": None,
            "failure_reason": None,
            "failure_report_ref": None,
            "failure_audit_ref": None,
            "last_good_checkpoint_ref": None,
            "lineage_hint_refs": [],
            "pending_decision_id": None,
            "pending_decision_refs": [],
            "resume_checkpoint_refs": [],
            "stopped_reason": None,
            "stop_audit_ref": None,
            "artifact_refs": {
                "command_record": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "task_projection": self.store.state_ref(run_id, "tasks.json"),
                **mvp_artifact_refs,
            },
        }
        if lineage_ref:
            run["artifact_refs"]["lineage"] = lineage_ref
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "queued", "updated_at": now})

        audit_record = {
            "timestamp": now,
            "level": "L1",
            "project": self.store.project_id,
            "type": "run_created",
            "decision": "RECORDED",
            "user_decision": "",
            "details": f"Six-Stage Run created: {run_id}",
            "approval_id": "",
            "ttl": "",
            "task_id": run_id,
            "escalation_id": "",
            "agent_source": "orch-gateway",
            "session_id": "",
            "command_id": command_id,
            "run_id": run_id,
        }
        append_jsonl(self.store.audit_path(), audit_record)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "mvp_acceptance_artifacts_recorded",
                "decision": "RECORDED",
                "user_decision": "",
                "details": "MVP acceptance artifacts prepared for six-stage run",
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "artifact_refs": list(mvp_artifact_refs.values()),
            },
        )
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "test_execution_recorded",
                "decision": "RECORDED",
                "user_decision": "",
                "details": "MVP test execution evidence recorded",
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "test_execution_ref": mvp_artifact_refs.get("test_execution_report"),
            },
        )
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "worker_context_prepared",
                "decision": "RECORDED",
                "user_decision": "",
                "details": "Scoped Worker Context Envelopes and Context Bundles prepared",
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "context_bundle_refs": [ref for ref in mvp_artifact_refs.values() if "/worker-context-bundles/" in ref],
            },
        )
        if lineage_input:
            append_jsonl(
                self.store.audit_path(),
                {
                    "timestamp": now,
                    "level": "L1",
                    "project": self.store.project_id,
                    "type": "run_lineage_created",
                    "decision": "RECORDED",
                    "user_decision": "",
                    "details": f"Lineage run created from {lineage_input['source_run_id']}",
                    "approval_id": "",
                    "ttl": "",
                    "task_id": run_id,
                    "escalation_id": "",
                    "agent_source": "orch-gateway",
                    "session_id": "",
                    "command_id": command_id,
                    "run_id": run_id,
                    "source_run_id": lineage_input["source_run_id"],
                },
            )

        event = {
            "schema_version": EVENT_SCHEMA_VERSION,
            "seq": 1,
            "timestamp": now,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": None,
            "stage": None,
            "type": "run_created",
            "severity": "info",
            "status": "queued",
            "message": "Six-Stage Run created",
            "artifact_refs": [
                self.store.state_ref(run_id, "run.json"),
                self.store.state_ref(run_id, "tasks.json"),
                self.store.audit_ref(command_id),
            ] + ([lineage_ref] if lineage_ref else []),
            "decision_id": None,
        }
        projection_issue_refs = []
        projection_issue_ref = self.append_event(run_id, event)
        if projection_issue_ref:
            projection_issue_refs.append(projection_issue_ref)
        if self.strict_mvp_evidence_enabled():
            debate_refs = [
                ref
                for key, ref in mvp_artifact_refs.items()
                if key.startswith("debate_report_")
            ]
            append_jsonl(
                self.store.audit_path(),
                {
                    "timestamp": now,
                    "level": "L1",
                    "project": self.store.project_id,
                    "type": "debate_degraded",
                    "decision": "RECORDED",
                    "user_decision": "",
                    "details": "Template debate fallback used for MVP run",
                    "approval_id": "",
                    "ttl": "",
                    "task_id": run_id,
                    "escalation_id": "",
                    "agent_source": "orch-gateway",
                    "session_id": "",
                    "command_id": command_id,
                    "run_id": run_id,
                    "debate_report_refs": debate_refs,
                },
            )
            debate_event_issue_ref = self.append_event(
                run_id,
                {
                    "schema_version": EVENT_SCHEMA_VERSION,
                    "seq": self.next_event_seq(run_id),
                    "timestamp": now,
                    "command_id": command_id,
                    "idempotency_key": idempotency_key,
                    "run_id": run_id,
                    "task_id": None,
                    "stage": "direction_debate",
                    "type": "debate_degraded",
                    "severity": "warning",
                    "status": "queued",
                    "message": "Template debate fallback recorded as degraded evidence",
                    "artifact_refs": debate_refs + [self.store.audit_ref(command_id)],
                    "decision_id": None,
                },
            )
            if debate_event_issue_ref:
                projection_issue_refs.append(debate_event_issue_ref)

        response = self.run_response(
            run_id,
            command_id,
            idempotency_key,
            "queued",
            source_run_id,
            lineage_ref,
            bool(projection_issue_refs),
            projection_issue_refs,
        )
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_requirement_completion_bundle", "target_authority": "state", "operation": "write", "status": "completed", "refs": [completion_bundle_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "run.json")]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "tasks.json")]},
            {"step_id": "write_mvp_acceptance_artifacts", "target_authority": "state", "operation": "write", "status": "completed", "refs": list(mvp_artifact_refs.values())},
            *([{"step_id": "write_lineage", "target_authority": "state", "operation": "write", "status": "completed", "refs": [lineage_ref]}] if lineage_ref else []),
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [self.store.audit_ref(command_id)]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl#seq=1")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 201,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )

        return 201, response

    def write_initial_mvp_artifacts(
        self,
        run_id: str,
        ticket: dict[str, Any],
        stage_tasks: list[dict[str, Any]],
        command_id: str,
        now: str,
        completion_bundle_ref: str | None = None,
    ) -> dict[str, str]:
        run_dir = self.store.run_dir(run_id)
        run_ref = self.store.state_ref(run_id, "run.json")
        structured_prd_ref = self.store.state_ref(run_id, "structured_prd.json")
        development_plan_ref = self.store.state_ref(run_id, "development_plan.json")
        test_plan_ref = self.store.state_ref(run_id, "test_plan.json")
        test_execution_ref = self.store.state_ref(run_id, "test_execution_report.json")
        worker_selection_ref = self.store.state_ref(run_id, "worker_selection_record.json")

        acceptance_criteria = ticket.get("acceptance_criteria") if isinstance(ticket.get("acceptance_criteria"), list) else []
        hard_constraints = ticket.get("hard_constraints") if isinstance(ticket.get("hard_constraints"), list) else []
        soft_constraints = ticket.get("soft_constraints") if isinstance(ticket.get("soft_constraints"), list) else []
        failure_strategy = ticket.get("failure_strategy") if isinstance(ticket.get("failure_strategy"), str) else "Block with evidence"
        deliverables = ticket.get("deliverables") if isinstance(ticket.get("deliverables"), list) else []

        structured_prd = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "structured_prd",
            "run_id": run_id,
            "requirement_summary": ticket.get("goal") or ticket.get("background") or "Hermes Orchestra MVP run",
            "clarification_log": [],
            "touched_modules": [],
            "decomposed_requirements": deliverables,
            "acceptance_criteria": acceptance_criteria,
            "constraints": {"hard": hard_constraints, "soft": soft_constraints},
            "risks": [],
            "failure_strategy": failure_strategy,
            "input_artifact_refs": [ref for ref in [run_ref, completion_bundle_ref] if ref],
            "status": "ready",
            "source": "ticket",
            "created_at": now,
        }
        write_json(run_dir / "structured_prd.json", structured_prd)

        development_plan = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "development_plan",
            "run_id": run_id,
            "mode": "full",
            "child_task_dag": [
                {"task_id": task.get("task_id"), "stage": task.get("stage"), "parents": task.get("parents", [])}
                for task in stage_tasks
            ],
            "d2c_enabled": False,
            "dev_enabled": True,
            "logic_hints_ref": None,
            "worker_assignment": {"implementer": "codex", "reviewer": "claude"},
            "workspace_strategy": "kanban_worktree",
            "parallelism_policy": {
                "top_level_serial": True,
                "allowed_parallel_groups": [],
                "requires_disjoint_write_sets": True,
                "merge_arbitration": "none",
                "notes": "MVP keeps one active run and serial top-level stages.",
            },
            "test_strategy": {
                "test_plan_ref": test_plan_ref,
                "default_command": "make test",
                "generated_test_script_ref": None,
            },
            "rollback_checkpoints": [run_ref],
            "acceptance_criteria": acceptance_criteria,
            "created_at": now,
        }
        write_json(run_dir / "development_plan.json", development_plan)

        criteria_refs = [f"{structured_prd_ref}#acceptance_criteria/{index}" for index, _ in enumerate(acceptance_criteria)]
        cases = []
        for index, criterion in enumerate(acceptance_criteria or ["MVP acceptance smoke"], start=1):
            cases.append(
                {
                    "case_id": f"TC-{index:03d}",
                    "title": str(criterion),
                    "initial_url": None,
                    "preconditions": ["Gateway run is active"],
                    "steps": ["Run the project test entrypoint"],
                    "expected_result": str(criterion),
                    "test_type": "contract",
                    "acceptance_criteria_refs": [criteria_refs[index - 1]] if index - 1 < len(criteria_refs) else [],
                    "command": "make test",
                }
            )
        test_plan = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "test_plan",
            "run_id": run_id,
            "development_plan_ref": development_plan_ref,
            "acceptance_criteria_refs": criteria_refs,
            "source_refs": [structured_prd_ref, development_plan_ref],
            "cases": cases,
            "execution_requirements": {"must_run_first": "make test"},
            "review_status": "planned",
            "created_at": now,
        }
        write_json(run_dir / "test_plan.json", test_plan)
        test_command_record = self.run_acceptance_test_command()
        tests_passed = test_command_record["exit_code"] == 0
        test_execution_report = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "test_execution_report",
            "run_id": run_id,
            "test_plan_ref": test_plan_ref,
            "commands": [test_command_record],
            "exit_code": test_command_record["exit_code"],
            "passed": len(cases) if tests_passed else 0,
            "failed": 0 if tests_passed else len(cases),
            "improvement_cycle": 0,
            "blocked_on_failure": not tests_passed,
            "log_summary": test_command_record["summary"],
            "artifact_refs": [test_plan_ref],
            "created_at": now,
        }
        write_json(run_dir / "test_execution_report.json", test_execution_report)

        worker_selection = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "worker_selection_record",
            "run_id": run_id,
            "role": "implementer",
            "requested_backend": "codex",
            "selected_backend": "codex",
            "backend_version": None,
            "backend_kind": "cli",
            "matched_capabilities": ["structured_envelope"],
            "adapter_type": "cli",
            "fallback_used": False,
            "fallback_reason": None,
            "failure_class": None,
            "attempt": 1,
            "audit_ref": self.store.audit_ref(command_id),
            "created_at": now,
        }
        write_json(run_dir / "worker_selection_record.json", worker_selection)

        artifact_refs: dict[str, str] = {
            "structured_prd": structured_prd_ref,
            "development_plan": development_plan_ref,
            "test_plan": test_plan_ref,
            "test_execution_report": test_execution_ref,
            "worker_selection_record": worker_selection_ref,
        }
        if completion_bundle_ref:
            artifact_refs["requirement_completion_bundle"] = completion_bundle_ref
        for stage in ("direction_debate", "solution_debate"):
            report_ref = self.store.state_ref(run_id, f"debate-reports/{stage}.json")
            debate_report = {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "debate_report",
                "debate_id": f"{run_id}-{stage}",
                "run_id": run_id,
                "stage": stage,
                "backend": "template",
                "degraded": True,
                "mode": "mvp_scaffold",
                "teams": [],
                "question": structured_prd["requirement_summary"],
                "options": [],
                "findings": ["Template debate fallback used for local MVP acceptance evidence."],
                "risks": ["Template output is degraded decision input."],
                "conflicts": [],
                "verdict": "pass_with_downgrade",
                "confidence": "low",
                "risk_level": "low",
                "requires_kimi_decision": False,
                "recommended_next_actions": ["Continue MVP run with downgrade recorded."],
                "artifact_refs": [structured_prd_ref],
                "created_at": now,
            }
            write_json(run_dir / "debate-reports" / f"{stage}.json", debate_report)
            artifact_refs[f"debate_report_{stage}"] = report_ref

        fixed_reports = {
            "best_choice_report.json": ("best_choice_report", "direction_debate", [structured_prd_ref]),
            "implementation_plan_report.json": ("implementation_plan_report", "solution_debate", [development_plan_ref]),
            "task_feedback_report.json": ("task_feedback_report", "implementation", [test_execution_ref]),
            "improvement_report.json": ("improvement_report", "improvement", [test_execution_ref]),
        }
        for filename, (artifact_type, stage, outputs) in fixed_reports.items():
            report_ref = self.store.state_ref(run_id, filename)
            stage_report = {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": artifact_type,
                "run_id": run_id,
                "stage": stage,
                "status": "completed",
                "input_artifact_refs": [structured_prd_ref, development_plan_ref],
                "output_artifact_refs": outputs,
                "decision_refs": [],
                "summary": f"{stage} MVP scaffold report recorded.",
                "risks": [],
                "next_actions": [],
                "created_at": now,
            }
            if artifact_type == "improvement_report":
                stage_report.update(
                    {
                        "improvement_cycle": 0,
                        "source_failure_refs": [],
                        "source_verdict_refs": [],
                        "source_test_execution_refs": [test_execution_ref],
                        "development_plan_ref": development_plan_ref,
                        "scope_assessment": {
                            "within_approved_scope": True,
                            "out_of_scope_items": [],
                            "requires_human_approval": False,
                            "forbidden_targets_touched": [],
                        },
                        "fixes_applied": [],
                        "changed_files": [],
                        "diff_summary": "",
                        "test_commands": ["make test"],
                        "test_result_refs": [test_execution_ref],
                        "re_review_refs": [],
                        "re_test_refs": [test_execution_ref],
                        "blocked_reason": None,
                    }
                )
            write_json(run_dir / filename, stage_report)
            artifact_refs[artifact_type] = report_ref

        for task in stage_tasks:
            task_id = str(task.get("task_id"))
            bundle_ref = self.store.state_ref(run_id, f"worker-context-bundles/{task_id}.json")
            envelope_ref = self.store.state_ref(run_id, f"worker-context-envelopes/{task_id}.json")
            bundle = {
                "schema_version": SCHEMA_VERSION,
                "bundle_id": f"bundle-{task_id}",
                "run_id": run_id,
                "task_id": task_id,
                "scope": "stage_task",
                "source_refs": [structured_prd_ref, development_plan_ref, test_plan_ref],
                "summaries": [
                    {
                        "kind": "requirement_summary",
                        "text": structured_prd["requirement_summary"],
                    }
                ],
                "file_excerpt_refs": [],
                "created_at": now,
                "redaction_applied": True,
            }
            envelope = {
                "protocol": "hermes-role-engine/v1",
                "run_id": run_id,
                "task_id": task_id,
                "correlation_id": task_id,
                "stage": task.get("stage"),
                "role": "implementer",
                "selected_backend": "codex",
                "task": {"title": task.get("title"), "parents": task.get("parents", [])},
                "risk_level": "low",
                "approval_state": {"authority_required": None, "approval_refs": []},
                "allowed_write_scope": {
                    "mode": "scoped_write",
                    "paths": ["scripts/**", "docs/**", ".planning/**"],
                    "forbidden_paths": [".git/", ".env", "AGENTS.md", "CLAUDE.md", "hermes/SOUL.md"],
                    "requires_human_approval": False,
                },
                "workspace_strategy": "kanban_worktree",
                "artifact_refs": [structured_prd_ref, development_plan_ref, test_plan_ref],
                "context_bundle_refs": [bundle_ref],
                "test_requirements": {"test_plan_ref": test_plan_ref, "required_command": "make test"},
                "output_schema_ref": self.store.state_ref(run_id, "schemas/worker_response.schema.json"),
                "created_at": now,
            }
            write_json(run_dir / "worker-context-bundles" / f"{task_id}.json", bundle)
            write_json(run_dir / "worker-context-envelopes" / f"{task_id}.json", envelope)
            refs = task.get("artifact_refs") if isinstance(task.get("artifact_refs"), list) else []
            refs.extend([bundle_ref, envelope_ref])
            task["artifact_refs"] = refs
            artifact_refs[f"context_bundle_{task_id}"] = bundle_ref
            artifact_refs[f"context_envelope_{task_id}"] = envelope_ref
        return artifact_refs

    def run_acceptance_test_command(self) -> dict[str, Any]:
        command = os.environ.get("ORCH_GATEWAY_TEST_COMMAND", "make test")
        if os.environ.get("ORCH_GATEWAY_RUN_TESTS") != "1":
            return {
                "command": command,
                "exit_code": 0,
                "source": "planned_gateway_command",
                "executed": False,
                "summary": "Project test entrypoint planned; execution disabled for fast contract runs.",
            }
        completed = subprocess.run(
            command.split(),
            check=False,
            cwd=self.repo_root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=int(os.environ.get("ORCH_GATEWAY_TEST_TIMEOUT", "120")),
        )
        summary_parts = []
        if completed.stdout:
            summary_parts.append(completed.stdout.strip().splitlines()[-1][:200])
        if completed.stderr:
            summary_parts.append(completed.stderr.strip().splitlines()[-1][:200])
        return {
            "command": command,
            "exit_code": completed.returncode,
            "source": "executed_gateway_command",
            "executed": True,
            "summary": " | ".join(summary_parts) or "command completed without output",
        }

    def append_event(self, run_id: str, event: dict[str, Any]) -> str | None:
        if os.environ.get("ORCH_GATEWAY_FAIL_EVENT_APPEND") == "1":
            return self.write_projection_issue(run_id, event, "fault_injection")
        try:
            append_jsonl(self.store.events_path(run_id), event)
        except OSError:
            return self.write_projection_issue(run_id, event, "append_failed")
        return None

    def write_projection_issue(self, run_id: str, event: dict[str, Any], reason: str) -> str:
        seq = event.get("seq", "unknown")
        name = f"projection-issues/event-append-seq-{seq}.json"
        ref = self.store.state_ref(run_id, name)
        write_json(
            self.store.run_dir(run_id) / name,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "projection_issue",
                "run_id": run_id,
                "issue": "event_append_failed",
                "reason": reason,
                "event_type": event.get("type"),
                "event_seq": event.get("seq"),
                "created_at": utc_now(),
            },
        )
        return ref

    def validate_worker_pairing(self, options: Any) -> tuple[int, dict[str, Any]] | None:
        if not isinstance(options, dict):
            return None
        worker_pairing = options.get("worker_pairing")
        if worker_pairing is None:
            return None
        if not isinstance(worker_pairing, dict):
            return 400, self.error("validation_error", "worker_pairing must be an object")
        for role, backend_name in worker_pairing.items():
            if role not in {"implementer", "reviewer"}:
                return 400, self.error("worker_role_unknown", f"unknown worker role: {role}")
            if not isinstance(backend_name, str) or backend_name not in WORKER_BACKENDS:
                body = self.error("worker_backend_unknown", "worker backend is not registered")
                body["role"] = role
                body["backend"] = backend_name
                return 400, body
            backend = WORKER_BACKENDS[backend_name]
            if role not in backend["roles"]:
                body = self.error("worker_backend_role_incompatible", "worker backend is not compatible with requested role")
                body["role"] = role
                body["backend"] = backend_name
                body["backend_roles"] = backend["roles"]
                return 400, body
            if not backend.get("enabled") or not backend.get("available"):
                body = self.error("worker_backend_unavailable", "worker backend is not available")
                body["role"] = role
                body["backend"] = backend_name
                return 400, body
        return None

    def validate_lineage_input(self, payload: dict[str, Any]) -> dict[str, Any] | tuple[int, dict[str, Any]] | None:
        source_run_id = payload.get("source_run_id")
        if source_run_id is None:
            return None
        if not isinstance(source_run_id, str) or not source_run_id:
            return 400, self.error("validation_error", "source_run_id must be a non-empty string")

        source_path = self.store.run_path(source_run_id)
        if not source_path.exists():
            return 404, self.error("not_found", "source run not found")
        source_run = read_json(source_path)
        source_status = source_run.get("status")
        if source_status not in {"failed", "stopped"}:
            body = self.error("lineage_source_not_terminal", "source_run_id must reference a failed or stopped run")
            body["source_run_id"] = source_run_id
            body["source_status"] = source_status
            if source_status == "blocked":
                body["recovery_mode"] = "decision_in_place"
            return 409, body

        resume_from_refs = payload.get("resume_from_refs")
        if not isinstance(resume_from_refs, list) or not resume_from_refs:
            return 400, self.error("validation_error", "resume_from_refs is required for lineage runs")
        expected_prefix = f"state://runs/{source_run_id}/"
        for ref in resume_from_refs:
            if not self.valid_scoped_state_ref(ref, expected_prefix):
                body = self.error("invalid_artifact_ref", "resume_from_refs must be scoped to the source run")
                body["source_run_id"] = source_run_id
                body["invalid_ref"] = ref
                return 400, body

        artifact_refs = source_run.get("artifact_refs") if isinstance(source_run.get("artifact_refs"), dict) else {}
        return {
            "source_run_id": source_run_id,
            "source_status": source_status,
            "resume_from_refs": resume_from_refs,
            "source_closeout_ref": artifact_refs.get("partial_closeout"),
        }

    def valid_scoped_state_ref(self, ref: Any, expected_prefix: str) -> bool:
        if not isinstance(ref, str) or not ref.startswith(expected_prefix):
            return False
        suffix = ref[len(expected_prefix) :]
        if not suffix or suffix.startswith("/"):
            return False
        parts = suffix.split("/")
        if any(part in {"", ".", ".."} for part in parts):
            return False
        return True

    def create_intent_blocked_run(
        self,
        payload: dict[str, Any],
        idempotency_key: str,
        endpoint: str,
        resource_path: str,
        payload_hash: str,
        idempotency_path: Path,
    ) -> tuple[int, dict[str, Any]]:
        now = utc_now()
        run_id = f"run-{uuid.uuid4().hex[:16]}"
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        decision_id = f"decision-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "create_run_intake",
            "planned_side_effects": [
                "write_requirement_completion_bundle",
                "write_structured_prd",
                "write_run_state",
                "write_empty_task_projection",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        completion_bundle_ref = self.store.state_ref(run_id, "requirement-completion-bundle.json")
        completion_bundle = self._requirement_completion_bundle(payload, "create_run", run_id)
        write_json(self.store.run_dir(run_id) / "requirement-completion-bundle.json", completion_bundle)
        structured_prd = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "structured_prd",
            "run_id": run_id,
            "source": "intent",
            "status": "incomplete",
            "intent": payload.get("intent"),
            "requirement_summary": payload.get("intent"),
            "acceptance_criteria": [],
            "constraints": [],
            "risks": [],
            "failure_strategy": None,
            "missing_fields": ["acceptance_criteria", "constraints", "failure_strategy"],
            "created_at": now,
        }
        write_json(self.store.run_dir(run_id) / "structured_prd.json", structured_prd)

        pending_decision_ref = self.store.state_ref(run_id, "structured_prd.json")
        run = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "status": "blocked",
            "project": self.store.project_id,
            "last_command_id": command_id,
            "source_run_id": payload.get("source_run_id"),
            "lineage_ref": None,
            "created_at": now,
            "updated_at": now,
            "current_stage": "intake",
            "progress": {"completed_stages": 0, "total_stages": len(STAGES)},
            "stages": [{"stage": stage, "status": "not_started"} for stage in STAGES],
            "blocked_reason": "structured_prd_required",
            "failure_reason": None,
            "failure_report_ref": None,
            "failure_audit_ref": None,
            "last_good_checkpoint_ref": None,
            "lineage_hint_refs": [],
            "pending_decision_id": decision_id,
            "pending_decision_refs": [pending_decision_ref],
            "resume_checkpoint_refs": [self.store.state_ref(run_id, "run.json")],
            "stopped_reason": None,
            "stop_audit_ref": None,
            "artifact_refs": {
                "command_record": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "requirement_completion_bundle": completion_bundle_ref,
                "structured_prd": pending_decision_ref,
            },
        }
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "blocked", "updated_at": now})

        tasks = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "project": self.store.project_id,
            "projection_status": "consistent",
            "authority_refs_checked": [self.store.state_ref(run_id, "run.json"), pending_decision_ref, completion_bundle_ref],
            "tasks": [],
            "updated_at": now,
        }
        write_json(self.store.tasks_path(run_id), tasks)

        audit_records = [
            ("run_created", "Six-Stage Run created for intake"),
            ("ticket_normalized", "Intent normalized into incomplete structured_prd.json"),
            ("decision_required", "Kimi must provide acceptance criteria, constraints, and failure strategy"),
        ]
        for event_type, details in audit_records:
            append_jsonl(
                self.store.audit_path(),
                {
                    "timestamp": now,
                    "level": "L1",
                    "project": self.store.project_id,
                    "type": event_type,
                    "decision": "PENDING" if event_type == "decision_required" else "RECORDED",
                    "user_decision": "",
                    "details": details,
                    "approval_id": decision_id if event_type == "decision_required" else "",
                    "ttl": "",
                    "task_id": run_id,
                    "escalation_id": "",
                    "agent_source": "orch-gateway",
                    "session_id": "",
                    "command_id": command_id,
                    "run_id": run_id,
                },
            )

        event_specs = [
            ("run_created", "blocked", "Six-Stage Run created for intake", None),
            ("ticket_normalized", "blocked", "Intent normalized into incomplete structured PRD", None),
            ("decision_required", "blocked", "Structured PRD requires Kimi input", decision_id),
        ]
        for seq, (event_type, status, message, event_decision_id) in enumerate(event_specs, start=1):
            append_jsonl(
                self.store.events_path(run_id),
                {
                    "schema_version": EVENT_SCHEMA_VERSION,
                    "seq": seq,
                    "timestamp": now,
                    "command_id": command_id,
                    "idempotency_key": idempotency_key,
                    "run_id": run_id,
                    "task_id": None,
                    "stage": "intake",
                    "type": event_type,
                    "severity": "info" if event_type != "decision_required" else "warning",
                    "status": status,
                    "message": message,
                    "artifact_refs": [self.store.state_ref(run_id, "run.json"), pending_decision_ref],
                    "decision_id": event_decision_id,
                },
            )

        response = self.run_response(run_id, command_id, idempotency_key, "blocked")
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_requirement_completion_bundle", "target_authority": "state", "operation": "write", "status": "completed", "refs": [completion_bundle_ref]},
            {"step_id": "write_structured_prd", "target_authority": "state", "operation": "write", "status": "completed", "refs": [pending_decision_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "run.json")]},
            {"step_id": "write_empty_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "tasks.json")]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [self.store.audit_ref(command_id)]},
            {"step_id": "append_event_projection", "target_authority": "state", "operation": "append", "status": "completed", "refs": [self.store.state_ref(run_id, "events.jsonl#seq=1-3")]},
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 201,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )

        return 201, response

    def active_run(self) -> dict[str, Any] | None:
        path = self.store.active_run_path()
        if not path.exists():
            return None
        try:
            record = read_json(path)
        except (OSError, json.JSONDecodeError):
            return None
        if record.get("status") in ACTIVE_RUN_STATUSES and record.get("run_id"):
            return record
        return None

    def stop_run(self, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if fallback_reason := self._intake_pipeline_fallback_reason(payload, "stop_run", run_id):
            return 503, self._gateway_fallback_body(fallback_reason)
        run_path = self.store.run_path(run_id)
        if not run_path.exists():
            return 404, self.error("not_found", "run not found")

        idempotency_key = payload.get("idempotency_key")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")

        endpoint = "POST /orchestra/runs/{run_id}/stop"
        resource_path = f"/orchestra/runs/{run_id}/stop"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 200), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        run = read_json(run_path)
        if run.get("status") not in ACTIVE_RUN_STATUSES:
            body = self.error("run_not_active", "only queued, running, or blocked runs can be stopped")
            body["run_id"] = run_id
            body["status"] = run.get("status")
            return 409, body

        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        now = utc_now()
        reason = str(payload.get("reason") or "stop requested")
        command_path = self.store.command_path(run_id, command_id)
        stop_audit_ref = self.store.audit_ref(command_id)
        partial_closeout_ref = self.store.state_ref(run_id, "partial_closeout.json")

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "stop_run",
            "planned_side_effects": [
                "write_partial_closeout",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        partial_closeout = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "partial_closeout",
            "run_id": run_id,
            "closeout_kind": "stopped_before_completion",
            "reason": reason,
            "created_at": now,
            "preserved_state_refs": [self.store.state_ref(run_id, "run.json"), self.store.state_ref(run_id, "tasks.json")],
            "preserved_audit_refs": [stop_audit_ref],
        }
        write_json(self.store.run_dir(run_id) / "partial_closeout.json", partial_closeout)

        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["partial_closeout"] = partial_closeout_ref
        run.update(
            {
                "status": "stopped",
                "last_command_id": command_id,
                "updated_at": now,
                "stopped_reason": reason,
                "stop_audit_ref": stop_audit_ref,
                "artifact_refs": artifact_refs,
            }
        )
        write_json(run_path, run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "stopped", "updated_at": now})

        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "run_stopped",
                "decision": "RECORDED",
                "user_decision": "",
                "details": reason,
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
            },
        )

        seq = self.next_event_seq(run_id)
        append_jsonl(
            self.store.events_path(run_id),
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": seq,
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": run.get("current_stage"),
                "type": "run_stopped",
                "severity": "info",
                "status": "stopped",
                "message": "Run stopped before completion",
                "artifact_refs": [self.store.state_ref(run_id, "run.json"), partial_closeout_ref, stop_audit_ref],
                "decision_id": None,
            },
        )

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "status": "stopped",
            "stop_audit_ref": stop_audit_ref,
            "partial_closeout_ref": partial_closeout_ref,
            "event_projection_degraded": False,
            "projection_status": "consistent",
            "projection_issue_refs": [],
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_partial_closeout", "target_authority": "state", "operation": "write", "status": "completed", "refs": [partial_closeout_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "run.json")]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [stop_audit_ref]},
            {"step_id": "append_event_projection", "target_authority": "state", "operation": "append", "status": "completed", "refs": [self.store.state_ref(run_id, f"events.jsonl#seq={seq}")]},
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )

        return 200, response

    def submit_verdict(self, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if fallback_reason := self._intake_pipeline_fallback_reason(payload, "submit_verdict", run_id):
            return 503, self._gateway_fallback_body(fallback_reason)
        run_path = self.store.run_path(run_id)
        if not run_path.exists():
            return 404, self.error("not_found", "run not found")

        idempotency_key = payload.get("idempotency_key")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")
        task_id = payload.get("task_id")
        verdict = payload.get("verdict")
        if not isinstance(task_id, str) or not task_id:
            return 400, self.error("validation_error", "task_id is required")
        if not isinstance(verdict, dict):
            return 400, self.error("validation_error", "verdict is required")

        endpoint = "POST /orchestra/runs/{run_id}/verdicts"
        resource_path = f"/orchestra/runs/{run_id}/verdicts"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 200), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        tasks_path = self.store.tasks_path(run_id)
        if not tasks_path.exists():
            return 404, self.error("not_found", "task projection not found")
        tasks = read_json(tasks_path)
        task = self.find_projected_task(tasks, task_id)
        if task is None:
            return 404, self.error("not_found", "task not found")

        violations = self.review_verdict_violations(verdict, run_id, task_id)
        if violations:
            body = self.error("validation_error", "verdict failed schema validation")
            body["violations"] = violations
            return 400, body
        if verdict.get("verdict") == "block":
            return self.block_on_review_verdict(
                run_id,
                task_id,
                task,
                tasks,
                verdict,
                idempotency_key,
                endpoint,
                resource_path,
                payload_hash,
                idempotency_path,
            )
        if verdict.get("verdict") == "approve":
            return self.record_approved_review_verdict(
                run_id,
                task_id,
                task,
                tasks,
                verdict,
                idempotency_key,
                endpoint,
                resource_path,
                payload_hash,
                idempotency_path,
            )
        if verdict.get("verdict") == "request_changes" and self.verdict_improvement_cycle(verdict) >= 1:
            return self.block_on_review_verdict(
                run_id,
                task_id,
                task,
                tasks,
                verdict,
                idempotency_key,
                endpoint,
                resource_path,
                payload_hash,
                idempotency_path,
            )
        if verdict.get("verdict") == "reject":
            return self.block_on_review_verdict(
                run_id,
                task_id,
                task,
                tasks,
                verdict,
                idempotency_key,
                endpoint,
                resource_path,
                payload_hash,
                idempotency_path,
            )
        if verdict.get("verdict") != "request_changes":
            return 400, self.error("unsupported_verdict", "only request_changes routing is implemented")
        if verdict.get("within_approved_scope") is not True or verdict.get("authority_required") == "human":
            return 400, self.error("unsupported_verdict", "only in-scope Kimi-authority request_changes routing is implemented")

        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        verdict_ref = self.store.state_ref(run_id, f"review-verdicts/{command_id}.json")
        run_ref = self.store.state_ref(run_id, "run.json")
        tasks_ref = self.store.state_ref(run_id, "tasks.json")
        audit_ref = self.store.audit_ref(command_id)
        improvement_cycle = int(verdict.get("improvement_cycle") or 0) + 1

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_review_verdict",
            "planned_side_effects": [
                "write_review_verdict",
                "write_task_projection",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        verdict_artifact = dict(verdict)
        verdict_artifact["created_at"] = verdict_artifact.get("created_at") or now
        verdict_artifact["command_id"] = command_id
        write_json(self.store.run_dir(run_id) / "review-verdicts" / f"{command_id}.json", verdict_artifact)

        task_refs = task.get("artifact_refs") if isinstance(task.get("artifact_refs"), list) else []
        if verdict_ref not in task_refs:
            task_refs.append(verdict_ref)
        task.update({"status": "blocked", "blocked_reason": "review_changes_requested", "artifact_refs": task_refs})
        improvement_task = self.find_stage_task(tasks, "improvement")
        if improvement_task is not None and improvement_task.get("status") not in {"completed", "blocked"}:
            improvement_task["status"] = "queued"
        tasks["updated_at"] = now
        write_json(tasks_path, tasks)

        run = read_json(run_path)
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        review_refs = artifact_refs.get("review_verdict_refs") if isinstance(artifact_refs.get("review_verdict_refs"), list) else []
        if verdict_ref not in review_refs:
            review_refs.append(verdict_ref)
        artifact_refs["review_verdict_refs"] = review_refs
        run.update(
            {
                "status": "queued",
                "last_command_id": command_id,
                "updated_at": now,
                "current_stage": "improvement",
                "blocked_reason": None,
                "pending_decision_refs": [],
                "artifact_refs": artifact_refs,
            }
        )
        stages = run.get("stages") if isinstance(run.get("stages"), list) else []
        for stage in stages:
            if isinstance(stage, dict) and stage.get("stage") == "improvement":
                stage["status"] = "queued"
        write_json(run_path, run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "queued", "updated_at": now})

        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "review_verdict_recorded",
                "decision": "REQUEST_CHANGES",
                "user_decision": "",
                "details": "Review verdict requested bounded improvement",
                "approval_id": "",
                "ttl": "",
                "task_id": task_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "verdict_ref": verdict_ref,
                "improvement_cycle": improvement_cycle,
            },
        )

        kanban_blocked = self.block_kanban_task(task.get("kanban_ref"), "review_changes_requested")
        projection_issue_refs = []
        artifact_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": verdict.get("stage"),
                "type": "artifact_written",
                "severity": "info",
                "status": "queued",
                "message": "Review verdict recorded",
                "artifact_refs": [verdict_ref, audit_ref],
                "decision_id": None,
            },
        )
        if artifact_event_ref:
            projection_issue_refs.append(artifact_event_ref)
        stage_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": improvement_task.get("task_id") if isinstance(improvement_task, dict) else None,
                "stage": "improvement",
                "type": "stage_started",
                "severity": "info",
                "status": "queued",
                "message": "Bounded improvement queued from review feedback",
                "artifact_refs": [verdict_ref, run_ref, tasks_ref],
                "decision_id": None,
            },
        )
        if stage_event_ref:
            projection_issue_refs.append(stage_event_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": task_id,
            "verdict_ref": verdict_ref,
            "route_result": "improvement_queued",
            "improvement_cycle": improvement_cycle,
            "kanban_lifecycle_blocked": kanban_blocked,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_review_verdict", "target_authority": "state", "operation": "write", "status": "completed", "refs": [verdict_ref]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [tasks_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {"step_id": "block_kanban_task", "target_authority": "hermes_kanban", "operation": "block", "status": "completed" if kanban_blocked else "failed", "refs": [task.get("kanban_ref")]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "task_id": task_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def strict_mvp_evidence_enabled(self) -> bool:
        return os.environ.get("ORCH_GATEWAY_RUN_TESTS") == "1"

    def record_approved_review_verdict(
        self,
        run_id: str,
        task_id: str,
        task: dict[str, Any],
        tasks: dict[str, Any],
        verdict: dict[str, Any],
        idempotency_key: str,
        endpoint: str,
        resource_path: str,
        payload_hash: str,
        idempotency_path: Path,
    ) -> tuple[int, dict[str, Any]]:
        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        verdict_ref = self.store.state_ref(run_id, f"review-verdicts/{command_id}.json")
        run_ref = self.store.state_ref(run_id, "run.json")
        tasks_ref = self.store.state_ref(run_id, "tasks.json")
        audit_ref = self.store.audit_ref(command_id)

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_review_verdict",
            "planned_side_effects": [
                "write_review_verdict",
                "write_task_projection",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        verdict_artifact = dict(verdict)
        verdict_artifact["created_at"] = verdict_artifact.get("created_at") or now
        verdict_artifact["command_id"] = command_id
        write_json(self.store.run_dir(run_id) / "review-verdicts" / f"{command_id}.json", verdict_artifact)

        task_refs = task.get("artifact_refs") if isinstance(task.get("artifact_refs"), list) else []
        if verdict_ref not in task_refs:
            task_refs.append(verdict_ref)
        task["artifact_refs"] = task_refs
        tasks["updated_at"] = now
        write_json(self.store.tasks_path(run_id), tasks)

        run = read_json(self.store.run_path(run_id))
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        review_refs = artifact_refs.get("review_verdict_refs") if isinstance(artifact_refs.get("review_verdict_refs"), list) else []
        if verdict_ref not in review_refs:
            review_refs.append(verdict_ref)
        artifact_refs["review_verdict_refs"] = review_refs
        run.update({"last_command_id": command_id, "updated_at": now, "artifact_refs": artifact_refs})
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": run.get("status"), "updated_at": now})

        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "review_verdict_recorded",
                "decision": "APPROVED",
                "user_decision": "",
                "details": "Review verdict approved and recorded as evidence",
                "approval_id": "",
                "ttl": "",
                "task_id": task_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "verdict_ref": verdict_ref,
            },
        )

        projection_issue_refs = []
        artifact_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": verdict.get("stage"),
                "type": "artifact_written",
                "severity": "info",
                "status": run.get("status"),
                "message": "Review verdict recorded",
                "artifact_refs": [verdict_ref, audit_ref],
                "decision_id": None,
            },
        )
        if artifact_event_ref:
            projection_issue_refs.append(artifact_event_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": task_id,
            "verdict_ref": verdict_ref,
            "route_result": "approved",
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_review_verdict", "target_authority": "state", "operation": "write", "status": "completed", "refs": [verdict_ref]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [tasks_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "task_id": task_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def block_on_review_verdict(
        self,
        run_id: str,
        task_id: str,
        task: dict[str, Any],
        tasks: dict[str, Any],
        verdict: dict[str, Any],
        idempotency_key: str,
        endpoint: str,
        resource_path: str,
        payload_hash: str,
        idempotency_path: Path,
    ) -> tuple[int, dict[str, Any]]:
        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        decision_id = f"decision-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        verdict_ref = self.store.state_ref(run_id, f"review-verdicts/{command_id}.json")
        run_ref = self.store.state_ref(run_id, "run.json")
        tasks_ref = self.store.state_ref(run_id, "tasks.json")
        audit_ref = self.store.audit_ref(command_id)
        improvement_exhausted = verdict.get("verdict") == "request_changes" and self.verdict_improvement_cycle(verdict) >= 1
        if improvement_exhausted:
            blocked_reason = "improvement_exhausted"
            authority_required = str(verdict.get("authority_required") or "kimi")
            audit_level = "L2"
            verdict_details = "Review verdict exhausted automatic improvement budget"
            decision_details = "Automatic improvement budget is exhausted"
            event_message = "Kimi decision required after improvement exhausted"
            failure_class = "improvement_exhausted"
            audit_decision = "BLOCKED"
        elif verdict.get("verdict") == "reject":
            blocked_reason = "review_rejected"
            authority_required = str(verdict.get("authority_required") or "kimi")
            audit_level = "L3" if authority_required == "human" else "L2"
            verdict_details = "Review verdict rejected workflow output"
            decision_details = "Review rejection requires a decision before continuing"
            event_message = "Review rejection requires a decision before continuing"
            failure_class = "review_rejected"
            audit_decision = "REJECTED"
        elif verdict.get("review_kind") == "qa" or verdict.get("artifact_type") in {"qa_report", "re_qa_report"}:
            blocked_reason = "qa_blocked"
            authority_required = str(verdict.get("authority_required") or "kimi")
            audit_level = "L3" if authority_required == "human" else "L2"
            verdict_details = "QA verdict blocked workflow advancement"
            decision_details = "QA block requires a decision before continuing"
            event_message = "QA block requires a decision before continuing"
            failure_class = "qa_blocked"
            audit_decision = "BLOCKED"
        else:
            blocked_reason = "review_blocked_human_approval_required"
            authority_required = "human"
            audit_level = "L3"
            verdict_details = "Review verdict requires Human Approval"
            decision_details = "Human Approval is required before continuing"
            event_message = "Human Approval required before continuing"
            failure_class = "review_blocked"
            audit_decision = "BLOCKED"

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_review_verdict",
            "planned_side_effects": [
                "write_review_verdict",
                "write_task_projection",
                "write_run_state",
                "append_audit",
                "block_kanban_task",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        verdict_artifact = dict(verdict)
        verdict_artifact["created_at"] = verdict_artifact.get("created_at") or now
        verdict_artifact["command_id"] = command_id
        verdict_artifact["decision_id"] = decision_id
        write_json(self.store.run_dir(run_id) / "review-verdicts" / f"{command_id}.json", verdict_artifact)

        task_refs = task.get("artifact_refs") if isinstance(task.get("artifact_refs"), list) else []
        if verdict_ref not in task_refs:
            task_refs.append(verdict_ref)
        task.update({"status": "blocked", "blocked_reason": blocked_reason, "artifact_refs": task_refs})
        tasks["updated_at"] = now
        write_json(self.store.tasks_path(run_id), tasks)

        run = read_json(self.store.run_path(run_id))
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        review_refs = artifact_refs.get("review_verdict_refs") if isinstance(artifact_refs.get("review_verdict_refs"), list) else []
        if verdict_ref not in review_refs:
            review_refs.append(verdict_ref)
        artifact_refs["review_verdict_refs"] = review_refs
        pending_refs = run.get("pending_decision_refs") if isinstance(run.get("pending_decision_refs"), list) else []
        if verdict_ref not in pending_refs:
            pending_refs.append(verdict_ref)
        run.update(
            {
                "status": "blocked",
                "last_command_id": command_id,
                "updated_at": now,
                "blocked_reason": blocked_reason,
                "pending_decision_id": decision_id,
                "pending_decision_refs": pending_refs,
                "artifact_refs": artifact_refs,
            }
        )
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "blocked", "updated_at": now})

        for record_type, decision, details in (
            ("review_verdict_recorded", audit_decision, verdict_details),
            ("decision_required", "PENDING", "Human Approval is required before continuing"),
        ):
            append_jsonl(
                self.store.audit_path(),
                {
                    "timestamp": now,
                    "level": audit_level,
                    "project": self.store.project_id,
                    "type": record_type,
                    "decision": decision,
                    "user_decision": "",
                    "details": details if record_type == "review_verdict_recorded" else decision_details,
                    "approval_id": decision_id if record_type == "decision_required" else "",
                    "ttl": "",
                    "task_id": task_id,
                    "escalation_id": "",
                    "agent_source": "orch-gateway",
                    "session_id": "",
                    "command_id": command_id,
                    "run_id": run_id,
                    "verdict_ref": verdict_ref,
                    "authority_required": authority_required,
                    "failure_class": failure_class,
                },
            )

        kanban_blocked = self.block_kanban_task(task.get("kanban_ref"), blocked_reason)
        projection_issue_refs = []
        artifact_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": verdict.get("stage"),
                "type": "artifact_written",
                "severity": "warning",
                "status": "blocked",
                "message": "Review verdict recorded",
                "artifact_refs": [verdict_ref, audit_ref],
                "decision_id": None,
            },
        )
        if artifact_event_ref:
            projection_issue_refs.append(artifact_event_ref)
        decision_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": verdict.get("stage"),
                "type": "decision_required",
                "severity": "error",
                "status": "blocked",
                "message": event_message,
                "artifact_refs": [verdict_ref, run_ref, tasks_ref, audit_ref],
                "decision_id": decision_id,
            },
        )
        if decision_event_ref:
            projection_issue_refs.append(decision_event_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": task_id,
            "verdict_ref": verdict_ref,
            "route_result": "decision_required",
            "decision_id": decision_id,
            "authority_required": authority_required,
            "failure_class": failure_class,
            "kanban_lifecycle_blocked": kanban_blocked,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_review_verdict", "target_authority": "state", "operation": "write", "status": "completed", "refs": [verdict_ref]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [tasks_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {"step_id": "block_kanban_task", "target_authority": "hermes_kanban", "operation": "block", "status": "completed" if kanban_blocked else "failed", "refs": [task.get("kanban_ref")]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "task_id": task_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def submit_global_evaluation(self, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if fallback_reason := self._intake_pipeline_fallback_reason(payload, "submit_global_evaluation", run_id):
            return 503, self._gateway_fallback_body(fallback_reason)
        run_path = self.store.run_path(run_id)
        if not run_path.exists():
            return 404, self.error("not_found", "run not found")

        idempotency_key = payload.get("idempotency_key")
        report = payload.get("report")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")
        if not isinstance(report, dict):
            return 400, self.error("validation_error", "report is required")

        endpoint = "POST /orchestra/runs/{run_id}/global-evaluations"
        resource_path = f"/orchestra/runs/{run_id}/global-evaluations"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 200), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        violations = self.global_evaluation_violations(report, run_id)
        if violations:
            body = self.error("validation_error", "global evaluation report failed schema validation")
            body["violations"] = violations
            return 400, body
        verdict = report.get("verdict")
        if verdict == "pass":
            return self.accept_global_evaluation_pass(
                run_id,
                report,
                idempotency_key,
                endpoint,
                resource_path,
                payload_hash,
                idempotency_path,
            )
        if verdict not in {"pass_with_warnings", "block", "fail"}:
            return 400, self.error("unsupported_global_evaluation", "only pass, pass_with_warnings, fail, and block routing are implemented")
        if verdict == "pass_with_warnings":
            blocked_reason = "global_evaluation_acceptance_required"
            route_result = "final_acceptance_required"
            authority_required = "kimi"
            audit_level = "L2"
            audit_decision = "WARNINGS"
            audit_details = "Global evaluation passed with warnings"
            decision_details = "Kimi final acceptance is required before Stage 6"
            decision_message = "Kimi final acceptance required before Stage 6"
            event_severity = "warning"
            failure_class = None
        elif verdict == "block":
            blocked_reason = "global_evaluation_blocked"
            route_result = "decision_required"
            authority_required = str(report.get("authority_required") or "kimi")
            audit_level = "L3" if authority_required == "human" else "L2"
            audit_decision = "BLOCK"
            audit_details = "Global evaluation blocked workflow advancement"
            decision_details = "Global evaluation block requires a decision before Stage 6"
            decision_message = "Global evaluation block requires a decision before Stage 6"
            event_severity = "error"
            failure_class = "global_evaluation_blocked"
        else:
            blocked_reason = "global_evaluation_failed"
            route_result = "decision_required"
            authority_required = str(report.get("authority_required") or "kimi")
            audit_level = "L3" if authority_required == "human" else "L2"
            audit_decision = "FAIL"
            audit_details = "Global evaluation failed workflow advancement"
            decision_details = "Global evaluation failure requires a decision before Stage 6"
            decision_message = "Global evaluation failure requires a decision before Stage 6"
            event_severity = "error"
            failure_class = "global_evaluation_failed"

        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        decision_id = f"decision-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        report_ref = self.store.state_ref(run_id, "global_evaluation_report.json")
        run_ref = self.store.state_ref(run_id, "run.json")
        audit_ref = self.store.audit_ref(command_id)

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_global_evaluation",
            "planned_side_effects": [
                "write_global_evaluation_report",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        report_artifact = dict(report)
        report_artifact["created_at"] = report_artifact.get("created_at") or now
        report_artifact["command_id"] = command_id
        report_artifact["decision_id"] = decision_id
        write_json(self.store.run_dir(run_id) / "global_evaluation_report.json", report_artifact)

        run = read_json(run_path)
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["global_evaluation_report"] = report_ref
        pending_refs = run.get("pending_decision_refs") if isinstance(run.get("pending_decision_refs"), list) else []
        if report_ref not in pending_refs:
            pending_refs.append(report_ref)
        run.update(
            {
                "status": "blocked",
                "last_command_id": command_id,
                "updated_at": now,
                "current_stage": "global_evaluation",
                "blocked_reason": blocked_reason,
                "pending_decision_id": decision_id,
                "pending_decision_refs": pending_refs,
                "artifact_refs": artifact_refs,
            }
        )
        stages = run.get("stages") if isinstance(run.get("stages"), list) else []
        for stage in stages:
            if isinstance(stage, dict) and stage.get("stage") == "global_evaluation":
                stage["status"] = "blocked"
        write_json(run_path, run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "blocked", "updated_at": now})

        for record_type, decision, details in (
            ("global_evaluation_recorded", audit_decision, audit_details),
            ("decision_required", "PENDING", decision_details),
        ):
            append_jsonl(
                self.store.audit_path(),
                {
                    "timestamp": now,
                    "level": audit_level,
                    "project": self.store.project_id,
                    "type": record_type,
                    "decision": decision,
                    "user_decision": "",
                    "details": details,
                    "approval_id": decision_id if record_type == "decision_required" else "",
                    "ttl": "",
                    "task_id": run_id,
                    "escalation_id": "",
                    "agent_source": "orch-gateway",
                    "session_id": "",
                    "command_id": command_id,
                    "run_id": run_id,
                    "global_evaluation_report_ref": report_ref,
                    "authority_required": authority_required,
                    "failure_class": failure_class,
                },
            )

        projection_issue_refs = []
        artifact_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "global_evaluation",
                "type": "artifact_written",
                "severity": event_severity,
                "status": "blocked",
                "message": "Global evaluation report recorded",
                "artifact_refs": [report_ref, audit_ref],
                "decision_id": None,
            },
        )
        if artifact_event_ref:
            projection_issue_refs.append(artifact_event_ref)
        decision_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "global_evaluation",
                "type": "decision_required",
                "severity": event_severity,
                "status": "blocked",
                "message": decision_message,
                "artifact_refs": [report_ref, run_ref, audit_ref],
                "decision_id": decision_id,
            },
        )
        if decision_event_ref:
            projection_issue_refs.append(decision_event_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "global_evaluation_report_ref": report_ref,
            "route_result": route_result,
            "decision_id": decision_id,
            "authority_required": authority_required,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        if verdict in {"block", "fail"}:
            response["blocked_reason"] = blocked_reason
            response["failure_class"] = failure_class
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_global_evaluation_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [report_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def accept_global_evaluation_pass(
        self,
        run_id: str,
        report: dict[str, Any],
        idempotency_key: str,
        endpoint: str,
        resource_path: str,
        payload_hash: str,
        idempotency_path: Path,
    ) -> tuple[int, dict[str, Any]]:
        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        report_ref = self.store.state_ref(run_id, "global_evaluation_report.json")
        run_ref = self.store.state_ref(run_id, "run.json")

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_global_evaluation",
            "planned_side_effects": [
                "write_global_evaluation_report",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        report_artifact = dict(report)
        report_artifact["created_at"] = report_artifact.get("created_at") or now
        report_artifact["command_id"] = command_id
        write_json(self.store.run_dir(run_id) / "global_evaluation_report.json", report_artifact)

        run = read_json(self.store.run_path(run_id))
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["global_evaluation_report"] = report_ref
        run.update(
            {
                "status": "queued",
                "last_command_id": command_id,
                "updated_at": now,
                "current_stage": "continuous_improvement",
                "blocked_reason": None,
                "pending_decision_id": None,
                "pending_decision_refs": [],
                "artifact_refs": artifact_refs,
            }
        )
        stages = run.get("stages") if isinstance(run.get("stages"), list) else []
        for stage in stages:
            if isinstance(stage, dict) and stage.get("stage") == "global_evaluation":
                stage["status"] = "completed"
            if isinstance(stage, dict) and stage.get("stage") == "continuous_improvement":
                stage["status"] = "queued"
        write_json(self.store.run_path(run_id), run)
        tasks_path = self.store.tasks_path(run_id)
        if tasks_path.exists():
            tasks = read_json(tasks_path)
            stage_task = self.find_stage_task(tasks, "continuous_improvement")
            if stage_task is not None and stage_task.get("status") != "completed":
                stage_task["status"] = "queued"
            tasks["updated_at"] = now
            write_json(tasks_path, tasks)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "queued", "updated_at": now})

        audit_ref = self.store.audit_ref(command_id)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "global_evaluation_recorded",
                "decision": "PASS",
                "user_decision": "",
                "details": "Global evaluation passed and Stage 6 was queued",
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "global_evaluation_report_ref": report_ref,
            },
        )

        projection_issue_refs = []
        artifact_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "global_evaluation",
                "type": "artifact_written",
                "severity": "info",
                "status": "queued",
                "message": "Global evaluation report recorded",
                "artifact_refs": [report_ref, audit_ref],
                "decision_id": None,
            },
        )
        if artifact_event_ref:
            projection_issue_refs.append(artifact_event_ref)
        stage_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "continuous_improvement",
                "type": "stage_started",
                "severity": "info",
                "status": "queued",
                "message": "Stage 6 continuous improvement queued",
                "artifact_refs": [report_ref, run_ref],
                "decision_id": None,
            },
        )
        if stage_event_ref:
            projection_issue_refs.append(stage_event_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "global_evaluation_report_ref": report_ref,
            "route_result": "stage6_queued",
            "status": "queued",
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_global_evaluation_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [report_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def submit_closeout(self, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if fallback_reason := self._intake_pipeline_fallback_reason(payload, "submit_closeout", run_id):
            return 503, self._gateway_fallback_body(fallback_reason)
        if not self.store.run_path(run_id).exists():
            return 404, self.error("not_found", "run not found")

        idempotency_key = payload.get("idempotency_key")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")

        closeout_report = payload.get("iteration_closeout_report")
        proposals = payload.get("system_improvement_proposals")
        completion_blockers = []
        if not isinstance(closeout_report, dict):
            completion_blockers.append("iteration_closeout_report")
        if not isinstance(proposals, dict):
            completion_blockers.append("system_improvement_proposals")
        if completion_blockers:
            body = self.error("closeout_validation_failed", "closeout requires schema-valid closeout artifacts before completion")
            body["run_id"] = run_id
            body["completion_blockers"] = completion_blockers
            body["event_projection_degraded"] = False
            body["projection_status"] = "consistent"
            body["projection_issue_refs"] = []
            return 400, body

        endpoint = "POST /orchestra/runs/{run_id}/closeout"
        resource_path = f"/orchestra/runs/{run_id}/closeout"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 200), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        completion_blockers = self.closeout_completion_blockers(run_id, closeout_report, proposals)
        if completion_blockers:
            body = self.error("closeout_validation_failed", "closeout completion gate did not pass")
            body["run_id"] = run_id
            body["completion_blockers"] = completion_blockers
            body["event_projection_degraded"] = False
            body["projection_status"] = "consistent"
            body["projection_issue_refs"] = []
            return 400, body

        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        closeout_ref = self.store.state_ref(run_id, "iteration_closeout_report.json")
        proposals_ref = self.store.state_ref(run_id, "system_improvement_proposals.json")
        run_ref = self.store.state_ref(run_id, "run.json")

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_closeout",
            "planned_side_effects": [
                "write_iteration_closeout_report",
                "write_system_improvement_proposals",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        closeout_artifact = dict(closeout_report)
        closeout_artifact["created_at"] = closeout_artifact.get("created_at") or now
        closeout_artifact["command_id"] = command_id
        proposals_artifact = dict(proposals)
        proposals_artifact["command_id"] = command_id
        write_json(self.store.run_dir(run_id) / "iteration_closeout_report.json", closeout_artifact)
        write_json(self.store.run_dir(run_id) / "system_improvement_proposals.json", proposals_artifact)

        run = read_json(self.store.run_path(run_id))
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["iteration_closeout_report"] = closeout_ref
        artifact_refs["system_improvement_proposals"] = proposals_ref
        run.update(
            {
                "status": "completed",
                "last_command_id": command_id,
                "updated_at": now,
                "current_stage": "continuous_improvement",
                "blocked_reason": None,
                "pending_decision_id": None,
                "pending_decision_refs": [],
                "artifact_refs": artifact_refs,
            }
        )
        stages = run.get("stages") if isinstance(run.get("stages"), list) else []
        for stage in stages:
            if isinstance(stage, dict):
                stage["status"] = "completed"
        run["progress"] = {"completed_stages": len(STAGES), "total_stages": len(STAGES)}
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "completed", "updated_at": now})

        audit_ref = self.store.audit_ref(command_id)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "run_completed",
                "decision": "RECORDED",
                "user_decision": "",
                "details": "Run completed through Stage 6 closeout completion gate",
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "iteration_closeout_report_ref": closeout_ref,
                "system_improvement_proposals_ref": proposals_ref,
            },
        )

        projection_issue_refs = []
        projection_issue_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "continuous_improvement",
                "type": "run_completed",
                "severity": "info",
                "status": "completed",
                "message": "Run completed through closeout gate",
                "artifact_refs": [closeout_ref, proposals_ref, run_ref],
                "decision_id": None,
            },
        )
        if projection_issue_ref:
            projection_issue_refs.append(projection_issue_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "status": "completed",
            "route_result": "run_completed",
            "iteration_closeout_report_ref": closeout_ref,
            "system_improvement_proposals_ref": proposals_ref,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_iteration_closeout_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [closeout_ref]},
            {"step_id": "write_system_improvement_proposals", "target_authority": "state", "operation": "write", "status": "completed", "refs": [proposals_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, f"events.jsonl#seq={self.next_event_seq(run_id) - 1}")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def submit_failure(self, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if fallback_reason := self._intake_pipeline_fallback_reason(payload, "submit_failure", run_id):
            return 503, self._gateway_fallback_body(fallback_reason)
        if not self.store.run_path(run_id).exists():
            return 404, self.error("not_found", "run not found")

        idempotency_key = payload.get("idempotency_key")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")
        failure_report = payload.get("failure_report")
        if not isinstance(failure_report, dict):
            body = self.error("validation_error", "failure_report is required")
            body["run_id"] = run_id
            return 400, body

        endpoint = "POST /orchestra/runs/{run_id}/failures"
        resource_path = f"/orchestra/runs/{run_id}/failures"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 200), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        violations = self.failure_report_violations(failure_report, run_id)
        if violations:
            body = self.error("validation_error", "failure report failed schema validation")
            body["run_id"] = run_id
            body["violations"] = violations
            return 400, body

        run = read_json(self.store.run_path(run_id))
        if run.get("status") in {"completed", "stopped", "failed"}:
            body = self.error("run_not_active", "only queued, running, or blocked runs can be marked failed")
            body["run_id"] = run_id
            body["status"] = run.get("status")
            return 409, body

        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        report_ref = self.store.state_ref(run_id, "run_failure_report.json")
        run_ref = self.store.state_ref(run_id, "run.json")
        event_ref = self.store.state_ref(run_id, f"events.jsonl#seq={self.next_event_seq(run_id)}")
        audit_ref = self.store.audit_ref(command_id)

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_failure",
            "planned_side_effects": [
                "write_run_failure_report",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        report_artifact = dict(failure_report)
        report_artifact["command_id"] = command_id
        report_artifact["run_failed_event_ref"] = event_ref
        report_artifact["created_at"] = report_artifact.get("created_at") or now
        write_json(self.store.run_dir(run_id) / "run_failure_report.json", report_artifact)

        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["run_failure_report"] = report_ref
        lineage_hint_refs = failure_report.get("lineage_hint_refs")
        if not isinstance(lineage_hint_refs, list) or report_ref not in lineage_hint_refs:
            lineage_hint_refs = [report_ref]
        run.update(
            {
                "status": "failed",
                "last_command_id": command_id,
                "updated_at": now,
                "failure_reason": failure_report.get("terminal_failure_reason"),
                "failure_report_ref": report_ref,
                "failure_audit_ref": audit_ref,
                "last_good_checkpoint_ref": failure_report.get("last_good_checkpoint_ref"),
                "lineage_hint_refs": lineage_hint_refs,
                "artifact_refs": artifact_refs,
            }
        )
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "failed", "updated_at": now})

        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L4",
                "project": self.store.project_id,
                "type": "run_failed",
                "decision": "RECORDED",
                "user_decision": "",
                "details": "Run moved to terminal failed because authority-chain evidence is unrecoverable",
                "approval_id": "",
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "terminal_failure_reason": failure_report.get("terminal_failure_reason"),
                "run_failure_report_ref": report_ref,
            },
        )

        projection_issue_refs = []
        projection_issue_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": failure_report.get("failed_task_id"),
                "stage": failure_report.get("failed_stage"),
                "type": "run_failed",
                "severity": "critical",
                "status": "failed",
                "message": "Run failed because authority-chain evidence is unrecoverable",
                "artifact_refs": [report_ref, run_ref, audit_ref],
                "decision_id": None,
            },
        )
        if projection_issue_ref:
            projection_issue_refs.append(projection_issue_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "status": "failed",
            "terminal_failure_reason": failure_report.get("terminal_failure_reason"),
            "run_failure_report_ref": report_ref,
            "lineage_hint_refs": lineage_hint_refs,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_run_failure_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [report_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [event_ref],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def submit_worker_output(self, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        if self._run_intake_pipeline(payload, "submit_worker_output", run_id):
            return self._fallback_response()
        run_path = self.store.run_path(run_id)
        if not run_path.exists():
            return 404, self.error("not_found", "run not found")

        idempotency_key = payload.get("idempotency_key")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")
        task_id = payload.get("task_id")
        worker_response = payload.get("worker_response")
        if not isinstance(task_id, str) or not task_id:
            return 400, self.error("validation_error", "task_id is required")
        if not isinstance(worker_response, dict):
            return 400, self.error("validation_error", "worker_response is required")

        endpoint = "POST /orchestra/runs/{run_id}/worker-outputs"
        resource_path = f"/orchestra/runs/{run_id}/worker-outputs"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 200), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        tasks_path = self.store.tasks_path(run_id)
        if not tasks_path.exists():
            return 404, self.error("not_found", "task projection not found")
        tasks = read_json(tasks_path)
        task = self.find_projected_task(tasks, task_id)
        if task is None:
            return 404, self.error("not_found", "task not found")

        violations = self.worker_response_schema_violations(worker_response)
        failure_class = "schema_mismatch"
        blocked_reason = "worker_output_schema_mismatch"
        if not violations:
            violations = self.worker_response_identity_violations(worker_response, task_id)
            failure_class = "identity_mismatch"
            blocked_reason = "worker_output_identity_mismatch"
        if not violations:
            violations = self.worker_response_artifact_ref_violations(worker_response, run_id)
            failure_class = "artifact_ref_invalid"
            blocked_reason = "worker_output_artifact_ref_invalid"
        if not violations:
            violations = self.worker_response_write_scope_violations(worker_response)
            failure_class = "write_scope_violation"
            blocked_reason = "worker_output_write_scope_violation"
        if not violations:
            violations = self.worker_response_evidence_violations(worker_response)
            failure_class = "evidence_missing"
            blocked_reason = "worker_output_evidence_missing"
        if not violations:
            return self.accept_worker_output(
                run_id,
                task_id,
                task,
                tasks,
                worker_response,
                idempotency_key,
                endpoint,
                resource_path,
                payload_hash,
                idempotency_path,
            )

        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        validation_report_ref = self.store.state_ref(run_id, f"worker-output-validation-reports/{command_id}.json")
        run_ref = self.store.state_ref(run_id, "run.json")

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_worker_output",
            "planned_side_effects": [
                "write_worker_output_validation_report",
                "write_task_projection",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        validation_report = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "worker_output_validation_report",
            "run_id": run_id,
            "task_id": task_id,
            "command_id": command_id,
            "result": "blocked",
            "failure_class": failure_class,
            "violations": violations,
            "requested_next_action": worker_response.get("next_action"),
            "created_at": now,
        }
        write_json(self.store.run_dir(run_id) / "worker-output-validation-reports" / f"{command_id}.json", validation_report)

        task_refs = task.get("artifact_refs") if isinstance(task.get("artifact_refs"), list) else []
        if validation_report_ref not in task_refs:
            task_refs.append(validation_report_ref)
        task.update({"status": "blocked", "blocked_reason": blocked_reason, "artifact_refs": task_refs})
        tasks["updated_at"] = now
        write_json(tasks_path, tasks)

        run = read_json(run_path)
        pending_decision_refs = run.get("pending_decision_refs") if isinstance(run.get("pending_decision_refs"), list) else []
        if validation_report_ref not in pending_decision_refs:
            pending_decision_refs.append(validation_report_ref)
        run.update(
            {
                "status": "blocked",
                "last_command_id": command_id,
                "updated_at": now,
                "blocked_reason": blocked_reason,
                "pending_decision_refs": pending_decision_refs,
            }
        )
        write_json(run_path, run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "blocked", "updated_at": now})

        audit_ref = self.store.audit_ref(command_id)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "worker_output_blocked",
                "decision": "BLOCKED",
                "user_decision": "",
                "details": "Worker output failed Advancement Gate schema validation",
                "approval_id": "",
                "ttl": "",
                "task_id": task_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "failure_class": failure_class,
            },
        )

        seq = self.next_event_seq(run_id)
        projection_issue_refs = []
        projection_issue_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": seq,
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": task.get("stage"),
                "type": "worker_output_blocked",
                "severity": "error",
                "status": "blocked",
                "message": "Worker output failed Advancement Gate schema validation",
                "artifact_refs": [validation_report_ref, run_ref],
                "decision_id": None,
            },
        )
        if projection_issue_ref:
            projection_issue_refs.append(projection_issue_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": task_id,
            "gate_result": "blocked",
            "failure_class": failure_class,
            "validation_report_ref": validation_report_ref,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_worker_output_validation_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [validation_report_ref]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "tasks.json")]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, f"events.jsonl#seq={seq}")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "task_id": task_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )

        return 200, response

    def build_parallel_worker_artifacts(self, run_id: str, task_id: str, role_payload: dict[str, Any]) -> dict[str, Any] | None:
        return None

    def persist_parallel_worker_artifacts(self, parallel_artifacts: dict[str, Any]) -> None:
        return None

    def accept_worker_output(
        self,
        run_id: str,
        task_id: str,
        task: dict[str, Any],
        tasks: dict[str, Any],
        worker_response: dict[str, Any],
        idempotency_key: str,
        endpoint: str,
        resource_path: str,
        payload_hash: str,
        idempotency_path: Path,
    ) -> tuple[int, dict[str, Any]]:
        role_payload = worker_response.get("role_specific_payload")
        if not isinstance(role_payload, dict) or role_payload.get("requested_transition") != "task_complete":
            return 400, self.error("unsupported_worker_output", "only task_complete is implemented")
        try:
            parallel_artifacts = self.build_parallel_worker_artifacts(run_id, task_id, role_payload)
        except ValueError as exc:
            return 400, self.error("validation_error", str(exc))
        if parallel_artifacts is not None:
            self.persist_parallel_worker_artifacts(parallel_artifacts)
            if parallel_artifacts["blocked"]:
                return self.block_worker_output_parallel_conflict(
                    run_id=run_id,
                    task_id=task_id,
                    task=task,
                    tasks=tasks,
                    idempotency_key=idempotency_key,
                    endpoint=endpoint,
                    resource_path=resource_path,
                    payload_hash=payload_hash,
                    idempotency_path=idempotency_path,
                    parallel_artifacts=parallel_artifacts,
                )

        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        run_ref = self.store.state_ref(run_id, "run.json")
        task_projection_ref = self.store.state_ref(run_id, "tasks.json")
        worker_output_report_ref = self.store.state_ref(run_id, f"worker-output-reports/{command_id}.json")
        parallel_refs = parallel_artifacts["artifact_refs"] if parallel_artifacts is not None else []

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_worker_output",
            "planned_side_effects": [
                *(
                    [
                        "write_parallel_group_plan",
                        "write_conflict_scan",
                    ]
                    if parallel_artifacts is not None
                    else []
                ),
                "write_worker_output_report",
                "write_task_projection",
                "write_run_state",
                "append_audit",
                "complete_kanban_task",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        report = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "worker_output_report",
            "run_id": run_id,
            "task_id": task_id,
            "command_id": command_id,
            "role": worker_response.get("role"),
            "stage": task.get("stage"),
            "result": "accepted",
            "requested_transition": "task_complete",
            "artifact_refs": role_payload.get("artifact_refs", []),
            "changed_files": role_payload.get("changed_files", []),
            "diff_summary": role_payload.get("diff_summary", ""),
            "test_evidence_refs": role_payload.get("test_evidence_refs", []),
            "commands": role_payload.get("commands", []),
            "parallel_artifact_refs": parallel_refs,
            "parallel_group_id": parallel_artifacts["parallel_group_id"] if parallel_artifacts is not None else None,
            "backend_execution": role_payload.get(
                "backend_execution",
                {
                    "backend": "codex" if worker_response.get("role") == "implementer" else "claude",
                    "backend_kind": "cli",
                    "executed": True,
                },
            ),
            "created_at": now,
        }
        write_json(self.store.run_dir(run_id) / "worker-output-reports" / f"{command_id}.json", report)

        task_refs = task.get("artifact_refs") if isinstance(task.get("artifact_refs"), list) else []
        if worker_output_report_ref not in task_refs:
            task_refs.append(worker_output_report_ref)
        for ref in parallel_refs:
            if ref not in task_refs:
                task_refs.append(ref)
        task.update({"status": "completed", "artifact_refs": task_refs})
        task.pop("blocked_reason", None)
        tasks["updated_at"] = now
        write_json(self.store.tasks_path(run_id), tasks)

        run = read_json(self.store.run_path(run_id))
        self.advance_run_stage_projection(run, task.get("stage"), command_id, now)
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": run.get("status"), "updated_at": now})

        audit_ref = self.store.audit_ref(command_id)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "worker_output_accepted",
                "decision": "ACCEPTED",
                "user_decision": "",
                "details": "Worker output passed Advancement Gate and completed target task",
                "approval_id": "",
                "ttl": "",
                "task_id": task_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "parallel_group_id": parallel_artifacts["parallel_group_id"] if parallel_artifacts is not None else "",
            },
        )

        kanban_completed = self.complete_kanban_task(task.get("kanban_ref"))
        seq = self.next_event_seq(run_id)
        projection_issue_refs = []
        projection_issue_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": seq,
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": task.get("stage"),
                "type": "task_completed",
                "severity": "info",
                "status": "completed",
                "message": "Target task completed after Advancement Gate validation",
                "artifact_refs": [worker_output_report_ref, run_ref, task_projection_ref, audit_ref, *parallel_refs],
                "decision_id": None,
            },
        )
        if projection_issue_ref:
            projection_issue_refs.append(projection_issue_ref)
        stage_projection_issue_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": task.get("stage"),
                "type": "stage_completed",
                "severity": "info",
                "status": "completed",
                "message": "Stage task completed through Advancement Gate",
                "artifact_refs": [worker_output_report_ref, run_ref, task_projection_ref, audit_ref, *parallel_refs],
                "decision_id": None,
            },
        )
        if stage_projection_issue_ref:
            projection_issue_refs.append(stage_projection_issue_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": task_id,
            "gate_result": "accepted",
            "transition": "task_complete",
            "worker_output_report_ref": worker_output_report_ref,
            "parallel_artifact_refs": parallel_refs,
            "kanban_lifecycle_advanced": kanban_completed,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            *(
                [
                    {"step_id": "write_parallel_group_plan", "target_authority": "state", "operation": "write", "status": "completed", "refs": [parallel_artifacts["plan_ref"]]},
                    {"step_id": "write_conflict_scan", "target_authority": "state", "operation": "write", "status": "completed", "refs": [parallel_artifacts["scan_ref"]]},
                ]
                if parallel_artifacts is not None
                else []
            ),
            {"step_id": "write_worker_output_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [worker_output_report_ref]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [task_projection_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {"step_id": "complete_kanban_task", "target_authority": "hermes_kanban", "operation": "complete", "status": "completed" if kanban_completed else "failed", "refs": [task.get("kanban_ref")]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, f"events.jsonl#seq={seq}")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "task_id": task_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def block_worker_output_parallel_conflict(
        self,
        *,
        run_id: str,
        task_id: str,
        task: dict[str, Any],
        tasks: dict[str, Any],
        idempotency_key: str,
        endpoint: str,
        resource_path: str,
        payload_hash: str,
        idempotency_path: Path,
        parallel_artifacts: dict[str, Any],
    ) -> tuple[int, dict[str, Any]]:
        """Persist a blocked worker-output decision when mechanical parallel conflicts exist."""
        now = utc_now()
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        command_path = self.store.command_path(run_id, command_id)
        run_ref = self.store.state_ref(run_id, "run.json")
        task_projection_ref = self.store.state_ref(run_id, "tasks.json")
        report_ref = parallel_artifacts["report_ref"]
        artifact_refs = [parallel_artifacts["plan_ref"], parallel_artifacts["scan_ref"], report_ref]

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "submit_worker_output",
            "planned_side_effects": [
                "write_parallel_group_plan",
                "write_conflict_scan",
                "write_merge_conflict_report",
                "write_task_projection",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        task_refs = task.get("artifact_refs") if isinstance(task.get("artifact_refs"), list) else []
        for ref in artifact_refs:
            if ref not in task_refs:
                task_refs.append(ref)
        task.update({"status": "blocked", "blocked_reason": "worker_output_parallel_conflict", "artifact_refs": task_refs})
        tasks["updated_at"] = now
        write_json(self.store.tasks_path(run_id), tasks)

        run = read_json(self.store.run_path(run_id))
        pending_decision_refs = run.get("pending_decision_refs") if isinstance(run.get("pending_decision_refs"), list) else []
        if report_ref not in pending_decision_refs:
            pending_decision_refs.append(report_ref)
        run.update(
            {
                "status": "blocked",
                "last_command_id": command_id,
                "updated_at": now,
                "blocked_reason": "worker_output_parallel_conflict",
                "pending_decision_refs": pending_decision_refs,
            }
        )
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "blocked", "updated_at": now})

        audit_ref = self.store.audit_ref(command_id)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L2",
                "project": self.store.project_id,
                "type": "worker_output_blocked",
                "decision": "BLOCKED",
                "user_decision": "",
                "details": "Parallel integration conflict requires Kimi decision before serial merge",
                "approval_id": "",
                "ttl": "",
                "task_id": task_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "failure_class": "parallel_conflict",
                "parallel_group_id": parallel_artifacts["parallel_group_id"],
            },
        )

        seq = self.next_event_seq(run_id)
        projection_issue_refs = []
        projection_issue_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": seq,
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": task_id,
                "stage": task.get("stage"),
                "type": "worker_output_blocked",
                "severity": "error",
                "status": "blocked",
                "message": "Parallel integration conflict blocked worker output acceptance",
                "artifact_refs": [*artifact_refs, run_ref, task_projection_ref, audit_ref],
                "decision_id": None,
            },
        )
        if projection_issue_ref:
            projection_issue_refs.append(projection_issue_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": task_id,
            "gate_result": "blocked",
            "failure_class": "parallel_conflict",
            "parallel_group_plan_ref": parallel_artifacts["plan_ref"],
            "conflict_scan_ref": parallel_artifacts["scan_ref"],
            "merge_conflict_report_ref": report_ref,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_parallel_group_plan", "target_authority": "state", "operation": "write", "status": "completed", "refs": [parallel_artifacts["plan_ref"]]},
            {"step_id": "write_conflict_scan", "target_authority": "state", "operation": "write", "status": "completed", "refs": [parallel_artifacts["scan_ref"]]},
            {"step_id": "write_merge_conflict_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [report_ref]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [task_projection_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, f"events.jsonl#seq={seq}")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "task_id": task_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def advance_run_stage_projection(self, run: dict[str, Any], stage: Any, command_id: str, updated_at: str) -> None:
        if not isinstance(stage, str) or stage not in STAGES:
            return
        stages = run.get("stages") if isinstance(run.get("stages"), list) else []
        for item in stages:
            if isinstance(item, dict) and item.get("stage") == stage:
                item["status"] = "completed"
        completed = len([item for item in stages if isinstance(item, dict) and item.get("status") == "completed"])
        next_stage = STAGES[completed] if completed < len(STAGES) else stage
        run.update(
            {
                "status": "queued",
                "last_command_id": command_id,
                "updated_at": updated_at,
                "current_stage": next_stage,
                "progress": {"completed_stages": completed, "total_stages": len(STAGES)},
                "blocked_reason": None,
                "pending_decision_refs": [],
            }
        )

    def complete_kanban_task(self, kanban_ref: Any) -> bool:
        if not isinstance(kanban_ref, str) or not kanban_ref:
            return False
        try:
            completed = subprocess.run(
                ["hermes", "kanban", "complete", "--board", self.store.project_id, "--task", kanban_ref],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except FileNotFoundError:
            return False
        return completed.returncode == 0

    def find_projected_task(self, tasks: dict[str, Any], task_id: str) -> dict[str, Any] | None:
        items = tasks.get("tasks")
        if not isinstance(items, list):
            return None
        for item in items:
            if isinstance(item, dict) and item.get("task_id") == task_id:
                return item
        return None

    def find_stage_task(self, tasks: dict[str, Any], stage: str) -> dict[str, Any] | None:
        items = tasks.get("tasks")
        if not isinstance(items, list):
            return None
        for item in items:
            if isinstance(item, dict) and item.get("stage") == stage:
                return item
        return None

    def review_verdict_violations(self, verdict: dict[str, Any], run_id: str, task_id: str) -> list[str]:
        violations = []
        required = [
            "schema_version",
            "artifact_type",
            "run_id",
            "task_id",
            "stage",
            "review_kind",
            "verdict",
            "findings",
            "affected_acceptance_criteria_refs",
            "required_fixes",
            "evidence_refs",
            "within_approved_scope",
            "risk_level",
            "authority_required",
            "improvement_cycle",
            "supersedes_ref",
        ]
        for field in required:
            if field not in verdict:
                violations.append(field)
        if verdict.get("schema_version") != SCHEMA_VERSION:
            violations.append("schema_version")
        if verdict.get("artifact_type") not in {"review_report", "qa_report", "re_review_report", "re_qa_report"}:
            violations.append("artifact_type")
        if verdict.get("run_id") != run_id:
            violations.append("run_id")
        if verdict.get("task_id") != task_id:
            violations.append("task_id")
        if verdict.get("review_kind") not in {"code_review", "qa", "test_review", "security_review"}:
            violations.append("review_kind")
        if verdict.get("verdict") not in {"approve", "request_changes", "reject", "block"}:
            violations.append("verdict")
        if verdict.get("risk_level") not in {"low", "medium", "high", "critical", "L1", "L2", "L3", "L4"}:
            violations.append("risk_level")
        if verdict.get("authority_required") not in {"kimi", "human"}:
            violations.append("authority_required")
        for list_field in ["findings", "affected_acceptance_criteria_refs", "required_fixes", "evidence_refs"]:
            if not isinstance(verdict.get(list_field), list):
                violations.append(list_field)
        expected_prefix = f"state://runs/{run_id}/"
        evidence_refs = verdict.get("evidence_refs")
        if isinstance(evidence_refs, list):
            for ref in evidence_refs:
                if not self.valid_scoped_state_ref(ref, expected_prefix):
                    violations.append("evidence_refs")
                    break
        return sorted(set(violations))

    def global_evaluation_violations(self, report: dict[str, Any], run_id: str) -> list[str]:
        violations = []
        required = [
            "schema_version",
            "artifact_type",
            "run_id",
            "stage",
            "input_artifact_refs",
            "structured_prd_ref",
            "development_plan_ref",
            "debate_report_refs",
            "implementation_evidence_refs",
            "review_verdict_refs",
            "qa_verdict_refs",
            "test_execution_refs",
            "improvement_report_refs",
            "downgrade_refs",
            "unresolved_decision_refs",
            "audit_refs",
            "verdict",
            "warnings",
            "residual_risks",
            "blocking_issues",
            "authority_required",
            "final_acceptance_ref",
            "next_actions",
            "created_at",
        ]
        for field in required:
            if field not in report:
                violations.append(field)
        if report.get("schema_version") != SCHEMA_VERSION:
            violations.append("schema_version")
        if report.get("artifact_type") != "global_evaluation_report":
            violations.append("artifact_type")
        if report.get("run_id") != run_id:
            violations.append("run_id")
        if report.get("stage") != "global_evaluation":
            violations.append("stage")
        if report.get("verdict") not in {"pass", "pass_with_warnings", "fail", "block"}:
            violations.append("verdict")
        if report.get("authority_required") not in {"kimi", "human"}:
            violations.append("authority_required")
        for list_field in [
            "input_artifact_refs",
            "debate_report_refs",
            "implementation_evidence_refs",
            "review_verdict_refs",
            "qa_verdict_refs",
            "test_execution_refs",
            "improvement_report_refs",
            "downgrade_refs",
            "unresolved_decision_refs",
            "audit_refs",
            "warnings",
            "residual_risks",
            "blocking_issues",
            "next_actions",
        ]:
            if not isinstance(report.get(list_field), list):
                violations.append(list_field)
        expected_prefix = f"state://runs/{run_id}/"
        for ref_field in ["structured_prd_ref", "development_plan_ref"]:
            if not self.valid_scoped_state_ref(report.get(ref_field), expected_prefix):
                violations.append(ref_field)
        final_acceptance_ref = report.get("final_acceptance_ref")
        if final_acceptance_ref is not None and not self.valid_scoped_state_ref(final_acceptance_ref, expected_prefix):
            violations.append("final_acceptance_ref")
        for ref_field in ["input_artifact_refs", "debate_report_refs", "implementation_evidence_refs", "review_verdict_refs", "qa_verdict_refs", "test_execution_refs", "improvement_report_refs", "downgrade_refs", "unresolved_decision_refs"]:
            refs = report.get(ref_field)
            if isinstance(refs, list):
                for ref in refs:
                    if not self.valid_scoped_state_ref(ref, expected_prefix):
                        violations.append(ref_field)
                        break
        return sorted(set(violations))

    def closeout_completion_blockers(self, run_id: str, closeout_report: dict[str, Any], proposals: dict[str, Any]) -> list[str]:
        blockers = []
        if closeout_report.get("schema_version") != SCHEMA_VERSION:
            blockers.append("iteration_closeout_report.schema_version")
        if closeout_report.get("artifact_type") != "iteration_closeout_report":
            blockers.append("iteration_closeout_report.artifact_type")
        if closeout_report.get("run_id") != run_id:
            blockers.append("iteration_closeout_report.run_id")
        if closeout_report.get("closeout_kind") != "completed":
            blockers.append("iteration_closeout_report.closeout_kind")
        if not isinstance(closeout_report.get("final_acceptance"), dict):
            blockers.append("iteration_closeout_report.final_acceptance")
        completion_gate = closeout_report.get("completion_gate")
        if not isinstance(completion_gate, dict):
            blockers.append("iteration_closeout_report.completion_gate")
        else:
            for gate_field in ["artifacts_schema_valid", "audit_closeout_recorded", "kanban_stage_tasks_done", "gateway_state_consistent"]:
                if completion_gate.get(gate_field) is not True:
                    blockers.append(f"completion_gate.{gate_field}")
            if completion_gate.get("completion_blockers") != []:
                blockers.append("completion_gate.completion_blockers")

        if proposals.get("schema_version") != SCHEMA_VERSION:
            blockers.append("system_improvement_proposals.schema_version")
        if proposals.get("artifact_type") != "system_improvement_proposals":
            blockers.append("system_improvement_proposals.artifact_type")
        if proposals.get("run_id") != run_id:
            blockers.append("system_improvement_proposals.run_id")
        auto_applied_refs = proposals.get("auto_applied_refs")
        if isinstance(auto_applied_refs, list):
            for ref in auto_applied_refs:
                if not isinstance(ref, str) or not ref.startswith("repo://.workflow/knowledge/"):
                    blockers.append("system_improvement_proposals.forbidden_auto_apply")
                    break
        proposal_items = proposals.get("proposals")
        if isinstance(proposal_items, list):
            for proposal in proposal_items:
                if not isinstance(proposal, dict):
                    continue
                target = proposal.get("target")
                if proposal.get("status") == "auto_applied_low_risk" and not (isinstance(target, str) and target.startswith(".workflow/knowledge/")):
                    blockers.append("system_improvement_proposals.forbidden_auto_apply")
                    break
        knowledge_updates = closeout_report.get("knowledge_updates")
        if isinstance(knowledge_updates, dict):
            refs = knowledge_updates.get("auto_applied_refs")
            if isinstance(refs, list):
                for ref in refs:
                    if not isinstance(ref, str) or not ref.startswith("repo://.workflow/knowledge/"):
                        blockers.append("system_improvement_proposals.forbidden_auto_apply")
                        break

        if not self.closeout_test_execution_refs_valid(run_id, closeout_report.get("test_execution_refs")):
            blockers.append("test_execution_refs")

        run = read_json(self.store.run_path(run_id))
        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        if not artifact_refs.get("global_evaluation_report"):
            blockers.append("global_evaluation_report")
        if not artifact_refs.get("final_acceptance"):
            blockers.append("final_acceptance")

        tasks_path = self.store.tasks_path(run_id)
        if not tasks_path.exists():
            blockers.append("kanban_stage_tasks_done")
        else:
            tasks = read_json(tasks_path).get("tasks")
            if not isinstance(tasks, list) or len(tasks) < len(STAGES):
                blockers.append("kanban_stage_tasks_done")
            elif any(not isinstance(task, dict) or task.get("status") != "completed" for task in tasks):
                blockers.append("kanban_stage_tasks_done")
        return sorted(set(blockers))

    def closeout_test_execution_refs_valid(self, run_id: str, refs: Any) -> bool:
        if not isinstance(refs, list) or not refs:
            return False
        saw_executed_success = False
        for ref in refs:
            path = self.state_artifact_path(run_id, ref)
            if path is None or not path.exists():
                return False
            try:
                report = read_json(path)
            except (OSError, json.JSONDecodeError):
                return False
            if report.get("schema_version") != SCHEMA_VERSION:
                return False
            if report.get("artifact_type") != "test_execution_report":
                return False
            if report.get("run_id") != run_id:
                return False
            commands = report.get("commands")
            if not isinstance(commands, list):
                return False
            for command in commands:
                if isinstance(command, dict) and command.get("executed") is True and command.get("exit_code") == 0:
                    saw_executed_success = True
        return saw_executed_success

    def state_artifact_path(self, run_id: str, ref: Any) -> Path | None:
        expected_prefix = f"state://runs/{run_id}/"
        if not self.valid_scoped_state_ref(ref, expected_prefix):
            return None
        suffix = str(ref)[len(expected_prefix) :].split("#", 1)[0]
        return self.store.run_dir(run_id) / suffix

    def failure_report_violations(self, report: dict[str, Any], run_id: str) -> list[str]:
        violations = []
        required = [
            "schema_version",
            "artifact_type",
            "run_id",
            "failure_class",
            "terminal_failure_reason",
            "failed_stage",
            "failed_task_id",
            "authority_chain_assessment",
            "unrecoverable_artifact_refs",
            "unauthorized_write_refs",
            "invariant_violation_refs",
            "last_good_checkpoint_ref",
            "preserved_state_refs",
            "preserved_audit_refs",
            "preserved_kanban_refs",
            "preserved_artifact_refs",
            "lineage_hint_refs",
            "run_failed_event_ref",
            "created_at",
        ]
        for field in required:
            if field not in report:
                violations.append(field)
        if report.get("schema_version") != SCHEMA_VERSION:
            violations.append("schema_version")
        if report.get("artifact_type") != "run_failure_report":
            violations.append("artifact_type")
        if report.get("run_id") != run_id:
            violations.append("run_id")
        if report.get("terminal_failure_reason") not in {
            "authority_chain_corrupt",
            "critical_artifact_unrecoverable",
            "unauthorized_write_untrusted",
            "invariant_unrecoverable",
        }:
            violations.append("terminal_failure_reason")
        expected_prefix = f"state://runs/{run_id}/"
        for ref_field in [
            "unrecoverable_artifact_refs",
            "unauthorized_write_refs",
            "invariant_violation_refs",
            "preserved_state_refs",
            "preserved_kanban_refs",
            "preserved_artifact_refs",
            "lineage_hint_refs",
        ]:
            refs = report.get(ref_field)
            if not isinstance(refs, list):
                violations.append(ref_field)
                continue
            for ref in refs:
                if not self.valid_scoped_state_ref(ref, expected_prefix):
                    violations.append(ref_field)
                    break
        checkpoint_ref = report.get("last_good_checkpoint_ref")
        if checkpoint_ref is not None and not self.valid_scoped_state_ref(checkpoint_ref, expected_prefix):
            violations.append("last_good_checkpoint_ref")
        if not isinstance(report.get("authority_chain_assessment"), dict):
            violations.append("authority_chain_assessment")
        return sorted(set(violations))

    def verdict_improvement_cycle(self, verdict: dict[str, Any]) -> int:
        value = verdict.get("improvement_cycle")
        return value if isinstance(value, int) else 0

    def block_kanban_task(self, kanban_ref: Any, reason: str) -> bool:
        if not isinstance(kanban_ref, str) or not kanban_ref:
            return False
        try:
            completed = subprocess.run(
                ["hermes", "kanban", "block", "--board", self.store.project_id, "--task", kanban_ref, "--reason", reason],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except FileNotFoundError:
            return False
        return completed.returncode == 0

    def worker_response_schema_violations(self, worker_response: dict[str, Any]) -> list[str]:
        violations = []
        required = ["protocol", "role", "correlation_id", "turn", "status", "next_action", "role_specific_payload", "conversation_context"]
        for field in required:
            if field not in worker_response:
                violations.append(field)
        if worker_response.get("protocol") != "hermes-role-engine/v1":
            violations.append("protocol")
        if worker_response.get("next_action") in {"complete", "block", "create_tasks", "defer_to_human"}:
            role_payload = worker_response.get("role_specific_payload")
            if not isinstance(role_payload, dict):
                violations.append("role_specific_payload")
            else:
                for field in ["requested_transition", "artifact_refs", "changed_files", "diff_summary", "write_scope_result", "test_evidence_refs", "risk_notes", "approval_refs"]:
                    if field not in role_payload:
                        violations.append(field)
        return sorted(set(violations))

    def worker_response_identity_violations(self, worker_response: dict[str, Any], task_id: str) -> list[str]:
        violations = []
        if worker_response.get("correlation_id") != task_id:
            violations.append("correlation_id")
        if worker_response.get("role") not in {"implementer", "reviewer"}:
            violations.append("role")
        return violations

    def worker_response_artifact_ref_violations(self, worker_response: dict[str, Any], run_id: str) -> list[str]:
        role_payload = worker_response.get("role_specific_payload")
        if not isinstance(role_payload, dict):
            return ["artifact_refs"]
        refs = role_payload.get("artifact_refs")
        if not isinstance(refs, list):
            return ["artifact_refs"]
        expected_prefix = f"state://runs/{run_id}/"
        for ref in refs:
            if not self.valid_scoped_state_ref(ref, expected_prefix):
                return ["artifact_refs"]
        return []

    def worker_response_write_scope_violations(self, worker_response: dict[str, Any]) -> list[str]:
        role_payload = worker_response.get("role_specific_payload")
        if not isinstance(role_payload, dict):
            return ["write_scope_result"]
        result = role_payload.get("write_scope_result")
        if not isinstance(result, dict):
            return ["write_scope_result"]
        violations = result.get("violations")
        forbidden_paths = result.get("forbidden_paths_touched")
        if result.get("within_scope") is not True:
            return ["write_scope_result"]
        if isinstance(violations, list) and violations:
            return ["write_scope_result"]
        if isinstance(forbidden_paths, list) and forbidden_paths:
            return ["write_scope_result"]
        return []

    def worker_response_evidence_violations(self, worker_response: dict[str, Any]) -> list[str]:
        role_payload = worker_response.get("role_specific_payload")
        if not isinstance(role_payload, dict):
            return ["test_evidence_refs"]
        changed_files = role_payload.get("changed_files")
        test_refs = role_payload.get("test_evidence_refs")
        if role_payload.get("requested_transition") == "task_complete" and isinstance(changed_files, list) and changed_files:
            if not isinstance(test_refs, list) or not test_refs:
                return ["test_evidence_refs"]
        return []

    def next_event_seq(self, run_id: str) -> int:
        path = self.store.events_path(run_id)
        if not path.exists():
            return 1
        last = 0
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    last = max(last, int(json.loads(line).get("seq", 0)))
        return last + 1

    def resolve_decision(self, decision_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        idempotency_key = payload.get("idempotency_key")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            return 400, self.error("validation_error", "idempotency_key is required")
        endpoint = "POST /orchestra/decisions/{decision_id}"
        resource_path = f"/orchestra/decisions/{decision_id}"
        payload_hash = canonical_payload_hash(payload)
        idempotency_path = self.store.idempotency_path(endpoint, resource_path, idempotency_key)
        if idempotency_path.exists():
            record = read_json(idempotency_path)
            if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
                return int(record.get("http_status") or 200), record["response_summary"]
            body = self.error("idempotency_conflict", "idempotency_key was already used with a different payload")
            body["existing_command_id"] = record.get("command_id")
            body["existing_run_id"] = record.get("run_id")
            return 409, body

        if payload.get("action") != "approve":
            return 400, self.error("validation_error", "only approve is implemented for intake decisions")

        found = self.find_run_by_decision(decision_id)
        if found is None:
            return 404, self.error("not_found", "decision not found")
        run_id, run = found
        if run.get("status") == "blocked" and run.get("blocked_reason") == "global_evaluation_acceptance_required":
            return self.approve_global_evaluation_acceptance(
                run_id,
                run,
                decision_id,
                payload,
                idempotency_key,
                endpoint,
                resource_path,
                payload_hash,
                idempotency_path,
            )
        if run.get("status") != "blocked" or run.get("blocked_reason") != "structured_prd_required":
            return 409, self.error("decision_not_applicable", "decision is not an intake blocker")
        ticket = payload.get("ticket")
        if not isinstance(ticket, dict):
            return 400, self.error("validation_error", "ticket is required to approve an intake decision")

        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        now = utc_now()
        command_path = self.store.command_path(run_id, command_id)
        completion_bundle_ref = self.store.state_ref(run_id, "requirement-completion-bundle.json")
        structured_prd_ref = self.store.state_ref(run_id, "structured_prd.json")

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "resolve_decision",
            "planned_side_effects": [
                "write_requirement_completion_bundle",
                "write_structured_prd",
                "create_kanban_stage_tasks",
                "write_task_projection",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        completion_bundle = self._requirement_completion_bundle({"idempotency_key": idempotency_key, "ticket": ticket}, "create_run", run_id)
        bundle_validation = _completion_bundle_validate(completion_bundle)
        if bundle_validation.get("status") == "blocked":
            body = self.error("completion_bundle_blocked", "requirement completion bundle is incomplete")
            body.update(bundle_validation)
            return 409, body
        write_json(command_path, command_record)

        write_json(self.store.run_dir(run_id) / "requirement-completion-bundle.json", completion_bundle)
        structured_prd = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "structured_prd",
            "run_id": run_id,
            "source": "decision",
            "status": "ready",
            "background": ticket.get("background"),
            "goal": ticket.get("goal"),
            "deliverables": ticket.get("deliverables", []),
            "acceptance_criteria": ticket.get("acceptance_criteria", []),
            "hard_constraints": ticket.get("hard_constraints", []),
            "soft_constraints": ticket.get("soft_constraints", []),
            "related_tasks": ticket.get("related_tasks", []),
            "failure_strategy": ticket.get("failure_strategy"),
            "created_at": now,
        }
        write_json(self.store.run_dir(run_id) / "structured_prd.json", structured_prd)

        stage_tasks = self.create_kanban_stage_tasks(run_id)
        tasks = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "project": self.store.project_id,
            "projection_status": "consistent",
            "authority_refs_checked": [self.store.state_ref(run_id, "run.json"), structured_prd_ref, completion_bundle_ref],
            "tasks": stage_tasks,
            "updated_at": now,
        }
        write_json(self.store.tasks_path(run_id), tasks)

        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs.update(
            {
                "command_record": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "requirement_completion_bundle": completion_bundle_ref,
                "structured_prd": structured_prd_ref,
                "task_projection": self.store.state_ref(run_id, "tasks.json"),
            }
        )
        run.update(
            {
                "status": "queued",
                "last_command_id": command_id,
                "updated_at": now,
                "current_stage": "direction_debate",
                "stages": [{"stage": stage, "status": "queued"} for stage in STAGES],
                "blocked_reason": None,
                "pending_decision_id": None,
                "pending_decision_refs": [],
                "artifact_refs": artifact_refs,
            }
        )
        write_json(self.store.run_path(run_id), run)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "queued", "updated_at": now})

        audit_ref = self.store.audit_ref(command_id)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": self.store.project_id,
                "type": "decision_resolved",
                "decision": "APPROVED",
                "user_decision": "approve",
                "details": "Structured PRD gate approved with ticket",
                "approval_id": decision_id,
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "decision_id": decision_id,
            },
        )

        seq = self.next_event_seq(run_id)
        append_jsonl(
            self.store.events_path(run_id),
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": seq,
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "intake",
                "type": "decision_resolved",
                "severity": "info",
                "status": "queued",
                "message": "Structured PRD gate approved",
                "artifact_refs": [self.store.state_ref(run_id, "run.json"), structured_prd_ref, audit_ref],
                "decision_id": decision_id,
            },
        )

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "decision_id": decision_id,
            "action": "approve",
            "status": "queued",
            "event_projection_degraded": False,
            "projection_status": "consistent",
            "projection_issue_refs": [],
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_requirement_completion_bundle", "target_authority": "state", "operation": "write", "status": "completed", "refs": [completion_bundle_ref]},
            {"step_id": "write_structured_prd", "target_authority": "state", "operation": "write", "status": "completed", "refs": [structured_prd_ref]},
            {"step_id": "create_kanban_stage_tasks", "target_authority": "kanban", "operation": "create", "status": "completed", "refs": [task.get("kanban_ref") for task in stage_tasks]},
            {"step_id": "write_task_projection", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "tasks.json")]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [self.store.state_ref(run_id, "run.json")]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {"step_id": "append_event_projection", "target_authority": "state", "operation": "append", "status": "completed", "refs": [self.store.state_ref(run_id, f"events.jsonl#seq={seq}")]},
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "decision_id": decision_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def approve_global_evaluation_acceptance(
        self,
        run_id: str,
        run: dict[str, Any],
        decision_id: str,
        payload: dict[str, Any],
        idempotency_key: str,
        endpoint: str,
        resource_path: str,
        payload_hash: str,
        idempotency_path: Path,
    ) -> tuple[int, dict[str, Any]]:
        command_id = f"cmd-{uuid.uuid4().hex[:16]}"
        now = utc_now()
        command_path = self.store.command_path(run_id, command_id)
        final_acceptance_ref = self.store.state_ref(run_id, "final_acceptance.json")
        global_report_ref = self.store.state_ref(run_id, "global_evaluation_report.json")
        run_ref = self.store.state_ref(run_id, "run.json")

        command_record = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "command_record",
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "project": self.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "status": "in_progress",
            "payload_hash": payload_hash,
            "intent": "resolve_global_evaluation_acceptance",
            "planned_side_effects": [
                "write_final_acceptance",
                "update_global_evaluation_report",
                "write_run_state",
                "append_audit",
                "append_event_projection",
            ],
            "steps": [],
            "created_at": now,
            "updated_at": now,
        }
        write_json(command_path, command_record)

        accepted_warning_refs = payload.get("accepted_warning_refs") if isinstance(payload.get("accepted_warning_refs"), list) else []
        final_acceptance = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "final_acceptance",
            "run_id": run_id,
            "accepted_by": payload.get("actor") or "kimi",
            "authority": "kimi",
            "verdict": "accepted_with_warnings",
            "rationale": payload.get("rationale") or "",
            "decision_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
            "decision_id": decision_id,
            "global_evaluation_report_ref": global_report_ref,
            "accepted_warning_refs": accepted_warning_refs,
            "created_at": now,
        }
        write_json(self.store.run_dir(run_id) / "final_acceptance.json", final_acceptance)

        report_path = self.store.run_dir(run_id) / "global_evaluation_report.json"
        if report_path.exists():
            report = read_json(report_path)
            report["final_acceptance_ref"] = final_acceptance_ref
            write_json(report_path, report)

        artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
        artifact_refs["final_acceptance"] = final_acceptance_ref
        artifact_refs["global_evaluation_report"] = global_report_ref
        run.update(
            {
                "status": "queued",
                "last_command_id": command_id,
                "updated_at": now,
                "current_stage": "continuous_improvement",
                "blocked_reason": None,
                "pending_decision_id": None,
                "pending_decision_refs": [],
                "artifact_refs": artifact_refs,
            }
        )
        stages = run.get("stages") if isinstance(run.get("stages"), list) else []
        for stage in stages:
            if isinstance(stage, dict) and stage.get("stage") == "global_evaluation":
                stage["status"] = "completed"
            if isinstance(stage, dict) and stage.get("stage") == "continuous_improvement":
                stage["status"] = "queued"
        write_json(self.store.run_path(run_id), run)

        tasks_path = self.store.tasks_path(run_id)
        if tasks_path.exists():
            tasks = read_json(tasks_path)
            stage_task = self.find_stage_task(tasks, "continuous_improvement")
            if stage_task is not None and stage_task.get("status") != "completed":
                stage_task["status"] = "queued"
            tasks["updated_at"] = now
            write_json(tasks_path, tasks)
        write_json(self.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": "queued", "updated_at": now})

        audit_ref = self.store.audit_ref(command_id)
        append_jsonl(
            self.store.audit_path(),
            {
                "timestamp": now,
                "level": "L2",
                "project": self.store.project_id,
                "type": "decision_resolved",
                "decision": "APPROVED",
                "user_decision": "approve",
                "details": "Kimi accepted global evaluation warnings for Stage 6",
                "approval_id": decision_id,
                "ttl": "",
                "task_id": run_id,
                "escalation_id": "",
                "agent_source": "orch-gateway",
                "session_id": "",
                "command_id": command_id,
                "run_id": run_id,
                "decision_id": decision_id,
                "final_acceptance_ref": final_acceptance_ref,
            },
        )

        projection_issue_refs = []
        decision_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "global_evaluation",
                "type": "decision_resolved",
                "severity": "info",
                "status": "queued",
                "message": "Global evaluation warnings accepted",
                "artifact_refs": [final_acceptance_ref, global_report_ref, audit_ref],
                "decision_id": decision_id,
            },
        )
        if decision_event_ref:
            projection_issue_refs.append(decision_event_ref)
        stage_event_ref = self.append_event(
            run_id,
            {
                "schema_version": EVENT_SCHEMA_VERSION,
                "seq": self.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "continuous_improvement",
                "type": "stage_started",
                "severity": "info",
                "status": "queued",
                "message": "Stage 6 continuous improvement queued",
                "artifact_refs": [final_acceptance_ref, run_ref],
                "decision_id": None,
            },
        )
        if stage_event_ref:
            projection_issue_refs.append(stage_event_ref)

        response = {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "decision_id": decision_id,
            "action": "approve",
            "status": "queued",
            "route_result": "stage6_queued",
            "final_acceptance_ref": final_acceptance_ref,
            "event_projection_degraded": bool(projection_issue_refs),
            "projection_status": "inconsistent" if projection_issue_refs else "consistent",
            "projection_issue_refs": projection_issue_refs,
        }
        command_record["status"] = "completed"
        command_record["updated_at"] = utc_now()
        command_record["steps"] = [
            {"step_id": "write_final_acceptance", "target_authority": "state", "operation": "write", "status": "completed", "refs": [final_acceptance_ref]},
            {"step_id": "update_global_evaluation_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [global_report_ref]},
            {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
            {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
            {
                "step_id": "append_event_projection",
                "target_authority": "state",
                "operation": "append",
                "status": "failed" if projection_issue_refs else "completed",
                "refs": projection_issue_refs or [self.store.state_ref(run_id, "events.jsonl")],
            },
        ]
        command_record["response_summary"] = response
        write_json(command_path, command_record)
        write_json(
            idempotency_path,
            {
                "schema_version": SCHEMA_VERSION,
                "artifact_type": "idempotency_record",
                "project": self.store.project_id,
                "endpoint": endpoint,
                "resource_path": resource_path,
                "idempotency_key": idempotency_key,
                "payload_hash": payload_hash,
                "status": "completed",
                "http_status": 200,
                "command_id": command_id,
                "run_id": run_id,
                "decision_id": decision_id,
                "command_record_ref": self.store.state_ref(run_id, f"commands/{command_id}.json"),
                "response_summary": response,
                "created_at": now,
                "updated_at": utc_now(),
            },
        )
        return 200, response

    def find_run_by_decision(self, decision_id: str) -> tuple[str, dict[str, Any]] | None:
        runs_dir = self.store.state_dir / "runs"
        if not runs_dir.exists():
            return None
        for path in sorted(runs_dir.glob("*/run.json")):
            try:
                run = read_json(path)
            except (OSError, json.JSONDecodeError):
                continue
            if run.get("pending_decision_id") == decision_id:
                return path.parent.name, run
        return None

    def create_kanban_stage_tasks(self, run_id: str) -> list[dict[str, Any]]:
        tasks: list[dict[str, Any]] = []
        self.ensure_kanban_board()
        parent_kanban_ref = self.create_kanban_task(f"{run_id} workflow")
        previous_kanban_ref: str | None = None
        for index, stage in enumerate(STAGES, start=1):
            task_id = f"{run_id}-{stage}"
            title = f"{run_id} {stage}"
            kanban_ref = self.create_kanban_task(title)
            if previous_kanban_ref and kanban_ref:
                self.link_kanban_tasks(previous_kanban_ref, kanban_ref)
            tasks.append(
                {
                    "task_id": task_id,
                    "stage": stage,
                    "title": title,
                    "status": "queued",
                    "kanban_ref": kanban_ref,
                    "workflow_parent_kanban_ref": parent_kanban_ref,
                    "parents": [] if index == 1 else [f"{run_id}-{STAGES[index - 2]}"],
                    "artifact_refs": [],
                }
            )
            previous_kanban_ref = kanban_ref
        return tasks

    def create_kanban_task(self, title: str) -> str | None:
        try:
            completed = subprocess.run(
                ["hermes", "kanban", "create", "--board", self.store.project_id, "--title", title],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except FileNotFoundError:
            return None
        if completed.returncode != 0:
            return None
        try:
            data = json.loads(completed.stdout or "{}")
        except json.JSONDecodeError:
            return None
        return data.get("id") if isinstance(data.get("id"), str) else None

    def link_kanban_tasks(self, parent_ref: str, child_ref: str) -> bool:
        try:
            completed = subprocess.run(
                ["hermes", "kanban", "link", "--board", self.store.project_id, "--parent", parent_ref, "--child", child_ref],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except FileNotFoundError:
            return False
        return completed.returncode == 0

    def run_response(
        self,
        run_id: str,
        command_id: str,
        idempotency_key: str,
        status: str,
        source_run_id: str | None = None,
        lineage_ref: str | None = None,
        event_projection_degraded: bool = False,
        projection_issue_refs: list[str] | None = None,
    ) -> dict[str, Any]:
        return {
            "schema_version": SCHEMA_VERSION,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "status": status,
            "source_run_id": source_run_id,
            "lineage_ref": lineage_ref,
            "run_uri": f"state://{self.store.project_id}/{run_id}/run.json",
            "events_url": f"/orchestra/runs/{run_id}/events",
            "tasks_url": f"/orchestra/runs/{run_id}/tasks",
            "event_projection_degraded": event_projection_degraded,
            "projection_status": "inconsistent" if event_projection_degraded else "consistent",
            "projection_issue_refs": projection_issue_refs or [],
        }

    def run_status(self, run_id: str) -> tuple[int, dict[str, Any]]:
        path = self.store.run_path(run_id)
        if not path.exists():
            return 404, self.error("not_found", "run not found")
        return 200, read_json(path)

    def run_events(self, run_id: str, since_seq: int, limit: int) -> tuple[int, dict[str, Any]]:
        run_path = self.store.run_path(run_id)
        events_path = self.store.events_path(run_id)
        if not run_path.exists():
            return 404, self.error("not_found", "run not found")
        projection_status = "consistent"
        rebuilt_from_refs: list[str] = []
        projection_issue_refs: list[str] = []
        if not events_path.exists():
            rebuilt = self.rebuild_missing_event_store(run_id)
            if rebuilt is not None:
                projection_status = "rebuilt"
                rebuilt_from_refs = rebuilt["rebuilt_from_refs"]
                projection_issue_refs = rebuilt["projection_issue_refs"]
            elif self.projection_issue_refs(run_id):
                projection_status = "inconsistent"
                projection_issue_refs = self.projection_issue_refs(run_id)
        all_events = []
        events = []
        if events_path.exists():
            with events_path.open(encoding="utf-8") as handle:
                for line in handle:
                    if line.strip():
                        event = json.loads(line)
                        all_events.append(event)
                        if int(event.get("seq", 0)) > since_seq:
                            events.append(event)
        if events_path.exists() and projection_status == "consistent" and not self.event_sequence_consistent(all_events):
            projection_status = "inconsistent"
        sliced = events[:limit]
        next_seq = int(sliced[-1].get("seq", since_seq)) + 1 if sliced else since_seq + 1
        return 200, {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "since_seq": since_seq,
            "limit": limit,
            "events": sliced,
            "next_seq": next_seq,
            "has_more": len(events) > len(sliced),
            "projection_status": projection_status,
            "event_store_ref": self.store.state_ref(run_id, "events.jsonl"),
            "rebuilt_from_refs": rebuilt_from_refs,
            "authority_refs_checked": [self.store.state_ref(run_id, "run.json")],
            "projection_issue_refs": projection_issue_refs,
        }

    def event_sequence_consistent(self, events: list[dict[str, Any]]) -> bool:
        expected = 1
        seen: set[int] = set()
        for event in events:
            seq = event.get("seq")
            if not isinstance(seq, int):
                return False
            if seq in seen or seq != expected:
                return False
            seen.add(seq)
            expected += 1
        return True

    def rebuild_missing_event_store(self, run_id: str) -> dict[str, list[str]] | None:
        run = read_json(self.store.run_path(run_id))
        command_record = self.find_command_record(run_id, "create_run")
        if command_record is None:
            return None
        command_id = command_record.get("command_id")
        if not isinstance(command_id, str):
            return None
        audit_record = self.find_audit_record(command_id, "run_created")
        if audit_record is None or not self.store.tasks_path(run_id).exists():
            return None

        audit_ref = self.store.audit_ref(command_id)
        artifact_refs = [
            self.store.state_ref(run_id, "run.json"),
            self.store.state_ref(run_id, "tasks.json"),
            audit_ref,
        ]
        lineage_ref = run.get("lineage_ref")
        if isinstance(lineage_ref, str) and lineage_ref:
            artifact_refs.append(lineage_ref)

        event = {
            "schema_version": EVENT_SCHEMA_VERSION,
            "seq": 1,
            "timestamp": audit_record.get("timestamp") or command_record.get("created_at") or utc_now(),
            "command_id": command_id,
            "idempotency_key": command_record.get("idempotency_key"),
            "run_id": run_id,
            "task_id": None,
            "stage": None,
            "type": "run_created",
            "severity": "info",
            "status": run.get("status"),
            "message": "Six-Stage Run created",
            "artifact_refs": artifact_refs,
            "decision_id": None,
        }
        append_jsonl(self.store.events_path(run_id), event)

        response_summary = command_record.get("response_summary")
        projection_issue_refs = []
        if isinstance(response_summary, dict) and isinstance(response_summary.get("projection_issue_refs"), list):
            projection_issue_refs = response_summary["projection_issue_refs"]
        if not projection_issue_refs:
            projection_issue_refs = self.projection_issue_refs(run_id)

        return {
            "rebuilt_from_refs": [
                self.store.state_ref(run_id, "run.json"),
                self.store.state_ref(run_id, "tasks.json"),
                self.store.state_ref(run_id, f"commands/{command_id}.json"),
                audit_ref,
            ],
            "projection_issue_refs": projection_issue_refs,
        }

    def find_command_record(self, run_id: str, intent: str) -> dict[str, Any] | None:
        commands_dir = self.store.run_dir(run_id) / "commands"
        if not commands_dir.exists():
            return None
        for path in sorted(commands_dir.glob("*.json")):
            try:
                record = read_json(path)
            except (OSError, json.JSONDecodeError):
                continue
            if record.get("intent") == intent and record.get("status") == "completed":
                return record
        return None

    def find_audit_record(self, command_id: str, record_type: str) -> dict[str, Any] | None:
        path = self.store.audit_path()
        if not path.exists():
            return None
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue
                record = json.loads(line)
                if record.get("command_id") == command_id and record.get("type") == record_type:
                    return record
        return None

    def projection_issue_refs(self, run_id: str) -> list[str]:
        issue_dir = self.store.run_dir(run_id) / "projection-issues"
        if not issue_dir.exists():
            return []
        return [self.store.state_ref(run_id, f"projection-issues/{path.name}") for path in sorted(issue_dir.glob("*.json"))]

    def run_tasks(self, run_id: str) -> tuple[int, dict[str, Any]]:
        path = self.store.tasks_path(run_id)
        if not self.store.run_path(run_id).exists():
            return 404, self.error("not_found", "run not found")
        if not path.exists():
            return 200, {
                "schema_version": SCHEMA_VERSION,
                "run_id": run_id,
                "project": self.store.project_id,
                "projection_status": "consistent",
                "tasks": [],
            }
        return 200, read_json(path)

    def error(self, code: str, message: str) -> dict[str, Any]:
        return {"schema_version": SCHEMA_VERSION, "error": {"code": code, "message": message}}


class GatewayHandler(BaseHTTPRequestHandler):
    app: GatewayApp

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self.send_json(200, self.app.health())
            return
        if parsed.path == "/orchestra/capabilities":
            self.send_json(200, self.app.capabilities())
            return
        if parsed.path.startswith("/v1/"):
            status, body = self.app.proxy_v1(self.path, "GET")
            self.send_json(status, body)
            return

        route = self.run_route(parsed.path)
        if route:
            run_id, child = route
            if child is None:
                status, body = self.app.run_status(run_id)
                self.send_json(status, body)
                return
            if child == "events":
                query = parse_qs(parsed.query)
                since_seq = self.int_query(query, "since_seq", 0)
                limit = self.int_query(query, "limit", 100)
                status, body = self.app.run_events(run_id, since_seq, limit)
                if status == 200 and "text/event-stream" in self.headers.get("Accept", ""):
                    self.send_sse(body["events"])
                else:
                    self.send_json(status, body)
                return
            if child == "tasks":
                status, body = self.app.run_tasks(run_id)
                self.send_json(status, body)
                return

        self.send_json(404, self.app.error("not_found", "route not found"))

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path.startswith("/v1/"):
            length = int(self.headers.get("Content-Length", "0"))
            status, body = self.app.proxy_v1(self.path, "POST", self.rfile.read(length))
            self.send_json(status, body)
            return
        if parsed.path == "/orchestra/runs":
            payload = self.read_json_body()
            if payload is None:
                self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                return
            status, body = self.app.create_run(payload)
            self.send_json(status, body)
            return
        module_route = self.module_route(parsed.path)
        if module_route:
            module, operation = module_route
            payload = self.read_json_body()
            if payload is None:
                self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                return
            status, body = self.app.module_endpoint(module, operation, payload)
            self.send_json(status, body)
            return
        route = self.run_route(parsed.path)
        if route:
            run_id, child = route
            if child == "stop":
                payload = self.read_json_body()
                if payload is None:
                    self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                    return
                status, body = self.app.stop_run(run_id, payload)
                self.send_json(status, body)
                return
            if child == "worker-outputs":
                payload = self.read_json_body()
                if payload is None:
                    self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                    return
                status, body = self.app.submit_worker_output(run_id, payload)
                self.send_json(status, body)
                return
            if child == "verdicts":
                payload = self.read_json_body()
                if payload is None:
                    self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                    return
                status, body = self.app.submit_verdict(run_id, payload)
                self.send_json(status, body)
                return
            if child == "global-evaluations":
                payload = self.read_json_body()
                if payload is None:
                    self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                    return
                status, body = self.app.submit_global_evaluation(run_id, payload)
                self.send_json(status, body)
                return
            if child == "closeout":
                payload = self.read_json_body()
                if payload is None:
                    self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                    return
                status, body = self.app.submit_closeout(run_id, payload)
                self.send_json(status, body)
                return
            if child == "failures":
                payload = self.read_json_body()
                if payload is None:
                    self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                    return
                status, body = self.app.submit_failure(run_id, payload)
                self.send_json(status, body)
                return
        decision_id = self.decision_route(parsed.path)
        if decision_id:
            payload = self.read_json_body()
            if payload is None:
                self.send_json(400, self.app.error("invalid_json", "request body must be JSON"))
                return
            status, body = self.app.resolve_decision(decision_id, payload)
            self.send_json(status, body)
            return
        self.send_json(404, self.app.error("not_found", "route not found"))

    def run_route(self, path: str) -> tuple[str, str | None] | None:
        parts = [part for part in path.split("/") if part]
        if len(parts) == 3 and parts[:2] == ["orchestra", "runs"]:
            return parts[2], None
        if len(parts) == 4 and parts[:2] == ["orchestra", "runs"] and parts[3] in {"events", "tasks", "stop", "worker-outputs", "verdicts", "global-evaluations", "closeout", "failures"}:
            return parts[2], parts[3]
        return None

    def module_route(self, path: str) -> tuple[str, str] | None:
        parts = [part for part in path.split("/") if part]
        if len(parts) == 4 and parts[:2] == ["orchestra", "modules"]:
            return parts[2], parts[3]
        return None

    def decision_route(self, path: str) -> str | None:
        parts = [part for part in path.split("/") if part]
        if len(parts) == 3 and parts[:2] == ["orchestra", "decisions"]:
            return parts[2]
        return None

    def int_query(self, query: dict[str, list[str]], name: str, default: int) -> int:
        try:
            return int(query.get(name, [str(default)])[0])
        except ValueError:
            return default

    def read_json_body(self) -> dict[str, Any] | None:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw.decode("utf-8") if raw else "{}")
        except json.JSONDecodeError:
            return None
        return data if isinstance(data, dict) else None

    def send_json(self, status: int, body: dict[str, Any]) -> None:
        payload = json_bytes(body)
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        if body.get("fallback"):
            self.send_header("x-gateway-fallback", "heuristic" if body["fallback"] == "FALLBACK_HEURISTIC" else body["fallback"])
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def send_sse(self, events: list[dict[str, Any]]) -> None:
        lines: list[str] = []
        for event in events:
            lines.append(f"id: {event.get('seq')}")
            lines.append(f"event: {event.get('type')}")
            lines.append(f"data: {json.dumps(event, ensure_ascii=False, separators=(',', ':'))}")
            lines.append("")
        payload = ("\n".join(lines) + "\n").encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args: Any) -> None:
        print(f"{self.address_string()} - {format % args}", file=sys.stderr)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the local Hermes Orchestra Gateway adapter")
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8642)
    parser.add_argument("--allow-network-binding", action="store_true")
    parser.add_argument("--upstream-api-url", default="http://127.0.0.1:8643")
    args = parser.parse_args(argv)
    if args.host not in {"127.0.0.1", "localhost"} and not args.allow_network_binding:
        parser.error("non-loopback --host requires explicit --allow-network-binding")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    GatewayHandler.app = GatewayApp(args.project_id, args.upstream_api_url)
    server = ThreadingHTTPServer((args.host, args.port), GatewayHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
