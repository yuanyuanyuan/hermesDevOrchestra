"""Global evaluation scoring and routing helpers."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


DIMENSION_NAMES = [
    "业务目标",
    "补全正确性",
    "安全合规",
    "质量",
    "性能",
    "可维护性",
    "文档",
    "可观测性",
]

SEVERITY_RANK = {"high": 0, "medium": 1, "low": 2}


def load_policy(repo_root: Path) -> dict[str, Any]:
    path = repo_root / "config" / "debate" / "full" / "coverage-policy.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        data = {}
    stage = data.get("stage_requirements", {}).get("global_evaluation", {})
    return {
        "warning_trigger_min_score": int(stage.get("warning_trigger_min_score", 3)),
        "warning_trigger_any_below": int(stage.get("warning_trigger_any_below", 5)),
    }


def normalize_global_evaluation(report: dict[str, Any], run_id: str, repo_root: Path) -> dict[str, Any]:
    normalized = dict(report)
    policy = load_policy(repo_root)
    dimensions = _normalize_dimensions(normalized, run_id)
    normalized["dimensions"] = dimensions
    normalized["residual_risks"] = _sorted_residual_risks(normalized.get("residual_risks", []))
    normalized["mode_refs"] = _mode_refs(normalized)
    normalized["trigger_events"] = _trigger_events(normalized)
    normalized["notification_level"] = _notification_level(normalized)
    normalized["verdict"] = _verdict(normalized.get("verdict"), dimensions, policy, normalized)
    normalized["authority_route"] = _authority_route(normalized)
    normalized["notification"] = _notification(normalized)
    return normalized


def append_side_events(app: Any, run_id: str, report: dict[str, Any], command_id: str, idempotency_key: str, report_ref: str, audit_ref: str, now: str, event_schema_version: str) -> list[str]:
    refs = []
    for trigger in report.get("trigger_events", []):
        if not isinstance(trigger, dict):
            continue
        event_ref = app.append_event(
            run_id,
            {
                "schema_version": event_schema_version,
                "seq": app.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "global_evaluation",
                "type": trigger.get("type"),
                "severity": "warning",
                "status": "recorded",
                "message": trigger.get("reason", "Global evaluation mode triggered"),
                "artifact_refs": [report_ref, audit_ref],
                "decision_id": None,
            },
        )
        if event_ref:
            refs.append(event_ref)

    notification = report.get("notification") if isinstance(report.get("notification"), dict) else {}
    if notification.get("level") == "none":
        _append_jsonl(
            app.store.audit_path(),
            {
                "timestamp": now,
                "level": "L1",
                "project": app.store.project_id,
                "type": "notification_suppressed",
                "decision": "RECORDED",
                "user_decision": "",
                "details": "Global evaluation notification suppressed by notification_level=none",
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
        return refs

    if notification.get("sent"):
        event_ref = app.append_event(
            run_id,
            {
                "schema_version": event_schema_version,
                "seq": app.next_event_seq(run_id),
                "timestamp": now,
                "command_id": command_id,
                "idempotency_key": idempotency_key,
                "run_id": run_id,
                "task_id": None,
                "stage": "global_evaluation",
                "type": "user_notification",
                "severity": "info",
                "status": "sent",
                "message": json.dumps(notification.get("body"), ensure_ascii=False, sort_keys=True),
                "artifact_refs": [report_ref, audit_ref],
                "decision_id": None,
            },
        )
        if event_ref:
            refs.append(event_ref)
    return refs


def _append_jsonl(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        json.dump(record, handle, ensure_ascii=False)
        handle.write("\n")


def _normalize_dimensions(report: dict[str, Any], run_id: str) -> list[dict[str, Any]]:
    supplied = report.get("dimensions")
    by_name = {item.get("name"): item for item in supplied if isinstance(item, dict)} if isinstance(supplied, list) else {}
    fallback_refs = _fallback_evidence_refs(report, run_id)
    dimensions = []
    for name in DIMENSION_NAMES:
        raw = by_name.get(name, {})
        score = raw.get("score", 10 if report.get("verdict") in {None, "pass"} else 5)
        if not isinstance(score, int) or score < 0 or score > 10:
            raise ValueError(f"dimension {name} score must be an integer from 0 to 10")
        rationale = raw.get("rationale") or f"{name} scored from submitted Stage 0-4 evidence"
        evidence_refs = raw.get("evidence_refs") if isinstance(raw.get("evidence_refs"), list) else fallback_refs
        evidence_refs = [ref for ref in evidence_refs if isinstance(ref, str) and ref]
        if not evidence_refs:
            evidence_refs = fallback_refs
        dimensions.append({"name": name, "score": score, "rationale": rationale, "evidence_refs": evidence_refs})
    return dimensions


def _fallback_evidence_refs(report: dict[str, Any], run_id: str) -> list[str]:
    for key in ("test_execution_refs", "implementation_evidence_refs", "review_verdict_refs", "input_artifact_refs"):
        refs = report.get(key)
        if isinstance(refs, list):
            values = [ref for ref in refs if isinstance(ref, str) and ref]
            if values:
                return values
    return [f"state://runs/{run_id}/run.json"]


def _verdict(submitted: Any, dimensions: list[dict[str, Any]], policy: dict[str, Any], report: dict[str, Any]) -> str:
    scores = [item["score"] for item in dimensions]
    if report.get("blocking_issues"):
        return "block" if submitted == "block" else "fail"
    if any(score < policy["warning_trigger_min_score"] for score in scores):
        return "fail"
    if any(score < policy["warning_trigger_any_below"] for score in scores):
        return "pass_with_warnings"
    return submitted if submitted in {"pass", "pass_with_warnings", "fail", "block"} else "pass"


def _sorted_residual_risks(raw: Any) -> list[Any]:
    if not isinstance(raw, list):
        return []
    return sorted(raw, key=lambda item: SEVERITY_RANK.get(item.get("severity", "medium"), 1) if isinstance(item, dict) else 1)


def _mode_refs(report: dict[str, Any]) -> list[str]:
    refs = []
    if _jury_required(report):
        refs.append("jury_panel")
    if _meta_review_required(report):
        refs.append("meta_review")
    if _conflict_required(report):
        refs.append("cross_team_conflict_detector")
    return refs


def _trigger_events(report: dict[str, Any]) -> list[dict[str, str]]:
    events = []
    if _jury_required(report):
        events.append({"type": "jury_panel_triggered", "reason": "dimension score disagreement >= 3 or unresolved E-class dispute"})
    if _meta_review_required(report):
        events.append({"type": "meta_review_triggered", "reason": "cross-team impact >= 2 or protected target changed"})
    if _conflict_required(report):
        events.append({"type": "cross_team_conflict_triggered", "reason": "opposite conclusions for the same file across teams"})
    elif isinstance(report.get("review_records"), list):
        report["detector_skipped"] = {"detector": "cross_team_conflict_detector", "reason": "no opposite same-file team conclusions"}
    return events


def _jury_required(report: dict[str, Any]) -> bool:
    scores = report.get("evaluator_scores")
    if isinstance(scores, dict):
        for values in scores.values():
            if isinstance(values, list):
                ints = [value for value in values if isinstance(value, int)]
                if ints and max(ints) - min(ints) >= 3:
                    return True
    return bool(report.get("unresolved_e_dispute"))


def _meta_review_required(report: dict[str, Any]) -> bool:
    teams = report.get("affected_teams")
    protected = report.get("protected_targets_changed")
    return (isinstance(teams, list) and len(set(teams)) >= 2) or bool(protected)


def _conflict_required(report: dict[str, Any]) -> bool:
    seen: dict[tuple[str, str], set[str]] = {}
    records = report.get("review_records")
    if not isinstance(records, list):
        return False
    for record in records:
        if not isinstance(record, dict):
            continue
        file_path = record.get("file")
        team = record.get("team")
        conclusion = record.get("conclusion")
        if not all(isinstance(value, str) and value for value in (file_path, team, conclusion)):
            continue
        key = (file_path, team)
        seen.setdefault(key, set()).add(conclusion)
        file_conclusions = {value for (path, _), values in seen.items() if path == file_path for value in values}
        if {"approve", "reject"}.issubset(file_conclusions):
            return True
    return False


def _notification_level(report: dict[str, Any]) -> str:
    level = report.get("notification_level") or report.get("warning_notification") or "summary"
    return level if level in {"none", "summary", "full"} else "summary"


def _authority_route(report: dict[str, Any]) -> dict[str, Any]:
    verdict = report["verdict"]
    risks = report.get("residual_risks", [])
    high_risk = any(isinstance(risk, dict) and risk.get("severity") == "high" for risk in risks)
    if verdict == "fail":
        return {"next_stage": "improvement", "required_approvers": [], "block_reason": "dimension_score_below_minimum"}
    if verdict == "block":
        return {"next_stage": "approval_required", "required_approvers": ["human"], "block_reason": "global_evaluation_blocked"}
    if high_risk and report.get("change_level") == "L4":
        report["verdict"] = "pass_with_warnings"
        return {"next_stage": "approval_required", "required_approvers": ["human", "kimi"], "block_reason": "acceptance_required"}
    if verdict == "pass_with_warnings":
        return {"next_stage": "approval_required", "required_approvers": ["kimi"], "block_reason": "residual_risks_require_acceptance"}
    return {"next_stage": "closeout", "required_approvers": [], "block_reason": None}


def _notification(report: dict[str, Any]) -> dict[str, Any]:
    level = report["notification_level"]
    risks = report.get("residual_risks", [])
    counts = {"high": 0, "medium": 0, "low": 0}
    highest = None
    for risk in risks:
        if isinstance(risk, dict):
            severity = risk.get("severity", "medium")
            if severity in counts:
                counts[severity] += 1
            if highest is None:
                highest = risk.get("title") or risk.get("summary")
    if level == "none":
        return {"level": level, "sent": False, "body": ""}
    if level == "summary":
        return {"level": level, "sent": True, "body": {"verdict": report["verdict"], "risk_counts": counts, "highest_risk": highest}}
    return {
        "level": level,
        "sent": True,
        "body": {
            "verdict": report["verdict"],
            "dimensions": report["dimensions"],
            "residual_risks": risks,
            "authority_route": report["authority_route"],
        },
    }
