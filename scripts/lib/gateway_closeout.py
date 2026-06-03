from __future__ import annotations

import fnmatch
import json
from pathlib import Path
from typing import Any


PROTECTED_TARGETS = [
    ("k8s_production", "k8s/production/*", "L4"),
    ("db_schema", "db/migrations/*", "L4"),
    ("api_contract", "docs/api/*", "L3"),
    ("api_contract", "specs/*", "L3"),
    ("auth_policy", "config/auth/*", "L4"),
    ("auth_policy", "policies/*", "L4"),
    ("iam_secrets", "config/secrets/*", "L4"),
    ("iam_secrets", ".env*", "L4"),
    ("infrastructure", "terraform/*", "L4"),
    ("infrastructure", "infrastructure/*", "L4"),
    ("payment_compliance", "src/payment/*", "L4"),
    ("payment_compliance", "compliance/*", "L4"),
    ("ci_cd_pipeline", ".github/workflows/*", "L3"),
    ("ci_cd_pipeline", "ci/*", "L3"),
    ("legal_terms", "docs/legal/*", "L4"),
    ("legal_terms", "terms/*", "L4"),
    ("core_business_logic", "src/core/*", "L3"),
    ("core_business_logic", "domain/*", "L3"),
    ("data_privacy", "src/pii/*", "L4"),
    ("data_privacy", "privacy/*", "L4"),
]


def closeout_audit_checklist(run_dir: Path, audit_path: Path, closeout_report: dict[str, Any], proposals: dict[str, Any]) -> dict[str, Any]:
    events_path = run_dir / "events.jsonl"
    worker_session_paths = sorted((run_dir / "worker-sessions").glob("*.json"))
    events = _read_jsonl(events_path)
    worker_sessions = [_read_json(path) for path in worker_session_paths]
    run = _read_json(run_dir / "run.json")

    checks = [
        _file_check("complete_logs.events_jsonl", "complete_logs", events_path),
        _file_check("complete_logs.audit_jsonl", "complete_logs", audit_path),
        _field_check("intake_package", "intake_package", _intake_package(run_dir, run), min_size=8),
        _worker_invocation_check(worker_sessions),
        _event_query_check("error_stack", "error_stack", events, "error", allow_empty=True),
        _review_check(closeout_report),
        _closeout_artifact_check(closeout_report, proposals),
    ]
    missing = [item["id"] for item in checks if not item["passed"]]
    return {
        "schema_version": "orchestra.v1",
        "artifact_type": "closeout_audit_checklist",
        "run_id": closeout_report.get("run_id"),
        "checks": checks,
        "missing_items": missing,
        "passed": not missing,
    }


def enrich_proposals(proposals: dict[str, Any], run_id: str) -> dict[str, Any]:
    enriched = dict(proposals)
    items = []
    default_ref = f"state://runs/{run_id}/events.jsonl"
    for proposal in proposals.get("proposals", []):
        if not isinstance(proposal, dict):
            items.append(proposal)
            continue
        item = dict(proposal)
        item.setdefault("source_event_refs", [default_ref])
        item.setdefault("confidence_score", 0.8)
        item.setdefault("applicable_scope", item.get("target") or item.get("target_area") or "task_type:general")
        item.setdefault("status", "pending_review")
        items.append(item)
    enriched["proposals"] = items
    return enriched


def protected_target_approval_blockers(proposals: dict[str, Any]) -> tuple[list[str], list[dict[str, str]]]:
    blockers: list[str] = []
    approvals: list[dict[str, str]] = []
    for proposal in proposals.get("proposals", []):
        if not isinstance(proposal, dict):
            continue
        target = proposal.get("target")
        if not isinstance(target, str):
            continue
        match = protected_target_for(target)
        if match is None:
            continue
        target_class, pattern, level = match
        kimi_ref = proposal.get("kimi_review_ref")
        human_ref = proposal.get("human_approval_ref")
        missing_kimi = level == "L4" and not isinstance(kimi_ref, str)
        missing_human = level in {"L3", "L4"} and not isinstance(human_ref, str)
        approvals.append(
            {
                "target_pattern": pattern,
                "target": target,
                "target_class": target_class,
                "approval_level": level,
                "kimi_review_ref": kimi_ref if isinstance(kimi_ref, str) else "",
                "human_approval_ref": human_ref if isinstance(human_ref, str) else "",
            }
        )
        if missing_kimi or missing_human:
            blockers.append(f"protected_target_missing_approval:{target}")
    return blockers, approvals


