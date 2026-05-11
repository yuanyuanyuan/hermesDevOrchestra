#!/usr/bin/env bash
set -euo pipefail

ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"
RUNTIME_ROOT="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
STATE_ROOT="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"
AUDIT_ROOT="${AUDIT_ROOT:-$HOME/.local/share/hermes-orchestra}"
CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hermes-orchestra}"

orch_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

orch_validate_project_id() {
    local project_id="${1:-}"

    if [[ ! "$project_id" =~ ^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$ ]]; then
        echo "Invalid project id. Use 3-32 lowercase letters, numbers, and hyphens; start and end with alphanumeric." >&2
        return 1
    fi
}

orch_require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required command not found: $command_name" >&2
        exit 1
    fi
}

orch_project_dirs() {
    if [ "${1:-}" != "" ]; then
        PROJECT_ID="$1"
    fi

    RUNTIME_DIR="$RUNTIME_ROOT/$PROJECT_ID"
    STATE_DIR="$STATE_ROOT/$PROJECT_ID"
    AUDIT_DIR="$AUDIT_ROOT/$PROJECT_ID"
    CACHE_DIR="$CACHE_ROOT/$PROJECT_ID"
    CLAUDE_SESSION="$(orch_claude_session_name "$PROJECT_ID")"
    CODEX_SESSION="$(orch_codex_session_name "$PROJECT_ID")"

    export PROJECT_ID RUNTIME_DIR STATE_DIR AUDIT_DIR CACHE_DIR CLAUDE_SESSION CODEX_SESSION
}

orch_project_workspace_root() {
    local project_dir="$1"
    local project_id="$2"

    printf '%s/.hermes/projects/%s' "$project_dir" "$project_id"
}

orch_project_override_dir() {
    local project_dir="$1"

    printf '%s/.hermes/profiles' "$project_dir"
}

orch_project_board_slug() {
    printf '%s' "$1"
}

orch_project_memory_namespace() {
    printf 'project:%s' "$1"
}

orch_role_default_expected_duration() {
    case "${1:-}" in
        implementer) printf '%s\n' "60min" ;;
        reviewer) printf '%s\n' "10min" ;;
        qa-tester) printf '%s\n' "20min" ;;
        researcher) printf '%s\n' "45min" ;;
        pm) printf '%s\n' "30min" ;;
        devops-engineer) printf '%s\n' "45min" ;;
        sre-observer) printf '%s\n' "30min" ;;
        orchestrator) printf '%s\n' "20min" ;;
        *) printf '%s\n' "30min" ;;
    esac
}

orch_parse_duration_seconds() {
    local raw="${1:-}"

    python3 - "$raw" <<'PY'
import re
import sys

raw = (sys.argv[1] or "").strip().lower()
if not raw:
    print(0)
    raise SystemExit(0)

match = re.fullmatch(r"(\d+)\s*(s|sec|secs|second|seconds|m|min|mins|minute|minutes|h|hr|hrs|hour|hours)?", raw)
if not match:
    print(0)
    raise SystemExit(0)

value = int(match.group(1))
unit = match.group(2) or "s"
factors = {
    "s": 1,
    "sec": 1,
    "secs": 1,
    "second": 1,
    "seconds": 1,
    "m": 60,
    "min": 60,
    "mins": 60,
    "minute": 60,
    "minutes": 60,
    "h": 3600,
    "hr": 3600,
    "hrs": 3600,
    "hour": 3600,
    "hours": 3600,
}
print(value * factors.get(unit, 1))
PY
}

orch_task_expected_duration() {
    local task_file="$1"
    local role="${2:-}"
    local value=""

    for field in expected_duration_max instructions.expected_duration_max metadata.expected_duration_max; do
        value="$(orch_json_field "$task_file" "$field")"
        if [ -n "$value" ] && [ "$value" != "null" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    orch_role_default_expected_duration "$role"
}

orch_profile_catalog_dir() {
    if [ -d "$ORCHESTRA_HOME/profile-distribution" ]; then
        printf '%s/profile-distribution' "$ORCHESTRA_HOME"
        return
    fi

    local fallback
    fallback="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../hermes/profile-distribution" && pwd)"
    printf '%s' "$fallback"
}

orch_active_run_file() {
    printf '%s\n' "$STATE_DIR/active-run.json"
}

orch_backpressure_file() {
    printf '%s\n' "$STATE_DIR/backpressure.json"
}

orch_trace_db_file() {
    printf '%s\n' "$AUDIT_DIR/observability_trace.db"
}

orch_managed_workspace_root() {
    local workspace_root

    workspace_root="$(orch_json_field "$STATE_DIR/paths.json" "workspace_root")"
    if [ -n "$workspace_root" ] && [ "$workspace_root" != "null" ]; then
        printf '%s\n' "$workspace_root"
    fi
}

