from __future__ import annotations

import fnmatch
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
import uuid


FULL_SCHEMA_VERSION = "orchestra.full.v1"
VALID_SEVERITIES = {"high", "medium", "low"}
VALID_RESOLUTIONS = {"open", "auto_resolved", "accepted_risk", "manual_resolved", "superseded"}
VALID_TYPES = {"intent_vs_inference", "fact_vs_assumption", "cross_team_conflict", "dependency_conflict", "user_override"}
VALID_STAGES = {
    "direction_debate",
    "solution_debate",
    "implementation",
    "improvement",
    "global_evaluation",
    "continuous_improvement",
}


def load_conflict_ledger(path: Path) -> dict[str, Any]:
    """Load conflict ledger from disk. Returns empty ledger if missing."""
    if not path.exists():
        return {"schema_version": FULL_SCHEMA_VERSION, "artifact_type": "conflict_ledger", "run_id": "", "conflicts": []}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"schema_version": FULL_SCHEMA_VERSION, "artifact_type": "conflict_ledger", "run_id": "", "conflicts": []}
    if not isinstance(data, dict):
        return {"schema_version": FULL_SCHEMA_VERSION, "artifact_type": "conflict_ledger", "run_id": "", "conflicts": []}
    return data


def validate_conflict_record(record: dict[str, Any]) -> list[str]:
    """Validate a single conflict record. Returns list of violations."""
    violations = []
    if not isinstance(record.get("conflict_id"), str) or not record["conflict_id"]:
        violations.append("conflict_id missing or empty")
    if not isinstance(record.get("run_id"), str) or not record["run_id"]:
        violations.append("run_id missing or empty")
    severity = record.get("severity")
    if severity not in VALID_SEVERITIES:
        violations.append(f"severity must be one of {sorted(VALID_SEVERITIES)}, got {severity!r}")
    resolution = record.get("resolution")
    if resolution not in VALID_RESOLUTIONS:
        violations.append(f"resolution must be one of {sorted(VALID_RESOLUTIONS)}, got {resolution!r}")
    stage = record.get("stage")
    if stage not in VALID_STAGES:
        violations.append(f"stage must be one of {sorted(VALID_STAGES)}, got {stage!r}")
    conflict_type = record.get("type")
    if conflict_type not in VALID_TYPES:
        violations.append(f"type must be one of {sorted(VALID_TYPES)}, got {conflict_type!r}")
    if not isinstance(record.get("created_at"), str) or not record["created_at"]:
        violations.append("created_at missing or empty")
    if not isinstance(record.get("sources"), list):
        violations.append("sources must be an array")
    if not isinstance(record.get("resolver"), str):
        violations.append("resolver must be a string")
    if not isinstance(record.get("resolution_evidence"), str):
        violations.append("resolution_evidence must be a string")
    resolved_at = record.get("resolved_at")
    if resolved_at is not None and (not isinstance(resolved_at, str) or not resolved_at):
        violations.append("resolved_at must be null or a non-empty string")
    if resolution != "open":
        evidence = record.get("resolution_evidence", "")
        if not isinstance(evidence, str) or not evidence.strip():
            violations.append("resolution_evidence required for resolved conflicts")
    return violations


def append_conflict(ledger_path: Path, conflict: dict[str, Any]) -> dict[str, Any]:
    """Append a conflict record to the ledger. Returns updated ledger."""
    violations = validate_conflict_record(conflict)
    if violations:
        raise ValueError(f"invalid conflict record: {'; '.join(violations)}")
    # Do not silently overwrite a corrupt ledger
    if ledger_path.exists():
        try:
            raw = json.loads(ledger_path.read_text(encoding="utf-8"))
            if not isinstance(raw, dict):
                raise ValueError(f"corrupt conflict ledger at {ledger_path}: not a dict")
        except (OSError, json.JSONDecodeError) as e:
            raise ValueError(f"corrupt conflict ledger at {ledger_path}: {e}")
    ledger = load_conflict_ledger(ledger_path)
    conflicts = ledger.get("conflicts")
    if not isinstance(conflicts, list):
        raise ValueError(f"corrupt conflict ledger at {ledger_path}: conflicts is not a list")
    conflicts.append(conflict)
    ledger["conflicts"] = conflicts
    ledger["schema_version"] = FULL_SCHEMA_VERSION
    ledger["artifact_type"] = "conflict_ledger"
    if not ledger.get("run_id"):
        ledger["run_id"] = conflict.get("run_id", "")
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    ledger_path.write_text(json.dumps(ledger, indent=2, ensure_ascii=False), encoding="utf-8")
    return ledger


def query_open_conflicts(ledger: dict[str, Any]) -> list[dict[str, Any]]:
    """Return all conflicts with resolution=open."""
    conflicts = ledger.get("conflicts")
    if not isinstance(conflicts, list):
        return []
    return [c for c in conflicts if isinstance(c, dict) and c.get("resolution") == "open"]


def query_open_high_conflicts(ledger: dict[str, Any]) -> list[dict[str, Any]]:
    """Return conflicts with resolution=open and severity=high."""
    return [c for c in query_open_conflicts(ledger) if c.get("severity") == "high"]


def query_unjustified_accepted_risk(ledger: dict[str, Any]) -> list[dict[str, Any]]:
    """Return accepted_risk conflicts missing resolver or resolution_evidence."""
    conflicts = ledger.get("conflicts")
    if not isinstance(conflicts, list):
        return []
    results = []
    for c in conflicts:
        if not isinstance(c, dict):
            continue
        if c.get("resolution") != "accepted_risk":
            continue
        resolver = c.get("resolver", "")
        evidence = c.get("resolution_evidence", "")
        if not isinstance(resolver, str) or not resolver.strip():
            results.append(c)
        elif not isinstance(evidence, str) or not evidence.strip():
            results.append(c)
    return results


