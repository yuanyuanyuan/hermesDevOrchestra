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

orch_profile_catalog_dir() {
    if [ -d "$ORCHESTRA_HOME/profile-distribution" ]; then
        printf '%s/profile-distribution' "$ORCHESTRA_HOME"
        return
    fi

    local fallback
    fallback="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../hermes/profile-distribution" && pwd)"
    printf '%s' "$fallback"
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

    mkdir -p "$STATE_DIR"

    python3 - "$STATE_DIR/current-task.json" "$PROJECT_ID" "$state" "$task_id" "$(orch_now)" <<'PY'
import json, sys
path, project_id, state, task_id, now = sys.argv[1:]
if task_id in ("", "null"):
    task_id = None
with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "project_id": project_id,
        "state": state,
        "task_id": task_id,
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

    approval_id="$(orch_uuid)"
    created_at="$(orch_now)"
    created_at_epoch="$(date +%s)"
    expires_at_epoch="$((created_at_epoch + ttl))"
    pending_dir="$(orch_pending_dir)"
    pending_file="$pending_dir/$approval_id.json"
    runtime_mailbox="$RUNTIME_DIR/decision-request.$approval_id.json"

    mkdir -p "$pending_dir" "$RUNTIME_DIR"
    python3 - "$pending_file" "$approval_id" "$PROJECT_ID" "$level" "$type" "$details" "$task_id" "$escalation_id" "$agent_source" "$ttl" "$created_at" "$created_at_epoch" "$expires_at_epoch" <<'PY'
import json
import os
import sys

path, approval_id, project_id, level, request_type, details, task_id, escalation_id, agent_source, ttl, created_at, created_at_epoch, expires_at_epoch = sys.argv[1:]
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