orch_atomic_write() {
    local target="$1"
    local content_file="$2"
    local target_dir
    local temp_file

    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"
    temp_file="$(mktemp "$target_dir/.tmp.$(basename "$target").XXXXXX")"
    cp "$content_file" "$temp_file"
    mv "$temp_file" "$target"
}

orch_stage_for_project() {
    local project_id="$1"
    local runtime_dir="$RUNTIME_ROOT/$project_id"
    local state_dir="$STATE_ROOT/$project_id"
    local state_value=""
    local review_decision=""

    if [ -f "$runtime_dir/escalation.md" ]; then
        echo "blocked"
    elif [ -f "$runtime_dir/review-result.md" ]; then
        if [ -f "$state_dir/current-task.json" ]; then
            state_value="$(python3 - "$state_dir/current-task.json" <<'PY' 2>/dev/null || true
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("state", ""))
PY
)"
        fi
        case "$state_value" in
            completed|failed|waiting|blocked) echo "$state_value"; return ;;
        esac
        review_decision="$(python3 - "$runtime_dir/review-result.md" <<'PY' 2>/dev/null || true
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("decision", ""))
PY
)"
        case "$review_decision" in
            APPROVED) echo "completed" ;;
            REJECTED) echo "failed" ;;
            NEEDS_MODIFICATION) echo "waiting" ;;
            *) echo "completed" ;;
        esac
    elif [ -f "$runtime_dir/codex-result.md" ]; then
        echo "ready-for-review"
    elif [ -f "$runtime_dir/claude-decision.md" ]; then
        echo "claude-decided"
    elif [ -f "$runtime_dir/codex-question.md" ]; then
        echo "waiting-for-claude"
    elif [ -f "$state_dir/current-task.json" ]; then
        state_value="$(python3 - "$state_dir/current-task.json" <<'PY' 2>/dev/null || true
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("state", ""))
PY
)"
        case "$state_value" in
            executing) echo "codex-working" ;;
            queued|waiting|reviewing|completed|blocked|failed) echo "$state_value" ;;
            *) [ -f "$runtime_dir/task.md" ] && echo "queued" || echo "idle" ;;
        esac
    elif [ -f "$runtime_dir/task.md" ]; then
        echo "queued"
    else
        echo "idle"
    fi
}

orch_print_file_marker() {
    local file="$1"

    if [ -f "$file" ]; then
        echo "✓ $(basename "$file")"
    else
        echo "· $(basename "$file")"
    fi
}

orch_claude_session_name() {
    echo "hermes-$1-claude"
}

orch_codex_session_name() {
    echo "hermes-$1-codex"
}

orch_tmux_session_running() {
    local session="$1"
    tmux has-session -t "$session" 2>/dev/null
}

orch_tmux_session_healthy() {
    local session="$1"
    local pane_states

    orch_tmux_session_running "$session" || return 1
    pane_states="$(tmux list-panes -t "$session" -F '#{pane_dead}' 2>/dev/null || true)"
    ! printf '%s\n' "$pane_states" | grep -qx '1'
}

orch_write_project_state() {
    local state="$1"
    local task_id="${2:-null}"
    local workflow_state="${3-__CLEAR__}"
    local routing_reason="${4-__CLEAR__}"
    local resume_target="${5-__CLEAR__}"
    local handoff_ref="${6-__CLEAR__}"

    mkdir -p "$STATE_DIR"

    python3 - "$STATE_DIR/current-task.json" "$PROJECT_ID" "$state" "$task_id" "$(orch_now)" "$workflow_state" "$routing_reason" "$resume_target" "$handoff_ref" <<'PY'
import json, sys
path, project_id, state, task_id, now, workflow_state, routing_reason, resume_target, handoff_ref = sys.argv[1:]
if task_id in ("", "null"):
    task_id = None
try:
    with open(path, encoding="utf-8") as handle:
        current = json.load(handle)
except Exception:
    current = {}

def normalize(existing_value, raw_value):
    if raw_value == "__KEEP__":
        return existing_value
    if raw_value in ("", "null", "__CLEAR__"):
        return None
    return raw_value

with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "project_id": project_id,
        "state": state,
        "task_id": task_id,
        "workflow_state": normalize(current.get("workflow_state"), workflow_state),
        "routing_reason": normalize(current.get("routing_reason"), routing_reason),
        "resume_target": normalize(current.get("resume_target"), resume_target),
        "handoff_ref": normalize(current.get("handoff_ref"), handoff_ref),
        "updated_at": now,
    }, handle, indent=2)
    handle.write("\n")
PY
}

orch_current_task_hash() {
    if [ -f "$RUNTIME_DIR/task.md" ]; then
        sha256sum "$RUNTIME_DIR/task.md" | awk '{print $1}'
    fi
}

