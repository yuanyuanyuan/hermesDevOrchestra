#!/usr/bin/env python3
"""Two-round correction gate for Sprint 3 CLI flows."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from time import time_ns
from typing import Any

from atomic_writer import AtomicWriter
from project_config_loader import ProjectConfigLoader


NODE_DEFINITIONS = [
    {"id": "low_confidence", "label": "Low confidence", "reason": "intent confidence is below confirmation threshold"},
    {"id": "conflict", "label": "Conflict", "reason": "request or config contains conflicting signals"},
    {"id": "l3_l4_target", "label": "L3/L4 target", "reason": "request touches an approval-gated target level"},
    {"id": "protected_target", "label": "Protected target", "reason": "request touches protected targets"},
    {"id": "goal_divergence", "label": "Goal divergence", "reason": "request appears to diverge from the project profile"},
    {"id": "unreliable_inference", "label": "Unreliable inference", "reason": "required details cannot be inferred reliably"},
]
NODE_INDEX = {node["id"]: node for node in NODE_DEFINITIONS}


def build_confirmation_nodes(
    intent: dict[str, Any],
    profile: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    profile = profile or {}
    payload = intent.get("normalized_payload") if isinstance(intent.get("normalized_payload"), dict) else {}
    ticket = payload.get("ticket") if isinstance(payload.get("ticket"), dict) else {}
    threshold = float(profile.get("interaction", {}).get("confirmation_threshold", 0.5))
    confidence = float(intent.get("confidence", 0.0) or 0.0)
    validation_errors = intent.get("validation_errors") if isinstance(intent.get("validation_errors"), list) else []
    protected_targets = ticket.get("protected_targets") or payload.get("protected_targets") or profile.get("protected_targets") or []
    target_level = str(ticket.get("target_level") or payload.get("target_level") or payload.get("authority_level") or "").upper()
    goal_divergence = bool(payload.get("goal_divergence") or ticket.get("goal_divergence"))
    unreliable_inference = bool(payload.get("unreliable_inference") or not ticket.get("acceptance_criteria"))

    triggered: list[str] = []
    if confidence < threshold:
        triggered.append("low_confidence")
    if validation_errors or payload.get("conflicts") or ticket.get("conflicts"):
        triggered.append("conflict")
    if target_level in {"L3", "L4"}:
        triggered.append("l3_l4_target")
    if _has_values(protected_targets) or payload.get("protected_target"):
        triggered.append("protected_target")
    if goal_divergence:
        triggered.append("goal_divergence")
    if unreliable_inference or confidence < 0.75:
        triggered.append("unreliable_inference")

    return [dict(NODE_INDEX[node_id]) for node_id in triggered]


def make_mock_intent() -> dict[str, Any]:
    return {
        "intent_type": "create_run",
        "confidence": 0.42,
        "validation_errors": ["mock_conflict"],
        "normalized_payload": {
            "intent": "modify protected checkout policy",
            "goal_divergence": False,
            "ticket": {
                "goal": "Update checkout risk policy",
                "acceptance_criteria": [],
                "target_level": "L2",
                "protected_targets": [],
            },
        },
    }


def run_batch(intent: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    nodes = build_confirmation_nodes(intent, profile)
    return {
        "status": "confirmation_required" if nodes else "approved",
        "mode": "non-interactive",
        "warn": "non-interactive: two-round correction degraded to single-round confirmation",
        "rounds_completed": 1,
        "override": False,
        "confirmation_nodes": [node["id"] for node in nodes],
    }


def run_interactive(intent: dict[str, Any], profile: dict[str, Any], project_dir: Path) -> dict[str, Any]:
    nodes = build_confirmation_nodes(intent, profile)
    print(f"round_1: confirmation nodes => {', '.join(node['id'] for node in nodes) or 'none'}")
    print("round_1: Is the summary correct? [Y/N/Explain]")
    first = _read_choice()
    if first == "Y":
        return {
            "status": "approved",
            "mode": "cli_interactive",
            "rounds_completed": 1,
            "override": False,
            "confirmation_nodes": [node["id"] for node in nodes],
        }

    print("round_1_follow_up: Choose [Explain/Y/N]")
    second = _read_choice()
    if second == "Explain":
        print("round_2: scope -> confirm acceptance criteria")
        print("round_2: risk -> confirm protected target and approval level")
        print("round_2: fallback -> clarify if the original goal still stands")
        final = _read_choice()
        override = final == "N"
        result = {
            "status": "blocked" if override else "approved",
            "mode": "cli_interactive",
            "rounds_completed": 2,
            "override": override,
            "confirmation_nodes": [node["id"] for node in nodes],
        }
        if override:
            result["writer_receipt"] = append_override_record(project_dir, intent, result)
        return result

    override = second == "N"
    result = {
        "status": "blocked" if override else "approved",
        "mode": "cli_interactive",
        "rounds_completed": 1,
        "override": override,
        "confirmation_nodes": [node["id"] for node in nodes],
    }
    if override:
        result["writer_receipt"] = append_override_record(project_dir, intent, result)
    return result


def append_override_record(project_dir: Path, intent: dict[str, Any], result: dict[str, Any]) -> dict[str, Any]:
    log_path = project_dir / ".hermes" / "override-log.jsonl"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    existing = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
    record = {
        "timestamp": _utc_now(),
        "original_intent": intent.get("normalized_payload", {}).get("intent") or intent.get("intent_type"),
        "user_override": "persist_original_intent",
        "approval_status": "pending_approval" if "l3_l4_target" in result.get("confirmation_nodes", []) else "not_required",
        "confirmation_nodes": result.get("confirmation_nodes", []),
    }
    payload = existing + json.dumps(record, ensure_ascii=False) + "\n"
    temp_path = log_path.with_name(f".tmp.{log_path.name}.{os.getpid()}.{time_ns()}")
    with temp_path.open("w", encoding="utf-8") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temp_path, log_path)
    AtomicWriter._fsync_parent(log_path.parent)
    return {
        "status": "written",
        "path": str(log_path),
        "temp_path": str(temp_path),
    }


def _has_values(value: Any) -> bool:
    return isinstance(value, list) and any(str(item).strip() for item in value)


def _read_choice() -> str:
    line = sys.stdin.readline()
    if not line:
        return "Y"
    return line.strip() or "Y"


def _utc_now() -> str:
    import datetime as _dt

    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-dir", default=".")
    parser.add_argument("--project-id")
    parser.add_argument("--list-nodes", action="store_true")
    parser.add_argument("--interactive", action="store_true")
    parser.add_argument("--batch", action="store_true")
    parser.add_argument("--mock", action="store_true")
    args = parser.parse_args(argv)

    if args.list_nodes:
        for node in NODE_DEFINITIONS:
            print(node["id"])
        return 0

    loader = ProjectConfigLoader()
    profile = loader.load(args.project_dir, args.project_id)
    intent = make_mock_intent() if args.mock or args.interactive or args.batch else make_mock_intent()
    project_dir = Path(args.project_dir).resolve()

    if args.batch:
        print(json.dumps(run_batch(intent, profile), ensure_ascii=False))
        return 0
    if args.interactive:
        print(json.dumps(run_interactive(intent, profile, project_dir), ensure_ascii=False))
        return 0

    print(json.dumps({"confirmation_nodes": build_confirmation_nodes(intent, profile)}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
