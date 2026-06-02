from __future__ import annotations

import hashlib
import json
from collections import deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class DagValidationError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def compute_source_fingerprint(agent_id: str, workspace_path: str, context_hash: str) -> str:
    for label, value in {
        "agent_id": agent_id,
        "workspace_path": workspace_path,
        "context_hash": context_hash,
    }.items():
        if not isinstance(value, str) or not value:
            raise DagValidationError("validation_error", f"{label} must be a non-empty string")
    return hashlib.sha256(f"{agent_id}{workspace_path}{context_hash}".encode("utf-8")).hexdigest()


def validate_dag(dag: dict[str, Any], event_log_path: str | Path | None = None) -> dict[str, Any]:
    nodes = _nodes(dag)
    edges = _edges(dag)
    node_ids = [node["id"] for node in nodes]
    node_id_set = set(node_ids)
    adjacency = {node_id: [] for node_id in node_ids}
    incoming = {node_id: set() for node_id in node_ids}
    errors: list[str] = []

    for source, target in edges:
        if source not in node_id_set or target not in node_id_set:
            errors.append("unknown_edge_endpoint")
            continue
        adjacency[source].append(target)
        incoming[target].add(source)

    back_edges = _back_edges(adjacency)
    cycle_detected = bool(back_edges)
    if cycle_detected:
        errors.append("cycle_detected")
        _append_event(event_log_path, {"type": "dag_cycle_detected", "back_edges": back_edges})

    root_id = dag.get("root_id") or ("root" if "root" in node_id_set else (node_ids[0] if node_ids else None))
    reachable = _reachable(adjacency, root_id) if root_id else set()
    orphan_task_ids = [node_id for node_id in node_ids if node_id not in reachable]
    if orphan_task_ids:
        errors.append("orphan_task")
        _append_event(event_log_path, {"type": "orphan_task", "orphan_task_ids": orphan_task_ids})

    topological_order = _topological_order(adjacency, incoming)
    topological_sort_consistent = bool(topological_order) and _dependencies_match(nodes, edges, topological_order)
    if not topological_sort_consistent:
        errors.append("topological_sort_mismatch")

    return {
        "acyclicity_passed": not cycle_detected and "unknown_edge_endpoint" not in errors,
        "cycle_detected": cycle_detected,
        "back_edges": back_edges,
        "connectivity_passed": not orphan_task_ids,
        "orphan_task_ids": orphan_task_ids,
        "topological_order": topological_order,
        "topological_sort_consistent": topological_sort_consistent,
        "passed": not errors,
        "errors": errors,
    }


def check_source_isolation(tasks: list[dict[str, Any]], audit_log_path: str | Path | None = None) -> dict[str, Any]:
    normalized = []
    degraded = False
    collisions = []
    seen: dict[tuple[str, str], str] = {}

    for task in tasks:
        task_id = _task_id(task)
        delegate_to = _string(task.get("delegate_to") or task.get("assigned_actor") or task.get("agent_id"), "delegate_to")
        fingerprint = task.get("source_fingerprint")
        if not isinstance(fingerprint, str) or not fingerprint:
            source = task.get("source") if isinstance(task.get("source"), dict) else {}
            agent_id = source.get("agent_id") or delegate_to
            workspace_path = source.get("workspace_path")
            context_hash = source.get("context_hash")
            if isinstance(workspace_path, str) and isinstance(context_hash, str):
                fingerprint = compute_source_fingerprint(agent_id, workspace_path, context_hash)
            else:
                degraded = True
                fingerprint = "unavailable"

        key = (delegate_to, fingerprint)
        collision_with = seen.get(key)
        collision_result = collision_with is not None and fingerprint != "unavailable"
        if collision_result:
            collisions.append(
                {
                    "task_id": task_id,
                    "collides_with_task_id": collision_with,
                    "delegate_to": delegate_to,
                    "source_fingerprint": fingerprint,
                }
            )
            _append_event(audit_log_path, {"type": "source_collision", "task_id": task_id, "collides_with_task_id": collision_with})
        else:
            seen.setdefault(key, task_id)

        record = {
            "type": "source_isolation_check",
            "task_id": task_id,
            "delegate_to": delegate_to,
            "expected_fingerprint": fingerprint,
            "actual_fingerprint": fingerprint,
            "collision_result": collision_result,
        }
        normalized.append(record)
        _append_event(audit_log_path, record)

    return {
        "passed": not collisions and not degraded,
        "degraded": degraded,
        "execution_mode": "sequential_execution" if degraded or collisions else "parallel_allowed",
        "collisions": collisions,
        "checks": normalized,
    }