orch_json_field() {
    local file="$1"
    local field="$2"

    python3 - "$file" "$field" <<'PY' 2>/dev/null || true
import json, sys
path, field = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as handle:
        value = json.load(handle)
    for part in field.split("."):
        value = value[part]
    if isinstance(value, bool):
        print("true" if value else "false")
    elif value is None:
        print("null")
    else:
        print(value)
except Exception:
    pass
PY
}

orch_parse_block_reason_prefix() {
    local reason="${1:-}"

    case "$reason" in
        needs-user:*) echo "needs-user:" ;;
        needs-review:*) echo "needs-review:" ;;
        research-required:*) echo "research-required:" ;;
        *) return 1 ;;
    esac
}

orch_normalize_block_reason() {
    local default_prefix="${1:-needs-review:}"
    local detail="${2:-}"
    local prefix

    if prefix="$(orch_parse_block_reason_prefix "$detail" 2>/dev/null)"; then
        printf '%s\n' "$detail"
        return 0
    fi

    detail="${detail#"${detail%%[![:space:]]*}"}"
    if [ -z "$detail" ]; then
        detail="routing decision pending"
    fi
    printf '%s%s\n' "$default_prefix" "$detail"
}

orch_build_resume_target() {
    local target_type="${1:-task}"
    local target_id="${2:-}"

    if [ -z "$target_id" ]; then
        return 1
    fi
    printf '%s:%s\n' "$target_type" "$target_id"
}

orch_task_needs_research() {
    local file="$1"

    python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

def get(obj, path):
    value = obj
    for part in path.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value

def truthy(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "yes", "required", "needed", "research"}
    return bool(value)

if get(data, "next_action") == "create_research_task":
    sys.exit(0)

for path in (
    "research_required",
    "research_needed",
    "role_specific_payload.research_required",
    "role_specific_payload.research_needed",
):
    if truthy(get(data, path)):
        sys.exit(0)

allowed = {
    "new_stack",
    "new_capability",
    "unverified_stack",
    "solution_branching",
    "tradeoff",
    "branching",
    "explicit_research_request",
    "comparison",
    "proposal",
    "feasibility",
}
for path in ("research_triggers", "role_specific_payload.research_triggers"):
    value = get(data, path)
    if isinstance(value, list):
        normalized = {str(item).strip().lower() for item in value}
        if normalized & allowed:
            sys.exit(0)

research_topic = get(data, "research.topic")
if isinstance(research_topic, str) and research_topic.strip():
    sys.exit(0)

sys.exit(1)
PY
}

orch_task_needs_qa() {
    local file="$1"

    python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

def get(obj, path):
    value = obj
    for part in path.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value

def truthy(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "yes", "required", "high", "material"}
    return bool(value)

for path in (
    "qa_required",
    "role_specific_payload.qa_required",
    "user_visible_change",
    "role_specific_payload.user_visible_change",
    "qa.user_visible_change",
    "cross_module_integration",
    "role_specific_payload.cross_module_integration",
    "cross_boundary_integration",
    "role_specific_payload.cross_boundary_integration",
    "qa.cross_boundary_integration",
):
    if truthy(get(data, path)):
        sys.exit(0)

for path in (
    "acceptance_risk",
    "role_specific_payload.acceptance_risk",
    "regression_risk",
    "role_specific_payload.regression_risk",
    "qa.acceptance_risk",
    "qa.regression_risk",
):
    value = get(data, path)
    if isinstance(value, str) and value.strip().lower() in {"high", "material", "required"}:
        sys.exit(0)
    if value is True:
        sys.exit(0)

sys.exit(1)
PY
}

orch_task_graph_file() {
    echo "$STATE_DIR/task-graph.json"
}

