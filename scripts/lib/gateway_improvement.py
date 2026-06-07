"""Stage 4 improvement classification and routing helpers."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from typing import Any
import uuid

from atomic_writer import AtomicWriter
from e_class_mini_debate import get_e_class_config


CLASSIFICATION_TABLE: dict[str, dict[str, str]] = {
    "A": {
        "name": "format_style",
        "criterion": "lint/format can be automatically fixed",
        "action": "auto_fix_and_retest",
        "escalation": "none",
    },
    "B": {
        "name": "simple_logic_error",
        "criterion": "unit test failed and the fault is localized",
        "action": "auto_fix_and_retest",
        "escalation": "human_after_two_failures",
    },
    "C": {
        "name": "missing_boundary_condition",
        "criterion": "boundary test failed",
        "action": "auto_fix_add_boundary_case_and_retest",
        "escalation": "human_after_two_failures",
    },
    "D": {
        "name": "architecture_design_defect",
        "criterion": "multi-module impact requiring redesign or refactor",
        "action": "mini_debate_then_fix",
        "escalation": "decision_after_three_failures",
    },
    "E": {
        "name": "review_dispute",
        "criterion": "reviewers disagree",
        "action": "two_round_mini_debate_then_arbitration",
        "escalation": "block_and_escalate_when_consensus_below_threshold",
    },
}

DECISION_OPTIONS = ["accept_with_risk", "rollback", "redesign"]
MAX_D_REGRESSION_CYCLES = 3
MAX_E_DEBATE_ROUNDS = 2
CONSENSUS_THRESHOLD = float(get_e_class_config()["required_consensus"])
SCHEMA_VERSION = "orchestra.v1"
EVENT_SCHEMA_VERSION = "orchestra.event.v1"
_ATOMIC_WRITER = AtomicWriter()


@dataclass(frozen=True)
class ImprovementRoute:
    classification: str
    action: str
    status: str
    route_result: str
    cycles_count: int
    verdict: str
    authority_route: dict[str, Any]
    residual_risks: list[dict[str, Any]]
    child_task_refs: list[str]
    decision_options: list[str]
    debate_rounds: list[dict[str, Any]]
    block_reason: str | None = None
    http_status: int = 200


def normalize_classification(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip().upper()
    if normalized in CLASSIFICATION_TABLE:
        return normalized
    return None


def unknown_classification(value: Any) -> dict[str, Any]:
    return {
        "event": "unknown_classification",
        "classification": value,
        "allowed": sorted(CLASSIFICATION_TABLE),
    }


def scope_violations(write_scope_ref: Any, changed_files: Any) -> list[str]:
    if not isinstance(write_scope_ref, list) or not isinstance(changed_files, list):
        return []
    allowed = {item for item in write_scope_ref if isinstance(item, str)}
    changed = [item for item in changed_files if isinstance(item, str)]
    return [path for path in changed if path not in allowed]


def route_improvement(payload: dict[str, Any]) -> ImprovementRoute:
    classification = normalize_classification(payload.get("classification"))
    if classification is None:
        raise ValueError("unknown_classification")

    violations = scope_violations(payload.get("write_scope_ref"), payload.get("changed_files"))
    task_id = payload.get("task_id") if isinstance(payload.get("task_id"), str) else "task"
    if violations:
        child_ref = f"child-task:{task_id}:scope-violation"
        return ImprovementRoute(
            classification=classification,
            action="scope_violation_block",
            status="blocked_scope_violation",
            route_result="scope_violation_blocked",
            cycles_count=_current_cycle(payload),
            verdict="blocked",
            authority_route={"target": "human", "reason": "scope_violation", "required_approvers": ["human"]},
            residual_risks=[{"risk": "unauthorized_write_scope", "severity": "high", "paths": violations}],
            child_task_refs=[child_ref],
            decision_options=[],
            debate_rounds=[],
            block_reason="blocked_scope_violation",
            http_status=422,
        )

    if classification == "E":
        return _route_dispute(payload)

    cycles_count = _next_cycle(payload) if payload.get("outcome") == "failed" else _current_cycle(payload)
    if payload.get("outcome") == "resolved":
        return _resolved_route(classification, cycles_count)

    if classification == "D" and cycles_count >= MAX_D_REGRESSION_CYCLES:
        return ImprovementRoute(
            classification=classification,
            action=CLASSIFICATION_TABLE[classification]["action"],
            status="regression_budget_exceeded",
            route_result="decision_required",
            cycles_count=MAX_D_REGRESSION_CYCLES,
            verdict="escalated",
            authority_route={"target": "kimi", "reason": "regression_budget_exceeded", "required_approvers": ["kimi"]},
            residual_risks=[{"risk": "architecture_fix_failed_three_times", "severity": "high"}],
            child_task_refs=[],
            decision_options=DECISION_OPTIONS,
            debate_rounds=[],
            block_reason="regression_budget_exceeded",
        )

    if classification in {"B", "C"} and cycles_count >= 2:
        return ImprovementRoute(
            classification=classification,
            action=CLASSIFICATION_TABLE[classification]["action"],
            status="escalated",
            route_result="decision_required",
            cycles_count=cycles_count,
            verdict="escalated",
            authority_route={"target": "human", "reason": "two_failed_simple_fix_cycles", "required_approvers": ["human"]},
            residual_risks=[{"risk": "simple_fix_failed_twice", "severity": "medium"}],
            child_task_refs=[],
            decision_options=[],
            debate_rounds=[],
            block_reason="regression_budget_exceeded",
        )

    return ImprovementRoute(
        classification=classification,
        action=CLASSIFICATION_TABLE[classification]["action"],
        status="retesting",
        route_result="improvement_queued",
        cycles_count=cycles_count,
        verdict="resolved" if classification == "A" and payload.get("outcome") == "passed" else "blocked" if cycles_count > MAX_D_REGRESSION_CYCLES else "resolved",
        authority_route={"target": "gateway", "reason": "within_regression_budget", "required_approvers": []},
        residual_risks=[],
        child_task_refs=[],
        decision_options=[],
        debate_rounds=[],
    )


def improvement_report(route: ImprovementRoute) -> dict[str, Any]:
    return {
        "classification": route.classification,
        "classification_detail": CLASSIFICATION_TABLE[route.classification],
        "cycles_count": route.cycles_count,
        "verdict": route.verdict,
        "status": route.status,
        "handling_action": route.action,
        "residual_risks": route.residual_risks,
        "child_task_refs": route.child_task_refs,
        "authority_route": route.authority_route,
        "decision_options": route.decision_options,
        "debate_rounds": route.debate_rounds,
        "replay_verification": {
            "script": "scripts/tests/test-gateway-review-verdict-improvement-budget.sh",
            "max_cycles": MAX_D_REGRESSION_CYCLES,
            "consensus_threshold": CONSENSUS_THRESHOLD,
        },
    }


def submit_improvement_endpoint(app: Any, run_id: str, payload: dict[str, Any]) -> tuple[int, dict[str, Any]]:
    run_path = app.store.run_path(run_id)
    if not run_path.exists():
        return 404, app.error("not_found", "run not found")
    idempotency_key = payload.get("idempotency_key")
    task_id = payload.get("task_id")
    if not isinstance(idempotency_key, str) or not idempotency_key.strip():
        return 400, app.error("validation_error", "idempotency_key is required")
    if not isinstance(task_id, str) or not task_id:
        return 400, app.error("validation_error", "task_id is required")

    endpoint = "POST /orchestra/runs/{run_id}/improvement"
    resource_path = f"/orchestra/runs/{run_id}/improvement"
    payload_hash = _canonical_payload_hash(payload)
    idempotency_path = app.store.idempotency_path(endpoint, resource_path, idempotency_key)
    if idempotency_path.exists():
        record = _read_json(idempotency_path)
        if record.get("payload_hash") == payload_hash and record.get("status") == "completed":
            return int(record.get("http_status") or 200), record["response_summary"]
        body = app.error("idempotency_conflict", "idempotency_key was already used with a different payload")
        body["existing_command_id"] = record.get("command_id")
        body["existing_run_id"] = record.get("run_id")
        return 409, body

    try:
        route = route_improvement(payload)
    except ValueError:
        _append_jsonl(
            app.store.audit_path(),
            {
                "timestamp": app.utc_now() if hasattr(app, "utc_now") else _utc_now(),
                "level": "L2",
                "project": app.store.project_id,
                "type": "unknown_classification",
                "decision": "REJECTED",
                "run_id": run_id,
                "task_id": task_id,
                "details": unknown_classification(payload.get("classification")),
            },
        )
        body = app.error("unknown_classification", "classification must be one of A, B, C, D, E")
        body["classification"] = payload.get("classification")
        return 400, body

    now = _utc_now()
    command_id = f"cmd-{uuid.uuid4().hex[:16]}"
    decision_id = f"decision-{uuid.uuid4().hex[:16]}" if route.route_result == "decision_required" else None
    command_path = app.store.command_path(run_id, command_id)
    report = improvement_report(route)
    report.update(
        {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "improvement_report",
            "run_id": run_id,
            "task_id": task_id,
            "command_id": command_id,
            "created_at": now,
            "decision_id": decision_id,
        }
    )
    report_ref = app.store.state_ref(run_id, "improvement_report.json")
    run_ref = app.store.state_ref(run_id, "run.json")
    audit_ref = app.store.audit_ref(command_id)
    command_record = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "command_record",
        "command_id": command_id,
        "idempotency_key": idempotency_key,
        "project": app.store.project_id,
        "endpoint": endpoint,
        "resource_path": resource_path,
        "status": "in_progress",
        "payload_hash": payload_hash,
        "intent": "submit_improvement",
        "planned_side_effects": ["write_improvement_report", "write_run_state", "append_audit", "append_event_projection"],
        "steps": [],
        "created_at": now,
        "updated_at": now,
    }
    _write_json(command_path, command_record)
    _write_json(app.store.run_dir(run_id) / "improvement_report.json", report)

    run = _read_json(run_path)
    artifact_refs = run.get("artifact_refs") if isinstance(run.get("artifact_refs"), dict) else {}
    artifact_refs["improvement_report"] = report_ref
    pending_refs = run.get("pending_decision_refs") if isinstance(run.get("pending_decision_refs"), list) else []
    if decision_id and report_ref not in pending_refs:
        pending_refs.append(report_ref)
    run.update(
        {
            "status": "blocked" if route.block_reason else "queued",
            "current_stage": "improvement",
            "last_command_id": command_id,
            "updated_at": now,
            "blocked_reason": route.block_reason,
            "pending_decision_id": decision_id,
            "pending_decision_refs": pending_refs if decision_id else [],
            "artifact_refs": artifact_refs,
        }
    )
    _write_json(run_path, run)
    _write_json(app.store.active_run_path(), {"schema_version": SCHEMA_VERSION, "run_id": run_id, "status": run["status"], "updated_at": now})

    if decision_id:
        decisions_path = app.store.run_dir(run_id) / "decisions.json"
        decisions = _read_json(decisions_path) if decisions_path.exists() else {"schema_version": SCHEMA_VERSION, "decisions": []}
        decisions.setdefault("decisions", []).append(
            {
                "decision_id": decision_id,
                "type": route.block_reason or "improvement_decision",
                "classification": route.classification,
                "options": route.decision_options,
                "authority_route": route.authority_route,
                "created_at": now,
                "artifact_refs": [report_ref],
            }
        )
        _write_json(decisions_path, decisions)

    _append_jsonl(
        app.store.audit_path(),
        {
            "timestamp": now,
            "level": "L2" if route.block_reason else "L1",
            "project": app.store.project_id,
            "type": "improvement_cycle_recorded",
            "decision": "BLOCKED" if route.block_reason else "RECORDED",
            "details": route.status,
            "approval_id": decision_id or "",
            "task_id": task_id,
            "agent_source": "orch-gateway",
            "command_id": command_id,
            "run_id": run_id,
            "classification": route.classification,
            "cycles_count": route.cycles_count,
            "authority_route": route.authority_route,
        },
    )

    projection_issue_refs = []
    event_ref = app.append_event(
        run_id,
        {
            "schema_version": EVENT_SCHEMA_VERSION,
            "seq": app.next_event_seq(run_id),
            "timestamp": now,
            "command_id": command_id,
            "idempotency_key": idempotency_key,
            "run_id": run_id,
            "task_id": task_id,
            "stage": "improvement",
            "type": "decision_required" if decision_id else "artifact_written",
            "severity": "error" if decision_id else "info",
            "status": route.status,
            "message": f"Improvement {route.classification} routed as {route.status}",
            "artifact_refs": [report_ref, run_ref, audit_ref],
            "decision_id": decision_id,
        },
    )
    if event_ref:
        projection_issue_refs.append(event_ref)

    response = {
        "schema_version": SCHEMA_VERSION,
        "command_id": command_id,
        "idempotency_key": idempotency_key,
        "run_id": run_id,
        "task_id": task_id,
        "improvement_report_ref": report_ref,
        "route_result": route.route_result,
        "status": route.status,
        "classification": route.classification,
        "cycles_count": route.cycles_count,
        "verdict": route.verdict,
        "decision_id": decision_id,
        "decision_options": route.decision_options,
        "authority_route": route.authority_route,
        "child_task_refs": route.child_task_refs,
        "debate_rounds": route.debate_rounds,
        "event_projection_degraded": bool(projection_issue_refs),
        "projection_status": "inconsistent" if projection_issue_refs else "consistent",
        "projection_issue_refs": projection_issue_refs,
    }
    command_record["status"] = "completed"
    command_record["updated_at"] = _utc_now()
    command_record["steps"] = [
        {"step_id": "write_improvement_report", "target_authority": "state", "operation": "write", "status": "completed", "refs": [report_ref]},
        {"step_id": "write_run_state", "target_authority": "state", "operation": "write", "status": "completed", "refs": [run_ref]},
        {"step_id": "append_audit", "target_authority": "audit", "operation": "append", "status": "completed", "refs": [audit_ref]},
        {"step_id": "append_event_projection", "target_authority": "state", "operation": "append", "status": "failed" if projection_issue_refs else "completed", "refs": projection_issue_refs or [app.store.state_ref(run_id, "events.jsonl")]},
    ]
    command_record["response_summary"] = response
    _write_json(command_path, command_record)
    _write_json(
        idempotency_path,
        {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "idempotency_record",
            "project": app.store.project_id,
            "endpoint": endpoint,
            "resource_path": resource_path,
            "idempotency_key": idempotency_key,
            "payload_hash": payload_hash,
            "status": "completed",
            "http_status": route.http_status,
            "command_id": command_id,
            "run_id": run_id,
            "task_id": task_id,
            "command_record_ref": app.store.state_ref(run_id, f"commands/{command_id}.json"),
            "response_summary": response,
            "created_at": now,
            "updated_at": _utc_now(),
        },
    )
    return route.http_status, response


def improvement_cycles_endpoint(app: Any, run_id: str) -> tuple[int, dict[str, Any]]:
    path = app.store.run_dir(run_id) / "improvement_report.json"
    if not path.exists():
        return 404, app.error("not_found", "improvement report not found")
    report = _read_json(path)
    return 200, {
        "schema_version": SCHEMA_VERSION,
        "run_id": run_id,
        "classification": report.get("classification"),
        "cycles_count": report.get("cycles_count"),
        "status": report.get("status"),
        "verdict": report.get("verdict"),
        "authority_route": report.get("authority_route"),
        "decision_options": report.get("decision_options", []),
        "debate_rounds": report.get("debate_rounds", []),
    }


def reject_unknown_classification(app: Any, run_id: str, task_id: str, classification: Any) -> tuple[int, dict[str, Any]]:
    _append_jsonl(
        app.store.audit_path(),
        {
            "timestamp": _utc_now(),
            "level": "L2",
            "project": app.store.project_id,
            "type": "unknown_classification",
            "decision": "REJECTED",
            "run_id": run_id,
            "task_id": task_id,
            "details": unknown_classification(classification),
        },
    )
    body = app.error("unknown_classification", "classification must be one of A, B, C, D, E")
    body["classification"] = classification
    return 400, body


def review_verdict_budget_exceeded(verdict: dict[str, Any]) -> bool:
    classification = normalize_classification(verdict.get("classification")) or "D"
    value = verdict.get("improvement_cycle", 0)
    current_cycle = value if isinstance(value, int) else 0
    return classification == "D" and current_cycle >= 2


def write_regression_decision(app: Any, run_id: str, decision_id: str, verdict: dict[str, Any], authority_required: str, verdict_ref: str, now: str) -> None:
    decisions_path = app.store.run_dir(run_id) / "decisions.json"
    decisions = _read_json(decisions_path) if decisions_path.exists() else {"schema_version": SCHEMA_VERSION, "decisions": []}
    decisions.setdefault("decisions", []).append(
        {
            "decision_id": decision_id,
            "type": "regression_budget_exceeded",
            "classification": normalize_classification(verdict.get("classification")) or "D",
            "options": DECISION_OPTIONS,
            "authority_route": {"target": authority_required, "reason": "regression_budget_exceeded", "required_approvers": [authority_required]},
            "created_at": now,
            "artifact_refs": [verdict_ref],
        }
    )
    _write_json(decisions_path, decisions)


def _route_dispute(payload: dict[str, Any]) -> ImprovementRoute:
    scores = payload.get("consensus_scores")
    if not isinstance(scores, list):
        scores = []
    numeric_scores = [
        float(score)
        for score in scores[:MAX_E_DEBATE_ROUNDS]
        if isinstance(score, (int, float)) and not isinstance(score, bool) and math.isfinite(score)
    ]
    rounds = [
        {"round": index + 1, "consensus_score": score}
        for index, score in enumerate(numeric_scores)
    ]
    while len(rounds) < MAX_E_DEBATE_ROUNDS:
        rounds.append({"round": len(rounds) + 1, "consensus_score": 0.0})
    final_score = rounds[-1]["consensus_score"]
    if final_score < CONSENSUS_THRESHOLD:
        return ImprovementRoute(
            classification="E",
            action=CLASSIFICATION_TABLE["E"]["action"],
            status="escalated",
            route_result="decision_required",
            cycles_count=_current_cycle(payload),
            verdict="escalated",
            authority_route={"target": "kimi", "reason": "review_dispute_unresolved", "required_approvers": ["kimi", "user"]},
            residual_risks=[{"risk": "review_dispute_unresolved", "severity": "high"}],
            child_task_refs=[],
            decision_options=["escalation"],
            debate_rounds=rounds,
            block_reason="review_dispute_unresolved",
        )
    return ImprovementRoute(
        classification="E",
        action=CLASSIFICATION_TABLE["E"]["action"],
        status="resolved",
        route_result="dispute_resolved",
        cycles_count=_current_cycle(payload),
        verdict="resolved",
        authority_route={"target": "gateway", "reason": "mini_debate_converged", "required_approvers": []},
        residual_risks=[],
        child_task_refs=[],
        decision_options=[],
        debate_rounds=rounds,
    )


def _resolved_route(classification: str, cycles_count: int) -> ImprovementRoute:
    return ImprovementRoute(
        classification=classification,
        action=CLASSIFICATION_TABLE[classification]["action"],
        status="resolved",
        route_result="resolved",
        cycles_count=cycles_count,
        verdict="resolved",
        authority_route={"target": "gateway", "reason": "fix_retested_successfully", "required_approvers": []},
        residual_risks=[],
        child_task_refs=[],
        decision_options=[],
        debate_rounds=[],
    )


def _current_cycle(payload: dict[str, Any]) -> int:
    value = payload.get("cycles_count", payload.get("improvement_cycle", 0))
    if not isinstance(value, int):
        return 0
    return max(0, min(value, MAX_D_REGRESSION_CYCLES))


def _next_cycle(payload: dict[str, Any]) -> int:
    return min(_current_cycle(payload) + 1, MAX_D_REGRESSION_CYCLES)


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _canonical_payload_hash(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _write_json(path: Any, data: dict[str, Any]) -> None:
    receipt = _ATOMIC_WRITER.write(path, data)
    if receipt.get("status") == "conflict":
        raise RuntimeError(f"atomic write conflict: {path}")


def _read_json(path: Any) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def _append_jsonl(path: Any, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        json.dump(record, handle, ensure_ascii=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
