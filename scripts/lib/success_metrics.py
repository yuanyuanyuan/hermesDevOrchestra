from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def load_policy(repo_root: Path | str) -> dict[str, Any]:
    path = Path(repo_root) / "config/performance/slo-policy.json"
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    metrics = data.get("success_metrics")
    if not isinstance(metrics, list) or not metrics:
        raise ValueError("slo-policy.json is missing success_metrics")
    return data


def read_events(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            record = json.loads(line)
            if isinstance(record, dict):
                events.append(record)
    return events


def aggregate_run(repo_root: Path | str, state_root: Path | str, run_id: str) -> dict[str, Any]:
    policy = load_policy(repo_root)
    run_dir = _find_run_dir(Path(state_root), run_id)
    events = read_events(run_dir / "events.jsonl")
    return aggregate_events(policy, events, run_id)


def aggregate_events(policy: dict[str, Any], events: list[dict[str, Any]], run_id: str) -> dict[str, Any]:
    metrics = []
    for metric in policy["success_metrics"]:
        metric_id = metric["metric_id"]
        observed = _observed_value(metric_id, metric, events)
        status = _status(metric, observed)
        metrics.append(
            {
                "metric_id": metric_id,
                "source_events": metric["source_events"],
                "aggregation_rule": metric["aggregation_rule"],
                "threshold": metric["threshold"],
                "observed_value": observed,
                "status": status,
            }
        )
    return {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "metrics_summary",
        "run_id": run_id,
        "metrics": metrics,
    }


def verify_metrics(metrics_summary: dict[str, Any], policy: dict[str, Any]) -> dict[str, Any]:
    expected = {metric["metric_id"] for metric in policy["success_metrics"]}
    observed = {
        metric.get("metric_id"): metric.get("status")
        for metric in metrics_summary.get("metrics", [])
        if isinstance(metric, dict)
    }
    missing = sorted(expected - set(observed))
    failing = sorted(metric_id for metric_id, status in observed.items() if status not in {"pass", "warn"})
    return release_gate_report(
        strict_six_stage_passed=True,
        schema_sync_passed=True,
        metrics_pipeline_passed=not missing and not failing,
        block_reasons=[*(f"missing_metric:{item}" for item in missing), *(f"metric_failed:{item}" for item in failing)],
    )


def release_gate_report(
    *,
    strict_six_stage_passed: bool,
    schema_sync_passed: bool,
    metrics_pipeline_passed: bool,
    block_reasons: list[str] | None = None,
) -> dict[str, Any]:
    reasons = list(block_reasons or [])
    if not strict_six_stage_passed:
        reasons.append("strict_six_stage_failed")
    if not schema_sync_passed:
        reasons.append("schema_sync_failed")
    if not metrics_pipeline_passed:
        reasons.append("metrics_pipeline_failed")
    approved = strict_six_stage_passed and schema_sync_passed and metrics_pipeline_passed
    return {
        "schema_version": "orchestra.full.v1",
        "artifact_type": "release_gate_report",
        "strict_six_stage_passed": strict_six_stage_passed,
        "schema_sync_passed": schema_sync_passed,
        "metrics_pipeline_passed": metrics_pipeline_passed,
        "release_approved": approved,
        "block_reasons": [] if approved else sorted(set(reasons)),
    }


def _find_run_dir(state_root: Path, run_id: str) -> Path:
    direct = state_root / "runs" / run_id
    if direct.is_dir():
        return direct
    candidates = list(state_root.glob(f"*/runs/{run_id}"))
    if candidates:
        return candidates[0]
    nested = list(state_root.glob(f"**/runs/{run_id}"))
    if nested:
        return nested[0]
    raise FileNotFoundError(f"run not found in state root: {run_id}")


def atomic_write_json(path: Path | str, payload: dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(f".{target.name}.tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(tmp, target)


def _records(metric: dict[str, Any], events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    source_events = set(metric["source_events"])
    return [event for event in events if _event_type(event) in source_events]


def _event_type(event: dict[str, Any]) -> str:
    return str(event.get("event_type") or event.get("type") or "")


def _payload(event: dict[str, Any]) -> dict[str, Any]:
    payload = event.get("payload")
    return payload if isinstance(payload, dict) else event


def _observed_value(metric_id: str, metric: dict[str, Any], events: list[dict[str, Any]]) -> float:
    records = [_payload(event) for event in _records(metric, events)]
    if not records:
        return 0.0
    if metric_id == "intent_only_start_rate":
        return _ratio(records, lambda item: item.get("has_intent_only") is True)
    if metric_id == "intake_completion_coverage":
        keys = ["has_env_deps", "has_upstream", "has_downstream", "has_implicit", "has_acceptance_matrix"]
        return _ratio(records, lambda item: all(item.get(key) is True for key in keys))
    if metric_id == "conflict_auto_resolved_rate":
        return _ratio(records, lambda item: item.get("resolution") == "auto_resolved")
    if metric_id == "debate_error_interception_count":
        return float(len(records))
    if metric_id == "implementation_evidence_rate":
        keys = ["has_test_evidence", "has_review_evidence", "write_scope_verified"]
        return _ratio(records, lambda item: all(item.get(key) is True for key in keys))
    if metric_id == "improvement_a_class_closure_rate":
        return _ratio(records, lambda item: item.get("a_fixed") is True)
    if metric_id == "improvement_d_class_closure_rate":
        return _ratio(records, lambda item: int(item.get("d_regression_loops") or 99) <= 3)
    if metric_id == "global_warning_rate":
        return len(records) / max(1, len(events))
    if metric_id == "closeout_proposals_applied":
        return float(sum(int(item.get("proposals_applied") or 0) for item in records))
    if metric_id == "gateway_blocked_count":
        return float(len(records))
    if metric_id == "autonomous_run_rate":
        return _ratio(records, lambda item: int(item.get("human_intervention_count") or 0) == 0)
    if metric_id == "heartbeat_progress_health":
        return _ratio(records, lambda item: float(item.get("latency_ms") or 999999) <= 5000 and float(item.get("delivery_rate") or 0) >= 0.99)
    if metric_id == "quick_channel_auto_merge_rate":
        return _ratio(records, lambda item: item.get("auto_merged") is True)
    if metric_id == "risk_notification_delivery_rate":
        return _ratio(records, lambda item: item.get("delivery_confirmed") is True)
    raise ValueError(f"unknown success metric: {metric_id}")


def _ratio(records: list[dict[str, Any]], predicate) -> float:
    return sum(1 for item in records if predicate(item)) / max(1, len(records))


def _status(metric: dict[str, Any], observed: float) -> str:
    threshold = metric["threshold"]
    kind = threshold["kind"]
    if kind == "min":
        return "pass" if observed >= float(threshold["value"]) else "fail"
    if kind == "max":
        return "pass" if observed <= float(threshold["value"]) else "fail"
    if kind == "range":
        return "pass" if float(threshold["min"]) <= observed <= float(threshold["max"]) else "fail"
    raise ValueError(f"unknown threshold kind: {kind}")