orch_write_active_run() {
    local task_id="$1"
    local role="$2"
    local runner_kind="$3"
    local runner_id="$4"
    local workspace="$5"
    local expected_duration="$6"
    local snapshot_path="${7:-}"
    local engine_name="${8:-}"
    local task_file="${9:-$RUNTIME_DIR/task.md}"
    local active_run_file

    active_run_file="$(orch_active_run_file)"
    mkdir -p "$STATE_DIR"

    python3 - "$active_run_file" "$PROJECT_ID" "$task_id" "$role" "$runner_kind" "$runner_id" "$workspace" "$expected_duration" "$(orch_parse_duration_seconds "$expected_duration")" "$snapshot_path" "$engine_name" "$task_file" "$(orch_now)" "$(date +%s)" <<'PY'
import json
import os
import sys

(
    path,
    project_id,
    task_id,
    role,
    runner_kind,
    runner_id,
    workspace,
    expected_duration,
    expected_duration_seconds,
    snapshot_path,
    engine_name,
    task_file,
    started_at,
    started_at_epoch,
) = sys.argv[1:]

record = {
    "project_id": project_id,
    "task_id": task_id,
    "role": role,
    "runner_kind": runner_kind,
    "runner_id": runner_id,
    "workspace": workspace or None,
    "expected_duration_max": expected_duration,
    "expected_duration_seconds": int(expected_duration_seconds or 0),
    "snapshot_path": snapshot_path or None,
    "engine_name": engine_name or None,
    "task_file": task_file,
    "started_at": started_at,
    "started_at_epoch": int(started_at_epoch),
}

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(record, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
os.replace(tmp, path)
PY
}

orch_clear_active_run() {
    rm -f "$(orch_active_run_file)"
}

orch_observability_python() {
    python3 - "$@" <<'PY'
import os
import sqlite3
import sys

db_path = sys.argv[1]
action = sys.argv[2]
args = sys.argv[3:]

os.makedirs(os.path.dirname(db_path), exist_ok=True)
conn = sqlite3.connect(db_path)
conn.execute(
    """
    create table if not exists lifecycle_events (
      id integer primary key autoincrement,
      project_id text not null,
      task_id text,
      role text,
      status text,
      details text,
      event_at text not null
    )
    """
)
conn.execute(
    """
    create table if not exists env_snapshots (
      id integer primary key autoincrement,
      project_id text not null,
      task_id text,
      snapshot_path text,
      git_status text,
      disk_free text,
      hermes_status text,
      captured_at text not null
    )
    """
)

if action == "lifecycle":
    project_id, task_id, role, status, details, event_at = args
    conn.execute(
        "insert into lifecycle_events(project_id, task_id, role, status, details, event_at) values (?, ?, ?, ?, ?, ?)",
        (project_id, task_id, role, status, details, event_at),
    )
elif action == "snapshot":
    project_id, task_id, snapshot_path, git_status, disk_free, hermes_status, captured_at = args
    conn.execute(
        "insert into env_snapshots(project_id, task_id, snapshot_path, git_status, disk_free, hermes_status, captured_at) values (?, ?, ?, ?, ?, ?, ?)",
        (project_id, task_id, snapshot_path, git_status, disk_free, hermes_status, captured_at),
    )
else:
    raise SystemExit(f"unsupported action: {action}")

conn.commit()
conn.close()
PY
}

orch_record_lifecycle_event() {
    local task_id="$1"
    local role="$2"
    local status="$3"
    local details="${4:-}"

    orch_observability_python "$(orch_trace_db_file)" lifecycle "$PROJECT_ID" "$task_id" "$role" "$status" "$details" "$(orch_now)"
}

orch_capture_env_snapshot() {
    local task_id="$1"
    local project_dir="$2"
    local snapshot_dir="$AUDIT_DIR/env-snapshots"
    local snapshot_path="$snapshot_dir/${task_id}.$(date +%s).json"
    local git_status=""
    local disk_free=""
    local hermes_status=""

    mkdir -p "$snapshot_dir"

    if [ -d "$project_dir" ] && command -v git >/dev/null 2>&1; then
        git_status="$(git -C "$project_dir" status --short --branch 2>&1 || true)"
    fi
    disk_free="$(df -h 2>&1 | head -n 5 || true)"
    if command -v hermes >/dev/null 2>&1; then
        hermes_status="$(hermes status 2>&1 | head -n 20 || true)"
    else
        hermes_status="hermes unavailable"
    fi

    python3 - "$snapshot_path" "$PROJECT_ID" "$task_id" "$project_dir" "$git_status" "$disk_free" "$hermes_status" "$(orch_now)" <<'PY'
import json
import sys

path, project_id, task_id, project_dir, git_status, disk_free, hermes_status, captured_at = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "project_id": project_id,
        "task_id": task_id,
        "project_dir": project_dir,
        "captured_at": captured_at,
        "git_status": git_status,
        "disk_free": disk_free,
        "hermes_status": hermes_status,
    }, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY

    orch_observability_python "$(orch_trace_db_file)" snapshot "$PROJECT_ID" "$task_id" "$snapshot_path" "$git_status" "$disk_free" "$hermes_status" "$(orch_now)"
    printf '%s\n' "$snapshot_path"
}

orch_write_backpressure_state() {
    local current_role="$1"
    local downstream_role="$2"
    local ready_count="$3"
    local downstream_ready_count="$4"
    local ratio="$5"
    local task_id="${6:-}"
    local file

    file="$(orch_backpressure_file)"
    mkdir -p "$STATE_DIR"
    python3 - "$file" "$PROJECT_ID" "$current_role" "$downstream_role" "$ready_count" "$downstream_ready_count" "$ratio" "$task_id" "$(orch_now)" <<'PY'
import json
import sys

path, project_id, current_role, downstream_role, ready_count, downstream_ready_count, ratio, task_id, paused_at = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "project_id": project_id,
        "current_role": current_role,
        "downstream_role": downstream_role,
        "ready_count": int(float(ready_count)),
        "downstream_ready_count": int(float(downstream_ready_count)),
        "ratio": float(ratio),
        "task_id": task_id or None,
        "paused_at": paused_at,
    }, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
}

