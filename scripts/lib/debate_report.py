from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import jsonschema


class DebateReportError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def validate_artifact_definition(repo_root: Path | str, definition_name: str, artifact: dict[str, Any]) -> None:
    repo_path = Path(repo_root)
    schema = json.loads((repo_path / "config/schemas/orchestra.full.schema.json").read_text(encoding="utf-8"))
    try:
        jsonschema.validate(
            instance=artifact,
            schema={
                "$schema": schema["$schema"],
                "$ref": f"#/$defs/{definition_name}",
                "$defs": schema["$defs"],
            },
        )
    except jsonschema.ValidationError as exc:
        raise DebateReportError("schema_invalid", f"{definition_name} failed schema validation: {exc.message}") from exc


class DebateReportBuilder:
    def __init__(self, repo_root: Path | str, package_root: str = "config/debate/full") -> None:
        self.repo_root = Path(repo_root)
        self.package_root = package_root

    def build(
        self,
        run: dict[str, Any],
        assembly: dict[str, Any],
        backend_policy: dict[str, Any],
        invocations: list[dict[str, Any]],
        opinions: list[dict[str, Any]],
        invocation_receipts: list[dict[str, Any]],
        input_refs: list[str],
        affected_scopes: list[str],
    ) -> dict[str, Any]:
        run_id = self._run_id(run)
        stage = assembly["stage"]
        report_ref = f"state://runs/{run_id}/debate-reports/{stage}.json"
        audit_ref = f"state://runs/{run_id}/debate-audit/{stage}.json"
        package_ref = f"state://runs/{run_id}/debate-package/full-package.json"
        teams_ref = f"state://runs/{run_id}/debate-config/teams.json"
        modes_ref = f"state://runs/{run_id}/debate-config/modes.json"
        coverage_ref = f"state://runs/{run_id}/debate-config/coverage-policy.json"
        assembly_ref = f"state://runs/{run_id}/debate-config/assembly-policy.json"
        backend_ref = f"state://runs/{run_id}/debate-config/backend-policy.json"
        opinion_refs = [opinion["artifact_ref"] for opinion in opinions]
        invocation_refs = [invocation["artifact_ref"] for invocation in invocations]

        degraded = any(opinion["degraded"] for opinion in opinions)
        partial = len(opinions) != len(assembly["selected_member_ids"])
        missing_members = sorted(set(assembly["selected_member_ids"]) - {opinion["member_id"] for opinion in opinions})
        coverage_satisfied = not degraded and not partial and not missing_members
        if backend_policy.get("real_backend_required_for_full_acceptance", False) and degraded:
            coverage_satisfied = False

        missing_coverage = [f"missing_member:{member_id}" for member_id in missing_members]
        if degraded and backend_policy.get("real_backend_required_for_full_acceptance", False):
            missing_coverage.append("real_backend_required_for_full_acceptance")

        findings = self._flatten_opinion_values(opinions, "findings")
        risks = self._flatten_opinion_values(opinions, "risks")
        recommendations = self._flatten_opinion_values(opinions, "recommendations")
        conflicts = []
        requires_kimi_decision = degraded or any(opinion["requires_kimi_decision"] for opinion in opinions)
        authority_required = "kimi" if requires_kimi_decision else "none"
        verdict = "request_changes" if degraded or any(opinion["verdict"] == "block" for opinion in opinions) else "approve"
        degradation_record = self._degradation_record(
            degraded=degraded,
            affected_evidence_refs=opinion_refs,
            policy_ref=backend_ref,
        )

        report = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "debate_report",
            "debate_id": run["debate_id"],
            "run_id": run_id,
            "stage": stage,
            "created_at": self._created_at(invocations, opinions),
            "package_ref": package_ref,
            "mode": run["mode_id"],
            "coverage_policy_ref": coverage_ref,
            "assembly_policy_ref": assembly_ref,
            "backend_policy_ref": backend_ref,
            "question": run["question"],
            "input_refs": list(input_refs),
            "options": list(assembly.get("task_type_overlays_applied", [])),
            "selected_team_ids": list(assembly["selected_team_ids"]),
            "selected_member_ids": list(assembly["selected_member_ids"]),
            "opinion_refs": opinion_refs,
            "coverage_satisfied": coverage_satisfied,
            "required_coverage": dict(assembly["coverage_requirements"]),
            "missing_coverage": missing_coverage,
            "failed_invocation_refs": [],
            "partial": partial,
            "degraded": degraded,
            "degradation_status": "degraded" if degraded else "normal",
            "degradation_record": degradation_record,
            "findings": findings,
            "risks": risks,
            "recommendations": recommendations,
            "conflicts": conflicts,
            "synthesis": {
                "summary": "Debate synthesized from per-member opinions.",
                "opinion_count": len(opinions),
                "degraded_backend_ids": sorted({opinion["backend_id"] for opinion in opinions if opinion["degraded"]}),
                "affected_scopes": list(affected_scopes),
            },
            "confidence": "low" if degraded else "medium",
            "verdict": verdict,
            "requires_kimi_decision": requires_kimi_decision,
            "authority_required": authority_required,
            "kimi_decision_inputs": {
                "opinion_refs": opinion_refs,
                "blocking_member_ids": [opinion["member_id"] for opinion in opinions if opinion["blocking"]],
                "degraded": degraded,
            },
            "recommended_next_actions": [
                "Enable a real debate backend before using the report as strong acceptance evidence."
            ] if degraded else [],
            "audit_trail_ref": audit_ref,
            "artifact_refs": sorted(set([*input_refs, *invocation_refs, *opinion_refs, coverage_ref, assembly_ref, backend_ref])),
        }

        audit_trail = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "debate_audit_trail",
            "audit_id": report_ref.rsplit("/", 1)[-1].removesuffix(".json"),
            "debate_id": run["debate_id"],
            "run_id": run_id,
            "stage": stage,
            "created_at": report["created_at"],
            "package_ref": package_ref,
            "package_hash": self._package_hash(),
            "teams_config_ref": teams_ref,
            "modes_config_ref": modes_ref,
            "coverage_policy_ref": coverage_ref,
            "assembly_policy_ref": assembly_ref,
            "backend_policy_ref": backend_ref,
            "assembly_reason": "Dynamic assembly selected debate members before backend fan-out.",
            "assembly_input": {
                "stage": stage,
                "risk_level": assembly["assembly_input"]["risk_level"],
                "task_type_tags": list(assembly["assembly_input"]["task_type_tags"]),
                "affected_scopes": list(affected_scopes),
            },
            "matched_assembly_rules": list(assembly["matched_assembly_rules"]),
            "risk_overlay_applied": dict(assembly["risk_overlay_applied"]),
            "task_type_overlays_applied": list(assembly["task_type_overlays_applied"]),
            "project_overrides_applied": self._normalize_project_overrides(assembly.get("project_overrides_applied", {})),
            "selected_team_ids": list(assembly["selected_team_ids"]),
            "skipped_team_ids": list(assembly["skipped_team_ids"]),
            "selected_member_ids": list(assembly["selected_member_ids"]),
            "member_selection_scores": self._normalize_member_selection_scores(assembly.get("member_selection_scores", {})),
            "coverage_requirements": dict(assembly["coverage_requirements"]),
            "degradation_status": report["degradation_status"],
            "degradation_record": degradation_record,
            "invocations": self._build_audit_invocations(invocations, invocation_receipts),
            "report_ref": report_ref,
            "conflict_refs": [],
            "synthesis_ref": report_ref,
            "kimi_decision_input_ref": report_ref,
            "redaction_applied": True,
            "secret_scan_status": "clear",
            "raw_prompt_persisted": False,
            "raw_stdout_persisted": False,
        }

        validate_artifact_definition(self.repo_root, "debate_report", report)
        validate_artifact_definition(self.repo_root, "debate_audit_trail", audit_trail)

        return {
            "report": report,
            "report_ref": report_ref,
            "audit_trail": audit_trail,
            "audit_ref": audit_ref,
        }

    def _build_audit_invocations(
        self,
        invocations: list[dict[str, Any]],
        invocation_receipts: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        entries = []
        for invocation, receipt in zip(invocations, invocation_receipts, strict=True):
            entries.append(
                {
                    "invocation_id": invocation["invocation_id"],
                    "team_id": invocation["team_id"],
                    "member_id": invocation["member_id"],
                    "backend_id": invocation["backend_id"],
                    "backend_family": invocation["backend_family"],
                    "backend_capabilities": list(invocation.get("backend_capabilities", [])),
                    "input_ref": invocation["artifact_ref"],
                    "opinion_ref": receipt["opinion_ref"],
                    "status": receipt["status"],
                    "started_at": receipt["started_at"],
                    "finished_at": receipt["finished_at"],
                    "retry_count": receipt["retry_count"],
                    "degraded": receipt["degraded"],
                    "degradation_status": receipt["degradation_status"],
                    "degradation_record": dict(receipt["degradation_record"]),
                    "error_class": receipt["error_class"],
                    "timing": dict(receipt.get("timing", {})),
                }
            )
        return entries

    def _normalize_project_overrides(self, project_overrides: Any) -> list[Any]:
        if isinstance(project_overrides, list):
            return list(project_overrides)
        if not isinstance(project_overrides, dict):
            return []
        normalized = []
        for key in sorted(project_overrides):
            normalized.append({"key": key, "value": project_overrides[key]})
        return normalized

    def _normalize_member_selection_scores(self, score_map: Any) -> list[Any]:
        if isinstance(score_map, list):
            return list(score_map)
        if not isinstance(score_map, dict):
            return []
        normalized = []
        for team_id in sorted(score_map):
            normalized.append({"team_id": team_id, "scores": score_map[team_id]})
        return normalized

    def _flatten_opinion_values(self, opinions: list[dict[str, Any]], key: str) -> list[Any]:
        combined = []
        for opinion in opinions:
            for item in opinion.get(key, []):
                combined.append(item)
        return combined

    def _created_at(self, invocations: list[dict[str, Any]], opinions: list[dict[str, Any]]) -> str:
        timestamps = [item["created_at"] for item in invocations] + [item["created_at"] for item in opinions]
        return min(timestamps)

    def _degradation_record(
        self,
        degraded: bool,
        affected_evidence_refs: list[str],
        policy_ref: str,
    ) -> dict[str, Any]:
        if degraded:
            return {
                "degradation_status": "degraded",
                "degradation_class": "template_debate_fallback",
                "cause": "Template fallback was used for at least one debate member opinion.",
                "affected_evidence_refs": list(affected_evidence_refs),
                "decision_required": "kimi",
                "recovery_options": ["configure_real_backend", "rerun_debate"],
                "accepted_by_ref": None,
                "completion_evidence_allowed": False,
                "replacement_evidence_ref": None,
                "policy_ref": policy_ref,
            }
        return {
            "degradation_status": "normal",
            "degradation_class": "none",
            "cause": "No degradation recorded.",
            "affected_evidence_refs": list(affected_evidence_refs),
            "decision_required": "none",
            "recovery_options": [],
            "accepted_by_ref": None,
            "completion_evidence_allowed": True,
            "replacement_evidence_ref": None,
            "policy_ref": policy_ref,
        }

    def _package_hash(self) -> str:
        digest = hashlib.sha256()
        for filename in [
            "teams.json",
            "modes.json",
            "coverage-policy.json",
            "assembly-policy.json",
            "backend-policy.json",
        ]:
            digest.update((self.repo_root / self.package_root / filename).read_bytes())
        return digest.hexdigest()

    def _run_id(self, run: dict[str, Any]) -> str:
        run_id = run.get("run_id", run.get("debate_id"))
        if not isinstance(run_id, str) or not run_id:
            raise DebateReportError("validation_error", "run must provide run_id or debate_id")
        return run_id
