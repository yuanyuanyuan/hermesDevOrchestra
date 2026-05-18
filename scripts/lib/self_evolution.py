from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from debate_report import DebateReportError, validate_artifact_definition


_TRIGGER_MATCHES = {
    "authority_chain_divergence",
    "worker_session_cleanup_failure",
    "schema_mismatch",
    "full_contract_validation_failure",
    "debate_required_coverage_failure",
    "debate_degraded_required_evidence",
    "same_failure_class_repeated",
    "review_or_qa_same_class_repeated",
    "decision_exposed_rule_or_doc_gap",
}
_SEVERITY_LEVELS = {"critical": 4, "high": 3, "medium": 2, "low": 1}
_EVIDENCE_QUALITY = {"high": 3, "medium": 2, "low": 1}
_PROPOSAL_REF_PATTERN = re.compile(r"[^A-Za-z0-9._-]+")


class SelfEvolutionError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class SelfEvolutionQueue:
    def __init__(
        self,
        repo_root: Path | str,
        package_root: str = "config/evolution",
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

        data = self._load_json("self-evolution-review-queue.json")
        self._validate_definition("self_evolution_review_queue_policy", data)
        package_status = data.get("package_status")
        if not isinstance(package_status, str) or not package_status:
            raise SelfEvolutionError("config_invalid", "self-evolution-review-queue.json is missing package_status")
        if package_status != "active" and not self.allow_staged:
            raise SelfEvolutionError(
                "module_disabled",
                "self-evolution-review-queue.json is staged; allow_staged=True is required",
            )

        self._policy = data
        return self._policy

    def generate_stage6_sweep(
        self,
        *,
        run_id: str,
        source_refs: list[str],
        proposals: list[dict[str, Any]],
        trigger_matches: list[str],
    ) -> dict[str, Any]:
        return self._build_proposals_artifact(
            run_id=run_id,
            trigger_type="stage_6_candidate_sweep",
            source_scope="single_run",
            source_run_ids=[run_id],
            source_refs=source_refs,
            proposals=proposals,
            trigger_matches=trigger_matches,
        )

    def generate_cross_run_review(
        self,
        *,
        run_id: str,
        source_run_ids: list[str],
        source_refs: list[str],
        proposals: list[dict[str, Any]],
        trigger_matches: list[str],
    ) -> dict[str, Any]:
        return self._build_proposals_artifact(
            run_id=run_id,
            trigger_type="manual_cross_run_review",
            source_scope="cross_run",
            source_run_ids=source_run_ids,
            source_refs=source_refs,
            proposals=proposals,
            trigger_matches=trigger_matches,
        )

    def enqueue(self, proposal: dict[str, Any]) -> dict[str, Any]:
        policy = self.load_policy()
        if not isinstance(proposal, dict):
            raise SelfEvolutionError("validation_error", "proposal artifact must be an object")
        self._validate_definition("system_improvement_proposals", proposal)

        if proposal.get("candidate_only") is not True or proposal.get("review_queue_required") is not True:
            raise SelfEvolutionError("queue_bypass_forbidden", "self evolution proposals must remain candidate-only and queue-bound")
        if proposal.get("auto_applied_refs"):
            raise SelfEvolutionError("queue_bypass_forbidden", "self evolution proposals cannot auto-apply changes")

        queue_items: list[dict[str, Any]] = []
        proposal_refs: list[str] = []
        for proposal_item in proposal.get("proposals", []):
            if proposal_item.get("queue_bypass_requested") is True:
                raise SelfEvolutionError("queue_bypass_forbidden", "queue bypass is forbidden for self evolution proposals")
            if proposal_item.get("auto_apply_requested") is True:
                raise SelfEvolutionError("queue_bypass_forbidden", "auto-apply is forbidden for self evolution proposals")
            queue_item = self._build_queue_item(policy, proposal, proposal_item)
            queue_items.append(queue_item)
            proposal_refs.append(str(queue_item["proposal_ref"]))

        proposal["queued_item_refs"] = proposal_refs
        return {"proposals_artifact": proposal, "queue_items": queue_items}

    def transition(
        self,
        queue_item: dict[str, Any],
        next_status: str,
        *,
        decision_ref: str | None = None,
        rejection_reason: str | None = None,
        kimi_review_ref: str | None = None,
        human_approval_ref: str | None = None,
    ) -> dict[str, Any]:
        policy = self.load_policy()
        self._validate_queue_item_shape(policy, queue_item)
        if not isinstance(next_status, str) or not next_status:
            raise SelfEvolutionError("validation_error", "next_status must be a non-empty string")

        allowed_transitions = {
            (entry["from"], entry["to"])
            for entry in policy["status_machine"]["transitions"]
            if isinstance(entry, dict) and isinstance(entry.get("from"), str) and isinstance(entry.get("to"), str)
        }
        current_status = str(queue_item["status"])
        if (current_status, next_status) not in allowed_transitions:
            raise SelfEvolutionError("transition_invalid", f"invalid queue transition: {current_status} -> {next_status}")

        if current_status == "under_review" and next_status in {"accepted", "rejected", "needs_more_evidence", "deferred"} and not decision_ref:
            raise SelfEvolutionError("transition_invalid", "decision_ref is required for review outcomes")
        if next_status == "rejected" and not rejection_reason:
            raise SelfEvolutionError("transition_invalid", "rejection_reason is required for rejected items")
        if queue_item.get("human_approval_required") and next_status in {"accepted", "applied"}:
            if not kimi_review_ref or not human_approval_ref:
                raise SelfEvolutionError(
                    "transition_invalid",
                    "protected target proposals require both kimi_review_ref and human_approval_ref",
                )

        updated = dict(queue_item)
        updated["status"] = next_status
        if decision_ref is not None:
            updated["decision_ref"] = decision_ref
        if rejection_reason is not None:
            updated["rejection_reason"] = rejection_reason
        if next_status in {"accepted", "rejected", "needs_more_evidence", "deferred", "applied", "superseded"}:
            updated["reviewed_at"] = self._timestamp()
        if kimi_review_ref is not None:
            updated["kimi_review_ref"] = kimi_review_ref
        if human_approval_ref is not None:
            updated["human_approval_ref"] = human_approval_ref
        if decision_ref is not None and decision_ref not in updated["audit_refs"]:
            updated["audit_refs"] = [*updated["audit_refs"], decision_ref]
        return updated

    def list_pending(self, queue_items: list[dict[str, Any]] | None = None) -> list[dict[str, Any]]:
        policy = self.load_policy()
        if queue_items is None:
            return []
        if not isinstance(queue_items, list):
            raise SelfEvolutionError("validation_error", "queue_items must be a list")

        terminal_states = set(policy["status_machine"]["terminal_states"])
        pending = []
        for queue_item in queue_items:
            self._validate_queue_item_shape(policy, queue_item)
            if queue_item["status"] not in terminal_states:
                pending.append(queue_item)
        return sorted(
            pending,
            key=lambda item: (
                0 if item["protected_target_class"] != "none" else 1,
                -int(item["priority_score"]),
                str(item["created_at"]),
            ),
        )

    def _build_proposals_artifact(
        self,
        *,
        run_id: str,
        trigger_type: str,
        source_scope: str,
        source_run_ids: list[str],
        source_refs: list[str],
        proposals: list[dict[str, Any]],
        trigger_matches: list[str],
    ) -> dict[str, Any]:
        policy = self.load_policy()
        self._require_string(run_id, "run_id")
        self._require_string_list(source_refs, "source_refs")
        self._require_string_list(source_run_ids, "source_run_ids")
        if not isinstance(proposals, list):
            raise SelfEvolutionError("validation_error", "proposals must be a list")
        self._validate_trigger_matches(trigger_matches, bool(proposals))

        normalized_proposals = [self._normalize_proposal(policy, proposal) for proposal in proposals]
        queued_item_refs = [
            self._queue_item_ref(run_id, str(proposal["proposal_id"]))
            for proposal in normalized_proposals
        ]
        approval_required = [
            str(proposal["proposal_id"])
            for proposal in normalized_proposals
            if proposal["target_class"] in set(policy["protected_target_policy"]["protected_target_classes"])
        ]
        artifact = {
            "schema_version": "orchestra.full.v1",
            "artifact_type": "system_improvement_proposals",
            "run_id": run_id,
            "trigger_type": trigger_type,
            "source_scope": source_scope,
            "source_run_ids": list(source_run_ids),
            "generated_at": self._timestamp(),
            "candidate_only": True,
            "review_queue_required": True,
            "review_queue_policy_ref": "config://evolution/self-evolution-review-queue",
            "queued_item_refs": queued_item_refs,
            "trigger_matches": list(trigger_matches),
            "source_refs": list(source_refs),
            "proposals": normalized_proposals,
            "auto_applied_refs": [],
            "approval_required": approval_required,
        }
        self._validate_definition("system_improvement_proposals", artifact)
        return artifact

    def _normalize_proposal(self, policy: dict[str, Any], proposal: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(proposal, dict):
            raise SelfEvolutionError("proposal_invalid", "each proposal must be an object")

        normalized = dict(proposal)
        for key in ["proposal_id", "target_class", "target", "target_area", "summary", "rationale", "severity", "evidence_quality"]:
            self._require_string(normalized.get(key), key)
        self._require_string_list(normalized.get("source_run_ids"), "proposal.source_run_ids")
        self._require_string_list(normalized.get("artifact_refs"), "proposal.artifact_refs")

        if normalized["severity"] not in _SEVERITY_LEVELS:
            raise SelfEvolutionError("proposal_invalid", f"invalid proposal severity: {normalized['severity']}")
        if normalized["evidence_quality"] not in _EVIDENCE_QUALITY:
            raise SelfEvolutionError("proposal_invalid", f"invalid evidence_quality: {normalized['evidence_quality']}")

        for numeric_key in ["repeated_failure_count", "source_run_count"]:
            value = normalized.get(numeric_key)
            if not isinstance(value, int) or value < 0:
                raise SelfEvolutionError("proposal_invalid", f"{numeric_key} must be an integer >= 0")
        if normalized["source_run_count"] < 1:
            raise SelfEvolutionError("proposal_invalid", "source_run_count must be >= 1")

        protected_targets = set(policy["protected_target_policy"]["protected_target_classes"])
        if normalized["target_class"] in protected_targets:
            if not isinstance(normalized.get("proposed_patch_ref"), str) or not normalized.get("proposed_patch_ref"):
                raise SelfEvolutionError("proposal_invalid", "protected target proposals require proposed_patch_ref")
            if not isinstance(normalized.get("approval_impact"), str) or not normalized.get("approval_impact"):
                raise SelfEvolutionError("proposal_invalid", "protected target proposals require approval_impact")
        return normalized

    def _build_queue_item(self, policy: dict[str, Any], artifact: dict[str, Any], proposal: dict[str, Any]) -> dict[str, Any]:
        protected_targets = set(policy["protected_target_policy"]["protected_target_classes"])
        is_protected = proposal["target_class"] in protected_targets
        queue_item_id = self._queue_item_id(str(proposal["proposal_id"]))
        protected_target_class = proposal["target_class"] if is_protected else "none"
        batch_key = None
        if not is_protected and proposal["severity"] in {"low", "medium"} and artifact["trigger_matches"]:
            batch_key = f"{artifact['trigger_matches'][0]}|{proposal['target_area']}|{protected_target_class}"

        queue_item = {
            "queue_item_id": queue_item_id,
            "proposal_id": proposal["proposal_id"],
            "proposal_ref": self._queue_item_ref(str(artifact["run_id"]), str(proposal["proposal_id"])),
            "source_run_ids": list(proposal["source_run_ids"]),
            "trigger_matches": list(artifact["trigger_matches"]),
            "severity": proposal["severity"],
            "protected_target_class": protected_target_class,
            "evidence_quality": proposal["evidence_quality"],
            "priority_score": self._priority_score(policy, artifact["trigger_matches"], proposal, is_protected),
            "status": "queued",
            "decision_required": "human" if is_protected else "kimi",
            "human_approval_required": is_protected,
            "kimi_review_required": is_protected,
            "batch_key": batch_key,
            "created_at": artifact["generated_at"],
            "reviewed_at": None,
            "decision_ref": None,
            "rejection_reason": None,
            "audit_refs": [*artifact["source_refs"], *proposal["artifact_refs"]],
        }
        self._validate_queue_item_shape(policy, queue_item)
        return queue_item

    def _priority_score(
        self,
        policy: dict[str, Any],
        trigger_matches: list[str],
        proposal: dict[str, Any],
        is_protected: bool,
    ) -> int:
        priority_policy = policy["priority_policy"]
        score = 0
        if is_protected and priority_policy.get("protected_targets_first") is True:
            score += 1000
        score += _SEVERITY_LEVELS[proposal["severity"]] * 100
        score += int(proposal["repeated_failure_count"]) * int(priority_policy["same_class_failure_weight"])
        score += int(proposal["source_run_count"])
        if "decision_exposed_rule_or_doc_gap" in trigger_matches:
            score += int(priority_policy["decision_exposed_gap_weight"])
        if {"schema_mismatch", "full_contract_validation_failure"} & set(trigger_matches):
            score += int(priority_policy["schema_or_contract_failure_weight"])
        if "review_or_qa_same_class_repeated" in trigger_matches:
            score += int(priority_policy["review_or_qa_repeat_weight"])
        if proposal["evidence_quality"] == "low":
            score -= int(priority_policy["low_evidence_penalty"])
        return score

    def _validate_trigger_matches(self, trigger_matches: list[str], proposals_present: bool) -> None:
        if not isinstance(trigger_matches, list) or not all(isinstance(item, str) and item for item in trigger_matches):
            raise SelfEvolutionError("validation_error", "trigger_matches must be a list of non-empty strings")
        unknown = [item for item in trigger_matches if item not in _TRIGGER_MATCHES]
        if unknown:
            raise SelfEvolutionError("validation_error", f"unknown trigger matches: {unknown}")
        if proposals_present and not trigger_matches:
            raise SelfEvolutionError("trigger_required", "non-empty proposals require at least one trigger match")

    def _validate_queue_item_shape(self, policy: dict[str, Any], queue_item: dict[str, Any]) -> None:
        if not isinstance(queue_item, dict):
            raise SelfEvolutionError("validation_error", "queue item must be an object")
        required_fields = policy["queue_item_required_fields"]
        missing = [field for field in required_fields if field not in queue_item]
        if missing:
            raise SelfEvolutionError("validation_error", f"queue item is missing fields: {missing}")

    def _queue_item_id(self, proposal_id: str) -> str:
        safe = _PROPOSAL_REF_PATTERN.sub("-", proposal_id).strip("-") or "proposal"
        return f"queue-{safe}"

    def _queue_item_ref(self, run_id: str, proposal_id: str) -> str:
        return f"state://runs/{run_id}/review-queue/{self._queue_item_id(proposal_id)}.json"

    def _load_json(self, filename: str) -> dict[str, Any]:
        path = self.repo_root / self.package_root / filename
        try:
            with path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except json.JSONDecodeError as exc:
            raise SelfEvolutionError("config_invalid", f"{filename} is not valid JSON: {exc.msg}") from exc
        except FileNotFoundError as exc:
            raise SelfEvolutionError("config_invalid", f"{filename} is missing") from exc
        if not isinstance(data, dict):
            raise SelfEvolutionError("config_invalid", f"{filename} must contain a JSON object")
        return data

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise SelfEvolutionError("module_disabled", "self evolution queue is disabled")

    def _require_string(self, value: Any, label: str) -> None:
        if not isinstance(value, str) or not value:
            raise SelfEvolutionError("validation_error", f"{label} must be a non-empty string")

    def _require_string_list(self, value: Any, label: str) -> None:
        if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
            raise SelfEvolutionError("validation_error", f"{label} must be a list of non-empty strings")

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _validate_definition(self, definition_name: str, artifact: dict[str, Any]) -> None:
        try:
            validate_artifact_definition(self.repo_root, definition_name, artifact)
        except DebateReportError as exc:
            code = "proposal_invalid" if definition_name == "system_improvement_proposals" else "config_invalid"
            raise SelfEvolutionError(code, exc.message) from exc