def resolve_conflict(ledger_path: Path, conflict_id: str, resolution: str, resolver: str = "", resolution_evidence: str = "") -> dict[str, Any]:
    """Resolve a conflict in the ledger. Returns updated ledger."""
    if resolution not in VALID_RESOLUTIONS:
        raise ValueError(f"invalid resolution: {resolution!r}")
    if resolution in ("accepted_risk", "manual_resolved") and not resolver:
        raise ValueError(f"resolution={resolution} requires resolver")
    if resolution in ("accepted_risk", "manual_resolved", "auto_resolved", "superseded") and not resolution_evidence:
        raise ValueError(f"resolution={resolution} requires resolution_evidence")
    ledger = load_conflict_ledger(ledger_path)
    conflicts = ledger.get("conflicts")
    if not isinstance(conflicts, list):
        raise ValueError("ledger has no conflicts list")
    found = False
    now = datetime.now(timezone.utc).isoformat()
    for c in conflicts:
        if isinstance(c, dict) and c.get("conflict_id") == conflict_id:
            c["resolution"] = resolution
            c["resolver"] = resolver
            c["resolution_evidence"] = resolution_evidence
            c["resolved_at"] = now
            found = True
            break
    if not found:
        raise ValueError(f"conflict_id {conflict_id!r} not found in ledger")
    ledger_path.write_text(json.dumps(ledger, indent=2, ensure_ascii=False), encoding="utf-8")
    return ledger


def conflict_counts(ledger: dict[str, Any]) -> dict[str, Any]:
    """Return conflict counts aggregated by severity and resolution."""
    conflicts = ledger.get("conflicts")
    if not isinstance(conflicts, list):
        return {"by_severity": {}, "by_resolution": {}, "total": 0}
    by_severity: dict[str, int] = {}
    by_resolution: dict[str, int] = {}
    total = 0
    for c in conflicts:
        if not isinstance(c, dict):
            continue
        total += 1
        severity = c.get("severity")
        if isinstance(severity, str):
            by_severity[severity] = by_severity.get(severity, 0) + 1
        resolution = c.get("resolution")
        if isinstance(resolution, str):
            by_resolution[resolution] = by_resolution.get(resolution, 0) + 1
    return {"by_severity": by_severity, "by_resolution": by_resolution, "total": total}


def enrich_closeout_report_conflict_counts(closeout_report: dict[str, Any], ledger: dict[str, Any]) -> dict[str, Any]:
    """Inject conflict counts into closeout_report and return it."""
    closeout_report["conflict_counts"] = conflict_counts(ledger)
    return closeout_report


def closeout_conflict_blockers(ledger: dict[str, Any]) -> list[str]:
    """Check conflict ledger for closeout blockers. Returns list of blocker reasons."""
    blockers = []
    open_conflicts = query_open_conflicts(ledger)
    for c in open_conflicts:
        blockers.append(f"open_conflict:{c.get('conflict_id', 'unknown')}")
    unjustified = query_unjustified_accepted_risk(ledger)
    for c in unjustified:
        blockers.append(f"unjustified_accepted_risk:{c.get('conflict_id', 'unknown')}")
    # All resolved conflicts must carry non-empty resolution_evidence
    # Also validate each conflict record against the schema
    conflicts = ledger.get("conflicts")
    if isinstance(conflicts, list):
        for c in conflicts:
            if not isinstance(c, dict):
                blockers.append("schema_invalid_conflict:not_a_dict")
                continue
            resolution = c.get("resolution")
            if resolution != "open":
                evidence = c.get("resolution_evidence", "")
                if not isinstance(evidence, str) or not evidence.strip():
                    blockers.append(f"missing_resolution_evidence:{c.get('conflict_id', 'unknown')}")
            violations = validate_conflict_record(c)
            for v in violations:
                blockers.append(f"schema_invalid_conflict:{c.get('conflict_id', 'unknown')}:{v}")
    return sorted(set(blockers))


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
        _conflict_ledger_check(run_dir),
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
        "non_empty": bool(refs),
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


def _conflict_ledger_check(run_dir: Path) -> dict[str, Any]:
    ledger_path = run_dir / "conflict-ledger.json"
    if ledger_path.exists():
        try:
            raw = json.loads(ledger_path.read_text(encoding="utf-8"))
            if not isinstance(raw, dict):
                return {
                    "id": "conflict_ledger",
                    "category": "conflict_ledger",
                    "exists": True,
                    "non_empty": False,
                    "passed": False,
                    "blockers": ["unreadable_conflict_ledger:invalid_structure"],
                }
        except (OSError, json.JSONDecodeError):
            return {
                "id": "conflict_ledger",
                "category": "conflict_ledger",
                "exists": True,
                "non_empty": False,
                "passed": False,
                "blockers": ["unreadable_conflict_ledger:json_decode_error"],
            }
    ledger = load_conflict_ledger(ledger_path)
    blockers = closeout_conflict_blockers(ledger)
    return {
        "id": "conflict_ledger",
        "category": "conflict_ledger",
        "exists": ledger_path.exists(),
        "non_empty": True,
        "passed": len(blockers) == 0,
        "blockers": blockers,
    }


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