orch_clear_backpressure_state() {
    rm -f "$(orch_backpressure_file)"
}

orch_backpressure_reason_for_role() {
    local current_role="${1:-}"
    local graph_file

    case "$current_role" in
        implementer|reviewer) ;;
        *) return 1 ;;
    esac

    graph_file="$(orch_task_graph_file)"
    [ -f "$graph_file" ] || return 1

    python3 - "$graph_file" "$current_role" <<'PY'
import json
import sys

path, current_role = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    graph = json.load(handle)

tasks = graph.get("tasks") if isinstance(graph, dict) else []
if not isinstance(tasks, list):
    raise SystemExit(1)

downstream = {
    "implementer": "reviewer",
    "reviewer": "qa-tester",
}.get(current_role)
if not downstream:
    raise SystemExit(1)

def ready_count(role):
    return sum(1 for item in tasks if item.get("role") == role and item.get("state") == "ready")

current_ready = ready_count(current_role)
downstream_ready = ready_count(downstream)
ratio = current_ready / max(downstream_ready, 1)
if current_ready > 0 and ratio > 2.0:
    print(f"{current_role}|{downstream}|{current_ready}|{downstream_ready}|{ratio:.1f}")
    raise SystemExit(0)
raise SystemExit(1)
PY
}

orch_is_scoped_workspace() {
    local workspace="${1:-}"
    local managed_root=""

    [ -n "$workspace" ] || return 1
    managed_root="$(orch_managed_workspace_root)"

    case "$workspace" in
        "$RUNTIME_DIR"/workspaces/*) return 0 ;;
    esac
    if [ -n "$managed_root" ]; then
        case "$workspace" in
            "$managed_root"/*) return 0 ;;
        esac
    fi
    return 1
}

orch_cleanup_workspace() {
    local workspace="${1:-}"

    if ! orch_is_scoped_workspace "$workspace"; then
        return 1
    fi
    [ -d "$workspace" ] || return 0

    if git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$workspace" restore --source=HEAD --staged --worktree . >/dev/null 2>&1 || true
        git -C "$workspace" clean -fd >/dev/null 2>&1 || true
    else
        rm -rf "$workspace"
        mkdir -p "$workspace"
    fi
}

orch_validate_handoff_payload() {
    local source_file="$1"

    python3 - "$source_file" <<'PY'
import json
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

role = data.get("role")
status = data.get("status")
payload = data.get("role_specific_payload")
if not isinstance(payload, dict):
    raise SystemExit("role_specific_payload missing")

needs_schema = (role, status) in {
    ("implementer", "task_complete"),
    ("reviewer", "approved"),
    ("reviewer", "findings"),
}
if not needs_schema:
    raise SystemExit(0)

required = ("behaviors", "regression", "changed_files", "decisions", "pitfalls")
for field in required:
    if field not in payload:
        raise SystemExit(f"handoff field missing: {field}")

if not isinstance(payload["behaviors"], list):
    raise SystemExit("behaviors must be a list")
if not isinstance(payload["changed_files"], list):
    raise SystemExit("changed_files must be a list")
if not isinstance(payload["decisions"], list):
    raise SystemExit("decisions must be a list")
if not isinstance(payload["pitfalls"], list):
    raise SystemExit("pitfalls must be a list")
if not isinstance(payload["regression"], dict):
    raise SystemExit("regression must be an object")

unsafe = re.compile(r"(#!\/|<<['\"]?[A-Z_]+['\"]?|https?:\/\/[^ ]*(token|auth)|[`;$][^ \n]*rm\b|\$\(|\|\|)", re.IGNORECASE)
for field in ("decisions", "pitfalls"):
    for item in payload.get(field, []):
        if isinstance(item, str) and unsafe.search(item):
            raise SystemExit(f"unsafe handoff text in {field}")

print("ok")
PY
}

orch_task_graph_upsert() {
    local task_id="$1"
    local role="$2"
    local task_state="$3"
    local parents_csv="${4:-}"
    local handoff_ref="${5:-}"
    local title="${6:-}"
    local graph_file

    graph_file="$(orch_task_graph_file)"
    mkdir -p "$STATE_DIR"
    python3 - "$graph_file" "$PROJECT_ID" "$task_id" "$role" "$task_state" "$parents_csv" "$handoff_ref" "$title" "$(orch_now)" <<'PY'
import json
import os
import sys

path, project_id, task_id, role, task_state, parents_csv, handoff_ref, title, now = sys.argv[1:]
parents = [item for item in parents_csv.split(",") if item]
try:
    with open(path, encoding="utf-8") as handle:
        graph = json.load(handle)
    if not isinstance(graph, dict):
        raise ValueError("graph must be object")
except Exception:
    graph = {"project_id": project_id, "tasks": []}

tasks = graph.get("tasks")
if not isinstance(tasks, list):
    tasks = []

node = None
for item in tasks:
    if item.get("task_id") == task_id:
        node = item
        break

if node is None:
    node = {"task_id": task_id}
    tasks.append(node)

node["role"] = role
node["state"] = task_state
node["parents"] = parents
node["handoff_ref"] = handoff_ref or None
node["title"] = title or node.get("title") or None
node["updated_at"] = now

graph["project_id"] = project_id
graph["updated_at"] = now
graph["tasks"] = tasks

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(graph, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
os.replace(tmp, path)
PY
}

orch_project_matches_if_present() {
    local file="$1"
    local file_project

    file_project="$(orch_json_field "$file" "project_id")"
    [ -z "$file_project" ] || [ "$file_project" = "$PROJECT_ID" ]
}

orch_correlation_compatible() {
    local expected=""
    local file
    local value

    for file in "$@"; do
        [ -f "$file" ] || continue
        value="$(orch_json_field "$file" "correlation_id")"
        [ -n "$value" ] || continue
        if [ -z "$expected" ]; then
            expected="$value"
        elif [ "$expected" != "$value" ]; then
            return 1
        fi
    done
}

orch_archive_task_artifacts() {
    local task_id="${1:-}"
    local archive_dir
    local copied_file
    local copied_files=()

    if [ -z "$task_id" ] || [ "$task_id" = "null" ]; then
        task_id="$(orch_json_field "$STATE_DIR/current-task.json" "task_id")"
    fi
    if [ -z "$task_id" ] || [ "$task_id" = "null" ]; then
        task_id="unknown-$(date +%s)"
    fi

    archive_dir="$AUDIT_DIR/archive/$(date +%Y-%m-%d)/$task_id"
    mkdir -p "$archive_dir"

    for copied_file in task.md codex-question.md claude-decision.md codex-result.md review-result.md escalation.md; do
        if [ -f "$RUNTIME_DIR/$copied_file" ]; then
            cp "$RUNTIME_DIR/$copied_file" "$archive_dir/$copied_file"
            copied_files+=("$copied_file")
        fi
    done

    python3 - "$archive_dir/archive-manifest.json" "$PROJECT_ID" "$task_id" "$(orch_now)" "${copied_files[@]}" <<'PY'
import json, sys
path, project_id, task_id, archived_at, *files = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "project_id": project_id,
        "task_id": task_id,
        "archived_at": archived_at,
        "files": files,
    }, handle, indent=2)
    handle.write("\n")
PY
}

orch_audit_file() {
    echo "$AUDIT_DIR/audit.jsonl"
}

orch_rotate_audit_if_needed() {
    local audit_file

    audit_file="$(orch_audit_file)"
    if [ -f "$audit_file" ] && [ "$(wc -c < "$audit_file")" -gt 10485760 ]; then
        mv "$audit_file" "$(dirname "$audit_file")/audit-$(date +%Y%m%d-%H%M%S).jsonl"
    fi
}

orch_append_audit() {
    local type="$1"
    local project="$2"
    local level="$3"
    local decision="$4"
    local user_decision="$5"
    local details="$6"
    local approval_id="$7"
    local ttl="$8"
    local task_id="$9"
    local escalation_id="${10}"
    local agent_source="${11}"
    local session_id="${12}"
    local audit_dir="$AUDIT_ROOT/$project"
    local audit_file="$audit_dir/audit.jsonl"

    mkdir -p "$audit_dir"
    AUDIT_DIR="$audit_dir" orch_rotate_audit_if_needed
    python3 - "$audit_file" "$(orch_now)" "$level" "$project" "$type" "$decision" "$user_decision" "$details" "$approval_id" "$ttl" "$task_id" "$escalation_id" "$agent_source" "$session_id" <<'PY'
import json
import os
import sys

path, timestamp, level, project, event_type, decision, user_decision, details, approval_id, ttl, task_id, escalation_id, agent_source, session_id = sys.argv[1:]
record = {
    "timestamp": timestamp,
    "level": level,
    "project": project,
    "type": event_type,
    "decision": decision,
    "user_decision": user_decision,
    "details": details,
    "approval_id": approval_id,
    "ttl": ttl,
    "task_id": task_id,
    "escalation_id": escalation_id,
    "agent_source": agent_source,
    "session_id": session_id,
}
with open(path, "a", encoding="utf-8") as handle:
    json.dump(record, handle, ensure_ascii=False)
    handle.write("\n")
    handle.flush()
    os.fsync(handle.fileno())
PY
}

orch_pending_dir() {
    echo "$STATE_DIR/pending-decisions"
}

orch_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
    fi
}

orch_policy_file() {
    local package_dir

    if [ -f "$ORCHESTRA_HOME/risk-policy.yaml" ]; then
        printf '%s\n' "$ORCHESTRA_HOME/risk-policy.yaml"
        return 0
    fi

    package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    printf '%s/config/risk-policy.yaml\n' "$package_dir"
}

orch_l4_approval_phrase() {
    local approval_id="${1:-}"

    if [ -z "$approval_id" ]; then
        return 1
    fi
    printf 'APPROVE-L4 %s\n' "$approval_id"
}

orch_valid_implementer_block_category() {
    case "${1:-}" in
        architecture-decision|external-dependency-unavailable|risk-policy-intercepted|critical-test-failure) return 0 ;;
        *) return 1 ;;
    esac
}

orch_infer_implementer_block_category() {
    local status="${1:-}"
    local requested="${2:-}"
    local detail="${3:-}"
    local lowered

    if orch_valid_implementer_block_category "$requested"; then
        printf '%s\n' "$requested"
        return 0
    fi

    if [ "$status" = "test_failed" ]; then
        printf '%s\n' "critical-test-failure"
        return 0
    fi

    lowered="$(printf '%s' "$detail" | tr '[:upper:]' '[:lower:]')"
    case "$lowered" in
        *risk-policy*|*approval*|*l3*|*l4*)
            printf '%s\n' "risk-policy-intercepted"
            ;;
        *dependency*|*registry*|*network*|*service\ unavailable*|*package\ index*|*dns*)
            printf '%s\n' "external-dependency-unavailable"
            ;;
        *)
            printf '%s\n' "architecture-decision"
            ;;
    esac
}

orch_create_pending_decision() {
    local level="$1"
    local type="$2"
    local details="$3"
    local task_id="$4"
    local escalation_id="$5"
    local agent_source="$6"
    local approval_id
    local ttl="3600"
    local created_at
    local created_at_epoch
    local expires_at_epoch
    local pending_dir
    local pending_file
    local runtime_mailbox
    local approval_mode="explicit"
    local required_phrase=""

    approval_id="$(orch_uuid)"
    if [ "$level" = "L4" ]; then
        approval_mode="fixed_phrase"
        required_phrase="$(orch_l4_approval_phrase "$approval_id")"
    fi
    created_at="$(orch_now)"
    created_at_epoch="$(date +%s)"
    expires_at_epoch="$((created_at_epoch + ttl))"
    pending_dir="$(orch_pending_dir)"
    pending_file="$pending_dir/$approval_id.json"
    runtime_mailbox="$RUNTIME_DIR/decision-request.$approval_id.json"

    mkdir -p "$pending_dir" "$RUNTIME_DIR"
    python3 - "$pending_file" "$approval_id" "$PROJECT_ID" "$level" "$type" "$details" "$task_id" "$escalation_id" "$agent_source" "$ttl" "$created_at" "$created_at_epoch" "$expires_at_epoch" "$approval_mode" "$required_phrase" <<'PY'
import json
import os
import sys

path, approval_id, project_id, level, request_type, details, task_id, escalation_id, agent_source, ttl, created_at, created_at_epoch, expires_at_epoch, approval_mode, required_phrase = sys.argv[1:]
record = {
    "approval_id": approval_id,
    "project_id": project_id,
    "binding_project_id": project_id,
    "level": level,
    "type": request_type,
    "details": details,
    "task_id": task_id,
    "binding_task_id": task_id,
    "escalation_id": escalation_id,
    "agent_source": agent_source,
    "ttl": int(ttl),
    "created_at": created_at,
    "created_at_epoch": int(created_at_epoch),
    "expires_at_epoch": int(expires_at_epoch),
    "approval_mode": approval_mode,
    "required_phrase": required_phrase,
    "status": "PENDING",
    "used_at": "",
    "decision": "",
    "user_decision": "",
}
tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(record, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
os.replace(tmp, path)
PY
    cp "$pending_file" "$runtime_mailbox"
    orch_append_audit "decision_requested" "$PROJECT_ID" "$level" "PENDING" "" "$details" "$approval_id" "$ttl" "$task_id" "$escalation_id" "$agent_source" ""
    echo "$approval_id"
}

orch_find_pending_decision() {
    local approval_id="$1"
    local matches

    matches="$(find "$STATE_ROOT" -path "*/pending-decisions/$approval_id.json" -type f 2>/dev/null || true)"
    if [ -z "$matches" ]; then
        return 2
    fi
    if [ "$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')" -ne 1 ]; then
        return 6
    fi
    printf '%s\n' "$matches"
}