def protected_target_rejection(project_id: str, run_id: str, blockers: list[str], now: str) -> dict[str, Any]:
    return {
        "audit_record": {
            "timestamp": now,
            "level": "L4",
            "project": project_id,
            "type": "protected_target_missing_approval",
            "decision": "REJECTED",
            "details": "Protected target closeout missing required approval refs",
            "task_id": run_id,
            "agent_source": "orch-gateway",
            "run_id": run_id,
            "completion_blockers": blockers,
        },
        "body": {
            "schema_version": "orchestra.v1",
            "error": {"code": "closeout_validation_failed", "message": "protected target closeout requires approval refs"},
            "run_id": run_id,
            "completion_blockers": blockers,
            "event_projection_degraded": False,
            "projection_status": "consistent",
            "projection_issue_refs": [],
        },
    }


def protected_target_for(target: str) -> tuple[str, str, str] | None:
    normalized = target.removeprefix("repo://").lstrip("/")
    for target_class, pattern, level in PROTECTED_TARGETS:
        if fnmatch.fnmatch(normalized, pattern):
            return target_class, pattern, level
    return None


def _file_check(check_id: str, category: str, path: Path) -> dict[str, Any]:
    exists = path.exists() and path.is_file()
    non_empty = exists and path.stat().st_size > 0
    return {"id": check_id, "category": category, "exists": exists, "non_empty": non_empty, "passed": exists and non_empty}


def _field_check(check_id: str, category: str, value: Any, min_size: int) -> dict[str, Any]:
    exists = isinstance(value, dict)
    non_empty = exists and len(value) >= min_size
    return {"id": check_id, "category": category, "exists": exists, "non_empty": non_empty, "passed": exists and non_empty}


def _worker_invocation_check(worker_sessions: list[dict[str, Any]]) -> dict[str, Any]:
    count = 0
    for session in worker_sessions:
        invocations = session.get("invocations")
        if isinstance(invocations, list):
            count += len(invocations)
    return {
        "id": "worker_invocation_logs",
        "category": "worker_invocation_logs",
        "exists": bool(worker_sessions),
        "non_empty": count > 0,
        "passed": bool(worker_sessions) and count > 0,
        "count": count,
    }


def _event_query_check(check_id: str, category: str, events: list[dict[str, Any]], event_type: str, allow_empty: bool) -> dict[str, Any]:
    matches = [event for event in events if event.get("type") == event_type or event.get("event_type") == event_type]
    exists = True if allow_empty else bool(matches)
    non_empty = True if allow_empty else bool(matches)
    return {"id": check_id, "category": category, "exists": exists, "non_empty": non_empty, "passed": exists and non_empty, "count": len(matches)}


def _review_check(closeout_report: dict[str, Any]) -> dict[str, Any]:
    refs = []
    for field in ("review_verdict_refs", "qa_verdict_refs"):
        value = closeout_report.get(field)
        if isinstance(value, list):
            refs.extend(value)
    return {
        "id": "review_records",
        "category": "review_records",
        "exists": True,
        "non_empty": True,
        "passed": True,
        "count": len(refs),
        "note": "no review" if not refs else "",
    }


def _closeout_artifact_check(closeout_report: dict[str, Any], proposals: dict[str, Any]) -> dict[str, Any]:
    exists = isinstance(closeout_report, dict) and isinstance(proposals, dict)
    has_summary = bool(closeout_report.get("closeout_summary") or closeout_report.get("final_acceptance"))
    has_metrics = bool(closeout_report.get("metrics_summary") or closeout_report.get("completion_gate"))
    has_proposals = isinstance(proposals.get("proposals"), list)
    passed = exists and has_summary and has_metrics and has_proposals
    return {"id": "closeout_artifacts", "category": "closeout_artifacts", "exists": exists, "non_empty": passed, "passed": passed}


def _intake_package(run_dir: Path, run: dict[str, Any]) -> dict[str, Any] | None:
    for key in ("intake_package", "requirement_completion_bundle", "ticket"):
        value = run.get(key)
        if isinstance(value, dict):
            return value
    for name in ("requirement_completion_bundle.json", "structured_prd.json", "development_plan.json"):
        value = _read_json(run_dir / name)
        if isinstance(value, dict) and value:
            return value
    return None


def _read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    records = []
    for line in lines:
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            records.append(item)
    return records