def _nodes(dag: dict[str, Any]) -> list[dict[str, Any]]:
    raw_nodes = dag.get("nodes")
    if not isinstance(raw_nodes, list) or not raw_nodes:
        raise DagValidationError("validation_error", "dag.nodes must be a non-empty list")
    nodes = []
    for node in raw_nodes:
        if isinstance(node, str):
            nodes.append({"id": node})
        elif isinstance(node, dict):
            node_id = node.get("id") or node.get("task_id")
            nodes.append({**node, "id": _string(node_id, "node.id")})
        else:
            raise DagValidationError("validation_error", "dag.nodes entries must be strings or objects")
    return nodes


def _edges(dag: dict[str, Any]) -> list[tuple[str, str]]:
    raw_edges = dag.get("edges", [])
    if not isinstance(raw_edges, list):
        raise DagValidationError("validation_error", "dag.edges must be a list")
    edges = []
    for edge in raw_edges:
        if isinstance(edge, dict):
            source = edge.get("from") or edge.get("source")
            target = edge.get("to") or edge.get("target")
        elif isinstance(edge, list) and len(edge) == 2:
            source, target = edge
        else:
            raise DagValidationError("validation_error", "dag.edges entries must be objects or pairs")
        edges.append((_string(source, "edge.from"), _string(target, "edge.to")))
    return edges


def _back_edges(adjacency: dict[str, list[str]]) -> list[dict[str, str]]:
    visiting: set[str] = set()
    visited: set[str] = set()
    back_edges: list[dict[str, str]] = []

    def visit(node_id: str) -> None:
        visiting.add(node_id)
        for child_id in adjacency[node_id]:
            if child_id in visiting:
                back_edges.append({"from": node_id, "to": child_id})
            elif child_id not in visited:
                visit(child_id)
        visiting.remove(node_id)
        visited.add(node_id)

    for node_id in adjacency:
        if node_id not in visited:
            visit(node_id)
    return back_edges


def _reachable(adjacency: dict[str, list[str]], root_id: str) -> set[str]:
    seen = {root_id}
    queue = deque([root_id])
    while queue:
        node_id = queue.popleft()
        for child_id in adjacency.get(node_id, []):
            if child_id not in seen:
                seen.add(child_id)
                queue.append(child_id)
    return seen


def _topological_order(adjacency: dict[str, list[str]], incoming: dict[str, set[str]]) -> list[str]:
    remaining = {node_id: set(deps) for node_id, deps in incoming.items()}
    queue = deque([node_id for node_id, deps in remaining.items() if not deps])
    order = []
    while queue:
        node_id = queue.popleft()
        order.append(node_id)
        for child_id in adjacency[node_id]:
            remaining[child_id].discard(node_id)
            if not remaining[child_id]:
                queue.append(child_id)
    return order if len(order) == len(adjacency) else []


def _dependencies_match(nodes: list[dict[str, Any]], edges: list[tuple[str, str]], order: list[str]) -> bool:
    position = {node_id: index for index, node_id in enumerate(order)}
    edge_set = set(edges)
    for node in nodes:
        node_id = node["id"]
        dependencies = node.get("dependencies", [])
        if not isinstance(dependencies, list):
            return False
        for dependency in dependencies:
            if not isinstance(dependency, str):
                return False
            if (dependency, node_id) not in edge_set:
                return False
            if position.get(dependency, -1) >= position.get(node_id, -1):
                return False
    return True


def _task_id(task: dict[str, Any]) -> str:
    return _string(task.get("task_id") or task.get("id"), "task_id")


def _string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise DagValidationError("validation_error", f"{label} must be a non-empty string")
    return value


def _append_event(path: str | Path | None, record: dict[str, Any]) -> None:
    if path is None:
        return
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        **record,
    }
    with target.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")