orch_pending_decision_approved() {
    local approval_id="$1"
    local project_id="$2"
    local task_id="$3"
    local pending_file

    pending_file="$(orch_find_pending_decision "$approval_id")" || return 1
    python3 - "$pending_file" "$project_id" "$task_id" "$(date +%s)" <<'PY'
import json
import sys

path, project_id, task_id, now = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    record = json.load(handle)
if record.get("project_id") != project_id:
    sys.exit(1)
if record.get("task_id") != task_id:
    sys.exit(1)
if record.get("binding_project_id") != record.get("project_id"):
    sys.exit(1)
if record.get("binding_task_id") != record.get("task_id"):
    sys.exit(1)
if not record.get("used_at"):
    sys.exit(1)
if record.get("decision") != "APPROVED":
    sys.exit(1)
if int(record.get("expires_at_epoch") or 0) < int(now):
    sys.exit(1)
PY
}

orch_resolve_pending_decision() {
    local approval_id="$1"
    local decision="$2"
    local user_decision="$3"
    local pending_file
    local project_id
    local task_id
    local level
    local details
    local escalation_id
    local runtime_dir
    local decision_file
    local resolution_status
    local lock_output

    pending_file="$(orch_find_pending_decision "$approval_id")" || {
        echo "Pending decision not found: $approval_id" >&2
        exit 2
    }

    set +e
    lock_output="$(
        {
            flock -x 9
            python3 - "$pending_file" "$RUNTIME_ROOT" "$approval_id" "$decision" "$user_decision" "$(orch_now)" "$(date +%s)" <<'PY'
import json
import os
import sys
import uuid

pending_path, runtime_root, approval_id, decision, rationale, timestamp, now = sys.argv[1:]
with open(pending_path, encoding="utf-8") as handle:
    pending = json.load(handle)

if pending.get("used_at"):
    sys.exit(4)
if int(pending.get("expires_at_epoch") or 0) < int(now):
    sys.exit(3)
if not pending.get("project_id") or not pending.get("task_id"):
    sys.exit(5)
if pending.get("binding_project_id") != pending.get("project_id") or pending.get("binding_task_id") != pending.get("task_id"):
    sys.exit(5)
if decision == "APPROVED" and pending.get("approval_mode") == "fixed_phrase":
    if rationale != pending.get("required_phrase"):
        sys.exit(7)

project_id = pending["project_id"]
task_id = pending["task_id"]
level = pending.get("level", "")
runtime_dir = os.path.join(runtime_root, project_id)
os.makedirs(runtime_dir, exist_ok=True)
decision_path = os.path.join(runtime_dir, "claude-decision.md")
approved = decision == "APPROVED"
record = {
    "schema_version": "1.0",
    "message_id": f"user-decision-{uuid.uuid4()}",
    "project_id": project_id,
    "task_id": task_id,
    "correlation_id": f"approval-{approval_id}",
    "status": "resolved",
    "author": "user",
    "authority": level,
    "timestamp": timestamp,
    "decision": decision,
    "rationale": rationale,
    "approval_id": approval_id,
    "level": level,
    "assessment": {"assessed_level": level},
    "execution": {"authority_sufficient": approved},
}
tmp_decision = f"{decision_path}.tmp"
with open(tmp_decision, "w", encoding="utf-8") as handle:
    json.dump(record, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
os.replace(tmp_decision, decision_path)

pending["used_at"] = timestamp
pending["status"] = "RESOLVED"
pending["decision"] = decision
pending["user_decision"] = rationale
tmp_pending = f"{pending_path}.tmp"
with open(tmp_pending, "w", encoding="utf-8") as handle:
    json.dump(pending, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
os.replace(tmp_pending, pending_path)
PY
        } 9>"$pending_file.lock"
    )"
    resolution_status=$?
    set -e

    case "$resolution_status" in
        0) ;;
        3) echo "Pending decision expired: $approval_id" >&2; exit 3 ;;
        4) echo "Pending decision already used: $approval_id" >&2; exit 4 ;;
        5) echo "Pending decision binding mismatch: $approval_id" >&2; exit 5 ;;
        7) echo "Approval phrase mismatch: expected $(orch_json_field "$pending_file" "required_phrase")" >&2; exit 7 ;;
        *) echo "Pending decision resolution failed: $approval_id" >&2; [ -n "$lock_output" ] && echo "$lock_output" >&2; exit "$resolution_status" ;;
    esac

    project_id="$(orch_json_field "$pending_file" "project_id")"
    task_id="$(orch_json_field "$pending_file" "task_id")"
    level="$(orch_json_field "$pending_file" "level")"
    details="$(orch_json_field "$pending_file" "details")"
    escalation_id="$(orch_json_field "$pending_file" "escalation_id")"
    runtime_dir="$RUNTIME_ROOT/$project_id"
    decision_file="$runtime_dir/claude-decision.md"

    if [ "$decision" = "APPROVED" ]; then
        orch_append_audit "decision_approved" "$project_id" "$level" "APPROVED" "$user_decision" "$details" "$approval_id" "3600" "$task_id" "$escalation_id" "orch-approve" ""
    else
        orch_append_audit "decision_rejected" "$project_id" "$level" "REJECTED" "$user_decision" "$details" "$approval_id" "3600" "$task_id" "$escalation_id" "orch-reject" ""
    fi
    printf '%s %s project=%s task=%s\n' "$decision" "$approval_id" "$project_id" "$task_id"
}
